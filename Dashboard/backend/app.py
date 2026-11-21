import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from backend.api.routes import FRONTEND_DIST_DIR, router
from backend.api.ws import broadcast_event, websocket_endpoint
from backend.core.config import CONFIG
from backend.core.events import add_event, set_event_broadcaster
from backend.services.discord_bot import discord_bot_service
from backend.services.discord_notifier import heartbeat_loop, notifier, run_auto_discord_purge
from backend.services.maintenance import (
    auto_boost_loop,
    autonomous_standby_loop,
    get_defender_status,
    maintenance_loop,
)
from backend.services.mumu_monitor import (
    mumu_game_watchdog_loop,
    process_sampler_loop,
    roblox_presence_tracker_loop,
)
from backend.services.telemetry import (
    chart_sampler_loop,
    cpu_sampler_loop,
    roblox_ping_sampler_loop,
)
from backend.services.tunnel import stop_tunnel_process, tunnel_supervisor_loop
from backend.services.win32_ops import (
    apply_pcore_affinity_for_mumu,
    set_high_precision_timer,
)


@asynccontextmanager
async def lifespan(fastapi_app: FastAPI):
    loop = asyncio.get_running_loop()
    set_event_broadcaster(loop, broadcast_event)
    notifier.start(loop)
    discord_bot_service.start(loop)

    tasks = [
        asyncio.create_task(cpu_sampler_loop()),
        asyncio.create_task(roblox_ping_sampler_loop()),
        asyncio.create_task(process_sampler_loop()),
        asyncio.create_task(chart_sampler_loop()),
        asyncio.create_task(mumu_game_watchdog_loop()),
        asyncio.create_task(roblox_presence_tracker_loop()),
        asyncio.create_task(auto_boost_loop()),
        asyncio.create_task(autonomous_standby_loop()),
        asyncio.create_task(maintenance_loop()),
        asyncio.create_task(heartbeat_loop()),
        asyncio.create_task(tunnel_supervisor_loop()),
    ]

    try:
        await asyncio.to_thread(set_high_precision_timer, True)
        await asyncio.to_thread(apply_pcore_affinity_for_mumu, True)
    except Exception:
        pass

    asyncio.create_task(asyncio.to_thread(get_defender_status))
    asyncio.create_task(run_auto_discord_purge(on_startup=True))
    add_event("system", "Genesis Autonomous Core started (0.5ms Timer & P-Core Lock Active)")

    try:
        yield
    finally:
        for task in tasks:
            task.cancel()
        for task in tasks:
            try:
                await task
            except asyncio.CancelledError:
                pass
            except Exception:
                pass
        await discord_bot_service.stop()
        await notifier.stop()
        stop_tunnel_process()
        set_event_broadcaster(None, None)
        add_event("system", "Genesis Autonomous Core stopped")


def create_app() -> FastAPI:
    application = FastAPI(title="Genesis Dashboard", version="3.0.0", lifespan=lifespan)

    assets_dir = FRONTEND_DIST_DIR / "assets"
    if assets_dir.exists():
        application.mount("/assets", StaticFiles(directory=str(assets_dir)), name="assets")

    application.include_router(router)
    application.add_api_websocket_route("/ws", websocket_endpoint)
    return application


app = create_app()


def run() -> None:
    import uvicorn

    host = str(CONFIG.get("server", {}).get("host", "127.0.0.1"))
    port = int(CONFIG.get("server", {}).get("port", 7700))
    print(f"\n{'=' * 50}")
    print("  GENESIS AUTONOMOUS CORE -- System Supervisor")
    print(f"  Local Ingress: http://{host}:{port}")
    print(f"{'=' * 50}\n")
    uvicorn.run(app, host=host, port=port, log_level="info")
