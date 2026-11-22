import asyncio
import json
import socket
import threading
import time
import urllib.error
import urllib.request
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Awaitable, Callable, Literal

from backend.core.config import CONFIG, get_masked_alerts_status, mask_secret_url
from backend.core.events import add_event, broadcast_payload_threadsafe

Severity = Literal["critical", "warning", "recovery", "info"]

SEVERITY_STYLES: dict[str, tuple[int, str, str]] = {
    "critical": (0xEF4444, "CRITICAL", ":red_circle:"),
    "warning": (0xF59E0B, "WARNING", ":warning:"),
    "recovery": (0x10B981, "RESOLVED", ":white_check_mark:"),
    "info": (0x3B82F6, "INFO", ":green_circle:"),
}

EVENT_ICON_SHORTCODES: dict[str, str] = {
    "startup": ":green_circle:",
    "mumu_crash": ":red_circle:",
    "watchdog_recovery": ":arrows_counterclockwise:",
    "ram_critical": ":warning:",
    "vm_disk_critical": ":warning:",
    "drift": ":shield:",
    "net_outage": ":white_check_mark:",
    "auto_clean": ":broom:",
    "test": ":wrench:",
}

EVENT_TOGGLE_MAP: dict[str, str] = {
    "startup": "notify_on_startup",
    "mumu_crash": "notify_on_mumu_crash",
    "watchdog_recovery": "notify_on_watchdog_recovery",
    "ram_critical": "notify_on_ram_critical",
    "vm_disk_critical": "notify_on_vm_disk_critical",
    "drift": "notify_on_drift",
    "tunnel_change": "notify_on_tunnel_change",
    "net_outage": "notify_on_net_outage",
    "auto_clean": "notify_on_auto_clean",
}


def _utc_iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sanitize_error_text(text: str, webhook_url: str = "") -> str:
    clean = str(text or "")
    if not clean:
        return ""
    if webhook_url:
        masked = mask_secret_url(webhook_url)
        clean = clean.replace(webhook_url, masked)
    import re
    clean = re.sub(
        r"https?://(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/[^\s\"'<>]+",
        lambda m: mask_secret_url(m.group(0)),
        clean,
        flags=re.IGNORECASE,
    )
    return clean[:200]


@dataclass
class NotificationEvent:
    event_type: str
    severity: Severity
    title: str
    description: str
    dedupe_key: str
    fields: list[dict[str, object]] = field(default_factory=list)
    bypass_cooldown: bool = False
    bypass_toggle: bool = False
    timestamp_utc: str = field(default_factory=_utc_iso_now)


def build_embed_payload(event: NotificationEvent) -> dict:
    color, prefix, fallback_icon = SEVERITY_STYLES.get(event.severity, (0x3B82F6, "INFO", ":green_circle:"))
    if event.event_type == "tunnel_change":
        icon = ":red_circle:" if event.severity == "warning" else ":globe_with_meridians:"
    else:
        icon = EVENT_ICON_SHORTCODES.get(event.event_type, fallback_icon)

    clean_title = event.title.strip()
    tag = f"[{prefix}]"
    base_title = clean_title if clean_title.startswith("[") else f"{tag} {clean_title}"
    formatted_title = base_title if base_title.startswith(":") else f"{icon} {base_title}"

    host_label = socket.gethostname()
    return {
        "username": "Genesis Operations Core",
        "embeds": [
            {
                "title": formatted_title,
                "description": event.description,
                "color": color,
                "fields": event.fields,
                "footer": {"text": f"Genesis Core | Host: {host_label}"},
                "timestamp": event.timestamp_utc,
            }
        ],
    }


def _default_http_sender(webhook_url: str, payload: dict) -> tuple[int, dict[str, str], str]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Genesis-Operations-Core/3.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            headers = {k.lower(): v for k, v in resp.headers.items()}
            body = resp.read().decode("utf-8", errors="ignore")
            return resp.status, headers, body
    except urllib.error.HTTPError as http_err:
        headers = {k.lower(): v for k, v in http_err.headers.items()} if http_err.headers else {}
        body = http_err.read().decode("utf-8", errors="ignore") if http_err.fp else ""
        return http_err.code, headers, body
    except Exception as exc:
        return 0, {}, str(exc)


