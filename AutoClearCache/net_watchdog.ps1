# ===========================================================================
# Genesis Autonomous Network Watchdog v2.0
# Execution Environment: SYSTEM Task (Isolated in C:\Genesis)
# Independent of OneDrive, User Sessions, and server.py
# ===========================================================================

param (
    [string]$TargetSSID = "KMITL-HiSpeed",
    [string]$AdapterName = "Wi-Fi",
    [int]$CheckIntervalSeconds = 30,
    [string]$RuntimeDir = "C:\Genesis"
)

# Ensure runtime directory exists
if (-not (Test-Path $RuntimeDir)) {
    New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
}

$TextLogPath = Join-Path $RuntimeDir "watchdog.log"
$GenesisHistoryPath = "C:\Users\rocke\OneDrive\Documents\GitHub\Genesis\AutoClearCache\data\history.json"

function Write-WatchdogLog([string]$level, [string]$message) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp] [$level] $message"
    
    # 1. Always write to standalone local text log (Reliable, no sync conflict)
    try {
        Add-Content -Path $TextLogPath -Value $logLine -Encoding utf8 -ErrorAction SilentlyContinue
    } catch {}

    # 2. Best-effort append to Genesis Dashboard history.json
    try {
        if (Test-Path $GenesisHistoryPath) {
            $raw = Get-Content -Raw $GenesisHistoryPath -ErrorAction SilentlyContinue
            $events = @()
            if ($raw) {
                $parsed = ConvertFrom-Json $raw -ErrorAction SilentlyContinue
                if ($parsed) { $events = @($parsed) }
            }
            $newEntry = [PSCustomObject]@{
                time = $timestamp
                type = if ($level -eq "ERROR" -or $level -eq "CRITICAL") { "crash" } elseif ($level -eq "WARN") { "warning" } else { "system" }
                message = "🐕 [Watchdog] $message"
            }
            $events += $newEntry
            if ($events.Count -gt 500) {
                $events = $events[($events.Count - 500)..($events.Count - 1)]
            }
            $json = ConvertTo-Json $events -Depth 4
            Set-Content -Path $GenesisHistoryPath -Value $json -Encoding utf8 -Force -ErrorAction SilentlyContinue
        }
    } catch {}
}

function Test-InternetConnectivity {
    # Check 1: ICMP Ping to Cloudflare DNS
    if (Test-Connection -ComputerName "1.1.1.1" -Count 1 -Quiet -TimeoutSeconds 2 -ErrorAction SilentlyContinue) {
        return $true
    }
    # Check 2: ICMP Ping to Google DNS
    if (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -TimeoutSeconds 2 -ErrorAction SilentlyContinue) {
        return $true
    }
    # Check 3: TCP Port 443 Fallback (Bypasses ICMP filtering on campus networks)
    foreach ($ip in @("1.1.1.1", "8.8.8.8")) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $async = $tcp.BeginConnect($ip, 443, $null, $null)
            $wait = $async.AsyncWaitHandle.WaitOne(2000, $false)
            if ($wait -and $tcp.Connected) {
                $tcp.Close()
                return $true
            }
            $tcp.Close()
        } catch {}
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
$LastRestartTime = [DateTime]::MinValue
$WasOffline = $false

while ($true) {
    try {
        $isOnline = Test-InternetConnectivity
        
        if ($isOnline) {
            if ($WasOffline) {
                Write-WatchdogLog "INFO" "✅ Internet connectivity restored (after $ConsecutiveFails consecutive fails, $RestartAttempts adapter restarts)."
                $WasOffline = $false
                $ConsecutiveFails = 0
                $RestartAttempts = 0
            }
        } else {
            $ConsecutiveFails++
            $WasOffline = $true

            # Level 1: Re-issue connection request after 3 consecutive failures (~90s)
            if ($ConsecutiveFails -eq 3) {
                Write-WatchdogLog "WARN" "⚠️ Offline for 90s. Level 1 recovery: Sending netsh connect to '$TargetSSID' on interface '$AdapterName'..."
                netsh wlan connect name="$TargetSSID" interface="$AdapterName" | Out-Null
            }
            
            # Level 2: Restart Wi-Fi Adapter with Exponential Backoff (Max 3 attempts)
            # Attempt 1 @ 6 fails (~3 min), Attempt 2 @ 12 fails (~6 min), Attempt 3 @ 24 fails (~12 min)
            $shouldRestart = ($ConsecutiveFails -eq 6 -or $ConsecutiveFails -eq 12 -or $ConsecutiveFails -eq 24) -and ($RestartAttempts -lt $MaxRestartAttempts)
            
            if ($shouldRestart) {
                $RestartAttempts++
                Write-WatchdogLog "CRITICAL" "🚨 Offline for $($ConsecutiveFails * 30)s. Level 2 recovery (Attempt $RestartAttempts/$MaxRestartAttempts): Soft-restarting adapter '$AdapterName'..."
                
                Restart-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 10
                netsh wlan connect name="$TargetSSID" interface="$AdapterName" | Out-Null
                $LastRestartTime = Get-Date
            }
            
            # Outage Exhaustion: Reached max restarts (e.g. campus-wide AP outage)
            if ($RestartAttempts -ge $MaxRestartAttempts -and ($ConsecutiveFails % 20 -eq 0)) {
                Write-WatchdogLog "WARN" "⏳ Max adapter restarts reached ($MaxRestartAttempts/$MaxRestartAttempts). Campus network likely down. Passive polling continues..."
            }
        }
    } catch {
        Write-WatchdogLog "ERROR" "Unhandled exception in watchdog loop: $_"
    }

    Start-Sleep -Seconds $CheckIntervalSeconds
}
