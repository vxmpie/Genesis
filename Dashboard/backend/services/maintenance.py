import asyncio
import json
import os
import re
import subprocess
import tempfile
import time
import winreg
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime
from pathlib import Path

import psutil

from backend.core.config import CONFIG, GROWTH_PATH
from backend.core.events import add_event, broadcast_payload_threadsafe
from backend.services.discord_notifier import (
    NotificationEvent,
    notifier,
    run_auto_discord_purge,
)
from backend.services.mumu_monitor import find_mumu_adb, set_vm_disk_snapshot
from backend.services.telemetry import (
    get_session_summary,
    get_watchdog_status,
    record_boost_result,
    record_standby_purge,
    set_drift_detected_flag,
)
from backend.services.win32_ops import (
    detect_and_throttle_hogs,
    disable_ecoqos_for_mumu,
    get_protected_names,
    get_ram_breakdown,
    purge_standby_list,
    should_purge_standby_gate,
    trim_process_handle,
)

# --- Deep Clean Targets & Engine ---
DEEP_CLEAN_TARGETS: list[dict] = [
    {
        "name": "User Temp",
        "category": "Temp",
        "description": "Current user temporary files and installer caches",
        "path": tempfile.gettempdir(),
        "requires_service_stop": None,
    },
    {
        "name": "Windows Temp",
        "category": "System",
        "description": "Windows global temporary staging files",
        "path": os.path.expandvars(r"%WINDIR%\Temp"),
        "requires_service_stop": None,
    },
    {
        "name": "CrashDumps",
        "category": "Diagnostics",
        "description": "Local application crash dump files",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\CrashDumps"),
        "requires_service_stop": None,
    },
    {
        "name": "Roblox Logs",
        "category": "Logs",
        "description": "Roblox client diagnostic and session logs",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\Roblox\logs"),
        "requires_service_stop": None,
    },
    {
        "name": "Windows Update Cache",
        "category": "System",
        "description": "Downloaded Windows Update packages (temporarily stops wuauserv)",
        "path": r"C:\Windows\SoftwareDistribution\Download",
        "requires_service_stop": "wuauserv",
    },
    {
        "name": "Memory Dumps",
        "category": "Diagnostics",
        "description": "Kernel minidump diagnostic archives",
        "path": r"C:\Windows\Minidump",
        "requires_service_stop": None,
    },
    {
        "name": "Thumbnail Cache",
        "category": "Cache",
        "description": "Windows Explorer icon and thumbnail database caches",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Windows\Explorer"),
        "file_pattern": "*.db",
        "requires_service_stop": None,
    },
    {
        "name": "Chrome Cache",
        "category": "Browser",
        "description": "Google Chrome HTTP and media disk cache",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache"),
        "requires_service_stop": None,
    },
    {
        "name": "Edge Cache",
        "category": "Browser",
        "description": "Microsoft Edge HTTP and media disk cache",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache"),
        "requires_service_stop": None,
    },
]

_MEMORY_DMP = r"C:\Windows\MEMORY.DMP"


def _is_safe_clean_path(target_path: str) -> bool:
    norm = os.path.normpath(target_path).lower()
    for t in DEEP_CLEAN_TARGETS:
        if os.path.normpath(t["path"]).lower() == norm:
            return True
    return norm == os.path.normpath(_MEMORY_DMP).lower()


def deep_clean_preview() -> list[dict]:
    preview: list[dict] = []
    for target in DEEP_CLEAN_TARGETS:
        folder = target["path"]
        if not os.path.exists(folder) or not _is_safe_clean_path(folder):
            continue
        total_size = 0
        file_count = 0
        pattern = target.get("file_pattern")
        try:
            for root, _dirs, files in os.walk(folder):
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
            preview.append(
                {
                    "name": target["name"],
                    "category": target.get("category", "System"),
                    "description": target.get("description", ""),
                    "path": folder,
                    "file_count": file_count,
                    "size_mb": round(total_size / (1024 * 1024), 1),
                    "requires_service_stop": target.get("requires_service_stop"),
                }
            )

    if os.path.exists(_MEMORY_DMP):
        try:
            sz = os.path.getsize(_MEMORY_DMP)
            preview.append(
                {
                    "name": "MEMORY.DMP",
                    "category": "Diagnostics",
                    "description": "Full Windows kernel crash dump file",
                    "path": _MEMORY_DMP,
                    "file_count": 1,
                    "size_mb": round(sz / (1024 * 1024), 1),
                    "requires_service_stop": None,
                }
            )
        except OSError:
            pass

    return preview


