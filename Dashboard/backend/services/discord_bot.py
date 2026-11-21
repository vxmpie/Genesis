import asyncio
import json
import os
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

import psutil
import websockets

from backend.core.config import CONFIG, DATA_DIR
from backend.core.events import add_event
from backend.services.discord_notifier import DISCORD_API_BASE, purge_discord_channel_messages, sanitize_error_text
from backend.services.intel_feeds import (
    build_omni_briefing_payload,
    fetch_ai_cortex_intel,
    fetch_free_loot_intel,
    fetch_tech_radar_intel,
    fetch_world_pulse_intel,
    get_cached_hud_sensors_sync,
    strip_emojis,
)
from backend.services.maintenance import deep_clean_execute, get_vm_disk_status, ram_boost, trim_vm_caches
from backend.services.mumu_monitor import (
    check_mumu_health,
    find_mumu_adb,
    get_adb_port_for_instance,
    get_instance_place_id,
    recover_roblox_instance,
)
from backend.services.telemetry import get_session_summary, get_system_metrics, get_top_processes
from backend.services.tunnel import get_tunnel_status

# --- Constants & Mothership Topology ---
_CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
STATION_STATE_PATH = DATA_DIR / "discord_station.json"
NOTES_PATH = DATA_DIR / "notes.json"
USER_AGENT = "Genesis-Mothership-Core/4.0"

GUILD_MOTHERSHIP_NAME = "GENESIS-01 // ORBITAL MOTHERSHIP"
BOT_MOTHERSHIP_NICK = "GENESIS // AI CORE"

CATEGORY_HUD = "// [00] ORBITAL TELEMETRY ARRAY"
CATEGORY_BRIDGE = "// [01] BRIDGE COMMAND DECK"
CATEGORY_INTEL = "// [02] OMNISCIENT INTEL CORTEX"
CATEGORY_CREW = "// [03] CREW QUARTERS"
CATEGORY_COMMS = "// [04] COMMS & AIRLOCKS"

HUD_CHANNEL_PREFIXES = ("CORE:", "FLEET:", "HULL C:", "BKK:")

PERMISSION_VIEW_CHANNEL = 1 << 10
PERMISSION_CONNECT = 1 << 20

SLASH_COMMANDS: list[dict] = [
    {
        "name": "bridge",
        "description": "Spawn or refresh the GENESIS-01 Mothership Bridge Console",
        "type": 1,
    },
    {
        "name": "briefing",
        "description": "Unified Mothership Omni-Briefing (Ship + Weather + Markets + AI/Tech)",
        "type": 1,
    },
    {
        "name": "status",
        "description": "Full reactor and hull telemetry (CPU, RAM, GPU, Disk, Ping, Tunnel)",
        "type": 1,
    },
    {
        "name": "ai",
        "description": "Orbital AI & Singularity Cortex (HuggingFace Papers + TechCrunch AI)",
        "type": 1,
    },
    {
        "name": "tech",
        "description": "Deep-Space Tech & Cybernetics Radar (Hacker News + The Verge)",
        "type": 1,
    },
    {
        "name": "world",
        "description": "Planetary World Pulse, Bangkok Weather, Markets & GitHub Radar",
        "type": 1,
    },
    {
        "name": "loot",
        "description": "Orbital Supply Drop (Epic Games Freebies & 100%-Off PC Deals)",
        "type": 1,
    },
    {
        "name": "boost",
        "description": "Execute Reactor RAM Boost (Standby List purge and working set trim)",
        "type": 1,
    },
    {
        "name": "mumu",
        "description": "Inspect MuMu drone fleet, Roblox presence, and recovery controls",
        "type": 1,
    },
    {
        "name": "recover",
        "description": "Trigger Roblox drone recovery on an instance or all active instances",
        "type": 1,
        "options": [
            {
                "name": "instance",
                "description": "Instance index (1-10). Leave empty to recover all active instances.",
                "type": 4,
                "required": False,
                "min_value": 1,
                "max_value": 10,
            }
        ],
    },
    {
        "name": "screenshot",
        "description": "Capture live PNG sensor frame from MuMu or Host desktop",
        "type": 1,
        "options": [
            {
                "name": "target",
                "description": "Capture target (default: mumu if running, otherwise host)",
                "type": 3,
                "required": False,
                "choices": [
                    {"name": "MuMu Emulator", "value": "mumu"},
                    {"name": "Host Desktop", "value": "host"},
                ],
            }
        ],
    },
    {
        "name": "processes",
        "description": "List top 10 resource-consuming processes on the mothership",
        "type": 1,
    },
    {
        "name": "clean",
        "description": "Execute Hull Deep Clean across temp directories, logs, and caches",
        "type": 1,
    },
    {
        "name": "purge",
        "description": "Purge messages from the #reactor-telemetry alerts channel",
        "type": 1,
        "options": [
            {
                "name": "limit",
                "description": "Max messages to scan and delete (default 100)",
                "type": 4,
                "required": False,
                "min_value": 1,
                "max_value": 500,
            }
        ],
    },
    {
        "name": "log",
        "description": "Record a Captain's Log entry into #captain-datacore and local vault",
        "type": 1,
        "options": [
            {
                "name": "text",
                "description": "Log entry content to store",
                "type": 3,
                "required": True,
            }
        ],
    },
    {
        "name": "note",
        "description": "Alias for /log: save a quick note into #captain-datacore",
        "type": 1,
        "options": [
            {
                "name": "text",
                "description": "Note content to store",
                "type": 3,
                "required": True,
            }
        ],
    },
]

_STATE_LOCK = threading.RLock()


# --- Discord REST & Multipart Helpers ---
def _utc_iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def load_station_state() -> dict:
    with _STATE_LOCK:
        if STATION_STATE_PATH.exists():
            try:
                data = json.loads(STATION_STATE_PATH.read_text(encoding="utf-8-sig"))
                if isinstance(data, dict):
                    return data
            except Exception:
                pass
        return {}


def save_station_state(state: dict) -> None:
    with _STATE_LOCK:
        tmp_path = STATION_STATE_PATH.with_suffix(".json.tmp")
        tmp_path.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8", newline="\n")
        os.replace(tmp_path, STATION_STATE_PATH)


def append_quick_note(text: str, author: str = "commander") -> dict:
    clean_text = strip_emojis(text)
    entry = {
        "id": uuid.uuid4().hex[:8],
        "text": clean_text,
        "author": strip_emojis(author) or "commander",
        "timestamp_utc": _utc_iso_now(),
    }
    with _STATE_LOCK:
        notes: list[dict] = []
        if NOTES_PATH.exists():
            try:
                loaded = json.loads(NOTES_PATH.read_text(encoding="utf-8-sig"))
                if isinstance(loaded, list):
                    notes = loaded
            except Exception:
                notes = []
        notes.insert(0, entry)
        notes = notes[:200]
        tmp_path = NOTES_PATH.with_suffix(".json.tmp")
        tmp_path.write_text(json.dumps(notes, indent=2, ensure_ascii=False), encoding="utf-8", newline="\n")
        os.replace(tmp_path, NOTES_PATH)
    return entry


