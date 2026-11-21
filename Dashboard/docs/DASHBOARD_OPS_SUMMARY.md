# Genesis Dashboard Operations & Architecture Specification

Purpose: Token-efficient engineering reference for AI agents and maintainers operating on `C:\Dev\Genesis\Dashboard`. All host-specific identifiers, tailnet domains, Tailscale IPs, OS usernames, and credentials are intentionally parameterized.

---

## 1. System Architecture & Entry Points

- **Backend ASGI Server**: `Dashboard\server.py` (FastAPI / Uvicorn) serving the REST API (`/api/*`), WebSocket telemetry stream (`/ws`), and compiled frontend SPA (`Dashboard\frontend\dist`).
- **Frontend**: TypeScript + Vite React application (`Dashboard\frontend\src`), built into static assets consumed directly by the Python backend on port `7700` (default).
- **Primary Configuration**: `Dashboard\config.json` (untracked local config) modeled after `Dashboard\config.example.json`, managed thread-safely via `Dashboard\backend\core\config.py`.

---

## 2. Privilege, Process & Zero-Window Invariants (DO NOT BREAK)

1. **Mandatory Administrator Privilege (`AGENTS.md`)**:
   - `server.py` calls low-level Windows NT Native APIs (`NtSetSystemInformation` for Standby List purge, `NtSetTimerResolution` 0.5 ms, `ProcessPowerThrottling` Anti-EcoQoS, `SetProcessAffinityMask`, and Windows Defender / Service APIs).
   - Never start `server.py`, `start.bat`, or `start_hidden.vbs` directly from a non-elevated shell or AI agent sandbox. Always launch via the elevated Scheduled Task (`Highest` privilege) or an elevated Admin session (`Run as Administrator`).
2. **Immutable Process Name (`win32_ops.py`)**:
   - `python.exe` is registered in `IMMUTABLE_PROTECTED_PROCESSES`.
   - Never switch `start.bat` to `pythonw.exe`; keep `venv\Scripts\python.exe server.py` invoked headlessly via `wscript.exe //B //Nologo start_hidden.vbs` launching `start.bat --silent`.
3. **Zero-Window Subprocess Contract**:
   - Every `subprocess.run` and `subprocess.Popen` call across `backend/services/maintenance.py`, `mumu_monitor.py`, `telemetry.py`, and `tunnel.py` must set `creationflags=_CREATE_NO_WINDOW` (`0x08000000`) to prevent console flashes on the interactive desktop.
   - Enforced statically via AST verification in `tests/test_silent_execution.py`.

---

## 3. Supervisor, Startup Task & Restart Exit Protocol

- **Headless Bootstrap Chain**:
  `Scheduled Task (Highest)` -> `wscript.exe //B //Nologo start_hidden.vbs` -> `start.bat --silent` -> `venv\Scripts\python.exe server.py`
- **Task Scheduler Configuration (`install_startup_task.bat`)**:
  - Uses PowerShell `Register-ScheduledTask` with `-RunLevel Highest`, `ExecutionTimeLimit` = `New-TimeSpan -Days 0` (`PT0S`, unlimited runtime), `-AllowStartIfOnBatteries`, `-DontStopIfGoingOnBatteries`, and `-MultipleInstances IgnoreNew`.
- **Log Rotation (`start.bat`)**:
  - Rotates server/supervisor logs when size thresholds (10 MB / 5 MB) are crossed before spawning the worker loop.
- **Supervisor Exit-Code State Machine (`start.bat` <-> `backend/api/routes.py`)**:
  - `STOP_FLAG` present -> clean supervisor termination (`goto :supervisor_exit`).
  - `SERVER_EXIT == 42` -> emitted by `POST /api/system/restart` (`os._exit(42)`); waits 2 s (`timeout /t 2 /nobreak >nul`) and loops back to `:supervisor_loop` for immediate restart.
  - `SERVER_EXIT == 0` -> clean intentional exit; stops supervisor.
  - Any other non-zero exit code -> crash-recovery loop restart.

---

## 4. Ingress & Remote Access (`tunnel.provider`)

