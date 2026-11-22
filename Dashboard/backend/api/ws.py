import asyncio
import json
import psutil
from fastapi import WebSocket, WebSocketDisconnect

from backend.core.auth import is_auth_enabled, verify_session_token
from backend.core.config import (
    CONFIG,
    CONFIG_LOCK,
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
    get_cached_defender_status,
    get_cached_drift_result,
    get_defender_status,
    get_growth_data,
    get_vm_disk_status,
    ram_boost,
    remove_custom_clean_target,
    run_quick_scan,
    trim_vm_caches,
    update_auto_clean_config,
)
from backend.services.mumu_monitor import (
    add_game_preset,
    apply_instance_game_update,
    check_mumu_health,
    delete_game_preset,
    get_adb_port_for_instance,
    get_mumu_instances,
    governor_instance_action,
    set_auto_rejoin,
    set_instance_username,
    update_game_preset,
)
from backend.services.telemetry import (
    flush_dns_cache,
    get_auto_boost_payload,
    get_chart_history,
    get_metrics_with_rates,
    get_network_observatory,
    get_session_summary,
    get_top_processes,
    reset_session_boosts,
    reset_total_boosts,
)
from backend.services.tunnel import get_tunnel_status, request_tunnel_restart
from backend.services.win32_ops import (
    apply_pcore_affinity_for_mumu,
    get_affinity_status,
    get_protected_names,
    get_timer_resolution_status,
    scan_and_flush_shader_cache,
    set_high_precision_timer,
    trim_single_process,
)

READ_ONLY_COMMANDS: frozenset[str] = frozenset(
    {
        "deep_clean_preview",
        "deep_clean_status",
        "scan_deep_clean",
        "scan_targets",
        "defender_status",
        "check_hardening",
        "refresh_hardening",
        "observatory_refresh",
        "growth_data",
        "vm_disk_refresh",
        "scan_shader_cache",
        "alerts_status",
        "alerts_history",
    }
)


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[WebSocket, dict] = {}

    @property
    def active_connections(self) -> list[tuple[WebSocket, bool]]:
        return [(ws, meta["auth"]) for ws, meta in self._connections.items()]

    async def connect(self, ws: WebSocket, is_auth: bool) -> None:
        await ws.accept()
        self._connections[ws] = {"auth": is_auth, "lock": asyncio.Lock()}

    def set_auth(self, ws: WebSocket, is_auth: bool) -> None:
        if ws in self._connections:
            self._connections[ws]["auth"] = is_auth

    def is_auth(self, ws: WebSocket) -> bool:
        if not is_auth_enabled():
            return True
        meta = self._connections.get(ws)
        return bool(meta["auth"]) if meta else False

    def disconnect(self, ws: WebSocket) -> None:
        self._connections.pop(ws, None)

    async def send_to(self, ws: WebSocket, data: dict) -> None:
        meta = self._connections.get(ws)
        if meta is None:
            return
        async with meta["lock"]:
            await ws.send_json(data)

    async def broadcast(self, data: dict) -> None:
        dead: list[WebSocket] = []
        for conn in list(self._connections.keys()):
            try:
                await self.send_to(conn, data)
            except Exception:
                dead.append(conn)
        for d in dead:
            self.disconnect(d)


manager = ConnectionManager()


async def broadcast_event(data: dict) -> None:
    await manager.broadcast(data)


async def _build_init_payload(is_authed: bool) -> dict:
    observatory, summary, timer_res, pcore_aff, shader_cache, auto_clean_status = await asyncio.gather(
        asyncio.to_thread(get_network_observatory),
        asyncio.to_thread(get_session_summary),
        asyncio.to_thread(get_timer_resolution_status),
        asyncio.to_thread(get_affinity_status),
        asyncio.to_thread(scan_and_flush_shader_cache, True),
        asyncio.to_thread(get_auto_clean_status),
    )
    return {
        "type": "init",
        "auth_required": is_auth_enabled(),
        "authenticated": is_authed,
        "config": mask_config_for_client(CONFIG),
        "history": get_recent_events(50, newest_first=True),
        "hardening": get_cached_drift_result(),
        "defender": get_cached_defender_status(),
        "vm_disk": check_mumu_health().get("vm_disk", []),
        "growth": get_growth_data(24),
        "observatory": observatory,
        "summary": summary,
        "timer_resolution": timer_res,
        "pcore_affinity": pcore_aff,
        "shader_cache": shader_cache,
        "auto_clean_status": auto_clean_status,
        "chart_history": get_chart_history(),
        "alerts_status": notifier.get_status(),
        "alerts_history": notifier.get_history(),
        "tunnel": get_tunnel_status(),
    }


