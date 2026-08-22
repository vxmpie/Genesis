"""
Genesis Dashboard — Real-Time System Monitor & Auto-Boost Engine
Backend: FastAPI + WebSocket + Win32 API (EmptyWorkingSet)
"""

import asyncio
import ctypes
import ctypes.wintypes
import json
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path

import psutil
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

# ---------------------------------------------------------------------------
# GPU helper — pynvml with graceful fallback
# ---------------------------------------------------------------------------
_GPU_AVAILABLE = False
_GPU_HANDLE = None
try:
    import pynvml
    pynvml.nvmlInit()
    _GPU_HANDLE = pynvml.nvmlDeviceGetHandleByIndex(0)
    _GPU_AVAILABLE = True
except Exception:
    _GPU_HANDLE = None
    _GPU_AVAILABLE = False

# ---------------------------------------------------------------------------
# Paths & Config
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
DATA_DIR = BASE_DIR / "data"
HISTORY_PATH = DATA_DIR / "history.json"

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
                "process_names": ["MuMuNxDevice.exe", "MuMuNxMain.exe"]
            },
            "metrics": {"update_interval_ms": 1000, "history_length": 60}
        }
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def save_config(cfg: dict):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)

CONFIG = load_config()

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

# ---------------------------------------------------------------------------
# Win32 — RAM Boost via EmptyWorkingSet / SetProcessWorkingSetSize
# ---------------------------------------------------------------------------
_psapi = ctypes.WinDLL("psapi")
_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_SET_QUOTA = 0x0100

_kernel32.OpenProcess.restype = ctypes.wintypes.HANDLE
_kernel32.OpenProcess.argtypes = [
    ctypes.wintypes.DWORD,
    ctypes.wintypes.BOOL,
    ctypes.wintypes.DWORD,
]
_kernel32.CloseHandle.argtypes = [ctypes.wintypes.HANDLE]

_psapi.EmptyWorkingSet.restype = ctypes.wintypes.BOOL
_psapi.EmptyWorkingSet.argtypes = [ctypes.wintypes.HANDLE]


def _get_protected_names() -> set:
    names = set()
    for n in CONFIG.get("auto_boost", {}).get("protected_processes", []):
        names.add(n.lower())
    return names


def ram_boost() -> dict:
    """Trim working sets of non-protected processes. Returns stats."""
    protected = _get_protected_names()
    mem_before = psutil.virtual_memory()
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

    mem_after = psutil.virtual_memory()
    freed_mb = round((mem_after.available - mem_before.available) / (1024 * 1024), 1)
    if freed_mb < 0:
        freed_mb = 0.0

    result = {
        "freed_mb": freed_mb,
        "processes_trimmed": freed_count,
        "skipped": skipped,
        "errors": errors,
        "ram_before_percent": mem_before.percent,
        "ram_after_percent": mem_after.percent,
    }
    add_event("boost", f"RAM Boost — freed {freed_mb} MB ({freed_count} processes trimmed)")
    return result


# ---------------------------------------------------------------------------
# Metrics collection
# ---------------------------------------------------------------------------
def get_gpu_metrics() -> dict:
    if not _GPU_AVAILABLE or _GPU_HANDLE is None:
        return {"available": False}
    try:
        temp = pynvml.nvmlDeviceGetTemperature(_GPU_HANDLE, pynvml.NVML_TEMPERATURE_GPU)
        util = pynvml.nvmlDeviceGetUtilizationRates(_GPU_HANDLE)
        mem = pynvml.nvmlDeviceGetMemoryInfo(_GPU_HANDLE)
        name = pynvml.nvmlDeviceGetName(_GPU_HANDLE)
        if isinstance(name, bytes):
            name = name.decode("utf-8")
        return {
            "available": True,
            "name": name,
            "temperature_c": temp,
            "utilization_percent": util.gpu,
            "memory_used_mb": round(mem.used / (1024 * 1024)),
            "memory_total_mb": round(mem.total / (1024 * 1024)),
            "memory_percent": round(mem.used / mem.total * 100, 1),
        }
    except Exception:
        return {"available": False}


def get_system_metrics() -> dict:
    cpu_per_core = psutil.cpu_percent(interval=0, percpu=True)  # 16 values for i5-12500H
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
            "p_cores": cpu_per_core[:8],   # Threads 0-7: P-Cores (4C/8T)
            "e_cores": cpu_per_core[8:],   # Threads 8-15: E-Cores (8C/8T)
        },
        "ram": {
            "total_gb": round(mem.total / (1024 ** 3), 1),
            "used_gb": round(mem.used / (1024 ** 3), 1),
            "available_gb": round(mem.available / (1024 ** 3), 1),
            "percent": mem.percent,
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
    global _auto_boost_task
    # Prime CPU percent
    psutil.cpu_percent(interval=0, percpu=True)
    _auto_boost_task = asyncio.create_task(auto_boost_loop())
    add_event("system", "Genesis Dashboard started")
    yield
    if _auto_boost_task:
        _auto_boost_task.cancel()
    if _GPU_AVAILABLE:
        try:
            pynvml.nvmlShutdown()
        except Exception:
            pass
    add_event("system", "Genesis Dashboard stopped")


app = FastAPI(title="Genesis Dashboard", version="1.0.0", lifespan=lifespan)

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


if __name__ == "__main__":
    import uvicorn

    host = CONFIG.get("server", {}).get("host", "0.0.0.0")
    port = CONFIG.get("server", {}).get("port", 7700)
    print(f"\n{'='*50}")
    print(f"  GENESIS DASHBOARD")
    print(f"  http://localhost:{port}")
    print(f"  http://0.0.0.0:{port} (LAN access)")
    print(f"{'='*50}\n")
    uvicorn.run(app, host=host, port=port, log_level="info")
