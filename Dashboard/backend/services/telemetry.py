import asyncio
import json
import os
import platform
import socket
import subprocess
import threading
import time
import winreg
from datetime import datetime, timedelta
from pathlib import Path

import psutil

from backend.core.config import CHART_HISTORY_PATH, CONFIG, DATA_DIR
from backend.core.events import add_event, get_all_events_snapshot, purge_boost_events
from backend.services.win32_ops import get_ram_breakdown

WATCHDOG_LOG_PATH = Path(r"C:\Genesis\watchdog.log")

# --- Runtime Telemetry State ---
_server_start_time = time.time()
_boost_counter_reset_time = _server_start_time
_standby_purge_count = 0
_standby_reclaimed_gb = 0.0
_last_standby_purge_time: str | None = None
_last_boost_time: float | None = None
_last_boost_result: dict | None = None
_session_watchdog_recoveries = 0
_drift_detected_flag = False

_cpu_sampler_lock = threading.Lock()
_latest_cpu_total = 0.0
_latest_cpu_per_core: list[float] = [0.0] * (psutil.cpu_count(logical=True) or 16)
_latest_cpu_freq_ghz = 2.5
_cpu_brand_name: str | None = None
_cpu_raw_history: list[float] = []
_cpu_per_core_history: list[list[float]] = []

_last_roblox_ping_ms = 0.0
_nvml_initialized = False
_nvml_handle = None
_last_gpu_data: dict = {"available": False}

_prev_disk_io = None
_prev_net_io = None
_prev_time: float | None = None

_ping_history: list[tuple[float, bool, float]] = []
_wifi_telemetry_cache: dict = {}
_wifi_telemetry_time = 0.0

_top_processes_lock = threading.Lock()
_cached_top_processes: list[dict] = []


def _init_last_boost_time() -> float | None:
    for e in reversed(get_all_events_snapshot()):
        if e.get("type") == "boost":
            epoch = e.get("epoch")
            if epoch:
                return float(epoch)
            try:
                dt = datetime.strptime(e.get("time", ""), "%Y-%m-%d %H:%M:%S")
                return dt.timestamp()
            except Exception:
                pass
    return None


_last_boost_time = _init_last_boost_time()


