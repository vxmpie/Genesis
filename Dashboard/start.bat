@echo off
setlocal EnableExtensions

REM --- Mode & Paths ---
set "SILENT_MODE=0"
if /i "%~1"=="--silent" set "SILENT_MODE=1"

if not exist "C:\Genesis" mkdir "C:\Genesis"
set "SUPERVISOR_LOG=C:\Genesis\dashboard_supervisor.log"
set "SUPERVISOR_LOG_OLD=C:\Genesis\dashboard_supervisor.log.old"
set "SERVER_LOG=C:\Genesis\dashboard_server.log"
set "SERVER_LOG_OLD=C:\Genesis\dashboard_server.log.old"
set "STOP_FLAG=C:\Genesis\stop_dashboard.flag"

if "%SILENT_MODE%"=="0" (
    title Genesis Dashboard
    color 0C
    echo.
    echo  ============================================
    echo   GENESIS DASHBOARD - System Monitor
    echo   Auto-Boost Engine ^& MuMu Health Tracker
    echo  ============================================
    echo.
)

cd /d "%~dp0"

REM --- Targeted Process Cleanup ---
taskkill /F /IM cloudflared.exe >nul 2>&1
set "GENESIS_DASHBOARD_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$dir = ($env:GENESIS_DASHBOARD_DIR).TrimEnd('\'); Get-CimInstance Win32_Process -Filter ('Name=' + [char]39 + 'python.exe' + [char]39) | Where-Object { $_.CommandLine -and $_.CommandLine -match 'server\.py' -and ($_.CommandLine -like ('*' + $dir + '*') -or ($_.ExecutablePath -and ($_.ExecutablePath -like ($dir + '\*') -or $_.ExecutablePath -like '*\Genesis\Dashboard\*'))) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

REM --- Python & Virtual Environment Setup ---
where python >nul 2>&1
if %errorlevel% neq 0 (
    call :log_event "[ERROR] Python not found. Please install Python 3.10+"
    if "%SILENT_MODE%"=="0" (
        echo [ERROR] Python not found. Please install Python 3.10+
        pause
    )
    exit /b 1
)

if not exist "venv" (
    if "%SILENT_MODE%"=="0" (
        echo [SETUP] Creating virtual environment...
        python -m venv venv
    ) else (
        call :log_event "[SETUP] Creating virtual environment..."
        python -m venv venv >> "%SUPERVISOR_LOG%" 2>&1
    )
    if %errorlevel% neq 0 (
        call :log_event "[ERROR] Failed to create virtual environment."
        if "%SILENT_MODE%"=="0" pause
        exit /b 1
    )
)

call venv\Scripts\activate.bat

if "%SILENT_MODE%"=="0" (
    echo [SETUP] Checking dependencies...
    pip install -r requirements.txt -q --disable-pip-version-check
) else (
    pip install -r requirements.txt -q --disable-pip-version-check >> "%SUPERVISOR_LOG%" 2>&1
)
if %errorlevel% neq 0 (
    call :log_event "[ERROR] Failed to install dependencies from requirements.txt."
    if "%SILENT_MODE%"=="0" pause
    exit /b 1
)

if not exist "data" mkdir data

if not exist "cloudflared.exe" (
    if "%SILENT_MODE%"=="0" echo [SETUP] Downloading Cloudflare Tunnel binary...
    call :log_event "[SETUP] Downloading Cloudflare Tunnel binary..."
    powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile 'cloudflared.exe' -UseBasicParsing"
)

REM --- Crash-Recovery Supervisor Loop ---
:supervisor_loop
if exist "%STOP_FLAG%" (
    call :log_event "[STOP] Stop flag detected. Supervisor exiting."
    if "%SILENT_MODE%"=="0" echo [STOP] Stop flag detected at %STOP_FLAG%. Exiting supervisor.
    goto :supervisor_exit
)

call :rotate_logs

if "%SILENT_MODE%"=="0" (
    echo.
    echo [START] Starting Genesis Autonomous Core...
)
call :log_event "[START] Launching Genesis server.py (silent=%SILENT_MODE%)"
if "%SILENT_MODE%"=="1" (
    venv\Scripts\python.exe server.py >> "%SERVER_LOG%" 2>&1
) else (
    venv\Scripts\python.exe server.py
)
set "SERVER_EXIT=%ERRORLEVEL%"

if exist "%STOP_FLAG%" (
    call :log_event "[STOP] Stop flag detected after server.py exit (code %SERVER_EXIT%). Supervisor exiting."
    if "%SILENT_MODE%"=="0" echo [STOP] Stop flag detected. Exiting supervisor.
    goto :supervisor_exit
)

if "%SERVER_EXIT%"=="0" (
    call :log_event "[EXIT] Genesis server.py exited cleanly (code 0). Stopping supervisor."
    if "%SILENT_MODE%"=="0" echo [EXIT] Genesis server.py exited cleanly (code 0).
    goto :supervisor_exit
)

call :log_event "[CRASH] Genesis server.py exited with code %SERVER_EXIT%. Restarting in 5 seconds..."
if "%SILENT_MODE%"=="0" echo [CRASH] Genesis server.py exited with code %SERVER_EXIT%. Restarting in 5 seconds...
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Sleep -Seconds 5"
goto :supervisor_loop

REM --- Log Helpers ---
:rotate_logs
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "foreach ($pair in @(@($env:SERVER_LOG, $env:SERVER_LOG_OLD, 10485760), @($env:SUPERVISOR_LOG, $env:SUPERVISOR_LOG_OLD, 5242880))) { if (Test-Path $pair[0]) { $f = Get-Item $pair[0] -ErrorAction SilentlyContinue; if ($f -and $f.Length -gt $pair[2]) { Move-Item -Path $pair[0] -Destination $pair[1] -Force -ErrorAction SilentlyContinue } } }"
goto :eof

:log_event
set "LOG_MSG=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Add-Content -Path $env:SUPERVISOR_LOG -Value ('[' + $ts + '] ' + $env:LOG_MSG) -Encoding utf8"
goto :eof

:supervisor_exit
endlocal
exit /b 0

