import hashlib
import json
import os
import secrets
import threading
import time
from fastapi import Request

from backend.core.config import CONFIG, CONFIG_LOCK, DATA_DIR, SESSIONS_PATH, save_config

MAX_FAILED_ATTEMPTS = 5
LOCKOUT_SECONDS = 300

_auth_lock = threading.Lock()
_failed_attempts: dict[str, list[float]] = {}


def _load_sessions() -> dict[str, float]:
    if SESSIONS_PATH.exists():
        try:
            with open(SESSIONS_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            now = time.time()
            return {
                k: float(v)
                for k, v in data.items()
                if float(v) <= 0 or float(v) > now
            }
        except Exception:
            pass
    return {}


def _save_sessions(sessions: dict[str, float]) -> None:
    try:
        now = time.time()
        valid = {k: v for k, v in sessions.items() if v <= 0 or v > now}
        tmp_path = DATA_DIR / "sessions.json.tmp"
        with open(tmp_path, "w", encoding="utf-8", newline="\n") as f:
            json.dump(valid, f, indent=2)
        os.replace(tmp_path, SESSIONS_PATH)
    except Exception:
        pass


_valid_sessions: dict[str, float] = _load_sessions()


def hash_pin(pin: str, salt: str) -> str:
    return hashlib.sha256((salt + pin).encode("utf-8")).hexdigest()


def verify_pin_input(input_pin: str) -> bool:
    clean_input = (input_pin or "").strip()
    if not clean_input:
        return False

    with CONFIG_LOCK:
        auth_cfg = CONFIG.get("auth", {})
        if "pin_hash" in auth_cfg and "salt" in auth_cfg:
            computed = hash_pin(clean_input, str(auth_cfg["salt"]))
            return secrets.compare_digest(computed, str(auth_cfg["pin_hash"]))
        if "pin" in auth_cfg:
            stored_pin = str(auth_cfg["pin"]).strip()
            is_valid = secrets.compare_digest(clean_input, stored_pin)
            if is_valid:
                salt = secrets.token_hex(8)
                auth_cfg["salt"] = salt
                auth_cfg["pin_hash"] = hash_pin(clean_input, salt)
                auth_cfg.pop("pin", None)
                save_config(CONFIG)
            return is_valid
    return False


def get_client_ip(request: Request, tunnel_provider: str | None = None) -> str:
    peer_ip = request.client.host if request.client else "unknown"
    if peer_ip in ("127.0.0.1", "::1", "localhost"):
        provider = (tunnel_provider or CONFIG.get("tunnel", {}).get("provider", "ngrok")).strip().lower()
        if provider in ("cloudflared", "cloudflare"):
            cf_ip = request.headers.get("CF-Connecting-IP")
            if cf_ip:
                return cf_ip.strip()
        x_fwd = request.headers.get("X-Forwarded-For")
        if x_fwd:
            hops = [part.strip() for part in x_fwd.split(",") if part.strip()]
            if hops:
                return hops[-1]
    return peer_ip


def is_auth_enabled() -> bool:
    return bool(CONFIG.get("auth", {}).get("enabled", False))


def _prune_attempts_locked(ip: str, now: float) -> list[float]:
    cutoff = now - LOCKOUT_SECONDS
    recent = [ts for ts in _failed_attempts.get(ip, []) if ts > cutoff]
    if recent:
        _failed_attempts[ip] = recent
    else:
        _failed_attempts.pop(ip, None)
    return recent


def is_ip_locked(ip: str, now: float | None = None) -> bool:
    ts = now if now is not None else time.time()
    with _auth_lock:
        recent = _prune_attempts_locked(ip, ts)
        return len(recent) >= MAX_FAILED_ATTEMPTS


def get_lockout_remaining(ip: str, now: float | None = None) -> int:
    ts = now if now is not None else time.time()
    with _auth_lock:
        recent = _prune_attempts_locked(ip, ts)
        if len(recent) < MAX_FAILED_ATTEMPTS:
            return 0
        oldest_active = min(recent)
        return max(1, int((oldest_active + LOCKOUT_SECONDS) - ts))


def record_failed_attempt(ip: str, now: float | None = None) -> int:
    ts = now if now is not None else time.time()
    with _auth_lock:
        recent = _prune_attempts_locked(ip, ts)
        recent.append(ts)
        _failed_attempts[ip] = recent
        return len(recent)


def clear_failed_attempts(ip: str) -> None:
    with _auth_lock:
        _failed_attempts.pop(ip, None)


def extract_token_from_request(request: Request) -> str | None:
    return request.headers.get("X-Auth-Token") or request.query_params.get("token")


def verify_session_token(token: str | None) -> bool:
    if not is_auth_enabled():
        return True
    if not token:
        return False
    with _auth_lock:
        expiry = _valid_sessions.get(token)
        if expiry is None:
            return False
        if expiry <= 0:
            return True
        if time.time() > expiry:
            _valid_sessions.pop(token, None)
            _save_sessions(_valid_sessions)
            return False
        return True


def is_request_authenticated(request: Request) -> bool:
    if not is_auth_enabled():
        return True
    return verify_session_token(extract_token_from_request(request))


def create_session_token() -> str:
    token = secrets.token_hex(24)
    timeout_hours = float(CONFIG.get("auth", {}).get("session_timeout_hours", 0))
    with _auth_lock:
        if timeout_hours <= 0:
            _valid_sessions[token] = 0.0
        else:
            _valid_sessions[token] = time.time() + (timeout_hours * 3600.0)
        _save_sessions(_valid_sessions)
    return token