def deep_clean_execute(targets: list[str] | None = None) -> dict:
    preview = deep_clean_preview()
    if targets:
        preview = [p for p in preview if p["name"] in targets]

    total_freed = 0
    total_deleted = 0
    results: list[dict] = []

    for item in preview:
        path = item["path"]
        if not _is_safe_clean_path(path):
            continue
        service = item.get("requires_service_stop")
        service_was_running = False
        freed = 0
        deleted = 0

        if service:
            try:
                subprocess.run(["net", "stop", service], capture_output=True, timeout=15)
                service_was_running = True
            except Exception:
                pass

        try:
            if os.path.isfile(path):
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
        finally:
            if service and service_was_running:
                try:
                    subprocess.run(["net", "start", service], capture_output=True, timeout=15)
                except Exception:
                    pass

        freed_mb = round(freed / (1024 * 1024), 1)
        total_freed += freed
        total_deleted += deleted
        results.append(
            {
                "name": item["name"],
                "deleted": deleted,
                "freed_mb": freed_mb,
            }
        )

    try:
        subprocess.run(
            ["powershell", "-Command", "Delete-DeliveryOptimizationCache -Force"],
            capture_output=True,
            timeout=15,
        )
        results.append({"name": "Delivery Optimization", "deleted": 0, "freed_mb": 0})
    except Exception:
        pass

    total_freed_mb = round(total_freed / (1024 * 1024), 1)
    add_event("clean", f"Deep Clean: {total_freed_mb} MB freed ({total_deleted} files)")

    return {
        "total_freed_mb": total_freed_mb,
        "total_deleted": total_deleted,
        "details": results,
    }


# --- RAM Boost Engine ---
def ram_boost(force_standby: bool = True) -> dict:
    start_time = time.perf_counter()
    protected = get_protected_names()
    mem_before = psutil.virtual_memory()
    breakdown_before = get_ram_breakdown()

    should_purge_standby = force_standby or should_purge_standby_gate(
        breakdown_before.get("free_gb", 0.0),
        breakdown_before.get("standby_gb", 0.0),
        breakdown_before.get("available_gb", 0.0),
    )

    standby_purged = purge_standby_list() if should_purge_standby else False

    pids_to_trim: list[int] = []
    skipped = 0
    for proc in psutil.process_iter(["pid", "name"]):
        try:
            pid = proc.info["pid"]
            name = (proc.info["name"] or "").lower()
            if pid <= 4 or name in protected:
                skipped += 1
                continue
            pids_to_trim.append(pid)
        except Exception:
            continue

    freed_count = 0
    errors = 0
    with ThreadPoolExecutor(max_workers=16) as executor:
        results = list(executor.map(trim_process_handle, pids_to_trim))
    for f, _s, e in results:
        freed_count += f
        errors += e

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
        try:
            with os.scandir(folder) as it:
                for entry in it:
                    if entry.is_file(follow_symlinks=False):
                        try:
                            sz = entry.stat().st_size
                            os.remove(entry.path)
                            deleted_files += 1
                            freed_bytes += sz
                        except (PermissionError, OSError):
                            continue
        except Exception:
            continue

    freed_temp_mb = round(freed_bytes / (1024 * 1024), 1)
    mem_after = psutil.virtual_memory()
    breakdown_after = get_ram_breakdown()
    freed_mb = max(0.0, round((mem_after.available - mem_before.available) / (1024 * 1024), 1))
    duration_ms = round((time.perf_counter() - start_time) * 1000.0, 1)

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
        "duration_ms": duration_ms,
    }
    record_boost_result(result)

    msg_parts = [f"Boost: freed {freed_mb} MB RAM ({freed_count} procs in {duration_ms}ms)"]
    if standby_purged:
        msg_parts.append(f"purged {breakdown_before.get('standby_gb', 0)}GB Standby")
    else:
        msg_parts.append(f"Standby {breakdown_before.get('standby_gb', 0)}GB verified")

    if freed_temp_mb > 0 or deleted_files > 0:
        msg_parts.append(f"cleaned {freed_temp_mb} MB Temp ({deleted_files} files)")
    else:
        msg_parts.append("0 Temp files (Clean)")

    add_event("boost", " + ".join(msg_parts))
    return result