- **Supported Providers** (`backend/core/config.py`, `backend/services/tunnel.py`, `frontend/src/types/dashboard.ts`):
  - `tailscale`: Recommended zero-warning private mesh HTTPS ingress via Tailscale Serve (`tailscale serve --bg http://127.0.0.1:7700`), exposing `https://<node>.<tailnet>.ts.net` (configured via `tunnel.tailscale_url`). Persists across reboots over WireGuard with native TLS and no browser warning screen.
  - `local_only`: Strict local-host operation without opening external tunnel processes.
- **Deprecated / Removed Path**:
  - `ngrok` free tier was retired because its interstitial browser warning page blocks direct mobile/tablet dashboard loading unless custom headers/paid plans are used.
- **Mobile Client Note (Android / Chrome)**:
  - Even with Tailscale VPN connected, Android / Chrome "Private DNS" or "Secure DNS" (DoH/DoT) can override MagicDNS queries for `.ts.net` domains. Turn Private/Secure DNS Off on client devices if `.ts.net` fails to resolve while other tailnet devices succeed.

---

## 5. Resolved Production Defects & Hardening Fixes

| Component | Defect Fixed | Implementation |
|---|---|---|
| `backend/api/ws.py` | `Task exception was never retrieved` when mobile/tablet tabs closed (`WebSocketDisconnect(1001)` inside `_receiver` / `_metrics_sender`). | Wrapped `_metrics_sender()` and `_receiver()` loops in `try ... except WebSocketDisconnect: return`; canceled and awaited `pending`, drained `done` via `.result()`, and cleaned up tasks on `asyncio.CancelledError`. |
| `backend/core/config.py` | `JSONDecodeError: Unexpected UTF-8 BOM` when PowerShell 5.1 scripts touched `config.json`. | Changed `load_config()` file opens for `CONFIG_PATH` and `CONFIG_EXAMPLE_PATH` from `utf-8` to `utf-8-sig`. (When editing JSON via PowerShell, still prefer `UTF8Encoding($false)`.) |
| `backend/api/routes.py` & `start.bat` | `POST /api/system/restart` called `os._exit(0)`, causing `start.bat` to stop the supervisor instead of restarting `server.py`. | Changed `_delayed_exit()` in `routes.py` to `os._exit(42)` and added the matching `SERVER_EXIT == 42` restart branch in `start.bat` ahead of the `0` branch. |
| `start.bat`, `start_hidden.vbs`, `install_startup_task.bat`, services | Foreground cmd flashes, 72-hour Scheduled Task timeout risk, missing `creationflags` in subprocess calls. | Created `start_hidden.vbs`, added `--silent` + log rotation to `start.bat`, switched task registration to `PT0S` unlimited runtime, and applied `_CREATE_NO_WINDOW` across 24 subprocess sites. |

---

## 6. Verification & Release Checklist

Run from elevated or test-safe environment after code edits (`c:\Dev\Genesis\Dashboard`):

1. **Backend Unit & Regression Suite** (from `Dashboard\`):
   ```powershell
   .\venv\Scripts\python.exe -m unittest discover -s tests -v
   ```
   Covers API auth/security, `tailscale` / `local_only` tunnel config & serialization, UTF-8 BOM resilience (`test_load_config_handles_utf8_bom`), zero unretrieved asyncio task exceptions on disconnect (`test_ws_disconnect_leaves_no_unretrieved_task_exception`), AST `_CREATE_NO_WINDOW` coverage (`tests/test_silent_execution.py`), and exit-code `42` restart contract (`test_restart_exit_code_contract`).
2. **Frontend Lint & Production Build** (from `Dashboard\frontend\`):
   ```powershell
   npx oxlint
   npm run build
   ```
   Remember: the running backend serves built static assets from `frontend\dist`; always run `npm run build` after UI edits.
3. **Git Hygiene (`AGENTS.md`)**:
   - Stage only tracked code/docs/tests (keep `config.json`, tokens, tailnet domains, and local machine details untracked), use Conventional Commits, and push to `origin main`.
