import asyncio
import ctypes
import json
import os
import re
import subprocess
import tempfile
import threading
import time
import winreg
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta
from pathlib import Path

import psutil

from backend.core.config import CONFIG, CONFIG_LOCK, GROWTH_PATH, save_config
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

_CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
_DEEP_CLEAN_LOCK = threading.Lock()
_VDI_COMPACT_LOCK = threading.Lock()
_AUTO_CLEAN_STATE_LOCK = threading.Lock()

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
    {
        "name": "Google Updater Cache",
        "category": "Updater",
        "description": "Google Updater downloaded CRX component caches",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\Google\GoogleUpdater\crx_cache"),
        "requires_service_stop": None,
    },
    {
        "name": "npm Cache",
        "category": "Dev Cache",
        "description": "Node.js npm local package download cache",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\npm-cache"),
        "requires_service_stop": None,
    },
    {
        "name": "Antigravity Updater Pending",
        "category": "Updater",
        "description": "Staged Antigravity desktop installer packages",
        "path": os.path.expandvars(r"%LOCALAPPDATA%\antigravity-updater\pending"),
        "requires_service_stop": None,
    },
    {
        "name": "StarDesk Old Logs",
        "category": "Logs",
        "description": "StarDesk diagnostic logs older than 3 days (preserves active .slog)",
        "path": r"C:\Program Files\StarDesk\log",
        "requires_service_stop": None,
        "max_age_days": 3,
        "skip_recent_slog_hours": 24,
    },
]

_MEMORY_DMP = r"C:\Windows\MEMORY.DMP"

_PROTECTED_DISCOVERY_DIRS: frozenset[str] = frozenset(
    {
        "local storage",
        "indexeddb",
        "cookies",
        "session storage",
        "login data",
        "web storage",
    }
)
_DISCOVERY_CACHE_LEAVES: frozenset[str] = frozenset(
    {
        "code cache",
        "gpucache",
        "dawncache",
        "shadercache",
        "grshadercache",
        "crx_cache",
    }
)
_MUMU_VM_PROCESS_NAMES: frozenset[str] = frozenset(
    {
        "mumuvmmheadless.exe",
        "mumunxheadless.exe",
        "mumunxdevice.exe",
        "mumuplayer.exe",
        "nemuheadless.exe",
    }
)

