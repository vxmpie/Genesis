import ast
import unittest
from pathlib import Path

DASHBOARD_DIR = Path(__file__).resolve().parent.parent
SERVICES_DIR = DASHBOARD_DIR / "backend" / "services"


# --- Subprocess & Windowless Startup Tests ---
class TestSilentExecution(unittest.TestCase):
    def test_all_service_subprocesses_use_creationflags(self) -> None:
        target_files = [
            "maintenance.py",
            "mumu_monitor.py",
            "telemetry.py",
            "tunnel.py",
        ]
        missing: list[str] = []

        for filename in target_files:
            path = SERVICES_DIR / filename
            source = path.read_text(encoding="utf-8")
            tree = ast.parse(source, filename=str(path))
            for node in ast.walk(tree):
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                    if (
                        isinstance(node.func.value, ast.Name)
                        and node.func.value.id == "subprocess"
                        and node.func.attr in ("run", "Popen")
                    ):
                        kw_names = {kw.arg for kw in node.keywords if kw.arg}
                        if "creationflags" not in kw_names:
                            missing.append(f"{filename}:{node.lineno} ({node.func.attr})")

        self.assertEqual(missing, [], f"Missing creationflags in subprocess calls: {missing}")

    def test_start_hidden_vbs_contract(self) -> None:
        vbs_path = DASHBOARD_DIR / "start_hidden.vbs"
        self.assertTrue(vbs_path.exists(), "start_hidden.vbs must exist")
        content = vbs_path.read_text(encoding="utf-8")
        self.assertIn("start.bat", content)
        self.assertIn("--silent", content)
        self.assertIn(", 0, False", content)

    def test_start_bat_silent_and_log_rotation(self) -> None:
        bat_path = DASHBOARD_DIR / "start.bat"
        content = bat_path.read_text(encoding="utf-8")
        self.assertIn("--silent", content)
        self.assertIn("dashboard_server.log", content)
        self.assertIn("10485760", content)
        self.assertIn("stop_dashboard.flag", content)
        self.assertIn("venv\\Scripts\\python.exe server.py", content)

    def test_install_startup_task_uses_wscript_and_unlimited_runtime(self) -> None:
        installer_path = DASHBOARD_DIR / "install_startup_task.bat"
        content = installer_path.read_text(encoding="utf-8")
        self.assertIn("wscript.exe", content)
        self.assertIn("start_hidden.vbs", content)
        self.assertIn("New-TimeSpan -Days 0", content)
        self.assertIn("-AllowStartIfOnBatteries", content)
        self.assertIn("-DontStopIfGoingOnBatteries", content)
        self.assertIn("-MultipleInstances IgnoreNew", content)


if __name__ == "__main__":
    unittest.main()
