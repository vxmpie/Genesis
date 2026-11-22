import copy
import sys
import time
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

DASHBOARD_DIR = str(Path(__file__).resolve().parents[1])
if DASHBOARD_DIR not in sys.path:
    sys.path.insert(0, DASHBOARD_DIR)

from backend.services import mumu_monitor as mm  # noqa: E402
from backend.services.mumu_monitor import (  # noqa: E402
    HELPER_DENYLIST,
    MuMuStateTracker,
    _build_device_game_fields,
    add_game_preset,
    classify_process_role,
    delete_game_preset,
    ensure_mumu_adb_connected,
    evaluate_watchdog_device_sync,
    get_emulator_allowlist,
    get_game_name_for_place_id,
    get_game_presets,
    get_instance_place_id,
    governor_instance_action,
    is_auto_rejoin_enabled,
    parse_mumu_manager_json,
    rejoin_preset_instances,
    resolve_instance_index_from_serial,
    set_auto_rejoin,
    set_instance_place_id,
    set_instance_username,
    update_game_preset,
)


class FakeClock:
    def __init__(self, start: float = 1000.0) -> None:
        self.now = start

    def __call__(self) -> float:
        return self.now

    def advance(self, seconds: float) -> float:
        self.now += seconds
        return self.now


class TestMuMuProcessClassification(unittest.TestCase):
    def test_cleaner_and_crash_reporter_never_counted_as_emulator(self) -> None:
        allow = get_emulator_allowlist(["MuMuNxDevice.exe", "MuMuNxMain.exe", "MuMuNxDeviceCleaner.exe"])
        self.assertNotIn("mumunxdevicecleaner.exe", allow)
        self.assertIn("mumunxdevicecleaner.exe", HELPER_DENYLIST)

        self.assertEqual(classify_process_role("MuMuNxDevice.exe", allow), "emulator")
        self.assertEqual(classify_process_role("MuMuNxMain.exe", allow), "launcher")
        self.assertEqual(classify_process_role("MuMuNxDeviceCleaner.exe", allow), "helper")
        self.assertEqual(classify_process_role("MuMuNxCrashReporter.exe", allow), "helper")
        self.assertEqual(classify_process_role("MuMuChecker.exe", allow), "helper")
        self.assertEqual(classify_process_role("MuMuNxDevice_custom_test.exe", allow), "other")

    def test_parse_mumu_manager_json_formats(self) -> None:
        raw_dict = '{"0": {"index": 0, "pid": 4412, "adb_port": 16384, "is_process_started": true}}'
        parsed = parse_mumu_manager_json(raw_dict)
        self.assertIn(4412, parsed)
        self.assertEqual(parsed[4412]["adb_port"], 16384)

        raw_single = '{"index": 1, "pid": 8890, "adb_port": 16416}'
        parsed_single = parse_mumu_manager_json(raw_single)
        self.assertIn(8890, parsed_single)


