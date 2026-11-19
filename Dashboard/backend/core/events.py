import asyncio
import json
import os
import threading
import time
from datetime import datetime
from typing import Awaitable, Callable

from backend.core.config import DATA_DIR, HISTORY_PATH

MAX_HISTORY = 5000

_history_lock = threading.RLock()
_main_event_loop: asyncio.AbstractEventLoop | None = None
_broadcaster_fn: Callable[[dict], Awaitable[None]] | None = None


def _load_history() -> list[dict]:
    if HISTORY_PATH.exists():
        try:
            with open(HISTORY_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data[-MAX_HISTORY:]
        except Exception:
            return []
    return []


def _save_history(events: list[dict]) -> None:
    try:
        tmp_path = DATA_DIR / "history.json.tmp"
        with open(tmp_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(events[-MAX_HISTORY:], f, indent=2, ensure_ascii=False)
        os.replace(tmp_path, HISTORY_PATH)
    except Exception as exc:
        print(f"[ERROR] Failed to save history.json: {exc}")


event_history: list[dict] = _load_history()


def set_event_broadcaster(
    loop: asyncio.AbstractEventLoop | None,
    broadcaster_fn: Callable[[dict], Awaitable[None]] | None,
) -> None:
    global _main_event_loop, _broadcaster_fn
    _main_event_loop = loop
    _broadcaster_fn = broadcaster_fn


def broadcast_payload_threadsafe(payload: dict) -> None:
    loop = _main_event_loop
    broadcaster = _broadcaster_fn
    if loop is None or broadcaster is None or not loop.is_running():
        return
    try:
        asyncio.run_coroutine_threadsafe(broadcaster(payload), loop)
    except Exception:
        pass


def add_event(event_type: str, message: str) -> dict:
    entry = {
        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "epoch": time.time(),
        "type": event_type,
        "message": message,
    }
    with _history_lock:
        event_history.append(entry)
        if len(event_history) > MAX_HISTORY:
            del event_history[: len(event_history) - MAX_HISTORY]
        _save_history(event_history)

    broadcast_payload_threadsafe({"type": "event", "event": entry})
    return entry


def get_recent_events(limit: int = 50, newest_first: bool = False) -> list[dict]:
    with _history_lock:
        sliced = list(event_history[-limit:])
    if newest_first:
        sliced.reverse()
    return sliced


def get_all_events_snapshot() -> list[dict]:
    with _history_lock:
        return list(event_history)


def purge_boost_events() -> None:
    with _history_lock:
        event_history[:] = [e for e in event_history if e.get("type") != "boost"]
        _save_history(event_history)
