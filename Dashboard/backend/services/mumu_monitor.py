import asyncio
import copy
import json
import re
import subprocess
import threading
import time
import urllib.request
from pathlib import Path
from typing import Callable

import psutil

from backend.core.config import CONFIG, CONFIG_LOCK, save_config
from backend.core.events import add_event
from backend.services.discord_notifier import NotificationEvent, notifier
from backend.services.telemetry import increment_watchdog_recovery, set_cached_top_processes
from backend.services.win32_ops import disable_ecoqos_for_mumu, get_protected_names

# --- Process Classification Sets (Exact Match, Zero Substring Guessing) ---
HELPER_DENYLIST: frozenset[str] = frozenset(
    {
        "mumunxdevicecleaner.exe",
        "mumunxcrashreporter.exe",
        "mumuchecker.exe",
        "mumunxupdater.exe",
        "mumupermission.exe",
        "mumudeviceengineinstaller.exe",
        "mumustatisticsreporter.exe",
        "mumunxservice.exe",
        "mumuplayerremotebackend.exe",
        "mumuplayerremotehealthd.exe",
        "mumuplayerremoteservice.exe",
    }
)

LAUNCHER_ALLOWLIST: frozenset[str] = frozenset(
    {
        "mumunxmain.exe",
        "mumunxlauncher.exe",
    }
)

BASE_EMULATOR_ALLOWLIST: frozenset[str] = frozenset(
    {
        "mumunxdevice.exe",
        "mumuplayer.exe",
        "nemuheadless.exe",
    }
)

CLEANER_EXE = "mumunxdevicecleaner.exe"
CRASH_REPORTER_EXE = "mumunxcrashreporter.exe"

_VM_INDEX_RE = re.compile(r"(?:^|\s)(?:-v|--index)\s+(\d+)")
_CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def get_emulator_allowlist(configured_names: list[str] | None = None) -> set[str]:
    names = set(BASE_EMULATOR_ALLOWLIST)
    raw = configured_names if configured_names is not None else CONFIG.get("mumu", {}).get("process_names", [])
    for item in raw:
        low = str(item or "").strip().lower()
        if low and low not in HELPER_DENYLIST and low not in LAUNCHER_ALLOWLIST:
            names.add(low)
    return names


def classify_process_role(proc_name: str, emulator_allowlist: set[str] | None = None) -> str:
    low = (proc_name or "").strip().lower()
    if not low or low in HELPER_DENYLIST:
        return "helper"
    if low in LAUNCHER_ALLOWLIST:
        return "launcher"
    allow = emulator_allowlist if emulator_allowlist is not None else get_emulator_allowlist()
    if low in allow:
        return "emulator"
    return "other"


# --- Settle Window & Crash vs Clean Shutdown Tracker ---
class MuMuStateTracker:
    def __init__(
        self,
        settle_seconds: float = 4.0,
        max_settle_seconds: float = 10.0,
        context_grace_seconds: float = 15.0,
        clock: Callable[[], float] | None = None,
    ) -> None:
        self.settle_seconds = settle_seconds
        self.max_settle_seconds = max_settle_seconds
        self.context_grace_seconds = context_grace_seconds
        self._clock = clock or time.time

        self._initialized = False
        self._active_ids: set[str] = set()
        self._prev_launcher_running = False
        self._pending_drop: dict | None = None
        self._last_cleaner_ts: float | None = None
        self._last_crash_reporter_ts: float | None = None
        self._last_governor_ts: float | None = None

    @property
    def has_pending_settle(self) -> bool:
        return self._pending_drop is not None

    def mark_governor_action(self, now: float | None = None) -> None:
        self._last_governor_ts = now if now is not None else self._clock()

    def _within_grace(self, last_ts: float | None, now: float) -> bool:
        return last_ts is not None and (now - last_ts) <= self.context_grace_seconds

    def observe(
        self,
        device_ids: set[str],
        launcher_running: bool,
        cleaner_active: bool = False,
        crash_reporter_active: bool = False,
        now: float | None = None,
    ) -> list[dict]:
        ts = now if now is not None else self._clock()
        if cleaner_active:
            self._last_cleaner_ts = ts
        if crash_reporter_active:
            self._last_crash_reporter_ts = ts

        in_cleaner_ctx = cleaner_active or self._within_grace(self._last_cleaner_ts, ts)
        in_governor_ctx = self._within_grace(self._last_governor_ts, ts)
        in_crash_ctx = crash_reporter_active or self._within_grace(self._last_crash_reporter_ts, ts)

        current_ids = set(device_ids)

        if not self._initialized:
            self._initialized = True
            self._active_ids = current_ids
            self._prev_launcher_running = launcher_running
            return []

        dropped = self._active_ids - current_ids
        if dropped:
            if self._pending_drop is None:
                self._pending_drop = {
                    "started_at": ts,
                    "last_change_at": ts,
                    "initial_count": len(self._active_ids),
                    "lost_ids": set(dropped),
                    "saw_cleaner": in_cleaner_ctx,
                    "saw_governor": in_governor_ctx,
                    "saw_crash_reporter": in_crash_ctx,
                    "saw_launcher_exit": (not launcher_running) or (self._prev_launcher_running and not launcher_running),
                }
            else:
                self._pending_drop["last_change_at"] = ts
                self._pending_drop["lost_ids"].update(dropped)
                self._pending_drop["saw_cleaner"] |= in_cleaner_ctx
                self._pending_drop["saw_governor"] |= in_governor_ctx
                self._pending_drop["saw_crash_reporter"] |= in_crash_ctx
                self._pending_drop["saw_launcher_exit"] |= not launcher_running
        elif self._pending_drop is not None:
            self._pending_drop["saw_cleaner"] |= in_cleaner_ctx
            self._pending_drop["saw_governor"] |= in_governor_ctx
            self._pending_drop["saw_crash_reporter"] |= in_crash_ctx
            self._pending_drop["saw_launcher_exit"] |= not launcher_running
            if len(current_ids) >= self._pending_drop["initial_count"]:
                self._pending_drop = None

        self._active_ids = current_ids
        self._prev_launcher_running = launcher_running

        if self._pending_drop is None:
            return []

        elapsed_since_change = ts - self._pending_drop["last_change_at"]
        elapsed_total = ts - self._pending_drop["started_at"]
        if elapsed_since_change < self.settle_seconds and elapsed_total < self.max_settle_seconds:
            return []

        pending = self._pending_drop
        self._pending_drop = None

        remaining = len(current_ids)
        net_lost = max(0, pending["initial_count"] - remaining)
        if net_lost == 0:
            return []

        if pending["saw_crash_reporter"]:
            classification = "crash"
        elif pending["saw_cleaner"] or pending["saw_governor"] or pending["saw_launcher_exit"]:
            classification = "intentional_close"
        else:
            classification = "crash"

        return [
            {
                "classification": classification,
                "initial_count": pending["initial_count"],
                "remaining_count": remaining,
                "lost_count": net_lost,
                "lost_ids": sorted(pending["lost_ids"]),
                "saw_cleaner": pending["saw_cleaner"],
                "saw_crash_reporter": pending["saw_crash_reporter"],
                "saw_launcher_exit": pending["saw_launcher_exit"],
                "saw_governor": pending["saw_governor"],
            }
        ]


# --- Hybrid MuMuManager CLI Discovery ---
_mgr_backoff_until = 0.0
_mgr_last_cache: dict[int, dict] = {}