class TestMuMuStateTrackerSettleAndClassification(unittest.TestCase):
    def test_clean_disk_with_one_instance_triggers_zero_crash_alerts(self) -> None:
        clock = FakeClock()
        tracker = MuMuStateTracker(settle_seconds=4.0, clock=clock)

        self.assertEqual(tracker.observe({"1:100"}, launcher_running=True, cleaner_active=False), [])

        clock.advance(1.5)
        self.assertEqual(tracker.observe({"1:100"}, launcher_running=True, cleaner_active=True), [])

        clock.advance(3.0)
        self.assertEqual(tracker.observe({"1:100"}, launcher_running=True, cleaner_active=False), [])
        self.assertFalse(tracker.has_pending_settle)

    def test_clean_disk_closing_vm_temporarily_classified_as_intentional(self) -> None:
        clock = FakeClock()
        tracker = MuMuStateTracker(settle_seconds=4.0, clock=clock)

        tracker.observe({"1:100"}, launcher_running=True, cleaner_active=False)
        clock.advance(1.5)
        self.assertEqual(tracker.observe(set(), launcher_running=True, cleaner_active=True), [])

        clock.advance(4.2)
        events = tracker.observe(set(), launcher_running=True, cleaner_active=False)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["classification"], "intentional_close")
        self.assertEqual(events[0]["remaining_count"], 0)
        self.assertTrue(events[0]["saw_cleaner"])

    def test_staggered_close_2_to_1_to_0_reports_final_zero_not_stale_one(self) -> None:
        clock = FakeClock()
        tracker = MuMuStateTracker(settle_seconds=4.0, clock=clock)

        tracker.observe({"1:100", "2:200"}, launcher_running=True)

        clock.advance(1.5)
        ev1 = tracker.observe({"2:200"}, launcher_running=True)
        self.assertEqual(ev1, [])
        self.assertTrue(tracker.has_pending_settle)

        clock.advance(1.5)
        ev2 = tracker.observe(set(), launcher_running=False)
        self.assertEqual(ev2, [])
        self.assertTrue(tracker.has_pending_settle)

        clock.advance(4.1)
        ev3 = tracker.observe(set(), launcher_running=False)
        self.assertEqual(len(ev3), 1)
        self.assertEqual(ev3[0]["classification"], "intentional_close")
        self.assertEqual(ev3[0]["initial_count"], 2)
        self.assertEqual(ev3[0]["remaining_count"], 0)
        self.assertEqual(ev3[0]["lost_count"], 2)

    def test_single_instance_close_1_to_0_settles_with_zero_remaining(self) -> None:
        clock = FakeClock()
        tracker = MuMuStateTracker(settle_seconds=4.0, clock=clock)

        tracker.observe({"1:100"}, launcher_running=True)
        clock.advance(1.5)
        self.assertEqual(tracker.observe(set(), launcher_running=False), [])

        clock.advance(4.1)
        events = tracker.observe(set(), launcher_running=False)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["classification"], "intentional_close")
        self.assertEqual(events[0]["remaining_count"], 0)

    def test_unexpected_crash_while_launcher_stays_alive_fires_critical(self) -> None:
        clock = FakeClock()
        tracker = MuMuStateTracker(settle_seconds=4.0, clock=clock)

        tracker.observe({"1:100", "2:200"}, launcher_running=True)
        clock.advance(1.5)
        self.assertEqual(tracker.observe({"1:100"}, launcher_running=True), [])

        clock.advance(4.1)
        events = tracker.observe({"1:100"}, launcher_running=True)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["classification"], "crash")
        self.assertEqual(events[0]["remaining_count"], 1)
        self.assertEqual(events[0]["lost_count"], 1)

    def test_crash_reporter_overrides_launcher_exit_as_crash(self) -> None:
        clock = FakeClock()
        tracker = MuMuStateTracker(settle_seconds=4.0, clock=clock)

        tracker.observe({"1:100"}, launcher_running=True)
        clock.advance(1.5)
        tracker.observe(set(), launcher_running=False, crash_reporter_active=True)
        clock.advance(4.1)
        events = tracker.observe(set(), launcher_running=False, crash_reporter_active=False)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["classification"], "crash")
        self.assertEqual(events[0]["remaining_count"], 0)

    def test_governor_action_prevents_false_crash_alert(self) -> None:
        clock = FakeClock()
        tracker = MuMuStateTracker(settle_seconds=4.0, clock=clock)

        tracker.observe({"1:100"}, launcher_running=True)
        clock.advance(1.0)
        tracker.mark_governor_action()
        clock.advance(1.5)
        tracker.observe(set(), launcher_running=True)
        clock.advance(4.1)
        events = tracker.observe(set(), launcher_running=True)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["classification"], "intentional_close")
        self.assertTrue(events[0]["saw_governor"])