_auto_clean_state: dict = {
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


def _norm_lower(path_str: str) -> str:
    return os.path.normpath(os.path.expandvars(path_str)).lower()


def _is_reparse_or_symlink(path_obj: Path) -> bool:
    try:
        if os.path.islink(path_obj):
            return True
        if hasattr(os.path, "isjunction") and os.path.isjunction(path_obj):
            return True
    except OSError:
        return True
    return False


def _build_denylist_sets() -> tuple[set[str], set[str]]:
    exact_denied: set[str] = {
        _norm_lower(r"C:\Windows"),
        _norm_lower(r"C:\Program Files"),
        _norm_lower(r"C:\Program Files (x86)"),
        _norm_lower(r"C:\Users"),
        _norm_lower(r"C:\ProgramData"),
    }
    subtree_denied: set[str] = {
        _norm_lower(r"C:\Windows"),
        _norm_lower(r"C:\Windows\System32"),
        _norm_lower(r"C:\Windows\SysWOW64"),
        _norm_lower(r"C:\Windows\WinSxS"),
        _norm_lower(r"C:\Dev"),
    }

    for var_name in ("USERPROFILE", "LOCALAPPDATA", "APPDATA", "PROGRAMDATA", "WINDIR"):
        raw = os.environ.get(var_name, "").strip()
        if raw and "%" not in raw:
            exact_denied.add(_norm_lower(raw))

    user_profile = os.environ.get("USERPROFILE", "").strip()
    if user_profile and "%" not in user_profile:
        exact_denied.add(_norm_lower(os.path.join(user_profile, "AppData")))
        for sub in ("Desktop", "Documents", "Downloads", "OneDrive", "Pictures", "Videos", "Music", ".ssh"):
            subtree_denied.add(_norm_lower(os.path.join(user_profile, sub)))

    windir = os.environ.get("WINDIR", "").strip()
    if windir and "%" not in windir:
        subtree_denied.add(_norm_lower(windir))

    return exact_denied, subtree_denied


def validate_clean_target_path(raw_path: str) -> tuple[bool, str, str]:
    if not isinstance(raw_path, str) or not raw_path.strip():
        return False, "", "Target path cannot be empty"

    expanded = os.path.expandvars(raw_path.strip())
    if "%" in expanded and re.search(r"%[^%]+%", expanded):
        return False, expanded, "Unresolved environment variable in path"
    if expanded.startswith("\\\\") or expanded.startswith("//"):
        return False, expanded, "Network UNC paths are not allowed"
    if not os.path.isabs(expanded):
        return False, expanded, "Target path must be an absolute path"

    abs_path = os.path.abspath(expanded)
    probe = Path(abs_path)
    for component in (probe, *probe.parents):
        if _is_reparse_or_symlink(component):
            return False, abs_path, "Symlinks and directory junctions are blocked for safety"

    resolved = os.path.realpath(abs_path)
    resolved_probe = Path(resolved)
    if _is_reparse_or_symlink(resolved_probe):
        return False, resolved, "Resolved target cannot be a symlink or junction"

    if len(resolved_probe.parts) < 3:
        return False, resolved, "Path must be at least 2 levels deeper than drive root"

    exact_denied, subtree_denied = _build_denylist_sets()
    for candidate in (_norm_lower(abs_path), _norm_lower(resolved)):
        if candidate in exact_denied:
            return False, resolved, f"Path is protected by denylist: {resolved}"
        for blocked in subtree_denied:
            if candidate == blocked or candidate.startswith(blocked + os.sep):
                return False, resolved, f"Path falls inside protected subtree: {blocked}"

    return True, resolved, ""


def _is_builtin_clean_path(target_path: str) -> bool:
    norm = _norm_lower(target_path)
    for t in DEEP_CLEAN_TARGETS:
        if _norm_lower(t["path"]) == norm:
            return True
    return norm == _norm_lower(_MEMORY_DMP)


def _is_safe_clean_path(target_path: str) -> bool:
    if _is_builtin_clean_path(target_path):
        return True
    ok, _resolved, _reason = validate_clean_target_path(target_path)
    return ok


def _is_file_eligible(
    file_path: str,
    file_name: str,
    pattern: str | None = None,
    max_age_days: float | None = None,
    skip_recent_slog_hours: float | None = None,
    now_ts: float | None = None,
) -> tuple[bool, int]:
    if pattern:
        suffix = pattern.replace("*", "").lower()
        if suffix and not file_name.lower().endswith(suffix):
            return False, 0

    try:
        st = os.stat(file_path, follow_symlinks=False)
    except OSError:
        return False, 0

    if os.path.islink(file_path):
        return False, 0

    current_ts = now_ts if now_ts is not None else time.time()
    if skip_recent_slog_hours and skip_recent_slog_hours > 0 and file_name.lower().endswith(".slog"):
        if (current_ts - st.st_mtime) < (float(skip_recent_slog_hours) * 3600.0):
            return False, 0

    if max_age_days is not None and float(max_age_days) > 0:
        if (current_ts - st.st_mtime) < (float(max_age_days) * 86400.0):
            return False, 0

    return True, int(st.st_size)


def _measure_directory(
    folder: str,
    pattern: str | None = None,
    max_age_days: float | None = None,
    skip_recent_slog_hours: float | None = None,
) -> tuple[int, int]:
    total_size = 0
    file_count = 0
    now_ts = time.time()
    try:
        for root, dirs, files in os.walk(folder, followlinks=False):
            dirs[:] = [d for d in dirs if not _is_reparse_or_symlink(Path(root) / d)]
            for f in files:
                fp = os.path.join(root, f)
                eligible, sz = _is_file_eligible(
                    fp,
                    f,
                    pattern=pattern,
                    max_age_days=max_age_days,
                    skip_recent_slog_hours=skip_recent_slog_hours,
                    now_ts=now_ts,
                )
                if eligible:
                    total_size += sz
                    file_count += 1
    except (PermissionError, OSError):
        return 0, 0
    return total_size, file_count


def _is_excluded_target(dirpath: str, rel_path: str, target_name: str, excludes: list[str]) -> bool:
    if not excludes:
        return False
    norm_dir = os.path.normpath(dirpath).lower()
    rel_low = rel_path.replace("/", "\\").lower()
    name_low = target_name.lower()
    parts_low = {p.lower() for p in Path(rel_path).parts}
    for exc in excludes:
        token = exc.strip().lower()
        if not token:
            continue
        if token in (norm_dir, rel_low, name_low) or token in parts_low:
            return True
    return False


def _get_known_target_paths() -> set[str]:
    known: set[str] = {_norm_lower(t["path"]) for t in DEEP_CLEAN_TARGETS}
    known.add(_norm_lower(_MEMORY_DMP))
    for custom in CONFIG.get("maintenance", {}).get("custom_clean_targets", []):
        if isinstance(custom, dict) and custom.get("path"):
            known.add(_norm_lower(str(custom["path"])))
    return known


def discover_dynamic_cache_targets(
    roots: list[str] | None = None,
    min_mb: float | None = None,
    excludes: list[str] | None = None,
    max_depth: int = 4,
) -> list[dict]:
    maint_cfg = CONFIG.get("maintenance", {})
    if roots is None:
        candidate_roots = [
            os.path.expandvars(r"%LOCALAPPDATA%"),
            os.path.expandvars(r"%APPDATA%"),
        ]
    else:
        candidate_roots = list(roots)

    resolved_roots: list[str] = []
    seen_roots: set[str] = set()
    for r in candidate_roots:
        if not r or "%" in r or not os.path.isdir(r):
            continue
        real_r = os.path.realpath(r)
        key = real_r.lower()
        if key not in seen_roots:
            seen_roots.add(key)
            resolved_roots.append(real_r)

    threshold_mb = float(maint_cfg.get("auto_discovery_min_mb", 20) if min_mb is None else min_mb)
    min_bytes = max(0.0, threshold_mb) * 1024.0 * 1024.0
    exclude_list = (
        [str(x) for x in maint_cfg.get("auto_discovery_excludes", []) if str(x).strip()]
        if excludes is None
        else [str(x) for x in excludes if str(x).strip()]
    )

    known_paths = _get_known_target_paths()
    discovered_paths: set[str] = set()
    discovered: list[dict] = []

    for root in resolved_roots:
        for dirpath, dirs, _files in os.walk(root, topdown=True, followlinks=False):
            dirs[:] = [
                d
                for d in dirs
                if d.lower() not in _PROTECTED_DISCOVERY_DIRS
                and not _is_reparse_or_symlink(Path(dirpath) / d)
            ]

            rel = os.path.relpath(dirpath, root)
            if rel == ".":
                continue
            depth = len(Path(rel).parts)

            leaf_low = os.path.basename(dirpath).lower()
            parent_low = os.path.basename(os.path.dirname(dirpath)).lower()
            target_name = f"Auto: {rel}"

            if _is_excluded_target(dirpath, rel, target_name, exclude_list):
                dirs[:] = []
                continue

            if leaf_low in _PROTECTED_DISCOVERY_DIRS or leaf_low == "user data":
                if depth >= max_depth:
                    dirs[:] = []
                continue

            is_cache_leaf = (
                leaf_low in _DISCOVERY_CACHE_LEAVES
                or (leaf_low == "cache_data" and parent_low == "cache")
                or (leaf_low == "pending" and parent_low.endswith("-updater"))
            )

            if is_cache_leaf:
                dirs[:] = []
                norm_dir = os.path.normpath(dirpath).lower()
                if norm_dir in known_paths or norm_dir in discovered_paths:
                    continue
                if any(norm_dir.startswith(kp + os.sep) for kp in known_paths):
                    continue

                ok_path, safe_path, _reason = validate_clean_target_path(dirpath)
                if not ok_path:
                    continue

                total_bytes, file_count = _measure_directory(safe_path)
                if file_count > 0 and total_bytes >= min_bytes:
                    discovered_paths.add(norm_dir)
                    discovered.append(
                        {
                            "name": target_name,
                            "category": "Auto-Cache",
                            "description": f"Auto-discovered cache ({os.path.basename(safe_path)})",
                            "path": safe_path,
                            "file_count": file_count,
                            "size_mb": round(total_bytes / (1024 * 1024), 1),
                            "requires_service_stop": None,
                            "source": "discovered",
                            "max_age_days": None,
                            "skip_recent_slog_hours": None,
                        }
                    )
            elif depth >= max_depth:
                dirs[:] = []

    discovered.sort(key=lambda item: item["size_mb"], reverse=True)
    return discovered


def _collect_all_clean_targets() -> list[dict]:
    maint_cfg = CONFIG.get("maintenance", {})
    disabled_set = {
        str(x).strip().lower()
        for x in maint_cfg.get("disabled_clean_targets", [])
        if str(x).strip()
    }
    all_targets: list[dict] = []
    seen_paths: set[str] = set()

    for target in DEEP_CLEAN_TARGETS:
        folder = target["path"]
        norm = _norm_lower(folder)
        seen_paths.add(norm)
        all_targets.append(
            {
                "name": target["name"],
                "category": target.get("category", "System"),
                "description": target.get("description", ""),
                "path": folder,
                "file_pattern": target.get("file_pattern"),
                "requires_service_stop": target.get("requires_service_stop"),
                "max_age_days": target.get("max_age_days"),
                "skip_recent_slog_hours": target.get("skip_recent_slog_hours"),
                "source": "builtin",
                "enabled": target["name"].lower() not in disabled_set,
            }
        )

    for custom in maint_cfg.get("custom_clean_targets", []):
        if not isinstance(custom, dict):
            continue
        raw_path = str(custom.get("path", "") or "").strip()
        name = str(custom.get("name", "") or "").strip()
        if not raw_path or not name:
            continue
        ok, resolved, _reason = validate_clean_target_path(raw_path)
        if not ok:
            continue
        norm = _norm_lower(resolved)
        if norm in seen_paths:
            continue
        seen_paths.add(norm)
        raw_age = custom.get("max_age_days")
        max_age = float(raw_age) if raw_age not in (None, "", 0) else None
        is_enabled = bool(custom.get("enabled", True)) and (name.lower() not in disabled_set)
        all_targets.append(
            {
                "name": name,
                "category": str(custom.get("category") or "Custom"),
                "description": str(custom.get("description") or "User-configured custom cache target"),
                "path": resolved,
                "file_pattern": custom.get("file_pattern") or None,
                "requires_service_stop": None,
                "max_age_days": max_age,
                "skip_recent_slog_hours": None,
                "source": "custom",
                "enabled": is_enabled,
            }
        )

    return all_targets


def deep_clean_preview() -> list[dict]:
    maint_cfg = CONFIG.get("maintenance", {})
    disabled_set = {
        str(x).strip().lower()
        for x in maint_cfg.get("disabled_clean_targets", [])
        if str(x).strip()
    }
    preview: list[dict] = []

    for target in _collect_all_clean_targets():
        folder = target["path"]
        if not os.path.exists(folder) or not _is_safe_clean_path(folder):
            continue
        total_size, file_count = _measure_directory(
            folder,
            pattern=target.get("file_pattern"),
            max_age_days=target.get("max_age_days"),
            skip_recent_slog_hours=target.get("skip_recent_slog_hours"),
        )
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
                    "source": target.get("source", "builtin"),
                    "enabled": bool(target.get("enabled", True)),
                    "max_age_days": target.get("max_age_days"),
                    "file_pattern": target.get("file_pattern"),
                    "skip_recent_slog_hours": target.get("skip_recent_slog_hours"),
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
                    "source": "builtin",
                    "enabled": "memory.dmp" not in disabled_set,
                    "max_age_days": None,
                    "file_pattern": None,
                    "skip_recent_slog_hours": None,
                }
            )
        except OSError:
            pass

    if maint_cfg.get("auto_discovery_enabled", True):
        for item in discover_dynamic_cache_targets():
            item["enabled"] = item["name"].lower() not in disabled_set
            preview.append(item)

    return preview


