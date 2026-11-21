import asyncio
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

DASHBOARD_DIR = str(Path(__file__).resolve().parents[1])
if DASHBOARD_DIR not in sys.path:
    sys.path.insert(0, DASHBOARD_DIR)

from backend.services import discord_bot, intel_feeds  # noqa: E402

_EMOJI_RE = re.compile(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]")


class TestDiscordBot(unittest.IsolatedAsyncioTestCase):
    def test_slash_commands_topics_and_bilingual_builders(self) -> None:
        raw_cmds = json.dumps(discord_bot.SLASH_COMMANDS)
        self.assertIsNone(_EMOJI_RE.search(raw_cmds))
        self.assertEqual(discord_bot.GUILD_MOTHERSHIP_NAME, "Genesis Motherboard")

        for ch_name, topic in discord_bot.CHANNEL_TOPICS.items():
            self.assertNotIn("//", topic, f"Found // in topic for {ch_name}")
            self.assertIsNone(_EMOJI_RE.search(topic))
            self.assertIn("|", topic, f"Expected bilingual separator in topic for {ch_name}")

        for cat in (
            discord_bot.CATEGORY_HUD,
            discord_bot.CATEGORY_BRIDGE,
            discord_bot.CATEGORY_INTEL,
            discord_bot.CATEGORY_CREW,
            discord_bot.CATEGORY_COMMS,
        ):
            self.assertNotIn("//", cat)
            self.assertIsNone(_EMOJI_RE.search(cat))

        api_cmds = discord_bot.get_discord_api_commands()
        self.assertTrue(all(not k.startswith("_") for c in api_cmds for k in c))
        cmd_names = {c["name"] for c in api_cmds}
        self.assertTrue(
            {
                "bridge",
                "wall",
                "briefing",
                "lang",
                "status",
                "google",
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
                "feed-add",
                "feed-remove",
                "cmd-add",
                "cmd-remove",
                "run",
            }.issubset(cmd_names)
        )

        self.assertEqual(intel_feeds.tr("en", "Hello", "สวัสดี"), "Hello")
        self.assertEqual(intel_feeds.tr("th", "Hello", "สวัสดี"), "สวัสดี")
        self.assertEqual(intel_feeds.tr("dual", "Hello", "สวัสดี"), "Hello | สวัสดี")

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
            deck_dual = discord_bot.build_deck_payload("dual")
            deck_th = discord_bot.build_deck_payload("th")
            wall_en = discord_bot.build_command_wall_payload("en")
            status = discord_bot.build_status_payload("dual")
            mumu = discord_bot.build_mumu_payload("dual")
            procs = discord_bot.build_processes_payload("dual")
            hud = discord_bot.format_hud_channel_names()

        for obj in (deck_dual, deck_th, wall_en, status, mumu, procs, hud):
            self.assertIsNone(_EMOJI_RE.search(json.dumps(obj, ensure_ascii=False)))

        self.assertIn("แผงควบคุมหลักประจำยาน", deck_dual["embeds"][0]["title"])
        self.assertEqual(deck_th["embeds"][0]["title"], "[GENESIS MOTHERBOARD] แผงควบคุมหลักประจำยาน")
        self.assertEqual(wall_en["embeds"][0]["title"], "[COMMAND WALL] GENESIS MOTHERBOARD MASTER DIRECTORY")
        self.assertEqual(len(deck_dual["components"]), 4)
        self.assertEqual(len(hud), 4)

    def test_dynamic_feeds_lang_cycle_and_custom_commands_encapsulation(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_data = Path(tmpdir)
            tmp_discord = tmp_data / "discord"
            tmp_feeds = tmp_discord / "feeds.json"
            tmp_cmds = tmp_discord / "commands.json"
            tmp_station = tmp_discord / "station.json"
            tmp_notes = tmp_discord / "notes.json"

            legacy_station = tmp_data / "discord_station.json"
            tmp_data.mkdir(parents=True, exist_ok=True)
            legacy_station.write_text(json.dumps({"guild_id": "999"}), encoding="utf-8")

            with patch.object(intel_feeds, "DISCORD_DATA_DIR", tmp_discord), patch.object(
                intel_feeds, "FEEDS_REGISTRY_PATH", tmp_feeds
            ), patch.object(discord_bot, "DATA_DIR", tmp_data), patch.object(
                discord_bot, "DISCORD_DATA_DIR", tmp_discord
            ), patch.object(discord_bot, "STATION_STATE_PATH", tmp_station), patch.object(
                discord_bot, "COMMANDS_REGISTRY_PATH", tmp_cmds
            ), patch.object(discord_bot, "NOTES_PATH", tmp_notes):
                loaded_state = discord_bot.load_station_state()
                self.assertEqual(loaded_state.get("guild_id"), "999")
                self.assertFalse(legacy_station.exists())
                self.assertTrue(tmp_station.exists())

                self.assertEqual(discord_bot.get_current_lang(), "dual")
                self.assertEqual(discord_bot.cycle_station_lang(), "th")
                self.assertEqual(discord_bot.cycle_station_lang(), "en")
                self.assertEqual(discord_bot.cycle_station_lang(), "dual")

                add_res = intel_feeds.add_custom_rss_feed("ai", "Anthropic News", "https://example.com/rss.xml")
                self.assertEqual(add_res["action"], "added")
                reg = intel_feeds.list_feed_sources()
                self.assertTrue(any(f["name"] == "Anthropic News" for f in reg["ai"]))
                self.assertEqual(intel_feeds.remove_feed_source("ai", "Anthropic News")["removed"], 1)

                cmd_res = discord_bot.upsert_custom_command("Dash!", "Open Tailscale UI", "https://node.ts.net")
                self.assertEqual(cmd_res["command"]["name"], "dash")
                wall_payload = discord_bot.build_command_wall_payload("dual")
                self.assertIn("/run name:dash", json.dumps(wall_payload))
                self.assertTrue(discord_bot.delete_custom_command("dash"))

    def test_intel_feed_parsers_github_trending_and_cisa_kev(self) -> None:
        gh_html = """
        <article class="Box-row">
            <h2><a href="/owner/awesome-agent">owner / awesome-agent</a></h2>
            <p class="col-9 color-fg-muted my-1 pr-4">Autonomous \U0001F680 AI Agent toolkit</p>
            <span itemprop="programmingLanguage">Python</span>
        </article>
        """
        repos = intel_feeds.parse_github_trending_html(gh_html, limit=5)
        self.assertEqual(len(repos), 1)
        self.assertEqual(repos[0]["repo"], "owner/awesome-agent")
        self.assertEqual(repos[0]["lang"], "Python")
        self.assertEqual(repos[0]["desc"], "Autonomous AI Agent toolkit")

        cisa_stub = {
            "vulnerabilities": [
                {
                    "cveID": "CVE-2026-9999",
                    "vendorProject": "Apache",
                    "vulnerabilityName": "Remote Code Execution",
                    "dateAdded": "2026-11-20",
                }
            ]
        }
        with patch.object(intel_feeds, "_fetch_json", return_value=cisa_stub):
            cisa_lines = intel_feeds._collect_feed_lines(
                {"name": "CISA", "kind": "json_cisa_kev", "url": "https://cisa.test", "enabled": True},
                limit=3,
            )
        self.assertEqual(len(cisa_lines), 1)
        self.assertIn("CVE-2026-9999", cisa_lines[0])

    def test_google_and_antigravity_zero_overhead_delta_watcher(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_root = Path(tmpdir)
            ver_file = tmp_root / "version"
            skills_dir = tmp_root / "skills"
            skills_dir.mkdir(parents=True, exist_ok=True)
            (skills_dir / "antigravity_guide").mkdir()
            ver_file.write_text("44.9.1", encoding="utf-8")

            state: dict = {}
            intel_feeds._LAST_AGY_MTIME = -1.0
            deltas1, changed1 = intel_feeds.check_local_antigravity_delta_sync(state, ver_file, skills_dir)
            self.assertEqual(deltas1, [])
            self.assertTrue(changed1)
            self.assertEqual(state["google_watcher_baseline"]["agy_version"], "44.9.1")

            ver_file.write_text("45.0.0", encoding="utf-8")
            (skills_dir / "new_super_skill").mkdir()
            intel_feeds._LAST_AGY_MTIME = -1.0
            deltas2, changed2 = intel_feeds.check_local_antigravity_delta_sync(state, ver_file, skills_dir)
            self.assertTrue(changed2)
            self.assertEqual(len(deltas2), 2)
            self.assertEqual(deltas2[0]["new_version"], "45.0.0")
            self.assertIn("new_super_skill", deltas2[1]["added_skills"])

            rss_v1 = """<?xml version="1.0"?><rss><channel><item><title>Gemini 3.1 Released</title><link>https://blog.google/1</link></item></channel></rss>"""
            rss_v2 = """<?xml version="1.0"?><rss><channel><item><title>Gemini 4.0 Released</title><link>https://blog.google/2</link></item></channel></rss>"""

            with patch.object(
                intel_feeds,
                "load_feeds_registry",
                return_value={"google": [{"name": "Google AI Blog", "kind": "rss", "url": "https://blog.google/rss", "enabled": True}]},
            ):
                with patch.object(intel_feeds, "_fetch_text_with_etag", return_value=(200, rss_v1)):
                    ext_d1, ext_c1 = intel_feeds.check_google_external_feeds_delta_sync(state)
                self.assertEqual(ext_d1, [])
                self.assertTrue(ext_c1)

                with patch.object(intel_feeds, "_fetch_text_with_etag", return_value=(304, "")):
                    ext_304, _ = intel_feeds.check_google_external_feeds_delta_sync(state)
                self.assertEqual(ext_304, [])

                with patch.object(intel_feeds, "_fetch_text_with_etag", return_value=(200, rss_v2)):
                    ext_d2, ext_c2 = intel_feeds.check_google_external_feeds_delta_sync(state)
                self.assertTrue(ext_c2)
                self.assertEqual(len(ext_d2), 1)
                self.assertEqual(ext_d2[0]["title"], "Gemini 4.0 Released")
                self.assertEqual(ext_d2[0]["url"], "https://blog.google/2")

                with patch.object(intel_feeds, "_fetch_text", return_value=rss_v2):
                    g_board = intel_feeds.fetch_google_gemini_intel(limit=2, lang="dual")
                self.assertIsNone(_EMOJI_RE.search(json.dumps(g_board, ensure_ascii=False)))
                self.assertIn("GOOGLE, GEMINI MODELS & ANTIGRAVITY RADAR", g_board["embeds"][0]["title"])

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
        with patch.object(discord_bot, "get_current_lang", return_value="dual"), patch.object(
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
        self.assertIn("Reactor RAM Boost Executed", payload["embeds"][0]["title"])

        with patch.object(
            discord_bot,
            "load_custom_commands",
            return_value=[{"name": "ping", "description": "Test", "response": "Pong!"}],
        ):
            run_payload, _ = await discord_bot._execute_command_action("run", {"name": "ping"})
        self.assertEqual(run_payload["embeds"][0]["title"], "[MACRO] /ping")
        self.assertEqual(run_payload["embeds"][0]["description"], "Pong!")

    def test_epic_url_resolution_and_loot_deduplication(self) -> None:
        mock_element = {
            "title": "Mark of the Deep",
            "productSlug": None,
            "urlSlug": "2fd257a6cd80405a833f9004ff07993a",
            "offerMappings": [{"pageSlug": "mark-of-the-deep-f7dc08", "pageType": "productHome"}],
            "catalogNs": {"mappings": [{"pageSlug": "mark-of-the-deep-f7dc08", "pageType": "productHome"}]},
        }
        resolved = intel_feeds._resolve_epic_store_url(mock_element)
        self.assertEqual(resolved, "https://store.epicgames.com/en-US/p/mark-of-the-deep-f7dc08")

        fallback_el = {
            "title": "Mystery Game",
            "productSlug": None,
            "urlSlug": "2fd257a6cd80405a833f9004ff07993a",
            "offerMappings": [],
            "catalogNs": {"mappings": []},
        }
        self.assertEqual(intel_feeds._resolve_epic_store_url(fallback_el), "https://store.epicgames.com/en-US/free-games")

        mock_gp = [
            {
                "title": "Mark of the Deep (Epic Games) Giveaway",
                "worth": "$29.99",
                "gamerpower_url": "https://www.gamerpower.com/mark-of-the-deep-epic-games-giveaway",
            },
            {
                "title": "Distant Space (Steam) Giveaway",
                "worth": "$0.99",
                "gamerpower_url": "https://www.gamerpower.com/distant-space-steam-giveaway",
            },
        ]
        with patch.object(intel_feeds, "_fetch_json", return_value=mock_gp):
            gp_lines = intel_feeds._collect_feed_lines(
                {"kind": "json_gamerpower", "url": "https://www.gamerpower.com/api/giveaways?platform=pc&type=game"},
                limit=5,
            )
        self.assertEqual(len(gp_lines), 1)
        self.assertIn("Distant Space", gp_lines[0])
        self.assertNotIn("Mark of the Deep", gp_lines[0])

    async def test_readonly_board_overwrites_and_single_slot_popup_ttl(self) -> None:
        ow = discord_bot.build_readonly_board_overwrites("111", "222", "333")
        self.assertEqual(len(ow), 3)
        everyone_deny = int(ow[0]["deny"])
        everyone_allow = int(ow[0]["allow"])
        self.assertTrue(everyone_deny & discord_bot.PERMISSION_SEND_MESSAGES)
        self.assertTrue(everyone_deny & discord_bot.PERMISSION_ADD_REACTIONS)
        self.assertTrue(everyone_allow & discord_bot.PERMISSION_VIEW_CHANNEL)
        self.assertTrue(everyone_allow & discord_bot.PERMISSION_READ_MESSAGE_HISTORY)

        mock_state = {
            "command_deck_channel_id": "ch_bridge",
            "deck_message_id": "msg_board_main",
            "command_wall_channel_id": "ch_wall",
            "command_wall_message_id": "msg_wall_main",
            "dropzone_channel_id": "ch_datacore",
            "intel_channel_ids": {"loot": "ch_loot"},
            "intel_message_ids": {"loot": "msg_loot_main"},
            "active_popups": {},
        }

        deleted_paths: list[str] = []
        patch_seq = 0

        async def fake_discord_api(method: str, path: str, bot_token: str | None = None, **kwargs):
            nonlocal patch_seq
            if method == "DELETE":
                deleted_paths.append(path)
                return 204, {}, ""
            if method == "GET" and "/messages?limit=30" in path:
                return 200, [{"id": "msg_board_main", "type": 0}], ""
            if method == "PATCH" and path.endswith("/messages/@original"):
                patch_seq += 1
                return 200, {"id": f"popup_{patch_seq}"}, ""
            return 200, {}, ""

        svc = discord_bot.DiscordBotService(popup_ttl_sec=0.08)
        with patch.object(discord_bot, "load_station_state", return_value=mock_state), patch.object(
            discord_bot, "save_station_state"
        ), patch.object(discord_bot, "_discord_api", side_effect=fake_discord_api), patch.object(
            discord_bot, "_execute_command_action", return_value=({"embeds": [{"title": "[ONLINE] Test"}]}, None)
        ):
            await svc._handle_datacore_message(
                {"id": "stray_user_msg_1", "channel_id": "ch_bridge", "type": 0, "author": {"bot": False}},
                "fake_token",
            )
            self.assertIn("/channels/ch_bridge/messages/stray_user_msg_1", deleted_paths)

            await svc._handle_interaction(
                {
                    "id": "int_1",
                    "token": "tok_1",
                    "application_id": "app_1",
                    "type": 3,
                    "channel_id": "ch_bridge",
                    "message": {"id": "msg_board_main"},
                    "data": {"custom_id": "cmd:status"},
                },
                "fake_token",
            )
            first_popup = svc._active_popups.get("ch_bridge")
            self.assertIsNotNone(first_popup)

            await svc._handle_interaction(
                {
                    "id": "int_2",
                    "token": "tok_2",
                    "application_id": "app_1",
                    "type": 3,
                    "channel_id": "ch_bridge",
                    "message": {"id": "msg_board_main"},
                    "data": {"custom_id": "cmd:mumu"},
                },
                "fake_token",
            )
            await asyncio.sleep(0.02)
            self.assertIn(f"/channels/ch_bridge/messages/{first_popup}", deleted_paths)
            second_popup = svc._active_popups.get("ch_bridge")
            self.assertIsNotNone(second_popup)
            self.assertNotEqual(first_popup, second_popup)

            await asyncio.sleep(0.12)
            self.assertIn(f"/channels/ch_bridge/messages/{second_popup}", deleted_paths)
            self.assertNotIn("ch_bridge", svc._active_popups)


if __name__ == "__main__":
    unittest.main()