class TestAutoRejoinControl(unittest.TestCase):
    def setUp(self) -> None:
        self._orig_mumu = copy.deepcopy(mm.CONFIG.get("mumu", {}))
        self._orig_idle = dict(mm._mumu_consecutive_idle)
        self._orig_hb = copy.deepcopy(mm._bot_heartbeats)
        self._orig_live = copy.deepcopy(mm._instance_live_presence)
        self._orig_learned = dict(mm._instance_auto_learned_place)
        mm.CONFIG["mumu"] = {
            "install_path": "C:/Program Files/Netease/MuMuPlayer",
            "process_names": ["MuMuNxDevice.exe", "MuMuNxMain.exe"],
            "adb_base_port": 16384,
            "adb_port_step": 32,
            "max_instances": 10,
            "auto_reconnect": True,
        }
        mm._mumu_consecutive_idle.clear()
        mm._bot_heartbeats.clear()
        mm._instance_live_presence.clear()
        mm._instance_auto_learned_place.clear()

    def tearDown(self) -> None:
        mm.CONFIG["mumu"] = self._orig_mumu
        mm._mumu_consecutive_idle.clear()
        mm._mumu_consecutive_idle.update(self._orig_idle)
        mm._bot_heartbeats.clear()
        mm._bot_heartbeats.update(self._orig_hb)
        mm._instance_live_presence.clear()
        mm._instance_live_presence.update(self._orig_live)
        mm._instance_auto_learned_place.clear()
        mm._instance_auto_learned_place.update(self._orig_learned)

    def test_absent_key_defaults_to_enabled_and_serial_resolves_slot(self) -> None:
        self.assertEqual(resolve_instance_index_from_serial("127.0.0.1:16384", 1), 1)
        self.assertEqual(resolve_instance_index_from_serial("127.0.0.1:16416", 1), 2)
        self.assertTrue(is_auto_rejoin_enabled(1, "127.0.0.1:16384"))
        self.assertTrue(is_auto_rejoin_enabled(2, "127.0.0.1:16416"))

    def test_per_instance_off_only_blocks_that_instance(self) -> None:
        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            set_auto_rejoin(1, True)
            res = set_auto_rejoin(2, False)
        self.assertEqual(res["instance"], 2)
        self.assertFalse(res["enabled"])
        self.assertTrue(res["global"])
        self.assertTrue(is_auto_rejoin_enabled(1, "127.0.0.1:16384"))
        self.assertFalse(is_auto_rejoin_enabled(2, "127.0.0.1:16416"))
        self.assertFalse(
            is_auto_rejoin_enabled(resolve_instance_index_from_serial("127.0.0.1:16416", 1), "127.0.0.1:16416")
        )
        self.assertFalse(is_auto_rejoin_enabled(1, "127.0.0.1:16416"))

    def test_global_off_blocks_all_while_preserving_instance_flags(self) -> None:
        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            set_auto_rejoin(1, True)
            set_auto_rejoin(2, False)
            res = set_auto_rejoin(None, False)
        self.assertIsNone(res["instance"])
        self.assertFalse(res["global"])
        self.assertFalse(is_auto_rejoin_enabled(1, "127.0.0.1:16384"))
        self.assertFalse(is_auto_rejoin_enabled(2, "127.0.0.1:16416"))

        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            set_auto_rejoin(None, True)
        self.assertTrue(is_auto_rejoin_enabled(1, "127.0.0.1:16384"))
        self.assertFalse(is_auto_rejoin_enabled(2, "127.0.0.1:16416"))

    def test_reenable_resets_idle_counter_and_refreshes_heartbeat(self) -> None:
        mm._mumu_consecutive_idle["127.0.0.1:16416"] = 2
        mm._bot_heartbeats["127.0.0.1:16416"] = {"last_seen": 1.0}
        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            set_auto_rejoin(2, False)
            before_re = time.time()
            set_auto_rejoin(2, True)
        self.assertNotIn("127.0.0.1:16416", mm._mumu_consecutive_idle)
        self.assertGreaterEqual(mm._bot_heartbeats["127.0.0.1:16416"]["last_seen"], before_re)

    def test_watchdog_skips_stale_heartbeat_and_idle_when_disabled(self) -> None:
        adb = Path("adb.exe")
        serial = "127.0.0.1:16416"
        mm._bot_heartbeats[serial] = {"last_seen": 100.0}
        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            set_auto_rejoin(2, False)

        with patch.object(mm, "recover_roblox_instance") as mock_rec:
            status = evaluate_watchdog_device_sync(adb, serial, enum_idx=1, now=200.0)
            self.assertEqual(status, "skipped_disabled")
            mock_rec.assert_not_called()

        mm._bot_heartbeats.pop(serial, None)
        mm._mumu_consecutive_idle[serial] = 2
        with patch.object(mm, "recover_roblox_instance") as mock_rec, patch.object(
            mm.subprocess, "run", return_value=MagicMock(returncode=0, stdout="")
        ):
            status_idle = evaluate_watchdog_device_sync(adb, serial, enum_idx=1, now=200.0)
            self.assertEqual(status_idle, "skipped_disabled")
            self.assertEqual(mm._mumu_consecutive_idle[serial], 0)
            mock_rec.assert_not_called()

        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            set_auto_rejoin(2, True)
        mm._mumu_consecutive_idle[serial] = 2
        with patch.object(mm, "recover_roblox_instance", return_value=True) as mock_rec, patch.object(
            mm.subprocess, "run", return_value=MagicMock(returncode=0, stdout="")
        ):
            status_enabled = evaluate_watchdog_device_sync(adb, serial, enum_idx=1, now=200.0)
            self.assertEqual(status_enabled, "recovered_idle")
            mock_rec.assert_called_once()

    def test_manual_governor_restart_works_when_auto_rejoin_off(self) -> None:
        mm.CONFIG["mumu"]["instance_places"] = {"1": 98800969324557}
        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            set_auto_rejoin(1, False)
        with patch.object(mm, "find_mumu_adb", return_value=Path("adb.exe")), patch.object(
            mm, "_run_cmd", return_value=MagicMock(returncode=0)
        ) as mock_cmd, patch.object(mm, "add_event"):
            res = governor_instance_action(1, "restart_game")
        self.assertTrue(res["success"])
        self.assertEqual(mock_cmd.call_count, 2)

    def test_governor_restart_rejects_unconfigured_place_and_adb_failure(self) -> None:
        with patch.object(mm, "find_mumu_adb", return_value=Path("adb.exe")), patch.object(
            mm, "_run_cmd", return_value=MagicMock(returncode=0)
        ) as mock_cmd:
            res_empty = governor_instance_action(1, "restart_game")
        self.assertFalse(res_empty["success"])
        self.assertIn("No target Place ID", res_empty["error"])
        mock_cmd.assert_not_called()

        mm.CONFIG["mumu"]["instance_places"] = {"1": 98800969324557}
        with patch.object(mm, "find_mumu_adb", return_value=Path("adb.exe")), patch.object(
            mm,
            "_run_cmd",
            side_effect=[
                MagicMock(returncode=0, stdout="", stderr=""),
                MagicMock(returncode=1, stdout="", stderr="device offline"),
            ],
        ), patch.object(mm, "add_event"):
            res_fail = governor_instance_action(1, "restart_game")
        self.assertFalse(res_fail["success"])
        self.assertIn("device offline", res_fail["error"])