def deep_clean_execute(targets: list[str] | None = None, trigger: str = "manual") -> dict:
    with _DEEP_CLEAN_LOCK:
        with _AUTO_CLEAN_STATE_LOCK:
            _auto_clean_state["is_cleaning"] = True

        try:
            preview = deep_clean_preview()
            if targets is not None:
                target_set = set(targets)
                preview = [p for p in preview if p["name"] in target_set]
            else:
                preview = [p for p in preview if p.get("enabled", True)]

            total_freed = 0
            total_deleted = 0
            results: list[dict] = []
            now_ts = time.time()

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
                        subprocess.run(
                            ["net", "stop", service],
                            capture_output=True,
                            timeout=15,
                            creationflags=_CREATE_NO_WINDOW,
                        )
                        service_was_running = True
                    except Exception:
                        pass

                try:
                    if os.path.isfile(path) and not os.path.islink(path):
                        try:
                            freed = os.path.getsize(path)
                            os.remove(path)
                            deleted = 1
                        except (PermissionError, OSError):
                            pass
                    else:
                        pattern = item.get("file_pattern")
                        max_age_days = item.get("max_age_days")
                        skip_slog_hours = item.get("skip_recent_slog_hours")

                        if os.path.exists(path) and not _is_reparse_or_symlink(Path(path)):
                            for root, dirs, files in os.walk(path, topdown=False, followlinks=False):
                                for f in files:
                                    fp = os.path.join(root, f)
                                    eligible, sz = _is_file_eligible(
                                        fp,
                                        f,
                                        pattern=pattern,
                                        max_age_days=max_age_days,
                                        skip_recent_slog_hours=skip_slog_hours,
                                        now_ts=now_ts,
                                    )
                                    if not eligible:
                                        continue
                                    try:
                                        os.remove(fp)
                                        freed += sz
                                        deleted += 1
                                    except (PermissionError, OSError):
                                        continue
                                for d in dirs:
                                    dp = os.path.join(root, d)
                                    if _is_reparse_or_symlink(Path(dp)):
                                        continue
                                    try:
                                        os.rmdir(dp)
                                    except (PermissionError, OSError):
                                        continue
                finally:
                    if service and service_was_running:
                        try:
                            subprocess.run(
                                ["net", "start", service],
                                capture_output=True,
                                timeout=15,
                                creationflags=_CREATE_NO_WINDOW,
                            )
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
                        "source": item.get("source", "builtin"),
                    }
                )

            try:
                subprocess.run(
                    ["powershell", "-Command", "Delete-DeliveryOptimizationCache -Force"],
                    capture_output=True,
                    timeout=15,
                    creationflags=_CREATE_NO_WINDOW,
                )
                results.append({"name": "Delivery Optimization", "deleted": 0, "freed_mb": 0, "source": "builtin"})
            except Exception:
                pass

            total_freed_mb = round(total_freed / (1024 * 1024), 1)
            now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            with _AUTO_CLEAN_STATE_LOCK:
                if trigger in ("scheduled", "threshold"):
                    _auto_clean_state["last_auto_clean_at"] = now_str
                    _auto_clean_state["last_auto_clean_freed_mb"] = total_freed_mb
                if trigger == "threshold":
                    _auto_clean_state["last_threshold_run_ts"] = time.time()
                _auto_clean_state["last_trigger"] = trigger

            add_event("clean", f"Deep Clean ({trigger}): {total_freed_mb} MB freed ({total_deleted} files)")

            return {
                "total_freed_mb": total_freed_mb,
                "total_deleted": total_deleted,
                "trigger": trigger,
                "timestamp": now_str,
                "details": results,
            }
        finally:
            with _AUTO_CLEAN_STATE_LOCK:
                _auto_clean_state["is_cleaning"] = False


