import ctypes
import ctypes.wintypes
import os
import struct
import time
from pathlib import Path
from typing import Callable

import psutil

from backend.core.config import CONFIG
from backend.core.events import add_event

# --- Win32 / NT Native Constants & Handles ---
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

EXACT_EMULATOR_TARGETS = {
    "mumunxdevice.exe",
    "nemuheadless.exe",
    "mumuplayer.exe",
    "robloxplayerbeta.exe",
}

IMMUTABLE_PROTECTED_PROCESSES = {
    "csrss.exe",
    "lsass.exe",
    "smss.exe",
    "wininit.exe",
    "system",
    "dwm.exe",
    "services.exe",
    "stardesk.exe",
    "parsecd.exe",
    "anydesk.exe",
    "teamviewer.exe",
    "cloudflared.exe",
    "python.exe",
    "mumunxdevice.exe",
    "mumunxmain.exe",
    "mumuplayer.exe",
    "nemuheadless.exe",
    "nemuplayer.exe",
    "nemumain.exe",
    "hd-player.exe",
    "dnplayer.exe",
    "ldboxheadless.exe",
    "vboxheadless.exe",
    "qemu-system-x86_64.exe",
    "adb.exe",
    "robloxplayerbeta.exe",
    "robloxplayerlauncher.exe",
}

HOG_TARGETS = {
    "compattelrunner.exe",
    "mousocoreworker.exe",
    "searchindexer.exe",
    "wmiprvse.exe",
    "windowsupdatebox.exe",
    "installagent.exe",
    "musnotification.exe",
}


class LUID(ctypes.Structure):
    _fields_ = [("LowPart", ctypes.wintypes.DWORD), ("HighPart", ctypes.wintypes.LONG)]


class LUID_AND_ATTRIBUTES(ctypes.Structure):
    _fields_ = [("Luid", LUID), ("Attributes", ctypes.wintypes.DWORD)]


class TOKEN_PRIVILEGES(ctypes.Structure):
    _fields_ = [("PrivilegeCount", ctypes.wintypes.DWORD), ("Privileges", LUID_AND_ATTRIBUTES * 1)]


class PROCESS_POWER_THROTTLING_STATE(ctypes.Structure):
    _fields_ = [
        ("Version", ctypes.c_ulong),
        ("ControlMask", ctypes.c_ulong),
        ("StateMask", ctypes.c_ulong),
    ]


_kernel32.OpenProcess.restype = ctypes.wintypes.HANDLE
_kernel32.OpenProcess.argtypes = [
    ctypes.wintypes.DWORD,
    ctypes.wintypes.BOOL,
    ctypes.wintypes.DWORD,
]
_kernel32.CloseHandle.argtypes = [ctypes.wintypes.HANDLE]

_psapi.EmptyWorkingSet.restype = ctypes.wintypes.BOOL
_psapi.EmptyWorkingSet.argtypes = [ctypes.wintypes.HANDLE]

_ntdll.NtSetTimerResolution.argtypes = [
    ctypes.c_ulong,
    ctypes.c_bool,
    ctypes.POINTER(ctypes.c_ulong),
]
_ntdll.NtSetTimerResolution.restype = ctypes.c_long
_ntdll.NtQueryTimerResolution.argtypes = [
    ctypes.POINTER(ctypes.c_ulong),
    ctypes.POINTER(ctypes.c_ulong),
    ctypes.POINTER(ctypes.c_ulong),
]
_ntdll.NtQueryTimerResolution.restype = ctypes.c_long

_timer_resolution_active = True
_current_timer_res_ms = 0.500
_pcore_affinity_enabled = True
_ecoqos_applied_pids: set[int] = set()
_hog_actions: list[str] = []


def enable_privilege(privilege_name: str) -> bool:
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


# --- Memory & Standby Purge ---
def purge_standby_list() -> bool:
    try:
        enable_privilege("SeProfileSingleProcessPrivilege")
        enable_privilege("SeIncreaseQuotaPrivilege")
        command = ctypes.c_ulong(4)
        status = _ntdll.NtSetSystemInformation(
            0x50,
            ctypes.byref(command),
            ctypes.sizeof(command),
        )
        return status == 0
    except Exception:
        return False


def should_purge_standby_gate(free_gb: float, standby_gb: float, available_gb: float) -> bool:
    cfg = CONFIG.get("maintenance", {})
    min_standby = cfg.get("standby_purge_min_standby_gb", 4.0)
    min_available = cfg.get("standby_purge_min_available_gb", 4.0)
    return standby_gb >= min_standby and available_gb < min_available


