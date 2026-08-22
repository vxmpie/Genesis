# ===========================================================================
# Genesis Autonomous Network Watchdog v2.1
# Execution Environment: SYSTEM Task (Isolated in C:\Genesis)
# Independent of OneDrive, User Sessions, and server.py
# Compatible with Windows PowerShell 5.1 & PowerShell Core
# ===========================================================================

param (
    [string]$TargetSSID = "KMITL-HiSpeed",
    [string]$AdapterName = "Wi-Fi",
    [int]$CheckIntervalSeconds = 30,
    [string]$RuntimeDir = "C:\Genesis"
)

# Ensure isolated runtime directory exists
if (-not (Test-Path $RuntimeDir)) {
    New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
}

$LogPath = Join-Path $RuntimeDir "watchdog.log"
$LogOldPath = Join-Path $RuntimeDir "watchdog.log.old"

# Log Rotation: Cap at 5MB
function Rotate-LogIfNeeded {
    try {
        if (Test-Path $LogPath) {
            $item = Get-Item $LogPath -ErrorAction SilentlyContinue
            if ($item -and $item.Length -gt 5242880) {
                Move-Item -Path $LogPath -Destination $LogOldPath -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

function Write-WatchdogLog([string]$level, [string]$message) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp] [$level] $message"
    
    Rotate-LogIfNeeded
    try {
        Add-Content -Path $LogPath -Value $logLine -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {}
}

function Test-InternetConnectivity {
    # Check 1 & 2: ICMP via .NET Ping (Pure .NET - 100% compatible with PowerShell 5.1)
    $pinger = New-Object System.Net.NetworkInformation.Ping
    foreach ($ip in @("1.1.1.1", "8.8.8.8")) {
        try {
            $reply = $pinger.Send($ip, 2000)
            if ($reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                return $true
            }
        } catch {}
    }

    # Check 3: TCP Port 443 Fallback (Bypasses ICMP filtering on campus firewalls)
    foreach ($ip in @("1.1.1.1", "8.8.8.8")) {
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $async = $tcp.BeginConnect($ip, 443, $null, $null)
            $wait = $async.AsyncWaitHandle.WaitOne(2000, $false)
            if ($wait -and $tcp.Connected) {
                return $true
            }
        } catch {} finally {
            $tcp.Close()
        }
    }

    return $false
}

# ---------------------------------------------------------------------------
# Boot Grace Period (120 seconds)
# Allows Windows 802.1X Enterprise Handshake and DHCP to complete naturally
# ---------------------------------------------------------------------------
Write-WatchdogLog "INFO" "Watchdog initialized at boot. Entering 120s grace period..."
Start-Sleep -Seconds 120
Write-WatchdogLog "INFO" "Grace period ended. Active monitoring started (Target: $TargetSSID on $AdapterName)."

$ConsecutiveFails = 0
$RestartAttempts = 0
$MaxRestartAttempts = 3
$WasOffline = $false

while ($true) {
    try {
        $isOnline = Test-InternetConnectivity
        
        if ($isOnline) {
            if ($WasOffline) {
                Write-WatchdogLog "INFO" "[RECOVERED] Internet connectivity restored (after $ConsecutiveFails consecutive fails, $RestartAttempts adapter restarts)."
                $WasOffline = $false
                $ConsecutiveFails = 0
                $RestartAttempts = 0
            }
        } else {
            $ConsecutiveFails++
            $WasOffline = $true

            # Level 1: Re-issue connection request after 3 consecutive failures (~90s)
            if ($ConsecutiveFails -eq 3) {
                Write-WatchdogLog "WARN" "[LEVEL 1] Offline for 90s. Reconnecting to '$TargetSSID' on interface '$AdapterName'..."
                netsh wlan connect name="$TargetSSID" interface="$AdapterName" | Out-Null
            }
            
            # Level 2: Restart Wi-Fi Adapter with Exponential Backoff (Max 3 attempts)
            # Attempt 1 @ 6 fails (~3 min), Attempt 2 @ 12 fails (~6 min), Attempt 3 @ 24 fails (~12 min)
            $shouldRestart = ($ConsecutiveFails -eq 6 -or $ConsecutiveFails -eq 12 -or $ConsecutiveFails -eq 24) -and ($RestartAttempts -lt $MaxRestartAttempts)
            
            if ($shouldRestart) {
                $RestartAttempts++
                Write-WatchdogLog "CRITICAL" "[LEVEL 2] Offline for $($ConsecutiveFails * 30)s. Soft-restarting adapter '$AdapterName' (Attempt $RestartAttempts/$MaxRestartAttempts)..."
                
                Restart-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 10
                netsh wlan connect name="$TargetSSID" interface="$AdapterName" | Out-Null
            }
            
            # Outage Exhaustion: Reached max restarts (e.g. campus-wide AP outage)
            if ($RestartAttempts -ge $MaxRestartAttempts -and ($ConsecutiveFails % 20 -eq 0)) {
                Write-WatchdogLog "WARN" "[SUSPENDED] Max adapter restarts reached ($MaxRestartAttempts/$MaxRestartAttempts). Campus network likely down. Passive polling continues..."
            }
        }
    } catch {
        Write-WatchdogLog "ERROR" "Unhandled exception in watchdog loop: $_"
    }

    Start-Sleep -Seconds $CheckIntervalSeconds
}