# --- Offline MuMu VDI Compact ---
def _find_mumu_vmm_manage(install_path: str) -> Path | None:
    candidates = [
        Path(install_path) / "nx_device" / "12.0" / "hypervisor" / "MuMuVMMManage.exe",
        Path(r"C:\Program Files\MuMuVMMVbox\Hypervisor\MuMuVMMManage.exe"),
    ]
    for candidate in candidates:
        if candidate.exists() and candidate.is_file():
            return candidate
    return None


def _get_running_mumu_vm_names(known_vm_names: list[str]) -> tuple[set[str], bool]:
    running: set[str] = set()
    unknown_running = False
    known_lower = [name.lower() for name in known_vm_names]

    for proc in psutil.process_iter(["name", "cmdline"]):
        try:
            pname = str(proc.info.get("name") or "").lower()
            if pname not in _MUMU_VM_PROCESS_NAMES:
                continue
            cmdline = proc.info.get("cmdline") or []
            cmd_tokens = [str(tok) for tok in cmdline]
            matched_any = False

            for idx, tok in enumerate(cmd_tokens):
                if tok in ("--comment", "--vm") and idx + 1 < len(cmd_tokens):
                    running.add(cmd_tokens[idx + 1].strip().lower())
                    matched_any = True

            joined = " ".join(cmd_tokens).lower()
            for vm_low in known_lower:
                if vm_low in joined:
                    running.add(vm_low)
                    matched_any = True

            if not matched_any:
                unknown_running = True
        except Exception:
            continue

    return running, unknown_running


