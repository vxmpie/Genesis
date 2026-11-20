import asyncio
import re
import subprocess
import threading
from datetime import datetime

from backend.core.config import CONFIG, DASHBOARD_DIR, DATA_DIR
from backend.core.events import add_event, broadcast_payload_threadsafe
from backend.services.discord_notifier import NotificationEvent, notifier

_CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)

_tunnel_lock = threading.RLock()
_tunnel_proc: subprocess.Popen | None = None
_restart_event: asyncio.Event | None = None
_supervisor_loop: asyncio.AbstractEventLoop | None = None
_tunnel_state: dict = {
    "provider": "none",
    "status": "initializing",
    "tunnel_url": None,
    "local_url": "http://127.0.0.1:7700",
    "started_at": None,
    "last_error": None,
}


def get_tunnel_status() -> dict:
    port = int(CONFIG.get("server", {}).get("port", 7700))
    with _tunnel_lock:
        state = dict(_tunnel_state)
    state["local_url"] = f"http://127.0.0.1:{port}"
    return state


def _update_tunnel_state(broadcast: bool = False, **updates: object) -> dict:
    port = int(CONFIG.get("server", {}).get("port", 7700))
    with _tunnel_lock:
        _tunnel_state.update(updates)
        state = dict(_tunnel_state)
    state["local_url"] = f"http://127.0.0.1:{port}"
    if broadcast:
        broadcast_payload_threadsafe({"type": "tunnel_status", "data": state})
    return state


def stop_tunnel_process() -> None:
    global _tunnel_proc
    with _tunnel_lock:
        proc = _tunnel_proc
        _tunnel_proc = None
    if proc is not None:
        try:
            proc.terminate()
        except Exception:
            pass


def _detect_tailscale_serve_url(configured_url: str = "") -> str | None:
    clean = (configured_url or "").strip().rstrip("/")
    if clean.startswith(("https://", "http://")):
        return clean
    try:
        r = subprocess.run(
            ["tailscale", "serve", "status"],
            capture_output=True,
            text=True,
            timeout=5,
            creationflags=_CREATE_NO_WINDOW,
        )
        if r.returncode == 0 and r.stdout:
            m = re.search(r"https://[a-zA-Z0-9.-]+\.ts\.net", r.stdout)
            if m:
                return m.group(0)
    except Exception:
        pass
    return None


# --- Tunnel Restart Control ---
def request_tunnel_restart() -> dict:
    tunnel_cfg = CONFIG.get("tunnel", {})
    provider = str(tunnel_cfg.get("provider", "ngrok")).lower().strip()
    if provider in ("local_only", "none", "disabled"):
        return {
            "ok": False,
            "error": "Tunnel is running in local-only mode",
            "tunnel": get_tunnel_status(),
        }

    ngrok_token = str(tunnel_cfg.get("ngrok_authtoken", "") or "").strip()
    has_ngrok = provider == "ngrok" and bool(ngrok_token)
    has_tailscale = provider == "tailscale"
    has_cloudflared = (DASHBOARD_DIR / "cloudflared.exe").exists()

    if not has_ngrok and not has_tailscale and not has_cloudflared:
        return {
            "ok": False,
            "error": "Tunnel is running in local-only mode",
            "tunnel": get_tunnel_status(),
        }

    with _tunnel_lock:
        if _tunnel_state.get("status") == "restarting":
            return {
                "ok": False,
                "error": "Tunnel restart already in progress",
                "tunnel": get_tunnel_status(),
            }
        snapshot = _update_tunnel_state(
            broadcast=True,
            status="restarting",
            tunnel_url=None,
            last_error=None,
        )
        loop = _supervisor_loop
        event = _restart_event

    stop_tunnel_process()

    if loop is not None and loop.is_running() and event is not None:
        loop.call_soon_threadsafe(event.set)

    add_event("system", "Public tunnel restart requested")
    return {"ok": True, "tunnel": snapshot}


async def _sleep_or_restart(restart_event: asyncio.Event, delay_sec: float) -> bool:
    try:
        await asyncio.wait_for(restart_event.wait(), timeout=delay_sec)
        return True
    except asyncio.TimeoutError:
        return False