def parse_mumu_manager_json(raw_stdout: str) -> dict[int, dict]:
    parsed: dict[int, dict] = {}
    if not raw_stdout or not raw_stdout.strip():
        return parsed
    data = json.loads(raw_stdout.strip())
    items: list[dict] = []
    if isinstance(data, dict):
        if "index" in data or "pid" in data:
            items = [data]
        else:
            for k, v in data.items():
                if isinstance(v, dict):
                    entry = dict(v)
                    entry.setdefault("index", k)
                    items.append(entry)
    elif isinstance(data, list):
        items = [x for x in data if isinstance(x, dict)]

    for item in items:
        pid = item.get("pid")
        try:
            pid_int = int(pid) if pid else 0
        except (TypeError, ValueError):
            pid_int = 0
        if pid_int > 0:
            parsed[pid_int] = item
    return parsed


def query_mumu_manager_sync(install_path: str | None = None) -> dict[int, dict]:
    global _mgr_backoff_until, _mgr_last_cache
    now = time.time()
    if now < _mgr_backoff_until:
        return _mgr_last_cache

    base = Path(install_path or CONFIG.get("mumu", {}).get("install_path", r"C:\Program Files\Netease\MuMuPlayer"))
    mgr_path = base / "nx_main" / "MuMuManager.exe"
    if not mgr_path.exists():
        _mgr_backoff_until = now + 60.0
        return {}

    try:
        r = subprocess.run(
            [str(mgr_path), "info", "-v", "all"],
            capture_output=True,
            text=True,
            timeout=4,
            creationflags=_CREATE_NO_WINDOW,
        )
        if r.returncode == 0 and r.stdout.strip():
            _mgr_last_cache = parse_mumu_manager_json(r.stdout)
            return _mgr_last_cache
    except Exception:
        pass

    _mgr_backoff_until = now + 60.0
    return {}


# --- Persistent Process Cache & Single-Pass Sampler ---
_process_sampler_lock = threading.Lock()
_proc_cache: dict[int, psutil.Process] = {}
_pid_slot_map: dict[int, int] = {}
_state_tracker = MuMuStateTracker(settle_seconds=4.0)

_cached_mumu_instances: list[dict] = []
_cached_mumu_health: dict = {
    "devices": [],
    "launchers": [],
    "total_instances": 0,
    "running": False,
    "count": 0,
    "launcher_running": False,
    "cleaner_active": False,
    "pending_settle": False,
    "vm_disk": [],
    "vm_disk_last_check": None,
    "instance_places": {},
    "game_presets": [],
    "auto_rejoin_global": True,
    "instance_auto_rejoin": {},
}


# --- Auto-Rejoin Policy & Canonical Slot/Port Mapping ---
def get_adb_port_for_instance(instance_idx: int) -> int:
    with _process_sampler_lock:
        for inst in _cached_mumu_instances:
            if inst.get("type") == "Emulator" and inst.get("instance_index") == instance_idx:
                port_val = inst.get("adb_port")
                if isinstance(port_val, int) and port_val > 0:
                    return port_val
    mumu_cfg = CONFIG.get("mumu", {})
    base_port = int(mumu_cfg.get("adb_base_port", 16384))
    step = int(mumu_cfg.get("adb_port_step", 32))
    return base_port + ((max(1, int(instance_idx)) - 1) * step)