def _is_vdi_file_locked(vdi_path: Path) -> bool:
    if os.name == "nt":
        handle = ctypes.windll.kernel32.CreateFileW(
            str(vdi_path),
            0xC0000000,
            0,
            None,
            3,
            0x80,
            None,
        )
        invalid_handle = ctypes.c_void_p(-1).value
        if handle == invalid_handle or handle == -1:
            return True
        ctypes.windll.kernel32.CloseHandle(handle)
        return False

    try:
        with open(vdi_path, "r+b"):
            return False
    except OSError:
        return True


def compact_stopped_mumu_vdis(trigger: str = "manual") -> dict:
    with _VDI_COMPACT_LOCK:
        with _AUTO_CLEAN_STATE_LOCK:
            _auto_clean_state["is_compacting_vdi"] = True

        try:
            install_path = str(
                CONFIG.get("mumu", {}).get("install_path", r"C:\Program Files\Netease\MuMuPlayer")
            )
            vms_dir = Path(install_path) / "vms"
            if not vms_dir.exists():
                res = {
                    "ok": False,
                    "trigger": trigger,
                    "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "total_freed_mb": 0.0,
                    "compacted_count": 0,
                    "skipped_count": 0,
                    "error_count": 0,
                    "vms": [],
                    "error": f"MuMu vms directory not found: {vms_dir}",
                }
                with _AUTO_CLEAN_STATE_LOCK:
                    _auto_clean_state["last_vdi_compact_result"] = res
                return res

            vmm_manage = _find_mumu_vmm_manage(install_path)
            if not vmm_manage:
                res = {
                    "ok": False,
                    "trigger": trigger,
                    "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    "total_freed_mb": 0.0,
                    "compacted_count": 0,
                    "skipped_count": 0,
                    "error_count": 0,
                    "vms": [],
                    "error": "MuMuVMMManage.exe not found",
                }
                with _AUTO_CLEAN_STATE_LOCK:
                    _auto_clean_state["last_vdi_compact_result"] = res
                return res

            vm_dirs = sorted([d for d in vms_dir.iterdir() if d.is_dir()], key=lambda d: d.name.lower())
            running_vms, unknown_running = _get_running_mumu_vm_names([d.name for d in vm_dirs])

            vm_results: list[dict] = []
            total_freed_mb = 0.0
            compacted_count = 0
            skipped_count = 0
            error_count = 0

            for vm_dir in vm_dirs:
                vdi_path = vm_dir / "data.vdi"
                if not vdi_path.exists() or not vdi_path.is_file():
                    continue

                before_mb = round(vdi_path.stat().st_size / (1024 * 1024), 1)
                is_running = (
                    unknown_running
                    or (vm_dir.name.lower() in running_vms)
                    or _is_vdi_file_locked(vdi_path)
                )
                if is_running:
                    skipped_count += 1
                    vm_results.append(
                        {
                            "vm_name": vm_dir.name,
                            "status": "skipped_running",
                            "before_mb": before_mb,
                            "after_mb": before_mb,
                            "freed_mb": 0.0,
                        }
                    )
                    continue

                try:
                    proc = subprocess.run(
                        [str(vmm_manage), "modifymedium", "disk", str(vdi_path), "--compact"],
                        capture_output=True,
                        text=True,
                        timeout=300,
                        creationflags=_CREATE_NO_WINDOW,
                    )
                    after_mb = round(vdi_path.stat().st_size / (1024 * 1024), 1)
                    freed_mb = max(0.0, round(before_mb - after_mb, 1))
                    if proc.returncode == 0:
                        compacted_count += 1
                        total_freed_mb = round(total_freed_mb + freed_mb, 1)
                        vm_results.append(
                            {
                                "vm_name": vm_dir.name,
                                "status": "compacted",
                                "before_mb": before_mb,
                                "after_mb": after_mb,
                                "freed_mb": freed_mb,
                            }
                        )
                    else:
                        error_count += 1
                        err_msg = (proc.stderr or proc.stdout or f"exit {proc.returncode}").strip()[:160]
                        vm_results.append(
                            {
                                "vm_name": vm_dir.name,
                                "status": "error",
                                "before_mb": before_mb,
                                "after_mb": after_mb,
                                "freed_mb": 0.0,
                                "error": err_msg,
                            }
                        )
                except Exception as exc:
                    error_count += 1
                    after_mb = round(vdi_path.stat().st_size / (1024 * 1024), 1) if vdi_path.exists() else before_mb
                    vm_results.append(
                        {
                            "vm_name": vm_dir.name,
                            "status": "error",
                            "before_mb": before_mb,
                            "after_mb": after_mb,
                            "freed_mb": 0.0,
                            "error": str(exc)[:160],
                        }
                    )

            now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            res = {
                "ok": error_count == 0 or compacted_count > 0,
                "trigger": trigger,
                "timestamp": now_str,
                "total_freed_mb": round(total_freed_mb, 1),
                "compacted_count": compacted_count,
                "skipped_count": skipped_count,
                "error_count": error_count,
                "vms": vm_results,
            }
            with _AUTO_CLEAN_STATE_LOCK:
                _auto_clean_state["last_vdi_compact_at"] = now_str
                _auto_clean_state["last_vdi_compact_result"] = res

            add_event(
                "clean",
                f"VDI Compact ({trigger}): {res['total_freed_mb']} MB freed "
                f"({compacted_count} compacted, {skipped_count} running skipped)",
            )
            return res
        finally:
            with _AUTO_CLEAN_STATE_LOCK:
                _auto_clean_state["is_compacting_vdi"] = False