def encode_multipart_form_data(
    payload_json: dict,
    files: list[tuple[str, str, bytes]],
) -> tuple[bytes, str]:
    boundary = f"----GenesisBoundary{uuid.uuid4().hex}"
    chunks: list[bytes] = []

    chunks.append(f"--{boundary}\r\n".encode("utf-8"))
    chunks.append(b'Content-Disposition: form-data; name="payload_json"\r\n')
    chunks.append(b"Content-Type: application/json\r\n\r\n")
    chunks.append(json.dumps(payload_json, ensure_ascii=False).encode("utf-8"))
    chunks.append(b"\r\n")

    for idx, (_field_name, filename, content) in enumerate(files):
        chunks.append(f"--{boundary}\r\n".encode("utf-8"))
        chunks.append(
            f'Content-Disposition: form-data; name="files[{idx}]"; filename="{filename}"\r\n'.encode("utf-8")
        )
        chunks.append(b"Content-Type: image/png\r\n\r\n")
        chunks.append(content)
        chunks.append(b"\r\n")

    chunks.append(f"--{boundary}--\r\n".encode("utf-8"))
    body = b"".join(chunks)
    content_type = f"multipart/form-data; boundary={boundary}"
    return body, content_type


def _discord_http_request(
    method: str,
    path: str,
    bot_token: str | None = None,
    payload: dict | list | None = None,
    raw_body: bytes | None = None,
    content_type: str | None = None,
) -> tuple[int, dict[str, str], str]:
    url = path if path.startswith("http") else f"{DISCORD_API_BASE}{path}"
    headers = {"User-Agent": USER_AGENT}
    if bot_token:
        headers["Authorization"] = f"Bot {bot_token}"

    data: bytes | None = raw_body
    if data is not None:
        if content_type:
            headers["Content-Type"] = content_type
    elif payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp_headers = {k.lower(): v for k, v in resp.headers.items()}
            body = resp.read().decode("utf-8", errors="ignore")
            return resp.status, resp_headers, body
    except urllib.error.HTTPError as exc:
        resp_headers = {k.lower(): v for k, v in exc.headers.items()} if exc.headers else {}
        body = exc.read().decode("utf-8", errors="ignore") if exc.fp else ""
        return exc.code, resp_headers, body
    except Exception as exc:
        return 0, {}, str(exc)


async def _discord_api(
    method: str,
    path: str,
    bot_token: str | None = None,
    payload: dict | list | None = None,
    raw_body: bytes | None = None,
    content_type: str | None = None,
    retries: int = 3,
) -> tuple[int, dict | list | None, str]:
    for attempt in range(retries):
        status, headers, body = await asyncio.to_thread(
            _discord_http_request,
            method,
            path,
            bot_token,
            payload,
            raw_body,
            content_type,
        )
        if status == 429 and attempt < retries - 1:
            wait_sec = 1.5
            retry_hdr = headers.get("retry-after") or headers.get("x-ratelimit-reset-after")
            if retry_hdr:
                try:
                    wait_sec = max(0.2, min(15.0, float(retry_hdr)))
                except ValueError:
                    pass
            await asyncio.sleep(wait_sec)
            continue
        parsed: dict | list | None = None
        if body:
            try:
                parsed = json.loads(body)
            except json.JSONDecodeError:
                parsed = None
        return status, parsed, body
    return 0, None, "Max retries exceeded"


# --- Telemetry & Screenshot Helpers ---
def _format_uptime(seconds: int) -> str:
    days, rem = divmod(max(0, int(seconds)), 86400)
    hours, rem = divmod(rem, 3600)
    minutes, _ = divmod(rem, 60)
    if days > 0:
        return f"{days}d {hours}h {minutes}m"
    if hours > 0:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def format_hud_channel_names(
    metrics: dict | None = None,
    mumu_health: dict | None = None,
    summary: dict | None = None,
    weather: dict | None = None,
    markets: dict | None = None,
) -> list[str]:
    m = metrics if metrics is not None else get_system_metrics()
    mh = mumu_health if mumu_health is not None else check_mumu_health()
    s = summary if summary is not None else get_session_summary()

    if weather is None or markets is None:
        w_cached, m_cached = get_cached_hud_sensors_sync(max_age_sec=300.0)
        weather = weather if weather is not None else w_cached
        markets = markets if markets is not None else m_cached

    cpu_pct = round(float(m.get("cpu", {}).get("total_percent", 0.0)))
    ram = m.get("ram", {})
    ram_used = float(ram.get("used_gb", 0.0))
    ram_total = float(ram.get("total_gb", 0.0))

    mumu_count = int(mh.get("count", 0))
    ping_ms = round(float(m.get("network", {}).get("roblox_ping_ms", 0.0)))

    c_free = float(m.get("storage", {}).get("c_drive", {}).get("free_gb", 0.0))
    boosts = int(s.get("session_boosts", 0))

    temp_str = f"{weather['temp_c']:.0f}C" if isinstance(weather, dict) and weather.get("ok") else "--C"
    btc_usd = float(markets.get("btc_usd", 0.0)) if isinstance(markets, dict) and markets.get("ok") else 0.0
    btc_str = f"${btc_usd / 1000.0:.1f}K" if btc_usd > 0 else "$--K"

    return [
        f"CORE: {cpu_pct}% | MEM: {ram_used:.1f}/{ram_total:.0f}GB"[:100],
        f"FLEET: {mumu_count} ONLINE | {ping_ms}MS"[:100],
        f"HULL C: {c_free:.1f}GB FREE | {boosts}B"[:100],
        f"BKK: {temp_str} | BTC: {btc_str}"[:100],
    ]


def capture_mumu_screenshot_png(instance_idx: int = 1) -> tuple[bytes | None, str]:
    adb = find_mumu_adb()
    if not adb:
        return None, "MuMu adb.exe not found"

    health = check_mumu_health()
    devices = health.get("devices", [])
    port = get_adb_port_for_instance(instance_idx)
    if devices:
        first = devices[0]
        port = int(first.get("adb_port") or get_adb_port_for_instance(int(first.get("index", 1))))

    serial = f"127.0.0.1:{port}"
    try:
        subprocess.run(
            [str(adb), "connect", serial],
            capture_output=True,
            timeout=5,
            creationflags=_CREATE_NO_WINDOW,
        )
        proc = subprocess.run(
            [str(adb), "-s", serial, "exec-out", "screencap", "-p"],
            capture_output=True,
            timeout=10,
            creationflags=_CREATE_NO_WINDOW,
        )
        if proc.returncode == 0 and proc.stdout.startswith(b"\x89PNG"):
            return proc.stdout, f"MuMu Drone ({serial})"
        err_msg = proc.stderr.decode("utf-8", errors="ignore").strip() or f"exit {proc.returncode}"
        return None, f"ADB screencap failed on {serial}: {err_msg}"
    except Exception as exc:
        return None, f"ADB screencap error: {exc}"


def capture_host_screenshot_png() -> tuple[bytes | None, str]:
    tmp_path = Path(tempfile.gettempdir()) / f"genesis_cap_{uuid.uuid4().hex[:8]}.png"
    ps_script = (
        "Add-Type -AssemblyName System.Windows.Forms,System.Drawing; "
        "$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; "
        "$bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height); "
        "$g = [System.Drawing.Graphics]::FromImage($bmp); "
        "$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size); "
        f"$bmp.Save('{str(tmp_path)}', [System.Drawing.Imaging.ImageFormat]::Png); "
        "$g.Dispose(); $bmp.Dispose()"
    )
    try:
        proc = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script],
            capture_output=True,
            text=True,
            timeout=10,
            creationflags=_CREATE_NO_WINDOW,
        )
        if proc.returncode == 0 and tmp_path.exists():
            data = tmp_path.read_bytes()
            if data.startswith(b"\x89PNG"):
                return data, f"Mothership Bridge Display ({socket.gethostname()})"
        err_text = (proc.stderr or proc.stdout or "Desktop capture unavailable in current session").strip()
        return None, f"Host capture failed: {err_text[:180]}"
    except Exception as exc:
        return None, f"Host capture error: {exc}"
    finally:
        try:
            tmp_path.unlink(missing_ok=True)
        except Exception:
            pass


