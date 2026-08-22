# ===========================================================================
# Genesis Network Hardening & Watchdog Installer v2.1
# Execute with Administrator Privileges
# ===========================================================================

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  GENESIS NETWORK HARDENING & SELF-HEALING WATCHDOG" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Wi-Fi Profile Optimizations
# ---------------------------------------------------------------------------
Write-Host "[1/6] Optimizing Wi-Fi Profile Priority & Randomization..." -ForegroundColor Yellow
netsh wlan set profileorder name="KMITL-HiSpeed" interface="Wi-Fi" priority=1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] KMITL-HiSpeed set to Priority #1" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Failed to set profile order (Exit code: $LASTEXITCODE)" -ForegroundColor DarkYellow
}

netsh wlan set profileparameter name="KMITL-HiSpeed" Randomization=disable | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] MAC Randomization set to Disabled" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Failed to set randomization (Exit code: $LASTEXITCODE)" -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------
# 2. Service Optimizations
# ---------------------------------------------------------------------------
Write-Host "[2/6] Configuring Eaphost Authentication Service..." -ForegroundColor Yellow
try {
    Set-Service -Name "Eaphost" -StartupType Automatic
    Start-Service -Name "Eaphost" -ErrorAction SilentlyContinue
    Write-Host "  [OK] Eaphost StartupType set to Automatic" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Failed to configure Eaphost: $_" -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------
# 3. Power Plan Wireless Maximum Performance
# ---------------------------------------------------------------------------
Write-Host "[3/6] Setting Wireless Adapter Power Plan to Maximum Performance..." -ForegroundColor Yellow
try {
    $subGroup = "19cbb8fa-5279-450e-9fac-8a3d5fedd0c1"
    $setting = "12bbebe6-58d6-4636-95bb-3217ef867c1a"
    powercfg /setacvalueindex SCHEME_CURRENT $subGroup $setting 0
    powercfg /setdcvalueindex SCHEME_CURRENT $subGroup $setting 0
    powercfg /setactive SCHEME_CURRENT
    Write-Host "  [OK] Power Plan Wireless Power Saving Mode set to 0 (Max Performance)" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Failed to update power plan: $_" -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------
# 4. Dynamic Realtek Registry Tuning with Strict Hardware Guard
# ---------------------------------------------------------------------------
Write-Host "[4/6] Locating and Tuning Realtek RTL8852BE Driver Registry..." -ForegroundColor Yellow
$classRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
$targetKey = $null

Get-ChildItem -Path $classRoot -ErrorAction SilentlyContinue | ForEach-Object {
    $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
    if ($props -and $props.DriverDesc -match "8852") {
        $targetKey = $_.PSPath
    }
}

if (-not $targetKey) {
    Write-Host "  [ERROR] Realtek RTL8852BE registry key not found! Skipped to avoid affecting other adapters." -ForegroundColor Red
} else {
    $desc = (Get-ItemProperty -Path $targetKey).DriverDesc
    Write-Host "  [FOUND] Target Driver: $desc ($targetKey)" -ForegroundColor Cyan
    
    # Apply driver performance properties with explicit types
    Set-ItemProperty -Path $targetKey -Name "LpsEn" -Value "0" -Type String
    Set-ItemProperty -Path $targetKey -Name "Dot11dEnable" -Value "0" -Type String
    Set-ItemProperty -Path $targetKey -Name "PnPCapabilities" -Value 24 -Type DWord
    
    Write-Host "  [OK] Leisure Power Save (LpsEn) -> 0 (Disabled)" -ForegroundColor Green
    Write-Host "  [OK] 802.11d (Dot11dEnable) -> 0 (Disabled)" -ForegroundColor Green
    Write-Host "  [OK] PnPCapabilities -> 24 (Prevent Device Power Down)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 5. Install Standalone Scheduled Task Watchdog (Isolated in C:\Genesis)
# ---------------------------------------------------------------------------
Write-Host "[5/6] Deploying Watchdog Runtime to Local SSD (C:\Genesis)..." -ForegroundColor Yellow
$sourceScript = Join-Path $PSScriptRoot "net_watchdog.ps1"
$runtimeDir = "C:\Genesis"
$destScript = Join-Path $runtimeDir "net_watchdog.ps1"

if (-not (Test-Path $sourceScript)) {
    $sourceScript = ".\net_watchdog.ps1"
}

if (-not (Test-Path $sourceScript)) {
    Write-Host "  [ERROR] Source watchdog script not found at $sourceScript!" -ForegroundColor Red
} else {
    if (-not (Test-Path $runtimeDir)) {
        New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
    }
    Copy-Item -Path $sourceScript -Destination $destScript -Force
    Write-Host "  [OK] Deployed net_watchdog.ps1 to $destScript (Independent of OneDrive)" -ForegroundColor Green

    $taskName = "Genesis-NetworkWatchdog"
    
    # Unregister previous task if exists
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$destScript`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 0)
    
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Genesis Autonomous Network Watchdog and Self-Healing Engine" | Out-Null
    
    # Start the task immediately
    Start-ScheduledTask -TaskName $taskName
    Write-Host "  [OK] Scheduled Task '$taskName' registered and active under SYSTEM" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 6. Soft-Restart Wi-Fi Adapter (Kept at the very end)
# ---------------------------------------------------------------------------
Write-Host "`n[6/6] Reloading Wi-Fi Adapter Parameters (Adapter Bounce)..." -ForegroundColor Yellow
Write-Host "  Note: Brief 2-3s reconnection may occur..." -ForegroundColor DarkYellow
Restart-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  [OK] Wi-Fi Adapter reloaded successfully!`n" -ForegroundColor Green

Write-Host "========================================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE — Network is now Hardened & Self-Healing" -ForegroundColor Green
Write-Host "========================================================`n" -ForegroundColor Green