def resolve_instance_index_from_serial(serial: str, fallback_idx: int = 1) -> int:
    match = re.search(r":(\d+)$", str(serial or "").strip())
    if not match:
        return fallback_idx
    port = int(match.group(1))
    mumu_cfg = CONFIG.get("mumu", {})
    base_port = int(mumu_cfg.get("adb_base_port", 16384))
    step = int(mumu_cfg.get("adb_port_step", 32))
    if step > 0 and port >= base_port and (port - base_port) % step == 0:
        return ((port - base_port) // step) + 1
    return fallback_idx


def is_auto_rejoin_enabled(instance_idx: int | str, serial: str = "") -> bool:
    with CONFIG_LOCK:
        mumu_cfg = CONFIG.get("mumu", {})
        if not bool(mumu_cfg.get("auto_reconnect", True)):
            return False
        raw_flags = mumu_cfg.get("instance_auto_rejoin", {})
        flags = raw_flags if isinstance(raw_flags, dict) else {}

        if serial:
            slot_from_serial = resolve_instance_index_from_serial(serial, -1)
            if slot_from_serial > 0 and str(slot_from_serial) in flags:
                return bool(flags[str(slot_from_serial)])
            if serial in flags:
                return bool(flags[serial])

        idx_key = str(instance_idx) if instance_idx is not None else ""
        if idx_key and idx_key in flags:
            return bool(flags[idx_key])

        return True


def set_auto_rejoin(instance_idx: int | None, enabled: bool) -> dict:
    idx: int | None = None
    if instance_idx is not None:
        idx = int(instance_idx)
        if idx < 1:
            raise ValueError("instance must be >= 1")

    flag_bool = bool(enabled)
    with CONFIG_LOCK:
        mumu_cfg = CONFIG.setdefault("mumu", {})
        flags = mumu_cfg.get("instance_auto_rejoin")
        if not isinstance(flags, dict):
            flags = {}
            mumu_cfg["instance_auto_rejoin"] = flags
        if idx is None:
            mumu_cfg["auto_reconnect"] = flag_bool
        else:
            flags[str(idx)] = flag_bool
        save_config(CONFIG)
        global_enabled = bool(mumu_cfg.get("auto_reconnect", True))
        flags_snap = copy.deepcopy(flags)

    if flag_bool:
        now = time.time()
        if idx is None:
            _mumu_consecutive_idle.clear()
            for hb in _bot_heartbeats.values():
                hb["last_seen"] = now
        else:
            target_serial = f"127.0.0.1:{get_adb_port_for_instance(idx)}"
            _mumu_consecutive_idle.pop(target_serial, None)
            for key in list(_mumu_consecutive_idle.keys()):
                if resolve_instance_index_from_serial(key, -1) == idx:
                    _mumu_consecutive_idle.pop(key, None)
            for key, hb in _bot_heartbeats.items():
                if key == target_serial or resolve_instance_index_from_serial(key, -1) == idx:
                    hb["last_seen"] = now

    with _process_sampler_lock:
        _cached_mumu_health["auto_rejoin_global"] = global_enabled
        _cached_mumu_health["instance_auto_rejoin"] = copy.deepcopy(flags_snap)
        for dev in _cached_mumu_health.get("devices", []):
            dev_idx = dev.get("index") or dev.get("instance_index")
            dev["auto_rejoin"] = global_enabled and bool(flags_snap.get(str(dev_idx), True))
        for inst in _cached_mumu_instances:
            if inst.get("type") == "Emulator":
                inst_idx = inst.get("index") or inst.get("instance_index")
                inst["auto_rejoin"] = global_enabled and bool(flags_snap.get(str(inst_idx), True))

    if idx is None:
        add_event("system", f"Global Auto-Rejoin {'enabled' if flag_bool else 'disabled'}")
    else:
        add_event("system", f"Instance #{idx} Auto-Rejoin {'enabled' if flag_bool else 'disabled'}")

    return {
        "instance": idx,
        "enabled": flag_bool,
        "global": global_enabled,
        "instance_auto_rejoin": flags_snap,
    }

_vm_disk_cache_ref: list = []
_vm_disk_last_check_ref: str | None = None


def set_vm_disk_snapshot(vm_disk: list, last_check: str | None) -> None:
    global _vm_disk_cache_ref, _vm_disk_last_check_ref
    _vm_disk_cache_ref = vm_disk
    _vm_disk_last_check_ref = last_check
    with _process_sampler_lock:
        _cached_mumu_health["vm_disk"] = vm_disk
        _cached_mumu_health["vm_disk_last_check"] = last_check


def _extract_vm_slot_from_cmdline(proc: psutil.Process) -> int | None:
    try:
        cmd = " ".join(proc.cmdline())
        m = _VM_INDEX_RE.search(cmd)
        if m:
            return int(m.group(1))
    except Exception:
        pass
    return None


def _assign_instance_index(pid: int, mgr_info: dict | None, proc: psutil.Process) -> int:
    if mgr_info and "index" in mgr_info:
        try:
            idx = int(mgr_info["index"]) + 1
            _pid_slot_map[pid] = idx
            return idx
        except (TypeError, ValueError):
            pass

    cmd_slot = _extract_vm_slot_from_cmdline(proc)
    if cmd_slot is not None:
        idx = cmd_slot + 1
        _pid_slot_map[pid] = idx
        return idx

    if pid in _pid_slot_map:
        return _pid_slot_map[pid]

    used = set(_pid_slot_map.values())
    candidate = 1
    while candidate in used:
        candidate += 1
    _pid_slot_map[pid] = candidate
    return candidate


def _emit_settled_transition(event: dict) -> None:
    remaining = event["remaining_count"]
    lost = event["lost_count"]
    initial = event["initial_count"]
    classification = event["classification"]

    if classification == "crash":
        msg = f"MuMu Instance crash detected -- {lost} instance(s) disappeared (remaining: {remaining})"
        add_event("crash", msg)
        reason_detail = (
            "Crash reporter process detected."
            if event["saw_crash_reporter"]
            else "Emulator process exited while MuMu launcher remained active."
        )
        notifier.notify_sync(
            NotificationEvent(
                event_type="mumu_crash",
                severity="critical",
                title="MuMu Instance Crash Detected",
                description=(
                    f"{lost} instance(s) terminated unexpectedly.\n"
                    f"Active devices: {remaining} (was {initial})\n"
                    f"Detection: {reason_detail}"
                ),
                dedupe_key=f"mumu_crash:{remaining}:{lost}",
                fields=[
                    {"name": "Remaining Instances", "value": f"{remaining} running", "inline": True},
                    {"name": "Impact", "value": f"-{lost} instance(s) offline", "inline": True},
                    {"name": "Previous Count", "value": str(initial), "inline": True},
                ],
            )
        )
    else:
        ctx_parts = []
        if event["saw_cleaner"]:
            ctx_parts.append("Clean Disk")
        if event["saw_launcher_exit"]:
            ctx_parts.append("Launcher Exit")
        if event["saw_governor"]:
            ctx_parts.append("Governor Action")
        ctx_label = ", ".join(ctx_parts) if ctx_parts else "Intentional Shutdown"
        add_event(
            "mumu",
            f"MuMu shutdown settled ({ctx_label}): -{lost} instance(s), {remaining} remaining",
        )


def _sample_all_processes_sync() -> None:
    global _cached_mumu_instances, _cached_mumu_health

    try:
        disable_ecoqos_for_mumu()
    except Exception:
        pass

    emulator_allowlist = get_emulator_allowlist()
    protected_names = get_protected_names()
    mgr_by_pid = query_mumu_manager_sync()

    all_procs: list[dict] = []
    mumu_instances: list[dict] = []
    seen_pids: set[int] = set()
    cleaner_active = False
    crash_reporter_active = False

    for proc in psutil.process_iter(["pid", "name", "memory_info", "create_time"]):
        try:
            pid = int(proc.info["pid"])
            seen_pids.add(pid)
            raw_name = proc.info["name"] or "Unknown"
            low_name = raw_name.lower()

            if low_name == CLEANER_EXE:
                cleaner_active = True
            elif low_name == CRASH_REPORTER_EXE:
                crash_reporter_active = True

            mem = proc.info["memory_info"]
            rss = mem.rss if mem else 0
            ram_mb = round(rss / (1024 ** 2), 1)

            all_procs.append(
                {
                    "pid": pid,
                    "name": raw_name,
                    "ram_mb": ram_mb,
                    "cpu_percent": 0.0,
                    "protected": low_name in protected_names,
                }
            )

            role = classify_process_role(low_name, emulator_allowlist)
            if role not in ("emulator", "launcher"):
                continue

            cached_proc = _proc_cache.get(pid)
            if cached_proc is None:
                cached_proc = psutil.Process(pid)
                cached_proc.cpu_percent(interval=None)
                _proc_cache[pid] = cached_proc
                cpu_pct = 0.0
            else:
                try:
                    cpu_pct = round(cached_proc.cpu_percent(interval=None), 1)
                except Exception:
                    cpu_pct = 0.0

            uptime_sec = max(0.0, time.time() - float(proc.info["create_time"] or time.time()))
            hours = int(uptime_sec // 3600)
            minutes = int((uptime_sec % 3600) // 60)
            is_bloated = ram_mb >= 4000.0
            is_device = role == "emulator"

            device_idx = 0
            adb_port: int | None = None
            auto_rejoin_val = True
            saved_username = ""

            if is_device:
                mgr_info = mgr_by_pid.get(pid)
                device_idx = _assign_instance_index(pid, mgr_info, cached_proc)
                raw_port = mgr_info.get("adb_port") if isinstance(mgr_info, dict) else None
                try:
                    adb_port = int(raw_port) if raw_port else None
                except (TypeError, ValueError):
                    adb_port = None
                if not adb_port or adb_port <= 0:
                    mumu_snap = CONFIG.get("mumu", {})
                    base_p = int(mumu_snap.get("adb_base_port", 16384))
                    step_p = int(mumu_snap.get("adb_port_step", 32))
                    adb_port = base_p + ((max(1, device_idx) - 1) * step_p)
                auto_rejoin_val = is_auto_rejoin_enabled(device_idx, f"127.0.0.1:{adb_port}")
                saved_username = str(
                    CONFIG.get("mumu", {}).get("instance_usernames", {}).get(str(device_idx), "") or ""
                )
                game_fields = _build_device_game_fields(device_idx, saved_username)
            else:
                game_fields = {
                    "presence_status": "Unknown",
                    "active_game": "Unassigned",
                    "active_place_id": None,
                    "live_game_name": None,
                    "place_id": 0,
                    "target_place_id": 0,
                    "configured_place_id": 0,
                    "target_game": "Unassigned",
                    "target_game_name": "Unassigned",
                }

            entry: dict = {
                "pid": pid,
                "name": raw_name,
                "cpu_percent": cpu_pct,
                "ram_mb": ram_mb,
                "uptime": f"{hours}h{minutes:02d}m",
                "uptime_seconds": int(uptime_sec),
                "status": "running",
                "is_bloated": is_bloated,
                "index": device_idx if is_device else 0,
                "instance_index": device_idx if is_device else 0,
                "type": "Emulator" if is_device else "Launcher",
                "username": saved_username,
                **game_fields,
            }
            if is_device:
                entry["adb_port"] = adb_port
                entry["auto_rejoin"] = auto_rejoin_val
            mumu_instances.append(entry)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    for dead_pid in list(_proc_cache.keys()):
        if dead_pid not in seen_pids:
            _proc_cache.pop(dead_pid, None)
    for dead_pid in list(_pid_slot_map.keys()):
        if dead_pid not in seen_pids:
            _pid_slot_map.pop(dead_pid, None)

    all_procs.sort(key=lambda x: x["ram_mb"], reverse=True)
    set_cached_top_processes(all_procs[:30])

    devices = sorted(
        [i for i in mumu_instances if i["type"] == "Emulator"],
        key=lambda x: (x["instance_index"], x["pid"]),
    )
    launchers = [i for i in mumu_instances if i["type"] == "Launcher"]
    current_device_count = len(devices)
    launcher_running = len(launchers) > 0

    device_ids = {f"{d['instance_index']}:{d['pid']}" for d in devices}
    settled_events = _state_tracker.observe(
        device_ids=device_ids,
        launcher_running=launcher_running,
        cleaner_active=cleaner_active,
        crash_reporter_active=crash_reporter_active,
    )
    for ev in settled_events:
        _emit_settled_transition(ev)

    with CONFIG_LOCK:
        mumu_cfg = CONFIG.get("mumu", {})
        instance_places_snap = copy.deepcopy(mumu_cfg.get("instance_places", {}))
        game_presets_snap = _normalize_game_presets(mumu_cfg.get("game_presets", []))
        auto_rejoin_global = bool(mumu_cfg.get("auto_reconnect", True))
        raw_rejoin_flags = mumu_cfg.get("instance_auto_rejoin", {})
        instance_auto_rejoin_snap = (
            copy.deepcopy(raw_rejoin_flags) if isinstance(raw_rejoin_flags, dict) else {}
        )

    with _process_sampler_lock:
        _cached_mumu_instances = mumu_instances
        _cached_mumu_health = {
            "devices": devices,
            "launchers": launchers,
            "total_instances": current_device_count,
            "running": current_device_count > 0,
            "count": current_device_count,
            "launcher_running": launcher_running,
            "cleaner_active": cleaner_active,
            "pending_settle": _state_tracker.has_pending_settle,
            "vm_disk": list(_vm_disk_cache_ref),
            "vm_disk_last_check": _vm_disk_last_check_ref,
            "instance_places": instance_places_snap,
            "game_presets": game_presets_snap,
            "auto_rejoin_global": auto_rejoin_global,
            "instance_auto_rejoin": instance_auto_rejoin_snap,
        }


def get_mumu_instances() -> list[dict]:
    with _process_sampler_lock:
        return copy.deepcopy(_cached_mumu_instances)


def check_mumu_health() -> dict:
    with _process_sampler_lock:
        return copy.deepcopy(_cached_mumu_health)


async def process_sampler_loop() -> None:
    await asyncio.to_thread(_sample_all_processes_sync)
    while True:
        try:
            await asyncio.to_thread(_sample_all_processes_sync)
        except asyncio.CancelledError:
            break
        except Exception:
            pass
        await asyncio.sleep(1.5)


# --- MuMu ADB, Roblox Presence & Watchdog Recovery ---
def find_mumu_adb() -> Path | None:
    install_path = Path(CONFIG.get("mumu", {}).get("install_path", "C:/Program Files/Netease/MuMuPlayer"))
    candidates = [
        install_path / "nx_main" / "adb.exe",
        install_path / "nx_device" / "12.0" / "shell" / "adb.exe",
        install_path / "nx_device" / "15.0" / "shell" / "adb.exe",
        Path(r"C:\Program Files\Netease\MuMuPlayer\nx_device\12.0\shell\adb.exe"),
        Path(r"C:\Program Files\Netease\MuMuPlayer\nx_device\15.0\shell\adb.exe"),
    ]
    for c in candidates:
        if c.exists():
            return c
    if install_path.exists():
        for found in install_path.rglob("adb.exe"):
            return found
    try:
        result = subprocess.run(
            ["where", "adb"],
            capture_output=True,
            text=True,
            timeout=5,
            creationflags=_CREATE_NO_WINDOW,
        )
        if result.returncode == 0 and result.stdout.strip():
            return Path(result.stdout.strip().splitlines()[0].strip())
    except Exception:
        pass
    return None


def get_mumu_adb_devices() -> list[str]:
    adb = find_mumu_adb()
    if not adb:
        return []
    try:
        r = subprocess.run(
            [str(adb), "devices"],
            capture_output=True,
            text=True,
            timeout=5,
            creationflags=_CREATE_NO_WINDOW,
        )
        if r.returncode == 0:
            devices = []
            for line in r.stdout.strip().splitlines()[1:]:
                parts = line.strip().split()
                if len(parts) >= 2 and parts[1] == "device":
                    devices.append(parts[0])
            return devices
    except Exception:
        pass
    return []


_instance_auto_learned_place: dict[str, int] = {}
_place_name_cache: dict[int, str] = {
    98800969324557: "Storage Hunters",
    9640154: "Storage Hunters",
    17450551531: "Gym League",
    17017769292: "Anime Defenders",
    2753915549: "Blox Fruits",
}
_place_name_fail_until: dict[int, float] = {}
_user_id_cache: dict[str, int] = {}
_instance_live_presence: dict[str, dict] = {}
_bot_heartbeats: dict[str, dict] = {}
_mumu_consecutive_idle: dict[str, int] = {}


def validate_place_id(raw: object, allow_zero: bool = False) -> int:
    msg = (
        "place_id must be a non-negative integer"
        if allow_zero
        else "place_id must be a positive integer"
    )
    if raw is None or isinstance(raw, bool):
        raise ValueError(msg)
    if isinstance(raw, float):
        if not raw.is_integer():
            raise ValueError(msg)
        num = int(raw)
    elif isinstance(raw, int):
        num = raw
    else:
        text = str(raw).strip()
        if not re.fullmatch(r"-?\d+", text):
            raise ValueError(msg)
        num = int(text)

    if allow_zero:
        if num < 0:
            raise ValueError(msg)
    elif num <= 0:
        raise ValueError(msg)
    return num


_validate_place_id = validate_place_id


def _normalize_game_presets(raw_presets: object) -> list[dict]:
    if not isinstance(raw_presets, list):
        return []
    normalized: list[dict] = []
    seen_ids: set[int] = set()
    for item in raw_presets:
        if not isinstance(item, dict):
            continue
        try:
            pid = validate_place_id(item.get("place_id"), allow_zero=False)
        except ValueError:
            continue
        if pid in seen_ids:
            continue
        seen_ids.add(pid)
        clean_name = str(item.get("name") or "").strip()[:100]
        normalized.append({"place_id": pid, "name": clean_name or f"Place {pid}"})
    return normalized


def _find_preset_name(place_id: int) -> str | None:
    if not place_id or place_id <= 0:
        return None
    with CONFIG_LOCK:
        raw_presets = CONFIG.get("mumu", {}).get("game_presets", [])
        if not isinstance(raw_presets, list):
            return None
        for item in raw_presets:
            if not isinstance(item, dict):
                continue
            try:
                pid = int(item.get("place_id", 0))
            except (TypeError, ValueError):
                continue
            if pid == place_id:
                name = str(item.get("name") or "").strip()
                if name:
                    return name
    return None


def resolve_roblox_game_name_sync(
    place_id: int,
    use_presets: bool = True,
    use_cache: bool = True,
) -> str:
    if not place_id or place_id <= 0:
        return "Unassigned"
    if use_presets:
        preset_name = _find_preset_name(place_id)
        if preset_name:
            return preset_name
    if use_cache and place_id in _place_name_cache:
        return _place_name_cache[place_id]
    if time.time() < _place_name_fail_until.get(place_id, 0.0):
        return f"Place {place_id}"

    try:
        u_url = f"https://apis.roblox.com/universes/v1/places/{place_id}/universe"
        req = urllib.request.Request(u_url, headers={"User-Agent": "Mozilla/5.0 Genesis/3.0"})
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            u_data = json.loads(resp.read().decode("utf-8"))
            universe_id = u_data.get("universeId")
        if not universe_id:
            _place_name_fail_until[place_id] = time.time() + 60.0
            return f"Place {place_id}"

        g_url = f"https://games.roblox.com/v1/games?universeIds={universe_id}"
        req2 = urllib.request.Request(g_url, headers={"User-Agent": "Mozilla/5.0 Genesis/3.0"})
        with urllib.request.urlopen(req2, timeout=3.5) as resp2:
            g_data = json.loads(resp2.read().decode("utf-8"))
            items = g_data.get("data", [])
            if items and items[0].get("name"):
                raw_name = items[0].get("name", "").strip()
                if raw_name:
                    _place_name_fail_until.pop(place_id, None)
                    _place_name_cache[place_id] = raw_name
                    return raw_name
    except Exception:
        pass

    _place_name_fail_until[place_id] = time.time() + 60.0
    return f"Place {place_id}"


def get_roblox_user_id_sync(username: str) -> int | None:
    if not username:
        return None
    uname_lower = username.strip().lower()
    if uname_lower in _user_id_cache:
        return _user_id_cache[uname_lower]
    try:
        payload = json.dumps({"usernames": [username.strip()], "excludeBannedUsers": True}).encode("utf-8")
        req = urllib.request.Request(
            "https://users.roblox.com/v1/usernames/users",
            data=payload,
            headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 Genesis/3.0"},
        )
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            u_data = json.loads(resp.read().decode("utf-8"))
            data_list = u_data.get("data", [])
            if data_list:
                uid = int(data_list[0].get("id"))
                _user_id_cache[uname_lower] = uid
                return uid
    except Exception:
        pass
    return None


def get_roblox_user_presence_sync(user_id: int) -> dict | None:
    if not user_id or user_id <= 0:
        return None
    try:
        payload = json.dumps({"userIds": [user_id]}).encode("utf-8")
        req = urllib.request.Request(
            "https://presence.roblox.com/v1/presence/users",
            data=payload,
            headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 Genesis/3.0"},
        )
        with urllib.request.urlopen(req, timeout=3.5) as resp:
            p_data = json.loads(resp.read().decode("utf-8"))
            presences = p_data.get("userPresences", [])
            if presences:
                p = presences[0]
                ptype = p.get("userPresenceType", 0)
                status_map = {0: "Offline", 1: "Online", 2: "InGame", 3: "InStudio"}
                place_id = p.get("placeId") or p.get("rootPlaceId")
                last_loc = p.get("lastLocation") or ""
                return {
                    "presence_type": ptype,
                    "presence_status": status_map.get(ptype, "Unknown"),
                    "place_id": int(place_id) if place_id else None,
                    "game_name": last_loc,
                    "game_id": p.get("gameId"),
                }
    except Exception:
        pass
    return None


def _build_device_game_fields(device_idx: int, saved_username: str) -> dict:
    configured_place_id = get_configured_instance_place_id(device_idx)
    target_place_id = get_instance_place_id(device_idx)
    target_game_name = get_game_name_for_place_id(target_place_id)
    live_pres = _instance_live_presence.get(str(device_idx)) or {}
    presence_status = live_pres.get("presence_status", "Offline" if saved_username else "Manual")
    live_is_in_game = presence_status == "InGame"
    raw_live_place = live_pres.get("place_id")
    try:
        parsed_live_place = int(raw_live_place) if raw_live_place else 0
    except (TypeError, ValueError):
        parsed_live_place = 0
    live_place_id = parsed_live_place if (live_is_in_game and parsed_live_place > 0) else None
    raw_live_game = str(live_pres.get("game_name") or "").strip()
    live_game_name = (
        raw_live_game
        if (
            live_is_in_game
            and raw_live_game
            and raw_live_game.lower() not in ("roblox", "website", "experience")
        )
        else (get_game_name_for_place_id(live_place_id) if live_place_id else None)
    )
    return {
        "presence_status": presence_status,
        "active_game": live_game_name or target_game_name or "Unassigned",
        "active_place_id": live_place_id,
        "live_game_name": live_game_name,
        "place_id": target_place_id,
        "target_place_id": target_place_id,
        "configured_place_id": configured_place_id,
        "target_game": target_game_name,
        "target_game_name": target_game_name,
    }


def _sync_mumu_cache_from_config() -> None:
    with CONFIG_LOCK:
        mumu_cfg = CONFIG.get("mumu", {})
        instance_places_snap = copy.deepcopy(mumu_cfg.get("instance_places", {}))
        game_presets_snap = _normalize_game_presets(mumu_cfg.get("game_presets", []))
        raw_usernames = mumu_cfg.get("instance_usernames", {})
        usernames_snap = copy.deepcopy(raw_usernames) if isinstance(raw_usernames, dict) else {}
        auto_rejoin_global = bool(mumu_cfg.get("auto_reconnect", True))
        raw_rejoin_flags = mumu_cfg.get("instance_auto_rejoin", {})
        instance_auto_rejoin_snap = (
            copy.deepcopy(raw_rejoin_flags) if isinstance(raw_rejoin_flags, dict) else {}
        )

    with _process_sampler_lock:
        indices: set[int] = set()
        for dev in _cached_mumu_health.get("devices", []):
            raw_idx = dev.get("index") or dev.get("instance_index")
            if isinstance(raw_idx, int) and raw_idx > 0:
                indices.add(raw_idx)
        for inst in _cached_mumu_instances:
            if inst.get("type") == "Emulator":
                raw_idx = inst.get("index") or inst.get("instance_index")
                if isinstance(raw_idx, int) and raw_idx > 0:
                    indices.add(raw_idx)

    fields_by_idx = {
        idx: _build_device_game_fields(idx, str(usernames_snap.get(str(idx), "") or ""))
        for idx in indices
    }

    with _process_sampler_lock:
        _cached_mumu_health["instance_places"] = copy.deepcopy(instance_places_snap)
        _cached_mumu_health["game_presets"] = copy.deepcopy(game_presets_snap)
        _cached_mumu_health["auto_rejoin_global"] = auto_rejoin_global
        _cached_mumu_health["instance_auto_rejoin"] = copy.deepcopy(instance_auto_rejoin_snap)

        for dev in _cached_mumu_health.get("devices", []):
            dev_idx = dev.get("index") or dev.get("instance_index")
            if isinstance(dev_idx, int) and dev_idx in fields_by_idx:
                dev["username"] = str(usernames_snap.get(str(dev_idx), "") or "")
                dev["auto_rejoin"] = auto_rejoin_global and bool(
                    instance_auto_rejoin_snap.get(str(dev_idx), True)
                )
                dev.update(fields_by_idx[dev_idx])

        for inst in _cached_mumu_instances:
            if inst.get("type") == "Emulator":
                inst_idx = inst.get("index") or inst.get("instance_index")
                if isinstance(inst_idx, int) and inst_idx in fields_by_idx:
                    inst["username"] = str(usernames_snap.get(str(inst_idx), "") or "")
                    inst["auto_rejoin"] = auto_rejoin_global and bool(
                        instance_auto_rejoin_snap.get(str(inst_idx), True)
                    )
                    inst.update(fields_by_idx[inst_idx])


# --- Game Presets CRUD ---
def get_game_presets() -> list[dict]:
    with CONFIG_LOCK:
        return copy.deepcopy(
            _normalize_game_presets(CONFIG.get("mumu", {}).get("game_presets", []))
        )


def add_game_preset(place_id: object, name: str = "", upsert: bool = False) -> dict:
    pid = validate_place_id(place_id, allow_zero=False)
    clean_name = str(name or "").strip()[:100]

    with CONFIG_LOCK:
        existing_presets = _normalize_game_presets(CONFIG.get("mumu", {}).get("game_presets", []))
        already_exists = any(p["place_id"] == pid for p in existing_presets)
    if already_exists and not upsert:
        raise ValueError(f"Preset for Place ID {pid} already exists")

    if not clean_name:
        clean_name = resolve_roblox_game_name_sync(pid, use_presets=False)[:100]

    with CONFIG_LOCK:
        mumu_cfg = CONFIG.setdefault("mumu", {})
        presets = _normalize_game_presets(mumu_cfg.get("game_presets", []))
        existing = next((p for p in presets if p["place_id"] == pid), None)
        created = existing is None
        if existing is not None:
            if not upsert:
                raise ValueError(f"Preset for Place ID {pid} already exists")
            existing["name"] = clean_name
            entry = dict(existing)
        else:
            entry = {"place_id": pid, "name": clean_name}
            presets.append(entry)
        mumu_cfg["game_presets"] = presets
        save_config(CONFIG)
        presets_snap = copy.deepcopy(presets)

    _place_name_cache[pid] = clean_name
    _place_name_fail_until.pop(pid, None)
    _sync_mumu_cache_from_config()
    add_event("system", f"Game preset {'saved' if created else 'updated'}: {clean_name} ({pid})")
    return {"preset": entry, "presets": presets_snap, "created": created}


def update_game_preset(original_place_id: object, new_place_id: object, name: str = "") -> dict:
    orig_pid = validate_place_id(original_place_id, allow_zero=False)
    next_pid = validate_place_id(new_place_id, allow_zero=False)
    clean_name = str(name or "").strip()[:100]

    with CONFIG_LOCK:
        existing_presets = _normalize_game_presets(CONFIG.get("mumu", {}).get("game_presets", []))
        if not any(p["place_id"] == orig_pid for p in existing_presets):
            raise KeyError("Game preset not found")
        if next_pid != orig_pid and any(p["place_id"] == next_pid for p in existing_presets):
            raise ValueError(f"Preset for Place ID {next_pid} already exists")

    if not clean_name:
        clean_name = resolve_roblox_game_name_sync(
            next_pid,
            use_presets=False,
            use_cache=(orig_pid != next_pid),
        )[:100]

    with CONFIG_LOCK:
        mumu_cfg = CONFIG.setdefault("mumu", {})
        presets = _normalize_game_presets(mumu_cfg.get("game_presets", []))
        target = next((p for p in presets if p["place_id"] == orig_pid), None)
        if target is None:
            raise KeyError("Game preset not found")
        if next_pid != orig_pid and any(p["place_id"] == next_pid for p in presets):
            raise ValueError(f"Preset for Place ID {next_pid} already exists")
        target["place_id"] = next_pid
        target["name"] = clean_name
        entry = dict(target)
        mumu_cfg["game_presets"] = presets
        save_config(CONFIG)
        presets_snap = copy.deepcopy(presets)

    if orig_pid != next_pid:
        _place_name_cache.pop(orig_pid, None)
    _place_name_cache[next_pid] = clean_name
    _place_name_fail_until.pop(next_pid, None)
    _sync_mumu_cache_from_config()
    add_event("system", f"Game preset updated: {clean_name} ({next_pid})")
    return {"preset": entry, "presets": presets_snap}


def delete_game_preset(place_id: object) -> dict:
    pid = validate_place_id(place_id, allow_zero=False)
    with CONFIG_LOCK:
        mumu_cfg = CONFIG.setdefault("mumu", {})
        presets = _normalize_game_presets(mumu_cfg.get("game_presets", []))
        idx = next((i for i, p in enumerate(presets) if p["place_id"] == pid), None)
        if idx is None:
            raise KeyError("Game preset not found")
        removed = presets.pop(idx)
        mumu_cfg["game_presets"] = presets
        save_config(CONFIG)
        presets_snap = copy.deepcopy(presets)

    _place_name_cache.pop(pid, None)
    _sync_mumu_cache_from_config()
    add_event("system", f"Game preset removed: {removed['name']} ({pid})")
    return {"deleted_place_id": pid, "presets": presets_snap}


def set_instance_username(instance_idx: int | str, username: str) -> dict:
    inst_id = str(instance_idx)
    clean_username = str(username or "").strip()
    _instance_live_presence.pop(inst_id, None)
    with CONFIG_LOCK:
        mumu_cfg = CONFIG.setdefault("mumu", {})
        usernames = mumu_cfg.setdefault("instance_usernames", {})
        if clean_username:
            usernames[inst_id] = clean_username
        else:
            usernames.pop(inst_id, None)
        save_config(CONFIG)

    if clean_username:
        add_event("system", f"Instance #{inst_id} Roblox username set to '{clean_username}'")
        uid = get_roblox_user_id_sync(clean_username)
        if uid:
            pres = get_roblox_user_presence_sync(uid)
            if pres:
                pid = pres.get("place_id")
                gname = pres.get("game_name")
                if pid:
                    record_instance_active_place(inst_id, pid)
                    if not gname or gname.lower() in ("experience", "roblox"):
                        gname = resolve_roblox_game_name_sync(pid)
                _instance_live_presence[inst_id] = {
                    "username": clean_username,
                    "presence_type": pres.get("presence_type", 0),
                    "presence_status": pres.get("presence_status", "Offline"),
                    "place_id": pid,
                    "game_name": gname or (resolve_roblox_game_name_sync(pid) if pid else "Roblox"),
                    "last_updated": time.time(),
                }
    else:
        add_event("system", f"Instance #{inst_id} Roblox username cleared")

    _sync_mumu_cache_from_config()
    return _instance_live_presence.get(inst_id, {})


def record_instance_active_place(instance_idx: int | str, place_id: int, serial: str = "") -> None:
    if not place_id or place_id <= 0:
        return
    _instance_auto_learned_place[str(instance_idx)] = int(place_id)
    if serial:
        _instance_auto_learned_place[serial] = int(place_id)


def get_configured_instance_place_id(instance_idx: int | str, serial: str = "") -> int:
    with CONFIG_LOCK:
        mumu_cfg = CONFIG.get("mumu", {})
        instance_places = mumu_cfg.get("instance_places", {})
        if not isinstance(instance_places, dict):
            return 0
        for key in (str(instance_idx), serial):
            if key and key in instance_places:
                try:
                    val = int(instance_places[key])
                    if val > 0:
                        return val
                except (ValueError, TypeError):
                    continue
    return 0


def get_instance_place_id(instance_idx: int | str, serial: str = "") -> int:
    configured = get_configured_instance_place_id(instance_idx, serial)
    if configured > 0:
        return configured

    live = _instance_live_presence.get(str(instance_idx))
    if live and live.get("place_id"):
        try:
            live_pid = int(live["place_id"])
            if live_pid > 0:
                return live_pid
        except (ValueError, TypeError):
            pass

    if str(instance_idx) in _instance_auto_learned_place:
        return _instance_auto_learned_place[str(instance_idx)]
    if serial and serial in _instance_auto_learned_place:
        return _instance_auto_learned_place[serial]

    with CONFIG_LOCK:
        default_pid = CONFIG.get("mumu", {}).get("default_place_id", 0) or 0
    try:
        parsed_default = int(default_pid)
        return parsed_default if parsed_default > 0 else 0
    except (ValueError, TypeError):
        return 0


def set_instance_place_id(instance_idx: int | str, place_id: int) -> bool:
    try:
        pid = validate_place_id(place_id, allow_zero=True)
        with CONFIG_LOCK:
            mumu_cfg = CONFIG.setdefault("mumu", {})
            places = mumu_cfg.setdefault("instance_places", {})
            if pid == 0:
                places.pop(str(instance_idx), None)
                _instance_auto_learned_place.pop(str(instance_idx), None)
            else:
                places[str(instance_idx)] = pid
                _instance_auto_learned_place[str(instance_idx)] = pid
            save_config(CONFIG)
        _sync_mumu_cache_from_config()
        if pid == 0:
            add_event("system", f"Instance {instance_idx} target game cleared")
        else:
            gname = get_game_name_for_place_id(pid)
            add_event("system", f"Instance {instance_idx} target game set to {gname} ({pid})")
        return True
    except Exception as exc:
        print(f"[SET INSTANCE GAME ERROR] {exc}")
        return False


def get_game_name_for_place_id(place_id: int) -> str:
    if not place_id or place_id <= 0:
        return "Unassigned"
    preset_name = _find_preset_name(place_id)
    if preset_name:
        return preset_name
    if place_id in _place_name_cache:
        return _place_name_cache[place_id]
    return resolve_roblox_game_name_sync(place_id)


def apply_instance_game_update(
    instance_idx: int | str,
    raw_place_id: object,
    save_as_preset: bool = False,
    preset_name: str = "",
) -> dict:
    place_id = validate_place_id(raw_place_id, allow_zero=True)
    ok = set_instance_place_id(instance_idx, place_id)
    preset_res: dict | None = None

    clean_preset_name = str(preset_name or "").strip()
    if ok and save_as_preset and place_id > 0:
        already_present = any(p["place_id"] == place_id for p in get_game_presets())
        if clean_preset_name or not already_present:
            preset_res = add_game_preset(place_id, clean_preset_name, upsert=True)

    game_name = get_game_name_for_place_id(place_id)
    with CONFIG_LOCK:
        raw_places = CONFIG.get("mumu", {}).get("instance_places", {})
        instance_places_snap = copy.deepcopy(raw_places) if isinstance(raw_places, dict) else {}

    return {
        "ok": ok,
        "instance": instance_idx,
        "place_id": place_id,
        "game_name": game_name,
        "instance_places": instance_places_snap,
        "preset_res": preset_res,
    }


def record_bot_heartbeat(
    place_id: int | None,
    inst_id: int | str,
    player: str,
    status: str,
    extra: dict,
) -> dict:
    now = time.time()
    adb = find_mumu_adb()
    devices = get_mumu_adb_devices() if adb else []
    try:
        inst_num = int(inst_id)
    except (TypeError, ValueError):
        inst_num = 1
    expected_port = get_adb_port_for_instance(max(1, inst_num))
    expected_serial = f"127.0.0.1:{expected_port}"
    if expected_serial in devices:
        serial = expected_serial
    elif devices and 1 <= inst_num <= len(devices):
        matched = next(
            (d for d in devices if resolve_instance_index_from_serial(d, -1) == inst_num),
            None,
        )
        serial = matched or devices[inst_num - 1]
    elif devices:
        serial = devices[0]
    else:
        serial = expected_serial

    place_num: int | None = None
    if place_id is not None:
        try:
            place_num = int(place_id)
            record_instance_active_place(inst_id, place_num, serial)
        except (ValueError, TypeError):
            place_num = None
    if place_num is None:
        place_num = get_instance_place_id(inst_id, serial)

    _bot_heartbeats[serial] = {
        "last_seen": now,
        "status": status,
        "place_id": place_num,
        "player": player,
        "extra": extra,
    }

    return {
        "instance": inst_id,
        "serial": serial,
        "place_id": place_num,
        "game_name": get_game_name_for_place_id(place_num) if place_num else "Roblox",
        "status": status,
        "ack": now,
    }


def _run_cmd(cmd: list[str], timeout: int = 10) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            creationflags=_CREATE_NO_WINDOW,
        )
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(cmd, returncode=-1, stdout="", stderr="timeout")
    except Exception as exc:
        return subprocess.CompletedProcess(cmd, returncode=-1, stdout="", stderr=str(exc))


def governor_instance_action(instance_idx: int, action: str) -> dict:
    adb_path = find_mumu_adb()
    if not adb_path:
        return {"success": False, "error": "ADB not found"}

    _state_tracker.mark_governor_action()
    port = get_adb_port_for_instance(instance_idx)
    device_id = f"127.0.0.1:{port}"

    if action == "restart_game":
        place_id = get_instance_place_id(instance_idx)
        if place_id <= 0:
            return {"success": False, "error": "No target Place ID configured for this instance"}
        launch_cmd = f'am start -a android.intent.action.VIEW -d "roblox://placeId={place_id}"'
        _run_cmd([str(adb_path), "-s", device_id, "shell", "am", "force-stop", "com.roblox.client"])
        time.sleep(0.5)
        r_launch = _run_cmd([str(adb_path), "-s", device_id, "shell", launch_cmd])
        if r_launch.returncode != 0:
            err = (r_launch.stderr or r_launch.stdout or "").strip() or f"ADB restart failed for {device_id}"
            return {"success": False, "error": err}
        add_event("system", f"Governor: Restarted Roblox on Instance #{instance_idx} (Place {place_id})")
        return {"success": True, "instance": instance_idx, "action": "restart_game"}
    if action == "trim_ram":
        r1 = _run_cmd([str(adb_path), "-s", device_id, "shell", "echo", "3", ">", "/proc/sys/vm/drop_caches"])
        r2 = _run_cmd([str(adb_path), "-s", device_id, "shell", "fstrim", "-v", "/data"])
        if r1.returncode != 0 and r2.returncode != 0:
            err = (r2.stderr or r1.stderr or "").strip() or f"ADB trim failed for {device_id}"
            return {"success": False, "error": err}
        add_event("system", f"Governor: Memory & Storage trimmed for Instance #{instance_idx}")
        return {"success": True, "instance": instance_idx, "action": "trim_ram"}
    if action == "kill_game":
        r_kill = _run_cmd([str(adb_path), "-s", device_id, "shell", "am", "force-stop", "com.roblox.client"])
        if r_kill.returncode != 0:
            err = (r_kill.stderr or r_kill.stdout or "").strip() or f"ADB stop failed for {device_id}"
            return {"success": False, "error": err}
        add_event("warning", f"Governor: Stopped Roblox on Instance #{instance_idx}")
        return {"success": True, "instance": instance_idx, "action": "kill_game"}

    return {"success": False, "error": f"Unknown action {action}"}


def recover_roblox_instance(
    serial: str,
    place_id: int | None = None,
    instance_idx: int | str = 1,
) -> bool:
    adb = find_mumu_adb()
    if not adb:
        return False
    if not place_id or place_id <= 0:
        place_id = get_instance_place_id(instance_idx, serial)
    if not place_id or place_id <= 0:
        add_event(
            "warning",
            f"MuMu Watchdog: Skipped recovery on Instance {instance_idx} ({serial}) -- no target Place ID",
        )
        return False

    game_name = get_game_name_for_place_id(place_id)

    try:
        r_wm = subprocess.run(
            [str(adb), "-s", serial, "shell", "wm", "size"],
            capture_output=True,
            text=True,
            timeout=4,
            creationflags=_CREATE_NO_WINDOW,
        )
        w, h = 1600, 900
        if "Physical size:" in r_wm.stdout:
            dim_str = r_wm.stdout.split("Physical size:")[1].strip().split("x")
            if len(dim_str) == 2:
                dim_a, dim_b = int(dim_str[0]), int(dim_str[1])
                w, h = max(dim_a, dim_b), min(dim_a, dim_b)

        tap_x = int(w * 0.575)
        tap_y = int(h * 0.622)

        subprocess.run(
            [str(adb), "-s", serial, "shell", "input", "tap", str(tap_x), str(tap_y)],
            capture_output=True,
            timeout=4,
            creationflags=_CREATE_NO_WINDOW,
        )
        time.sleep(3)

        r_win = subprocess.run(
            [str(adb), "-s", serial, "shell", "dumpsys", "window", "displays"],
            capture_output=True,
            text=True,
            timeout=5,
            creationflags=_CREATE_NO_WINDOW,
        )
        is_roblox_focused = "ActivityNativeMain" in r_win.stdout and "Lawnchair" not in r_win.stdout

        if not is_roblox_focused:
            subprocess.run(
                [str(adb), "-s", serial, "shell", "am", "force-stop", "com.roblox.client"],
                capture_output=True,
                timeout=5,
                creationflags=_CREATE_NO_WINDOW,
            )
            time.sleep(0.5)
            deep_link = f"roblox://placeId={place_id}"
            subprocess.run(
                [str(adb), "-s", serial, "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", deep_link],
                capture_output=True,
                timeout=5,
                creationflags=_CREATE_NO_WINDOW,
            )

        increment_watchdog_recovery()
        add_event(
            "system",
            f"MuMu Watchdog: Auto-recovered Roblox on Instance {instance_idx} ({serial}) -> {game_name}",
        )
        notifier.notify_sync(
            NotificationEvent(
                event_type="watchdog_recovery",
                severity="recovery",
                title="Roblox Game Auto-Recovered",
                description=(
                    f"MuMu Autonomous Watchdog detected disconnect/freeze on Instance {instance_idx} ({serial}).\n"
                    f"Roblox rejoined into {game_name} ({place_id})."
                ),
                dedupe_key=f"watchdog_recovery:{instance_idx}",
                fields=[
                    {"name": "Instance", "value": f"Instance {instance_idx} ({serial})", "inline": True},
                    {"name": "Target Game", "value": f"{game_name} ({place_id})", "inline": True},
                    {"name": "Status", "value": "Rejoined", "inline": True},
                ],
            )
        )
        return True
    except Exception as exc:
        print(f"[MUMU RECOVERY ERROR] {exc}")
        return False


async def roblox_presence_tracker_loop() -> None:
    while True:
        try:
            with CONFIG_LOCK:
                instance_users = dict(CONFIG.get("mumu", {}).get("instance_usernames", {}))
            for inst_key, username in instance_users.items():
                if not username:
                    continue
                uid = await asyncio.to_thread(get_roblox_user_id_sync, username)
                if not uid:
                    continue
                pres = await asyncio.to_thread(get_roblox_user_presence_sync, uid)
                if pres:
                    pid = pres.get("place_id")
                    gname = pres.get("game_name")
                    if pid:
                        record_instance_active_place(inst_key, pid)
                        if not gname or gname.lower() in ("experience", "roblox"):
                            gname = await asyncio.to_thread(resolve_roblox_game_name_sync, pid)

                    with CONFIG_LOCK:
                        current_user = CONFIG.get("mumu", {}).get("instance_usernames", {}).get(str(inst_key), "")
                    if current_user == username:
                        _instance_live_presence[str(inst_key)] = {
                            "username": username,
                            "presence_type": pres.get("presence_type", 0),
                            "presence_status": pres.get("presence_status", "Offline"),
                            "place_id": pid,
                            "game_name": gname or (
                                await asyncio.to_thread(resolve_roblox_game_name_sync, pid)
                                if pid
                                else "Roblox"
                            ),
                            "last_updated": time.time(),
                        }

            for serial, hb in list(_bot_heartbeats.items()):
                pid = hb.get("place_id")
                if pid and time.time() - hb.get("last_seen", 0) < 60:
                    hb["game_name"] = await asyncio.to_thread(resolve_roblox_game_name_sync, pid)
        except asyncio.CancelledError:
            break
        except Exception:
            pass
        await asyncio.sleep(6)


def evaluate_watchdog_device_sync(
    adb: Path,
    serial: str,
    enum_idx: int,
    now: float | None = None,
) -> str:
    ts = now if now is not None else time.time()
    slot_idx = resolve_instance_index_from_serial(serial, enum_idx)
    if not is_auto_rejoin_enabled(slot_idx, serial):
        _mumu_consecutive_idle[serial] = 0
        return "skipped_disabled"

    hb = _bot_heartbeats.get(serial)
    if hb:
        last_seen = hb.get("last_seen", 0)
        if ts - last_seen > 45:
            place_id = get_instance_place_id(slot_idx, serial)
            recover_roblox_instance(serial, place_id, slot_idx)
            hb["last_seen"] = ts
            return "recovered_stale_hb"
        return "ok"

    r_pid = subprocess.run(
        [str(adb), "-s", serial, "shell", "pidof", "com.roblox.client"],
        capture_output=True,
        text=True,
        timeout=5,
        creationflags=_CREATE_NO_WINDOW,
    )
    pid_out = r_pid.stdout.strip() if r_pid.returncode == 0 else ""
    if not pid_out:
        _mumu_consecutive_idle[serial] = _mumu_consecutive_idle.get(serial, 0) + 1
        if _mumu_consecutive_idle[serial] >= 3:
            place_id = get_instance_place_id(slot_idx, serial)
            recover_roblox_instance(serial, place_id, slot_idx)
            _mumu_consecutive_idle[serial] = 0
            return "recovered_idle"
        return "idle_incremented"

    _mumu_consecutive_idle[serial] = 0
    return "ok"


async def mumu_game_watchdog_loop() -> None:
    await asyncio.sleep(20)
    while True:
        try:
            mumu_cfg = CONFIG.get("mumu", {})
            if mumu_cfg.get("auto_reconnect", True):
                adb = await asyncio.to_thread(find_mumu_adb)
                if adb:
                    devices = await asyncio.to_thread(get_mumu_adb_devices)
                    for enum_idx, serial in enumerate(devices, 1):
                        await asyncio.to_thread(evaluate_watchdog_device_sync, adb, serial, enum_idx)
            else:
                _mumu_consecutive_idle.clear()
            interval = int(mumu_cfg.get("check_interval_seconds", 20))
            await asyncio.sleep(max(15, interval))
        except asyncio.CancelledError:
            break
        except Exception as exc:
            print(f"[MUMU WATCHDOG ERROR] {exc}")
            await asyncio.sleep(20)