# --- Hardening Drift Detector ---
_last_drift_check: str | None = None
_last_drift_result: dict = {}


def get_cached_drift_result() -> dict:
    return dict(_last_drift_result)


def check_hardening_drift() -> dict:
    global _last_drift_check, _last_drift_result
    drift: dict[str, str] = {}
    checks: dict[str, str] = {}

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
        checks["vbs"] = "ok"
    except Exception as exc:
        checks["vbs"] = f"error: {exc}"

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
        drift["MPO"] = "Key missing -- MPO is active (Default)"
        checks["mpo"] = "drift"
    except Exception as exc:
        checks["mpo"] = f"error: {exc}"

    try:
        r_cim = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "(Get-CimInstance -ClassName Win32_ComputerSystem).HypervisorPresent",
            ],
            capture_output=True,
            text=True,
            timeout=8,
        )
        if r_cim.returncode == 0 and r_cim.stdout.strip():
            hv_present = r_cim.stdout.strip().lower()
            if hv_present == "true":
                drift["Hypervisor"] = "Hypervisor is active (Expected: Disabled)"
                checks["hypervisor"] = "drift"
            else:
                checks["hypervisor"] = "ok"
        else:
            result = subprocess.run(
                ["bcdedit", "/enum", "{current}"],
                capture_output=True,
                text=True,
                timeout=8,
            )
            if result.returncode == 0:
                output = result.stdout.lower()
                if "hypervisorlaunchtype" in output:
                    line = output.split("hypervisorlaunchtype")[1].split("\n")[0]
                    if "off" in line:
                        checks["hypervisor"] = "ok"
                    else:
                        drift["Hypervisor"] = "hypervisorlaunchtype is NOT off"
                        checks["hypervisor"] = "drift"
                else:
                    checks["hypervisor"] = "ok"
            else:
                checks["hypervisor"] = "ok"
    except Exception:
        checks["hypervisor"] = "ok"

    try:
        mumu_dir = CONFIG.get("mumu", {}).get("install_path", "C:/Program Files/Netease/MuMuPlayer")
        norm_mumu = os.path.normpath(mumu_dir).lower()
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command", "(Get-MpPreference).ExclusionPath"],
            capture_output=True,
            text=True,
            timeout=8,
        )
        if r.returncode == 0 and r.stdout.strip():
            raw_out = r.stdout.strip()
            if "must be an administrator" in raw_out.lower():
                checks["defender_exclusion"] = "ok"
            else:
                exclusions = [
                    os.path.normpath(line.strip()).lower()
                    for line in raw_out.splitlines()
                    if line.strip()
                ]
                if any(norm_mumu in exc or exc in norm_mumu for exc in exclusions):
                    checks["defender_exclusion"] = "ok"
                else:
                    checks["defender_exclusion"] = "drift"
                    drift["Defender Exclusion"] = "MuMu path missing from Defender exclusions"
        else:
            checks["defender_exclusion"] = "ok"
    except Exception:
        checks["defender_exclusion"] = "ok"

    _last_drift_check = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    _last_drift_result = {
        "drift": drift,
        "checks": checks,
        "has_drift": len(drift) > 0,
        "last_check": _last_drift_check,
    }
    set_drift_detected_flag(len(drift) > 0)

    if drift:
        drift_items = ", ".join(f"{k}: {v}" for k, v in drift.items())
        add_event("warning", f"Hardening drift detected: {drift_items}")
        notifier.notify_sync(
            NotificationEvent(
                event_type="drift",
                severity="warning",
                title="Windows Hardening Drift Detected",
                description=f"Security/display baseline drifted:\n{drift_items}",
                dedupe_key=f"hardening_drift:{','.join(sorted(drift.keys()))}",
                fields=[
                    {
                        "name": "Action Required",
                        "value": "Verify registry settings or re-run setup_network_hardening.ps1",
                        "inline": False,
                    }
                ],
            )
        )

    return _last_drift_result


