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

echo.
echo [START] Starting Genesis Dashboard server...
start /B "" venv\Scripts\python.exe server.py

echo [START] Starting Autonomous Network Watchdog...
start /B "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0net_watchdog.ps1"

REM Wait for server to start
timeout /t 3 /nobreak >nul

REM Check for cloudflared
if not exist "cloudflared.exe" (
    echo [SETUP] Downloading Cloudflare Tunnel binary...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile 'cloudflared.exe' -UseBasicParsing"
)

echo [START] Starting Cloudflare Tunnel...
echo [INFO]  Please wait a few seconds for the Public Cloud URL to appear below:
echo.

REM Start cloudflared tunnel (output shows the public URL)
.\cloudflared.exe tunnel --url http://localhost:7700

