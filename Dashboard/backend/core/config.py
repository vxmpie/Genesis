import copy
import json
import os
import re
import threading
from pathlib import Path
from urllib.parse import urlsplit

# --- Paths ---
DASHBOARD_DIR = Path(__file__).resolve().parents[2]
CONFIG_PATH = DASHBOARD_DIR / "config.json"
CONFIG_EXAMPLE_PATH = DASHBOARD_DIR / "config.example.json"
DATA_DIR = DASHBOARD_DIR / "data"
HISTORY_PATH = DATA_DIR / "history.json"
GROWTH_PATH = DATA_DIR / "growth.json"
CHART_HISTORY_PATH = DATA_DIR / "chart_history.json"
SESSIONS_PATH = DATA_DIR / "sessions.json"

DATA_DIR.mkdir(exist_ok=True)

CONFIG_LOCK = threading.RLock()

# --- Default Schemas ---
DEFAULT_ALERTS_CONFIG: dict = {
    "discord_webhook_url": "",
    "discord_bot_token": "",
    "discord_channel_id": "",
    "auto_purge_enabled": True,
    "auto_purge_on_startup": True,
    "auto_purge_keep_latest": 15,
    "auto_purge_interval_hours": 6,
    "heartbeat_url": "",
    "heartbeat_interval_minutes": 5,
    "min_alert_interval_seconds": 60,
    "notify_on_startup": True,
    "notify_on_mumu_crash": True,
    "notify_on_watchdog_recovery": True,
    "notify_on_ram_critical": True,
    "notify_on_vm_disk_critical": True,
    "notify_on_drift": True,
    "notify_on_tunnel_change": True,
    "notify_on_net_outage": True,
    "notify_on_auto_clean": True,
}

ALERT_TOGGLE_KEYS = (
    "notify_on_startup",
    "notify_on_mumu_crash",
    "notify_on_watchdog_recovery",
    "notify_on_ram_critical",
    "notify_on_vm_disk_critical",
    "notify_on_drift",
    "notify_on_tunnel_change",
    "notify_on_net_outage",
    "notify_on_auto_clean",
)

DEFAULT_CONFIG: dict = {
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
            "csrss.exe",
            "lsass.exe",
            "smss.exe",
            "wininit.exe",
            "System",
            "StarDesk.exe",
            "parsecd.exe",
            "dwm.exe",
        ],
    },
    "mumu": {
        "install_path": "C:/Program Files/Netease/MuMuPlayer",
        "process_names": ["MuMuNxDevice.exe", "MuMuNxMain.exe"],
        "adb_base_port": 16384,
        "adb_port_step": 32,
        "max_instances": 10,
        "auto_reconnect": True,
        "instance_auto_rejoin": {},
        "game_presets": [],
        "instance_places": {},
        "instance_usernames": {},
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
        "standby_purge_min_free_gb": 1.5,
        "auto_deep_clean_enabled": True,
        "auto_deep_clean_hour": 4,
        "auto_deep_clean_threshold_mb": 500,
        "auto_deep_clean_min_free_gb": 30.0,
        "auto_deep_clean_cooldown_hours": 6,
        "auto_deep_clean_notify_min_mb": 50,
        "auto_discovery_enabled": True,
        "auto_discovery_min_mb": 20,
        "auto_discovery_excludes": [],
        "disabled_clean_targets": [],
        "custom_clean_targets": [],
        "vdi_auto_compact_enabled": True,
    },
    "alerts": copy.deepcopy(DEFAULT_ALERTS_CONFIG),
    "tunnel": {
        "provider": "ngrok",
        "ngrok_authtoken": "",
        "ngrok_domain": "",
        "tailscale_url": "",
    },
}

_DISCORD_WEBHOOK_RE = re.compile(
    r"^(https?://(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/[^/]+/)([^/?#]+)(.*)$",
    re.IGNORECASE,
)


def _merge_defaults(cfg: dict) -> bool:
    changed = False
    for section, default_val in DEFAULT_CONFIG.items():
        if section not in cfg or not isinstance(cfg[section], dict):
            cfg[section] = copy.deepcopy(default_val)
            changed = True
            continue
        for key, val in default_val.items():
            if key == "pin" and "pin_hash" in cfg.get("auth", {}):
                continue
            if key not in cfg[section]:
                cfg[section][key] = copy.deepcopy(val)
                changed = True

    if cfg.get("maintenance", {}).get("drift_check_hours", 6) > 1:
        cfg["maintenance"]["drift_check_hours"] = 1
        changed = True
    return changed