# --- Supervisor Loop ---
async def tunnel_supervisor_loop() -> None:
    global _tunnel_proc, _restart_event, _supervisor_loop
    _supervisor_loop = asyncio.get_running_loop()
    _restart_event = asyncio.Event()
    startup_alert_sent = False

    while True:
        tunnel_cfg = CONFIG.get("tunnel", {})
        provider = str(tunnel_cfg.get("provider", "ngrok")).lower().strip()
        ngrok_token = str(tunnel_cfg.get("ngrok_authtoken", "") or "").strip()
        ngrok_domain = str(tunnel_cfg.get("ngrok_domain", "") or "").strip()
        tailscale_cfg_url = str(tunnel_cfg.get("tailscale_url", "") or "").strip()
        port = int(CONFIG.get("server", {}).get("port", 7700))

        _update_tunnel_state(provider=provider)

        if provider in ("local_only", "none", "disabled"):
            _update_tunnel_state(
                broadcast=True,
                provider="local_only",
                status="local_only",
                tunnel_url=None,
                started_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                last_error=None,
            )
            if not startup_alert_sent:
                startup_alert_sent = True
                notifier.enqueue(
                    NotificationEvent(
                        event_type="startup",
                        severity="info",
                        title="Genesis Autonomous Core Online (Local Only)",
                        description="System supervisor initialized without public tunnel.",
                        dedupe_key="startup_online",
                        fields=[
                            {"name": "Local Host", "value": f"http://127.0.0.1:{port}", "inline": True},
                            {"name": "Watchdog", "value": "Armed", "inline": True},
                            {"name": "Started At", "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "inline": True},
                        ],
                    )
                )
            try:
                await _restart_event.wait()
                _restart_event.clear()
                continue
            except asyncio.CancelledError:
                _update_tunnel_state(broadcast=True, status="offline")
                return

        if provider == "tailscale":
            _update_tunnel_state(broadcast=True, provider="tailscale", status="connecting")
            ts_url = await asyncio.to_thread(_detect_tailscale_serve_url, tailscale_cfg_url)
            if ts_url:
                with _tunnel_lock:
                    prev_url = _tunnel_state.get("tunnel_url")
                _update_tunnel_state(
                    broadcast=True,
                    provider="tailscale",
                    tunnel_url=ts_url,
                    status="online",
                    started_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    last_error=None,
                )
                try:
                    (DATA_DIR / "tunnel_url.txt").write_text(ts_url, encoding="utf-8")
                except Exception:
                    pass
                add_event("system", f"Tailscale Private HTTPS Tunnel active: {ts_url}")
                if not startup_alert_sent:
                    startup_alert_sent = True
                    notifier.enqueue(
                        NotificationEvent(
                            event_type="startup",
                            severity="info",
                            title="Genesis Autonomous Core Online (Tailscale Serve)",
                            description="System supervisor initialized with private Tailscale HTTPS ingress.",
                            dedupe_key="startup_online",
                            fields=[
                                {"name": "Tailscale URL", "value": f"[Open Dashboard]({ts_url})\n`{ts_url}`", "inline": False},
                                {"name": "Local Host", "value": f"http://127.0.0.1:{port}", "inline": True},
                                {"name": "Watchdog", "value": "Armed", "inline": True},
                                {"name": "Started At", "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "inline": True},
                            ],
                        )
                    )
                elif prev_url != ts_url:
                    notifier.enqueue(
                        NotificationEvent(
                            event_type="tunnel_change",
                            severity="recovery",
                            title="Tailscale Tunnel Updated",
                            description=f"Tailscale Serve HTTPS active at:\n`{ts_url}`",
                            dedupe_key=f"tunnel_change:{ts_url}",
                        )
                    )
                try:
                    await _restart_event.wait()
                    _restart_event.clear()
                    _update_tunnel_state(broadcast=True, status="restarting", tunnel_url=None)
                    continue
                except asyncio.CancelledError:
                    _update_tunnel_state(broadcast=True, status="offline")
                    return

            _update_tunnel_state(
                broadcast=True,
                provider="tailscale",
                status="offline",
                tunnel_url=None,
                last_error="Tailscale Serve URL not detected (run: tailscale serve --bg http://127.0.0.1:7700)",
            )
            try:
                if await _sleep_or_restart(_restart_event, 30.0):
                    _restart_event.clear()
                continue
            except asyncio.CancelledError:
                _update_tunnel_state(broadcast=True, status="offline")
                return

        if provider == "ngrok" and ngrok_token:
            listener = None
            try:
                import ngrok

                _update_tunnel_state(broadcast=True, status="connecting")
                forward_kwargs: dict = {"authtoken": ngrok_token}
                if ngrok_domain:
                    forward_kwargs["domain"] = ngrok_domain

                listener = await ngrok.forward(port, **forward_kwargs)
                url = listener.url()
                with _tunnel_lock:
                    prev_url = _tunnel_state.get("tunnel_url")
                _update_tunnel_state(
                    broadcast=True,
                    tunnel_url=url,
                    status="online",
                    started_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                    last_error=None,
                )

                try:
                    (DATA_DIR / "tunnel_url.txt").write_text(url, encoding="utf-8")
                except Exception:
                    pass

                add_event("system", f"Permanent ngrok Public Tunnel active: {url}")
                if not startup_alert_sent:
                    startup_alert_sent = True
                    notifier.enqueue(
                        NotificationEvent(
                            event_type="startup",
                            severity="info",
                            title="Genesis Autonomous Core Online (Permanent Domain)",
                            description="System supervisor initialized. Monitoring, memory guard, and watchdog active.",
                            dedupe_key="startup_online",
                            fields=[
                                {"name": "Public URL", "value": f"[Open Dashboard]({url})\n`{url}`", "inline": False},
                                {"name": "Local Host", "value": f"http://127.0.0.1:{port}", "inline": True},
                                {"name": "Watchdog", "value": "Armed", "inline": True},
                                {"name": "Started At", "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "inline": True},
                            ],
                        )
                    )
                elif prev_url != url:
                    notifier.enqueue(
                        NotificationEvent(
                            event_type="tunnel_change",
                            severity="recovery",
                            title="Public Tunnel Reconnected",
                            description=f"ngrok tunnel active at:\n`{url}`",
                            dedupe_key=f"tunnel_change:{url}",
                        )
                    )

                await _restart_event.wait()
                _restart_event.clear()
                _update_tunnel_state(broadcast=True, status="restarting", tunnel_url=None)
                continue
            except asyncio.CancelledError:
                _update_tunnel_state(broadcast=True, status="offline")
                return
            except Exception as exc:
                _update_tunnel_state(broadcast=True, last_error=str(exc), status="offline")
                print(f"[NGROK TUNNEL ERROR] {exc}. Falling back to Cloudflare Tunnel if available...")
            finally:
                if listener is not None:
                    try:
                        await listener.close()
                    except Exception:
                        pass

        cloudflared_path = DASHBOARD_DIR / "cloudflared.exe"
        if not cloudflared_path.exists():
            _update_tunnel_state(
                broadcast=True,
                provider="local_only",
                status="local_only",
                tunnel_url=None,
                started_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            )
            if not startup_alert_sent:
                startup_alert_sent = True
                notifier.enqueue(
                    NotificationEvent(
                        event_type="startup",
                        severity="info",
                        title="Genesis Autonomous Core Online (Local Only)",
                        description="System supervisor initialized without public tunnel.",
                        dedupe_key="startup_online",
                        fields=[
                            {"name": "Local Host", "value": f"http://127.0.0.1:{port}", "inline": True},
                            {"name": "Watchdog", "value": "Armed", "inline": True},
                            {"name": "Started At", "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "inline": True},
                        ],
                    )
                )
            try:
                await _restart_event.wait()
                _restart_event.clear()
                continue
            except asyncio.CancelledError:
                _update_tunnel_state(broadcast=True, status="offline")
                return

        _update_tunnel_state(provider="cloudflared")
        restarting_outer = False
        while True:
            try:
                if _restart_event.is_set():
                    _restart_event.clear()
                    _update_tunnel_state(broadcast=True, status="restarting", tunnel_url=None)
                    restarting_outer = True
                    break

                _update_tunnel_state(broadcast=True, status="connecting")
                cmd = [str(cloudflared_path), "tunnel", "--url", f"http://127.0.0.1:{port}"]
                new_proc = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    bufsize=1,
                    creationflags=_CREATE_NO_WINDOW,
                )
                with _tunnel_lock:
                    _tunnel_proc = new_proc

                while True:
                    with _tunnel_lock:
                        proc = _tunnel_proc
                        stderr = proc.stderr if proc is not None else None
                    if proc is None or stderr is None:
                        break
                    line = await asyncio.to_thread(stderr.readline)
                    if not line:
                        if proc.poll() is not None:
                            break
                        await asyncio.sleep(0.5)
                        continue

                    m = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", line)
                    if m:
                        url = m.group(0)
                        with _tunnel_lock:
                            prev_url = _tunnel_state.get("tunnel_url")
                        if url != prev_url:
                            _update_tunnel_state(
                                broadcast=True,
                                tunnel_url=url,
                                status="online",
                                started_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                                last_error=None,
                            )
                            try:
                                (DATA_DIR / "tunnel_url.txt").write_text(url, encoding="utf-8")
                            except Exception:
                                pass
                            add_event("system", f"Cloudflare Public Tunnel active: {url}")

                            if not startup_alert_sent:
                                startup_alert_sent = True
                                notifier.enqueue(
                                    NotificationEvent(
                                        event_type="startup",
                                        severity="info",
                                        title="Genesis Autonomous Core Online",
                                        description="System supervisor initialized with Cloudflare Tunnel.",
                                        dedupe_key="startup_online",
                                        fields=[
                                            {"name": "Public Access URL", "value": f"[Open Dashboard]({url})\n`{url}`", "inline": False},
                                            {"name": "Local Host", "value": f"http://127.0.0.1:{port}", "inline": True},
                                            {"name": "Watchdog", "value": "Armed", "inline": True},
                                            {"name": "Started At", "value": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "inline": True},
                                        ],
                                    )
                                )
                            else:
                                notifier.enqueue(
                                    NotificationEvent(
                                        event_type="tunnel_change",
                                        severity="recovery",
                                        title="Public Tunnel Reconnected",
                                        description=f"Cloudflare tunnel assigned a new URL:\n`{url}`",
                                        dedupe_key=f"tunnel_change:{url}",
                                    )
                                )

                if _restart_event.is_set():
                    stop_tunnel_process()
                    _restart_event.clear()
                    _update_tunnel_state(broadcast=True, status="restarting", tunnel_url=None)
                    restarting_outer = True
                    break

                with _tunnel_lock:
                    was_online = _tunnel_state.get("status") == "online"
                if was_online:
                    _update_tunnel_state(broadcast=True, status="offline")
                    notifier.enqueue(
                        NotificationEvent(
                            event_type="tunnel_change",
                            severity="warning",
                            title="Public Tunnel Disconnected",
                            description="Cloudflare tunnel process exited; attempting automatic reconnect.",
                            dedupe_key="tunnel_disconnect",
                        )
                    )
                if await _sleep_or_restart(_restart_event, 5.0):
                    _restart_event.clear()
                    _update_tunnel_state(broadcast=True, status="restarting", tunnel_url=None)
                    restarting_outer = True
                    break
            except asyncio.CancelledError:
                stop_tunnel_process()
                _update_tunnel_state(broadcast=True, status="offline")
                return
            except Exception as exc:
                _update_tunnel_state(broadcast=True, last_error=str(exc), status="offline")
                print(f"[TUNNEL ERROR] {exc}")
                if await _sleep_or_restart(_restart_event, 5.0):
                    _restart_event.clear()
                    _update_tunnel_state(broadcast=True, status="restarting", tunnel_url=None)
                    restarting_outer = True
                    break

        if restarting_outer:
            continue
        return