async def websocket_endpoint(ws: WebSocket) -> None:
    initial_token = ws.query_params.get("token")
    is_authed = verify_session_token(initial_token)
    await manager.connect(ws, is_authed)

    try:
        init_payload = await _build_init_payload(is_authed)
        await manager.send_to(ws, init_payload)

        async def _metrics_sender() -> None:
            obs_counter = 0
            try:
                while True:
                    metrics, summary, timer_res, pcore_aff = await asyncio.gather(
                        asyncio.to_thread(get_metrics_with_rates),
                        asyncio.to_thread(get_session_summary),
                        asyncio.to_thread(get_timer_resolution_status),
                        asyncio.to_thread(get_affinity_status),
                    )
                    obs_counter += 1
                    payload: dict = {
                        "type": "metrics",
                        "metrics": metrics,
                        "mumu": check_mumu_health(),
                        "top_processes": get_top_processes(10),
                        "summary": summary,
                        "timer_resolution": timer_res,
                        "pcore_affinity": pcore_aff,
                        "auto_boost": get_auto_boost_payload(),
                        "tunnel": get_tunnel_status(),
                    }
                    if obs_counter % 2 == 0:
                        payload["observatory"] = await asyncio.to_thread(get_network_observatory)

                    await manager.send_to(ws, payload)
                    interval_ms = int(CONFIG.get("metrics", {}).get("update_interval_ms", 1000))
                    await asyncio.sleep(max(0.25, interval_ms / 1000.0))
            except WebSocketDisconnect:
                return

        async def _receiver() -> None:
            try:
                while True:
                    msg = await ws.receive_text()
                    try:
                        data = json.loads(msg)
                    except json.JSONDecodeError:
                        await manager.send_to(ws, {"type": "error", "error": "Invalid JSON payload"})
                        continue
                    if isinstance(data, dict):
                        await handle_ws_command(ws, data)
            except WebSocketDisconnect:
                return

        sender_task = asyncio.create_task(_metrics_sender())
        receiver_task = asyncio.create_task(_receiver())
        try:
            done, pending = await asyncio.wait(
                {sender_task, receiver_task},
                return_when=asyncio.FIRST_COMPLETED,
            )
            for task in pending:
                task.cancel()
            for task in pending:
                try:
                    await task
                except (asyncio.CancelledError, WebSocketDisconnect, Exception):
                    pass
            for task in done:
                if not task.cancelled():
                    try:
                        task.result()
                    except (WebSocketDisconnect, asyncio.CancelledError, Exception):
                        pass
        except asyncio.CancelledError:
            for task in (sender_task, receiver_task):
                if not task.done():
                    task.cancel()
            for task in (sender_task, receiver_task):
                try:
                    await task
                except (asyncio.CancelledError, WebSocketDisconnect, Exception):
                    pass
            raise
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        manager.disconnect(ws)


