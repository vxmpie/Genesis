import copy
import json
import os
import re
import sys
import tempfile
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

DASHBOARD_DIR = str(Path(__file__).resolve().parents[1])
if DASHBOARD_DIR not in sys.path:
    sys.path.insert(0, DASHBOARD_DIR)

from backend.core import auth as auth_mod  # noqa: E402
from backend.core.config import DEFAULT_CONFIG  # noqa: E402
from backend.services import discord_bot, discord_notifier, maintenance  # noqa: E402
from tests.test_security_and_api import _call_asgi  # noqa: E402

_EMOJI_RE = re.compile(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]")


class TestAutoDeepCleanEngine(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self._orig_maint = copy.deepcopy(maintenance.CONFIG.get("maintenance", {}))
        self._orig_mumu = copy.deepcopy(maintenance.CONFIG.get("mumu", {}))
        with maintenance._AUTO_CLEAN_STATE_LOCK:
            self._orig_state = dict(maintenance._auto_clean_state)
            maintenance._auto_clean_state.update(
                {
                    "last_auto_clean_at": None,
                    "last_auto_clean_freed_mb": 0.0,
                    "last_trigger": None,
                    "last_threshold_run_ts": 0.0,
                    "last_scheduled_date": None,
                    "last_vdi_compact_at": None,
                    "last_vdi_compact_result": None,
                    "is_cleaning": False,
                    "is_compacting_vdi": False,
                }
            )

    def tearDown(self) -> None:
        with maintenance.CONFIG_LOCK:
            maintenance.CONFIG["maintenance"] = copy.deepcopy(self._orig_maint)
            maintenance.CONFIG["mumu"] = copy.deepcopy(self._orig_mumu)
        with maintenance._AUTO_CLEAN_STATE_LOCK:
            maintenance._auto_clean_state.update(self._orig_state)

    def test_validate_clean_target_path_blocks_dangerous_and_symlink_escapes(self) -> None:
        blocked_paths = [
            "",
            "relative/path",
            r"\\server\share\cache",
            r"C:\\",
            r"C:\Temp",
            r"C:\Windows",
            r"C:\Windows\System32",
            r"C:\Windows\WinSxS",
            r"C:\Program Files",
            r"C:\Program Files (x86)",
            r"C:\Users",
            r"C:\Dev",
            os.path.expandvars(r"%USERPROFILE%"),
            os.path.expandvars(r"%USERPROFILE%\Desktop"),
            os.path.expandvars(r"%USERPROFILE%\Documents"),
            os.path.expandvars(r"%USERPROFILE%\Downloads"),
            os.path.expandvars(r"%LOCALAPPDATA%"),
            os.path.expandvars(r"%APPDATA%"),
        ]
        for path in blocked_paths:
            ok, _resolved, reason = maintenance.validate_clean_target_path(path)
            self.assertFalse(ok, f"Expected path to be blocked: {path!r}")
            self.assertTrue(reason)

        with tempfile.TemporaryDirectory() as tmpdir:
            safe_dir = Path(tmpdir) / "MyCustomApp" / "Cache"
            safe_dir.mkdir(parents=True)
            ok, resolved, reason = maintenance.validate_clean_target_path(str(safe_dir))
            self.assertTrue(ok, f"Expected safe path to pass, got: {reason}")
            self.assertEqual(os.path.normpath(resolved).lower(), os.path.normpath(os.path.realpath(safe_dir)).lower())

            escape_target = Path(tmpdir) / "OutsideSensitive"
            escape_target.mkdir()
            symlink_path = Path(tmpdir) / "MyCustomApp" / "LinkCache"
            try:
                os.symlink(escape_target, symlink_path, target_is_directory=True)
            except OSError:
                self.skipTest("Symlink creation requires elevated or developer privilege")

            ok_link, _res_link, link_reason = maintenance.validate_clean_target_path(str(symlink_path))
            self.assertFalse(ok_link, "Expected symlink escape to be blocked")
            self.assertIn("symlink", link_reason.lower())

    def test_discover_dynamic_cache_targets_filters_protected_and_excludes(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            cache_data = root / "CoolApp" / "Cache" / "Cache_Data"
            updater_pending = root / "foo-updater" / "pending"
            local_storage = root / "BrowserApp" / "User Data" / "Local Storage"
            indexed_db = root / "BrowserApp" / "User Data" / "IndexedDB"
            excluded_cache = root / "SkipMe" / "Code Cache"
            tiny_cache = root / "TinyApp" / "GPUCache"

            for d in (cache_data, updater_pending, local_storage, indexed_db, excluded_cache, tiny_cache):
                d.mkdir(parents=True, exist_ok=True)

            (cache_data / "blob.bin").write_bytes(b"x" * 200_000)
            (updater_pending / "update.exe").write_bytes(b"y" * 200_000)
            (local_storage / "0001.ldb").write_bytes(b"z" * 500_000)
            (indexed_db / "db.bin").write_bytes(b"w" * 500_000)
            (excluded_cache / "js.bin").write_bytes(b"q" * 500_000)
            (tiny_cache / "tiny.bin").write_bytes(b"t" * 1024)

            with patch.object(maintenance, "DEEP_CLEAN_TARGETS", []):
                discovered = maintenance.discover_dynamic_cache_targets(
                    roots=[str(root)],
                    min_mb=0.1,
                    excludes=["SkipMe"],
                    max_depth=4,
                )
            names = {item["name"] for item in discovered}
            paths = {os.path.normpath(item["path"]).lower() for item in discovered}

            self.assertIn(os.path.normpath(os.path.realpath(cache_data)).lower(), paths)
            self.assertIn(os.path.normpath(os.path.realpath(updater_pending)).lower(), paths)
            self.assertNotIn(os.path.normpath(os.path.realpath(local_storage)).lower(), paths)
            self.assertNotIn(os.path.normpath(os.path.realpath(indexed_db)).lower(), paths)
            self.assertNotIn(os.path.normpath(os.path.realpath(excluded_cache)).lower(), paths)
            self.assertNotIn(os.path.normpath(os.path.realpath(tiny_cache)).lower(), paths)
            self.assertTrue(all(item["source"] == "discovered" for item in discovered))
            self.assertTrue(any("CoolApp" in n for n in names))

    def test_deep_clean_execute_max_age_disabled_targets_and_cooldown(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            aged_dir = root / "AgedLogs" / "logs"
            dis_dir = root / "DisabledApp" / "Cache"
            aged_dir.mkdir(parents=True)
            dis_dir.mkdir(parents=True)

            old_file = aged_dir / "old.log"
            fresh_file = aged_dir / "fresh.log"
            old_slog = aged_dir / "old_session.slog"
            fresh_slog = aged_dir / "active_session.slog"
            dis_file = dis_dir / "junk.bin"

            old_file.write_bytes(b"a" * 2048)
            fresh_file.write_bytes(b"b" * 2048)
            old_slog.write_bytes(b"c" * 2048)
            fresh_slog.write_bytes(b"d" * 2048)
            dis_file.write_bytes(b"e" * 4096)

            now = time.time()
            five_days_ago = now - (5 * 86400)
            one_hour_ago = now - 3600
            os.utime(old_file, (five_days_ago, five_days_ago))
            os.utime(old_slog, (five_days_ago, five_days_ago))
            os.utime(fresh_file, (one_hour_ago, one_hour_ago))
            os.utime(fresh_slog, (one_hour_ago, one_hour_ago))

            mock_targets = [
                {
                    "name": "Test Aged Logs",
                    "category": "Logs",
                    "description": "Test aged logs",
                    "path": str(aged_dir),
                    "requires_service_stop": None,
                    "max_age_days": 3,
                    "skip_recent_slog_hours": 24,
                },
                {
                    "name": "Test Disabled Cache",
                    "category": "Cache",
                    "description": "Test disabled",
                    "path": str(dis_dir),
                    "requires_service_stop": None,
                },
            ]

            with maintenance.CONFIG_LOCK:
                maintenance.CONFIG["maintenance"]["disabled_clean_targets"] = ["Test Disabled Cache"]
                maintenance.CONFIG["maintenance"]["auto_discovery_enabled"] = False
                maintenance.CONFIG["maintenance"]["auto_deep_clean_threshold_mb"] = 100
                maintenance.CONFIG["maintenance"]["auto_deep_clean_min_free_gb"] = 30.0
                maintenance.CONFIG["maintenance"]["auto_deep_clean_cooldown_hours"] = 6

            with patch.object(maintenance, "DEEP_CLEAN_TARGETS", mock_targets), patch.object(
                maintenance, "_MEMORY_DMP", str(root / "nonexistent.dmp")
            ), patch.object(maintenance.subprocess, "run") as mock_sub:
                res = maintenance.deep_clean_execute(trigger="manual")

            self.assertFalse(old_file.exists())
            self.assertFalse(old_slog.exists())
            self.assertTrue(fresh_file.exists())
            self.assertTrue(fresh_slog.exists())
            self.assertTrue(dis_file.exists())
            self.assertEqual(res["total_deleted"], 2)
            self.assertTrue(mock_sub.called)

            with patch.object(
                maintenance,
                "deep_clean_preview",
                return_value=[{"name": "BigCache", "size_mb": 650.0, "enabled": True}],
            ), patch.object(
                maintenance,
                "deep_clean_execute",
                return_value={"total_freed_mb": 0.0, "total_deleted": 0, "details": []},
            ) as mock_exec, patch.object(
                maintenance.psutil,
                "disk_usage",
                return_value=SimpleNamespace(free=100 * (1024 ** 3)),
            ):
                t0 = 1_700_000_000.0
                first = maintenance.evaluate_threshold_auto_clean(now_ts=t0)
                self.assertIsNotNone(first)
                self.assertEqual(mock_exec.call_count, 1)

                second = maintenance.evaluate_threshold_auto_clean(now_ts=t0 + 1800.0)
                self.assertIsNone(second)
                self.assertEqual(mock_exec.call_count, 1)

                third = maintenance.evaluate_threshold_auto_clean(now_ts=t0 + (6 * 3600) + 10.0)
                self.assertIsNotNone(third)
                self.assertEqual(mock_exec.call_count, 2)

    def test_compact_stopped_mumu_vdis_skips_all_when_any_vm_running(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            mumu_root = Path(tmpdir) / "MuMuPlayer"
            vmm_exe = mumu_root / "nx_device" / "12.0" / "hypervisor" / "MuMuVMMManage.exe"
            vmm_exe.parent.mkdir(parents=True)
            vmm_exe.write_bytes(b"MZ")

            vm_running = mumu_root / "vms" / "MuMuPlayerGlobal-12.0-1"
            vm_stopped = mumu_root / "vms" / "MuMuPlayerGlobal-15.0-0"
            vm_running.mkdir(parents=True)
            vm_stopped.mkdir(parents=True)
            (vm_running / "data.vdi").write_bytes(b"1" * (2 * 1024 * 1024))
            (vm_stopped / "data.vdi").write_bytes(b"2" * (4 * 1024 * 1024))

            with maintenance.CONFIG_LOCK:
                maintenance.CONFIG["mumu"]["install_path"] = str(mumu_root)

            fake_proc = SimpleNamespace(
                info={
                    "name": "MuMuVMMHeadless.exe",
                    "cmdline": [
                        "MuMuVMMHeadless.exe",
                        "--comment",
                        "MuMuPlayerGlobal-12.0-1",
                        "--startvm",
                        "uuid-1",
                    ],
                }
            )

            with patch.object(maintenance.psutil, "process_iter", return_value=[fake_proc]), patch.object(
                maintenance, "_is_vdi_file_locked", return_value=False
            ), patch.object(maintenance.subprocess, "run") as mock_run, patch.object(
                maintenance, "add_event"
            ) as mock_event:
                res = maintenance.compact_stopped_mumu_vdis(trigger="manual")

            self.assertTrue(res["ok"])
            self.assertEqual(res["compacted_count"], 0)
            self.assertEqual(res["skipped_count"], 2)
            self.assertEqual(res["error_count"], 0)
            self.assertEqual(res["total_freed_mb"], 0.0)
            mock_run.assert_not_called()
            by_name = {v["vm_name"]: v for v in res["vms"]}
            self.assertEqual(by_name["MuMuPlayerGlobal-12.0-1"]["status"], "skipped_running")
            self.assertEqual(
                by_name["MuMuPlayerGlobal-12.0-1"]["reason"],
                "All MuMu VMs must be offline before VDI compact",
            )
            self.assertEqual(by_name["MuMuPlayerGlobal-15.0-0"]["status"], "skipped_running")
            self.assertEqual(
                by_name["MuMuPlayerGlobal-15.0-0"]["reason"],
                "All MuMu VMs must be offline before VDI compact",
            )
            mock_event.assert_called_once()
            self.assertEqual(mock_event.call_args[0][0], "clean")
            self.assertIn("all VMs must be offline", mock_event.call_args[0][1])

    def test_compact_stopped_mumu_vdis_compacts_when_all_offline(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            mumu_root = Path(tmpdir) / "MuMuPlayer"
            vmm_exe = mumu_root / "nx_device" / "12.0" / "hypervisor" / "MuMuVMMManage.exe"
            vmm_exe.parent.mkdir(parents=True)
            vmm_exe.write_bytes(b"MZ")

            vm_one = mumu_root / "vms" / "MuMuPlayerGlobal-12.0-1"
            vm_two = mumu_root / "vms" / "MuMuPlayerGlobal-15.0-0"
            vm_one.mkdir(parents=True)
            vm_two.mkdir(parents=True)
            (vm_one / "data.vdi").write_bytes(b"1" * (2 * 1024 * 1024))
            (vm_two / "data.vdi").write_bytes(b"2" * (4 * 1024 * 1024))

            with maintenance.CONFIG_LOCK:
                maintenance.CONFIG["mumu"]["install_path"] = str(mumu_root)

            def fake_sub_run(cmd, **kwargs):
                self.assertIn("creationflags", kwargs)
                vdi_arg = Path(cmd[3])
                vdi_arg.write_bytes(b"2" * (1 * 1024 * 1024))
                return SimpleNamespace(returncode=0, stdout="", stderr="")

            with patch.object(maintenance.psutil, "process_iter", return_value=[]), patch.object(
                maintenance, "_is_vdi_file_locked", return_value=False
            ), patch.object(maintenance.subprocess, "run", side_effect=fake_sub_run) as mock_run, patch.object(
                maintenance, "add_event"
            ) as mock_event:
                res = maintenance.compact_stopped_mumu_vdis(trigger="scheduled")

            self.assertTrue(res["ok"])
            self.assertEqual(res["compacted_count"], 2)
            self.assertEqual(res["skipped_count"], 0)
            self.assertEqual(res["error_count"], 0)
            self.assertEqual(res["total_freed_mb"], 4.0)
            self.assertEqual(mock_run.call_count, 2)
            by_name = {v["vm_name"]: v for v in res["vms"]}
            self.assertEqual(by_name["MuMuPlayerGlobal-12.0-1"]["status"], "compacted")
            self.assertEqual(by_name["MuMuPlayerGlobal-15.0-0"]["status"], "compacted")
            mock_event.assert_called_once()
            self.assertEqual(mock_event.call_args[0][0], "clean")

    def test_compact_stopped_mumu_vdis_logs_warning_on_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            mumu_root = Path(tmpdir) / "MuMuPlayer"
            vmm_exe = mumu_root / "nx_device" / "12.0" / "hypervisor" / "MuMuVMMManage.exe"
            vmm_exe.parent.mkdir(parents=True)
            vmm_exe.write_bytes(b"MZ")

            vm_offline = mumu_root / "vms" / "MuMuPlayerGlobal-15.0-0"
            vm_offline.mkdir(parents=True)
            (vm_offline / "data.vdi").write_bytes(b"2" * (4 * 1024 * 1024))

            with maintenance.CONFIG_LOCK:
                maintenance.CONFIG["mumu"]["install_path"] = str(mumu_root)

            failed_proc = SimpleNamespace(returncode=1, stdout="", stderr="VBoxManage error")
            with patch.object(maintenance.psutil, "process_iter", return_value=[]), patch.object(
                maintenance, "_is_vdi_file_locked", return_value=False
            ), patch.object(maintenance.subprocess, "run", return_value=failed_proc), patch.object(
                maintenance, "add_event"
            ) as mock_event:
                res = maintenance.compact_stopped_mumu_vdis(trigger="manual")

            self.assertFalse(res["ok"])
            self.assertEqual(res["compacted_count"], 0)
            self.assertEqual(res["error_count"], 1)
            self.assertEqual(res["vms"][0]["status"], "error")
            mock_event.assert_called_once()
            self.assertEqual(mock_event.call_args[0][0], "warning")
            self.assertIn("1 errors", mock_event.call_args[0][1])

    async def test_discord_clean_modes_and_notifier_toggle(self) -> None:
        self.assertEqual(discord_notifier.EVENT_TOGGLE_MAP["auto_clean"], "notify_on_auto_clean")
        self.assertIn("auto_clean", discord_notifier.EVENT_ICON_SHORTCODES)
        self.assertIn("notify_on_auto_clean", DEFAULT_CONFIG["alerts"])

        with patch.object(discord_bot, "get_current_lang", return_value="dual"), patch.object(
            discord_bot,
            "deep_clean_preview",
            return_value=[
                {
                    "name": "npm Cache",
                    "source": "builtin",
                    "size_mb": 42.5,
                    "file_count": 120,
                    "enabled": True,
                }
            ],
        ):
            preview_payload, _ = await discord_bot._execute_command_action("clean", {"mode": "preview"})
        self.assertIn("npm Cache", preview_payload["embeds"][0]["description"])
        self.assertIsNone(_EMOJI_RE.search(json.dumps(preview_payload)))

        with patch.object(discord_bot, "get_current_lang", return_value="dual"), patch.object(
            discord_bot,
            "deep_clean_execute",
            return_value={
                "total_freed_mb": 55.2,
                "total_deleted": 34,
                "details": [{"name": "User Temp", "freed_mb": 55.2, "deleted": 34}],
            },
        ):
            exec_payload, _ = await discord_bot._execute_command_action("clean", {"mode": "execute"})
        self.assertIn("55.2 MB", exec_payload["embeds"][0]["fields"][0]["value"])

        with patch.object(discord_bot, "get_current_lang", return_value="dual"), patch.object(
            discord_bot,
            "compact_stopped_mumu_vdis",
            return_value={
                "ok": True,
                "total_freed_mb": 120.0,
                "compacted_count": 1,
                "skipped_count": 1,
                "error_count": 0,
                "vms": [
                    {
                        "vm_name": "MuMuPlayerGlobal-15.0-0",
                        "status": "compacted",
                        "before_mb": 500.0,
                        "after_mb": 380.0,
                        "freed_mb": 120.0,
                    }
                ],
            },
        ):
            vdi_payload, _ = await discord_bot._execute_command_action("clean", {"mode": "compact_vdi"})
        self.assertIn("MuMuPlayerGlobal-15.0-0", vdi_payload["embeds"][0]["description"])

        with patch.object(discord_bot, "get_current_lang", return_value="dual"), patch.object(
            maintenance, "save_config"
        ), patch.object(
            discord_bot, "refresh_bridge_console", new_callable=AsyncMock, return_value={"ok": True}
        ):
            off_payload, _ = await discord_bot._execute_command_action("clean", {"mode": "auto_off"})
            self.assertIn("OFF", off_payload["embeds"][0]["title"])
            self.assertFalse(maintenance.CONFIG["maintenance"]["auto_deep_clean_enabled"])

            on_payload, _ = await discord_bot._execute_command_action("clean", {"mode": "auto_on"})
            self.assertIn("ON", on_payload["embeds"][0]["title"])
            self.assertTrue(maintenance.CONFIG["maintenance"]["auto_deep_clean_enabled"])

    async def test_rest_deep_clean_custom_targets_validation_and_status(self) -> None:
        with patch.object(auth_mod, "is_auth_enabled", return_value=False), patch.object(
            maintenance, "save_config"
        ):
            st_status, body_status = await _call_asgi("GET", "/api/deep-clean/status")
            self.assertEqual(st_status, 200)
            self.assertIn("auto_deep_clean_enabled", body_status)

            st_bad, body_bad = await _call_asgi(
                "POST",
                "/api/deep-clean/custom-targets",
                body={"name": "BadTarget", "path": r"C:\Windows\System32"},
            )
            self.assertEqual(st_bad, 400)
            self.assertIn("error", body_bad)

            with tempfile.TemporaryDirectory() as tmpdir:
                valid_dir = Path(tmpdir) / "MyApp" / "Cache"
                valid_dir.mkdir(parents=True)
                st_add, body_add = await _call_asgi(
                    "POST",
                    "/api/deep-clean/custom-targets",
                    body={"name": "MyCustomApp", "path": str(valid_dir), "max_age_days": 7},
                )
                self.assertEqual(st_add, 200)
                self.assertTrue(body_add["ok"])
                self.assertEqual(body_add["target"]["name"], "MyCustomApp")

                st_del, body_del = await _call_asgi("DELETE", "/api/deep-clean/custom-targets/MyCustomApp")
                self.assertEqual(st_del, 200)
                self.assertTrue(body_del["ok"])


if __name__ == "__main__":
    unittest.main()
