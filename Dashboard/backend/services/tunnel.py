import asyncio
import re
import subprocess
from datetime import datetime

from backend.core.config import CONFIG, DASHBOARD_DIR, DATA_DIR
from backend.core.events import add_event
from backend.services.discord_notifier import NotificationEvent, notifier

_tunnel_proc: subprocess.Popen | None = None
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
    state = dict(_tunnel_state)
    state["local_url"] = f"http://127.0.0.1:{port}"
    return state


def stop_tunnel_process() -> None:
    global _tunnel_proc
    if _tunnel_proc is not None:
        try:
            _tunnel_proc.terminate()
        except Exception:
            pass
        _tunnel_proc = None


async def tunnel_supervisor_loop() -> None:
    global _tunnel_proc
    tunnel_cfg = CONFIG.get("tunnel", {})
    provider = str(tunnel_cfg.get("provider", "ngrok")).lower()
    ngrok_token = str(tunnel_cfg.get("ngrok_authtoken", "") or "").strip()
    ngrok_domain = str(tunnel_cfg.get("ngrok_domain", "") or "").strip()
    port = int(CONFIG.get("server", {}).get("port", 7700))
    startup_alert_sent = False

    _tunnel_state["provider"] = provider
    _tunnel_state["local_url"] = f"http://127.0.0.1:{port}"

    if provider == "ngrok" and ngrok_token:
        try:
            import ngrok

            _tunnel_state["status"] = "connecting"
            forward_kwargs: dict = {"authtoken": ngrok_token}
            if ngrok_domain:
                forward_kwargs["domain"] = ngrok_domain

            listener = await ngrok.forward(port, **forward_kwargs)
            url = listener.url()
            _tunnel_state["tunnel_url"] = url
            _tunnel_state["status"] = "online"
            _tunnel_state["started_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            _tunnel_state["last_error"] = None

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

            while True:
                await asyncio.sleep(60)
        except asyncio.CancelledError:
            try:
                await listener.close()
            except Exception:
                pass
            _tunnel_state["status"] = "offline"
            return
        except Exception as exc:
            _tunnel_state["last_error"] = str(exc)
            print(f"[NGROK TUNNEL ERROR] {exc}. Falling back to Cloudflare Tunnel if available...")

    cloudflared_path = DASHBOARD_DIR / "cloudflared.exe"
    if not cloudflared_path.exists():
        _tunnel_state["provider"] = "local_only"
        _tunnel_state["status"] = "local_only"
        _tunnel_state["started_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
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
        return

    _tunnel_state["provider"] = "cloudflared"
    while True:
        try:
            _tunnel_state["status"] = "connecting"
            cmd = [str(cloudflared_path), "tunnel", "--url", f"http://127.0.0.1:{port}"]
            _tunnel_proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
            )

            while True:
                if _tunnel_proc.stderr is None:
                    break
                line = await asyncio.to_thread(_tunnel_proc.stderr.readline)
                if not line:
                    if _tunnel_proc.poll() is not None:
                        break
                    await asyncio.sleep(0.5)
                    continue

                m = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", line)
                if m:
                    url = m.group(0)
                    prev_url = _tunnel_state.get("tunnel_url")
                    if url != prev_url:
                        _tunnel_state["tunnel_url"] = url
                        _tunnel_state["status"] = "online"
                        _tunnel_state["started_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        _tunnel_state["last_error"] = None
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

            if _tunnel_state.get("status") == "online":
                _tunnel_state["status"] = "offline"
                notifier.enqueue(
                    NotificationEvent(
                        event_type="tunnel_change",
                        severity="warning",
                        title="Public Tunnel Disconnected",
                        description="Cloudflare tunnel process exited; attempting automatic reconnect.",
                        dedupe_key="tunnel_disconnect",
                    )
                )
            await asyncio.sleep(5)
        except asyncio.CancelledError:
            stop_tunnel_process()
            _tunnel_state["status"] = "offline"
            break
        except Exception as exc:
            _tunnel_state["last_error"] = str(exc)
            _tunnel_state["status"] = "offline"
            print(f"[TUNNEL ERROR] {exc}")
            await asyncio.sleep(5)
