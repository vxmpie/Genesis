# ===========================================================================
# Genesis Private Remote Access Installer (Tailscale + OpenSSH + Firewall)
# Execute with Administrator Privileges
# ===========================================================================

param (
    [switch]$LockdownPasswordAuth
)

# --- Administrator Privilege Guard ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Administrator privileges are required. Run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$SshDir = "C:\ProgramData\ssh"
$SshdConfigPath = Join-Path $SshDir "sshd_config"
$AdminAuthKeysPath = Join-Path $SshDir "administrators_authorized_keys"
$FirewallRuleName = "Genesis-OpenSSH-TailscaleOnly"

# --- Helpers ---
function Set-SshdDirective {
    param (
        [string]$ConfigPath,
        [string]$Key,
        [string]$Value
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "sshd_config not found at $ConfigPath"
    }

    $lines = [System.Collections.Generic.List[string]]::new([System.IO.File]::ReadAllLines($ConfigPath))
    $pattern = "^\s*#?\s*" + [regex]::Escape($Key) + "\b"
    $updated = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*Match\b") {
            break
        }
        if ($lines[$i] -match $pattern) {
            if (-not $updated) {
                $lines[$i] = "$Key $Value"
                $updated = $true
            }
        }
    }

    if (-not $updated) {
        $matchIndex = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^\s*Match\b") {
                $matchIndex = $i
                break
            }
        }
        if ($matchIndex -ge 0) {
            $lines.Insert($matchIndex, "$Key $Value")
        } else {
            $lines.Add("$Key $Value")
        }
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($ConfigPath, $lines.ToArray(), $utf8NoBom)
}

function Set-AdminAuthorizedKeysAcl([string]$FilePath) {
    if (-not (Test-Path -LiteralPath $FilePath)) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($FilePath, "", $utf8NoBom)
    }

    & icacls.exe $FilePath /inheritance:r /grant "*S-1-5-18:F" /grant "*S-1-5-32-544:F" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "icacls failed on $FilePath with exit code $LASTEXITCODE"
    }
}

