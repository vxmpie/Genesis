import asyncio
import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

DASHBOARD_DIR = str(Path(__file__).resolve().parents[1])
if DASHBOARD_DIR not in sys.path:
    sys.path.insert(0, DASHBOARD_DIR)

from backend.api.ws import _build_init_payload, handle_ws_command  # noqa: E402
from backend.app import app  # noqa: E402
from backend.core import auth as auth_mod  # noqa: E402
from backend.core.config import (  # noqa: E402
    DEFAULT_CONFIG,
    mask_config_for_client,
    mask_secret_url,
)


async def _call_asgi(
    method: str,
    path: str,
    body: dict | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[int, dict]:
    raw_body = json.dumps(body).encode("utf-8") if body is not None else b""
    req_headers = [(b"host", b"127.0.0.1:7700")]
    if body is not None:
        req_headers.append((b"content-type", b"application/json"))
    for k, v in (headers or {}).items():
        req_headers.append((k.lower().encode("latin-1"), v.encode("latin-1")))

    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": method,
        "scheme": "http",
        "path": path,
        "raw_path": path.encode("ascii"),
        "query_string": b"",
        "headers": req_headers,
        "client": ("10.0.0.55", 50000),
        "server": ("127.0.0.1", 7700),
    }

    sent_once = False
    status_code = 500
    chunks: list[bytes] = []

    async def receive():
        nonlocal sent_once
        if not sent_once:
            sent_once = True
            return {"type": "http.request", "body": raw_body, "more_body": False}
        return {"type": "http.disconnect"}

    async def send(message):
        nonlocal status_code
        if message["type"] == "http.response.start":
            status_code = message["status"]
        elif message["type"] == "http.response.body":
            chunks.append(message.get("body", b""))

    await app(scope, receive, send)
    raw = b"".join(chunks).decode("utf-8", errors="ignore")
    parsed = json.loads(raw) if raw else {}
    return status_code, parsed


class _FakeWebSocket:
    def __init__(self) -> None:
        self.sent: list[dict] = []
        self.query_params: dict[str, str] = {}

    async def accept(self) -> None:
        return None

    async def send_json(self, data: dict) -> None:
        self.sent.append(data)


