import asyncio
import copy
import re
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

DASHBOARD_DIR = str(Path(__file__).resolve().parents[1])
if DASHBOARD_DIR not in sys.path:
    sys.path.insert(0, DASHBOARD_DIR)

from backend.core.config import DEFAULT_ALERTS_CONFIG  # noqa: E402
from backend.services.discord_notifier import (  # noqa: E402
    DiscordNotifier,
    NotificationEvent,
    build_embed_payload,
)
from backend.services.maintenance import check_and_alert_ram_critical  # noqa: E402

_EMOJI_RE = re.compile(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]")


def _make_cfg(**alert_overrides) -> dict:
    alerts = copy.deepcopy(DEFAULT_ALERTS_CONFIG)
    alerts["discord_webhook_url"] = "https://discord.com/api/webhooks/123456/secret_token_9999"
    alerts.update(alert_overrides)
    return {"alerts": alerts}


class TestDiscordNotifier(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.loop = asyncio.get_running_loop()

    async def test_embed_zero_emojis_and_utc_timestamp(self) -> None:
        ev = NotificationEvent(
            event_type="mumu_crash",
            severity="critical",
            title="MuMu Instance Crash Detected",
            description="1 instance exited unexpectedly.",
            dedupe_key="mumu_crash:0:1",
            fields=[{"name": "Remaining", "value": "0 running", "inline": True}],
        )
        payload = build_embed_payload(ev)
        embed = payload["embeds"][0]
        self.assertEqual(embed["title"], "[CRITICAL] MuMu Instance Crash Detected")
        self.assertEqual(embed["color"], 0xEF4444)
        self.assertTrue(embed["timestamp"].endswith("Z"))
        self.assertIsNone(_EMOJI_RE.search(embed["title"]))
        self.assertIsNone(_EMOJI_RE.search(embed["description"]))

    async def test_queue_delivery_and_429_retry(self) -> None:
        attempts_seen: list[str] = []
        sleeps: list[float] = []

        def fake_sender(_url: str, payload: dict):
            title = payload["embeds"][0]["title"]
            attempts_seen.append(title)
            if len(attempts_seen) == 1:
                return 429, {"Retry-After": "0.05"}, '{"retry_after": 0.05}'
            return 204, {}, ""

        async def fake_sleep(sec: float):
            sleeps.append(sec)

        notifier = DiscordNotifier(
            config_provider=lambda: _make_cfg(),
            http_sender=fake_sender,
            event_logger=lambda *_args: None,
            broadcaster=None,
            sleep_fn=fake_sleep,
            retry_base_delay=0.01,
        )
        notifier.start(self.loop)
        try:
            ok = notifier.enqueue(
                NotificationEvent(
                    event_type="startup",
                    severity="info",
                    title="Core Online",
                    description="Booted",
                    dedupe_key="startup_online",
                )
            )
            self.assertTrue(ok)
            await asyncio.wait_for(notifier._queue.join(), timeout=2.0)
            self.assertEqual(len(attempts_seen), 2)
            self.assertEqual(sleeps, [0.05])
            hist = notifier.get_history()
            self.assertEqual(hist[0]["status"], "delivered")
            self.assertEqual(hist[0]["attempts"], 2)
        finally:
            await notifier.stop()

    async def test_5xx_retry_exhaustion_logs_failure(self) -> None:
        errors_logged: list[tuple[str, str]] = []

        def failing_sender(_url: str, _payload: dict):
            return 503, {}, "Service Unavailable"

        async def fake_sleep(_sec: float):
            return None

        notifier = DiscordNotifier(
            config_provider=lambda: _make_cfg(),
            http_sender=failing_sender,
            event_logger=lambda et, msg: errors_logged.append((et, msg)),
            broadcaster=None,
            sleep_fn=fake_sleep,
            retry_base_delay=0.0,
            max_attempts=3,
        )
        notifier.start(self.loop)
        try:
            notifier.enqueue(
                NotificationEvent(
                    event_type="drift",
                    severity="warning",
                    title="Hardening Drift",
                    description="MPO drifted",
                    dedupe_key="drift_mpo",
                )
            )
            await asyncio.wait_for(notifier._queue.join(), timeout=2.0)
            hist = notifier.get_history()
            self.assertEqual(hist[0]["status"], "failed")
            self.assertEqual(hist[0]["http_status"], 503)
            self.assertEqual(len(errors_logged), 1)
            self.assertEqual(errors_logged[0][0], "error")
        finally:
            await notifier.stop()

    async def test_per_entity_dedupe_allows_different_instances_and_blocks_duplicate(self) -> None:
        sent_titles: list[str] = []
        now = 1000.0

        def ok_sender(_url: str, payload: dict):
            sent_titles.append(payload["embeds"][0]["title"])
            return 204, {}, ""

        notifier = DiscordNotifier(
            config_provider=lambda: _make_cfg(min_alert_interval_seconds=60),
            http_sender=ok_sender,
            event_logger=lambda *_args: None,
            broadcaster=None,
            clock=lambda: now,
        )
        notifier.start(self.loop)
        try:
            r1 = notifier.enqueue(
                NotificationEvent(
                    event_type="watchdog_recovery",
                    severity="recovery",
                    title="Roblox Game Auto-Recovered",
                    description="Instance 1",
                    dedupe_key="watchdog_recovery:1",
                )
            )
            r2 = notifier.enqueue(
                NotificationEvent(
                    event_type="watchdog_recovery",
                    severity="recovery",
                    title="Roblox Game Auto-Recovered",
                    description="Instance 2",
                    dedupe_key="watchdog_recovery:2",
                )
            )
            r3 = notifier.enqueue(
                NotificationEvent(
                    event_type="watchdog_recovery",
                    severity="recovery",
                    title="Roblox Game Auto-Recovered",
                    description="Instance 1 repeat",
                    dedupe_key="watchdog_recovery:1",
                )
            )
            self.assertTrue(r1)
            self.assertTrue(r2)
            self.assertFalse(r3)
            await asyncio.wait_for(notifier._queue.join(), timeout=2.0)
            self.assertEqual(len(sent_titles), 2)
        finally:
            await notifier.stop()

    async def test_send_test_alert_bypasses_cooldown_and_disabled_toggle(self) -> None:
        sent: list[dict] = []

        def ok_sender(_url: str, payload: dict):
            sent.append(payload)
            return 200, {}, '{"ok": true}'

        notifier = DiscordNotifier(
            config_provider=lambda: _make_cfg(notify_on_startup=False),
            http_sender=ok_sender,
            event_logger=lambda *_args: None,
            broadcaster=None,
        )
        res = await notifier.send_test_alert()
        self.assertTrue(res["ok"])
        self.assertEqual(res["http_status"], 200)
        self.assertEqual(len(sent), 1)
        self.assertEqual(notifier.get_history()[0]["event_type"], "test")

    def test_ram_critical_fires_in_scheduled_and_auto_modes(self) -> None:
        dispatched: list[NotificationEvent] = []
        with patch("backend.services.maintenance.notifier.notify_sync", side_effect=lambda ev: dispatched.append(ev) or True):
            self.assertTrue(check_and_alert_ram_critical(92.5, 14 * 1024**3, 16 * 1024**3, "scheduled"))
            self.assertTrue(check_and_alert_ram_critical(91.0, 14 * 1024**3, 16 * 1024**3, "auto"))
            self.assertFalse(check_and_alert_ram_critical(85.0, 12 * 1024**3, 16 * 1024**3, "scheduled"))
        self.assertEqual(len(dispatched), 2)
        self.assertEqual(dispatched[0].event_type, "ram_critical")

    async def test_suppressed_history_not_flooded_and_error_sanitizes_webhook(self) -> None:
        now = 2000.0
        secret_url = "https://discord.com/api/webhooks/123456/RAWSECRETTOKEN9999"

        def leaky_failing_sender(_url: str, _payload: dict):
            return 0, {}, f"URLError contacting {secret_url}"

        async def no_sleep(_sec: float):
            return None

        n = DiscordNotifier(
            config_provider=lambda: {
                "alerts": {
                    **copy.deepcopy(DEFAULT_ALERTS_CONFIG),
                    "discord_webhook_url": secret_url,
                    "min_alert_interval_seconds": 60,
                }
            },
            http_sender=leaky_failing_sender,
            event_logger=lambda *_args: None,
            broadcaster=None,
            clock=lambda: now,
            sleep_fn=no_sleep,
            retry_base_delay=0.0,
            max_attempts=1,
        )
        n.start(self.loop)
        try:
            n.enqueue(
                NotificationEvent(
                    event_type="ram_critical",
                    severity="critical",
                    title="RAM Critical",
                    description="95%",
                    dedupe_key="ram_critical",
                )
            )
            await asyncio.wait_for(n._queue.join(), timeout=2.0)

            for _ in range(55):
                n.enqueue(
                    NotificationEvent(
                        event_type="ram_critical",
                        severity="critical",
                        title="RAM Critical",
                        description="95%",
                        dedupe_key="ram_critical",
                    )
                )

            hist = n.get_history()
            self.assertEqual(len(hist), 2)
            statuses = [h["status"] for h in hist]
            self.assertIn("failed", statuses)
            self.assertIn("suppressed", statuses)
            failed_entry = next(h for h in hist if h["status"] == "failed")
            self.assertNotIn("RAWSECRETTOKEN9999", failed_entry["error"])
            self.assertIn("****9999", failed_entry["error"])
        finally:
            await n.stop()


if __name__ == "__main__":
    unittest.main()