def _extract_retry_after(headers: dict[str, str], body: str, fallback: float) -> float:
    header_val = headers.get("retry-after") or headers.get("x-ratelimit-reset-after")
    if header_val:
        try:
            return max(0.0, min(60.0, float(header_val)))
        except ValueError:
            pass
    if body:
        try:
            parsed = json.loads(body)
            if isinstance(parsed, dict) and "retry_after" in parsed:
                return max(0.0, min(60.0, float(parsed["retry_after"])))
        except Exception:
            pass
    return fallback


class DiscordNotifier:
    def __init__(
        self,
        config_provider: Callable[[], dict] | None = None,
        http_sender: Callable[[str, dict], tuple[int, dict[str, str], str]] | None = None,
        event_logger: Callable[[str, str], object] | None = None,
        broadcaster: Callable[[dict], None] | None = None,
        clock: Callable[[], float] | None = None,
        sleep_fn: Callable[[float], Awaitable[None]] | None = None,
        retry_base_delay: float = 1.0,
        max_attempts: int = 3,
    ) -> None:
        self._config_provider = config_provider or (lambda: CONFIG)
        self._http_sender = http_sender or _default_http_sender
        self._event_logger = event_logger or add_event
        self._broadcaster = broadcaster or broadcast_payload_threadsafe
        self._clock = clock or time.time
        self._sleep = sleep_fn or asyncio.sleep
        self._retry_base_delay = retry_base_delay
        self._max_attempts = max_attempts

        self._lock = threading.Lock()
        self._last_sent_by_key: dict[str, float] = {}
        self._last_suppressed_by_key: dict[tuple[str, str], float] = {}
        self._history: deque[dict] = deque(maxlen=50)
        self._seq = 0
        self._queue: asyncio.Queue[NotificationEvent] | None = None
        self._worker_task: asyncio.Task | None = None
        self._loop: asyncio.AbstractEventLoop | None = None
        self._delivered_count = 0
        self._failed_count = 0
        self._suppressed_count = 0

    def start(self, loop: asyncio.AbstractEventLoop | None = None) -> None:
        running_loop = loop or asyncio.get_running_loop()
        self._loop = running_loop
        if self._queue is None:
            self._queue = asyncio.Queue()
        if self._worker_task is None or self._worker_task.done():
            self._worker_task = running_loop.create_task(self._worker_loop())

    async def stop(self) -> None:
        if self._worker_task and not self._worker_task.done():
            self._worker_task.cancel()
            try:
                await self._worker_task
            except asyncio.CancelledError:
                pass
        self._worker_task = None

    def _record_entry(
        self,
        event: NotificationEvent,
        status: str,
        http_status: int | None = None,
        attempts: int = 0,
        error: str = "",
    ) -> dict:
        with self._lock:
            self._seq += 1
            if status == "delivered":
                self._delivered_count += 1
            elif status == "failed":
                self._failed_count += 1
            elif status == "suppressed":
                self._suppressed_count += 1

            entry = {
                "id": self._seq,
                "event_type": event.event_type,
                "severity": event.severity,
                "title": event.title,
                "dedupe_key": event.dedupe_key,
                "status": status,
                "http_status": http_status,
                "attempts": attempts,
                "error": error[:200] if error else "",
                "timestamp": _utc_iso_now(),
            }
            self._history.appendleft(entry)

        if self._broadcaster:
            self._broadcaster({"type": "alerts_delivery", "entry": entry})
        return entry

    def _can_send_event(self, event: NotificationEvent) -> tuple[bool, str, str]:
        cfg = self._config_provider()
        alerts_cfg = cfg.get("alerts", {})
        webhook_url = str(alerts_cfg.get("discord_webhook_url", "") or "").strip()
        if not webhook_url:
            return False, "", "Webhook URL not configured"

        if not event.bypass_toggle:
            toggle_key = EVENT_TOGGLE_MAP.get(event.event_type)
            if toggle_key and not bool(alerts_cfg.get(toggle_key, True)):
                return False, webhook_url, f"Disabled by {toggle_key}"

        if not event.bypass_cooldown:
            min_interval = max(1, int(alerts_cfg.get("min_alert_interval_seconds", 60)))
            now = self._clock()
            with self._lock:
                last_ts = self._last_sent_by_key.get(event.dedupe_key)
                if last_ts is not None and (now - last_ts) < min_interval:
                    return False, webhook_url, f"Cooldown active for {event.dedupe_key}"
                self._last_sent_by_key[event.dedupe_key] = now

        return True, webhook_url, ""

    def enqueue(self, event: NotificationEvent) -> bool:
        allowed, _url, reason = self._can_send_event(event)
        if not allowed:
            now = self._clock()
            cfg = self._config_provider()
            min_interval = max(1, int(cfg.get("alerts", {}).get("min_alert_interval_seconds", 60)))
            supp_key = (event.dedupe_key, reason)
            should_record = False
            with self._lock:
                last_supp = self._last_suppressed_by_key.get(supp_key)
                if last_supp is None or (now - last_supp) >= min_interval:
                    self._last_suppressed_by_key[supp_key] = now
                    should_record = True
                else:
                    self._suppressed_count += 1
            if should_record:
                self._record_entry(event, status="suppressed", error=reason)
            return False

        if self._queue is None:
            self._queue = asyncio.Queue()
        self._queue.put_nowait(event)
        return True

    def notify_sync(self, event: NotificationEvent) -> bool:
        loop = self._loop
        if loop is not None and loop.is_running():
            loop.call_soon_threadsafe(self.enqueue, event)
            return True
        return self.enqueue(event)

    async def _worker_loop(self) -> None:
        assert self._queue is not None
        while True:
            try:
                event = await self._queue.get()
                try:
                    alerts_cfg = self._config_provider().get("alerts", {})
                    webhook_url = str(alerts_cfg.get("discord_webhook_url", "") or "").strip()
                    if not webhook_url:
                        self._record_entry(event, status="suppressed", error="Webhook URL not configured")
                    else:
                        await self._deliver_with_retry(event, webhook_url)
                finally:
                    self._queue.task_done()
            except asyncio.CancelledError:
                break
            except Exception as exc:
                self._event_logger("error", f"Discord worker error: {exc}")

    async def _deliver_with_retry(self, event: NotificationEvent, webhook_url: str) -> dict:
        payload = build_embed_payload(event)
        last_status = 0
        last_error = ""

        for attempt in range(1, self._max_attempts + 1):
            status_code, headers, body = await asyncio.to_thread(
                self._http_sender, webhook_url, payload
            )
            last_status = status_code

            if 200 <= status_code < 300:
                return self._record_entry(
                    event,
                    status="delivered",
                    http_status=status_code,
                    attempts=attempt,
                )

            if status_code == 429:
                last_error = "Rate limited (HTTP 429)"
                if attempt < self._max_attempts:
                    wait_sec = _extract_retry_after(
                        headers, body, self._retry_base_delay * (2 ** (attempt - 1))
                    )
                    await self._sleep(wait_sec)
                    continue
                break

            if 400 <= status_code < 500:
                safe_body = sanitize_error_text(body, webhook_url)
                last_error = f"HTTP {status_code}: {safe_body[:140]}".strip(": ")
                break

            safe_body = sanitize_error_text(body, webhook_url)
            last_error = safe_body[:140] if safe_body else f"HTTP {status_code or 'network error'}"
            if attempt < self._max_attempts:
                await self._sleep(self._retry_base_delay * (2 ** (attempt - 1)))

        last_error = sanitize_error_text(last_error, webhook_url)
        entry = self._record_entry(
            event,
            status="failed",
            http_status=last_status,
            attempts=self._max_attempts if last_status in (0, 429) or last_status >= 500 else 1,
            error=last_error,
        )
        self._event_logger("error", f"Discord delivery failed ({event.title}): {last_error}")
        return entry

    async def send_test_alert(self) -> dict:
        cfg = self._config_provider()
        webhook_url = str(cfg.get("alerts", {}).get("discord_webhook_url", "") or "").strip()
        event = NotificationEvent(
            event_type="test",
            severity="info",
            title="Genesis Alert Pipeline Test",
            description="Verification alert dispatched manually from Genesis Operations Core.",
            dedupe_key=f"test:{int(self._clock())}",
            fields=[
                {"name": "Delivery Mode", "value": "Direct Test (Cooldown Bypassed)", "inline": True},
                {"name": "Timestamp UTC", "value": _utc_iso_now(), "inline": True},
            ],
            bypass_cooldown=True,
            bypass_toggle=True,
        )
        if not webhook_url:
            entry = self._record_entry(event, status="failed", error="Webhook URL not configured")
            return {"ok": False, "error": "Webhook URL not configured", "entry": entry}

        entry = await self._deliver_with_retry(event, webhook_url)
        return {
            "ok": entry["status"] == "delivered",
            "http_status": entry.get("http_status"),
            "error": entry.get("error", ""),
            "entry": entry,
        }

    def get_history(self) -> list[dict]:
        with self._lock:
            return list(self._history)

    def get_status(self) -> dict:
        cfg = self._config_provider()
        status = get_masked_alerts_status(cfg)
        with self._lock:
            status["queue_size"] = self._queue.qsize() if self._queue else 0
            status["delivered_count"] = self._delivered_count
            status["failed_count"] = self._failed_count
            status["suppressed_count"] = self._suppressed_count
        return status


