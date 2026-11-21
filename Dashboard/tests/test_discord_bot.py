import json
import re
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

DASHBOARD_DIR = str(Path(__file__).resolve().parents[1])
if DASHBOARD_DIR not in sys.path:
    sys.path.insert(0, DASHBOARD_DIR)

from backend.services import discord_bot, intel_feeds  # noqa: E402

_EMOJI_RE = re.compile(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]")


class TestDiscordBot(unittest.IsolatedAsyncioTestCase):
    def test_slash_commands_and_builders_are_zero_emoji(self) -> None:
        raw_cmds = json.dumps(discord_bot.SLASH_COMMANDS)
        self.assertIsNone(_EMOJI_RE.search(raw_cmds))
        cmd_names = {c["name"] for c in discord_bot.SLASH_COMMANDS}
        self.assertTrue(
            {
                "bridge",
                "briefing",
                "status",
                "ai",
                "tech",
                "world",
                "loot",
                "boost",
                "mumu",
                "recover",
                "screenshot",
                "processes",
                "clean",
                "purge",
                "log",
                "note",
            }.issubset(cmd_names)
        )

        with patch.object(
            discord_bot,
            "get_system_metrics",
            return_value={
                "cpu": {"total_percent": 18.4, "frequency_ghz": 3.45},
                "ram": {
                    "used_gb": 11.2,
                    "total_gb": 31.7,
                    "percent": 35.3,
                    "active_gb": 8.0,
                    "standby_gb": 2.1,
                    "free_gb": 20.5,
                },
                "gpu": {
                    "available": True,
                    "name": "RTX 3050",
                    "utilization_percent": 12,
                    "temperature_c": 44,
                    "memory_used_mb": 512,
                    "memory_total_mb": 4096,
                },
                "network": {"roblox_ping_ms": 23.0},
                "storage": {"c_drive": {"free_gb": 325.9, "total_gb": 476.9, "percent": 31.7}},
            },
        ), patch.object(
            discord_bot,
            "check_mumu_health",
            return_value={
                "count": 1,
                "devices": [
                    {
                        "index": 1,
                        "pid": 4321,
                        "username": "TestUser",
                        "presence_status": "InGame",
                        "active_game": "Test Experience",
                        "ram_mb": 1450.0,
                        "cpu_percent": 9.5,
                        "uptime": "1h15m",
                        "adb_port": 16384,
                        "auto_rejoin": True,
                    }
                ],
                "vm_disk": [{"instance": 1, "used_pct": 42, "used_gb": 8.4, "total_gb": 20.0}],
            },
        ), patch.object(
            discord_bot,
            "get_tunnel_status",
            return_value={"provider": "tailscale", "status": "online", "tunnel_url": "https://node.ts.net"},
        ), patch.object(
            discord_bot,
            "get_session_summary",
            return_value={
                "uptime_seconds": 3665,
                "session_boosts": 3,
                "total_boosts": 12,
                "net_recoveries": 0,
                "standby_guard": {"purges": 1, "reclaimed_gb": 2.4},
            },
        ), patch.object(
            discord_bot,
            "get_cached_hud_sensors_sync",
            return_value=(
                {"ok": True, "temp_c": 31.2, "humidity": 65.0},
                {"ok": True, "btc_usd": 95400.0, "usd_thb": 34.5},
            ),
        ), patch.object(
            discord_bot,
            "get_top_processes",
            return_value=[{"pid": 100, "name": "MuMuNxDevice.exe", "ram_mb": 1450.0, "protected": True}],
        ):
            deck = discord_bot.build_deck_payload()
            status = discord_bot.build_status_payload()
            mumu = discord_bot.build_mumu_payload()
            procs = discord_bot.build_processes_payload()
            hud = discord_bot.format_hud_channel_names()

        for obj in (deck, status, mumu, procs, hud):
            self.assertIsNone(_EMOJI_RE.search(json.dumps(obj)))

        self.assertEqual(len(hud), 4)
        self.assertTrue(all(len(name) <= 100 for name in hud))
        self.assertIn("CORE: 18%", hud[0])
        self.assertIn("FLEET: 1 ONLINE", hud[1])
        self.assertIn("325.9GB FREE", hud[2])
        self.assertIn("BKK: 31C | BTC: $95.4K", hud[3])
        self.assertEqual(len(deck["components"]), 3)
        self.assertEqual(mumu["embeds"][0]["title"], "[ACTIVE] MuMu Drone Fleet (1 Online)")
        self.assertIn("MuMuNxDevice.exe", procs["embeds"][0]["description"])

    def test_intel_feed_parsers_and_emoji_stripping(self) -> None:
        rss_xml = """<?xml version="1.0" encoding="UTF-8"?>
        <rss><channel>
            <item><title>AI Breakthrough \U0001F680 Released</title><link>https://example.com/1</link></item>
        </channel></rss>"""
        parsed_rss = intel_feeds.parse_rss_or_atom_xml(rss_xml, limit=5)
        self.assertEqual(len(parsed_rss), 1)
        self.assertEqual(parsed_rss[0]["title"], "AI Breakthrough Released")
        self.assertIsNone(_EMOJI_RE.search(parsed_rss[0]["title"]))

        atom_xml = """<?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
            <entry><title>Quantum Chip Update</title><link href="https://example.com/atom"/></entry>
        </feed>"""
        parsed_atom = intel_feeds.parse_rss_or_atom_xml(atom_xml, limit=5)
        self.assertEqual(len(parsed_atom), 1)
        self.assertEqual(parsed_atom[0]["url"], "https://example.com/atom")

        with patch.object(
            intel_feeds,
            "_fetch_json",
            return_value=[{"paper": {"id": "2501.0001", "title": "Paper \U0001F525 One", "upvotes": 42}}],
        ), patch.object(intel_feeds, "_fetch_text", return_value=rss_xml):
            ai_payload = intel_feeds.fetch_ai_cortex_intel(limit=3)
        self.assertIsNone(_EMOJI_RE.search(json.dumps(ai_payload)))
        self.assertEqual(ai_payload["embeds"][0]["title"], "// ORBITAL AI & SINGULARITY CORTEX")

    def test_encode_multipart_form_data(self) -> None:
        png_stub = b"\x89PNG\r\n\x1a\nFAKEPNG"
        body, ctype = discord_bot.encode_multipart_form_data(
            {"embeds": [{"title": "Snap"}]},
            [("files[0]", "snap.png", png_stub)],
        )
        self.assertIn("multipart/form-data; boundary=", ctype)
        self.assertIn(b'name="payload_json"', body)
        self.assertIn(b'filename="snap.png"', body)
        self.assertIn(png_stub, body)

    async def test_execute_command_actions(self) -> None:
        with patch.object(
            discord_bot,
            "ram_boost",
            return_value={
                "freed_mb": 420.5,
                "ram_before_percent": 65.0,
                "ram_after_percent": 52.0,
                "standby_purged": True,
                "processes_trimmed": 45,
                "freed_temp_mb": 12.0,
                "deleted_temp_files": 5,
                "duration_ms": 180.0,
            },
        ):
            payload, files = await discord_bot._execute_command_action("boost")
        self.assertIsNone(files)
        self.assertEqual(payload["embeds"][0]["title"], "[OK] Reactor RAM Boost Executed")

        with patch.object(
            discord_bot,
            "capture_host_screenshot_png",
            return_value=(b"\x89PNG\r\n\x1a\nHOST", "Mothership Bridge Display (genesis)"),
        ):
            snap_payload, snap_files = await discord_bot._execute_command_action(
                "screenshot_host", {"target": "host"}
            )
        self.assertIsNotNone(snap_files)
        self.assertEqual(len(snap_files), 1)
        self.assertEqual(snap_payload["embeds"][0]["title"], "[SENSOR] Mothership Bridge Display (genesis)")

        with patch.object(
            discord_bot,
            "fetch_ai_cortex_intel",
            return_value={"embeds": [{"title": "// ORBITAL AI & SINGULARITY CORTEX"}]},
        ):
            ai_res, _ = await discord_bot._execute_command_action("ai")
        self.assertEqual(ai_res["embeds"][0]["title"], "// ORBITAL AI & SINGULARITY CORTEX")


if __name__ == "__main__":
    unittest.main()