# --- Auto Deep Clean Config & Scheduler Helpers ---
def _compute_next_scheduled_run(enabled: bool, target_hour: int) -> str | None:
    if not enabled:
        return None
    now = datetime.now()
    candidate = now.replace(hour=target_hour, minute=0, second=0, microsecond=0)
    if candidate <= now:
        candidate = candidate + timedelta(days=1)
    return candidate.strftime("%Y-%m-%d %H:%M")


def get_auto_clean_status() -> dict:
    with CONFIG_LOCK:
        maint = CONFIG.get("maintenance", {})
        enabled = bool(maint.get("auto_deep_clean_enabled", True))
        hour = max(0, min(23, int(maint.get("auto_deep_clean_hour", 4))))
        cfg_snapshot = {
            "auto_deep_clean_enabled": enabled,
            "auto_deep_clean_hour": hour,
            "auto_deep_clean_threshold_mb": max(100, int(maint.get("auto_deep_clean_threshold_mb", 500))),
            "auto_deep_clean_min_free_gb": float(maint.get("auto_deep_clean_min_free_gb", 30.0)),
            "auto_deep_clean_cooldown_hours": max(1, int(maint.get("auto_deep_clean_cooldown_hours", 6))),
            "auto_deep_clean_notify_min_mb": max(0, int(maint.get("auto_deep_clean_notify_min_mb", 50))),
            "auto_discovery_enabled": bool(maint.get("auto_discovery_enabled", True)),
            "auto_discovery_min_mb": max(1, int(maint.get("auto_discovery_min_mb", 20))),
            "auto_discovery_excludes": list(maint.get("auto_discovery_excludes", [])),
            "disabled_clean_targets": list(maint.get("disabled_clean_targets", [])),
            "custom_clean_targets": list(maint.get("custom_clean_targets", [])),
            "vdi_auto_compact_enabled": bool(maint.get("vdi_auto_compact_enabled", True)),
        }

    with _AUTO_CLEAN_STATE_LOCK:
        state_snapshot = {
            "last_auto_clean_at": _auto_clean_state["last_auto_clean_at"],
            "last_auto_clean_freed_mb": _auto_clean_state["last_auto_clean_freed_mb"],
            "last_trigger": _auto_clean_state["last_trigger"],
            "next_scheduled_run": _compute_next_scheduled_run(enabled, hour),
            "last_vdi_compact_at": _auto_clean_state["last_vdi_compact_at"],
            "last_vdi_compact_result": _auto_clean_state["last_vdi_compact_result"],
            "is_cleaning": _auto_clean_state["is_cleaning"],
            "is_compacting_vdi": _auto_clean_state["is_compacting_vdi"],
        }

    return {**cfg_snapshot, **state_snapshot}