# --- Embed & Component Builders ---
def build_deck_payload() -> dict:
    metrics = get_system_metrics()
    mumu = check_mumu_health()
    tunnel = get_tunnel_status()
    summary = get_session_summary()
    weather, markets = get_cached_hud_sensors_sync(max_age_sec=300.0)

    ram = metrics.get("ram", {})
    cpu_pct = float(metrics.get("cpu", {}).get("total_percent", 0.0))
    c_free = float(metrics.get("storage", {}).get("c_drive", {}).get("free_gb", 0.0))
    tunnel_url = tunnel.get("tunnel_url") or tunnel.get("local_url") or "http://127.0.0.1:7700"

    bkk_line = f"`{weather['temp_c']:.1f}C` (Hum `{weather['humidity']:.0f}%`)" if weather.get("ok") else "`Offline`"
    btc_line = (
        f"`${markets['btc_usd']:,.0f}` | USD/THB `{markets['usd_thb']:.2f}`"
        if markets.get("ok")
        else "`Offline`"
    )

    embed = {
        "title": "// GENESIS-01 MOTHERSHIP BRIDGE CONSOLE",
        "description": (
            f"Flagship Command & Omniscient Intelligence Terminal for vessel **{socket.gethostname()}**.\n"
            "Control reactor hardware, deploy drone recovery, capture live sensors, or intercept global AI/Tech/World intelligence."
        ),
        "color": 0x3B82F6,
        "fields": [
            {
                "name": "Ship Reactor & Hull",
                "value": (
                    f"CPU: `{cpu_pct:.1f}%`\n"
                    f"RAM: `{ram.get('used_gb', 0)} / {ram.get('total_gb', 0)} GB` ({ram.get('percent', 0)}%)\n"
                    f"Hull C: `{c_free:.1f} GB` Free"
                ),
                "inline": True,
            },
            {
                "name": "Fleet & Uptime",
                "value": (
                    f"MuMu Drones: `{mumu.get('count', 0)}` online\n"
                    f"Session Boosts: `{summary.get('session_boosts', 0)}`\n"
                    f"Uptime: `{_format_uptime(summary.get('uptime_seconds', 0))}`"
                ),
                "inline": True,
            },
            {
                "name": "Planetary Sensors & Ingress",
                "value": (
                    f"Bangkok Sector: {bkk_line} | Markets: {btc_line}\n"
                    f"Web Console: `{tunnel_url}`"
                ),
                "inline": False,
            },
        ],
        "footer": {"text": f"GENESIS-01 Orbital Mothership | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }

    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Live Status", "custom_id": "cmd:status"},
                {"type": 2, "style": 3, "label": "RAM Boost", "custom_id": "cmd:boost"},
                {"type": 2, "style": 2, "label": "MuMu Fleet", "custom_id": "cmd:mumu"},
                {"type": 2, "style": 2, "label": "Top Procs", "custom_id": "cmd:processes"},
                {"type": 2, "style": 1, "label": "Omni-Briefing", "custom_id": "cmd:briefing"},
            ],
        },
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 2, "label": "Snap MuMu", "custom_id": "cmd:screenshot_mumu"},
                {"type": 2, "style": 2, "label": "Snap Host", "custom_id": "cmd:screenshot_host"},
                {"type": 2, "style": 2, "label": "Deep Clean", "custom_id": "cmd:clean"},
                {"type": 2, "style": 2, "label": "Trim VM Cache", "custom_id": "cmd:trim_vm"},
                {"type": 2, "style": 4, "label": "Purge Alerts", "custom_id": "cmd:purge"},
            ],
        },
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 2, "label": "AI Cortex", "custom_id": "cmd:ai"},
                {"type": 2, "style": 2, "label": "Tech Radar", "custom_id": "cmd:tech"},
                {"type": 2, "style": 2, "label": "World Pulse", "custom_id": "cmd:world"},
                {"type": 2, "style": 2, "label": "Free Loot", "custom_id": "cmd:loot"},
                {"type": 2, "style": 3, "label": "Sync All Intel", "custom_id": "cmd:sync_intel"},
            ],
        },
    ]
    return {"embeds": [embed], "components": components}


def build_status_payload() -> dict:
    metrics = get_system_metrics()
    mumu = check_mumu_health()
    tunnel = get_tunnel_status()
    summary = get_session_summary()

    cpu = metrics.get("cpu", {})
    ram = metrics.get("ram", {})
    gpu = metrics.get("gpu", {})
    net = metrics.get("network", {})
    c_drive = metrics.get("storage", {}).get("c_drive", {})

    gpu_text = "Unavailable"
    if gpu.get("available"):
        gpu_text = (
            f"{gpu.get('name', 'GPU')}\n"
            f"Load: `{gpu.get('utilization_percent', gpu.get('load_percent', 0))}%` | "
            f"Temp: `{gpu.get('temperature_c', 0)}C` | "
            f"VRAM: `{gpu.get('memory_used_mb', 0)}/{gpu.get('memory_total_mb', 0)} MB`"
        )

    tunnel_url = tunnel.get("tunnel_url") or tunnel.get("local_url") or "http://127.0.0.1:7700"
    standby_guard = summary.get("standby_guard", {})

    embed = {
        "title": "[ONLINE] GENESIS-01 Reactor & Hull Telemetry",
        "color": 0x10B981,
        "fields": [
            {
                "name": "CPU & Memory Array",
                "value": (
                    f"CPU: `{cpu.get('total_percent', 0):.1f}%` @ `{cpu.get('frequency_ghz', 0):.2f} GHz`\n"
                    f"RAM Used: `{ram.get('used_gb', 0)} / {ram.get('total_gb', 0)} GB` (`{ram.get('percent', 0)}%`)\n"
                    f"Active: `{ram.get('active_gb', 0)} GB` | Standby: `{ram.get('standby_gb', 0)} GB` | Free: `{ram.get('free_gb', 0)} GB`"
                ),
                "inline": False,
            },
            {
                "name": "Hull Storage & GPU",
                "value": (
                    f"Drive C: `{c_drive.get('free_gb', 0)} GB` free / `{c_drive.get('total_gb', 0)} GB` (`{c_drive.get('percent', 0)}%` used)\n"
                    f"GPU: {gpu_text}"
                ),
                "inline": True,
            },
            {
                "name": "Subspace Link & Watchdog",
                "value": (
                    f"Roblox Ping: `{net.get('roblox_ping_ms', 0)} ms`\n"
                    f"MuMu Active: `{mumu.get('count', 0)}` | Recoveries: `{summary.get('net_recoveries', 0)}`\n"
                    f"Standby Purges: `{standby_guard.get('purges', 0)}` (`{standby_guard.get('reclaimed_gb', 0)} GB`)"
                ),
                "inline": True,
            },
            {
                "name": "Core & Ingress",
                "value": (
                    f"Uptime: `{_format_uptime(summary.get('uptime_seconds', 0))}` | "
                    f"Boosts: `{summary.get('session_boosts', 0)}` session / `{summary.get('total_boosts', 0)}` total\n"
                    f"Tunnel (`{tunnel.get('provider', 'unknown')}` / `{tunnel.get('status', 'unknown')}`): `{tunnel_url}`"
                ),
                "inline": False,
            },
        ],
        "footer": {"text": f"GENESIS-01 Orbital Mothership | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }

    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Refresh", "custom_id": "cmd:status"},
                {"type": 2, "style": 3, "label": "RAM Boost", "custom_id": "cmd:boost"},
                {"type": 2, "style": 2, "label": "MuMu Fleet", "custom_id": "cmd:mumu"},
                {"type": 2, "style": 2, "label": "Snap Host", "custom_id": "cmd:screenshot_host"},
            ],
        }
    ]
    return {"embeds": [embed], "components": components}


