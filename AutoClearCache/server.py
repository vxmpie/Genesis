"""
Genesis Dashboard — Real-Time System Monitor & Auto-Boost Engine
Backend: FastAPI + WebSocket + Win32 API (EmptyWorkingSet + NtSetSystemInformation)

Fable 5 Maintenance Suite:
  Module 1: Standby Memory Purge + RAM Breakdown
  Module 2: Hardening Drift Detector (VBS / MPO / Hypervisor)
  Module 3: In-VM Disk Sentinel (ADB → MuMu /data)
  Module 4: Deep Clean Engine (extended targets + dry-run)
  Module 5: Anti-EcoQoS + Background Hog Detector
  Module 6: Growth Tracker (MuMu vms/ folder snapshots)
  Module 7: Defender Maintenance (Definition age + Quick Scan + Downloads sweep)
"""

import asyncio
import ctypes
import ctypes.wintypes
import json
import os
import subprocess
import tempfile
import time
import winreg
from contextlib import asynccontextmanager
from datetime import datetime, date
from pathlib import Path

import psutil
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

# ---------------------------------------------------------------------------
# Paths & Config
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
DATA_DIR = BASE_DIR / "data"
HISTORY_PATH = DATA_DIR / "history.json"
GROWTH_PATH = DATA_DIR / "growth.json"

DATA_DIR.mkdir(exist_ok=True)


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        return {
            "server": {"host": "0.0.0.0", "port": 7700},
            "auto_boost": {
                "enabled": True,
                "threshold_percent": 85,
                "mode": "auto",
                "interval_minutes": 10,
                "protected_processes": [
                    "csrss.exe", "lsass.exe", "smss.exe", "wininit.exe",
                    "System", "StarDesk.exe", "parsecd.exe", "dwm.exe"
                ]
            },
            "mumu": {
                "install_path": "C:/Program Files/Netease/MuMuPlayer",
                "process_names": ["MuMuNxDevice.exe", "MuMuNxMain.exe"],
                "adb_base_port": 16384,
                "adb_port_step": 32,
                "max_instances": 10,
            },
            "metrics": {"update_interval_ms": 1000, "history_length": 60},
            "maintenance": {
                "deep_clean_on_boost": False,
                "vm_disk_warn_pct": 85,
                "vm_disk_critical_pct": 90,
                "vm_auto_trim": True,
                "defender_scan_hour": 4,
                "downloads_sweep_minutes": 30,
                "growth_snapshot_hours": 6,
                "drift_check_hours": 6,
            },
        }
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def save_config(cfg: dict):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)


CONFIG = load_config()

# Ensure maintenance key exists for upgrades from older config
if "maintenance" not in CONFIG:
    CONFIG["maintenance"] = {
        "deep_clean_on_boost": False,
        "vm_disk_warn_pct": 85,
        "vm_disk_critical_pct": 90,
        "vm_auto_trim": True,
        "defender_scan_hour": 4,
        "downloads_sweep_minutes": 30,
        "growth_snapshot_hours": 6,
        "drift_check_hours": 6,
    }
    save_config(CONFIG)

# ---------------------------------------------------------------------------
# Event History
# ---------------------------------------------------------------------------
MAX_HISTORY = 200


