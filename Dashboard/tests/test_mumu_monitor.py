import sys
import unittest
from pathlib import Path

DASHBOARD_DIR = str(Path(__file__).resolve().parents[1])
if DASHBOARD_DIR not in sys.path:
    sys.path.insert(0, DASHBOARD_DIR)

from backend.services.mumu_monitor import (  # noqa: E402
    HELPER_DENYLIST,
    MuMuStateTracker,
    classify_process_role,
    get_emulator_allowlist,
    parse_mumu_manager_json,
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


if __name__ == "__main__":
    unittest.main()