def build_processes_payload() -> dict:
    procs = get_top_processes(10)
    if not procs:
        snap: list[dict] = []
        for proc in psutil.process_iter(["pid", "name", "memory_info"]):
            try:
                mem = proc.info["memory_info"]
                ram_mb = round((mem.rss if mem else 0) / (1024 ** 2), 1)
                snap.append({"pid": proc.info["pid"], "name": proc.info["name"] or "Unknown", "ram_mb": ram_mb, "protected": False})
            except Exception:
                continue
        snap.sort(key=lambda x: x["ram_mb"], reverse=True)
        procs = snap[:10]

    lines = [
        f"`{idx:02d}.` **{p.get('name', 'Unknown')}** (PID `{p.get('pid', 0)}`) -- `{p.get('ram_mb', 0):.1f} MB`"
        + (" `[PROTECTED]`" if p.get("protected") else "")
        for idx, p in enumerate(procs[:10], 1)
    ]

    embed = {
        "title": "// TOP 10 MOTHERSHIP PROCESSES BY RAM",
        "description": "\n".join(lines) if lines else "No process telemetry sampled yet.",
        "color": 0x06B6D4,
        "footer": {"text": f"GENESIS-01 Process Scanner | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }
    components = [
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 1, "label": "Refresh Procs", "custom_id": "cmd:processes"},
                {"type": 2, "style": 3, "label": "RAM Boost", "custom_id": "cmd:boost"},
                {"type": 2, "style": 2, "label": "Live Status", "custom_id": "cmd:status"},
            ],
        }
    ]
    return {"embeds": [embed], "components": components}


def build_mumu_payload() -> dict:
    health = check_mumu_health()
    devices = health.get("devices", [])
    vm_disk = {int(v.get("instance", 0)): v for v in health.get("vm_disk", []) if v.get("instance")}

    if not devices:
        embed = {
            "title": "[IDLE] MuMu Drone Fleet Status",
            "description": "No MuMu emulator drones are currently active.",
            "color": 0x64748B,
            "footer": {"text": f"GENESIS-01 Fleet Monitor | Host: {socket.gethostname()}"},
            "timestamp": _utc_iso_now(),
        }
        return {"embeds": [embed], "components": []}

    fields: list[dict] = []
    buttons: list[dict] = []
    for dev in devices[:5]:
        idx = int(dev.get("index") or dev.get("instance_index") or 1)
        username = dev.get("username") or "Unlinked"
        game = strip_emojis(dev.get("active_game") or dev.get("target_game") or "Unassigned")
        presence = dev.get("presence_status") or "Unknown"
        disk_info = vm_disk.get(idx)
        disk_line = (
            f"\nVM Disk: `{disk_info.get('used_pct', 0)}%` (`{disk_info.get('used_gb', 0)}/{disk_info.get('total_gb', 0)} GB`)"
            if disk_info
            else ""
        )
        fields.append(
            {
                "name": f"Drone #{idx} (PID {dev.get('pid')})",
                "value": (
                    f"Account: `{username}` (`{presence}`)\n"
                    f"Game: `{game}`\n"
                    f"RAM: `{dev.get('ram_mb', 0):.0f} MB` | CPU: `{dev.get('cpu_percent', 0):.1f}%` | Up: `{dev.get('uptime', '0m')}`\n"
                    f"ADB Port: `{dev.get('adb_port', 16384)}` | Auto-Rejoin: `{'ON' if dev.get('auto_rejoin', True) else 'OFF'}`"
                    f"{disk_line}"
                ),
                "inline": False,
            }
        )
        buttons.append(
            {
                "type": 2,
                "style": 1,
                "label": f"Recover #{idx}",
                "custom_id": f"cmd:recover:{idx}",
            }
        )

    components: list[dict] = []
    if buttons:
        components.append({"type": 1, "components": buttons[:5]})
    components.append(
        {
            "type": 1,
            "components": [
                {"type": 2, "style": 2, "label": "Refresh Fleet", "custom_id": "cmd:mumu"},
                {"type": 2, "style": 2, "label": "Snap MuMu", "custom_id": "cmd:screenshot_mumu"},
                {"type": 2, "style": 2, "label": "Trim VM Cache", "custom_id": "cmd:trim_vm"},
            ],
        }
    )

    embed = {
        "title": f"[ACTIVE] MuMu Drone Fleet ({len(devices)} Online)",
        "color": 0x3B82F6,
        "fields": fields,
        "footer": {"text": f"GENESIS-01 Fleet Monitor | Host: {socket.gethostname()}"},
        "timestamp": _utc_iso_now(),
    }
    return {"embeds": [embed], "components": components}


# --- Server Provisioning & Intel Sync ---
async def _find_or_create_channel(
    bot_token: str,
    guild_id: str,
    existing_channels: list[dict],
    target_name: str,
    ch_type: int,
    parent_id: str | None = None,
    position: int | None = None,
    permission_overwrites: list[dict] | None = None,
    legacy_names: tuple[str, ...] = (),
    known_id: str | None = None,
) -> dict:
    match: dict | None = None
    if known_id:
        match = next((c for c in existing_channels if str(c.get("id")) == str(known_id)), None)
    if match is None:
        candidate_names = {target_name.lower(), *(n.lower() for n in legacy_names)}
        match = next(
            (
                c
                for c in existing_channels
                if c.get("type") == ch_type and str(c.get("name", "")).lower() in candidate_names
            ),
            None,
        )

    if match is not None:
        patch_payload: dict = {}
        if match.get("name") != target_name:
            patch_payload["name"] = target_name
        if parent_id is not None and match.get("parent_id") != parent_id:
            patch_payload["parent_id"] = parent_id
        if position is not None and match.get("position") != position:
            patch_payload["position"] = position
        if permission_overwrites is not None:
            patch_payload["permission_overwrites"] = permission_overwrites
        if patch_payload:
            st, updated, _ = await _discord_api(
                "PATCH", f"/channels/{match['id']}", bot_token, payload=patch_payload
            )
            if 200 <= st < 300 and isinstance(updated, dict):
                match.update(updated)
        return match

    create_payload: dict = {"name": target_name, "type": ch_type}
    if parent_id is not None:
        create_payload["parent_id"] = parent_id
    if position is not None:
        create_payload["position"] = position
    if permission_overwrites is not None:
        create_payload["permission_overwrites"] = permission_overwrites

    st, created, body = await _discord_api(
        "POST", f"/guilds/{guild_id}/channels", bot_token, payload=create_payload
    )
    if 200 <= st < 300 and isinstance(created, dict):
        existing_channels.append(created)
        return created
    raise RuntimeError(f"Failed to create channel '{target_name}' (HTTP {st}): {sanitize_error_text(body)}")


async def _upsert_board_message(
    bot_token: str,
    channel_id: str,
    existing_msg_id: str | None,
    payload: dict,
    pin: bool = False,
) -> str | None:
    if existing_msg_id:
        st_edit, _, _ = await _discord_api(
            "PATCH",
            f"/channels/{channel_id}/messages/{existing_msg_id}",
            bot_token,
            payload=payload,
        )
        if 200 <= st_edit < 300:
            return existing_msg_id

    st_post, msg_data, _ = await _discord_api(
        "POST",
        f"/channels/{channel_id}/messages",
        bot_token,
        payload=payload,
    )
    if 200 <= st_post < 300 and isinstance(msg_data, dict):
        msg_id = str(msg_data["id"])
        if pin:
            await _discord_api("PUT", f"/channels/{channel_id}/pins/{msg_id}", bot_token)
        return msg_id
    return existing_msg_id