def _load_history() -> list:
    if HISTORY_PATH.exists():
        try:
            with open(HISTORY_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return []
    return []


def _save_history(events: list):
    with open(HISTORY_PATH, "w", encoding="utf-8") as f:
        json.dump(events[-MAX_HISTORY:], f, indent=2, ensure_ascii=False)


event_history: list = _load_history()


def add_event(event_type: str, message: str):
    entry = {
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "type": event_type,
        "message": message,
    }
    event_history.append(entry)
    if len(event_history) > MAX_HISTORY:
        del event_history[: len(event_history) - MAX_HISTORY]
    _save_history(event_history)
    return entry


# ===========================================================================
# MODULE 1: Standby Memory Purge + RAM Boost via Win32 API
# ===========================================================================
_psapi = ctypes.WinDLL("psapi")
_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
_ntdll = ctypes.WinDLL("ntdll")

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_SET_QUOTA = 0x0100
PROCESS_SET_INFORMATION = 0x0200

_kernel32.OpenProcess.restype = ctypes.wintypes.HANDLE
_kernel32.OpenProcess.argtypes = [
    ctypes.wintypes.DWORD,
    ctypes.wintypes.BOOL,
    ctypes.wintypes.DWORD,
]
_kernel32.CloseHandle.argtypes = [ctypes.wintypes.HANDLE]

_psapi.EmptyWorkingSet.restype = ctypes.wintypes.BOOL
_psapi.EmptyWorkingSet.argtypes = [ctypes.wintypes.HANDLE]


def purge_standby_list() -> bool:
    """Purge the system Standby memory list via NtSetSystemInformation.
    
    SystemMemoryListInformation = 0x50 (80)
    MemoryPurgeStandbyList = 4
    Requires SeProfileSingleProcessPrivilege (Admin).
    """
    try:
        command = ctypes.c_ulong(4)  # MemoryPurgeStandbyList
        status = _ntdll.NtSetSystemInformation(
            0x50,  # SystemMemoryListInformation
            ctypes.byref(command),
            ctypes.sizeof(command),
        )
        return status == 0  # STATUS_SUCCESS (NTSTATUS)
    except Exception:
        return False


def get_ram_breakdown() -> dict:
    """Return RAM breakdown: Active (In Use), Standby, Free.
    
    Standby = Available - Free (the part Windows caches but can release)
    Active = Total - Available
    """
    mem = psutil.virtual_memory()
    # psutil gives us: total, available, used, free
    # Windows "Standby" = Available - Free
    total_gb = mem.total / (1024 ** 3)
    available_gb = mem.available / (1024 ** 3)
    free_gb = mem.free / (1024 ** 3) if hasattr(mem, 'free') else 0
    active_gb = (mem.total - mem.available) / (1024 ** 3)
    standby_gb = available_gb - free_gb

    return {
        "total_gb": round(total_gb, 2),
        "active_gb": round(active_gb, 2),
        "standby_gb": round(max(standby_gb, 0), 2),
        "free_gb": round(free_gb, 2),
        "available_gb": round(available_gb, 2),
    }


def _get_protected_names() -> set:
    names = set()
    for n in CONFIG.get("auto_boost", {}).get("protected_processes", []):
        names.add(n.lower())
    return names


# ===========================================================================
# MODULE 4: Deep Clean Engine (extended targets + dry-run)
# ===========================================================================
DEEP_CLEAN_TARGETS = [
    {
        "name": "User Temp",
        "path": tempfile.gettempdir(),
        "requires_service_stop": None,
    },
    {
        "name": "Windows Temp",
        "path": os.path.expandvars(r"%WINDIR%\Temp"),
        "requires_service_stop": None,
    },
    {
        "name": "CrashDumps",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\CrashDumps"),
        "requires_service_stop": None,
    },
    {
        "name": "Roblox Logs",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\Roblox\logs"),
        "requires_service_stop": None,
    },
    {
        "name": "Windows Update Cache",
        "path": r"C:\Windows\SoftwareDistribution\Download",
        "requires_service_stop": "wuauserv",
    },
    {
        "name": "Memory Dumps",
        "path": r"C:\Windows\Minidump",
        "requires_service_stop": None,
    },
    {
        "name": "Thumbnail Cache",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Windows\Explorer"),
        "file_pattern": "*.db",
        "requires_service_stop": None,
    },
    {
        "name": "Chrome Cache",
        "path": os.path.expandvars(
            r"%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache"
        ),
        "requires_service_stop": None,
    },
    {
        "name": "Edge Cache",
        "path": os.path.expandvars(
            r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache"
        ),
        "requires_service_stop": None,
    },
]

# Add MEMORY.DMP as a single file target
_memory_dmp = r"C:\Windows\MEMORY.DMP"


def deep_clean_preview() -> list:
    """Scan all targets and return estimated sizes without deleting anything."""
    preview = []
    for target in DEEP_CLEAN_TARGETS:
        folder = target["path"]
        if not os.path.exists(folder):
            continue
        total_size = 0
        file_count = 0
        pattern = target.get("file_pattern")
        try:
            for root, dirs, files in os.walk(folder):
                for f in files:
                    if pattern and not f.endswith(pattern.replace("*", "")):
                        continue
                    fp = os.path.join(root, f)
                    try:
                        total_size += os.path.getsize(fp)
                        file_count += 1
                    except OSError:
                        continue
        except PermissionError:
            continue
        if file_count > 0:
            preview.append({
                "name": target["name"],
                "path": folder,
                "file_count": file_count,
                "size_mb": round(total_size / (1024 * 1024), 1),
                "requires_service_stop": target.get("requires_service_stop"),
            })

    # Single file: MEMORY.DMP
    if os.path.exists(_memory_dmp):
        try:
            sz = os.path.getsize(_memory_dmp)
            preview.append({
                "name": "MEMORY.DMP",
                "path": _memory_dmp,
                "file_count": 1,
                "size_mb": round(sz / (1024 * 1024), 1),
                "requires_service_stop": None,
            })
        except OSError:
            pass

    # MuMu logs
    mumu_path = Path(CONFIG.get("mumu", {}).get("install_path", ""))
    if mumu_path.exists():
        vms_dir = mumu_path / "vms"
        if vms_dir.exists():
            total_size = 0
            file_count = 0
            for log_file in vms_dir.rglob("*.log"):
                try:
                    total_size += log_file.stat().st_size
                    file_count += 1
                except OSError:
                    continue
            if file_count > 0:
                preview.append({
                    "name": "MuMu Logs",
                    "path": str(vms_dir),
                    "file_count": file_count,
                    "size_mb": round(total_size / (1024 * 1024), 1),
                    "requires_service_stop": None,
                })

    return preview


def deep_clean_execute(targets: list | None = None) -> dict:
    """Execute deep clean on specified targets (or all if None)."""
    preview = deep_clean_preview()
    if targets:
        preview = [p for p in preview if p["name"] in targets]

    total_freed = 0
    total_deleted = 0
    results = []

    for item in preview:
        service = item.get("requires_service_stop")
        service_was_running = False

        # Stop service if needed
        if service:
            try:
                subprocess.run(
                    ["net", "stop", service],
                    capture_output=True, timeout=15
                )
                service_was_running = True
            except Exception:
                pass

        path = item["path"]
        freed = 0
        deleted = 0

        if os.path.isfile(path):
            # Single file (MEMORY.DMP)
            try:
                freed = os.path.getsize(path)
                os.remove(path)
                deleted = 1
            except (PermissionError, OSError):
                pass
        else:
            pattern = None
            for t in DEEP_CLEAN_TARGETS:
                if t["path"] == path:
                    pattern = t.get("file_pattern")
                    break

            if os.path.exists(path):
                for root, dirs, files in os.walk(path, topdown=False):
                    for f in files:
                        if pattern and not f.endswith(pattern.replace("*", "")):
                            continue
                        fp = os.path.join(root, f)
                        try:
                            sz = os.path.getsize(fp)
                            os.remove(fp)
                            freed += sz
                            deleted += 1
                        except (PermissionError, OSError):
                            continue
                    for d in dirs:
                        try:
                            os.rmdir(os.path.join(root, d))
                        except (PermissionError, OSError):
                            continue

        # Restart service
        if service and service_was_running:
            try:
                subprocess.run(
                    ["net", "start", service],
                    capture_output=True, timeout=15
                )
            except Exception:
                pass

        freed_mb = round(freed / (1024 * 1024), 1)
        total_freed += freed
        total_deleted += deleted
        results.append({
            "name": item["name"],
            "deleted": deleted,
            "freed_mb": freed_mb,
        })

    # Also try Delivery Optimization cache via PowerShell
    try:
        subprocess.run(
            ["powershell", "-Command", "Delete-DeliveryOptimizationCache -Force"],
            capture_output=True, timeout=15
        )
        results.append({"name": "Delivery Optimization", "deleted": 0, "freed_mb": 0})
    except Exception:
        pass

    total_freed_mb = round(total_freed / (1024 * 1024), 1)
    add_event("boost", f"Deep Clean: {total_freed_mb} MB freed ({total_deleted} files)")

    return {
        "total_freed_mb": total_freed_mb,
        "total_deleted": total_deleted,
        "details": results,
    }


def ram_boost() -> dict:
    """Trim working sets, purge standby list, and clean temp files. Returns stats."""
    protected = _get_protected_names()
    mem_before = psutil.virtual_memory()
    breakdown_before = get_ram_breakdown()
    freed_count = 0
    skipped = 0
    errors = 0

    for proc in psutil.process_iter(["pid", "name"]):
        try:
            name = (proc.info["name"] or "").lower()
            pid = proc.info["pid"]
            if pid <= 4 or name in protected:
                skipped += 1
                continue

            handle = _kernel32.OpenProcess(
                PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA, False, pid
            )
            if handle:
                _psapi.EmptyWorkingSet(handle)
                _kernel32.CloseHandle(handle)
                freed_count += 1
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            errors += 1
        except Exception:
            errors += 1

    # Purge Standby List (Module 1)
    standby_purged = purge_standby_list()

    mem_after = psutil.virtual_memory()
    breakdown_after = get_ram_breakdown()
    freed_mb = round((mem_after.available - mem_before.available) / (1024 * 1024), 1)
    if freed_mb < 0:
        freed_mb = 0.0

    # Clean basic temp files (always runs with boost)
    temp_dirs = [
        tempfile.gettempdir(),
        os.path.expandvars(r"%WINDIR%\Temp"),
        os.path.expandvars(r"%LOCALAPPDATA%\CrashDumps"),
        os.path.expandvars(r"%LOCALAPPDATA%\Roblox\logs"),
    ]
    deleted_files = 0
    freed_bytes = 0
    for folder in temp_dirs:
        if not os.path.exists(folder):
            continue
        for root, dirs, files in os.walk(folder, topdown=False):
            for file in files:
                file_path = os.path.join(root, file)
                try:
                    size = os.path.getsize(file_path)
                    os.remove(file_path)
                    deleted_files += 1
                    freed_bytes += size
                except (PermissionError, OSError):
                    continue
            for d in dirs:
                try:
                    os.rmdir(os.path.join(root, d))
                except (PermissionError, OSError):
                    continue

    freed_temp_mb = round(freed_bytes / (1024 * 1024), 1)

    result = {
        "freed_mb": freed_mb,
        "freed_temp_mb": freed_temp_mb,
        "deleted_temp_files": deleted_files,
        "processes_trimmed": freed_count,
        "skipped": skipped,
        "errors": errors,
        "standby_purged": standby_purged,
        "ram_before_percent": mem_before.percent,
        "ram_after_percent": mem_after.percent,
        "breakdown_before": breakdown_before,
        "breakdown_after": breakdown_after,
    }
    msg_parts = [f"Boost: freed {freed_mb} MB RAM ({freed_count} procs)"]
    if standby_purged:
        msg_parts.append("+ Standby purged")
    if freed_temp_mb > 0 or deleted_files > 0:
        msg_parts.append(f"+ cleaned {freed_temp_mb} MB Temp ({deleted_files} files)")
    add_event("boost", " ".join(msg_parts))
    return result


# ===========================================================================
# MODULE 2: Hardening Drift Detector
# ===========================================================================
_last_drift_check = None
_last_drift_result = {}


def check_hardening_drift() -> dict:
    """Check if system hardening settings have drifted from expected values."""
    global _last_drift_check, _last_drift_result
    drift = {}
    checks = {}

    # VBS check
    try:
        key = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SOFTWARE\Policies\Microsoft\Windows\DeviceGuard",
        )
        val, _ = winreg.QueryValueEx(key, "EnableVirtualizationBasedSecurity")
        winreg.CloseKey(key)
        if val != 0:
            drift["VBS"] = f"Expected 0, got {val}"
            checks["vbs"] = "drift"
        else:
            checks["vbs"] = "ok"
    except FileNotFoundError:
        checks["vbs"] = "ok"  # Key doesn't exist = VBS not configured via policy (OK)
    except Exception as e:
        checks["vbs"] = f"error: {e}"

    # MPO check
    try:
        key = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SOFTWARE\Microsoft\Windows\DWM",
        )
        val, _ = winreg.QueryValueEx(key, "OverlayTestMode")
        winreg.CloseKey(key)
        if val != 5:
            drift["MPO"] = f"Expected 5, got {val}"
            checks["mpo"] = "drift"
        else:
            checks["mpo"] = "ok"
    except FileNotFoundError:
        drift["MPO"] = "Key missing — MPO may be active"
        checks["mpo"] = "drift"
    except Exception as e:
        checks["mpo"] = f"error: {e}"

    # Hypervisor check
    try:
        result = subprocess.run(
            ["bcdedit", "/enum", "{current}"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0:
            output = result.stdout.lower()
            if "hypervisorlaunchtype" in output:
                if "off" in output.split("hypervisorlaunchtype")[1].split("\n")[0]:
                    checks["hypervisor"] = "ok"
                else:
                    drift["Hypervisor"] = "hypervisorlaunchtype is NOT off"
                    checks["hypervisor"] = "drift"
            else:
                checks["hypervisor"] = "ok"  # Key not present = not enabled
        else:
            checks["hypervisor"] = "error: bcdedit failed"
    except Exception as e:
        checks["hypervisor"] = f"error: {e}"

    _last_drift_check = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    _last_drift_result = {
        "drift": drift,
        "checks": checks,
        "has_drift": len(drift) > 0,
        "last_check": _last_drift_check,
    }

    if drift:
        drift_items = ", ".join(f"{k}: {v}" for k, v in drift.items())
        add_event("warning", f"⚠️ Hardening drift detected: {drift_items}")

    return _last_drift_result


# ===========================================================================
# MODULE 3: In-VM Disk Sentinel (ADB → MuMu /data)
# ===========================================================================
_vm_disk_cache = []
_last_vm_disk_check = None


def _find_adb() -> str | None:
    """Find adb executable — MuMu bundles one, or check system PATH."""
    mumu_path = Path(CONFIG.get("mumu", {}).get("install_path", ""))
    candidates = [
        mumu_path / "shell" / "adb.exe",
        mumu_path / "adb.exe",
    ]
    for c in candidates:
        if c.exists():
            return str(c)
    # Check system PATH
    try:
        result = subprocess.run(
            ["where", "adb"], capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip().split("\n")[0].strip()
    except Exception:
        pass
    return None


def get_vm_disk_status() -> list:
    """Poll MuMu VM instances via ADB for /data disk usage."""
    global _vm_disk_cache, _last_vm_disk_check

    adb = _find_adb()
    if not adb:
        return []

    mumu_cfg = CONFIG.get("mumu", {})
    base_port = mumu_cfg.get("adb_base_port", 16384)
    step = mumu_cfg.get("adb_port_step", 32)
    max_inst = mumu_cfg.get("max_instances", 10)

    results = []
    for i in range(max_inst):
        port = base_port + (step * i)
        try:
            r = subprocess.run(
                [adb, "-s", f"127.0.0.1:{port}", "shell", "df", "/data"],
                capture_output=True, text=True, timeout=5,
            )
            if r.returncode == 0 and "/data" in r.stdout:
                lines = r.stdout.strip().split("\n")
                if len(lines) >= 2:
                    parts = lines[1].split()
                    if len(parts) >= 5:
                        # df output: Filesystem 1K-blocks Used Available Use% Mounted
                        total_kb = int(parts[1])
                        used_kb = int(parts[2])
                        avail_kb = int(parts[3])
                        use_pct_str = parts[4].replace("%", "")
                        use_pct = int(use_pct_str)
                        results.append({
                            "port": port,
                            "instance": i + 1,
                            "total_gb": round(total_kb / (1024 * 1024), 2),
                            "used_gb": round(used_kb / (1024 * 1024), 2),
                            "avail_gb": round(avail_kb / (1024 * 1024), 2),
                            "used_pct": use_pct,
                            "status": (
                                "critical" if use_pct >= CONFIG["maintenance"]["vm_disk_critical_pct"]
                                else "warning" if use_pct >= CONFIG["maintenance"]["vm_disk_warn_pct"]
                                else "ok"
                            ),
                        })
        except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
            continue

    _vm_disk_cache = results
    _last_vm_disk_check = datetime.now().strftime("%H:%M:%S")
    return results


def trim_vm_caches(port: int) -> bool:
    """Run pm trim-caches on a specific MuMu VM instance."""
    adb = _find_adb()
    if not adb:
        return False
    try:
        r = subprocess.run(
            [adb, "-s", f"127.0.0.1:{port}", "shell", "pm", "trim-caches", "128G"],
            capture_output=True, text=True, timeout=15,
        )
        if r.returncode == 0:
            add_event("system", f"VM cache trimmed (port {port})")
            return True
    except Exception:
        pass
    return False


# ===========================================================================
# MODULE 5: Anti-EcoQoS + Background Hog Detector
# ===========================================================================

# ProcessPowerThrottling state structure
class PROCESS_POWER_THROTTLING_STATE(ctypes.Structure):
    _fields_ = [
        ("Version", ctypes.c_ulong),
        ("ControlMask", ctypes.c_ulong),
        ("StateMask", ctypes.c_ulong),
    ]


# Background hog targets — these get force-throttled + lowered priority
HOG_TARGETS = {
    "compattelrunner.exe",
    "mousocoreworker.exe",
    "searchindexer.exe",
    "wmiprvse.exe",
    "windowsupdatebox.exe",
    "installagent.exe",
    "musnotification.exe",
}

_ecoqos_applied_pids = set()
_hog_actions = []


def disable_ecoqos_for_mumu() -> int:
    """Disable Power Throttling (EcoQoS) for all MuMu device processes.
    
    Returns count of processes unthrottled.
    """
    global _ecoqos_applied_pids
    mumu_names = {n.lower() for n in CONFIG.get("mumu", {}).get("process_names", [])}
    count = 0

    for proc in psutil.process_iter(["pid", "name"]):
        try:
            name = (proc.info["name"] or "").lower()
            pid = proc.info["pid"]
            if name not in mumu_names or pid in _ecoqos_applied_pids:
                continue

            handle = _kernel32.OpenProcess(
                PROCESS_SET_INFORMATION | PROCESS_QUERY_INFORMATION,
                False, pid,
            )
            if handle:
                # Version=1, ControlMask=EXECUTION_SPEED(0x1), StateMask=0 → no throttle
                state = PROCESS_POWER_THROTTLING_STATE(1, 1, 0)
                try:
                    result = _kernel32.SetProcessInformation(
                        handle, 4,  # ProcessPowerThrottling
                        ctypes.byref(state),
                        ctypes.sizeof(state),
                    )
                    if result:
                        _ecoqos_applied_pids.add(pid)
                        count += 1
                except Exception:
                    pass
                _kernel32.CloseHandle(handle)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    # Clean up dead PIDs
    alive_pids = {p.pid for p in psutil.process_iter(["pid"])}
    _ecoqos_applied_pids = _ecoqos_applied_pids & alive_pids

    return count


def detect_and_throttle_hogs() -> list:
    """Find background hog processes and lower their priority."""
    global _hog_actions
    actions = []

    for proc in psutil.process_iter(["pid", "name", "cpu_percent"]):
        try:
            name = (proc.info["name"] or "").lower()
            if name not in HOG_TARGETS:
                continue

            pid = proc.info["pid"]
            cpu = proc.info["cpu_percent"] or 0

            # Lower priority to IDLE
            try:
                p = psutil.Process(pid)
                current_nice = p.nice()
                if current_nice != psutil.IDLE_PRIORITY_CLASS:
                    p.nice(psutil.IDLE_PRIORITY_CLASS)
                    action = f"Throttled {proc.info['name']} (PID {pid}, CPU {cpu}%)"
                    actions.append(action)
                    add_event("system", f"🔧 Hog Detector: {action}")
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    _hog_actions = actions
    return actions


# ===========================================================================
# MODULE 6: Growth Tracker (MuMu vms/ folder snapshots)
# ===========================================================================
def _load_growth_data() -> list:
    if GROWTH_PATH.exists():
        try:
            with open(GROWTH_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return []
    return []


def _save_growth_data(data: list):
    # Keep last 30 days of snapshots (max ~120 entries at 6h intervals)
    with open(GROWTH_PATH, "w", encoding="utf-8") as f:
        json.dump(data[-120:], f, indent=2, ensure_ascii=False)


_growth_data = _load_growth_data()


def snapshot_folder_sizes() -> dict:
    """Take a snapshot of MuMu vms/ folder sizes and disk partitions."""
    global _growth_data

    snapshot = {
        "timestamp": datetime.now().isoformat(),
        "folders": {},
        "disks": {},
    }

    # MuMu vms/ subfolders
    mumu_path = Path(CONFIG.get("mumu", {}).get("install_path", ""))
    vms_dir = mumu_path / "vms"
    if vms_dir.exists():
        for d in vms_dir.iterdir():
            if d.is_dir():
                try:
                    total = sum(f.stat().st_size for f in d.rglob("*") if f.is_file())
                    snapshot["folders"][d.name] = round(total / (1024 ** 3), 2)
                except Exception:
                    continue

    # Disk partition usage
    for part in psutil.disk_partitions():
        try:
            usage = psutil.disk_usage(part.mountpoint)
            snapshot["disks"][part.mountpoint] = {
                "total_gb": round(usage.total / (1024 ** 3), 1),
                "used_gb": round(usage.used / (1024 ** 3), 1),
                "free_gb": round(usage.free / (1024 ** 3), 1),
                "percent": usage.percent,
            }
        except Exception:
            continue

    _growth_data.append(snapshot)
    _save_growth_data(_growth_data)
    add_event("system", f"📊 Growth snapshot: {len(snapshot['folders'])} VM folders tracked")

    return snapshot


# ===========================================================================
# MODULE 7: Defender Maintenance
# ===========================================================================
_last_scan_date = None
_defender_status = {}


def get_defender_status() -> dict:
    """Get Windows Defender status including signature age and last scan."""
    global _defender_status
    try:
        r = subprocess.run(
            ["powershell", "-Command",
             "(Get-MpComputerStatus | Select-Object "
             "AntivirusSignatureAge, AntivirusSignatureLastUpdated, "
             "QuickScanAge, FullScanAge, RealTimeProtectionEnabled, "
             "AntivirusEnabled "
             "| ConvertTo-Json)"],
            capture_output=True, text=True, timeout=15,
        )
        if r.returncode == 0 and r.stdout.strip():
            data = json.loads(r.stdout.strip())
            sig_age = data.get("AntivirusSignatureAge", -1)
            _defender_status = {
                "available": True,
                "signature_age_days": sig_age,
                "signature_stale": sig_age > 3,
                "quick_scan_age_days": data.get("QuickScanAge", -1),
                "full_scan_age_days": data.get("FullScanAge", -1),
                "realtime_enabled": data.get("RealTimeProtectionEnabled", False),
                "antivirus_enabled": data.get("AntivirusEnabled", False),
                "last_check": datetime.now().strftime("%H:%M:%S"),
            }
            if sig_age > 3:
                add_event("warning", f"⚠️ Defender signatures are {sig_age} days old")
            return _defender_status
    except Exception:
        pass

    _defender_status = {"available": False, "last_check": datetime.now().strftime("%H:%M:%S")}
    return _defender_status


def run_quick_scan() -> bool:
    """Start a Windows Defender Quick Scan."""
    global _last_scan_date
    try:
        subprocess.Popen(
            ["powershell", "-Command", "Start-MpScan -ScanType 1"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        _last_scan_date = date.today()
        add_event("system", "🔒 Defender Quick Scan started")
        return True
    except Exception:
        return False


def scan_downloads_folder() -> int:
    """Scan new files in Downloads folder (modified in last 30 min)."""
    downloads = Path.home() / "Downloads"
    if not downloads.exists():
        return 0

    sweep_minutes = CONFIG.get("maintenance", {}).get("downloads_sweep_minutes", 30)
    cutoff = time.time() - (sweep_minutes * 60)
    scanned = 0

    for f in downloads.iterdir():
        if f.is_file() and f.stat().st_mtime > cutoff:
            try:
                subprocess.Popen(
                    ["powershell", "-Command",
                     f'Start-MpScan -ScanType 3 -ScanPath "{f}"'],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                )
                scanned += 1
            except Exception:
                continue

    if scanned > 0:
        add_event("system", f"🔒 Scanned {scanned} new file(s) in Downloads")
    return scanned


# ---------------------------------------------------------------------------
# Metrics collection
# ---------------------------------------------------------------------------
_last_gpu_data = {
    "available": True,
    "name": "NVIDIA GeForce RTX 3050 Laptop GPU",
    "temperature_c": 0,
    "utilization_percent": 0,
    "memory_used_mb": 0,
    "memory_total_mb": 4096,
    "memory_percent": 0.0,
}


def get_gpu_metrics() -> dict:
    global _last_gpu_data
    try:
        import pynvml
        pynvml.nvmlInit()
        handle = pynvml.nvmlDeviceGetHandleByIndex(0)
        temp = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
        util = pynvml.nvmlDeviceGetUtilizationRates(handle)
        mem = pynvml.nvmlDeviceGetMemoryInfo(handle)
        name = pynvml.nvmlDeviceGetName(handle)
        if isinstance(name, bytes):
            name = name.decode("utf-8")

        _last_gpu_data = {
            "available": True,
            "name": name,
            "temperature_c": temp,
            "utilization_percent": util.gpu,
            "memory_used_mb": round(mem.used / (1024 * 1024)),
            "memory_total_mb": round(mem.total / (1024 * 1024)),
            "memory_percent": round(mem.used / mem.total * 100, 1),
        }
        try:
            pynvml.nvmlShutdown()
        except Exception:
            pass
        return _last_gpu_data
    except Exception:
        try:
            import pynvml
            pynvml.nvmlShutdown()
        except Exception:
            pass
        if _last_gpu_data.get("temperature_c", 0) > 0:
            return _last_gpu_data
        return {"available": False}


def get_system_metrics() -> dict:
    cpu_per_core = psutil.cpu_percent(interval=0, percpu=True)
    cpu_total = psutil.cpu_percent(interval=0)
    mem = psutil.virtual_memory()
    disk_io = psutil.disk_io_counters()
    net_io = psutil.net_io_counters()

    return {
        "timestamp": datetime.now().strftime("%H:%M:%S"),
        "cpu": {
            "total_percent": cpu_total,
            "per_core": cpu_per_core,
            "core_count": len(cpu_per_core),
            "p_cores": cpu_per_core[:8],
            "e_cores": cpu_per_core[8:],
        },
        "ram": {
            "total_gb": round(mem.total / (1024 ** 3), 1),
            "used_gb": round(mem.used / (1024 ** 3), 1),
            "available_gb": round(mem.available / (1024 ** 3), 1),
            "percent": mem.percent,
            "breakdown": get_ram_breakdown(),
        },
        "gpu": get_gpu_metrics(),
        "disk": {
            "read_mb": round(disk_io.read_bytes / (1024 ** 2), 1) if disk_io else 0,
            "write_mb": round(disk_io.write_bytes / (1024 ** 2), 1) if disk_io else 0,
        },
        "network": {
            "sent_mb": round(net_io.bytes_sent / (1024 ** 2), 1),
            "recv_mb": round(net_io.bytes_recv / (1024 ** 2), 1),
        },
    }


# State for computing per-second rates
_prev_disk_io = None
_prev_net_io = None
_prev_time = None


def get_metrics_with_rates() -> dict:
    global _prev_disk_io, _prev_net_io, _prev_time

    metrics = get_system_metrics()
    now = time.monotonic()

    disk_io = psutil.disk_io_counters()
    net_io = psutil.net_io_counters()

    if _prev_disk_io and _prev_net_io and _prev_time:
        dt = now - _prev_time
        if dt > 0:
            metrics["disk"]["read_speed_mbs"] = round(
                (disk_io.read_bytes - _prev_disk_io.read_bytes) / (1024 ** 2) / dt, 2
            )
            metrics["disk"]["write_speed_mbs"] = round(
                (disk_io.write_bytes - _prev_disk_io.write_bytes) / (1024 ** 2) / dt, 2
            )
            metrics["network"]["sent_speed_mbs"] = round(
                (net_io.bytes_sent - _prev_net_io.bytes_sent) / (1024 ** 2) / dt, 2
            )
            metrics["network"]["recv_speed_mbs"] = round(
                (net_io.bytes_recv - _prev_net_io.bytes_recv) / (1024 ** 2) / dt, 2
            )
    else:
        metrics["disk"]["read_speed_mbs"] = 0
        metrics["disk"]["write_speed_mbs"] = 0
        metrics["network"]["sent_speed_mbs"] = 0
        metrics["network"]["recv_speed_mbs"] = 0

    _prev_disk_io = disk_io
    _prev_net_io = net_io
    _prev_time = now
    return metrics


# ---------------------------------------------------------------------------
# MuMu Instance Monitor
# ---------------------------------------------------------------------------
def get_mumu_instances() -> list:
    mumu_names = {n.lower() for n in CONFIG.get("mumu", {}).get("process_names", [])}
    instances = []
    for proc in psutil.process_iter(["pid", "name", "cpu_percent", "memory_info", "create_time"]):
        try:
            name = (proc.info["name"] or "").lower()
            if name in mumu_names:
                uptime_sec = time.time() - proc.info["create_time"]
                hours = int(uptime_sec // 3600)
                minutes = int((uptime_sec % 3600) // 60)
                instances.append({
                    "pid": proc.info["pid"],
                    "name": proc.info["name"],
                    "cpu_percent": round(proc.info["cpu_percent"] or 0, 1),
                    "ram_mb": round((proc.info["memory_info"].rss if proc.info["memory_info"] else 0) / (1024 ** 2), 1),
                    "uptime": f"{hours}h{minutes:02d}m",
                    "uptime_seconds": int(uptime_sec),
                    "status": "running",
                })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return instances


_prev_mumu_count = None


def check_mumu_health() -> dict:
    global _prev_mumu_count
    instances = get_mumu_instances()

    devices = [i for i in instances if i["name"].lower() == "mumunxdevice.exe"]
    launchers = [i for i in instances if i["name"].lower() == "mumunxmain.exe"]

    current_device_count = len(devices)

    if _prev_mumu_count is not None and current_device_count < _prev_mumu_count:
        lost = _prev_mumu_count - current_device_count
        add_event("crash", f"MuMu Instance crash detected — {lost} instance(s) disappeared")

    _prev_mumu_count = current_device_count

    return {
        "devices": devices,
        "launchers": launchers,
        "total_instances": current_device_count,
        "launcher_running": len(launchers) > 0,
        "vm_disk": _vm_disk_cache,
        "vm_disk_last_check": _last_vm_disk_check,
    }


# ---------------------------------------------------------------------------
# Top Processes
# ---------------------------------------------------------------------------
def get_top_processes(limit: int = 10) -> list:
    procs = []
    for proc in psutil.process_iter(["pid", "name", "memory_info", "cpu_percent"]):
        try:
            mem = proc.info["memory_info"]
            procs.append({
                "pid": proc.info["pid"],
                "name": proc.info["name"] or "Unknown",
                "ram_mb": round((mem.rss if mem else 0) / (1024 ** 2), 1),
                "cpu_percent": round(proc.info["cpu_percent"] or 0, 1),
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    procs.sort(key=lambda x: x["ram_mb"], reverse=True)
    return procs[:limit]


# ---------------------------------------------------------------------------
# Auto-Boost Background Task
# ---------------------------------------------------------------------------
_auto_boost_task = None
_last_boost_time = None
_last_boost_result = None


async def auto_boost_loop():
    global _last_boost_time, _last_boost_result
    while True:
        try:
            cfg = CONFIG.get("auto_boost", {})
            if not cfg.get("enabled", False):
                await asyncio.sleep(5)
                continue

            mode = cfg.get("mode", "auto")
            mem = psutil.virtual_memory()

            should_boost = False
            if mode == "auto" and mem.percent >= cfg.get("threshold_percent", 85):
                should_boost = True
                add_event("warning", f"RAM threshold {cfg['threshold_percent']}% reached ({mem.percent}%)")
            elif mode == "scheduled":
                interval = cfg.get("interval_minutes", 10) * 60
                if _last_boost_time is None or (time.time() - _last_boost_time) >= interval:
                    should_boost = True

            if should_boost:
                _last_boost_result = ram_boost()
                _last_boost_time = time.time()
                await broadcast_event({
                    "type": "boost_triggered",
                    "result": _last_boost_result,
                })

            await asyncio.sleep(5)
        except Exception as e:
            add_event("error", f"Auto-boost loop error: {str(e)}")
            await asyncio.sleep(10)


# ---------------------------------------------------------------------------
# Maintenance Background Task (Modules 2, 3, 5, 6, 7)
# ---------------------------------------------------------------------------
_maintenance_task = None


async def maintenance_loop():
    """Background loop handling periodic maintenance tasks."""
    # Track intervals
    last_drift_check = 0
    last_vm_disk_check = 0
    last_ecoqos_check = 0
    last_hog_check = 0
    last_growth_snapshot = 0
    last_defender_check = 0
    last_downloads_sweep = 0

    maint_cfg = CONFIG.get("maintenance", {})

    # Initial checks on startup
    await asyncio.sleep(5)  # Let server stabilize

    # Startup drift check
    try:
        check_hardening_drift()
    except Exception as e:
        add_event("error", f"Drift check failed: {e}")

    # Startup EcoQoS
    try:
        count = disable_ecoqos_for_mumu()
        if count > 0:
            add_event("system", f"🛡️ Anti-EcoQoS applied to {count} MuMu process(es)")
    except Exception:
        pass

    # Startup Defender status
    try:
        get_defender_status()
    except Exception:
        pass

    while True:
        try:
            now = time.time()
            maint_cfg = CONFIG.get("maintenance", {})

            # Module 2: Hardening Drift Detector (every N hours)
            drift_interval = maint_cfg.get("drift_check_hours", 6) * 3600
            if now - last_drift_check >= drift_interval:
                try:
                    result = check_hardening_drift()
                    await broadcast_event({"type": "hardening_status", "data": result})
                except Exception:
                    pass
                last_drift_check = now

            # Module 3: VM Disk Sentinel (every 15 min)
            if now - last_vm_disk_check >= 900:  # 15 minutes
                try:
                    vm_data = get_vm_disk_status()
                    # Auto-trim if enabled and any VM over threshold
                    if maint_cfg.get("vm_auto_trim", True):
                        for vm in vm_data:
                            if vm["used_pct"] >= maint_cfg.get("vm_disk_warn_pct", 85):
                                trim_vm_caches(vm["port"])
                                await asyncio.sleep(2)
                                # Re-check after trim
                                updated = get_vm_disk_status()
                                for u in updated:
                                    if u["port"] == vm["port"] and u["used_pct"] >= maint_cfg.get("vm_disk_critical_pct", 90):
                                        add_event("crash", f"🚨 VM #{u['instance']} disk CRITICAL at {u['used_pct']}% after trim!")
                    await broadcast_event({"type": "vm_disk_status", "data": vm_data})
                except Exception:
                    pass
                last_vm_disk_check = now

            # Module 5: Anti-EcoQoS (every 30 seconds — fast, catches new MuMu launches)
            if now - last_ecoqos_check >= 30:
                try:
                    count = disable_ecoqos_for_mumu()
                    if count > 0:
                        add_event("system", f"🛡️ Anti-EcoQoS applied to {count} new MuMu process(es)")
                except Exception:
                    pass
                last_ecoqos_check = now

            # Module 5: Hog Detector (every 60 seconds)
            if now - last_hog_check >= 60:
                try:
                    detect_and_throttle_hogs()
                except Exception:
                    pass
                last_hog_check = now

            # Module 6: Growth Tracker (every N hours)
            growth_interval = maint_cfg.get("growth_snapshot_hours", 6) * 3600
            if now - last_growth_snapshot >= growth_interval:
                try:
                    snapshot_folder_sizes()
                except Exception:
                    pass
                last_growth_snapshot = now

            # Module 7: Defender (check status every hour)
            if now - last_defender_check >= 3600:
                try:
                    status = get_defender_status()
                    await broadcast_event({"type": "defender_status", "data": status})
                except Exception:
                    pass
                last_defender_check = now

            # Module 7: Quick Scan at configured hour (once per day)
            current_hour = datetime.now().hour
            scan_hour = maint_cfg.get("defender_scan_hour", 4)
            if current_hour == scan_hour and _last_scan_date != date.today():
                try:
                    run_quick_scan()
                except Exception:
                    pass

            # Module 7: Downloads sweep
            sweep_interval = maint_cfg.get("downloads_sweep_minutes", 30) * 60
            if now - last_downloads_sweep >= sweep_interval:
                try:
                    scan_downloads_folder()
                except Exception:
                    pass
                last_downloads_sweep = now

            await asyncio.sleep(10)  # Check every 10 seconds
        except Exception as e:
            add_event("error", f"Maintenance loop error: {str(e)}")
            await asyncio.sleep(30)


# ---------------------------------------------------------------------------
# WebSocket Manager
# ---------------------------------------------------------------------------
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.active_connections.append(ws)

    def disconnect(self, ws: WebSocket):
        if ws in self.active_connections:
            self.active_connections.remove(ws)

    async def broadcast(self, data: dict):
        dead = []
        for conn in self.active_connections:
            try:
                await conn.send_json(data)
            except Exception:
                dead.append(conn)
        for d in dead:
            self.disconnect(d)


manager = ConnectionManager()


async def broadcast_event(data: dict):
    await manager.broadcast(data)


# ---------------------------------------------------------------------------
# FastAPI App with Lifespan
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    global _auto_boost_task, _maintenance_task
    # Prime CPU percent
    psutil.cpu_percent(interval=0, percpu=True)
    _auto_boost_task = asyncio.create_task(auto_boost_loop())
    _maintenance_task = asyncio.create_task(maintenance_loop())
    add_event("system", "Genesis Dashboard started (Fable 5 Engine)")
    yield
    if _auto_boost_task:
        _auto_boost_task.cancel()
    if _maintenance_task:
        _maintenance_task.cancel()
    add_event("system", "Genesis Dashboard stopped")


app = FastAPI(title="Genesis Dashboard", version="2.0.0", lifespan=lifespan)

static_dir = BASE_DIR / "static"
static_dir.mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")


@app.get("/")
async def serve_dashboard():
    return FileResponse(str(static_dir / "index.html"))


@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await manager.connect(ws)
    try:
        await ws.send_json({
            "type": "init",
            "config": CONFIG,
            "history": event_history[-50:],
            "hardening": _last_drift_result,
            "defender": _defender_status,
            "vm_disk": _vm_disk_cache,
            "growth": _growth_data[-24:] if _growth_data else [],
        })

        while True:
            metrics = get_metrics_with_rates()
            mumu = check_mumu_health()
            top_procs = get_top_processes(10)

            await ws.send_json({
                "type": "metrics",
                "metrics": metrics,
                "mumu": mumu,
                "top_processes": top_procs,
                "auto_boost": {
                    "enabled": CONFIG["auto_boost"]["enabled"],
                    "mode": CONFIG["auto_boost"]["mode"],
                    "threshold": CONFIG["auto_boost"]["threshold_percent"],
                    "last_boost_time": (
                        datetime.fromtimestamp(_last_boost_time).strftime("%H:%M:%S")
                        if _last_boost_time else None
                    ),
                    "last_boost_result": _last_boost_result,
                },
            })

            try:
                msg = await asyncio.wait_for(ws.receive_text(), timeout=CONFIG["metrics"]["update_interval_ms"] / 1000)
                data = json.loads(msg)
                await handle_ws_command(ws, data)
            except asyncio.TimeoutError:
                pass
    except WebSocketDisconnect:
        manager.disconnect(ws)
    except Exception:
        manager.disconnect(ws)


async def handle_ws_command(ws: WebSocket, data: dict):
    cmd = data.get("command")

    if cmd == "boost":
        result = ram_boost()
        await ws.send_json({"type": "boost_result", "result": result})

    elif cmd == "update_config":
        payload = data.get("config", {})
        if "threshold_percent" in payload:
            CONFIG["auto_boost"]["threshold_percent"] = int(payload["threshold_percent"])
        if "mode" in payload:
            CONFIG["auto_boost"]["mode"] = payload["mode"]
        if "enabled" in payload:
            CONFIG["auto_boost"]["enabled"] = bool(payload["enabled"])
        if "interval_minutes" in payload:
            CONFIG["auto_boost"]["interval_minutes"] = int(payload["interval_minutes"])
        save_config(CONFIG)
        await ws.send_json({"type": "config_updated", "config": CONFIG})

    # Module 4: Deep Clean commands
    elif cmd == "deep_clean_preview":
        preview = deep_clean_preview()
        await ws.send_json({"type": "deep_clean_preview", "data": preview})

    elif cmd == "deep_clean_execute":
        targets = data.get("targets")  # list of target names, or None for all
        result = deep_clean_execute(targets)
        await ws.send_json({"type": "deep_clean_result", "data": result})

    # Module 3: VM Disk commands
    elif cmd == "vm_disk_refresh":
        vm_data = get_vm_disk_status()
        await ws.send_json({"type": "vm_disk_status", "data": vm_data})

    elif cmd == "vm_trim_cache":
        port = data.get("port")
        if port:
            success = trim_vm_caches(port)
            await ws.send_json({"type": "vm_trim_result", "port": port, "success": success})

    # Module 2: Hardening check on-demand
    elif cmd == "check_hardening":
        result = check_hardening_drift()
        await ws.send_json({"type": "hardening_status", "data": result})

    # Module 7: Defender commands
    elif cmd == "defender_status":
        status = get_defender_status()
        await ws.send_json({"type": "defender_status", "data": status})

    elif cmd == "quick_scan":
        success = run_quick_scan()
        await ws.send_json({"type": "quick_scan_result", "success": success})

    # Module 6: Growth data
    elif cmd == "growth_data":
        await ws.send_json({"type": "growth_data", "data": _growth_data[-24:]})


# ---------------------------------------------------------------------------
# REST API Endpoints
# ---------------------------------------------------------------------------
@app.post("/api/boost")
async def api_boost():
    result = ram_boost()
    return JSONResponse(result)


@app.get("/api/config")
async def api_get_config():
    return JSONResponse(CONFIG)


@app.put("/api/config")
async def api_put_config(payload: dict):
    ab = payload.get("auto_boost", {})
    if "threshold_percent" in ab:
        CONFIG["auto_boost"]["threshold_percent"] = int(ab["threshold_percent"])
    if "mode" in ab:
        CONFIG["auto_boost"]["mode"] = ab["mode"]
    if "enabled" in ab:
        CONFIG["auto_boost"]["enabled"] = bool(ab["enabled"])
    if "interval_minutes" in ab:
        CONFIG["auto_boost"]["interval_minutes"] = int(ab["interval_minutes"])
    save_config(CONFIG)
    return JSONResponse(CONFIG)


@app.get("/api/history")
async def api_history():
    return JSONResponse(event_history[-50:])


@app.get("/api/processes")
async def api_processes():
    return JSONResponse(get_top_processes(30))


@app.post("/api/kill/{pid}")
async def api_kill(pid: int):
    try:
        proc = psutil.Process(pid)
        name = proc.name()
        protected = _get_protected_names()
        if name.lower() in protected:
            return JSONResponse({"error": f"{name} is protected"}, status_code=403)
        proc.terminate()
        add_event("kill", f"Process killed: {name} (PID {pid})")
        return JSONResponse({"ok": True, "name": name, "pid": pid})
    except psutil.NoSuchProcess:
        return JSONResponse({"error": "Process not found"}, status_code=404)
    except psutil.AccessDenied:
        return JSONResponse({"error": "Access denied"}, status_code=403)


@app.get("/api/deep-clean/preview")
async def api_deep_clean_preview():
    return JSONResponse(deep_clean_preview())


@app.post("/api/deep-clean/execute")
async def api_deep_clean_execute():
    result = deep_clean_execute()
    return JSONResponse(result)


@app.get("/api/hardening")
async def api_hardening():
    return JSONResponse(check_hardening_drift())


@app.get("/api/defender")
async def api_defender():
    return JSONResponse(get_defender_status())


@app.get("/api/growth")
async def api_growth():
    return JSONResponse(_growth_data[-24:])


@app.get("/api/vm-disk")
async def api_vm_disk():
    return JSONResponse(get_vm_disk_status())


if __name__ == "__main__":
    import uvicorn

    host = CONFIG.get("server", {}).get("host", "0.0.0.0")
    port = CONFIG.get("server", {}).get("port", 7700)
    print(f"\n{'='*50}")
    print(f"  GENESIS DASHBOARD v2.0 — Fable 5 Engine")
    print(f"  http://localhost:{port}")
    print(f"  http://0.0.0.0:{port} (LAN access)")
    print(f"{'='*50}\n")
    uvicorn.run(app, host=host, port=port, log_level="info")