def update_auto_clean_config(updates: dict) -> dict:
    if not isinstance(updates, dict):
        raise ValueError("Invalid deep clean configuration payload")

    with CONFIG_LOCK:
        maint = CONFIG.setdefault("maintenance", {})
        if "auto_deep_clean_enabled" in updates:
            maint["auto_deep_clean_enabled"] = bool(updates["auto_deep_clean_enabled"])
        if "auto_deep_clean_hour" in updates:
            maint["auto_deep_clean_hour"] = max(0, min(23, int(updates["auto_deep_clean_hour"])))
        if "auto_deep_clean_threshold_mb" in updates:
            maint["auto_deep_clean_threshold_mb"] = max(
                100, min(100000, int(updates["auto_deep_clean_threshold_mb"]))
            )
        if "auto_deep_clean_min_free_gb" in updates:
            maint["auto_deep_clean_min_free_gb"] = max(
                1.0, min(500.0, float(updates["auto_deep_clean_min_free_gb"]))
            )
        if "auto_deep_clean_cooldown_hours" in updates:
            maint["auto_deep_clean_cooldown_hours"] = max(
                1, min(168, int(updates["auto_deep_clean_cooldown_hours"]))
            )
        if "auto_deep_clean_notify_min_mb" in updates:
            maint["auto_deep_clean_notify_min_mb"] = max(
                0, min(10000, int(updates["auto_deep_clean_notify_min_mb"]))
            )
        if "auto_discovery_enabled" in updates:
            maint["auto_discovery_enabled"] = bool(updates["auto_discovery_enabled"])
        if "auto_discovery_min_mb" in updates:
            maint["auto_discovery_min_mb"] = max(1, min(5000, int(updates["auto_discovery_min_mb"])))
        if "vdi_auto_compact_enabled" in updates:
            maint["vdi_auto_compact_enabled"] = bool(updates["vdi_auto_compact_enabled"])

        if "auto_discovery_excludes" in updates:
            raw_exc = updates["auto_discovery_excludes"]
            if not isinstance(raw_exc, list):
                raise ValueError("auto_discovery_excludes must be a list")
            maint["auto_discovery_excludes"] = [str(x).strip() for x in raw_exc if str(x).strip()]

        if "disabled_clean_targets" in updates:
            raw_dis = updates["disabled_clean_targets"]
            if not isinstance(raw_dis, list):
                raise ValueError("disabled_clean_targets must be a list")
            maint["disabled_clean_targets"] = [str(x).strip() for x in raw_dis if str(x).strip()]

        save_config(CONFIG)

    return get_auto_clean_status()


def add_custom_clean_target(target_data: dict) -> dict:
    if not isinstance(target_data, dict):
        raise ValueError("Invalid custom target payload")

    name = str(target_data.get("name", "") or "").strip()
    if not name or len(name) > 64:
        raise ValueError("Target name must be between 1 and 64 characters")

    raw_path = str(target_data.get("path", "") or "").strip()
    ok, resolved_path, reason = validate_clean_target_path(raw_path)
    if not ok:
        raise ValueError(reason)

    category = str(target_data.get("category") or "Custom").strip()[:32] or "Custom"
    file_pattern = str(target_data.get("file_pattern") or "").strip()[:24] or None

    raw_age = target_data.get("max_age_days")
    max_age_days: int | None = None
    if raw_age not in (None, "", 0, "0"):
        parsed_age = int(raw_age)
        if parsed_age < 1 or parsed_age > 3650:
            raise ValueError("max_age_days must be between 1 and 3650")
        max_age_days = parsed_age

    entry = {
        "name": name,
        "category": category,
        "path": resolved_path,
        "file_pattern": file_pattern,
        "max_age_days": max_age_days,
        "enabled": bool(target_data.get("enabled", True)),
    }

    with CONFIG_LOCK:
        maint = CONFIG.setdefault("maintenance", {})
        custom_list = list(maint.get("custom_clean_targets", []))
        custom_list = [
            c
            for c in custom_list
            if isinstance(c, dict)
            and str(c.get("name", "")).strip().lower() != name.lower()
            and _norm_lower(str(c.get("path", ""))) != _norm_lower(resolved_path)
        ]
        custom_list.append(entry)
        maint["custom_clean_targets"] = custom_list
        save_config(CONFIG)

    add_event("system", f"Added custom clean target: {name} ({resolved_path})")
    return entry


def remove_custom_clean_target(name: str) -> bool:
    target_name = str(name or "").strip().lower()
    if not target_name:
        return False

    with CONFIG_LOCK:
        maint = CONFIG.setdefault("maintenance", {})
        custom_list = list(maint.get("custom_clean_targets", []))
        kept = [
            c
            for c in custom_list
            if isinstance(c, dict) and str(c.get("name", "")).strip().lower() != target_name
        ]
        if len(kept) == len(custom_list):
            return False
        maint["custom_clean_targets"] = kept
        save_config(CONFIG)

    add_event("system", f"Removed custom clean target: {name}")
    return True


def _emit_auto_clean_notification(
    trigger: str,
    clean_res: dict | None,
    vdi_res: dict | None = None,
) -> None:
    maint_cfg = CONFIG.get("maintenance", {})
    notify_min_mb = float(maint_cfg.get("auto_deep_clean_notify_min_mb", 50))
    clean_mb = float(clean_res.get("total_freed_mb", 0.0)) if clean_res else 0.0
    vdi_mb = float(vdi_res.get("total_freed_mb", 0.0)) if vdi_res else 0.0

    if clean_mb < notify_min_mb and vdi_mb < notify_min_mb:
        return

    fields: list[dict[str, object]] = [
        {"name": "Trigger", "value": trigger.capitalize(), "inline": True},
        {"name": "Cache Freed", "value": f"{clean_mb:.1f} MB", "inline": True},
    ]
    if clean_res:
        fields.append(
            {"name": "Files Deleted", "value": str(clean_res.get("total_deleted", 0)), "inline": True}
        )
    if vdi_res is not None:
        fields.append(
            {
                "name": "VDI Compacted",
                "value": f"{vdi_mb:.1f} MB ({vdi_res.get('compacted_count', 0)} VMs)",
                "inline": True,
            }
        )

    notifier.notify_sync(
        NotificationEvent(
            event_type="auto_clean",
            severity="info",
            title="Auto Deep Clean Completed",
            description=f"Automated maintenance reclaimed {round(clean_mb + vdi_mb, 1)} MB on host.",
            dedupe_key=f"auto_clean:{trigger}:{date.today().isoformat()}",
            fields=fields,
        )
    )