async def sync_intel_channels(bot_token: str | None = None) -> dict:
    alerts_cfg = CONFIG.get("alerts", {})
    token = (bot_token or str(alerts_cfg.get("discord_bot_token", "") or "")).strip()
    if not token:
        return {"ok": False, "error": "Missing discord_bot_token"}

    state = load_station_state()
    intel_channels = state.get("intel_channel_ids", {})
    if not isinstance(intel_channels, dict) or not intel_channels:
        return {"ok": False, "error": "Intel channels not provisioned yet"}

    intel_msgs = state.get("intel_message_ids", {})
    if not isinstance(intel_msgs, dict):
        intel_msgs = {}

    builders = {
        "ai": fetch_ai_cortex_intel,
        "tech": fetch_tech_radar_intel,
        "world": fetch_world_pulse_intel,
        "loot": fetch_free_loot_intel,
    }

    updated: list[str] = []
    for key, builder_fn in builders.items():
        cid = intel_channels.get(key)
        if not cid:
            continue
        try:
            payload = await asyncio.to_thread(builder_fn)
            msg_id = await _upsert_board_message(
                token,
                str(cid),
                intel_msgs.get(key),
                payload,
                pin=True,
            )
            if msg_id:
                intel_msgs[key] = msg_id
                updated.append(key)
        except Exception:
            continue

    state["intel_message_ids"] = intel_msgs
    state["last_intel_sync_utc"] = _utc_iso_now()
    save_station_state(state)
    return {"ok": True, "synced_feeds": updated}


async def provision_guild_station(
    bot_token: str | None = None,
    dashboard_channel_id: str | None = None,
) -> dict:
    alerts_cfg = CONFIG.get("alerts", {})
    token = (bot_token or str(alerts_cfg.get("discord_bot_token", "") or "")).strip()
    dash_ch_id = (dashboard_channel_id or str(alerts_cfg.get("discord_channel_id", "") or "")).strip()

    if not token or not dash_ch_id:
        return {"ok": False, "error": "discord_bot_token and discord_channel_id must be configured"}

    st_me, me_data, err_me = await _discord_api("GET", "/users/@me", token)
    if st_me != 200 or not isinstance(me_data, dict):
        return {"ok": False, "error": f"Failed to fetch bot profile (HTTP {st_me}): {err_me[:120]}"}
    app_id = str(me_data["id"])

    st_ch, ch_data, _ = await _discord_api("GET", f"/channels/{dash_ch_id}", token)
    if st_ch != 200 or not isinstance(ch_data, dict) or not ch_data.get("guild_id"):
        return {"ok": False, "error": f"Failed to resolve guild from channel {dash_ch_id} (HTTP {st_ch})"}
    guild_id = str(ch_data["guild_id"])

    await _discord_api("PATCH", f"/guilds/{guild_id}", token, payload={"name": GUILD_MOTHERSHIP_NAME})
    await _discord_api("PATCH", f"/guilds/{guild_id}/members/@me", token, payload={"nick": BOT_MOTHERSHIP_NICK})

    st_list, channels_raw, _ = await _discord_api("GET", f"/guilds/{guild_id}/channels", token)
    if st_list != 200 or not isinstance(channels_raw, list):
        return {"ok": False, "error": f"Failed to list guild channels (HTTP {st_list})"}

    channels = list(channels_raw)
    state = load_station_state()
    state["guild_id"] = guild_id
    state["app_id"] = app_id

    cat_hud = await _find_or_create_channel(
        token, guild_id, channels, CATEGORY_HUD, 4, position=0, legacy_names=("// GENESIS TELEMETRY HUD",)
    )
    cat_bridge = await _find_or_create_channel(
        token, guild_id, channels, CATEGORY_BRIDGE, 4, position=1, legacy_names=("// OPERATIONS CORE",)
    )
    cat_intel = await _find_or_create_channel(
        token, guild_id, channels, CATEGORY_INTEL, 4, position=2
    )
    cat_crew = await _find_or_create_channel(
        token, guild_id, channels, CATEGORY_CREW, 4, position=3, legacy_names=("// PERSONAL LOUNGE",)
    )
    cat_comms = await _find_or_create_channel(
        token, guild_id, channels, CATEGORY_COMMS, 4, position=4, legacy_names=("// VOICE DECK",)
    )

    locked_overwrites = [
        {
            "id": guild_id,
            "type": 0,
            "allow": str(PERMISSION_VIEW_CHANNEL),
            "deny": str(PERMISSION_CONNECT),
        }
    ]

    hud_names = await asyncio.to_thread(format_hud_channel_names)
    saved_hud_ids = list(state.get("hud_channel_ids", []))
    channels_by_id = {str(c["id"]): c for c in channels}
    resolved_hud_ids: list[str] = []

    legacy_hud_prefixes = ("CPU:", "MUMU:", "C:", "BKK:")
    for idx in range(4):
        existing_id = saved_hud_ids[idx] if idx < len(saved_hud_ids) else None
        ch_obj = channels_by_id.get(str(existing_id)) if existing_id else None
        if ch_obj is None:
            new_prefix = HUD_CHANNEL_PREFIXES[idx]
            old_prefix = legacy_hud_prefixes[idx]
            ch_obj = next(
                (
                    c
                    for c in channels
                    if c.get("type") == 2
                    and (c.get("name", "").startswith(new_prefix) or c.get("name", "").startswith(old_prefix))
                ),
                None,
            )
        if ch_obj is None:
            ch_obj = await _find_or_create_channel(
                token,
                guild_id,
                channels,
                hud_names[idx],
                2,
                parent_id=cat_hud["id"],
                position=idx,
                permission_overwrites=locked_overwrites,
            )
        else:
            patch_data = {
                "name": hud_names[idx],
                "parent_id": cat_hud["id"],
                "position": idx,
                "permission_overwrites": locked_overwrites,
            }
            await _discord_api("PATCH", f"/channels/{ch_obj['id']}", token, payload=patch_data)
        resolved_hud_ids.append(str(ch_obj["id"]))

    state["hud_channel_ids"] = resolved_hud_ids
    state["hud_last_names"] = hud_names

    bridge_ch = await _find_or_create_channel(
        token,
        guild_id,
        channels,
        "bridge-command",
        0,
        parent_id=cat_bridge["id"],
        position=0,
        legacy_names=("command-deck",),
        known_id=state.get("command_deck_channel_id"),
    )
    reactor_ch = await _find_or_create_channel(
        token,
        guild_id,
        channels,
        "reactor-telemetry",
        0,
        parent_id=cat_bridge["id"],
        position=1,
        legacy_names=("dashboard",),
        known_id=dash_ch_id,
    )
    datacore_ch = await _find_or_create_channel(
        token,
        guild_id,
        channels,
        "captain-datacore",
        0,
        parent_id=cat_bridge["id"],
        position=2,
        legacy_names=("dropzone",),
        known_id=state.get("dropzone_channel_id"),
    )

    state["command_deck_channel_id"] = str(bridge_ch["id"])
    state["dropzone_channel_id"] = str(datacore_ch["id"])

    existing_intel_ids = state.get("intel_channel_ids", {}) if isinstance(state.get("intel_channel_ids"), dict) else {}
    ch_ai = await _find_or_create_channel(
        token, guild_id, channels, "ai-singularity-feed", 0, parent_id=cat_intel["id"], position=0, known_id=existing_intel_ids.get("ai")
    )
    ch_tech = await _find_or_create_channel(
        token, guild_id, channels, "tech-cyber-radar", 0, parent_id=cat_intel["id"], position=1, known_id=existing_intel_ids.get("tech")
    )
    ch_world = await _find_or_create_channel(
        token, guild_id, channels, "world-market-pulse", 0, parent_id=cat_intel["id"], position=2, known_id=existing_intel_ids.get("world")
    )
    ch_loot = await _find_or_create_channel(
        token, guild_id, channels, "free-games-loot", 0, parent_id=cat_intel["id"], position=3, known_id=existing_intel_ids.get("loot")
    )

    state["intel_channel_ids"] = {
        "ai": str(ch_ai["id"]),
        "tech": str(ch_tech["id"]),
        "world": str(ch_world["id"]),
        "loot": str(ch_loot["id"]),
    }

    await _find_or_create_channel(
        token, guild_id, channels, "observation-lounge", 0, parent_id=cat_crew["id"], position=0, legacy_names=("general",)
    )
    await _find_or_create_channel(
        token, guild_id, channels, "holodeck-archives", 0, parent_id=cat_crew["id"], position=1, legacy_names=("clips-and-highlights",)
    )

    await _find_or_create_channel(
        token, guild_id, channels, "Bridge Comms [01]", 2, parent_id=cat_comms["id"], position=0, legacy_names=("lobby",)
    )
    await _find_or_create_channel(
        token, guild_id, channels, "Tactical Ops [02]", 2, parent_id=cat_comms["id"], position=1, legacy_names=("gaming",)
    )

    keep_cat_ids = {
        str(cat_hud["id"]),
        str(cat_bridge["id"]),
        str(cat_intel["id"]),
        str(cat_crew["id"]),
        str(cat_comms["id"]),
    }
    _, latest_channels, _ = await _discord_api("GET", f"/guilds/{guild_id}/channels", token)
    if isinstance(latest_channels, list):
        used_parents = {str(c.get("parent_id")) for c in latest_channels if c.get("parent_id")}
        for c in latest_channels:
            if c.get("type") == 4 and str(c["id"]) not in keep_cat_ids and str(c["id"]) not in used_parents:
                await _discord_api("DELETE", f"/channels/{c['id']}", token)

    st_cmd, _, err_cmd = await _discord_api(
        "PUT",
        f"/applications/{app_id}/guilds/{guild_id}/commands",
        token,
        payload=SLASH_COMMANDS,
    )
    if st_cmd not in (200, 201):
        return {"ok": False, "error": f"Command registration failed (HTTP {st_cmd}): {err_cmd[:150]}"}

    deck_payload = await asyncio.to_thread(build_deck_payload)
    deck_msg_id = await _upsert_board_message(
        token,
        state["command_deck_channel_id"],
        state.get("deck_message_id"),
        deck_payload,
        pin=True,
    )
    if deck_msg_id:
        state["deck_message_id"] = deck_msg_id

    save_station_state(state)
    intel_res = await sync_intel_channels(token)

    add_event(
        "system",
        f"GENESIS-01 Orbital Mothership provisioned in guild {guild_id} ({len(SLASH_COMMANDS)} slash commands)",
    )
    return {
        "ok": True,
        "guild_name": GUILD_MOTHERSHIP_NAME,
        "guild_id": guild_id,
        "app_id": app_id,
        "bridge_channel_id": state["command_deck_channel_id"],
        "reactor_channel_id": str(reactor_ch["id"]),
        "datacore_channel_id": state["dropzone_channel_id"],
        "intel_channel_ids": state["intel_channel_ids"],
        "hud_channel_ids": resolved_hud_ids,
        "deck_message_id": state.get("deck_message_id"),
        "commands_registered": [c["name"] for c in SLASH_COMMANDS],
        "intel_sync": intel_res,
    }