async def handle_ws_command(ws: WebSocket, data: dict) -> None:
    cmd = data.get("command")
    token = data.get("token")

    if token and verify_session_token(token):
        manager.set_auth(ws, True)

    if cmd == "auth":
        if verify_session_token(token):
            manager.set_auth(ws, True)
            await manager.send_to(ws, {"type": "auth_success", "authenticated": True})
        else:
            manager.set_auth(ws, False)
            await manager.send_to(ws, {"type": "auth_failed", "authenticated": False})
        return

    if is_auth_enabled() and cmd not in READ_ONLY_COMMANDS and not manager.is_auth(ws):
        await manager.send_to(
            ws,
            {"type": "auth_required", "command": cmd, "error": "Authentication required for this command."},
        )
        return

    if cmd == "boost":
        result = await asyncio.to_thread(ram_boost, True)
        summary = await asyncio.to_thread(get_session_summary)
        await manager.send_to(ws, {"type": "boost_result", "result": result, "summary": summary})
        metrics = await asyncio.to_thread(get_metrics_with_rates)
        await manager.broadcast(
            {
                "type": "metrics",
                "metrics": metrics,
                "summary": summary,
                "auto_boost": get_auto_boost_payload(),
            }
        )

    elif cmd in (
        "update_config",
        "set_auto_boost",
        "toggle_auto_boost",
        "set_threshold",
        "set_boost_mode",
        "set_boost_interval",
    ):
        payload = data.get("config") if isinstance(data.get("config"), dict) else {}
        try:
            def _apply_ws_config() -> dict:
                with CONFIG_LOCK:
                    ab = CONFIG.setdefault("auto_boost", {})
                    if "enabled" in data:
                        ab["enabled"] = bool(data["enabled"])
                    elif "enabled" in payload:
                        ab["enabled"] = bool(payload["enabled"])

                    if "threshold" in data:
                        ab["threshold_percent"] = max(10, min(99, int(data["threshold"])))
                    elif "threshold_percent" in payload:
                        ab["threshold_percent"] = max(10, min(99, int(payload["threshold_percent"])))

                    if "mode" in data and str(data["mode"]) in ("auto", "scheduled"):
                        ab["mode"] = str(data["mode"])
                    elif "mode" in payload and str(payload["mode"]) in ("auto", "scheduled"):
                        ab["mode"] = str(payload["mode"])

                    if "interval_minutes" in data:
                        ab["interval_minutes"] = max(1, min(1440, int(data["interval_minutes"])))
                    elif "interval_minutes" in payload:
                        ab["interval_minutes"] = max(1, min(1440, int(payload["interval_minutes"])))

                    save_config(CONFIG)
                    return {
                        "type": "config_updated",
                        "config": mask_config_for_client(CONFIG),
                        "auto_boost": {
                            "enabled": ab["enabled"],
                            "mode": ab["mode"],
                            "threshold": ab["threshold_percent"],
                            "interval_minutes": ab["interval_minutes"],
                        },
                    }
            resp = await asyncio.to_thread(_apply_ws_config)
            await manager.send_to(ws, resp)
        except (TypeError, ValueError) as exc:
            await manager.send_to(ws, {"type": "error", "error": f"Invalid config parameter: {exc}"})

    elif cmd in ("deep_clean_preview", "scan_deep_clean", "scan_targets"):
        preview = await asyncio.to_thread(deep_clean_preview)
        total_files = sum(p.get("file_count", 0) for p in preview)
        total_mb = round(sum(p.get("size_mb", 0) for p in preview), 1)
        await manager.send_to(
            ws,
            {
                "type": "deep_clean_preview",
                "data": preview,
                "items": preview,
                "total_files": total_files,
                "total_size_mb": total_mb,
            },
        )

    elif cmd in ("deep_clean_execute", "clean_all"):
        targets = data.get("targets")
        result = await asyncio.to_thread(deep_clean_execute, targets, "manual")
        status = await asyncio.to_thread(get_auto_clean_status)
        await manager.send_to(ws, {"type": "deep_clean_result", "data": result, "result": result})
        await broadcast_event({"type": "auto_clean_status", "data": status})

    elif cmd == "deep_clean_status":
        status = await asyncio.to_thread(get_auto_clean_status)
        await manager.send_to(ws, {"type": "auto_clean_status", "data": status})

    elif cmd == "deep_clean_config_update":
        updates = data.get("config") if isinstance(data.get("config"), dict) else data
        try:
            status = await asyncio.to_thread(update_auto_clean_config, updates)
            masked_cfg = mask_config_for_client(CONFIG)
            await broadcast_event({"type": "auto_clean_status", "data": status, "config": masked_cfg})
            await manager.send_to(
                ws,
                {"type": "deep_clean_config_updated", "data": status, "config": masked_cfg},
            )
        except (TypeError, ValueError) as exc:
            await manager.send_to(ws, {"type": "error", "error": str(exc)})

    elif cmd == "deep_clean_add_target":
        try:
            target = await asyncio.to_thread(add_custom_clean_target, data)
            status = await asyncio.to_thread(get_auto_clean_status)
            masked_cfg = mask_config_for_client(CONFIG)
            await broadcast_event({"type": "auto_clean_status", "data": status, "config": masked_cfg})
            await manager.send_to(
                ws,
                {"type": "deep_clean_target_added", "target": target, "data": status},
            )
        except (TypeError, ValueError) as exc:
            await manager.send_to(ws, {"type": "error", "error": str(exc)})

    elif cmd == "deep_clean_remove_target":
        name = str(data.get("name", "") or "").strip()
        removed = await asyncio.to_thread(remove_custom_clean_target, name)
        if not removed:
            await manager.send_to(ws, {"type": "error", "error": f"Custom target '{name}' not found"})
            return
        status = await asyncio.to_thread(get_auto_clean_status)
        masked_cfg = mask_config_for_client(CONFIG)
        await broadcast_event({"type": "auto_clean_status", "data": status, "config": masked_cfg})
        await manager.send_to(
            ws,
            {"type": "deep_clean_target_removed", "name": name, "data": status},
        )

    elif cmd == "deep_clean_compact_vdi":
        result = await asyncio.to_thread(compact_stopped_mumu_vdis, "manual")
        status = await asyncio.to_thread(get_auto_clean_status)
        await broadcast_event({"type": "vdi_compact_result", "data": result})
        await broadcast_event({"type": "auto_clean_status", "data": status})

    elif cmd == "vm_disk_refresh":
        vm_data = await asyncio.to_thread(get_vm_disk_status)
        await manager.send_to(ws, {"type": "vm_disk_status", "data": vm_data})

    elif cmd == "vm_trim_cache":
        port = data.get("port")
        if port:
            success = await asyncio.to_thread(trim_vm_caches, int(port))
            await manager.send_to(ws, {"type": "vm_trim_result", "port": int(port), "success": success})

    elif cmd in ("check_hardening", "refresh_hardening"):
        result = await asyncio.to_thread(check_hardening_drift)
        await manager.send_to(ws, {"type": "hardening_status", "data": result})

    elif cmd in ("set_instance_game", "set_mumu_game"):
        inst_id = data.get("instance", 1)
        try:
            res = await asyncio.to_thread(
                apply_instance_game_update,
                inst_id,
                data.get("place_id"),
                bool(data.get("save_as_preset")),
                str(data.get("preset_name") or ""),
            )
        except ValueError as exc:
            await manager.send_to(ws, {"type": "error", "error": str(exc)})
            return

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

    elif cmd in ("set_instance_username", "set_mumu_username"):
        inst_id = str(data.get("instance", 1))
        username = str(data.get("username", "")).strip()
        presence = await asyncio.to_thread(set_instance_username, inst_id, username)
        await broadcast_event(
            {
                "type": "mumu_username_set",
                "instance": inst_id,
                "username": username,
                "presence": presence,
            }
        )

    elif cmd == "add_game_preset":
        try:
            res = await asyncio.to_thread(
                add_game_preset,
                data.get("place_id"),
                str(data.get("name") or ""),
                False,
            )
        except ValueError as exc:
            await manager.send_to(ws, {"type": "error", "error": str(exc)})
            return
        await broadcast_event(
            {
                "type": "game_presets_updated",
                "action": "added",
                "preset": res["preset"],
                "presets": res["presets"],
                "config": mask_config_for_client(CONFIG),
            }
        )

    elif cmd == "update_game_preset":
        try:
            res = await asyncio.to_thread(
                update_game_preset,
                data.get("original_place_id"),
                data.get("place_id"),
                str(data.get("name") or ""),
            )
        except (ValueError, KeyError) as exc:
            msg = exc.args[0] if isinstance(exc, KeyError) and exc.args else str(exc)
            await manager.send_to(ws, {"type": "error", "error": msg})
            return
        await broadcast_event(
            {
                "type": "game_presets_updated",
                "action": "updated",
                "preset": res["preset"],
                "presets": res["presets"],
                "config": mask_config_for_client(CONFIG),
            }
        )

    elif cmd == "delete_game_preset":
        try:
            res = await asyncio.to_thread(delete_game_preset, data.get("place_id"))
        except (ValueError, KeyError) as exc:
            msg = exc.args[0] if isinstance(exc, KeyError) and exc.args else str(exc)
            await manager.send_to(ws, {"type": "error", "error": msg})
            return
        await broadcast_event(
            {
                "type": "game_presets_updated",
                "action": "deleted",
                "deleted_place_id": res["deleted_place_id"],
                "presets": res["presets"],
                "config": mask_config_for_client(CONFIG),
            }
        )

    elif cmd == "defender_status":
        status = await asyncio.to_thread(get_defender_status)
        await manager.send_to(ws, {"type": "defender_status", "data": status})

    elif cmd == "quick_scan":
        success = await asyncio.to_thread(run_quick_scan)
        await manager.send_to(ws, {"type": "quick_scan_result", "success": success})
        status = await asyncio.to_thread(get_defender_status)
        await manager.send_to(ws, {"type": "defender_status", "data": status})

    elif cmd == "growth_data":
        await manager.send_to(ws, {"type": "growth_data", "data": get_growth_data(24)})

    elif cmd == "flush_dns":
        success = await asyncio.to_thread(flush_dns_cache)
        await manager.send_to(ws, {"type": "flush_dns_result", "success": success})

    elif cmd == "observatory_refresh":
        obs = await asyncio.to_thread(get_network_observatory)
        await manager.send_to(ws, {"type": "observatory_update", "data": obs})

    elif cmd in ("reset_boost_counter", "reset_session_boosts"):
        summary = await asyncio.to_thread(reset_session_boosts)
        await broadcast_event({"type": "session_summary", "data": summary})
        await manager.send_to(ws, {"type": "session_boost_reset", "data": summary})

    elif cmd == "reset_total_boosts":
        summary = await asyncio.to_thread(reset_total_boosts)
        await broadcast_event({"type": "session_summary", "data": summary})
        await manager.send_to(ws, {"type": "total_boost_reset", "data": summary})

    elif cmd in ("trim_mumu_instance", "trim_mumu"):
        def _parse_int(val: object, min_val: int = 1) -> int | None:
            if val is None or isinstance(val, bool):
                return None
            try:
                num = int(val)  # type: ignore[arg-type]
                return num if num >= min_val else None
            except (TypeError, ValueError):
                return None

        raw_pid = data.get("pid")
        raw_inst = data.get("instance")
        pid = _parse_int(raw_pid, 5)
        if raw_pid is not None and pid is None:
            await manager.send_to(
                ws, {"type": "mumu_trim_result", "data": {"success": False, "error": "Invalid PID"}}
            )
            return

        inst = _parse_int(raw_inst, 1)
        adb_port: int | None = None
        instances = get_mumu_instances()
        if not pid and inst:
            m_inst = next(
                (x for x in instances if x.get("instance_index") == inst or x.get("index") == inst),
                None,
            )
            if m_inst:
                pid = _parse_int(m_inst.get("pid"), 5)
                if isinstance(m_inst.get("adb_port"), int) and m_inst["adb_port"] > 0:
                    adb_port = m_inst["adb_port"]
        elif pid:
            m_inst = next((x for x in instances if x.get("pid") == pid), None)
            if m_inst and isinstance(m_inst.get("adb_port"), int) and m_inst["adb_port"] > 0:
                adb_port = m_inst["adb_port"]
        if adb_port is None and inst is not None:
            adb_port = get_adb_port_for_instance(inst)
        if not pid:
            devs = [x for x in instances if x.get("type") == "Emulator"]
            if devs:
                pid = _parse_int(devs[0].get("pid"), 5)
                if adb_port is None and isinstance(devs[0].get("adb_port"), int) and devs[0]["adb_port"] > 0:
                    adb_port = devs[0]["adb_port"]
        if pid:
            fallback_fn = (lambda p=adb_port: trim_vm_caches(p)) if adb_port else None
            res = await asyncio.to_thread(trim_single_process, pid, fallback_fn)
            await manager.send_to(ws, {"type": "mumu_trim_result", "data": res})
        else:
            await manager.send_to(
                ws, {"type": "mumu_trim_result", "data": {"success": False, "error": "Instance PID not found"}}
            )

    elif cmd == "trim_process":
        raw_pid = data.get("pid")
        pid = 0
        if raw_pid is not None and not isinstance(raw_pid, bool):
            try:
                pid = int(raw_pid)
            except (TypeError, ValueError):
                pid = 0
        if pid <= 4:
            await manager.send_to(
                ws, {"type": "process_trim_result", "data": {"success": False, "pid": pid, "error": "Invalid PID"}}
            )
            return
        res = await asyncio.to_thread(trim_single_process, pid)
        if isinstance(res, dict):
            res.setdefault("pid", pid)
        await manager.send_to(ws, {"type": "process_trim_result", "data": res})

    elif cmd == "kill_process":
        raw_pid = data.get("pid")
        pid = 0
        if raw_pid is not None and not isinstance(raw_pid, bool):
            try:
                pid = int(raw_pid)
            except (TypeError, ValueError):
                pid = 0
        if pid <= 4:
            await manager.send_to(
                ws, {"type": "process_kill_result", "data": {"success": False, "pid": pid, "error": "Invalid PID"}}
            )
            return

        def _kill_proc_sync(target_pid: int) -> dict:
            try:
                proc = psutil.Process(target_pid)
                name = proc.name() or "Process"
                if name.lower() in get_protected_names():
                    return {"success": False, "pid": target_pid, "name": name, "error": f"{name} is protected"}
                proc.terminate()
                add_event("kill", f"Process killed: {name} (PID {target_pid})")
                return {"success": True, "pid": target_pid, "name": name}
            except psutil.NoSuchProcess:
                return {"success": False, "pid": target_pid, "error": "Process not found"}
            except psutil.AccessDenied:
                return {"success": False, "pid": target_pid, "error": "Access denied"}
            except Exception as exc:
                return {"success": False, "pid": target_pid, "error": str(exc)}

        res = await asyncio.to_thread(_kill_proc_sync, pid)
        await manager.send_to(ws, {"type": "process_kill_result", "data": res})

    elif cmd == "set_auto_rejoin":
        raw_inst = data.get("instance")
        inst_val: int | None
        if raw_inst is None:
            inst_val = None
        elif isinstance(raw_inst, bool):
            await manager.send_to(ws, {"type": "error", "error": "Invalid instance index"})
            return
        else:
            try:
                inst_val = int(raw_inst)
            except (TypeError, ValueError):
                await manager.send_to(ws, {"type": "error", "error": "Invalid instance index"})
                return
            if inst_val < 1:
                await manager.send_to(ws, {"type": "error", "error": "Invalid instance index"})
                return
        enabled = bool(data.get("enabled", True))
        res = await asyncio.to_thread(set_auto_rejoin, inst_val, enabled)
        await broadcast_event({"type": "auto_rejoin_updated", **res})

    elif cmd == "toggle_timer_resolution":
        enable = bool(data.get("enabled", True))
        res = await asyncio.to_thread(set_high_precision_timer, enable)
        await manager.send_to(ws, {"type": "timer_resolution_result", "data": res})

    elif cmd == "toggle_pcore_affinity":
        enable = bool(data.get("enabled", True))
        res = await asyncio.to_thread(apply_pcore_affinity_for_mumu, enable)
        await manager.send_to(ws, {"type": "pcore_affinity_result", "data": res})

    elif cmd == "flush_shader_cache":
        res = await asyncio.to_thread(scan_and_flush_shader_cache, False)
        await manager.send_to(ws, {"type": "shader_cache_result", "data": res})

    elif cmd == "scan_shader_cache":
        res = await asyncio.to_thread(scan_and_flush_shader_cache, True)
        await manager.send_to(ws, {"type": "shader_cache_status", "data": res})

    elif cmd == "governor_action":
        try:
            inst = int(data.get("instance", 1))
        except (TypeError, ValueError):
            await manager.send_to(ws, {"type": "error", "error": "Invalid instance index"})
            return
        act = str(data.get("action", "trim_ram"))
        res = await asyncio.to_thread(governor_instance_action, inst, act)
        await manager.send_to(ws, {"type": "governor_result", "data": res})

    elif cmd == "alerts_status":
        await manager.send_to(ws, {"type": "alerts_status", "data": notifier.get_status()})

    elif cmd == "alerts_history":
        await manager.send_to(ws, {"type": "alerts_history", "data": notifier.get_history()})

    elif cmd == "update_alerts_config":
        try:
            updates = data.get("alerts") if isinstance(data.get("alerts"), dict) else data
            await asyncio.to_thread(update_alerts_config, updates)
            status = notifier.get_status()
            await broadcast_event({"type": "alerts_status", "data": status})
            await manager.send_to(
                ws,
                {
                    "type": "alerts_config_updated",
                    "alerts": status,
                    "config": mask_config_for_client(CONFIG),
                },
            )
        except (TypeError, ValueError) as exc:
            await manager.send_to(ws, {"type": "error", "error": str(exc)})

    elif cmd == "test_discord_alert":
        res = await notifier.send_test_alert()
        await manager.send_to(ws, {"type": "alerts_test_result", **res})

    elif cmd == "restart_tunnel":
        res = await asyncio.to_thread(request_tunnel_restart)
        await manager.send_to(ws, {"type": "tunnel_restart_result", **res})

    elif cmd == "purge_discord_alerts":
        try:
            limit = int(data.get("limit", 100))
        except (TypeError, ValueError):
            limit = 100
        bot_only = bool(data.get("bot_only", False))
        res = await purge_discord_channel_messages(limit=limit, bot_only=bot_only)
        await manager.send_to(ws, {"type": "alerts_purge_result", **res})