def get_ram_breakdown() -> dict:
    mem = psutil.virtual_memory()
    total_gb = mem.total / (1024 ** 3)
    available_gb = mem.available / (1024 ** 3)

    standby_gb = 0.0
    free_gb = 0.0
    try:
        buf = ctypes.create_string_buffer(176)
        ret_len = ctypes.c_ulong()
        status = _ntdll.NtQuerySystemInformation(0x50, buf, 176, ctypes.byref(ret_len))
        if status == 0:
            vals = struct.unpack("22Q", buf.raw)
            zero_pages = vals[0]
            free_pages = vals[1]
            standby_pages = sum(vals[5:13])
            page_size = 4096
            standby_gb = (standby_pages * page_size) / (1024 ** 3)
            free_gb = ((zero_pages + free_pages) * page_size) / (1024 ** 3)
    except Exception:
        pass

    if standby_gb == 0.0 or standby_gb > total_gb:
        free_gb = mem.free / (1024 ** 3) if hasattr(mem, "free") else 0.0
        standby_gb = max(available_gb - free_gb, 0.0)

    active_gb = max(total_gb - (free_gb + standby_gb), 0.0)

    return {
        "total_gb": round(total_gb, 2),
        "active_gb": round(active_gb, 2),
        "standby_gb": round(max(standby_gb, 0.0), 2),
        "free_gb": round(free_gb, 2),
        "available_gb": round(available_gb, 2),
    }


# --- Timer Resolution & CPU Affinity ---
def set_high_precision_timer(enable: bool = True) -> dict:
    global _timer_resolution_active, _current_timer_res_ms
    try:
        actual = ctypes.c_ulong(0)
        if enable:
            status = _ntdll.NtSetTimerResolution(5000, True, ctypes.byref(actual))
            _timer_resolution_active = status == 0
        else:
            _ntdll.NtSetTimerResolution(5000, False, ctypes.byref(actual))
            _timer_resolution_active = False

        min_res, max_res, cur_res = ctypes.c_ulong(0), ctypes.c_ulong(0), ctypes.c_ulong(0)
        _ntdll.NtQueryTimerResolution(ctypes.byref(min_res), ctypes.byref(max_res), ctypes.byref(cur_res))
        _current_timer_res_ms = round(cur_res.value / 10000.0, 3)
        return {
            "active": _timer_resolution_active,
            "resolution_ms": _current_timer_res_ms,
            "min_ms": round(min_res.value / 10000.0, 3),
            "max_ms": round(max_res.value / 10000.0, 3),
        }
    except Exception as exc:
        return {"active": False, "resolution_ms": 15.6, "error": str(exc)}


def get_timer_resolution_status() -> dict:
    try:
        min_res, max_res, cur_res = ctypes.c_ulong(0), ctypes.c_ulong(0), ctypes.c_ulong(0)
        _ntdll.NtQueryTimerResolution(ctypes.byref(min_res), ctypes.byref(max_res), ctypes.byref(cur_res))
        res_ms = round(cur_res.value / 10000.0, 3)
        return {
            "active": res_ms <= 1.0,
            "resolution_ms": res_ms,
            "min_ms": round(min_res.value / 10000.0, 3),
            "max_ms": round(max_res.value / 10000.0, 3),
        }
    except Exception:
        return {"active": False, "resolution_ms": 15.6}


def apply_pcore_affinity_for_mumu(enable: bool = True) -> dict:
    global _pcore_affinity_enabled
    _pcore_affinity_enabled = enable
    count = 0
    total_cpus = psutil.cpu_count(logical=True) or 16
    target_mask = (
        list(range(0, min(8, total_cpus)))
        if (enable and total_cpus >= 12)
        else list(range(0, total_cpus))
    )
    configured = {
        str(n).strip().lower()
        for n in CONFIG.get("mumu", {}).get("process_names", [])
        if str(n).strip().lower() not in {"mumunxmain.exe", "mumunxlauncher.exe", "mumunxdevicecleaner.exe", "mumunxcrashreporter.exe"}
    }
    targets = EXACT_EMULATOR_TARGETS | configured

    for proc in psutil.process_iter(["pid", "name"]):
        try:
            name = (proc.info["name"] or "").lower()
            if name in targets:
                p = psutil.Process(proc.info["pid"])
                p.cpu_affinity(target_mask)
                count += 1
        except Exception:
            continue

    return {
        "success": True,
        "enabled": enable,
        "applied_count": count,
        "mode": "P-Core Exclusive (Cores 0-7)" if enable else "All Cores Balanced",
    }


def get_affinity_status() -> dict:
    total_cpus = psutil.cpu_count(logical=True) or 16
    return {
        "enabled": _pcore_affinity_enabled,
        "mode": "P-Core Exclusive (0-7)" if _pcore_affinity_enabled else "Balanced All Cores",
        "total_cores": total_cpus,
        "p_cores_count": min(8, total_cpus),
    }


