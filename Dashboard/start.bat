@echo off
setlocal EnableExtensions
title Genesis Dashboard
color 0C
echo.
echo  ============================================
echo   GENESIS DASHBOARD - System Monitor
echo   Auto-Boost Engine ^& MuMu Health Tracker
echo  ============================================
echo.

cd /d "%~dp0"

REM --- Targeted Process Cleanup ---
taskkill /F /IM cloudflared.exe 2>nul
set "GENESIS_DASHBOARD_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$dir = ($env:GENESIS_DASHBOARD_DIR).TrimEnd('\'); Get-CimInstance Win32_Process -Filter ('Name=' + [char]39 + 'python.exe' + [char]39) | Where-Object { $_.CommandLine -and $_.CommandLine -match 'server\.py' -and ($_.CommandLine -like ('*' + $dir + '*') -or ($_.ExecutablePath -and ($_.ExecutablePath -like ($dir + '\*') -or $_.ExecutablePath -like '*\Genesis\Dashboard\*'))) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

REM --- Python & Virtual Environment Setup ---
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found. Please install Python 3.10+
    pause
    exit /b 1
)

if not exist "venv" (
    echo [SETUP] Creating virtual environment...
    python -m venv venv
)

call venv\Scripts\activate.bat

echo [SETUP] Checking dependencies...
pip install -r requirements.txt -q --disable-pip-version-check

if not exist "data" mkdir data

if not exist "cloudflared.exe" (
    echo [SETUP] Downloading Cloudflare Tunnel binary...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile 'cloudflared.exe' -UseBasicParsing"
)

REM --- Crash-Recovery Supervisor Loop ---
if not exist "C:\Genesis" mkdir "C:\Genesis"
set "SUPERVISOR_LOG=C:\Genesis\dashboard_supervisor.log"
set "STOP_FLAG=C:\Genesis\stop_dashboard.flag"

:supervisor_loop
if exist "%STOP_FLAG%" (
    call :log_event "[STOP] Stop flag detected. Supervisor exiting."
    echo [STOP] Stop flag detected at %STOP_FLAG%. Exiting supervisor.
    goto :supervisor_exit
)

echo.
echo [START] Starting Genesis Autonomous Core...
call :log_event "[START] Launching Genesis server.py"
venv\Scripts\python.exe server.py
set "SERVER_EXIT=%ERRORLEVEL%"

if exist "%STOP_FLAG%" (
    call :log_event "[STOP] Stop flag detected after server.py exit (code %SERVER_EXIT%). Supervisor exiting."
    echo [STOP] Stop flag detected. Exiting supervisor.
    goto :supervisor_exit
)

if "%SERVER_EXIT%"=="0" (
    call :log_event "[EXIT] Genesis server.py exited cleanly (code 0). Stopping supervisor."
    echo [EXIT] Genesis server.py exited cleanly (code 0).
    goto :supervisor_exit
)

call :log_event "[CRASH] Genesis server.py exited with code %SERVER_EXIT%. Restarting in 5 seconds..."
echo [CRASH] Genesis server.py exited with code %SERVER_EXIT%. Restarting in 5 seconds...
powershell -NoProfile -Command "Start-Sleep -Seconds 5"
goto :supervisor_loop

:log_event
set "LOG_MSG=%~1"
powershell -NoProfile -Command "$ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Add-Content -Path $env:SUPERVISOR_LOG -Value ('[' + $ts + '] ' + $env:LOG_MSG) -Encoding utf8"
goto :eof

:supervisor_exit
endlocal
exit /b 0