# --- In-VM Disk Sentinel ---
_vm_disk_cache: list[dict] = []


def get_vm_disk_status() -> list[dict]:
    global _vm_disk_cache
    adb = find_mumu_adb()
    if not adb:
        return []

    mumu_cfg = CONFIG.get("mumu", {})
    base_port = int(mumu_cfg.get("adb_base_port", 16384))
    step = int(mumu_cfg.get("adb_port_step", 32))
    max_inst = int(mumu_cfg.get("max_instances", 10))

    results: list[dict] = []
    for i in range(max_inst):
        port = base_port + (step * i)
        try:
            subprocess.run([str(adb), "connect", f"127.0.0.1:{port}"], capture_output=True, timeout=2)
            r = subprocess.run(
                [str(adb), "-s", f"127.0.0.1:{port}", "shell", "df", "/data"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if r.returncode == 0 and "/data" in r.stdout:
                lines = r.stdout.strip().split("\n")
                if len(lines) >= 2:
                    parts = lines[1].split()
                    if len(parts) >= 5:
                        total_kb = int(parts[1])
                        used_kb = int(parts[2])
                        avail_kb = int(parts[3])
                        use_pct = int(parts[4].replace("%", ""))
                        results.append(
                            {
                                "port": port,
                                "instance": i + 1,
                                "total_gb": round(total_kb / (1024 * 1024), 2),
                                "used_gb": round(used_kb / (1024 * 1024), 2),
                                "avail_gb": round(avail_kb / (1024 * 1024), 2),
                                "used_pct": use_pct,
                                "status": (
                                    "critical"
                                    if use_pct >= CONFIG["maintenance"]["vm_disk_critical_pct"]
                                    else "warning"
                                    if use_pct >= CONFIG["maintenance"]["vm_disk_warn_pct"]
                                    else "ok"
                                ),
                            }
                        )
        except Exception:
            continue

    _vm_disk_cache = results
    set_vm_disk_snapshot(results, datetime.now().strftime("%H:%M:%S"))
    return results


def trim_vm_caches(port: int) -> bool:
    adb = find_mumu_adb()
    if not adb:
        return False
    try:
        r = subprocess.run(
            [str(adb), "-s", f"127.0.0.1:{port}", "shell", "fstrim", "-v", "/data"],
            capture_output=True,
            text=True,
            timeout=12,
        )
        subprocess.run(
            [str(adb), "-s", f"127.0.0.1:{port}", "shell", "rm", "-rf", "/data/local/tmp/*"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if r.returncode == 0:
            add_event("system", f"VM (port {port}) /data filesystem trimmed safely")
            return True
    except Exception:
        pass
    return False


# --- Growth Tracker ---
def _load_growth_data() -> list[dict]:
    if GROWTH_PATH.exists():
        try:
            with open(GROWTH_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data
        except Exception:
            return []
    return []


def _save_growth_data(data: list[dict]) -> None:
    with open(GROWTH_PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data[-120:], f, indent=2, ensure_ascii=False)


_growth_data: list[dict] = _load_growth_data()


def get_growth_data(limit: int = 24) -> list[dict]:
    return list(_growth_data[-limit:]) if _growth_data else []


def snapshot_folder_sizes() -> dict:
    snapshot: dict = {
        "timestamp": datetime.now().isoformat(),
        "folders": {},
        "disks": {},
    }

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
    add_event("system", f"Growth snapshot: {len(snapshot['folders'])} VM folders tracked")
    return snapshot


# --- Defender Maintenance ---
_last_scan_date: date | None = None
_last_scan_verified: date | None = None
_defender_status: dict = {}


def get_cached_defender_status() -> dict:
    return dict(_defender_status)


def _parse_dot_net_date(val: str | int | None) -> datetime | None:
    if not val:
        return None
    if isinstance(val, (int, float)):
        return datetime.fromtimestamp(val / 1000.0)
    match = re.search(r"/Date\((\d+)\)/", str(val))
    if match:
        return datetime.fromtimestamp(int(match.group(1)) / 1000.0)
    try:
        return datetime.fromisoformat(str(val))
    except Exception:
        return None


def format_defender_display_time(dt: datetime | None) -> str:
    if not dt:
        return "Never"
    today = date.today()
    if dt.date() == today:
        return "Today " + dt.strftime("%H:%M")
    if (today - dt.date()).days == 1:
        return "Yesterday " + dt.strftime("%H:%M")
    return dt.strftime("%d/%m %H:%M")


def get_defender_status() -> dict:
    global _defender_status
    try:
        r = subprocess.run(
            [
                "powershell",
                "-Command",
                "(Get-MpComputerStatus | Select-Object "
                "AntivirusSignatureAge, AntivirusSignatureLastUpdated, "
                "QuickScanAge, QuickScanEndTime, QuickScanStartTime, "
                "FullScanAge, RealTimeProtectionEnabled, AntivirusEnabled "
                "| ConvertTo-Json)",
            ],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if r.returncode == 0 and r.stdout.strip():
            data = json.loads(r.stdout.strip())
            sig_age = data.get("AntivirusSignatureAge", -1)

            dt_end = _parse_dot_net_date(data.get("QuickScanEndTime"))
            dt_start = _parse_dot_net_date(data.get("QuickScanStartTime"))
            dt_sig = _parse_dot_net_date(data.get("AntivirusSignatureLastUpdated"))

            duration_str = None
            if dt_end and dt_start and dt_end >= dt_start:
                dur_sec = int((dt_end - dt_start).total_seconds())
                mins, secs = divmod(dur_sec, 60)
                duration_str = f"{mins}m {secs}s" if mins > 0 else f"{secs}s"

            _defender_status = {
                "available": True,
                "signature_age_days": sig_age,
                "signature_stale": sig_age > 3,
                "signature_last_updated": dt_sig.strftime("%Y-%m-%d %H:%M:%S") if dt_sig else "Unknown",
                "signature_display": format_defender_display_time(dt_sig),
                "quick_scan_age_days": data.get("QuickScanAge", -1),
                "quick_scan_time": dt_end.strftime("%Y-%m-%d %H:%M:%S") if dt_end else "Never",
                "quick_scan_display": format_defender_display_time(dt_end),
                "quick_scan_duration": duration_str,
                "full_scan_age_days": data.get("FullScanAge", -1),
                "realtime_enabled": data.get("RealTimeProtectionEnabled", False),
                "antivirus_enabled": data.get("AntivirusEnabled", False),
                "last_check": datetime.now().strftime("%H:%M:%S"),
            }
            if sig_age > 3:
                add_event("warning", f"Defender signatures are {sig_age} days old")
            return _defender_status
    except Exception:
        pass

    _defender_status = {"available": False, "last_check": datetime.now().strftime("%H:%M:%S")}
    return _defender_status


def run_quick_scan() -> bool:
    global _last_scan_date
    for proc in psutil.process_iter(["name"]):
        try:
            if proc.info["name"] and "mpcmdrun" in proc.info["name"].lower():
                add_event("warning", "Defender Scan already in progress -- skipped duplicate launch")
                return False
        except Exception:
            continue

    try:
        subprocess.Popen(
            ["powershell", "-Command", "Start-MpScan -ScanType 1"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        _last_scan_date = date.today()
        add_event("system", "Defender Quick Scan started in background")
        return True
    except Exception:
        return False


def scan_downloads_folder() -> int:
    downloads = Path.home() / "Downloads"
    if not downloads.exists():
        return 0

    sweep_minutes = int(CONFIG.get("maintenance", {}).get("downloads_sweep_minutes", 30))
    cutoff = time.time() - (sweep_minutes * 60)
    scanned = 0

    for f in downloads.iterdir():
        if f.is_file() and f.stat().st_mtime > cutoff:
            try:
                subprocess.Popen(
                    ["powershell", "-Command", f'Start-MpScan -ScanType 3 -ScanPath "{f}"'],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                scanned += 1
            except Exception:
                continue

    if scanned > 0:
        add_event("system", f"Scanned {scanned} new file(s) in Downloads")
    return scanned


# --- RAM Critical Evaluation & Loops ---
_last_scheduled_slot: str | None = None


def check_and_alert_ram_critical(mem_percent: float, used_bytes: int, total_bytes: int, mode: str) -> bool:
    if mem_percent < 90.0:
        return False
    used_gb = round(used_bytes / (1024 ** 3), 1)
    total_gb = round(total_bytes / (1024 ** 3), 1)
    return notifier.notify_sync(
        NotificationEvent(
            event_type="ram_critical",
            severity="critical",
            title="System RAM Critical (>=90%)",
            description=(
                f"System RAM reached {mem_percent}% ({used_gb} GB / {total_gb} GB) "
                f"in {mode} boost mode."
            ),
            dedupe_key="ram_critical",
            fields=[
                {"name": "Memory Usage", "value": f"{mem_percent}% ({used_gb}/{total_gb} GB)", "inline": True},
                {"name": "Boost Mode", "value": mode, "inline": True},
            ],
        )
    )


async def auto_boost_loop() -> None:
    global _last_scheduled_slot
    last_ram_alert_ts = 0.0
    while True:
        try:
            cfg = CONFIG.get("auto_boost", {})
            if not cfg.get("enabled", False):
                await asyncio.sleep(5)
                continue

            mode = str(cfg.get("mode", "auto"))
            mem = psutil.virtual_memory()
            min_alert_interval = max(
                30, int(CONFIG.get("alerts", {}).get("min_alert_interval_seconds", 60))
            )
            now_ts = time.time()
            if mem.percent >= 90.0:
                if (now_ts - last_ram_alert_ts) >= min_alert_interval:
                    if check_and_alert_ram_critical(mem.percent, mem.used, mem.total, mode):
                        last_ram_alert_ts = now_ts
            elif mem.percent < 85.0:
                last_ram_alert_ts = 0.0

            should_boost = False
            if mode == "auto" and mem.percent >= cfg.get("threshold_percent", 85):
                should_boost = True
                add_event("warning", f"RAM threshold {cfg['threshold_percent']}% reached ({mem.percent}%)")
            elif mode == "scheduled":
                interval_min = max(1, int(cfg.get("interval_minutes", 30)))
                now_dt = datetime.now()
                current_slot = f"{now_dt.strftime('%Y-%m-%d %H')}:{now_dt.minute}"
                if (now_dt.minute % interval_min == 0) and _last_scheduled_slot != current_slot:
                    _last_scheduled_slot = current_slot
                    slot_desc = f"(every {interval_min}m)"
                    ram_breakdown = get_ram_breakdown()
                    thresh = cfg.get("threshold_percent", 80)
                    needs_ram_trim = (mem.percent >= thresh) or (ram_breakdown.get("available_gb", 0.0) < 4.0)
                    needs_standby_purge = should_purge_standby_gate(
                        ram_breakdown.get("free_gb", 0.0),
                        ram_breakdown.get("standby_gb", 0.0),
                        ram_breakdown.get("available_gb", 0.0),
                    )
                    if needs_ram_trim or needs_standby_purge:
                        should_boost = True
                        add_event(
                            "info",
                            f"Scheduled Clock-Aligned Boost {slot_desc} triggered -- RAM {mem.percent}%, Standby {ram_breakdown.get('standby_gb', 0)}GB",
                        )
                    else:
                        add_event(
                            "info",
                            f"Scheduled Boost {slot_desc} skipped -- Memory Healthy: RAM {mem.percent}%, Available {ram_breakdown.get('available_gb', 0)}GB",
                        )

            if should_boost:
                result = await asyncio.to_thread(ram_boost, False)
                broadcast_payload_threadsafe({"type": "boost_triggered", "result": result})
                summary = await asyncio.to_thread(get_session_summary)
                broadcast_payload_threadsafe({"type": "session_summary", "data": summary})

            delay = 1.0 - (datetime.now().microsecond / 1_000_000)
            await asyncio.sleep(max(0.05, delay))
        except asyncio.CancelledError:
            break
        except Exception as exc:
            add_event("error", f"Auto-boost loop error: {exc}")
            await asyncio.sleep(5)


async def autonomous_standby_loop() -> None:
    while True:
        try:
            cfg = CONFIG.get("maintenance", {})
            min_standby = float(cfg.get("standby_purge_min_standby_gb", 4.0))
            min_free = float(cfg.get("standby_purge_min_free_gb", 1.5))

            ram = get_ram_breakdown()
            standby_gb = ram.get("standby_gb", 0.0)
            free_gb = ram.get("free_gb", 0.0)

            if standby_gb >= min_standby and free_gb < min_free:
                success = await asyncio.to_thread(purge_standby_list)
                if success:
                    record_standby_purge(standby_gb)
                    new_ram = get_ram_breakdown()
                    add_event(
                        "standby",
                        f"Standby Guard: Auto-purged {standby_gb:.2f} GB cache -- Free RAM restored to {new_ram.get('free_gb', 0):.2f} GB",
                    )
                    summary = await asyncio.to_thread(get_session_summary)
                    broadcast_payload_threadsafe({"type": "session_summary", "data": summary})

            await asyncio.sleep(2)
        except asyncio.CancelledError:
            break
        except Exception:
            await asyncio.sleep(5)


async def maintenance_loop() -> None:
    global _last_scan_verified
    last_drift_check = 0.0
    last_vm_disk_check = 0.0
    last_hog_check = 0.0
    last_growth_snapshot = 0.0
    last_defender_check = 0.0
    last_downloads_sweep = 0.0
    last_watchdog_check = 0.0
    last_discord_purge = time.time()
    last_seen_recovered_line: str | None = None
    watchdog_baseline_set = False

    await asyncio.sleep(5)

    try:
        await asyncio.to_thread(check_hardening_drift)
    except Exception as exc:
        add_event("error", f"Drift check failed: {exc}")

    try:
        count = await asyncio.to_thread(disable_ecoqos_for_mumu)
        if count > 0:
            add_event("system", f"Anti-EcoQoS applied to {count} MuMu process(es)")
    except Exception:
        pass

    try:
        await asyncio.to_thread(get_defender_status)
    except Exception:
        pass

    while True:
        try:
            now = time.time()
            maint_cfg = CONFIG.get("maintenance", {})

            drift_interval = int(maint_cfg.get("drift_check_hours", 1)) * 3600
            if now - last_drift_check >= drift_interval:
                try:
                    result = await asyncio.to_thread(check_hardening_drift)
                    broadcast_payload_threadsafe({"type": "hardening_status", "data": result})
                except Exception:
                    pass
                last_drift_check = now

            if now - last_vm_disk_check >= 900:
                try:
                    vm_data = await asyncio.to_thread(get_vm_disk_status)
                    if maint_cfg.get("vm_auto_trim", True):
                        crit_pct = int(maint_cfg.get("vm_disk_critical_pct", 90))
                        warn_pct = int(maint_cfg.get("vm_disk_warn_pct", 85))
                        for vm in vm_data:
                            if vm["used_pct"] >= warn_pct:
                                await asyncio.to_thread(trim_vm_caches, vm["port"])
                                await asyncio.sleep(2)
                                updated = await asyncio.to_thread(get_vm_disk_status)
                                for u in updated:
                                    if u["port"] == vm["port"] and u["used_pct"] >= crit_pct:
                                        add_event(
                                            "crash",
                                            f"VM #{u['instance']} disk CRITICAL at {u['used_pct']}% after trim",
                                        )
                                        notifier.enqueue(
                                            NotificationEvent(
                                                event_type="vm_disk_critical",
                                                severity="critical",
                                                title="MuMu VM Disk Critical",
                                                description=(
                                                    f"Instance #{u['instance']} /data usage remains at "
                                                    f"{u['used_pct']}% ({u['used_gb']}/{u['total_gb']} GB) after TRIM."
                                                ),
                                                dedupe_key=f"vm_disk:{u['instance']}",
                                                fields=[
                                                    {"name": "Instance", "value": f"#{u['instance']} (port {u['port']})", "inline": True},
                                                    {"name": "Usage", "value": f"{u['used_pct']}%", "inline": True},
                                                ],
                                            )
                                        )
                                vm_data = updated
                    broadcast_payload_threadsafe({"type": "vm_disk_status", "data": vm_data})
                except Exception:
                    pass
                last_vm_disk_check = now

            if now - last_watchdog_check >= 60:
                try:
                    wd = await asyncio.to_thread(get_watchdog_status)
                    latest_rec = wd.get("latest_recovered_line")
                    if not watchdog_baseline_set:
                        last_seen_recovered_line = latest_rec
                        watchdog_baseline_set = True
                    elif latest_rec and latest_rec != last_seen_recovered_line:
                        last_seen_recovered_line = latest_rec
                        add_event("system", f"Network Watchdog recovery detected: {latest_rec}")
                        notifier.enqueue(
                            NotificationEvent(
                                event_type="net_outage",
                                severity="recovery",
                                title="Network Connectivity Restored",
                                description=f"Standalone network watchdog reported recovery:\n`{latest_rec}`",
                                dedupe_key=f"net_outage:{latest_rec[:21]}",
                            )
                        )
                except Exception:
                    pass
                last_watchdog_check = now

            if now - last_hog_check >= 60:
                try:
                    await asyncio.to_thread(detect_and_throttle_hogs)
                except Exception:
                    pass
                last_hog_check = now

            growth_interval = int(maint_cfg.get("growth_snapshot_hours", 6)) * 3600
            if now - last_growth_snapshot >= growth_interval:
                try:
                    await asyncio.to_thread(snapshot_folder_sizes)
                except Exception:
                    pass
                last_growth_snapshot = now

            if now - last_defender_check >= 3600:
                try:
                    status = await asyncio.to_thread(get_defender_status)
                    broadcast_payload_threadsafe({"type": "defender_status", "data": status})
                except Exception:
                    pass
                last_defender_check = now

            current_hour = datetime.now().hour
            current_minute = datetime.now().minute
            scan_hour = int(maint_cfg.get("defender_scan_hour", 4))
            if current_hour == scan_hour and _last_scan_date != date.today():
                try:
                    await asyncio.to_thread(run_quick_scan)
                except Exception:
                    pass

            if current_hour == scan_hour and current_minute >= 30 and _last_scan_verified != date.today():
                status = await asyncio.to_thread(get_defender_status)
                if status.get("quick_scan_age_days", -1) == 0:
                    add_event("system", "Defender Quick Scan completed and verified")
                    _last_scan_verified = date.today()

            sweep_interval = int(maint_cfg.get("downloads_sweep_minutes", 30)) * 60
            if now - last_downloads_sweep >= sweep_interval:
                try:
                    await asyncio.to_thread(scan_downloads_folder)
                except Exception:
                    pass
                last_downloads_sweep = now

            purge_interval = max(1, int(CONFIG.get("alerts", {}).get("auto_purge_interval_hours", 6))) * 3600
            if now - last_discord_purge >= purge_interval:
                try:
                    await run_auto_discord_purge(on_startup=False)
                except Exception:
                    pass
                last_discord_purge = now

            await asyncio.sleep(10)
        except asyncio.CancelledError:
            break
        except Exception as exc:
            add_event("error", f"Maintenance loop error: {exc}")
            await asyncio.sleep(30)
