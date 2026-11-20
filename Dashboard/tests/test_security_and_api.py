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
                ("POST", "/api/tunnel/restart", {}),
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
            ), patch(
                "backend.api.routes.request_tunnel_restart",
                return_value={
                    "ok": True,
                    "tunnel": {
                        "provider": "cloudflared",
                        "status": "restarting",
                        "tunnel_url": None,
                        "local_url": "http://127.0.0.1:7700",
                        "started_at": None,
                        "last_error": None,
                    },
                },
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

                st_tun, body_tun = await _call_asgi(
                    "POST",
                    "/api/tunnel/restart",
                    {},
                    headers={"X-Auth-Token": "valid-test-token"},
                )
                self.assertEqual(st_tun, 200)
                self.assertTrue(body_tun["ok"])
                self.assertEqual(body_tun["tunnel"]["status"], "restarting")

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
                    "set_auto_rejoin",
                    "trim_process",
                    "kill_process",
                    "flush_shader_cache",
                    "toggle_timer_resolution",
                    "toggle_pcore_affinity",
                    "update_alerts_config",
                    "test_discord_alert",
                    "purge_discord_alerts",
                    "restart_tunnel",
                ]:
                    ws.sent.clear()
                    await handle_ws_command(ws, {"command": cmd})
                    self.assertEqual(ws.sent[-1]["type"], "auth_required", f"Expected auth_required for {cmd}")
        finally:
            ws_mod.manager.disconnect(ws)

    def test_request_tunnel_restart_guard_and_state_transition(self) -> None:
        from backend.services import tunnel as tunnel_mod

        orig_state = dict(tunnel_mod._tunnel_state)
        try:
            with patch.dict(
                tunnel_mod.CONFIG,
                {"tunnel": {"provider": "ngrok", "ngrok_authtoken": "tok123", "ngrok_domain": ""}},
                clear=False,
            ), patch.object(tunnel_mod, "add_event"), patch.object(
                tunnel_mod, "broadcast_payload_threadsafe"
            ) as mock_bcast:
                tunnel_mod._update_tunnel_state(
                    provider="ngrok", status="online", tunnel_url="https://example.ngrok.dev"
                )
                first = tunnel_mod.request_tunnel_restart()
                self.assertTrue(first["ok"])
                self.assertEqual(first["tunnel"]["status"], "restarting")
                self.assertIsNone(first["tunnel"]["tunnel_url"])
                self.assertTrue(mock_bcast.called)

                second = tunnel_mod.request_tunnel_restart()
                self.assertFalse(second["ok"])
                self.assertIn("already in progress", second["error"])
        finally:
            with tunnel_mod._tunnel_lock:
                tunnel_mod._tunnel_state.clear()
                tunnel_mod._tunnel_state.update(orig_state)

    def test_tunnel_local_only_blocks_cloudflared_fallback_and_tailscale_mode(self) -> None:
        from backend.services import tunnel as tunnel_mod

        orig_state = dict(tunnel_mod._tunnel_state)
        try:
            with patch.dict(
                tunnel_mod.CONFIG,
                {"tunnel": {"provider": "local_only", "ngrok_authtoken": "", "ngrok_domain": "", "tailscale_url": ""}},
                clear=False,
            ):
                res_local = tunnel_mod.request_tunnel_restart()
                self.assertFalse(res_local["ok"])
                self.assertIn("local-only", res_local["error"])

            with patch.dict(
                tunnel_mod.CONFIG,
                {
                    "tunnel": {
                        "provider": "tailscale",
                        "ngrok_authtoken": "",
                        "ngrok_domain": "",
                        "tailscale_url": "https://genesis.taile67ec7.ts.net/",
                    }
                },
                clear=False,
            ), patch.object(tunnel_mod, "add_event"), patch.object(
                tunnel_mod, "broadcast_payload_threadsafe"
            ):
                tunnel_mod._update_tunnel_state(
                    provider="tailscale", status="online", tunnel_url="https://genesis.taile67ec7.ts.net"
                )
                res_ts = tunnel_mod.request_tunnel_restart()
                self.assertTrue(res_ts["ok"])
                self.assertEqual(res_ts["tunnel"]["status"], "restarting")

            self.assertEqual(
                tunnel_mod._detect_tailscale_serve_url("https://genesis.taile67ec7.ts.net/"),
                "https://genesis.taile67ec7.ts.net",
            )
            mock_proc = SimpleNamespace(
                returncode=0,
                stdout="https://genesis.taile67ec7.ts.net (tailnet only)\n|-- / proxy http://127.0.0.1:7700\n",
            )
            with patch.object(tunnel_mod.subprocess, "run", return_value=mock_proc):
                self.assertEqual(
                    tunnel_mod._detect_tailscale_serve_url(""),
                    "https://genesis.taile67ec7.ts.net",
                )
        finally:
            with tunnel_mod._tunnel_lock:
                tunnel_mod._tunnel_state.clear()
                tunnel_mod._tunnel_state.update(orig_state)

    async def test_ws_trim_and_kill_process_validation_and_protection(self) -> None:
        ws = _FakeWebSocket()
        from backend.api import ws as ws_mod

        await ws_mod.manager.connect(ws, True)
        try:
            with patch.object(ws_mod, "is_auth_enabled", return_value=True):
                for bad_pid in (0, 4, -3, "bad", True):
                    ws.sent.clear()
                    await handle_ws_command(ws, {"command": "trim_process", "pid": bad_pid})
                    self.assertEqual(ws.sent[-1]["type"], "process_trim_result")
                    self.assertFalse(ws.sent[-1]["data"]["success"])

                    ws.sent.clear()
                    await handle_ws_command(ws, {"command": "kill_process", "pid": bad_pid})
                    self.assertEqual(ws.sent[-1]["type"], "process_kill_result")
                    self.assertFalse(ws.sent[-1]["data"]["success"])

                for bad_mumu_pid in ("bad", 4, True):
                    ws.sent.clear()
                    await handle_ws_command(ws, {"command": "trim_mumu_instance", "pid": bad_mumu_pid})
                    self.assertEqual(ws.sent[-1]["type"], "mumu_trim_result")
                    self.assertFalse(ws.sent[-1]["data"]["success"])

                protected_proc = SimpleNamespace(
                    name=lambda: "csrss.exe",
                    terminate=lambda: (_ for _ in ()).throw(AssertionError("should not terminate protected")),
                )
                with patch.object(ws_mod.psutil, "Process", return_value=protected_proc):
                    ws.sent.clear()
                    await handle_ws_command(ws, {"command": "kill_process", "pid": 4444})
                    self.assertEqual(ws.sent[-1]["type"], "process_kill_result")
                    self.assertFalse(ws.sent[-1]["data"]["success"])
                    self.assertIn("protected", ws.sent[-1]["data"]["error"])

                terminated: list[bool] = []
                regular_proc = SimpleNamespace(
                    name=lambda: "notepad.exe",
                    terminate=lambda: terminated.append(True),
                )
                with patch.object(ws_mod.psutil, "Process", return_value=regular_proc), patch.object(
                    ws_mod, "add_event"
                ):
                    ws.sent.clear()
                    await handle_ws_command(ws, {"command": "kill_process", "pid": 5555})
                    self.assertEqual(ws.sent[-1]["type"], "process_kill_result")
                    self.assertTrue(ws.sent[-1]["data"]["success"])
                    self.assertEqual(terminated, [True])
        finally:
            ws_mod.manager.disconnect(ws)

    async def test_ws_set_auto_rejoin_and_heartbeat_skip(self) -> None:
        ws = _FakeWebSocket()
        from backend.api import ws as ws_mod
        from backend.services import mumu_monitor as mm

        orig_mumu = copy.deepcopy(mm.CONFIG.get("mumu", {}))
        await ws_mod.manager.connect(ws, True)
        try:
            with patch.object(ws_mod, "is_auth_enabled", return_value=True):
                for bad_inst in (0, "bad"):
                    ws.sent.clear()
                    await handle_ws_command(ws, {"command": "set_auto_rejoin", "instance": bad_inst, "enabled": False})
                    self.assertEqual(ws.sent[-1]["type"], "error")

                with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
                    ws.sent.clear()
                    await handle_ws_command(ws, {"command": "set_auto_rejoin", "instance": 2, "enabled": False})
                    self.assertEqual(ws.sent[-1]["type"], "auto_rejoin_updated")
                    self.assertEqual(ws.sent[-1]["instance"], 2)
                    self.assertFalse(ws.sent[-1]["enabled"])
                    self.assertFalse(mm.CONFIG["mumu"]["instance_auto_rejoin"]["2"])

                    with patch(
                        "backend.api.routes.record_bot_heartbeat",
                        return_value={
                            "instance": 2,
                            "serial": "127.0.0.1:16416",
                            "place_id": 123,
                            "game_name": "TestGame",
                            "status": "disconnected",
                            "ack": 1.0,
                        },
                    ), patch("backend.api.routes.recover_roblox_instance") as mock_rec, patch(
                        "backend.api.routes.add_event"
                    ):
                        st, body = await _call_asgi(
                            "POST",
                            "/api/bot/heartbeat",
                            {"instance": 2, "status": "disconnected", "place_id": 123},
                        )
                        self.assertEqual(st, 200)
                        self.assertTrue(body["ok"])
                        self.assertTrue(body.get("rejoin_skipped"))
                        mock_rec.assert_not_called()
        finally:
            mm.CONFIG["mumu"] = orig_mumu
            ws_mod.manager.disconnect(ws)