class TestSecurityAndApi(unittest.IsolatedAsyncioTestCase):
    def test_mask_secrets_strips_all_sensitive_fields(self) -> None:
        cfg = copy.deepcopy(DEFAULT_CONFIG)
        cfg["auth"] = {"enabled": True, "pin": "123456", "pin_hash": "abc", "salt": "xyz"}
        cfg["alerts"]["discord_webhook_url"] = "https://discord.com/api/webhooks/111222/SUPERSECRETTOKEN"
        cfg["alerts"]["discord_bot_token"] = "BOT_SECRET_TOKEN_XYZ9"
        cfg["alerts"]["discord_channel_id"] = "1541091932657426521"
        cfg["alerts"]["heartbeat_url"] = "https://hc-ping.com/secret-uuid-1234"
        cfg["tunnel"]["ngrok_authtoken"] = "2N_NGROK_RAW_SECRET"

        masked = mask_config_for_client(cfg)
        serialized = json.dumps(masked)

        self.assertNotIn("SUPERSECRETTOKEN", serialized)
        self.assertNotIn("BOT_SECRET_TOKEN_XYZ9", serialized)
        self.assertNotIn("secret-uuid-1234", serialized)
        self.assertNotIn("2N_NGROK_RAW_SECRET", serialized)
        self.assertNotIn("pin_hash", serialized)
        self.assertNotIn('"salt"', serialized)
        self.assertNotIn("123456", serialized)

        self.assertTrue(masked["alerts"]["discord_webhook_configured"])
        self.assertTrue(masked["alerts"]["discord_webhook_masked"].endswith("****OKEN"))
        self.assertTrue(masked["alerts"]["discord_bot_configured"])
        self.assertEqual(masked["alerts"]["discord_bot_masked"], "****XYZ9")
        self.assertEqual(masked["alerts"]["discord_bot_token"], "")
        self.assertTrue(masked["tunnel"]["ngrok_authtoken_configured"])
        self.assertEqual(mask_secret_url(""), "")

    def test_get_client_ip_trusts_cf_header_only_for_cloudflared(self) -> None:
        req = SimpleNamespace(
            client=SimpleNamespace(host="127.0.0.1"),
            headers={
                "CF-Connecting-IP": "198.51.100.250",
                "X-Forwarded-For": "192.0.2.1, 203.0.113.10",
            },
        )
        self.assertEqual(auth_mod.get_client_ip(req, tunnel_provider="ngrok"), "203.0.113.10")
        self.assertEqual(auth_mod.get_client_ip(req, tunnel_provider="cloudflared"), "198.51.100.250")

    def test_ip_lockout_after_five_failures_and_permanent_session_persistence(self) -> None:
        ip = "203.0.113.99"
        auth_mod.clear_failed_attempts(ip)
        for idx in range(5):
            self.assertFalse(auth_mod.is_ip_locked(ip, now=1000.0 + idx))
            auth_mod.record_failed_attempt(ip, now=1000.0 + idx)
        self.assertTrue(auth_mod.is_ip_locked(ip, now=1010.0))
        self.assertGreater(auth_mod.get_lockout_remaining(ip, now=1010.0), 0)
        self.assertFalse(auth_mod.is_ip_locked(ip, now=1310.0))

        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_sessions = Path(tmpdir) / "sessions.json"
            with patch.object(auth_mod, "DATA_DIR", Path(tmpdir)), patch.object(
                auth_mod, "SESSIONS_PATH", tmp_sessions
            ):
                auth_mod._save_sessions({"perm_tok": 0.0})
                loaded = auth_mod._load_sessions()
                self.assertIn("perm_tok", loaded)
                self.assertEqual(loaded["perm_tok"], 0.0)

    async def test_unauthenticated_rest_mutations_blocked_and_config_masked(self) -> None:
        with patch.object(auth_mod, "is_auth_enabled", return_value=True):
            status, cfg_body = await _call_asgi("GET", "/api/config")
            self.assertEqual(status, 200)
            self.assertEqual(cfg_body["alerts"]["discord_webhook_url"], "")
            self.assertEqual(cfg_body["tunnel"]["ngrok_authtoken"], "")
            self.assertNotIn("pin_hash", cfg_body["auth"])

            for method, path, payload in [
                ("POST", "/api/mumu/set_game", {"instance": 1, "place_id": 123}),
                ("POST", "/api/mumu/set_username", {"instance": 1, "username": "abc"}),
                ("PUT", "/api/alerts/config", {"notify_on_drift": False}),
                ("POST", "/api/alerts/test", {}),
                ("POST", "/api/alerts/purge", {"limit": 50}),
            ]:
                st, _ = await _call_asgi(method, path, payload)
                self.assertEqual(st, 401, f"Expected 401 for {method} {path}")

            with patch.object(auth_mod, "verify_session_token", return_value=True), patch(
                "backend.api.routes.update_alerts_config", return_value={"notify_on_drift": False}
            ), patch(
                "backend.api.routes.notifier.send_test_alert",
                new=AsyncMock(
                    return_value={"ok": True, "http_status": 204, "error": "", "entry": {"status": "delivered"}}
                ),
            ):
                st_cfg, body_cfg = await _call_asgi(
                    "PUT",
                    "/api/alerts/config",
                    {"notify_on_drift": False},
                    headers={"X-Auth-Token": "valid-test-token"},
                )
                self.assertEqual(st_cfg, 200)
                self.assertTrue(body_cfg["ok"])

                st_test, body_test = await _call_asgi(
                    "POST",
                    "/api/alerts/test",
                    {},
                    headers={"X-Auth-Token": "valid-test-token"},
                )
                self.assertEqual(st_test, 200)
                self.assertTrue(body_test["ok"])

    async def test_ws_init_masked_and_mutating_commands_require_auth(self) -> None:
        ws = _FakeWebSocket()
        from backend.api import ws as ws_mod

        await ws_mod.manager.connect(ws, False)
        try:
            init_payload = await _build_init_payload(False)
            self.assertEqual(init_payload["config"]["alerts"]["discord_webhook_url"], "")
            self.assertEqual(init_payload["config"]["tunnel"]["ngrok_authtoken"], "")
            self.assertIn("alerts_status", init_payload)
            self.assertIn("tunnel", init_payload)

            with patch.object(ws_mod, "is_auth_enabled", return_value=True):
                for cmd in [
                    "governor_action",
                    "set_mumu_game",
                    "set_mumu_username",
                    "flush_shader_cache",
                    "toggle_timer_resolution",
                    "toggle_pcore_affinity",
                    "update_alerts_config",
                    "test_discord_alert",
                    "purge_discord_alerts",
                ]:
                    ws.sent.clear()
                    await handle_ws_command(ws, {"command": cmd})
                    self.assertEqual(ws.sent[-1]["type"], "auth_required", f"Expected auth_required for {cmd}")
        finally:
            ws_mod.manager.disconnect(ws)


if __name__ == "__main__":
    unittest.main()