notifier = DiscordNotifier()


async def heartbeat_loop() -> None:
    while True:
        try:
            alerts_cfg = CONFIG.get("alerts", {})
            hb_url = str(alerts_cfg.get("heartbeat_url", "") or "").strip()
            interval_min = max(1, int(alerts_cfg.get("heartbeat_interval_minutes", 5)))
            if hb_url:
                try:
                    await asyncio.to_thread(lambda: urllib.request.urlopen(hb_url, timeout=10).close())
                except Exception as exc:
                    print(f"[HEARTBEAT ERROR] {exc}")
            await asyncio.sleep(max(60, interval_min * 60))
        except asyncio.CancelledError:
            break
        except Exception:
            await asyncio.sleep(60)


# --- Discord Bot Channel Purge (REST API v10) ---
DISCORD_API_BASE = "https://discord.com/api/v10"
DISCORD_EPOCH_MS = 1420070400000
BULK_DELETE_MAX_AGE_SEC = (14 * 86400) - 60


def snowflake_timestamp_sec(snowflake_id: str) -> float:
    return ((int(snowflake_id) >> 22) + DISCORD_EPOCH_MS) / 1000.0


def _default_bot_http_request(
    method: str,
    url: str,
    bot_token: str,
    payload: dict | None = None,
) -> tuple[int, dict[str, str], str]:
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {
        "Authorization": f"Bot {bot_token}",
        "User-Agent": "Genesis-Operations-Core/3.0",
    }
    if data is not None:
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            resp_headers = {k.lower(): v for k, v in resp.headers.items()}
            body = resp.read().decode("utf-8", errors="ignore")
            return resp.status, resp_headers, body
    except urllib.error.HTTPError as http_err:
        resp_headers = {k.lower(): v for k, v in http_err.headers.items()} if http_err.headers else {}
        body = http_err.read().decode("utf-8", errors="ignore") if http_err.fp else ""
        return http_err.code, resp_headers, body
    except Exception as exc:
        return 0, {}, str(exc)