# --- Chart Buffer ---
def _load_chart_history() -> dict:
    if CHART_HISTORY_PATH.exists():
        try:
            with open(CHART_HISTORY_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    return {
                        "ram": list(data.get("ram", [])[-60:]),
                        "cpu": list(data.get("cpu", [])[-60:]),
                        "timestamps": list(data.get("timestamps", [])[-60:]),
                    }
        except Exception:
            pass
    return {"ram": [], "cpu": [], "timestamps": []}


_loaded_chart = _load_chart_history()
_chart_buffer_ram: list[float] = _loaded_chart["ram"]
_chart_buffer_cpu: list[float] = _loaded_chart["cpu"]
_chart_buffer_timestamps: list[int] = _loaded_chart["timestamps"]
_chart_last_sample_time: float = (
    (_chart_buffer_timestamps[-1] / 1000.0) if _chart_buffer_timestamps else 0.0
)
_chart_lock = threading.Lock()


def _save_chart_history() -> None:
    try:
        tmp_path = DATA_DIR / "chart_history.json.tmp"
        with open(tmp_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(
                {
                    "ram": _chart_buffer_ram[-60:],
                    "cpu": _chart_buffer_cpu[-60:],
                    "timestamps": _chart_buffer_timestamps[-60:],
                },
                f,
                indent=2,
            )
        os.replace(tmp_path, CHART_HISTORY_PATH)
    except Exception:
        pass


def update_chart_buffer(ram_pct: float, cpu_pct: float) -> None:
    global _chart_last_sample_time
    now = time.time()
    with _chart_lock:
        if now - _chart_last_sample_time >= 28 or not _chart_buffer_timestamps:
            _chart_buffer_ram.append(round(float(ram_pct), 1))
            _chart_buffer_cpu.append(round(float(cpu_pct), 1))
            _chart_buffer_timestamps.append(int(now * 1000))
            if len(_chart_buffer_ram) > 60:
                _chart_buffer_ram.pop(0)
            if len(_chart_buffer_cpu) > 60:
                _chart_buffer_cpu.pop(0)
            if len(_chart_buffer_timestamps) > 60:
                _chart_buffer_timestamps.pop(0)
            _chart_last_sample_time = now
            _save_chart_history()


def get_chart_history() -> dict:
    with _chart_lock:
        return {
            "ram": list(_chart_buffer_ram),
            "cpu": list(_chart_buffer_cpu),
            "timestamps": list(_chart_buffer_timestamps),
        }


# --- Session, Boost & Standby Counters ---
def set_drift_detected_flag(has_drift: bool) -> None:
    global _drift_detected_flag
    _drift_detected_flag = bool(has_drift)


def record_boost_result(result: dict) -> None:
    global _last_boost_time, _last_boost_result
    _last_boost_time = time.time()
    _last_boost_result = result


def get_last_boost_state() -> tuple[float | None, dict | None]:
    return _last_boost_time, _last_boost_result


def record_standby_purge(reclaimed_gb: float) -> None:
    global _standby_purge_count, _standby_reclaimed_gb, _last_standby_purge_time
    _standby_purge_count += 1
    _standby_reclaimed_gb += max(0.0, float(reclaimed_gb))
    _last_standby_purge_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def increment_watchdog_recovery() -> int:
    global _session_watchdog_recoveries
    _session_watchdog_recoveries += 1
    return _session_watchdog_recoveries


def get_next_scheduled_boost_time(interval_min: int) -> str:
    now_dt = datetime.now()
    interval = max(1, interval_min)
    minutes_to_add = interval - (now_dt.minute % interval)
    if minutes_to_add == 0:
        minutes_to_add = interval
    next_dt = (now_dt + timedelta(minutes=minutes_to_add)).replace(second=0, microsecond=0)
    return next_dt.strftime("%H:%M:%S")


def get_next_boost_info() -> dict:
    cfg = CONFIG.get("auto_boost", {})
    if not cfg.get("enabled", False):
        return {"status": "disabled", "text": "Disabled (Sentinel Paused)"}

    mode = cfg.get("mode", "scheduled")
    if mode == "auto":
        thresh = cfg.get("threshold_percent", 85)
        mem = psutil.virtual_memory()
        return {
            "status": "threshold",
            "threshold": thresh,
            "current": mem.percent,
            "text": f"When RAM > {thresh}% (Now: {mem.percent}%)",
        }

    interval_min = max(1, int(cfg.get("interval_minutes", 60)))
    now = datetime.now()
    passed_mins = now.minute % interval_min
    mins_remaining = interval_min - passed_mins
    next_dt = now + timedelta(minutes=mins_remaining)
    next_time_str = next_dt.strftime("%H:%M")
    return {
        "status": "scheduled",
        "next_time": next_time_str,
        "in_minutes": mins_remaining,
        "text": f"{next_time_str} (in {mins_remaining}m)",
    }


def get_auto_boost_payload() -> dict:
    ab = CONFIG.get("auto_boost", {})
    return {
        "enabled": bool(ab.get("enabled", True)),
        "mode": str(ab.get("mode", "auto")),
        "threshold": int(ab.get("threshold_percent", 85)),
        "interval_minutes": int(ab.get("interval_minutes", 60)),
        "last_boost_time": (
            datetime.fromtimestamp(_last_boost_time).strftime("%H:%M:%S")
            if _last_boost_time
            else None
        ),
        "last_boost_result": _last_boost_result,
        "next_boost": get_next_boost_info(),
    }


def reset_session_boosts() -> dict:
    global _boost_counter_reset_time
    _boost_counter_reset_time = time.time()
    add_event("system", "Session boost counter reset to 0 (Lifetime total preserved)")
    return get_session_summary()


def reset_total_boosts() -> dict:
    global _boost_counter_reset_time
    _boost_counter_reset_time = time.time()
    purge_boost_events()
    add_event("system", "Lifetime total boost history purged (All counters 0)")
    return get_session_summary()


def get_session_summary() -> dict:
    uptime_sec = int(time.time() - _server_start_time)
    events = get_all_events_snapshot()

    total_boosts = 0
    session_boosts = 0
    last_clean_time = "None"

    for e in reversed(events):
        msg = e.get("message", "").lower()
        if (
            e.get("type") == "boost"
            and "triggered" not in msg
            and "scheduled clock-aligned boost" not in msg
        ):
            total_boosts += 1
            if last_clean_time == "None":
                last_clean_time = e.get("time", "")
            event_epoch = e.get("epoch")
            if event_epoch is None:
                try:
                    event_epoch = datetime.strptime(e.get("time", ""), "%Y-%m-%d %H:%M:%S").timestamp()
                except Exception:
                    event_epoch = _server_start_time
            if float(event_epoch) >= _boost_counter_reset_time:
                session_boosts += 1

    watchdog = get_watchdog_status()
    net_recoveries = watchdog.get("recoveries_today", 0) + _session_watchdog_recoveries

    cfg_boost = CONFIG.get("auto_boost", {})
    mode = cfg_boost.get("mode", "auto")
    interval = int(cfg_boost.get("interval_minutes", 30))
    next_boost_str = get_next_scheduled_boost_time(interval) if mode == "scheduled" else "N/A"

    return {
        "uptime_seconds": uptime_sec,
        "session_boosts": session_boosts,
        "total_boosts": total_boosts,
        "net_recoveries": net_recoveries,
        "last_clean_time": last_clean_time,
        "total_events": len(events),
        "drift_detected": _drift_detected_flag,
        "next_scheduled_boost": next_boost_str,
        "boost_mode": mode,
        "standby_guard": {
            "enabled": True,
            "purges": _standby_purge_count,
            "reclaimed_gb": round(_standby_reclaimed_gb, 2),
            "last_purge": _last_standby_purge_time or "None",
        },
    }


# --- Network Observatory ---
def get_watchdog_status() -> dict:
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
            "latest_recovered_line": None,
        }

    try:
        with open(WATCHDOG_LOG_PATH, "r", encoding="utf-8", errors="ignore") as f:
            lines = [line.strip().lstrip("\ufeff") for line in f.readlines() if line.strip()]
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
            "latest_recovered_line": None,
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
    today_lines = [line for line in lines if line.startswith(f"[{today_str}")]
    l1_count = sum(1 for line in today_lines if "[LEVEL 1]" in line)
    l2_count = sum(1 for line in today_lines if "[LEVEL 2]" in line)
    rec_lines = [line for line in today_lines if "[RECOVERED]" in line]

    return {
        "installed": True,
        "status": status_text,
        "state": state,
        "heartbeat_seconds": heartbeat_sec,
        "recoveries_today": len(rec_lines),
        "level1_today": l1_count,
        "level2_today": l2_count,
        "recent_logs": lines[-6:],
        "latest_recovered_line": rec_lines[-1] if rec_lines else None,
    }


def get_wifi_telemetry() -> dict:
    global _wifi_telemetry_cache, _wifi_telemetry_time
    now = time.time()
    if now - _wifi_telemetry_time < 3 and _wifi_telemetry_cache:
        return _wifi_telemetry_cache

    try:
        r = subprocess.run(
            ["netsh", "wlan", "show", "interfaces"],
            capture_output=True,
            text=True,
            timeout=3,
        )
        if r.returncode == 0:
            ssid = "Disconnected"
            signal_pct = 0
            rssi_dbm = -100
            band = "Unknown"
            channel = "Unknown"
            rx_rate = 0
            tx_rate = 0
            radio = "802.11"
            state = "disconnected"

            for raw_line in r.stdout.splitlines():
                line = raw_line.strip()
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
                    try:
                        rx_rate = int(float(line.split(":", 1)[1].strip()))
                    except ValueError:
                        pass
                elif line.startswith("Transmit rate (Mbps)") and ":" in line:
                    try:
                        tx_rate = int(float(line.split(":", 1)[1].strip()))
                    except ValueError:
                        pass
                elif line.startswith("Radio type") and ":" in line:
                    radio = line.split(":", 1)[1].strip()

            quality_score = (
                min(100, int(signal_pct * 0.6 + min(rx_rate / 400.0, 1.0) * 40))
                if state.lower() == "connected"
                else 0
            )
            if quality_score >= 85:
                quality_label = "Excellent"
            elif quality_score >= 70:
                quality_label = "Good"
            elif quality_score >= 50:
                quality_label = "Fair"
            else:
                quality_label = "Poor" if state.lower() == "connected" else "Offline"

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
                "quality_score": quality_score,
                "quality_label": quality_label,
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
        "quality_score": 0,
        "quality_label": "Offline",
    }


