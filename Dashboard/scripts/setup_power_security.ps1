# ===========================================================================
# Genesis Power Policy & Security Verification Setup
# Execute with Administrator Privileges
# ===========================================================================

# --- Administrator Privilege Guard ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Administrator privileges are required. Run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  GENESIS POWER POLICY & SECURITY HARDENING CHECK" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Power Scheme Configuration (SCHEME_CURRENT) ---
Write-Host "[1/3] Applying Power Policy (AC Never Sleep, DC 30m, Lid AC Do Nothing, Wake Timers ON)..." -ForegroundColor Yellow

$powerCommands = @(
    @{ Args = @("/setacvalueindex", "SCHEME_CURRENT", "SUB_SLEEP", "STANDBYIDLE", "0"); Desc = "AC Sleep Timeout -> 0 (Never)" },
    @{ Args = @("/setdcvalueindex", "SCHEME_CURRENT", "SUB_SLEEP", "STANDBYIDLE", "1800"); Desc = "DC Sleep Timeout -> 1800s (30 min)" },
    @{ Args = @("/setacvalueindex", "SCHEME_CURRENT", "SUB_BUTTONS", "LIDACTION", "0"); Desc = "AC Lid Close Action -> 0 (Do Nothing)" },
    @{ Args = @("/setacvalueindex", "SCHEME_CURRENT", "SUB_SLEEP", "RTCWAKE", "1"); Desc = "AC/DC Wake Timers (RTCWAKE) -> 1 (Enabled)" },
    @{ Args = @("/setactive", "SCHEME_CURRENT"); Desc = "Activated SCHEME_CURRENT" }
)

foreach ($cmd in $powerCommands) {
    & powercfg.exe @($cmd.Args)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] powercfg $($cmd.Args -join ' ') failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [OK] $($cmd.Desc)" -ForegroundColor Green
}

Write-Host ""
Write-Host "  --- Verified Power Settings ---" -ForegroundColor Cyan
& powercfg.exe /q SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Out-Host
& powercfg.exe /q SCHEME_CURRENT SUB_BUTTONS LIDACTION | Out-Host
& powercfg.exe /q SCHEME_CURRENT SUB_SLEEP RTCWAKE | Out-Host

# --- 2. AutoAdminLogon Verification (No Auto-Lock) ---
Write-Host "[2/3] Verifying AutoAdminLogon Configuration..." -ForegroundColor Yellow
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$winlogon = Get-ItemProperty -Path $winlogonPath -ErrorAction SilentlyContinue
if ($winlogon -and $winlogon.AutoAdminLogon -eq "1") {
    Write-Host "  [OK] AutoAdminLogon = 1 (DefaultUserName: $($winlogon.DefaultUserName), Auto-Lock left disabled)" -ForegroundColor Green
} else {
    $val = if ($winlogon) { $winlogon.AutoAdminLogon } else { "Not Set" }
    Write-Host "  [WARN] AutoAdminLogon is '$val' (expected '1'). Verify Autologon configuration." -ForegroundColor Yellow
}

# --- 3. Device Encryption Status Report ---
Write-Host ""
Write-Host "[3/3] Checking Drive C: Device Encryption / BitLocker Status..." -ForegroundColor Yellow
& manage-bde.exe -status C: | Out-Host

Write-Host "========================================================" -ForegroundColor Green
Write-Host "  POWER & SECURITY CHECK COMPLETE" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