async def _bot_request_with_429(
    method: str,
    url: str,
    bot_token: str,
    payload: dict | None,
    bot_http_fn: Callable[[str, str, str, dict | None], tuple[int, dict[str, str], str]],
    sleep_fn: Callable[[float], Awaitable[None]],
    max_retries: int = 3,
) -> tuple[int, dict[str, str], str]:
    for attempt in range(max_retries):
        status, headers, body = await asyncio.to_thread(bot_http_fn, method, url, bot_token, payload)
        if status == 429 and attempt < max_retries - 1:
            wait_sec = _extract_retry_after(headers, body, 1.5)
            await sleep_fn(wait_sec)
            continue
        return status, headers, body
    return 0, {}, "Max retries exceeded"


async def purge_discord_channel_messages(
    limit: int = 100,
    bot_only: bool = False,
    keep_latest: int = 0,
    min_age_seconds: float = 0.0,
    config_provider: Callable[[], dict] | None = None,
    bot_http_fn: Callable[[str, str, str, dict | None], tuple[int, dict[str, str], str]] | None = None,
    clock: Callable[[], float] | None = None,
    sleep_fn: Callable[[float], Awaitable[None]] | None = None,
) -> dict:
    cfg = (config_provider or (lambda: CONFIG))()
    alerts_cfg = cfg.get("alerts", {})
    bot_token = str(alerts_cfg.get("discord_bot_token", "") or "").strip()
    channel_id = str(alerts_cfg.get("discord_channel_id", "") or "").strip()

    if not bot_token or not channel_id:
        return {
            "ok": False,
            "error": "Discord Bot Token and Channel ID must be configured",
            "deleted_count": 0,
        }

    req_fn = bot_http_fn or _default_bot_http_request
    now_fn = clock or time.time
    sleeper = sleep_fn or asyncio.sleep
    target_limit = max(1, min(1000, int(limit)))

    collected: list[dict] = []
    before_id: str | None = None

    while len(collected) < target_limit:
        batch_size = min(100, target_limit - len(collected))
        url = f"{DISCORD_API_BASE}/channels/{channel_id}/messages?limit={batch_size}"
        if before_id:
            url += f"&before={before_id}"

        status, _headers, body = await _bot_request_with_429("GET", url, bot_token, None, req_fn, sleeper)
        if status != 200:
            err_msg = sanitize_error_text(body) or f"Failed to fetch messages (HTTP {status})"
            add_event("error", f"Discord Purge failed (HTTP {status}): {err_msg}")
            return {
                "ok": False,
                "http_status": status,
                "error": err_msg,
                "deleted_count": 0,
            }

        try:
            page = json.loads(body) if body else []
        except json.JSONDecodeError:
            page = []
        if not isinstance(page, list) or not page:
            break

        collected.extend(page)
        before_id = str(page[-1].get("id", ""))
        if len(page) < batch_size or not before_id:
            break

    if bot_only:
        candidates = [
            m for m in collected if m.get("webhook_id") or m.get("author", {}).get("bot")
        ]
    else:
        candidates = collected

    if keep_latest > 0:
        candidates = candidates[keep_latest:]

    now_sec = now_fn()
    recent_ids: list[str] = []
    old_ids: list[str] = []

    for msg in candidates:
        mid = str(msg.get("id", ""))
        if not mid.isdigit():
            continue
        age_sec = now_sec - snowflake_timestamp_sec(mid)
        if min_age_seconds > 0.0 and age_sec < min_age_seconds:
            continue
        if age_sec < BULK_DELETE_MAX_AGE_SEC:
            recent_ids.append(mid)
        else:
            old_ids.append(mid)

    bulk_deleted = 0
    single_deleted = 0
    errors = 0

    for i in range(0, len(recent_ids), 100):
        chunk = recent_ids[i : i + 100]
        if len(chunk) >= 2:
            bulk_url = f"{DISCORD_API_BASE}/channels/{channel_id}/messages/bulk-delete"
            st, _h, _b = await _bot_request_with_429(
                "POST", bulk_url, bot_token, {"messages": chunk}, req_fn, sleeper
            )
            if 200 <= st < 300:
                bulk_deleted += len(chunk)
            else:
                errors += len(chunk)
        else:
            old_ids.extend(chunk)

    for mid in old_ids:
        del_url = f"{DISCORD_API_BASE}/channels/{channel_id}/messages/{mid}"
        st, _h, _b = await _bot_request_with_429("DELETE", del_url, bot_token, None, req_fn, sleeper)
        if 200 <= st < 300:
            single_deleted += 1
        else:
            errors += 1

    total_deleted = bulk_deleted + single_deleted
    add_event(
        "system",
        f"Discord Purge: deleted {total_deleted} message(s) in channel {channel_id} (bulk={bulk_deleted}, single={single_deleted}, errors={errors})",
    )
    return {
        "ok": errors == 0 or total_deleted > 0,
        "deleted_count": total_deleted,
        "bulk_deleted": bulk_deleted,
        "single_deleted": single_deleted,
        "errors": errors,
        "scanned": len(collected),
    }