def measure_ping_latency(target: str = "1.1.1.1", port: int = 443, timeout_sec: float = 1.0) -> float | None:
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
    loss_pct = (
        round(((total_samples - len(success_pings)) / total_samples * 100.0), 1)
        if total_samples > 0
        else 0.0
    )

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
    try:
        r = subprocess.run(["ipconfig", "/flushdns"], capture_output=True, text=True, timeout=5)
        success = r.returncode == 0
        if success:
            add_event("system", "DNS Resolver Cache flushed successfully")
        return success
    except Exception:
        return False


# --- GPU, CPU & System Metrics ---
def _init_nvml() -> None:
    global _nvml_initialized, _nvml_handle
    if not _nvml_initialized:
        try:
            import pynvml

            pynvml.nvmlInit()
            _nvml_handle = pynvml.nvmlDeviceGetHandleByIndex(0)
            _nvml_initialized = True
        except Exception:
            _nvml_initialized = False


def get_gpu_metrics() -> dict:
    global _last_gpu_data, _nvml_initialized
    if not _nvml_initialized:
        _init_nvml()

    if _nvml_initialized and _nvml_handle is not None:
        try:
            import pynvml

            temp = pynvml.nvmlDeviceGetTemperature(_nvml_handle, pynvml.NVML_TEMPERATURE_GPU)
            util = pynvml.nvmlDeviceGetUtilizationRates(_nvml_handle)
            mem = pynvml.nvmlDeviceGetMemoryInfo(_nvml_handle)
            name = pynvml.nvmlDeviceGetName(_nvml_handle)
            if isinstance(name, bytes):
                name = name.decode("utf-8")

            _last_gpu_data = {
                "available": True,
                "name": name,
                "temperature_c": temp,
                "utilization_percent": util.gpu,
                "load_percent": util.gpu,
                "memory_used_mb": round(mem.used / (1024 * 1024)),
                "memory_total_mb": round(mem.total / (1024 * 1024)),
                "memory_percent": round(mem.used / mem.total * 100, 1) if mem.total else 0.0,
            }
            return _last_gpu_data
        except Exception:
            _nvml_initialized = False

    if _last_gpu_data.get("temperature_c", 0) > 0:
        return _last_gpu_data
    return {"available": False}


