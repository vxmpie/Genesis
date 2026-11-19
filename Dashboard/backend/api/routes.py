import asyncio
import os
import threading
import time

import psutil
from fastapi import APIRouter, Request
from fastapi.responses import FileResponse, JSONResponse

from backend.api.ws import broadcast_event
from backend.core.auth import (
    clear_failed_attempts,
    create_session_token,
    get_client_ip,
    get_lockout_remaining,
    is_auth_enabled,
    is_ip_locked,
    is_request_authenticated,
    record_failed_attempt,
    verify_pin_input,
)
from backend.core.config import (
    CONFIG,
    CONFIG_LOCK,
    DASHBOARD_DIR,
    mask_config_for_client,
    save_config,
    update_alerts_config,
)
from backend.core.events import add_event, get_recent_events
from backend.services.discord_notifier import notifier, purge_discord_channel_messages
from backend.services.maintenance import (
    check_hardening_drift,
    deep_clean_execute,
    deep_clean_preview,
    get_defender_status,
    get_growth_data,
    get_vm_disk_status,
    ram_boost,
    trim_vm_caches,
)
from backend.services.mumu_monitor import (
    get_game_name_for_place_id,
    record_bot_heartbeat,
    recover_roblox_instance,
    set_instance_place_id,
    set_instance_username,
)
from backend.services.telemetry import (
    flush_dns_cache,
    get_network_observatory,
    get_session_summary,
    get_top_processes,
    reset_session_boosts,
    reset_total_boosts,
)
from backend.services.tunnel import get_tunnel_status
from backend.services.win32_ops import get_protected_names, trim_single_process

router = APIRouter()
FRONTEND_DIST_DIR = DASHBOARD_DIR / "frontend" / "dist"


def _require_auth(request: Request) -> JSONResponse | None:
    if not is_request_authenticated(request):
        return JSONResponse({"error": "Unauthorized"}, status_code=401)
    return None


# --- SPA & PWA Static Routes ---
@router.get("/")
async def serve_dashboard():
    index_file = FRONTEND_DIST_DIR / "index.html"
    if index_file.exists():
        return FileResponse(str(index_file))
    return JSONResponse(
        {"status": "error", "message": "Frontend build not found. Run npm run build in frontend directory."},
        status_code=503,
    )


@router.get("/manifest.json")
async def serve_manifest():
    p = FRONTEND_DIST_DIR / "manifest.json"
    if p.exists():
        return FileResponse(str(p), media_type="application/manifest+json")
    return JSONResponse({"status": "not_found"}, status_code=404)


@router.get("/sw.js")
async def serve_service_worker():
    p = FRONTEND_DIST_DIR / "sw.js"
    if p.exists():
        return FileResponse(str(p), media_type="application/javascript")
    return JSONResponse({"status": "not_found"}, status_code=404)


@router.get("/icon-192.png")
async def serve_icon_192():
    p = FRONTEND_DIST_DIR / "icon-192.png"
    if p.exists():
        return FileResponse(str(p), media_type="image/png")
    return JSONResponse({"status": "not_found"}, status_code=404)


@router.get("/icon-512.png")
async def serve_icon_512():
    p = FRONTEND_DIST_DIR / "icon-512.png"
    if p.exists():
        return FileResponse(str(p), media_type="image/png")
    return JSONResponse({"status": "not_found"}, status_code=404)


# --- Auth Endpoints ---
@router.post("/api/auth/login")
async def api_auth_login(request: Request, payload: dict):
    client_ip = get_client_ip(request, tunnel_provider=get_tunnel_status().get("provider"))
    if is_ip_locked(client_ip):
        retry_after = get_lockout_remaining(client_ip)
        return JSONResponse(
            {"error": "Too many failed attempts. Try again later.", "retry_after_seconds": retry_after},
            status_code=429,
        )

    pin = str(payload.get("pin", "")).strip()
    if verify_pin_input(pin):
        clear_failed_attempts(client_ip)
        token = create_session_token()
        add_event("system", f"Session unlocked (IP: {client_ip})")
        return JSONResponse({"ok": True, "token": token})

    attempts = record_failed_attempt(client_ip)
    add_event("warning", f"Failed PIN attempt from IP: {client_ip} ({attempts})")
    if is_ip_locked(client_ip):
        return JSONResponse(
            {"error": "Too many failed attempts. Try again later.", "retry_after_seconds": get_lockout_remaining(client_ip)},
            status_code=429,
        )
    return JSONResponse({"error": "Invalid PIN"}, status_code=401)


@router.get("/api/auth/status")
async def api_auth_status(request: Request):
    return JSONResponse(
        {
            "auth_required": is_auth_enabled(),
            "authenticated": is_request_authenticated(request),
        }
    )