async def run_auto_discord_purge(
    on_startup: bool = False,
    config_provider: Callable[[], dict] | None = None,
    bot_http_fn: Callable[[str, str, str, dict | None], tuple[int, dict[str, str], str]] | None = None,
    clock: Callable[[], float] | None = None,
    sleep_fn: Callable[[float], Awaitable[None]] | None = None,
) -> dict | None:
    cfg = (config_provider or (lambda: CONFIG))()
    alerts_cfg = cfg.get("alerts", {})
    if not alerts_cfg.get("auto_purge_enabled", True):
        return None
    if on_startup and not alerts_cfg.get("auto_purge_on_startup", True):
        return None
    if not str(alerts_cfg.get("discord_bot_token", "") or "").strip():
        return None
    if not str(alerts_cfg.get("discord_channel_id", "") or "").strip():
        return None

    keep_latest = 0 if on_startup else max(0, int(alerts_cfg.get("auto_purge_keep_latest", 15)))
    min_age = 15.0 if on_startup else 0.0
    return await purge_discord_channel_messages(
        limit=200,
        bot_only=False,
        keep_latest=keep_latest,
        min_age_seconds=min_age,
        config_provider=config_provider,
        bot_http_fn=bot_http_fn,
        clock=clock,
        sleep_fn=sleep_fn,
    )