def get_cpu_brand() -> str:
    global _cpu_brand_name
    if _cpu_brand_name:
        return _cpu_brand_name
    try:
        key = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DESCRIPTION\System\CentralProcessor\0"
        )
        raw = winreg.QueryValueEx(key, "ProcessorNameString")[0].strip()
        winreg.CloseKey(key)
        _cpu_brand_name = raw.replace("(R)", "").replace("(TM)", "").replace("  ", " ").strip()
    except Exception:
        _cpu_brand_name = platform.processor() or "Unknown CPU"
    return _cpu_brand_name


def _sample_cpu_sync() -> None:
    global _latest_cpu_total, _latest_cpu_per_core, _latest_cpu_freq_ghz
    try:
        raw_per_core = psutil.cpu_percent(interval=None, percpu=True)
        if raw_per_core:
            raw_total = float(sum(raw_per_core) / len(raw_per_core))
        else:
            raw_total = float(psutil.cpu_percent(interval=None))

        freq = psutil.cpu_freq()
        ghz = round(freq.current / 1000, 2) if freq else 0.0

        _cpu_raw_history.append(raw_total)
        if len(_cpu_raw_history) > 4:
            _cpu_raw_history.pop(0)

        _cpu_per_core_history.append([float(x) for x in raw_per_core])
        if len(_cpu_per_core_history) > 4:
            _cpu_per_core_history.pop(0)

        n_hist = len(_cpu_raw_history)
        if n_hist >= 4:
            weights = [0.10, 0.20, 0.30, 0.40]
            smooth_total = round(sum(w * v for w, v in zip(weights, _cpu_raw_history[-4:])), 1)
            smooth_per_core = [
                round(sum(weights[j] * _cpu_per_core_history[-4:][j][i] for j in range(4)), 1)
                for i in range(len(raw_per_core))
            ]
        elif n_hist == 3:
            weights = [0.20, 0.30, 0.50]
            smooth_total = round(sum(w * v for w, v in zip(weights, _cpu_raw_history[-3:])), 1)
            smooth_per_core = [
                round(sum(weights[j] * _cpu_per_core_history[-3:][j][i] for j in range(3)), 1)
                for i in range(len(raw_per_core))
            ]
        elif n_hist == 2:
            smooth_total = round(_cpu_raw_history[1] * 0.60 + _cpu_raw_history[0] * 0.40, 1)
            smooth_per_core = [
                round(_cpu_per_core_history[1][i] * 0.60 + _cpu_per_core_history[0][i] * 0.40, 1)
                for i in range(len(raw_per_core))
            ]
        else:
            smooth_total = round(raw_total, 1)
            smooth_per_core = [round(float(x), 1) for x in raw_per_core]

        with _cpu_sampler_lock:
            _latest_cpu_total = smooth_total
            _latest_cpu_per_core = smooth_per_core
            _latest_cpu_freq_ghz = ghz
    except Exception:
        pass