class ConfigAndWebSocketRegressionTests(unittest.IsolatedAsyncioTestCase):
    def test_load_config_handles_utf8_bom(self) -> None:
        import json
        import tempfile
        from pathlib import Path
        from unittest import mock
        from backend.core import config as config_mod

        payload = {
            "server": {"host": "127.0.0.1", "port": 7700},
            "tunnel": {"enabled": True, "provider": "tailscale"},
        }
        bom_bytes = b"\xef\xbb\xbf" + json.dumps(payload).encode("utf-8")

        with tempfile.TemporaryDirectory() as tmp:
            cfg_path = Path(tmp) / "config.json"
            cfg_path.write_bytes(bom_bytes)
            with mock.patch.object(config_mod, "CONFIG_PATH", cfg_path):
                loaded = config_mod.load_config()
            self.assertEqual(loaded["tunnel"]["provider"], "tailscale")
            self.assertEqual(loaded["server"]["port"], 7700)

            example_path = Path(tmp) / "config.example.json"
            example_path.write_bytes(bom_bytes)
            missing_path = Path(tmp) / "missing.json"
            with (
                mock.patch.object(config_mod, "CONFIG_PATH", missing_path),
                mock.patch.object(config_mod, "CONFIG_EXAMPLE_PATH", example_path),
            ):
                loaded_example = config_mod.load_config()
            self.assertEqual(loaded_example["tunnel"]["provider"], "tailscale")

    async def test_ws_disconnect_leaves_no_unretrieved_task_exception(self) -> None:
        import asyncio
        import gc
        from types import SimpleNamespace
        from unittest import mock
        from fastapi import WebSocketDisconnect
        from backend.api import ws as ws_mod

        loop = asyncio.get_running_loop()
        loop_exceptions: list[dict] = []
        old_handler = loop.get_exception_handler()
        loop.set_exception_handler(lambda _loop, context: loop_exceptions.append(context))

        def _make_fake_ws(receive_side_effect) -> mock.MagicMock:
            sock = mock.MagicMock()
            sock.headers = {}
            sock.query_params = {}
            sock.cookies = {}
            sock.client = SimpleNamespace(host="127.0.0.1", port=54321)
            sock.accept = mock.AsyncMock()
            sock.close = mock.AsyncMock()
            sock.send_text = mock.AsyncMock()
            sock.send_json = mock.AsyncMock()
            sock.receive_text = mock.AsyncMock(side_effect=receive_side_effect)
            return sock

        ws_rx = _make_fake_ws(WebSocketDisconnect(code=1001))

        hold_rx = asyncio.Event()

        async def _slow_receive() -> str:
            await hold_rx.wait()
            return "{}"

        ws_tx = _make_fake_ws(_slow_receive)

        async def _send_then_disconnect(_ws, payload) -> None:
            if payload.get("type") == "metrics":
                raise WebSocketDisconnect(code=1001)

        try:
            with (
                mock.patch.object(
                    ws_mod, "_build_init_payload", new=mock.AsyncMock(return_value={"type": "init"})
                ),
                mock.patch.object(ws_mod, "get_metrics_with_rates", return_value={}),
                mock.patch.object(ws_mod, "get_session_summary", return_value={}),
                mock.patch.object(ws_mod, "get_timer_resolution_status", return_value={}),
                mock.patch.object(ws_mod, "get_affinity_status", return_value={}),
                mock.patch.object(ws_mod, "check_mumu_health", return_value={}),
                mock.patch.object(ws_mod, "get_top_processes", return_value=[]),
                mock.patch.object(ws_mod, "get_auto_boost_payload", return_value={}),
                mock.patch.object(ws_mod, "get_tunnel_status", return_value={}),
            ):
                await ws_mod.websocket_endpoint(ws_rx)

                with mock.patch.object(ws_mod.manager, "send_to", side_effect=_send_then_disconnect):
                    await ws_mod.websocket_endpoint(ws_tx)

            await asyncio.sleep(0)
            gc.collect()
            await asyncio.sleep(0)

            self.assertGreaterEqual(ws_rx.receive_text.await_count, 1)
            self.assertGreaterEqual(ws_tx.receive_text.await_count, 1)
            self.assertEqual(loop_exceptions, [], f"Unexpected unretrieved task exceptions: {loop_exceptions}")
        finally:
            hold_rx.set()
            ws_mod.manager.disconnect(ws_rx)
            ws_mod.manager.disconnect(ws_tx)
            loop.set_exception_handler(old_handler)


if __name__ == "__main__":
    unittest.main()
