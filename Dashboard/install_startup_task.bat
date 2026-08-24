@echo off
title Genesis Dashboard Elevated Startup Installer
color 0b

echo ========================================================
echo   GENESIS DASHBOARD - ELEVATED TASK SCHEDULER INSTALLER
echo ========================================================
echo.

:: Check Administrator Privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Requesting Administrator Privileges for Task Scheduler...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [1/2] Cleaning up legacy un-elevated startup shortcut...
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Genesis_Dashboard.lnk" 2>nul
echo   [OK] Legacy shortcut removed.

echo [2/2] Registering 'Genesis-Dashboard-Startup' with HIGHEST PRIVILEGES...
schtasks /create /tn "Genesis-Dashboard-Startup" /tr "\"%~dp0start.bat\"" /sc onlogon /rl highest /f
if %errorLevel% equ 0 (
    echo.
    echo ========================================================
    echo   [SUCCESS] Task Scheduler installed successfully!
    echo   Genesis Dashboard will now boot with Full Admin Rights
    echo   without any UAC prompts on Windows Login!
    echo ========================================================
) else (
    echo.
    echo [ERROR] Failed to register task. Please check permissions.
)

echo.
pause