# --- Interaction Handlers ---
async def _execute_command_action(
    action: str,
    options: dict[str, object] | None = None,
    author_name: str = "commander",
) -> tuple[dict, list[tuple[str, str, bytes]] | None]:
    opts = options or {}

    if action == "status":
        return await asyncio.to_thread(build_status_payload), None

    if action in ("deck", "bridge", "deck_refresh"):
        return await asyncio.to_thread(build_deck_payload), None

    if action == "briefing":
        def _build_brief():
            return build_omni_briefing_payload(
                get_system_metrics(),
                check_mumu_health(),
                get_tunnel_status(),
                get_session_summary(),
            )
        return await asyncio.to_thread(_build_brief), None

    if action == "ai":
        return await asyncio.to_thread(fetch_ai_cortex_intel), None

    if action == "tech":
        return await asyncio.to_thread(fetch_tech_radar_intel), None

    if action == "world":
        return await asyncio.to_thread(fetch_world_pulse_intel), None

    if action == "loot":
        return await asyncio.to_thread(fetch_free_loot_intel), None

    if action == "sync_intel":
        sync_res = await sync_intel_channels()
        ok = bool(sync_res.get("ok"))
        feeds = ", ".join(sync_res.get("synced_feeds", [])) or "none"
        return {
            "embeds": [
                {
                    "title": "[OK] Omniscient Intel Cortex Synchronized" if ok else "[WARN] Intel Sync Failed",
                    "description": f"Refreshed channels: `{feeds}`" if ok else str(sync_res.get("error", "")),
                    "color": 0x10B981 if ok else 0xF59E0B,
                    "timestamp": _utc_iso_now(),
                }
            ]
        }, None

    if action == "processes":
        return await asyncio.to_thread(build_processes_payload), None

    if action == "mumu":
        return await asyncio.to_thread(build_mumu_payload), None

    if action == "boost":
        res = await asyncio.to_thread(ram_boost, True)
        embed = {
            "title": "[OK] Reactor RAM Boost Executed",
            "color": 0x10B981,
            "fields": [
                {"name": "Memory Reclaimed", "value": f"`{res.get('freed_mb', 0)} MB`", "inline": True},
                {
                    "name": "RAM Utilization",
                    "value": f"`{res.get('ram_before_percent', 0)}%` -> `{res.get('ram_after_percent', 0)}%`",
                    "inline": True,
                },
                {
                    "name": "Standby Purge",
                    "value": "`Purged`" if res.get("standby_purged") else "`Verified Healthy`",
                    "inline": True,
                },
                {"name": "Processes Trimmed", "value": f"`{res.get('processes_trimmed', 0)}`", "inline": True},
                {
                    "name": "Temp Cleaned",
                    "value": f"`{res.get('freed_temp_mb', 0)} MB` ({res.get('deleted_temp_files', 0)} files)",
                    "inline": True,
                },
                {"name": "Duration", "value": f"`{res.get('duration_ms', 0)} ms`", "inline": True},
            ],
            "footer": {"text": f"GENESIS-01 Orbital Mothership | Host: {socket.gethostname()}"},
            "timestamp": _utc_iso_now(),
        }
        return {"embeds": [embed]}, None

    if action == "clean":
        res = await asyncio.to_thread(deep_clean_execute)
        details = res.get("details", [])
        summary_lines = [
            f"- {d['name']}: `{d['freed_mb']} MB` ({d['deleted']} files)"
            for d in details
            if d.get("deleted", 0) > 0 or d.get("freed_mb", 0) > 0
        ]
        embed = {
            "title": "[OK] Hull Deep Clean Completed",
            "description": "\n".join(summary_lines) if summary_lines else "All tracked cache targets are already clean.",
            "color": 0x10B981,
            "fields": [
                {"name": "Total Freed", "value": f"`{res.get('total_freed_mb', 0)} MB`", "inline": True},
                {"name": "Files Deleted", "value": f"`{res.get('total_deleted', 0)}`", "inline": True},
            ],
            "footer": {"text": f"GENESIS-01 Orbital Mothership | Host: {socket.gethostname()}"},
            "timestamp": _utc_iso_now(),
        }
        return {"embeds": [embed]}, None

    if action == "trim_vm":
        vm_list = await asyncio.to_thread(get_vm_disk_status)
        if not vm_list:
            return {
                "embeds": [
                    {
                        "title": "[INFO] Trim VM Cache",
                        "description": "No active MuMu VM drones available to trim.",
                        "color": 0x64748B,
                        "timestamp": _utc_iso_now(),
                    }
                ]
            }, None
        trimmed: list[str] = []
        for vm in vm_list:
            port = int(vm.get("port", 0))
            if port > 0:
                ok = await asyncio.to_thread(trim_vm_caches, port)
                trimmed.append(f"Drone #{vm.get('instance')} (port {port}): `{'OK' if ok else 'Failed'}`")
        return {
            "embeds": [
                {
                    "title": "[OK] VM Cache Trim Dispatched",
                    "description": "\n".join(trimmed),
                    "color": 0x3B82F6,
                    "timestamp": _utc_iso_now(),
                }
            ]
        }, None

    if action == "purge":
        limit = int(opts.get("limit") or 100)
        keep_latest = 5 if opts.get("from_button") else 0
        res = await purge_discord_channel_messages(limit=limit, bot_only=False, keep_latest=keep_latest)
        ok = bool(res.get("ok"))
        embed = {
            "title": "[OK] Reactor Channel Purge Completed" if ok else "[WARN] Channel Purge Failed",
            "color": 0x10B981 if ok else 0xEF4444,
            "fields": [
                {"name": "Deleted", "value": f"`{res.get('deleted_count', 0)}`", "inline": True},
                {"name": "Scanned", "value": f"`{res.get('scanned', 0)}`", "inline": True},
                {"name": "Kept Latest", "value": f"`{keep_latest}`", "inline": True},
            ],
            "timestamp": _utc_iso_now(),
        }
        if not ok and res.get("error"):
            embed["description"] = str(res["error"])
        return {"embeds": [embed]}, None

    if action == "recover" or action.startswith("recover:"):
        target_inst: int | None = None
        if ":" in action:
            target_inst = int(action.split(":", 1)[1])
        elif opts.get("instance") is not None:
            target_inst = int(opts["instance"])

        health = check_mumu_health()
        devices = health.get("devices", [])
        targets = []
        if target_inst is not None:
            port = get_adb_port_for_instance(target_inst)
            targets.append((target_inst, f"127.0.0.1:{port}"))
        else:
            for d in devices:
                idx = int(d.get("index") or d.get("instance_index") or 1)
                port = int(d.get("adb_port") or get_adb_port_for_instance(idx))
                targets.append((idx, f"127.0.0.1:{port}"))

        if not targets:
            return {
                "embeds": [
                    {
                        "title": "[WARN] No Target Drone",
                        "description": "No running MuMu drones found and no instance index was specified.",
                        "color": 0xF59E0B,
                        "timestamp": _utc_iso_now(),
                    }
                ]
            }, None

        lines: list[str] = []
        for idx, serial in targets:
            place_id = get_instance_place_id(idx, serial)
            ok = await asyncio.to_thread(recover_roblox_instance, serial, place_id, idx)
            lines.append(f"Drone #{idx} (`{serial}`, place `{place_id}`): `{'Triggered' if ok else 'Failed'}`")

        return {
            "embeds": [
                {
                    "title": "[OK] Drone Recovery Dispatched",
                    "description": "\n".join(lines),
                    "color": 0x3B82F6,
                    "timestamp": _utc_iso_now(),
                }
            ]
        }, None

    if action in ("screenshot", "screenshot_mumu", "screenshot_host"):
        target = str(opts.get("target") or "").lower()
        if action == "screenshot_mumu":
            target = "mumu"
        elif action == "screenshot_host":
            target = "host"
        elif not target:
            target = "mumu" if check_mumu_health().get("count", 0) > 0 else "host"

        if target == "mumu":
            png_bytes, label = await asyncio.to_thread(capture_mumu_screenshot_png)
            if png_bytes is None and action == "screenshot":
                png_bytes, label = await asyncio.to_thread(capture_host_screenshot_png)
        else:
            png_bytes, label = await asyncio.to_thread(capture_host_screenshot_png)

        if png_bytes is None:
            return {
                "embeds": [
                    {
                        "title": "[WARN] Visual Sensor Unavailable",
                        "description": label,
                        "color": 0xF59E0B,
                        "timestamp": _utc_iso_now(),
                    }
                ]
            }, None

        fname = f"genesis_{target}_{int(time.time())}.png"
        payload = {
            "embeds": [
                {
                    "title": f"[SENSOR] {label}",
                    "color": 0x3B82F6,
                    "image": {"url": f"attachment://{fname}"},
                    "footer": {"text": f"GENESIS-01 Visual Array | Host: {socket.gethostname()}"},
                    "timestamp": _utc_iso_now(),
                }
            ],
            "attachments": [{"id": 0, "filename": fname}],
        }
        return payload, [("files[0]", fname, png_bytes)]

    if action in ("note", "log"):
        text = str(opts.get("text") or "").strip()
        if not text:
            return {"content": "Log entry cannot be empty."}, None
        entry = await asyncio.to_thread(append_quick_note, text, author_name)
        state = load_station_state()
        datacore_id = state.get("dropzone_channel_id")
        bot_token = str(CONFIG.get("alerts", {}).get("discord_bot_token", "") or "").strip()
        note_embed = {
            "title": f"[CAPTAIN LOG] Entry #{entry['id']}",
            "description": entry["text"],
            "color": 0x8B5CF6,
            "footer": {"text": f"Logged by {entry['author']}"},
            "timestamp": entry["timestamp_utc"],
        }
        if datacore_id and bot_token:
            await _discord_api("POST", f"/channels/{datacore_id}/messages", bot_token, payload={"embeds": [note_embed]})
        return {
            "embeds": [
                {
                    "title": f"[OK] Captain's Log Recorded (#{entry['id']})",
                    "description": f"Stored in datacore vault and posted to <#{datacore_id}>." if datacore_id else "Stored in datacore vault.",
                    "color": 0x10B981,
                    "timestamp": _utc_iso_now(),
                }
            ]
        }, None

    return {"content": f"Unknown command action: `{action}`"}, None