# --- MuMu & Bot Endpoints ---
@router.post("/api/mumu/set_game")
async def api_mumu_set_game(request: Request, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    inst_id = payload.get("instance", 1)
    try:
        place_id = int(payload.get("place_id", 98800969324557))
    except (TypeError, ValueError):
        return JSONResponse({"error": "Invalid place_id"}, status_code=400)
    ok = await asyncio.to_thread(set_instance_place_id, inst_id, place_id)
    game_name = await asyncio.to_thread(get_game_name_for_place_id, place_id)
    return JSONResponse(
        {
            "ok": ok,
            "instance": inst_id,
            "place_id": place_id,
            "game_name": game_name,
        }
    )


@router.post("/api/mumu/set_username")
async def api_mumu_set_username(request: Request, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    inst_id = str(payload.get("instance", 1))
    username = str(payload.get("username", "")).strip()
    presence = await asyncio.to_thread(set_instance_username, inst_id, username)
    return JSONResponse(
        {
            "ok": True,
            "instance": inst_id,
            "username": username,
            "presence": presence,
        }
    )


@router.post("/api/mumu/trim-instance")
async def api_trim_mumu_instance(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    pid_raw = request.query_params.get("pid")
    if not pid_raw:
        return JSONResponse({"error": "Missing PID"}, status_code=400)
    try:
        pid_int = int(pid_raw)
    except (TypeError, ValueError):
        return JSONResponse({"error": "Invalid PID"}, status_code=400)
    res = await asyncio.to_thread(trim_single_process, pid_int, lambda: trim_vm_caches(16384))
    return JSONResponse(res)


@router.get("/api/roblox/resolve_place")
async def api_roblox_resolve_place(place_id: int):
    name = await asyncio.to_thread(get_game_name_for_place_id, place_id)
    return JSONResponse({"place_id": place_id, "game_name": name})


@router.get("/api/bot/heartbeat")
@router.post("/api/bot/heartbeat")
async def api_bot_heartbeat(request: Request):
    place_id = None
    inst_id = 1
    player = "Unknown"
    status = "playing"
    extra: dict = {}

    if request.method == "POST":
        try:
            body = await request.json()
            if isinstance(body, dict):
                place_id = body.get("place_id") or body.get("placeId")
                inst_id = body.get("instance") or 1
                player = body.get("player") or "Unknown"
                status = body.get("status") or "playing"
                raw_extra = body.get("extra")
                extra = raw_extra if isinstance(raw_extra, dict) else {}
        except Exception:
            pass
    else:
        place_id = request.query_params.get("place_id") or request.query_params.get("placeId")
        inst_id = request.query_params.get("instance") or 1
        player = request.query_params.get("player") or "Unknown"
        status = request.query_params.get("status") or "playing"

    ack = await asyncio.to_thread(record_bot_heartbeat, place_id, inst_id, player, status, extra)
    if status == "disconnected":
        reason = extra.get("reason", "Disconnect Error 277")
        add_event("warning", f"In-Game Bot: {reason} on Instance {inst_id} ({ack['serial']})")
        asyncio.create_task(
            asyncio.to_thread(recover_roblox_instance, ack["serial"], ack["place_id"], inst_id)
        )

    return JSONResponse({"ok": True, **ack})


# --- System Control & Config Endpoints ---
@router.post("/api/boost")
async def api_boost(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    result = await asyncio.to_thread(ram_boost, True)
    return JSONResponse(result)


@router.get("/api/config")
async def api_get_config():
    return JSONResponse(mask_config_for_client(CONFIG))


@router.put("/api/config")
async def api_put_config(request: Request, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    ab = payload.get("auto_boost")
    if not isinstance(ab, dict):
        return JSONResponse({"error": "Invalid auto_boost payload"}, status_code=400)
    try:
        def _apply() -> dict:
            with CONFIG_LOCK:
                target = CONFIG.setdefault("auto_boost", {})
                if "threshold_percent" in ab:
                    target["threshold_percent"] = max(10, min(99, int(ab["threshold_percent"])))
                if "mode" in ab and str(ab["mode"]) in ("auto", "scheduled"):
                    target["mode"] = str(ab["mode"])
                if "enabled" in ab:
                    target["enabled"] = bool(ab["enabled"])
                if "interval_minutes" in ab:
                    target["interval_minutes"] = max(1, min(1440, int(ab["interval_minutes"])))
                save_config(CONFIG)
                return mask_config_for_client(CONFIG)
        return JSONResponse(await asyncio.to_thread(_apply))
    except (TypeError, ValueError):
        return JSONResponse({"error": "Invalid auto_boost configuration values"}, status_code=400)


# --- Alerts & Discord Endpoints ---
@router.get("/api/alerts/status")
async def api_alerts_status():
    return JSONResponse(notifier.get_status())


@router.get("/api/alerts/history")
async def api_alerts_history():
    return JSONResponse(notifier.get_history())


@router.put("/api/alerts/config")
async def api_alerts_config(request: Request, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    try:
        await asyncio.to_thread(update_alerts_config, payload)
    except (TypeError, ValueError) as exc:
        return JSONResponse({"error": str(exc)}, status_code=400)
    status = notifier.get_status()
    await broadcast_event({"type": "alerts_status", "data": status})
    return JSONResponse({"ok": True, "alerts": status})


@router.post("/api/alerts/test")
async def api_alerts_test(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    result = await notifier.send_test_alert()
    status_code = 200 if result.get("ok") else 400
    return JSONResponse(result, status_code=status_code)


@router.post("/api/alerts/purge")
async def api_alerts_purge(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    limit = 100
    bot_only = False
    try:
        body = await request.json()
        if isinstance(body, dict):
            limit = int(body.get("limit", 100))
            bot_only = bool(body.get("bot_only", False))
    except Exception:
        pass
    result = await purge_discord_channel_messages(limit=limit, bot_only=bot_only)
    status_code = 200 if result.get("ok") else 400
    return JSONResponse(result, status_code=status_code)


# --- Telemetry & Maintenance Endpoints ---
@router.get("/api/history")
async def api_history():
    return JSONResponse(get_recent_events(50, newest_first=False))


@router.get("/api/processes")
async def api_processes():
    return JSONResponse(get_top_processes(30))


@router.post("/api/kill/{pid}")
async def api_kill(request: Request, pid: int):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    try:
        proc = psutil.Process(pid)
        name = proc.name()
        protected = get_protected_names()
        if name.lower() in protected:
            return JSONResponse({"error": f"{name} is protected"}, status_code=403)
        proc.terminate()
        add_event("kill", f"Process killed: {name} (PID {pid})")
        return JSONResponse({"ok": True, "name": name, "pid": pid})
    except psutil.NoSuchProcess:
        return JSONResponse({"error": "Process not found"}, status_code=404)
    except psutil.AccessDenied:
        return JSONResponse({"error": "Access denied"}, status_code=403)


@router.get("/api/deep-clean/preview")
async def api_deep_clean_preview():
    return JSONResponse(await asyncio.to_thread(deep_clean_preview))


@router.post("/api/deep-clean/execute")
async def api_deep_clean_execute(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    result = await asyncio.to_thread(deep_clean_execute)
    return JSONResponse(result)


@router.get("/api/hardening")
async def api_hardening():
    return JSONResponse(await asyncio.to_thread(check_hardening_drift))


@router.get("/api/defender")
async def api_defender():
    return JSONResponse(await asyncio.to_thread(get_defender_status))


@router.get("/api/growth")
async def api_growth():
    return JSONResponse(get_growth_data(24))


@router.get("/api/vm-disk")
async def api_vm_disk():
    return JSONResponse(await asyncio.to_thread(get_vm_disk_status))


@router.get("/api/network/observatory")
async def api_network_observatory():
    return JSONResponse(await asyncio.to_thread(get_network_observatory))


@router.post("/api/network/flush-dns")
async def api_network_flush_dns(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    return JSONResponse({"success": await asyncio.to_thread(flush_dns_cache)})


@router.get("/api/summary")
async def api_summary():
    return JSONResponse(await asyncio.to_thread(get_session_summary))


@router.post("/api/summary/reset-session-boosts")
async def api_reset_session_boosts(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    summary = await asyncio.to_thread(reset_session_boosts)
    await broadcast_event({"type": "session_summary", "data": summary})
    return JSONResponse({"success": True, "summary": summary})


@router.post("/api/summary/reset-total-boosts")
async def api_reset_total_boosts(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    summary = await asyncio.to_thread(reset_total_boosts)
    await broadcast_event({"type": "session_summary", "data": summary})
    return JSONResponse({"success": True, "summary": summary})


@router.post("/api/summary/reset-boosts")
async def api_reset_boosts(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    target = request.query_params.get("target", "session")
    summary = await asyncio.to_thread(reset_total_boosts if target == "total" else reset_session_boosts)
    await broadcast_event({"type": "session_summary", "data": summary})
    return JSONResponse({"success": True, "summary": summary})


@router.get("/api/tunnel")
async def api_get_tunnel():
    return JSONResponse(get_tunnel_status())


@router.post("/api/system/restart")
async def api_system_restart(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err

    def _delayed_exit() -> None:
        time.sleep(1)
        os._exit(0)

    threading.Thread(target=_delayed_exit, daemon=True).start()
    return JSONResponse({"success": True, "message": "Server restarting..."})