# --- GPU Shader Cache ---
def scan_and_flush_shader_cache(dry_run: bool = False) -> dict:
    local_app_data = os.environ.get("LOCALAPPDATA", "")
    if not local_app_data:
        return {"success": False, "error": "LOCALAPPDATA not found"}

    targets = [
        Path(local_app_data) / "NVIDIA" / "DXCache",
        Path(local_app_data) / "NVIDIA" / "GLCache",
        Path(local_app_data) / "D3DSCache",
        Path(local_app_data) / "AMD" / "DxCache",
    ]

    total_size = 0
    file_count = 0
    deleted_size = 0
    deleted_count = 0

    for target in targets:
        if not target.exists():
            continue
        try:
            for root, _, files in os.walk(target):
                for f in files:
                    fp = Path(root) / f
                    try:
                        sz = fp.stat().st_size
                        total_size += sz
                        file_count += 1
                        if not dry_run:
                            fp.unlink(missing_ok=True)
                            deleted_size += sz
                            deleted_count += 1
                    except Exception:
                        pass
        except Exception:
            pass

    if not dry_run and deleted_count > 0:
        add_event(
            "system",
            f"DirectX/GPU: Flushed {deleted_count} shader cache files ({round(deleted_size / (1024 ** 2), 1)} MB)",
        )

    return {
        "success": True,
        "total_files": file_count,
        "total_size_mb": round(total_size / (1024 ** 2), 2),
        "cleaned_files": deleted_count,
        "cleaned_mb": round(deleted_size / (1024 ** 2), 2),
    }


# --- Process Trimming & Protection ---
def get_protected_names() -> set[str]:
    names = set(IMMUTABLE_PROTECTED_PROCESSES)
    for n in CONFIG.get("auto_boost", {}).get("protected_processes", []):
        names.add(str(n).lower())
    return names


def trim_process_handle(pid: int) -> tuple[int, int, int]:
    try:
        handle = _kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA, False, pid)
        if handle:
            _psapi.EmptyWorkingSet(handle)
            _kernel32.CloseHandle(handle)
            return (1, 0, 0)
    except Exception:
        return (0, 0, 1)
    return (0, 0, 1)


def trim_single_process(pid: int, fallback_cb: Callable[[], bool] | None = None) -> dict:
    try:
        enable_privilege("SeDebugPrivilege")
        enable_privilege("SeIncreaseQuotaPrivilege")
        p = psutil.Process(pid)
        name = p.name() or "Process"
        mem_before = p.memory_info().rss / (1024 * 1024)

        handle = _kernel32.OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA, False, pid)
        if not handle:
            handle = _kernel32.OpenProcess(0x1F0FFF, False, pid)

        if handle:
            _psapi.EmptyWorkingSet(handle)
            _kernel32.CloseHandle(handle)
            time.sleep(0.1)
            mem_after = p.memory_info().rss / (1024 * 1024)
            freed = max(round(mem_before - mem_after, 1), 0.0)
            add_event("mumu", f"Trimmed working set for {name} (PID {pid}): freed {freed} MB")
            return {"success": True, "pid": pid, "name": name, "freed_mb": freed}

        if fallback_cb is not None and fallback_cb():
            return {"success": True, "pid": pid, "name": name, "freed_mb": 0.0, "note": "VM cache dropped"}
        return {"success": False, "error": "Unable to open process handle"}
    except Exception as exc:
        return {"success": False, "error": str(exc)}


# --- Anti-EcoQoS & Background Hog Throttling ---
def disable_ecoqos_for_mumu() -> int:
    global _ecoqos_applied_pids
    configured_names = {str(n).lower() for n in CONFIG.get("mumu", {}).get("process_names", [])}
    mumu_targets = {n for n in configured_names if n != "mumunxdevicecleaner.exe"} or {
        "mumunxdevice.exe",
        "mumunxmain.exe",
    }
    count = 0

    for proc in psutil.process_iter(["pid", "name"]):
        try:
            name = (proc.info["name"] or "").lower()
            pid = proc.info["pid"]
            if name not in mumu_targets or pid in _ecoqos_applied_pids:
                continue

            handle = _kernel32.OpenProcess(
                PROCESS_SET_INFORMATION | PROCESS_QUERY_INFORMATION,
                False,
                pid,
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


def detect_and_throttle_hogs() -> list[str]:
    global _hog_actions
    actions: list[str] = []

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
                    add_event("system", f"Hog Detector: {action}")
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    _hog_actions = actions
    return actions
