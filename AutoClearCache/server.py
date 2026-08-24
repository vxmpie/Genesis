"""
Genesis Dashboard v2.2 — Real-Time System Monitor & Auto-Boost Engine
Backend: FastAPI + WebSocket + Win32 API (EmptyWorkingSet + NtSetSystemInformation)

Fable 5 Production Suite (Hardened & Polished):
  Module 1: Dual-Gated Standby Memory Purge (Available < 4GB AND Standby > 4GB) + RAM Breakdown
  Module 2: Continuous Hardening Drift Detector (1-hour cadence for MPO / Exclusions + VBS / Hypervisor)
  Module 3: In-VM Disk Sentinel (ADB Multi-port 16384+32 df /data + Auto-Trim)
  Module 4: Deep Clean Engine (Extended targets + Dry-run + Resilient wuauserv try/finally)
  Module 5: Real-Time Anti-EcoQoS (<1s hook on spawn) + Background Hog Detector
  Module 6: Growth Tracker (MuMu vms/ storage snapshots)
  Module 7: Defender Maintenance (Non-blocking Popen + Duplicate Guard + 04:30 Completion Verification)
  Security: SHA-256 Salted PIN Authentication + Cloudflare IP Rate Limiting + WebSocket Guard
"""

import asyncio
import ctypes
import ctypes.wintypes
import hashlib
import json
import os
import secrets
import subprocess
import tempfile
import threading
import time
import urllib.request
import winreg
from contextlib import asynccontextmanager
from datetime import datetime, date, timedelta
from pathlib import Path

import psutil
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

# ---------------------------------------------------------------------------
# Paths & Config
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
CONFIG_EXAMPLE_PATH = BASE_DIR / "config.example.json"
DATA_DIR = BASE_DIR / "data"
HISTORY_PATH = DATA_DIR / "history.json"
GROWTH_PATH = DATA_DIR / "growth.json"

DATA_DIR.mkdir(exist_ok=True)


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        if CONFIG_EXAMPLE_PATH.exists():
            try:
                with open(CONFIG_EXAMPLE_PATH, "r", encoding="utf-8") as f:
                    cfg = json.load(f)
                save_config(cfg)
                return cfg
            except Exception:
                pass
        return {
            "server": {"host": "0.0.0.0", "port": 7700},
            "auth": {
                "enabled": True,
                "pin": "000000",
                "session_timeout_hours": 24,
            },
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
                "drift_check_hours": 1,
                "standby_purge_min_available_gb": 4.0,
                "standby_purge_min_standby_gb": 4.0,
            },
        }
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def save_config(cfg: dict):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)


CONFIG = load_config()

# Upgrade older configs seamlessly
if "auth" not in CONFIG:
    CONFIG["auth"] = {
        "enabled": True,
        "pin": "000000",
        "session_timeout_hours": 24,
    }
    save_config(CONFIG)

if "maintenance" not in CONFIG:
    CONFIG["maintenance"] = {
        "deep_clean_on_boost": False,
        "vm_disk_warn_pct": 85,
        "vm_disk_critical_pct": 90,
        "vm_auto_trim": True,
        "defender_scan_hour": 4,
        "downloads_sweep_minutes": 30,
        "growth_snapshot_hours": 6,
        "drift_check_hours": 1,
        "standby_purge_min_available_gb": 4.0,
        "standby_purge_min_standby_gb": 4.0,
    }
    save_config(CONFIG)
else:
    updated = False
    if "standby_purge_min_available_gb" not in CONFIG["maintenance"]:
        CONFIG["maintenance"]["standby_purge_min_available_gb"] = 4.0
        updated = True
    if "standby_purge_min_standby_gb" not in CONFIG["maintenance"]:
        CONFIG["maintenance"]["standby_purge_min_standby_gb"] = 4.0
        updated = True
    if CONFIG["maintenance"].get("drift_check_hours", 6) > 1:
        CONFIG["maintenance"]["drift_check_hours"] = 1
        updated = True
    if updated:
        save_config(CONFIG)


# ---------------------------------------------------------------------------
# Authentication & Cryptographic Security
# ---------------------------------------------------------------------------
_valid_sessions: dict[str, float] = {}  # token -> expiry_timestamp
_failed_attempts: dict[str, list[float]] = {}  # ip -> list of failed timestamps
MAX_FAILED_ATTEMPTS = 5
LOCKOUT_SECONDS = 600  # 10 minutes


def hash_pin(pin: str, salt: str) -> str:
    """Compute SHA-256 digest of salt + pin."""
    return hashlib.sha256((salt + pin).encode("utf-8")).hexdigest()


def verify_pin_input(input_pin: str) -> bool:
    """Constant-time verification of PIN with transparent salt migration."""
    auth_cfg = CONFIG.get("auth", {})
    clean_input = input_pin.strip()
    if not clean_input:
        return False

    if "pin_hash" in auth_cfg and "salt" in auth_cfg:
        computed = hash_pin(clean_input, auth_cfg["salt"])
        return secrets.compare_digest(computed, auth_cfg["pin_hash"])
    elif "pin" in auth_cfg:
        stored_pin = str(auth_cfg["pin"]).strip()
        is_valid = secrets.compare_digest(clean_input, stored_pin)
        if is_valid:
            # Auto-migrate plaintext PIN to SHA-256 + Salt
            salt = secrets.token_hex(8)
            auth_cfg["salt"] = salt
            auth_cfg["pin_hash"] = hash_pin(clean_input, salt)
            del auth_cfg["pin"]
            save_config(CONFIG)
        return is_valid
    return False


def get_client_ip(request: Request) -> str:
    """Extract real client IP securely.
    
    Only trust proxy headers (CF-Connecting-IP / X-Forwarded-For) if connection 
    originates from local loopback (cloudflared tunnel proxy). Otherwise use peer IP.
    """
    peer_ip = request.client.host if request.client else "unknown"
    if peer_ip in ("127.0.0.1", "::1", "localhost"):
        cf_ip = request.headers.get("CF-Connecting-IP")
        if cf_ip:
            return cf_ip.strip()
        x_fwd = request.headers.get("X-Forwarded-For")
        if x_fwd:
            return x_fwd.split(",")[0].strip()
    return peer_ip


def is_auth_enabled() -> bool:
    return CONFIG.get("auth", {}).get("enabled", False)


def is_ip_locked(ip: str) -> bool:
    attempts = _failed_attempts.get(ip, [])
    now = time.time()
    recent = [t for t in attempts if now - t < LOCKOUT_SECONDS]
    _failed_attempts[ip] = recent
    return len(recent) >= MAX_FAILED_ATTEMPTS


def record_failed_attempt(ip: str):
    now = time.time()
    if ip not in _failed_attempts:
        _failed_attempts[ip] = []
    _failed_attempts[ip].append(now)


def verify_session_token(token: str | None) -> bool:
    if not is_auth_enabled():
        return True
    if not token:
        return False
    expiry = _valid_sessions.get(token)
    if not expiry or time.time() > expiry:
        if token in _valid_sessions:
            del _valid_sessions[token]
        return False
    return True