def get_system_metrics() -> dict:
    with _cpu_sampler_lock:
        cpu_total = _latest_cpu_total
        cpu_per_core = list(_latest_cpu_per_core)
        cpu_ghz = _latest_cpu_freq_ghz

    mem = psutil.virtual_memory()
    breakdown = get_ram_breakdown()
    disk_io = psutil.disk_io_counters()
    net_io = psutil.net_io_counters()
    swap = psutil.swap_memory()
    try:
        c_usage = psutil.disk_usage("C:\\")
        c_drive_info = {
            "total_gb": round(c_usage.total / (1024 ** 3), 1),
            "free_gb": round(c_usage.free / (1024 ** 3), 1),
            "used_gb": round(c_usage.used / (1024 ** 3), 1),
            "percent": c_usage.percent,
            "is_low": round(c_usage.free / (1024 ** 3), 1) < 15.0,
        }
    except Exception:
        c_drive_info = {
            "total_gb": 0.0,
            "free_gb": 0.0,
            "used_gb": 0.0,
            "percent": 0.0,
            "is_low": False,
        }

    boot_time = psutil.boot_time()
    uptime_sec = time.time() - boot_time
    hours = int(uptime_sec // 3600)
    mins = int((uptime_sec % 3600) // 60)

    core_count = len(cpu_per_core) if cpu_per_core else (psutil.cpu_count(logical=True) or 1)
    p_cores = cpu_per_core[:8] if len(cpu_per_core) >= 12 else cpu_per_core
    e_cores = cpu_per_core[8:] if len(cpu_per_core) >= 12 else []

    sent_mb = round(net_io.bytes_sent / (1024 ** 2), 1) if net_io else 0.0
    recv_mb = round(net_io.bytes_recv / (1024 ** 2), 1) if net_io else 0.0

    return {
        "timestamp": datetime.now().strftime("%H:%M:%S"),
        "system": {
            "uptime": f"{hours}h {mins:02d}m",
            "uptime_seconds": int(uptime_sec),
        },
        "cpu": {
            "model": get_cpu_brand(),
            "total_percent": cpu_total,
            "per_core": cpu_per_core,
            "core_count": core_count,
            "count": core_count,
            "p_cores": p_cores,
            "e_cores": e_cores,
            "frequency_ghz": cpu_ghz,
        },
        "ram": {
            "total_gb": round(mem.total / (1024 ** 3), 1),
            "used_gb": round(mem.used / (1024 ** 3), 1),
            "available_gb": round(mem.available / (1024 ** 3), 1),
            "percent": mem.percent,
            "breakdown": breakdown,
            "active_gb": breakdown.get("active_gb", 0.0),
            "standby_gb": breakdown.get("standby_gb", 0.0),
            "free_gb": breakdown.get("free_gb", 0.0),
            "pagefile": {
                "used_gb": round(swap.used / (1024 ** 3), 1),
                "total_gb": round(swap.total / (1024 ** 3), 1),
                "percent": swap.percent,
            },
        },
        "gpu": get_gpu_metrics(),
        "disk": {
            "read_mb": round(disk_io.read_bytes / (1024 ** 2), 1) if disk_io else 0.0,
            "write_mb": round(disk_io.write_bytes / (1024 ** 2), 1) if disk_io else 0.0,
            "read_mb_s": 0.0,
            "write_mb_s": 0.0,
        },
        "network": {
            "sent_mb": sent_mb,
            "recv_mb": recv_mb,
            "total_sent_mb": sent_mb,
            "total_recv_mb": recv_mb,
            "bytes_sent_sec": 0,
            "bytes_recv_sec": 0,
            "sent_speed_mbs": 0.0,
            "recv_speed_mbs": 0.0,
            "roblox_ping_ms": _last_roblox_ping_ms,
        },
        "storage": {
            "c_drive": c_drive_info
        },
    }


def get_metrics_with_rates() -> dict:
    global _prev_disk_io, _prev_net_io, _prev_time

    metrics = get_system_metrics()
    now = time.monotonic()

    disk_io = psutil.disk_io_counters()
    net_io = psutil.net_io_counters()

    if _prev_disk_io and _prev_net_io and _prev_time and disk_io and net_io:
        dt = now - _prev_time
        if dt > 0:
            r_speed = max(0.0, round((disk_io.read_bytes - _prev_disk_io.read_bytes) / (1024 ** 2) / dt, 2))
            w_speed = max(0.0, round((disk_io.write_bytes - _prev_disk_io.write_bytes) / (1024 ** 2) / dt, 2))
            s_speed = max(0.0, round((net_io.bytes_sent - _prev_net_io.bytes_sent) / (1024 ** 2) / dt, 2))
            recv_spd = max(0.0, round((net_io.bytes_recv - _prev_net_io.bytes_recv) / (1024 ** 2) / dt, 2))

            metrics["disk"]["read_speed_mbs"] = r_speed
            metrics["disk"]["read_mb_s"] = r_speed
            metrics["disk"]["write_speed_mbs"] = w_speed
            metrics["disk"]["write_mb_s"] = w_speed

            metrics["network"]["sent_speed_mbs"] = s_speed
            metrics["network"]["bytes_sent_sec"] = int(s_speed * 1024 * 1024)
            metrics["network"]["recv_speed_mbs"] = recv_spd
            metrics["network"]["bytes_recv_sec"] = int(recv_spd * 1024 * 1024)
    else:
        metrics["disk"]["read_speed_mbs"] = 0.0
        metrics["disk"]["write_speed_mbs"] = 0.0

    _prev_disk_io = disk_io
    _prev_net_io = net_io
    _prev_time = now

    try:
        update_chart_buffer(metrics["ram"]["percent"], metrics["cpu"]["total_percent"])
    except Exception:
        pass

    return metrics


def set_cached_top_processes(procs: list[dict]) -> None:
    with _top_processes_lock:
        _cached_top_processes[:] = procs


def get_top_processes(limit: int = 10) -> list[dict]:
    with _top_processes_lock:
        return list(_cached_top_processes[:limit])


# --- Background Samplers ---
async def cpu_sampler_loop() -> None:
    psutil.cpu_percent(interval=None, percpu=True)
    while True:
        try:
            await asyncio.to_thread(_sample_cpu_sync)
        except asyncio.CancelledError:
            break
        except Exception:
            pass
        await asyncio.sleep(1.0)


async def roblox_ping_sampler_loop() -> None:
    global _last_roblox_ping_ms
    while True:
        try:
            def _ping() -> float:
                t0 = time.perf_counter()
                try:
                    s = socket.create_connection(("clientsettingscdn.roblox.com", 443), timeout=3)
                    s.close()
                    return round((time.perf_counter() - t0) * 1000, 1)
                except Exception:
                    return 0.0

            _last_roblox_ping_ms = await asyncio.to_thread(_ping)
        except asyncio.CancelledError:
            break
        except Exception:
            pass
        await asyncio.sleep(10)


async def chart_sampler_loop() -> None:
    while True:
        try:
            with _cpu_sampler_lock:
                cpu_pct = _latest_cpu_total
            mem = psutil.virtual_memory()
            update_chart_buffer(mem.percent, cpu_pct)
        except asyncio.CancelledError:
            break
        except Exception:
            pass
        await asyncio.sleep(30)
