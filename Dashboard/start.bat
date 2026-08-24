@echo off
title Genesis Dashboard
color 0C
echo.
echo  ============================================
echo   GENESIS DASHBOARD - System Monitor
echo   Auto-Boost Engine ^& MuMu Health Tracker
echo  ============================================
echo.

cd /d "%~dp0"

REM Terminate any existing background instances to prevent stale processes
taskkill /F /IM cloudflared.exe 2>nul
taskkill /F /IM python.exe 2>nul

REM Check for Python
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found. Please install Python 3.10+
    pause
    exit /b 1
)

REM Create venv if not exists
if not exist "venv" (
    echo [SETUP] Creating virtual environment...
    python -m venv venv
)

REM Activate venv
call venv\Scripts\activate.bat

REM Install dependencies
echo [SETUP] Checking dependencies...
pip install -r requirements.txt -q --disable-pip-version-check

REM Create data directory
if not exist "data" mkdir data

REM Check for cloudflared
if not exist "cloudflared.exe" (
    echo [SETUP] Downloading Cloudflare Tunnel binary...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile 'cloudflared.exe' -UseBasicParsing"
)

echo [START] Starting Autonomous Network Watchdog...
start /B "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0net_watchdog.ps1"

echo.
echo [START] Starting Genesis Autonomous Core...
venv\Scripts\python.exe server.py