class TestGamePresetsAndPlacePriority(unittest.TestCase):
    def setUp(self) -> None:
        self._orig_mumu = copy.deepcopy(mm.CONFIG.get("mumu", {}))
        self._orig_cache = dict(mm._place_name_cache)
        self._orig_fail = dict(mm._place_name_fail_until)
        self._orig_live = copy.deepcopy(mm._instance_live_presence)
        self._orig_learned = dict(mm._instance_auto_learned_place)
        mm.CONFIG["mumu"] = {
            "install_path": "C:/Program Files/Netease/MuMuPlayer",
            "process_names": ["MuMuNxDevice.exe", "MuMuNxMain.exe"],
            "adb_base_port": 16384,
            "adb_port_step": 32,
            "max_instances": 10,
            "auto_reconnect": True,
            "instance_places": {},
            "instance_usernames": {},
            "game_presets": [],
        }
        mm._instance_live_presence.clear()
        mm._instance_auto_learned_place.clear()

    def tearDown(self) -> None:
        mm.CONFIG["mumu"] = self._orig_mumu
        mm._place_name_cache.clear()
        mm._place_name_cache.update(self._orig_cache)
        mm._place_name_fail_until.clear()
        mm._place_name_fail_until.update(self._orig_fail)
        mm._instance_live_presence.clear()
        mm._instance_live_presence.update(self._orig_live)
        mm._instance_auto_learned_place.clear()
        mm._instance_auto_learned_place.update(self._orig_learned)

    def test_preset_crud_validation_and_name_override(self) -> None:
        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            added = add_game_preset(93898234979111, "Net a Fish")
            self.assertEqual(added["preset"], {"place_id": 93898234979111, "name": "Net a Fish"})
            self.assertEqual(len(get_game_presets()), 1)

            with self.assertRaises(ValueError):
                add_game_preset(93898234979111, "Duplicate")
            for bad_id in (0, -5, True, "abc", None):
                with self.assertRaises(ValueError):
                    add_game_preset(bad_id, "Bad")

            updated = update_game_preset(93898234979111, 93898234979111, "Net a Fish V2")
            self.assertEqual(updated["preset"]["name"], "Net a Fish V2")
            self.assertEqual(get_game_name_for_place_id(93898234979111), "Net a Fish V2")

            with self.assertRaises(KeyError):
                update_game_preset(111111, 222222, "Missing")

            add_game_preset(98800969324557, "Storage Hunters")
            with self.assertRaises(ValueError):
                update_game_preset(93898234979111, 98800969324557, "Collision")

            deleted = delete_game_preset(93898234979111)
            self.assertEqual(deleted["deleted_place_id"], 93898234979111)
            self.assertEqual(len(get_game_presets()), 1)
            with self.assertRaises(KeyError):
                delete_game_preset(93898234979111)

    def test_configured_place_beats_live_presence_and_clear_works(self) -> None:
        mm._instance_live_presence["1"] = {
            "presence_status": "InGame",
            "place_id": 93898234979111,
            "game_name": "Net a Fish",
        }
        self.assertEqual(get_instance_place_id(1), 93898234979111)

        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            set_instance_place_id(1, 98800969324557)
        self.assertEqual(get_instance_place_id(1), 98800969324557)

        fields = _build_device_game_fields(1, "1_Marple")
        self.assertEqual(fields["configured_place_id"], 98800969324557)
        self.assertEqual(fields["target_place_id"], 98800969324557)
        self.assertEqual(fields["active_place_id"], 93898234979111)
        self.assertEqual(fields["live_game_name"], "Net a Fish")
        self.assertEqual(fields["target_game"], "Storage Hunters")

        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            set_instance_place_id(1, 0)
        self.assertNotIn("1", mm.CONFIG["mumu"]["instance_places"])
        self.assertNotIn("1", mm._instance_auto_learned_place)
        self.assertEqual(get_instance_place_id(1), 93898234979111)

    def test_clear_username_clears_stale_live_presence(self) -> None:
        mm.CONFIG["mumu"]["instance_usernames"]["1"] = "1_Marple"
        mm._instance_live_presence["1"] = {
            "username": "1_Marple",
            "presence_status": "InGame",
            "place_id": 93898234979111,
            "game_name": "Net a Fish",
        }
        with patch.object(mm, "save_config"), patch.object(mm, "add_event"):
            pres = set_instance_username(1, "")
        self.assertEqual(pres, {})
        self.assertNotIn("1", mm._instance_live_presence)
        self.assertNotIn("1", mm.CONFIG["mumu"]["instance_usernames"])

    def test_rejoin_preset_instances_connects_assigns_and_launches(self) -> None:
        mm.CONFIG["mumu"]["game_presets"] = [{"place_id": 93898234979111, "name": "Net a Fish"}]
        orig_cached = list(mm._cached_mumu_instances)
        try:
            mm._cached_mumu_instances = [
                {"type": "Emulator", "instance_index": 1, "adb_port": 16384},
                {"type": "Emulator", "instance_index": 2, "adb_port": 16416},
            ]
            with patch.object(mm, "find_mumu_adb", return_value=Path("adb.exe")), patch.object(
                mm, "_run_cmd", return_value=MagicMock(returncode=0, stdout="", stderr="")
            ) as mock_cmd, patch.object(mm, "save_config"), patch.object(mm, "add_event"):
                res_single = rejoin_preset_instances(93898234979111, 2)
                self.assertTrue(res_single["success"])
                self.assertEqual(res_single["instances"], [2])
                self.assertEqual(mm.CONFIG["mumu"]["instance_places"]["2"], 93898234979111)
                self.assertEqual(mock_cmd.call_count, 3)

                mock_cmd.reset_mock()
                res_all = rejoin_preset_instances(93898234979111, None)
                self.assertTrue(res_all["success"])
                self.assertEqual(res_all["instances"], [1, 2])
                self.assertEqual(mm.CONFIG["mumu"]["instance_places"]["1"], 93898234979111)
                self.assertEqual(mock_cmd.call_count, 6)
        finally:
            mm._cached_mumu_instances = orig_cached

    def test_ensure_mumu_adb_connected_connects_missing_ports(self) -> None:
        orig_cached = list(mm._cached_mumu_instances)
        try:
            mm._cached_mumu_instances = [
                {"type": "Emulator", "instance_index": 1, "adb_port": 16384},
                {"type": "Emulator", "instance_index": 2, "adb_port": 16416},
            ]
            with patch.object(
                mm, "get_mumu_adb_devices", return_value=["127.0.0.1:16384"]
            ), patch.object(
                mm, "_run_cmd", return_value=MagicMock(returncode=0)
            ) as mock_cmd:
                ensure_mumu_adb_connected(Path("adb.exe"))
            mock_cmd.assert_called_once_with(
                ["adb.exe", "connect", "127.0.0.1:16416"], timeout=4
            )
        finally:
            mm._cached_mumu_instances = orig_cached


if __name__ == "__main__":
    unittest.main()