# --- Gateway Client, Live HUD & Intel Broadcaster ---
class DiscordBotService:
    def __init__(
        self,
        config_provider: Callable[[], dict] | None = None,
    ) -> None:
        self._config_provider = config_provider or (lambda: CONFIG)
        self._loop: asyncio.AbstractEventLoop | None = None
        self._gateway_task: asyncio.Task | None = None
        self._hud_task: asyncio.Task | None = None
        self._intel_task: asyncio.Task | None = None
        self._stop_event: asyncio.Event | None = None
        self._seq: int | None = None
        self._app_id: str | None = None
        self._connected = False

    def start(self, loop: asyncio.AbstractEventLoop | None = None) -> None:
        running_loop = loop or asyncio.get_running_loop()
        self._loop = running_loop
        if self._stop_event is None:
            self._stop_event = asyncio.Event()
        else:
            self._stop_event.clear()

        if self._gateway_task is None or self._gateway_task.done():
            self._gateway_task = running_loop.create_task(self._gateway_supervisor_loop())
        if self._hud_task is None or self._hud_task.done():
            self._hud_task = running_loop.create_task(self._hud_updater_loop())
        if self._intel_task is None or self._intel_task.done():
            self._intel_task = running_loop.create_task(self._intel_broadcast_loop())

    async def stop(self) -> None:
        if self._stop_event:
            self._stop_event.set()
        for task in (self._gateway_task, self._hud_task, self._intel_task):
            if task and not task.done():
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass
                except Exception:
                    pass
        self._gateway_task = None
        self._hud_task = None
        self._intel_task = None
        self._connected = False

    def _get_bot_token(self) -> str:
        cfg = self._config_provider()
        return str(cfg.get("alerts", {}).get("discord_bot_token", "") or "").strip()

    async def _handle_interaction(self, data: dict, bot_token: str) -> None:
        int_id = str(data.get("id", ""))
        int_token = str(data.get("token", ""))
        app_id = str(data.get("application_id") or self._app_id or "")
        int_type = int(data.get("type", 0))
        payload_data = data.get("data", {}) if isinstance(data.get("data"), dict) else {}

        member = data.get("member", {}) if isinstance(data.get("member"), dict) else {}
        user = member.get("user") if isinstance(member.get("user"), dict) else data.get("user", {})
        author_name = str(user.get("username", "commander")) if isinstance(user, dict) else "commander"

        action = ""
        opts: dict[str, object] = {}
        ack_type = 5

        if int_type == 2:
            action = str(payload_data.get("name", ""))
            for opt in payload_data.get("options", []) or []:
                if isinstance(opt, dict) and "name" in opt:
                    opts[str(opt["name"])] = opt.get("value")
        elif int_type == 3:
            custom_id = str(payload_data.get("custom_id", ""))
            if custom_id.startswith("cmd:"):
                action = custom_id[4:]
                opts["from_button"] = True
                if action == "deck_refresh":
                    ack_type = 6
        else:
            return

        await _discord_api(
            "POST",
            f"/interactions/{int_id}/{int_token}/callback",
            None,
            payload={"type": ack_type},
        )

        try:
            resp_payload, files = await _execute_command_action(action, opts, author_name=author_name)
        except Exception as exc:
            resp_payload = {
                "embeds": [
                    {
                        "title": "[ERROR] Command Execution Failed",
                        "description": sanitize_error_text(str(exc), bot_token),
                        "color": 0xEF4444,
                        "timestamp": _utc_iso_now(),
                    }
                ]
            }
            files = None

        patch_path = f"/webhooks/{app_id}/{int_token}/messages/@original"
        if files:
            raw_body, ctype = encode_multipart_form_data(resp_payload, files)
            await _discord_api("PATCH", patch_path, None, raw_body=raw_body, content_type=ctype)
        else:
            await _discord_api("PATCH", patch_path, None, payload=resp_payload)

    async def _run_gateway_session(self, bot_token: str) -> None:
        st, gw_data, err = await _discord_api("GET", "/gateway/bot", bot_token)
        ws_url = "wss://gateway.discord.gg/?v=10&encoding=json"
        if st == 200 and isinstance(gw_data, dict) and gw_data.get("url"):
            ws_url = f"{gw_data['url'].rstrip('/')}/?v=10&encoding=json"
        elif st in (401, 403):
            add_event("error", f"Discord Gateway authentication rejected (HTTP {st}): {err[:120]}")
            await asyncio.sleep(60)
            return

        async with websockets.connect(ws_url, max_size=4 * 1024 * 1024) as ws:
            hello_raw = await ws.recv()
            hello = json.loads(hello_raw)
            if hello.get("op") != 10:
                return
            hb_interval = max(5.0, float(hello["d"]["heartbeat_interval"]) / 1000.0)

            identify_payload = {
                "op": 2,
                "d": {
                    "token": bot_token,
                    "intents": 1,
                    "properties": {
                        "os": "windows",
                        "browser": "genesis_mothership",
                        "device": "genesis_mothership",
                    },
                    "presence": {
                        "status": "online",
                        "activities": [{"name": "GENESIS-01 // Orbital Core", "type": 3}],
                    },
                },
            }
            await ws.send(json.dumps(identify_payload))

            async def _heartbeat_sender() -> None:
                await asyncio.sleep(hb_interval * 0.5)
                while True:
                    await ws.send(json.dumps({"op": 1, "d": self._seq}))
                    await asyncio.sleep(hb_interval)

            hb_task = asyncio.create_task(_heartbeat_sender())
            try:
                async for raw_msg in ws:
                    frame = json.loads(raw_msg)
                    if frame.get("s") is not None:
                        self._seq = int(frame["s"])
                    op = frame.get("op")
                    t_name = frame.get("t")
                    d_body = frame.get("d")

                    if op == 1:
                        await ws.send(json.dumps({"op": 1, "d": self._seq}))
                    elif op == 7:
                        break
                    elif op == 9:
                        self._seq = None
                        await asyncio.sleep(3)
                        break
                    elif op == 0 and t_name == "READY" and isinstance(d_body, dict):
                        self._connected = True
                        app_info = d_body.get("application", {})
                        if isinstance(app_info, dict) and app_info.get("id"):
                            self._app_id = str(app_info["id"])
                        elif isinstance(d_body.get("user"), dict):
                            self._app_id = str(d_body["user"].get("id", ""))
                        add_event("system", "GENESIS-01 Discord Mothership Gateway online and listening")
                    elif op == 0 and t_name == "INTERACTION_CREATE" and isinstance(d_body, dict):
                        asyncio.create_task(self._handle_interaction(d_body, bot_token))
            finally:
                self._connected = False
                hb_task.cancel()
                try:
                    await hb_task
                except (asyncio.CancelledError, Exception):
                    pass

    async def _gateway_supervisor_loop(self) -> None:
        backoff = 2.0
        while True:
            try:
                token = self._get_bot_token()
                if not token:
                    await asyncio.sleep(15)
                    continue
                await self._run_gateway_session(token)
                backoff = 2.0
            except asyncio.CancelledError:
                break
            except Exception as exc:
                self._connected = False
                add_event("warning", f"Discord Gateway disconnected ({sanitize_error_text(str(exc))}); reconnecting...")
                await asyncio.sleep(backoff)
                backoff = min(60.0, backoff * 2)

    async def update_hud_once(self) -> bool:
        token = self._get_bot_token()
        if not token:
            return False
        state = load_station_state()
        hud_ids = state.get("hud_channel_ids", [])
        if not isinstance(hud_ids, list) or not hud_ids:
            return False

        names = await asyncio.to_thread(format_hud_channel_names)
        last_names = state.get("hud_last_names", [])
        updated_any = False

        for idx in range(min(len(hud_ids), len(names))):
            cid = str(hud_ids[idx])
            new_name = names[idx]
            old_name = last_names[idx] if idx < len(last_names) else None
            if new_name != old_name:
                st, _, _ = await _discord_api(
                    "PATCH", f"/channels/{cid}", token, payload={"name": new_name}
                )
                if 200 <= st < 300:
                    updated_any = True

        if updated_any:
            state["hud_last_names"] = names[: len(hud_ids)]
            save_station_state(state)
        return updated_any

    async def _hud_updater_loop(self) -> None:
        await asyncio.sleep(30)
        while True:
            try:
                await self.update_hud_once()
                await asyncio.sleep(360)
            except asyncio.CancelledError:
                break
            except Exception:
                await asyncio.sleep(120)

    async def _intel_broadcast_loop(self) -> None:
        await asyncio.sleep(45)
        while True:
            try:
                token = self._get_bot_token()
                if token:
                    await sync_intel_channels(token)
                await asyncio.sleep(7200)
            except asyncio.CancelledError:
                break
            except Exception:
                await asyncio.sleep(600)


discord_bot_service = DiscordBotService()