def save_config(cfg: dict) -> None:
    with CONFIG_LOCK:
        tmp_path = CONFIG_PATH.with_suffix(".json.tmp")
        with open(tmp_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
        os.replace(tmp_path, CONFIG_PATH)


def load_config() -> dict:
    with CONFIG_LOCK:
        cfg: dict | None = None
        if CONFIG_PATH.exists():
            with open(CONFIG_PATH, "r", encoding="utf-8-sig") as f:
                cfg = json.load(f)
        elif CONFIG_EXAMPLE_PATH.exists():
            try:
                with open(CONFIG_EXAMPLE_PATH, "r", encoding="utf-8-sig") as f:
                    cfg = json.load(f)
            except Exception:
                cfg = None

        if not isinstance(cfg, dict):
            cfg = copy.deepcopy(DEFAULT_CONFIG)
            save_config(cfg)
            return cfg

        if _merge_defaults(cfg) or not CONFIG_PATH.exists():
            save_config(cfg)
        return cfg


CONFIG: dict = load_config()


# --- Secret Masking & Client Config ---
def mask_secret_url(url: str) -> str:
    clean = (url or "").strip()
    if not clean:
        return ""
    match = _DISCORD_WEBHOOK_RE.match(clean)
    if match:
        prefix, token, _suffix = match.groups()
        tail = token[-4:] if len(token) > 4 else ""
        return f"{prefix}****{tail}"
    parsed = urlsplit(clean)
    tail = clean[-4:] if len(clean) > 4 else ""
    if parsed.scheme and parsed.netloc:
        return f"{parsed.scheme}://{parsed.netloc}/****{tail}"
    return f"****{tail}"


def mask_bot_token(token: str) -> str:
    clean = (token or "").strip()
    if not clean:
        return ""
    tail = clean[-4:] if len(clean) > 4 else ""
    return f"****{tail}"


def get_masked_alerts_status(cfg: dict | None = None) -> dict:
    with CONFIG_LOCK:
        source = cfg if cfg is not None else CONFIG
        alerts = source.get("alerts", {})
        raw_webhook = str(alerts.get("discord_webhook_url", "") or "").strip()
        raw_bot_token = str(alerts.get("discord_bot_token", "") or "").strip()
        channel_id = str(alerts.get("discord_channel_id", "") or "").strip()
        raw_heartbeat = str(alerts.get("heartbeat_url", "") or "").strip()
        result = {
            "discord_webhook_configured": bool(raw_webhook),
            "discord_webhook_masked": mask_secret_url(raw_webhook),
            "discord_bot_configured": bool(raw_bot_token),
            "discord_bot_masked": mask_bot_token(raw_bot_token),
            "discord_channel_id": channel_id,
            "auto_purge_enabled": bool(alerts.get("auto_purge_enabled", True)),
            "auto_purge_on_startup": bool(alerts.get("auto_purge_on_startup", True)),
            "auto_purge_keep_latest": int(alerts.get("auto_purge_keep_latest", 15)),
            "auto_purge_interval_hours": int(alerts.get("auto_purge_interval_hours", 6)),
            "heartbeat_configured": bool(raw_heartbeat),
            "heartbeat_masked": mask_secret_url(raw_heartbeat),
            "heartbeat_interval_minutes": int(alerts.get("heartbeat_interval_minutes", 5)),
            "min_alert_interval_seconds": int(alerts.get("min_alert_interval_seconds", 60)),
        }
        for key in ALERT_TOGGLE_KEYS:
            result[key] = bool(alerts.get(key, True))
        return result


def mask_config_for_client(cfg: dict | None = None) -> dict:
    with CONFIG_LOCK:
        source = cfg if cfg is not None else CONFIG
        safe_cfg = copy.deepcopy(source)

        auth_cfg = safe_cfg.setdefault("auth", {})
        auth_cfg.pop("pin_hash", None)
        auth_cfg.pop("salt", None)
        auth_cfg.pop("pin", None)

        alerts_cfg = safe_cfg.setdefault("alerts", {})
        raw_webhook = str(alerts_cfg.get("discord_webhook_url", "") or "").strip()
        raw_bot_token = str(alerts_cfg.get("discord_bot_token", "") or "").strip()
        raw_heartbeat = str(alerts_cfg.get("heartbeat_url", "") or "").strip()
        alerts_cfg["discord_webhook_url"] = ""
        alerts_cfg["discord_webhook_configured"] = bool(raw_webhook)
        alerts_cfg["discord_webhook_masked"] = mask_secret_url(raw_webhook)
        alerts_cfg["discord_bot_token"] = ""
        alerts_cfg["discord_bot_configured"] = bool(raw_bot_token)
        alerts_cfg["discord_bot_masked"] = mask_bot_token(raw_bot_token)
        alerts_cfg["heartbeat_url"] = ""
        alerts_cfg["heartbeat_configured"] = bool(raw_heartbeat)
        alerts_cfg["heartbeat_masked"] = mask_secret_url(raw_heartbeat)

        mumu_cfg = safe_cfg.setdefault("mumu", {})
        mumu_cfg.setdefault("auto_reconnect", True)
        mumu_cfg.setdefault("instance_auto_rejoin", {})
        mumu_cfg.setdefault("game_presets", [])
        mumu_cfg.setdefault("instance_places", {})
        mumu_cfg.setdefault("instance_usernames", {})

        tunnel_cfg = safe_cfg.setdefault("tunnel", {})
        raw_ngrok = str(tunnel_cfg.get("ngrok_authtoken", "") or "").strip()
        tunnel_cfg["ngrok_authtoken"] = ""
        tunnel_cfg["ngrok_authtoken_configured"] = bool(raw_ngrok)

        return safe_cfg


def _validate_http_url(url: str, field_name: str) -> str:
    parsed = urlsplit(url)
    if parsed.scheme.lower() not in ("http", "https") or not parsed.netloc:
        raise ValueError(f"{field_name} must be a valid http(s) URL")
    return url


def update_alerts_config(updates: dict) -> dict:
    with CONFIG_LOCK:
        alerts = CONFIG.setdefault("alerts", copy.deepcopy(DEFAULT_ALERTS_CONFIG))

        if updates.get("clear_webhook") is True:
            alerts["discord_webhook_url"] = ""
        elif "discord_webhook_url" in updates and isinstance(updates["discord_webhook_url"], str):
            raw = updates["discord_webhook_url"].strip()
            if raw and "****" not in raw:
                alerts["discord_webhook_url"] = _validate_http_url(raw, "discord_webhook_url")

        if updates.get("clear_bot_token") is True:
            alerts["discord_bot_token"] = ""
        elif "discord_bot_token" in updates and isinstance(updates["discord_bot_token"], str):
            raw_bot = updates["discord_bot_token"].strip()
            if raw_bot and "****" not in raw_bot:
                alerts["discord_bot_token"] = raw_bot

        if "discord_channel_id" in updates:
            raw_chan = str(updates["discord_channel_id"] or "").strip()
            if raw_chan and not raw_chan.isdigit():
                raise ValueError("discord_channel_id must be a numeric Discord channel ID")
            alerts["discord_channel_id"] = raw_chan

        if updates.get("clear_heartbeat") is True:
            alerts["heartbeat_url"] = ""
        elif "heartbeat_url" in updates and isinstance(updates["heartbeat_url"], str):
            raw_hb = updates["heartbeat_url"].strip()
            if raw_hb and "****" not in raw_hb:
                alerts["heartbeat_url"] = _validate_http_url(raw_hb, "heartbeat_url")

        if "min_alert_interval_seconds" in updates:
            val = int(updates["min_alert_interval_seconds"])
            alerts["min_alert_interval_seconds"] = max(5, min(3600, val))

        if "heartbeat_interval_minutes" in updates:
            val = int(updates["heartbeat_interval_minutes"])
            alerts["heartbeat_interval_minutes"] = max(1, min(1440, val))

        for key in ALERT_TOGGLE_KEYS:
            if key in updates:
                alerts[key] = bool(updates[key])

        if "auto_purge_enabled" in updates:
            alerts["auto_purge_enabled"] = bool(updates["auto_purge_enabled"])
        if "auto_purge_on_startup" in updates:
            alerts["auto_purge_on_startup"] = bool(updates["auto_purge_on_startup"])
        if "auto_purge_keep_latest" in updates:
            alerts["auto_purge_keep_latest"] = max(0, min(100, int(updates["auto_purge_keep_latest"])))
        if "auto_purge_interval_hours" in updates:
            alerts["auto_purge_interval_hours"] = max(1, min(168, int(updates["auto_purge_interval_hours"])))

        save_config(CONFIG)
        return get_masked_alerts_status(CONFIG)
