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
    add_custom_clean_target,
    check_hardening_drift,
    compact_stopped_mumu_vdis,
    deep_clean_execute,
    deep_clean_preview,
    get_auto_clean_status,
    get_defender_status,
    get_growth_data,
    get_vm_disk_status,
    ram_boost,
    remove_custom_clean_target,
    trim_vm_caches,
    update_auto_clean_config,
)
from backend.services.mumu_monitor import (
    add_game_preset,
    apply_instance_game_update,
    delete_game_preset,
    get_game_name_for_place_id,
    get_game_presets,
    get_mumu_instances,
    is_auto_rejoin_enabled,
    record_bot_heartbeat,
    recover_roblox_instance,
    set_instance_username,
    update_game_preset,
)
from backend.services.telemetry import (
    flush_dns_cache,
    get_network_observatory,
    get_session_summary,
    get_top_processes,
    reset_session_boosts,
    reset_total_boosts,
)
from backend.services.tunnel import get_tunnel_status, request_tunnel_restart
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
@router.get("/api/mumu/presets")
async def api_mumu_get_presets():
    presets = await asyncio.to_thread(get_game_presets)
    return JSONResponse({"presets": presets})


@router.post("/api/mumu/presets")
async def api_mumu_add_preset(request: Request, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    try:
        res = await asyncio.to_thread(
            add_game_preset,
            payload.get("place_id"),
            str(payload.get("name") or ""),
            False,
        )
    except ValueError as exc:
        return JSONResponse({"error": str(exc)}, status_code=400)
    await broadcast_event(
        {
            "type": "game_presets_updated",
            "action": "added",
            "preset": res["preset"],
            "presets": res["presets"],
            "config": mask_config_for_client(CONFIG),
        }
    )
    return JSONResponse({"ok": True, **res})


@router.put("/api/mumu/presets/{original_place_id}")
async def api_mumu_update_preset(request: Request, original_place_id: str, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    raw_new_pid = payload["place_id"] if "place_id" in payload else original_place_id
    try:
        res = await asyncio.to_thread(
            update_game_preset,
            original_place_id,
            raw_new_pid,
            str(payload.get("name") or ""),
        )
    except KeyError as exc:
        return JSONResponse({"error": exc.args[0] if exc.args else "Game preset not found"}, status_code=404)
    except ValueError as exc:
        return JSONResponse({"error": str(exc)}, status_code=400)
    await broadcast_event(
        {
            "type": "game_presets_updated",
            "action": "updated",
            "preset": res["preset"],
            "presets": res["presets"],
            "config": mask_config_for_client(CONFIG),
        }
    )
    return JSONResponse({"ok": True, **res})


@router.delete("/api/mumu/presets/{place_id}")
async def api_mumu_delete_preset(request: Request, place_id: str):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    try:
        res = await asyncio.to_thread(delete_game_preset, place_id)
    except KeyError as exc:
        return JSONResponse({"error": exc.args[0] if exc.args else "Game preset not found"}, status_code=404)
    except ValueError as exc:
        return JSONResponse({"error": str(exc)}, status_code=400)
    await broadcast_event(
        {
            "type": "game_presets_updated",
            "action": "deleted",
            "deleted_place_id": res["deleted_place_id"],
            "presets": res["presets"],
            "config": mask_config_for_client(CONFIG),
        }
    )
    return JSONResponse({"ok": True, **res})


@router.post("/api/mumu/set_game")
async def api_mumu_set_game(request: Request, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    inst_id = payload.get("instance", 1)
    try:
        res = await asyncio.to_thread(
            apply_instance_game_update,
            inst_id,
            payload.get("place_id"),
            bool(payload.get("save_as_preset")),
            str(payload.get("preset_name") or ""),
        )
    except ValueError as exc:
        return JSONResponse({"error": str(exc)}, status_code=400)

    preset_res = res.pop("preset_res", None)
    if preset_res is not None:
        await broadcast_event(
            {
                "type": "game_presets_updated",
                "action": "added" if preset_res["created"] else "updated",
                "preset": preset_res["preset"],
                "presets": preset_res["presets"],
                "config": mask_config_for_client(CONFIG),
            }
        )
    await broadcast_event({"type": "instance_game_updated", **res})
    return JSONResponse(res)


@router.post("/api/mumu/set_username")
async def api_mumu_set_username(request: Request, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    inst_id = str(payload.get("instance", 1))
    username = str(payload.get("username", "")).strip()
    presence = await asyncio.to_thread(set_instance_username, inst_id, username)
    event_payload = {
        "instance": inst_id,
        "username": username,
        "presence": presence,
    }
    await broadcast_event({"type": "mumu_username_set", **event_payload})
    return JSONResponse({"ok": True, **event_payload})


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
    if pid_int <= 4:
        return JSONResponse({"error": "Invalid PID"}, status_code=400)
    matched = next((x for x in get_mumu_instances() if x.get("pid") == pid_int), None)
    adb_port = (
        matched.get("adb_port")
        if matched and isinstance(matched.get("adb_port"), int) and matched["adb_port"] > 0
        else None
    )
    fallback_fn = (lambda p=adb_port: trim_vm_caches(p)) if adb_port else None
    res = await asyncio.to_thread(trim_single_process, pid_int, fallback_fn)
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
        if is_auto_rejoin_enabled(inst_id, ack["serial"]):
            add_event("warning", f"In-Game Bot: {reason} on Instance {inst_id} ({ack['serial']})")
            asyncio.create_task(
                asyncio.to_thread(recover_roblox_instance, ack["serial"], ack["place_id"], inst_id)
            )
        else:
            add_event(
                "warning",
                f"In-Game Bot: {reason} on Instance {inst_id} ({ack['serial']}) -- Rejoin skipped (auto-rejoin off)",
            )
            return JSONResponse({"ok": True, "rejoin_skipped": True, **ack})

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
    if pid <= 4:
        return JSONResponse({"error": "Invalid PID"}, status_code=400)

    def _kill_sync() -> tuple[int, dict]:
        try:
            proc = psutil.Process(pid)
            name = proc.name()
            protected = get_protected_names()
            if name.lower() in protected:
                return 403, {"error": f"{name} is protected"}
            proc.terminate()
            add_event("kill", f"Process killed: {name} (PID {pid})")
            return 200, {"ok": True, "name": name, "pid": pid}
        except psutil.NoSuchProcess:
            return 404, {"error": "Process not found"}
        except psutil.AccessDenied:
            return 403, {"error": "Access denied"}

    status_code, payload = await asyncio.to_thread(_kill_sync)
    return JSONResponse(payload, status_code=status_code)


@router.get("/api/deep-clean/preview")
async def api_deep_clean_preview():
    return JSONResponse(await asyncio.to_thread(deep_clean_preview))


@router.get("/api/deep-clean/status")
async def api_deep_clean_status():
    return JSONResponse(await asyncio.to_thread(get_auto_clean_status))


@router.post("/api/deep-clean/execute")
async def api_deep_clean_execute(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    targets: list[str] | None = None
    try:
        body = await request.json()
        if isinstance(body, dict) and isinstance(body.get("targets"), list):
            targets = [str(t) for t in body["targets"]]
    except Exception:
        pass
    result = await asyncio.to_thread(deep_clean_execute, targets, "manual")
    status = await asyncio.to_thread(get_auto_clean_status)
    await broadcast_event({"type": "deep_clean_result", "data": result, "result": result})
    await broadcast_event({"type": "auto_clean_status", "data": status})
    return JSONResponse(result)


@router.post("/api/deep-clean/config")
async def api_deep_clean_config(request: Request, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    try:
        status = await asyncio.to_thread(update_auto_clean_config, payload)
    except (TypeError, ValueError) as exc:
        return JSONResponse({"error": str(exc)}, status_code=400)
    masked_cfg = mask_config_for_client(CONFIG)
    await broadcast_event({"type": "auto_clean_status", "data": status, "config": masked_cfg})
    return JSONResponse({"ok": True, "status": status, "config": masked_cfg})


@router.post("/api/deep-clean/custom-targets")
async def api_deep_clean_add_target(request: Request, payload: dict):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    try:
        target = await asyncio.to_thread(add_custom_clean_target, payload)
    except (TypeError, ValueError) as exc:
        return JSONResponse({"error": str(exc)}, status_code=400)
    status = await asyncio.to_thread(get_auto_clean_status)
    masked_cfg = mask_config_for_client(CONFIG)
    await broadcast_event({"type": "auto_clean_status", "data": status, "config": masked_cfg})
    return JSONResponse({"ok": True, "target": target, "status": status, "config": masked_cfg})


@router.delete("/api/deep-clean/custom-targets/{name}")
async def api_deep_clean_delete_target(request: Request, name: str):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    removed = await asyncio.to_thread(remove_custom_clean_target, name)
    if not removed:
        return JSONResponse({"error": f"Custom target '{name}' not found"}, status_code=404)
    status = await asyncio.to_thread(get_auto_clean_status)
    masked_cfg = mask_config_for_client(CONFIG)
    await broadcast_event({"type": "auto_clean_status", "data": status, "config": masked_cfg})
    return JSONResponse({"ok": True, "deleted": name, "status": status, "config": masked_cfg})


@router.post("/api/deep-clean/compact-vdi")
async def api_deep_clean_compact_vdi(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    result = await asyncio.to_thread(compact_stopped_mumu_vdis, "manual")
    status = await asyncio.to_thread(get_auto_clean_status)
    await broadcast_event({"type": "vdi_compact_result", "data": result})
    await broadcast_event({"type": "auto_clean_status", "data": status})
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


@router.post("/api/tunnel/restart")
async def api_restart_tunnel(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err
    res = await asyncio.to_thread(request_tunnel_restart)
    status_code = 200 if res.get("ok") else 400
    return JSONResponse(res, status_code=status_code)


@router.post("/api/system/restart")
async def api_system_restart(request: Request):
    auth_err = _require_auth(request)
    if auth_err:
        return auth_err

    def _delayed_exit() -> None:
        time.sleep(1)
        os._exit(42)

    threading.Thread(target=_delayed_exit, daemon=True).start()
    return JSONResponse({"success": True, "message": "Server restarting..."})