# --- Password Auth Lockdown Mode ---
if ($LockdownPasswordAuth) {
    Write-Host ""
    Write-Host "=== Locking Down OpenSSH to Key-Only Authentication ===" -ForegroundColor Cyan

    if (-not (Test-Path -LiteralPath $AdminAuthKeysPath)) {
        Write-Host "[ERROR] $AdminAuthKeysPath not found. Add your public SSH key before locking down password auth." -ForegroundColor Red
        exit 1
    }

    $validKeys = Get-Content -LiteralPath $AdminAuthKeysPath -ErrorAction SilentlyContinue | Where-Object {
        $trimmed = $_.Trim()
        ($trimmed.Length -gt 20) -and (-not $trimmed.StartsWith("#"))
    }
    if (-not $validKeys) {
        Write-Host "[ERROR] No valid SSH public key found in $AdminAuthKeysPath. Aborting lockdown to prevent lockout." -ForegroundColor Red
        exit 1
    }

    Set-AdminAuthorizedKeysAcl -FilePath $AdminAuthKeysPath
    Set-SshdDirective -ConfigPath $SshdConfigPath -Key "PubkeyAuthentication" -Value "yes"
    Set-SshdDirective -ConfigPath $SshdConfigPath -Key "PasswordAuthentication" -Value "no"

    Restart-Service -Name "sshd" -ErrorAction Stop
    $sshd = Get-Service -Name "sshd"
    if ($sshd.Status -ne "Running") {
        Write-Host "[ERROR] sshd failed to stay running after lockdown." -ForegroundColor Red
        exit 1
    }

    Write-Host "[OK] PasswordAuthentication disabled, PubkeyAuthentication enabled, ACL verified, sshd running." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  GENESIS PRIVATE REMOTE ACCESS SETUP (TAILSCALE + SSH)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Tailscale Installation & Service Setup ---
Write-Host "[1/3] Checking and configuring Tailscale..." -ForegroundColor Yellow
$tsExe = "C:\Program Files\Tailscale\tailscale.exe"
$tsCmd = Get-Command tailscale -ErrorAction SilentlyContinue

if (-not $tsCmd -and -not (Test-Path -LiteralPath $tsExe)) {
    Write-Host "  [INSTALL] Fetching latest Tailscale 64-bit MSI metadata..." -ForegroundColor Cyan
    $msiName = $null
    try {
        $meta = Invoke-RestMethod -Uri "https://pkgs.tailscale.com/stable/?mode=json" -TimeoutSec 15
        if ($meta -and $meta.MSIs -and $meta.MSIs.amd64) {
            $msiName = [string]$meta.MSIs.amd64
        }
    } catch {
        Write-Host "  [WARN] JSON index lookup failed, falling back to HTML index..." -ForegroundColor DarkYellow
    }

    if (-not $msiName) {
        $html = (Invoke-WebRequest -Uri "https://pkgs.tailscale.com/stable/" -UseBasicParsing -TimeoutSec 15).Content
        $match = [regex]::Match($html, 'tailscale-setup-[^"''<>]+amd64\.msi')
        if ($match.Success) {
            $msiName = $match.Value
        }
    }

    if (-not $msiName) {
        Write-Host "  [ERROR] Unable to resolve Tailscale 64-bit MSI filename." -ForegroundColor Red
        exit 1
    }

    $msiUrl = "https://pkgs.tailscale.com/stable/$msiName"
    $msiPath = Join-Path $env:TEMP $msiName
    Write-Host "  [DOWNLOAD] $msiUrl -> $msiPath" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing -TimeoutSec 120

    Write-Host "  [MSI] Installing $msiName silently..." -ForegroundColor Cyan
    $msiProc = Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", "`"$msiPath`"", "/qn", "/norestart") -Wait -PassThru
    if ($msiProc.ExitCode -ne 0 -and $msiProc.ExitCode -ne 3010) {
        Write-Host "  [ERROR] Tailscale MSI installation failed with exit code $($msiProc.ExitCode)" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [OK] Tailscale installed (exit code: $($msiProc.ExitCode))" -ForegroundColor Green
} else {
    Write-Host "  [OK] Tailscale is already installed." -ForegroundColor Green
}

$tsService = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue
if ($tsService) {
    Set-Service -Name "Tailscale" -StartupType Automatic
    if ($tsService.Status -ne "Running") {
        Start-Service -Name "Tailscale" -ErrorAction SilentlyContinue
    }
    Write-Host "  [OK] Service 'Tailscale' set to Automatic ($((Get-Service -Name 'Tailscale').Status))" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Tailscale service not found yet; a reboot may be pending." -ForegroundColor DarkYellow
}

# --- 2. OpenSSH Server Setup & Key Auth Preparation ---
Write-Host ""
Write-Host "[2/3] Configuring OpenSSH Server & PowerShell Default Shell..." -ForegroundColor Yellow
$sshCap = Get-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"
if ($sshCap.State -ne "Installed") {
    Write-Host "  [INSTALL] Installing OpenSSH.Server~~~~0.0.1.0..." -ForegroundColor Cyan
    Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0" | Out-Null
}

Set-Service -Name "sshd" -StartupType Automatic
$sshdSvc = Get-Service -Name "sshd"
if ($sshdSvc.Status -ne "Running") {
    Start-Service -Name "sshd"
}

for ($attempt = 0; $attempt -lt 10 -and (-not (Test-Path -LiteralPath $SshdConfigPath)); $attempt++) {
    Start-Sleep -Milliseconds 500
}

$openSshReg = "HKLM:\SOFTWARE\OpenSSH"
if (-not (Test-Path -LiteralPath $openSshReg)) {
    New-Item -Path $openSshReg -Force | Out-Null
}
New-ItemProperty -Path $openSshReg -Name "DefaultShell" -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force | Out-Null
Write-Host "  [OK] DefaultShell set to Windows PowerShell" -ForegroundColor Green

Set-AdminAuthorizedKeysAcl -FilePath $AdminAuthKeysPath
Write-Host "  [OK] ACL locked on $AdminAuthKeysPath (SYSTEM + Administrators)" -ForegroundColor Green

Set-SshdDirective -ConfigPath $SshdConfigPath -Key "PubkeyAuthentication" -Value "yes"
Write-Host "  [OK] PubkeyAuthentication yes configured in sshd_config" -ForegroundColor Green

Restart-Service -Name "sshd"
$sshdAfter = Get-Service -Name "sshd"
Write-Host "  [OK] Service 'sshd' status: $($sshdAfter.Status)" -ForegroundColor Green

# --- 3. Windows Firewall Lock-Down (Tailscale CGNAT 100.64.0.0/10 Only) ---
Write-Host ""
Write-Host "[3/3] Locking down Windows Firewall Port 22 to Tailscale (100.64.0.0/10)..." -ForegroundColor Yellow

$openSshRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {
    $_.Direction -eq "Inbound" -and
    $_.DisplayName -like "*OpenSSH*" -and
    $_.DisplayName -ne $FirewallRuleName
}
foreach ($rule in $openSshRules) {
    if ($rule.Enabled -eq "True") {
        Disable-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
        Write-Host "  [DISABLED] Broad rule: $($rule.DisplayName)" -ForegroundColor DarkYellow
    }
}

Remove-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue
New-NetFirewallRule `
    -Name $FirewallRuleName `
    -DisplayName $FirewallRuleName `
    -Description "Allow OpenSSH TCP port 22 strictly from Tailscale 100.64.0.0/10" `
    -Enabled True `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 22 `
    -RemoteAddress "100.64.0.0/10" `
    -Action Allow `
    -Profile Any | Out-Null

Write-Host "  [OK] Firewall rule '$FirewallRuleName' active (TCP 22 <- 100.64.0.0/10)" -ForegroundColor Green

# --- Next Manual Steps ---
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  REMOTE ACCESS BASELINE READY" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "  1. Authenticate & enable unattended Tailscale:"
Write-Host "       tailscale up --unattended"
Write-Host "  2. Append your SSH public key to:"
Write-Host "       $AdminAuthKeysPath"
Write-Host "  3. Test SSH from your remote device over Tailscale:"
Write-Host "       ssh marple@<tailscale-ip>"
Write-Host "  4. Once key login succeeds, disable password SSH auth:"
Write-Host "       .\setup_remote_access.ps1 -LockdownPasswordAuth"
Write-Host ""