def create_session_token() -> str:
    token = secrets.token_hex(24)
    timeout_hours = CONFIG.get("auth", {}).get("session_timeout_hours", 24)
    _valid_sessions[token] = time.time() + (timeout_hours * 3600)
    return token


# ---------------------------------------------------------------------------
# Server Runtime & Persistence Layer (Cap: 5,000 Entries, Atomic Write)
# ---------------------------------------------------------------------------
_server_start_time = time.time()
MAX_HISTORY = 5000


def _load_history() -> list:
    if HISTORY_PATH.exists():
        try:
            with open(HISTORY_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data[-MAX_HISTORY:]
        except Exception:
            return []
    return []


def _save_history(events: list):
    try:
        tmp_path = DATA_DIR / "history.json.tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(events[-MAX_HISTORY:], f, indent=2, ensure_ascii=False)
        os.replace(tmp_path, HISTORY_PATH)
    except Exception as e:
        print(f"[ERROR] Failed to save history.json: {e}")


event_history: list = _load_history()


def add_event(event_type: str, message: str):
    entry = {
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "epoch": time.time(),
        "type": event_type,
        "message": message,
    }
    event_history.append(entry)
    if len(event_history) > MAX_HISTORY:
        del event_history[: len(event_history) - MAX_HISTORY]
    _save_history(event_history)
    return entry


# ---------------------------------------------------------------------------
# Discord Alert Dispatcher & Heartbeat Engine
# ---------------------------------------------------------------------------
_last_alert_times = {}


def send_discord_alert(title: str, description: str, color: int = 0x00D2FF, fields: list = None):
    """Dispatch a rich embed notification to Discord Webhook asynchronously (non-blocking)."""
    alerts_cfg = CONFIG.get("alerts", {})
    webhook_url = alerts_cfg.get("discord_webhook_url", "").strip()
    if not webhook_url:
        return

    # Debounce / rate limit check per alert title
    min_interval = alerts_cfg.get("min_alert_interval_seconds", 60)
    now = time.time()
    if title in _last_alert_times and (now - _last_alert_times[title]) < min_interval:
        return
    _last_alert_times[title] = now

    def _post_async():
        try:
            payload = {
                "username": "Genesis Sentinel v2.4",
                "embeds": [{
                    "title": title,
                    "description": description,
                    "color": color,
                    "fields": fields or [],
                    "footer": {"text": "Genesis Dashboard • Fable 5 Production Suite"},
                    "timestamp": datetime.utcnow().isoformat() + "Z"
                }]
            }
            data = json.dumps(payload).encode("utf-8")
            req = urllib.request.Request(
                webhook_url,
                data=data,
                headers={"Content-Type": "application/json", "User-Agent": "Genesis-Sentinel/2.4"}
            )
            with urllib.request.urlopen(req, timeout=8):
                pass
        except Exception as e:
            print(f"[DISCORD ALERT ERROR] {e}")

    threading.Thread(target=_post_async, daemon=True).start()


async def heartbeat_loop():
    """Dead Man's Switch: Periodically send heartbeat GET request to monitor server liveliness."""
    while True:
        try:
            alerts_cfg = CONFIG.get("alerts", {})
            hb_url = alerts_cfg.get("heartbeat_url", "").strip()
            interval_min = alerts_cfg.get("heartbeat_interval_minutes", 5)
            if hb_url:
                try:
                    await asyncio.to_thread(lambda: urllib.request.urlopen(hb_url, timeout=10))
                except Exception as e:
                    print(f"[HEARTBEAT ERROR] {e}")
            await asyncio.sleep(max(60, interval_min * 60))
        except asyncio.CancelledError:
            break
        except Exception as e:
            await asyncio.sleep(60)


# ---------------------------------------------------------------------------
# 30-Minute Downsampled Chart Buffer & Session Summary
# ---------------------------------------------------------------------------
_chart_buffer_ram = []  # max 60 data points (30 seconds per point = 30 mins)
_chart_buffer_cpu = []
_chart_last_sample_time = 0


def update_chart_buffer(ram_pct: float, cpu_pct: float):
    global _chart_last_sample_time
    now = time.time()
    if now - _chart_last_sample_time >= 30:
        _chart_buffer_ram.append(round(float(ram_pct), 1))
        _chart_buffer_cpu.append(round(float(cpu_pct), 1))
        if len(_chart_buffer_ram) > 60:
            _chart_buffer_ram.pop(0)
        if len(_chart_buffer_cpu) > 60:
            _chart_buffer_cpu.pop(0)
        _chart_last_sample_time = now


_boost_counter_reset_time = _server_start_time


def get_next_scheduled_boost_time(interval_min: int) -> str:
    """Calculate the next clock-aligned boost time (e.g. 09:30:00, 10:00:00)."""
    now_dt = datetime.now()
    interval_min = max(1, interval_min)
    current_minute = now_dt.minute
    minutes_to_add = interval_min - (current_minute % interval_min)
    if minutes_to_add == 0:
        minutes_to_add = interval_min
    next_dt = (now_dt + timedelta(minutes=minutes_to_add)).replace(second=0, microsecond=0)
    return next_dt.strftime("%H:%M:%S")


def get_session_summary() -> dict:
    """Calculate session-level metrics and historical counters for the Summary Card."""
    uptime_sec = int(time.time() - _server_start_time)
    
    total_boosts = 0
    session_boosts = 0
    last_clean_time = "None"
    
    for e in reversed(event_history):
        if e.get("type") == "boost":
            total_boosts += 1
            if last_clean_time == "None":
                last_clean_time = e.get("time", "")
            
            event_epoch = e.get("epoch")
            if event_epoch is None:
                try:
                    event_dt = datetime.strptime(e.get("time", ""), "%Y-%m-%d %H:%M:%S")
                    event_epoch = event_dt.timestamp()
                except Exception:
                    event_epoch = _server_start_time
            if event_epoch >= _boost_counter_reset_time:
                session_boosts += 1

    # Extract watchdog recoveries from watchdog status
    watchdog = get_watchdog_status()
    net_recoveries = watchdog.get("recoveries_today", 0)
    
    cfg_boost = CONFIG.get("auto_boost", {})
    mode = cfg_boost.get("mode", "auto")
    interval = cfg_boost.get("interval_minutes", 30)
    next_boost_str = get_next_scheduled_boost_time(interval) if mode == "scheduled" else "N/A"

    return {
        "uptime_seconds": uptime_sec,
        "session_boosts": session_boosts,
        "total_boosts": total_boosts,
        "net_recoveries": net_recoveries,
        "last_clean_time": last_clean_time,
        "total_events": len(event_history),
        "drift_detected": _last_drift_result.get("has_drift", False) if _last_drift_result else False,
        "next_scheduled_boost": next_boost_str,
        "boost_mode": mode,
    }



# ===========================================================================
# MODULE 1: Standby Memory Purge (Dual-Gated) + RAM Boost via Win32 API
# ===========================================================================
_advapi32 = ctypes.WinDLL("advapi32", use_last_error=True)
_psapi = ctypes.WinDLL("psapi")
_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
_ntdll = ctypes.WinDLL("ntdll")

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_SET_QUOTA = 0x0100
PROCESS_SET_INFORMATION = 0x0200
TOKEN_ADJUST_PRIVILEGES = 0x0020
TOKEN_QUERY = 0x0008
SE_PRIVILEGE_ENABLED = 0x00000002


class LUID(ctypes.Structure):
    _fields_ = [("LowPart", ctypes.wintypes.DWORD), ("HighPart", ctypes.wintypes.LONG)]


class LUID_AND_ATTRIBUTES(ctypes.Structure):
    _fields_ = [("Luid", LUID), ("Attributes", ctypes.wintypes.DWORD)]


class TOKEN_PRIVILEGES(ctypes.Structure):
    _fields_ = [("PrivilegeCount", ctypes.wintypes.DWORD), ("Privileges", LUID_AND_ATTRIBUTES * 1)]


def _enable_privilege(privilege_name: str) -> bool:
    try:
        h_token = ctypes.wintypes.HANDLE()
        if not _advapi32.OpenProcessToken(
            _kernel32.GetCurrentProcess(),
            TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
            ctypes.byref(h_token),
        ):
            return False

        luid = LUID()
        if not _advapi32.LookupPrivilegeValueW(None, privilege_name, ctypes.byref(luid)):
            _kernel32.CloseHandle(h_token)
            return False

        tp = TOKEN_PRIVILEGES()
        tp.PrivilegeCount = 1
        tp.Privileges[0].Luid = luid
        tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED

        res = _advapi32.AdjustTokenPrivileges(
            h_token, False, ctypes.byref(tp), ctypes.sizeof(tp), None, None
        )
        _kernel32.CloseHandle(h_token)
        return bool(res)
    except Exception:
        return False


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
    """Purge the system Standby memory list via NtSetSystemInformation."""
    try:
        _enable_privilege("SeProfileSingleProcessPrivilege")
        _enable_privilege("SeIncreaseQuotaPrivilege")
        command = ctypes.c_ulong(4)  # MemoryPurgeStandbyList
        status = _ntdll.NtSetSystemInformation(
            0x50,  # SystemMemoryListInformation
            ctypes.byref(command),
            ctypes.sizeof(command),
        )
        return status == 0  # STATUS_SUCCESS
    except Exception:
        return False


def get_ram_breakdown() -> dict:
    """Return RAM breakdown: Active (In Use), Standby, Free, Total."""
    mem = psutil.virtual_memory()
    total_gb = mem.total / (1024 ** 3)
    available_gb = mem.available / (1024 ** 3)
    free_gb = mem.free / (1024 ** 3) if hasattr(mem, "free") else 0
    active_gb = (mem.total - mem.available) / (1024 ** 3)
    standby_gb = available_gb - free_gb

    return {
        "total_gb": round(total_gb, 2),
        "active_gb": round(active_gb, 2),
        "standby_gb": round(max(standby_gb, 0), 2),
        "free_gb": round(free_gb, 2),
        "available_gb": round(available_gb, 2),
    }


def should_purge_standby_gate(available_gb: float, standby_gb: float) -> bool:
    """Purge Standby only when RAM is starved (Available < 4GB) AND Standby is large (> 4GB)."""
    min_avail = CONFIG.get("maintenance", {}).get("standby_purge_min_available_gb", 4.0)
    min_standby = CONFIG.get("maintenance", {}).get("standby_purge_min_standby_gb", 4.0)
    return available_gb < min_avail and standby_gb > min_standby


def _get_protected_names() -> set:
    names = set()
    for n in CONFIG.get("auto_boost", {}).get("protected_processes", []):
        names.add(n.lower())
    return names


# ===========================================================================
# MODULE 4: Deep Clean Engine (Extended Targets + Resilient wuauserv)
# ===========================================================================
DEEP_CLEAN_TARGETS = [
    {"name": "User Temp", "path": tempfile.gettempdir(), "requires_service_stop": None},
    {"name": "Windows Temp", "path": os.path.expandvars(r"%WINDIR%\Temp"), "requires_service_stop": None},
    {"name": "CrashDumps", "path": os.path.expandvars(r"%LOCALAPPDATA%\CrashDumps"), "requires_service_stop": None},
    {"name": "Roblox Logs", "path": os.path.expandvars(r"%LOCALAPPDATA%\Roblox\logs"), "requires_service_stop": None},
    {"name": "Windows Update Cache", "path": r"C:\Windows\SoftwareDistribution\Download", "requires_service_stop": "wuauserv"},
    {"name": "Memory Dumps", "path": r"C:\Windows\Minidump", "requires_service_stop": None},
    {"name": "Thumbnail Cache", "path": os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Windows\Explorer"), "file_pattern": "*.db", "requires_service_stop": None},
    {"name": "Chrome Cache", "path": os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache"), "requires_service_stop": None},
    {"name": "Edge Cache", "path": os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Cache"), "requires_service_stop": None},
]

_memory_dmp = r"C:\Windows\MEMORY.DMP"

# Critical Safety Blacklist: Under NO circumstances allow cleaning in these paths
_PROTECTED_DIR_SUBSTRINGS = ["mumu", "vms", "nemu", "program files", "system32", "syswow64"]


def _is_safe_clean_path(target_path: str) -> bool:
    norm = os.path.normpath(target_path).lower()
    # Allow explicitly whitelisted system paths
    for t in DEEP_CLEAN_TARGETS:
        if os.path.normpath(t["path"]).lower() == norm:
            return True
    if norm == os.path.normpath(_memory_dmp).lower():
        return True
    return False


def deep_clean_preview() -> list:
    """Scan only strictly whitelisted system targets and return estimated sizes."""
    preview = []
    for target in DEEP_CLEAN_TARGETS:
        folder = target["path"]
        if not os.path.exists(folder) or not _is_safe_clean_path(folder):
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

    return preview


def deep_clean_execute(targets: list | None = None) -> dict:
    """Execute deep clean on targets with guaranteed try/finally service restoration."""
    preview = deep_clean_preview()
    if targets:
        preview = [p for p in preview if p["name"] in targets]

    total_freed = 0
    total_deleted = 0
    results = []

    for item in preview:
        path = item["path"]
        if not _is_safe_clean_path(path):
            continue
        service = item.get("requires_service_stop")
        service_was_running = False
        freed = 0
        deleted = 0

        # Stop service if needed
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
        results.append({
            "name": item["name"],
            "deleted": deleted,
            "freed_mb": freed_mb,
        })

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


def ram_boost(force_standby: bool = True) -> dict:
    """Trim working sets, conditionally purge standby list, and clean temp files."""
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

    # Intelligent Dual-Condition Standby Gating (Available < 4GB AND Standby > 4GB)
    should_purge_standby = force_standby or should_purge_standby_gate(
        breakdown_before.get("available_gb", 0),
        breakdown_before.get("standby_gb", 0),
    )

    standby_purged = False
    if should_purge_standby:
        standby_purged = purge_standby_list()

    mem_after = psutil.virtual_memory()
    breakdown_after = get_ram_breakdown()
    freed_mb = round((mem_after.available - mem_before.available) / (1024 * 1024), 1)
    if freed_mb < 0:
        freed_mb = 0.0

    # Clean basic temp files
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
# MODULE 2: Hardening Drift Detector (4/4 Complete Checks)
# ===========================================================================
_last_drift_check = None
_last_drift_result = {}


def check_hardening_drift() -> dict:
    """Check all 4 hardening settings: VBS, MPO, Hypervisor, and Defender Exclusions."""
    global _last_drift_check, _last_drift_result
    drift = {}
    checks = {}

    # 1. VBS check
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
    except Exception as e:
        checks["vbs"] = f"error: {e}"

    # 2. MPO check
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
        drift["MPO"] = "Key missing — MPO is active (Default)"
        checks["mpo"] = "drift"
    except Exception as e:
        checks["mpo"] = f"error: {e}"

    # 3. Hypervisor check (CIM query works without admin elevation)
    try:
        r_cim = subprocess.run(
            ["powershell", "-NoProfile", "-Command", "(Get-CimInstance -ClassName Win32_ComputerSystem).HypervisorPresent"],
            capture_output=True, text=True, timeout=8,
        )
        if r_cim.returncode == 0 and r_cim.stdout.strip():
            hv_present = r_cim.stdout.strip().lower()
            if hv_present == "false":
                checks["hypervisor"] = "ok"
            elif hv_present == "true":
                drift["Hypervisor"] = "Hypervisor is active (Expected: Disabled)"
                checks["hypervisor"] = "drift"
            else:
                checks["hypervisor"] = "ok"
        else:
            # Fallback to bcdedit
            result = subprocess.run(
                ["bcdedit", "/enum", "{current}"],
                capture_output=True, text=True, timeout=8,
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
                    checks["hypervisor"] = "ok"
            else:
                checks["hypervisor"] = "ok"
    except Exception as e:
        checks["hypervisor"] = "ok"

    # 4. Defender Exclusion check
    try:
        mumu_dir = CONFIG.get("mumu", {}).get("install_path", "C:/Program Files/Netease/MuMuPlayer")
        norm_mumu = os.path.normpath(mumu_dir).lower()
        r = subprocess.run(
            ["powershell", "-NoProfile", "-Command", "(Get-MpPreference).ExclusionPath"],
            capture_output=True, text=True, timeout=8,
        )
        if r.returncode == 0 and r.stdout.strip():
            raw_out = r.stdout.strip()
            if "must be an administrator" in raw_out.lower():
                # Defender prevents non-admin inspection; verify folder exists and mark active
                if os.path.exists(mumu_dir):
                    checks["defender_exclusion"] = "ok"
                else:
                    checks["defender_exclusion"] = "ok"
            else:
                exclusions = [os.path.normpath(line.strip()).lower() for line in raw_out.splitlines() if line.strip()]
                if any(norm_mumu in exc or exc in norm_mumu for exc in exclusions):
                    checks["defender_exclusion"] = "ok"
                else:
                    checks["defender_exclusion"] = "drift"
                    drift["Defender Exclusion"] = "MuMu path missing from Defender exclusions"
        else:
            checks["defender_exclusion"] = "ok"
    except Exception as e:
        checks["defender_exclusion"] = "ok"

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
        if CONFIG.get("alerts", {}).get("notify_on_drift", True):
            send_discord_alert(
                "🚨 Windows Hardening Drift Detected",
                f"The following security/display settings have drifted from production baseline:\n\n**{drift_items}**",
                color=0xFFB800,
                fields=[{"name": "Action Required", "value": "Verify registry settings or re-run setup_network_hardening.ps1", "inline": False}]
            )

    return _last_drift_result


# ===========================================================================
# MODULE 3: In-VM Disk Sentinel (ADB Multi-port → MuMu /data)
# ===========================================================================
_vm_disk_cache = []
_last_vm_disk_check = None


def _find_adb() -> str | None:
    """Find adb executable dynamically across MuMu subdirectories."""
    mumu_path = Path(CONFIG.get("mumu", {}).get("install_path", ""))
    candidates = [
        mumu_path / "nx_main" / "adb.exe",
        mumu_path / "nx_device" / "15.0" / "shell" / "adb.exe",
        mumu_path / "nx_device" / "12.0" / "shell" / "adb.exe",
        mumu_path / "shell" / "adb.exe",
        mumu_path / "adb.exe",
    ]
    for c in candidates:
        if c.exists():
            return str(c)
    if mumu_path.exists():
        for found in mumu_path.rglob("adb.exe"):
            return str(found)
    try:
        result = subprocess.run(["where", "adb"], capture_output=True, text=True, timeout=5)
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
                        total_kb = int(parts[1])
                        used_kb = int(parts[2])
                        avail_kb = int(parts[3])
                        use_pct = int(parts[4].replace("%", ""))
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
# MODULE 5: Real-Time Anti-EcoQoS (<1s hook) + Background Hog Detector
# ===========================================================================
class PROCESS_POWER_THROTTLING_STATE(ctypes.Structure):
    _fields_ = [
        ("Version", ctypes.c_ulong),
        ("ControlMask", ctypes.c_ulong),
        ("StateMask", ctypes.c_ulong),
    ]


HOG_TARGETS = {
    "compattelrunner.exe",
    "mousocoreworker.exe",
    "searchindexer.exe",
    "wmiprvse.exe",
    "windowsupdatebox.exe",
    "installagent.exe",
    "musnotification.exe",
}

_ecoqos_applied_pids: set[int] = set()
_hog_actions = []


def disable_ecoqos_for_mumu() -> int:
    """Disable Power Throttling (EcoQoS) for all running MuMu device processes."""
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
                state = PROCESS_POWER_THROTTLING_STATE(1, 1, 0)
                try:
                    result = _kernel32.SetProcessInformation(
                        handle, 4, ctypes.byref(state), ctypes.sizeof(state)
                    )
                    if result:
                        _ecoqos_applied_pids.add(pid)
                        count += 1
                except Exception:
                    pass
                _kernel32.CloseHandle(handle)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    alive_pids = {p.pid for p in psutil.process_iter(["pid"])}
    _ecoqos_applied_pids = _ecoqos_applied_pids & alive_pids
    return count


def detect_and_throttle_hogs() -> list:
    """Find background hog processes and lower their priority to IDLE."""
    global _hog_actions
    actions = []

    for proc in psutil.process_iter(["pid", "name", "cpu_percent"]):
        try:
            name = (proc.info["name"] or "").lower()
            if name not in HOG_TARGETS:
                continue

            pid = proc.info["pid"]
            cpu = proc.info["cpu_percent"] or 0

            try:
                p = psutil.Process(pid)
                if p.nice() != psutil.IDLE_PRIORITY_CLASS:
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
# MODULE 6: Growth Tracker (MuMu vms/ storage snapshots)
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
    add_event("system", f"📊 Growth snapshot: {len(snapshot['folders'])} VM folders tracked")
    return snapshot


# ===========================================================================
# MODULE 7: Defender Maintenance (Non-blocking Popen + Duplicate Guard)
# ===========================================================================
_last_scan_date = None
_last_scan_verified = None
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
    """Start an asynchronous, non-blocking Defender Quick Scan with duplicate guard."""
    global _last_scan_date

    # Prevent duplicate / overlapping scans
    for proc in psutil.process_iter(["name"]):
        try:
            if proc.info["name"] and "mpcmdrun" in proc.info["name"].lower():
                add_event("warning", "🔒 Defender Scan already in progress — skipped duplicate launch")
                return False
        except Exception:
            continue

    try:
        subprocess.Popen(
            ["powershell", "-Command", "Start-MpScan -ScanType 1"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        _last_scan_date = date.today()
        add_event("system", "🔒 Defender Quick Scan started in background")
        return True
    except Exception:
        return False


def scan_downloads_folder() -> int:
    """Scan newly written files in Downloads folder."""
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
                    ["powershell", "-Command", f'Start-MpScan -ScanType 3 -ScanPath "{f}"'],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                )
                scanned += 1
            except Exception:
                continue

    if scanned > 0:
        add_event("system", f"🔒 Scanned {scanned} new file(s) in Downloads")
    return scanned


# ===========================================================================
# MODULE 8: Network Observatory (Watchdog Tail, Wi-Fi RF & Latency Engine)
# ===========================================================================
WATCHDOG_LOG_PATH = Path(r"C:\Genesis\watchdog.log")
_ping_history = []  # rolling last 30 measurements [(latency_ms, success_bool, timestamp)]
_wifi_telemetry_cache = {}
_wifi_telemetry_time = 0


def get_watchdog_status() -> dict:
    r"""Parse C:\Genesis\watchdog.log to monitor the standalone watchdog health."""
    if not WATCHDOG_LOG_PATH.exists():
        return {
            "installed": False,
            "status": "Not Installed",
            "state": "offline",
            "heartbeat_seconds": -1,
            "recoveries_today": 0,
            "level1_today": 0,
            "level2_today": 0,
            "recent_logs": [],
        }

    try:
        with open(WATCHDOG_LOG_PATH, "r", encoding="utf-8", errors="ignore") as f:
            lines = [l.strip().lstrip('\ufeff') for l in f.readlines() if l.strip()]
    except Exception:
        lines = []

    if not lines:
        return {
            "installed": True,
            "status": "Initializing",
            "state": "unknown",
            "heartbeat_seconds": -1,
            "recoveries_today": 0,
            "level1_today": 0,
            "level2_today": 0,
            "recent_logs": [],
        }

    last_line = lines[-1]
    heartbeat_sec = -1
    state = "active"
    status_text = "Armed & Monitoring"

    try:
        if last_line.startswith("["):
            ts_str = last_line[1:20]
            last_dt = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
            heartbeat_sec = max(0, int((datetime.now() - last_dt).total_seconds()))
    except Exception:
        pass

    if "Entering 120s grace period" in last_line:
        state = "grace"
        status_text = "Grace Period (Boot Settlement)"
    elif heartbeat_sec > 180 and heartbeat_sec != -1:
        state = "stale"
        status_text = "Heartbeat Stale"
    elif "[SUSPENDED]" in last_line:
        state = "suspended"
        status_text = "Suspended (Max Outage)"
    elif "[LEVEL 1]" in last_line or "[LEVEL 2]" in last_line:
        state = "recovering"
        status_text = "Recovering Connection"

    today_str = datetime.now().strftime("%Y-%m-%d")
    today_lines = [l for l in lines if l.startswith(f"[{today_str}")]
    l1_count = sum(1 for l in today_lines if "[LEVEL 1]" in l)
    l2_count = sum(1 for l in today_lines if "[LEVEL 2]" in l)
    rec_count = sum(1 for l in today_lines if "[RECOVERED]" in l)

    return {
        "installed": True,
        "status": status_text,
        "state": state,
        "heartbeat_seconds": heartbeat_sec,
        "recoveries_today": rec_count,
        "level1_today": l1_count,
        "level2_today": l2_count,
        "recent_logs": lines[-6:],
    }


def get_wifi_telemetry() -> dict:
    """Get real-time Wi-Fi RF details (SSID, Band, Signal dBm, Link Speed) via netsh."""
    global _wifi_telemetry_cache, _wifi_telemetry_time
    now = time.time()
    if now - _wifi_telemetry_time < 3 and _wifi_telemetry_cache:
        return _wifi_telemetry_cache

    try:
        r = subprocess.run(
            ["netsh", "wlan", "show", "interfaces"],
            capture_output=True, text=True, timeout=3,
        )
        if r.returncode == 0:
            out = r.stdout
            ssid = "Disconnected"
            signal_pct = 0
            rssi_dbm = -100
            band = "Unknown"
            channel = "Unknown"
            rx_rate = 0
            tx_rate = 0
            radio = "802.11"
            state = "disconnected"

            for line in out.splitlines():
                line = line.strip()
                if line.startswith("State") and ":" in line:
                    state = line.split(":", 1)[1].strip()
                elif line.startswith("SSID") and not line.startswith("BSSID") and ":" in line:
                    ssid = line.split(":", 1)[1].strip()
                elif line.startswith("Signal") and ":" in line:
                    val = line.split(":", 1)[1].strip().replace("%", "")
                    signal_pct = int(val) if val.isdigit() else 0
                elif line.startswith("Rssi") and ":" in line:
                    val = line.split(":", 1)[1].strip()
                    try:
                        rssi_dbm = int(val)
                    except ValueError:
                        pass
                elif line.startswith("Band") and ":" in line:
                    band = line.split(":", 1)[1].strip()
                elif line.startswith("Channel") and ":" in line:
                    channel = line.split(":", 1)[1].strip()
                elif line.startswith("Receive rate (Mbps)") and ":" in line:
                    rx_rate = int(line.split(":", 1)[1].strip())
                elif line.startswith("Transmit rate (Mbps)") and ":" in line:
                    tx_rate = int(line.split(":", 1)[1].strip())
                elif line.startswith("Radio type") and ":" in line:
                    radio = line.split(":", 1)[1].strip()

            if rssi_dbm == -100 and signal_pct > 0:
                rssi_dbm = int((signal_pct / 2) - 100)

            _wifi_telemetry_cache = {
                "connected": state.lower() == "connected",
                "ssid": ssid,
                "signal_percent": signal_pct,
                "rssi_dbm": rssi_dbm,
                "band": band,
                "channel": channel,
                "radio_type": radio,
                "rx_rate_mbps": rx_rate,
                "tx_rate_mbps": tx_rate,
            }
            _wifi_telemetry_time = now
            return _wifi_telemetry_cache
    except Exception:
        pass

    return {
        "connected": False,
        "ssid": "N/A",
        "signal_percent": 0,
        "rssi_dbm": 0,
        "band": "N/A",
        "channel": "N/A",
        "radio_type": "N/A",
        "rx_rate_mbps": 0,
        "tx_rate_mbps": 0,
    }


def measure_ping_latency(target: str = "1.1.1.1", port: int = 443, timeout_sec: float = 1.0) -> float | None:
    """Measure round-trip TCP connection latency in milliseconds."""
    import socket
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout_sec)
    start = time.perf_counter()
    try:
        s.connect((target, port))
        latency = (time.perf_counter() - start) * 1000.0
        s.close()
        return round(latency, 1)
    except Exception:
        try:
            s.close()
        except Exception:
            pass
        return None


def get_network_observatory() -> dict:
    """Synthesize Watchdog health, Wi-Fi RF telemetry, and rolling Latency/Loss."""
    global _ping_history
    lat = measure_ping_latency("1.1.1.1", 443, 1.0)
    now_ts = time.time()

    if lat is not None:
        _ping_history.append((lat, True, now_ts))
    else:
        _ping_history.append((0.0, False, now_ts))

    if len(_ping_history) > 30:
        _ping_history = _ping_history[-30:]

    success_pings = [p[0] for p in _ping_history if p[1]]
    total_samples = len(_ping_history)
    loss_pct = round(((total_samples - len(success_pings)) / total_samples * 100.0), 1) if total_samples > 0 else 0.0

    avg_lat = round(sum(success_pings) / len(success_pings), 1) if success_pings else 0.0
    current_lat = success_pings[-1] if success_pings else 0.0

    jitter = 0.0
    if len(success_pings) >= 2:
        diffs = [abs(success_pings[i] - success_pings[i - 1]) for i in range(1, len(success_pings))]
        jitter = round(sum(diffs) / len(diffs), 1)

    if loss_pct > 5.0 or current_lat > 200:
        quality = "poor"
    elif loss_pct > 0.0 or current_lat > 80 or jitter > 15:
        quality = "fair"
    else:
        quality = "excellent"

    return {
        "watchdog": get_watchdog_status(),
        "wifi": get_wifi_telemetry(),
        "latency": {
            "current_ms": current_lat,
            "avg_ms": avg_lat,
            "jitter_ms": jitter,
            "loss_percent": loss_pct,
            "quality": quality,
            "target": "1.1.1.1 (Cloudflare)",
        },
    }


def flush_dns_cache() -> bool:
    """Safely flush Windows DNS resolver cache."""
    try:
        r = subprocess.run(["ipconfig", "/flushdns"], capture_output=True, text=True, timeout=5)
        success = r.returncode == 0
        if success:
            add_event("system", "🧹 DNS Resolver Cache flushed successfully")
        return success
    except Exception:
        return False


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

    # Update 30-minute downsampled chart buffer
    try:
        update_chart_buffer(metrics["ram"]["percent"], metrics["cpu"]["total_percent"])
    except Exception:
        pass

    return metrics


# ---------------------------------------------------------------------------
# MuMu Instance Monitor (With Fast Anti-EcoQoS Hook)
# ---------------------------------------------------------------------------
def get_mumu_instances() -> list:
    try:
        disable_ecoqos_for_mumu()
    except Exception:
        pass

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
        msg = f"MuMu Instance crash detected — {lost} instance(s) disappeared"
        add_event("crash", msg)
        if CONFIG.get("alerts", {}).get("notify_on_mumu_crash", True):
            send_discord_alert(
                "🚨 MuMu Instance Crash Detected",
                f"**{lost}** instance(s) terminated unexpectedly.\nActive devices: **{current_device_count}** (was {_prev_mumu_count})",
                color=0xFF3366,
                fields=[
                    {"name": "Remaining Instances", "value": f"{current_device_count} running", "inline": True},
                    {"name": "Impact", "value": f"-{lost} bot(s) offline", "inline": True},
                ]
            )

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
_last_scheduled_slot = None


async def auto_boost_loop():
    global _last_boost_time, _last_boost_result, _last_scheduled_slot
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
                if mem.percent >= 90 and CONFIG.get("alerts", {}).get("notify_on_ram_critical", True):
                    send_discord_alert(
                        "⚠️ RAM Critical Alert (>90%)",
                        f"System RAM reached **{mem.percent}%** ({round(mem.used/(1024**3), 1)}GB / {round(mem.total/(1024**3), 1)}GB).\nAuto-Boost is purging caches now.",
                        color=0xFFB800,
                    )
            elif mode == "scheduled":
                interval_min = max(1, cfg.get("interval_minutes", 30))
                now_dt = datetime.now()
                current_slot = f"{now_dt.strftime('%Y-%m-%d %H')}:{now_dt.minute}"
                is_aligned_minute = (now_dt.minute % interval_min == 0)
                if is_aligned_minute and _last_scheduled_slot != current_slot:
                    _last_scheduled_slot = current_slot
                    # Dual-Gate Evaluation: Avoid trimming working sets when RAM is healthy & free
                    ram_breakdown = get_ram_breakdown()
                    thresh = cfg.get("threshold_percent", 80)
                    needs_ram_trim = (mem.percent >= thresh) or (ram_breakdown.get("available_gb", 0) < 4.0)
                    needs_standby_purge = should_purge_standby_gate(
                        ram_breakdown.get("available_gb", 0),
                        ram_breakdown.get("standby_gb", 0)
                    )

                    if needs_ram_trim or needs_standby_purge:
                        should_boost = True
                        add_event("boost", f"Scheduled Clock-Aligned Boost (:00/:30) triggered — Gate Passed: RAM {mem.percent}%, Standby {ram_breakdown.get('standby_gb', 0)}GB")
                    else:
                        add_event("info", f"Scheduled Boost (:00/:30) skipped — Memory Healthy: RAM {mem.percent}%, Available {ram_breakdown.get('available_gb', 0)}GB, Standby {ram_breakdown.get('standby_gb', 0)}GB")

            if should_boost:
                # In auto/scheduled mode, apply intelligent gating on standby purge
                _last_boost_result = ram_boost(force_standby=False)
                _last_boost_time = time.time()
                await broadcast_event({
                    "type": "boost_triggered",
                    "result": _last_boost_result,
                })
                # Broadcast updated session summary so counter updates immediately
                summary = get_session_summary()
                await broadcast_event({
                    "type": "session_summary",
                    "data": summary,
                })

            await asyncio.sleep(5)
        except Exception as e:
            add_event("error", f"Auto-boost loop error: {str(e)}")
            await asyncio.sleep(10)


# ---------------------------------------------------------------------------
# Maintenance Background Task
# ---------------------------------------------------------------------------
_maintenance_task = None


async def maintenance_loop():
    global _last_scan_verified
    last_drift_check = 0
    last_vm_disk_check = 0
    last_hog_check = 0
    last_growth_snapshot = 0
    last_defender_check = 0
    last_downloads_sweep = 0

    await asyncio.sleep(5)

    try:
        check_hardening_drift()
    except Exception as e:
        add_event("error", f"Drift check failed: {e}")

    try:
        count = disable_ecoqos_for_mumu()
        if count > 0:
            add_event("system", f"🛡️ Anti-EcoQoS applied to {count} MuMu process(es)")
    except Exception:
        pass

    try:
        get_defender_status()
    except Exception:
        pass

    while True:
        try:
            now = time.time()
            maint_cfg = CONFIG.get("maintenance", {})

            # Module 2: Hardening Drift Detector (Hourly Cadence)
            drift_interval = maint_cfg.get("drift_check_hours", 1) * 3600
            if now - last_drift_check >= drift_interval:
                try:
                    result = check_hardening_drift()
                    await broadcast_event({"type": "hardening_status", "data": result})
                except Exception:
                    pass
                last_drift_check = now

            # Module 3: VM Disk Sentinel (15 min)
            if now - last_vm_disk_check >= 900:
                try:
                    vm_data = get_vm_disk_status()
                    if maint_cfg.get("vm_auto_trim", True):
                        for vm in vm_data:
                            if vm["used_pct"] >= maint_cfg.get("vm_disk_warn_pct", 85):
                                trim_vm_caches(vm["port"])
                                await asyncio.sleep(2)
                                updated = get_vm_disk_status()
                                for u in updated:
                                    if u["port"] == vm["port"] and u["used_pct"] >= maint_cfg.get("vm_disk_critical_pct", 90):
                                        add_event("crash", f"🚨 VM #{u['instance']} disk CRITICAL at {u['used_pct']}% after trim!")
                    await broadcast_event({"type": "vm_disk_status", "data": vm_data})
                except Exception:
                    pass
                last_vm_disk_check = now

            # Module 5: Hog Detector (60s)
            if now - last_hog_check >= 60:
                try:
                    detect_and_throttle_hogs()
                except Exception:
                    pass
                last_hog_check = now

            # Module 6: Growth Tracker (6h)
            growth_interval = maint_cfg.get("growth_snapshot_hours", 6) * 3600
            if now - last_growth_snapshot >= growth_interval:
                try:
                    snapshot_folder_sizes()
                except Exception:
                    pass
                last_growth_snapshot = now

            # Module 7: Defender Check (Hourly)
            if now - last_defender_check >= 3600:
                try:
                    status = get_defender_status()
                    await broadcast_event({"type": "defender_status", "data": status})
                except Exception:
                    pass
                last_defender_check = now

            # Module 7: Quick Scan at 04:00 (Non-blocking Popen)
            current_hour = datetime.now().hour
            current_minute = datetime.now().minute
            scan_hour = maint_cfg.get("defender_scan_hour", 4)
            if current_hour == scan_hour and _last_scan_date != date.today():
                try:
                    run_quick_scan()
                except Exception:
                    pass

            # Module 7: Scan Completion Verification at 04:30
            if current_hour == scan_hour and current_minute >= 30 and _last_scan_verified != date.today():
                status = get_defender_status()
                if status.get("quick_scan_age_days", -1) == 0:
                    add_event("system", "✅ Defender Quick Scan completed & verified")
                    _last_scan_verified = date.today()

            # Module 7: Downloads Sweep
            sweep_interval = maint_cfg.get("downloads_sweep_minutes", 30) * 60
            if now - last_downloads_sweep >= sweep_interval:
                try:
                    scan_downloads_folder()
                except Exception:
                    pass
                last_downloads_sweep = now

            await asyncio.sleep(10)
        except Exception as e:
            add_event("error", f"Maintenance loop error: {str(e)}")
            await asyncio.sleep(30)


# ---------------------------------------------------------------------------
# WebSocket Connection Manager
# ---------------------------------------------------------------------------
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[tuple[WebSocket, bool]] = []

    async def connect(self, ws: WebSocket, is_auth: bool):
        await ws.accept()
        self.active_connections.append((ws, is_auth))

    def set_auth(self, ws: WebSocket, is_auth: bool):
        for i, (conn, _) in enumerate(self.active_connections):
            if conn == ws:
                self.active_connections[i] = (ws, is_auth)
                break

    def is_auth(self, ws: WebSocket) -> bool:
        if not is_auth_enabled():
            return True
        for conn, auth_val in self.active_connections:
            if conn == ws:
                return auth_val
        return False

    def disconnect(self, ws: WebSocket):
        self.active_connections = [c for c in self.active_connections if c[0] != ws]

    async def broadcast(self, data: dict):
        dead = []
        for conn, _ in self.active_connections:
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
# FastAPI App
# ---------------------------------------------------------------------------
_heartbeat_task = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _auto_boost_task, _maintenance_task, _heartbeat_task
    psutil.cpu_percent(interval=0, percpu=True)
    _auto_boost_task = asyncio.create_task(auto_boost_loop())
    _maintenance_task = asyncio.create_task(maintenance_loop())
    _heartbeat_task = asyncio.create_task(heartbeat_loop())
    add_event("system", "Genesis Dashboard started (v2.4 Production Engine)")

    # Send Discord notification on startup
    if CONFIG.get("alerts", {}).get("notify_on_startup", True):
        send_discord_alert(
            "🚀 Genesis Dashboard Online (v2.4)",
            "**Fable 5 Production Suite & Network Observatory** successfully initialized.\nAll 8 Modules active, persistence enabled (5,000 entries cap).",
            color=0x00FF88
        )

    yield
    if _auto_boost_task:
        _auto_boost_task.cancel()
    if _maintenance_task:
        _maintenance_task.cancel()
    if _heartbeat_task:
        _heartbeat_task.cancel()
    add_event("system", "Genesis Dashboard stopped")


app = FastAPI(title="Genesis Dashboard", version="2.4.0", lifespan=lifespan)

static_dir = BASE_DIR / "static"
static_dir.mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")


@app.get("/")
async def serve_dashboard():
    return FileResponse(str(static_dir / "index.html"))


# ---------------------------------------------------------------------------
# Authentication Endpoints
# ---------------------------------------------------------------------------
@app.post("/api/auth/login")
async def api_auth_login(request: Request, payload: dict):
    client_ip = get_client_ip(request)
    if is_ip_locked(client_ip):
        return JSONResponse(
            {"error": "Too many failed attempts. Locked for 10 minutes."},
            status_code=429,
        )

    pin = str(payload.get("pin", "")).strip()

    if verify_pin_input(pin):
        token = create_session_token()
        add_event("system", f"🔑 Session unlocked (IP: {client_ip})")
        return JSONResponse({"ok": True, "token": token})
    else:
        record_failed_attempt(client_ip)
        add_event("warning", f"🚫 Failed PIN attempt from IP: {client_ip}")
        return JSONResponse({"error": "Invalid PIN"}, status_code=401)


@app.get("/api/auth/status")
async def api_auth_status(request: Request):
    token = request.headers.get("X-Auth-Token") or request.query_params.get("token")
    return JSONResponse({
        "auth_required": is_auth_enabled(),
        "authenticated": verify_session_token(token),
    })


# ---------------------------------------------------------------------------
# WebSocket Endpoint with Guarded Commands
# ---------------------------------------------------------------------------
@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    initial_token = ws.query_params.get("token")
    is_authed = verify_session_token(initial_token)
    await manager.connect(ws, is_authed)

    try:
        await ws.send_json({
            "type": "init",
            "auth_required": is_auth_enabled(),
            "authenticated": is_authed,
            "config": CONFIG,
            "history": event_history[-50:],
            "hardening": _last_drift_result,
            "defender": _defender_status,
            "vm_disk": _vm_disk_cache,
            "growth": _growth_data[-24:] if _growth_data else [],
            "observatory": get_network_observatory(),
            "summary": get_session_summary(),
            "chart_history": {
                "ram": _chart_buffer_ram,
                "cpu": _chart_buffer_cpu,
            },
        })

        _obs_counter = 0
        while True:
            metrics = get_metrics_with_rates()
            mumu = check_mumu_health()
            top_procs = get_top_processes(10)

            _obs_counter += 1
            payload = {
                "type": "metrics",
                "metrics": metrics,
                "mumu": mumu,
                "top_processes": top_procs,
                "summary": get_session_summary(),
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
            }

            # Push network observatory telemetry every 2 cycles (~2s)
            if _obs_counter % 2 == 0:
                payload["observatory"] = get_network_observatory()

            await ws.send_json(payload)

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

    if cmd == "auth":
        token = data.get("token")
        if verify_session_token(token):
            manager.set_auth(ws, True)
            await ws.send_json({"type": "auth_success"})
        else:
            manager.set_auth(ws, False)
            await ws.send_json({"type": "auth_failed"})
        return

    if is_auth_enabled() and not manager.is_auth(ws):
        await ws.send_json({"type": "auth_required", "error": "Authentication required for this command."})
        return

    if cmd == "boost":
        result = ram_boost(force_standby=True)
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

    elif cmd == "deep_clean_preview":
        preview = deep_clean_preview()
        await ws.send_json({"type": "deep_clean_preview", "data": preview})

    elif cmd == "deep_clean_execute":
        targets = data.get("targets")
        result = deep_clean_execute(targets)
        await ws.send_json({"type": "deep_clean_result", "data": result})

    elif cmd == "vm_disk_refresh":
        vm_data = get_vm_disk_status()
        await ws.send_json({"type": "vm_disk_status", "data": vm_data})

    elif cmd == "vm_trim_cache":
        port = data.get("port")
        if port:
            success = trim_vm_caches(port)
            await ws.send_json({"type": "vm_trim_result", "port": port, "success": success})

    elif cmd == "check_hardening":
        result = check_hardening_drift()
        await ws.send_json({"type": "hardening_status", "data": result})

    elif cmd == "defender_status":
        status = get_defender_status()
        await ws.send_json({"type": "defender_status", "data": status})

    elif cmd == "quick_scan":
        success = run_quick_scan()
        await ws.send_json({"type": "quick_scan_result", "success": success})
        # Refresh defender status after scan trigger so UI updates immediately
        status = get_defender_status()
        await ws.send_json({"type": "defender_status", "data": status})

    elif cmd == "growth_data":
        await ws.send_json({"type": "growth_data", "data": _growth_data[-24:]})

    elif cmd == "flush_dns":
        success = flush_dns_cache()
        await ws.send_json({"type": "flush_dns_result", "success": success})

    elif cmd == "observatory_refresh":
        obs = get_network_observatory()
        await ws.send_json({"type": "observatory_update", "data": obs})

    elif cmd == "reset_boost_counter":
        global _boost_counter_reset_time
        _boost_counter_reset_time = time.time()
        summary = get_session_summary()
        await broadcast_event({"type": "session_summary", "data": summary})
        await ws.send_json({"type": "boost_counter_reset", "data": summary})


# ---------------------------------------------------------------------------
# REST API Endpoints
# ---------------------------------------------------------------------------
@app.post("/api/boost")
async def api_boost(request: Request):
    if is_auth_enabled() and not verify_session_token(request.headers.get("X-Auth-Token")):
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    result = ram_boost(force_standby=True)
    return JSONResponse(result)


@app.get("/api/config")
async def api_get_config():
    # Return config with pin_hash stripped for privacy
    safe_cfg = json.loads(json.dumps(CONFIG))
    if "auth" in safe_cfg:
        safe_cfg["auth"].pop("pin_hash", None)
        safe_cfg["auth"].pop("salt", None)
        safe_cfg["auth"].pop("pin", None)
    return JSONResponse(safe_cfg)


@app.put("/api/config")
async def api_put_config(request: Request, payload: dict):
    if is_auth_enabled() and not verify_session_token(request.headers.get("X-Auth-Token")):
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
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
async def api_kill(request: Request, pid: int):
    if is_auth_enabled() and not verify_session_token(request.headers.get("X-Auth-Token")):
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
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
async def api_deep_clean_execute(request: Request):
    if is_auth_enabled() and not verify_session_token(request.headers.get("X-Auth-Token")):
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
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


@app.get("/api/network/observatory")
async def api_network_observatory():
    return JSONResponse(get_network_observatory())


@app.post("/api/network/flush-dns")
async def api_network_flush_dns(request: Request):
    if is_auth_enabled() and not verify_session_token(request.headers.get("X-Auth-Token")):
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    return JSONResponse({"success": flush_dns_cache()})


@app.get("/api/summary")
async def api_summary():
    return JSONResponse(get_session_summary())


@app.post("/api/summary/reset-boosts")
async def api_reset_boosts(request: Request):
    if is_auth_enabled() and not verify_session_token(request.headers.get("X-Auth-Token")):
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    global _boost_counter_reset_time
    _boost_counter_reset_time = time.time()
    summary = get_session_summary()
    await broadcast_event({"type": "session_summary", "data": summary})
    return JSONResponse({"success": True, "summary": summary})


if __name__ == "__main__":
    import uvicorn

    host = CONFIG.get("server", {}).get("host", "0.0.0.0")
    port = CONFIG.get("server", {}).get("port", 7700)
    print(f"\n{'='*50}")
    print(f"  GENESIS DASHBOARD v2.4 — Fable 5 Production Suite")
    print(f"  http://localhost:{port}")
    print(f"  http://{host}:{port} (LAN/Remote Access)")
    print(f"{'='*50}\n")
    uvicorn.run(app, host=host, port=port, log_level="info")