def evaluate_threshold_auto_clean(now_ts: float | None = None) -> dict | None:
    maint_cfg = CONFIG.get("maintenance", {})
    if not maint_cfg.get("auto_deep_clean_enabled", True):
        return None

    current_ts = now_ts if now_ts is not None else time.time()
    cooldown_sec = max(1, int(maint_cfg.get("auto_deep_clean_cooldown_hours", 6))) * 3600
    with _AUTO_CLEAN_STATE_LOCK:
        last_run = float(_auto_clean_state["last_threshold_run_ts"])
    if (current_ts - last_run) < cooldown_sec:
        return None

    preview = deep_clean_preview()
    enabled_cache_mb = round(sum(float(p.get("size_mb", 0.0)) for p in preview if p.get("enabled", True)), 1)
    threshold_mb = float(maint_cfg.get("auto_deep_clean_threshold_mb", 500))
    min_free_gb = float(maint_cfg.get("auto_deep_clean_min_free_gb", 30.0))

    try:
        free_gb = psutil.disk_usage("C:\\").free / (1024 ** 3)
    except Exception:
        free_gb = 999.0

    if enabled_cache_mb < threshold_mb and free_gb >= min_free_gb:
        return None

    with _AUTO_CLEAN_STATE_LOCK:
        _auto_clean_state["last_threshold_run_ts"] = current_ts

    clean_res = deep_clean_execute(targets=None, trigger="threshold")
    _emit_auto_clean_notification("threshold", clean_res)
    return clean_res


def run_scheduled_auto_clean() -> tuple[dict | None, dict | None]:
    maint_cfg = CONFIG.get("maintenance", {})
    if not maint_cfg.get("auto_deep_clean_enabled", True):
        return None, None

    today_str = date.today().isoformat()
    with _AUTO_CLEAN_STATE_LOCK:
        if _auto_clean_state["last_scheduled_date"] == today_str:
            return None, None
        _auto_clean_state["last_scheduled_date"] = today_str
        _auto_clean_state["last_threshold_run_ts"] = time.time()

    clean_res = deep_clean_execute(targets=None, trigger="scheduled")
    vdi_res = None
    if maint_cfg.get("vdi_auto_compact_enabled", True):
        vdi_res = compact_stopped_mumu_vdis(trigger="scheduled")

    _emit_auto_clean_notification("scheduled", clean_res, vdi_res)
    return clean_res, vdi_res


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
            creationflags=_CREATE_NO_WINDOW,
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
                creationflags=_CREATE_NO_WINDOW,
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
            creationflags=_CREATE_NO_WINDOW,
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
            subprocess.run(
                [str(adb), "connect", f"127.0.0.1:{port}"],
                capture_output=True,
                timeout=2,
                creationflags=_CREATE_NO_WINDOW,
            )
            r = subprocess.run(
                [str(adb), "-s", f"127.0.0.1:{port}", "shell", "df", "/data"],
                capture_output=True,
                text=True,
                timeout=5,
                creationflags=_CREATE_NO_WINDOW,
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
            creationflags=_CREATE_NO_WINDOW,
        )
        subprocess.run(
            [str(adb), "-s", f"127.0.0.1:{port}", "shell", "rm", "-rf", "/data/local/tmp/*"],
            capture_output=True,
            text=True,
            timeout=5,
            creationflags=_CREATE_NO_WINDOW,
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
            creationflags=_CREATE_NO_WINDOW,
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
            creationflags=_CREATE_NO_WINDOW,
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
                    creationflags=_CREATE_NO_WINDOW,
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
    last_auto_clean_threshold_check = 0.0
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

            auto_clean_hour = max(0, min(23, int(maint_cfg.get("auto_deep_clean_hour", 4))))
            if maint_cfg.get("auto_deep_clean_enabled", True) and current_hour == auto_clean_hour:
                try:
                    clean_res, vdi_res = await asyncio.to_thread(run_scheduled_auto_clean)
                    if clean_res is not None:
                        broadcast_payload_threadsafe(
                            {"type": "deep_clean_result", "data": clean_res, "result": clean_res}
                        )
                        if vdi_res is not None:
                            broadcast_payload_threadsafe({"type": "vdi_compact_result", "data": vdi_res})
                        broadcast_payload_threadsafe(
                            {"type": "auto_clean_status", "data": get_auto_clean_status()}
                        )
                except Exception:
                    pass

            if now - last_auto_clean_threshold_check >= 1800:
                try:
                    thresh_res = await asyncio.to_thread(evaluate_threshold_auto_clean, now)
                    if thresh_res is not None:
                        broadcast_payload_threadsafe(
                            {"type": "deep_clean_result", "data": thresh_res, "result": thresh_res}
                        )
                        broadcast_payload_threadsafe(
                            {"type": "auto_clean_status", "data": get_auto_clean_status()}
                        )
                except Exception:
                    pass
                last_auto_clean_threshold_check = now

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
