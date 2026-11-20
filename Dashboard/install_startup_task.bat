@echo off
setlocal EnableExtensions
title Genesis Dashboard Elevated Startup Installer
color 0b

set "NO_PAUSE=0"
if /i "%~1"=="--no-pause" set "NO_PAUSE=1"
if /i "%~1"=="/nopause" set "NO_PAUSE=1"

echo ========================================================
echo   GENESIS DASHBOARD - ELEVATED TASK SCHEDULER INSTALLER
echo ========================================================
echo.

REM --- Administrator Privilege Guard ---
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Requesting Administrator Privileges for Task Scheduler...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%~1' -Verb RunAs"
    exit /b
)

echo [1/2] Cleaning up legacy un-elevated startup shortcut...
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Genesis_Dashboard.lnk" 2>nul
echo   [OK] Legacy shortcut removed.

echo [2/2] Registering 'Genesis-Dashboard-Startup' (Silent, Elevated, Unlimited Runtime)...
if not exist "%~dp0start_hidden.vbs" (
    echo [ERROR] Missing "%~dp0start_hidden.vbs".
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

set "GENESIS_DASHBOARD_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$dashDir = ($env:GENESIS_DASHBOARD_DIR).TrimEnd('\'); $vbsPath = Join-Path $dashDir 'start_hidden.vbs'; $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Unregister-ScheduledTask -TaskName 'Genesis-Dashboard-Startup' -Confirm:$false -ErrorAction SilentlyContinue; $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('//B //Nologo \"' + $vbsPath + '\"') -WorkingDirectory $dashDir; $trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser; $principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Highest; $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 0) -MultipleInstances IgnoreNew -StartWhenAvailable; Register-ScheduledTask -TaskName 'Genesis-Dashboard-Startup' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Genesis Autonomous Core Dashboard (Silent Elevated 24/7)' -Force | Out-Null"

if %errorLevel% equ 0 (
    echo.
    echo ========================================================
    echo   [SUCCESS] Task Scheduler installed successfully!
    echo   Genesis Dashboard will now boot silently with Admin
    echo   rights, zero console windows, and unlimited runtime.
    echo ========================================================
) else (
    echo.
    echo [ERROR] Failed to register task. Please check permissions.
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

echo.
if "%NO_PAUSE%"=="0" pause
exit /b 0
