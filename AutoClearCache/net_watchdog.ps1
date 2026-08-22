# ===========================================================================
# Genesis Standalone Network Watchdog v1.0
# Runs independently as Windows SYSTEM Task at Boot
# Self-healing Wi-Fi connection with ICMP + TCP Dual-Check
# ===========================================================================

param (
    [string]$TargetSSID = "KMITL-HiSpeed",
    [string]$AdapterName = "Wi-Fi",
    [int]$CheckIntervalSeconds = 30
)

$LogPath = "C:\Users\rocke\OneDrive\Documents\GitHub\Genesis\AutoClearCache\data\history.json"

function Add-WatchdogLog([string]$type, [string]$message) {
    try {
        $events = @()
        if (Test-Path $LogPath) {
            $raw = Get-Content -Raw $LogPath -ErrorAction SilentlyContinue
            if ($raw) {
                $parsed = ConvertFrom-Json $raw -ErrorAction SilentlyContinue
                if ($parsed -is [System.Collections.IEnumerable]) {
                    $events = @($parsed)
                } elseif ($parsed) {
                    $events = @($parsed)
                }
            }
        }
        $newEntry = [PSCustomObject]@{
            time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            type = $type
            message = "🐕 [Watchdog] $message"
        }
        $events += $newEntry
        if ($events.Count -gt 500) {
            $events = $events[($events.Count - 500)..($events.Count - 1)]
        }
        $json = ConvertTo-Json $events -Depth 4
        Set-Content -Path $LogPath -Value $json -Encoding utf8 -Force
    } catch {
        # Silent fallback - never crash watchdog on logging error
    }
}

function Test-InternetConnection {
    # Check 1: ICMP Ping Cloudflare DNS (1.1.1.1)
    if (Test-Connection -ComputerName "1.1.1.1" -Count 1 -Quiet -TimeoutSeconds 2) {
        return $true
    }
    # Check 2: ICMP Ping Google DNS (8.8.8.8)
    if (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -TimeoutSeconds 2) {
        return $true
    }
    # Check 3: TCP Port 443 Fallback (Bypasses ICMP block)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect("1.1.1.1", 443, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait -and $tcp.Connected) {
            $tcp.Close()
            return $true
        }
        $tcp.Close()
    } catch {}

    return $false
}

# Initial Boot Grace Period (Wait for initial services to settle)
Start-Sleep -Seconds 20
Add-WatchdogLog "system" "Network Watchdog started (Target SSID: $TargetSSID)"

$FailCount = 0
$WasDegraded = $false

while ($true) {
    try {
        $isOnline = Test-InternetConnection
        if ($isOnline) {
            if ($WasDegraded) {
                Add-WatchdogLog "system" "✅ Internet connectivity restored successfully (after $FailCount consecutive failures)"
                $WasDegraded = $false
            }
            $FailCount = 0
        } else {
            $FailCount++
            $WasDegraded = $true

            if ($FailCount -eq 3) {
                # Level 1 (~90s offline): Re-issue WLAN Connect command
                Add-WatchdogLog "warning" "⚠️ Connection offline for 90s — executing Level 1 recovery (netsh connect to $TargetSSID)"
                netsh wlan connect name="$TargetSSID" | Out-Null
            } elseif ($FailCount -ge 6 -and ($FailCount % 6 -eq 0)) {
                # Level 2 (~180s offline): Soft-reset Network Adapter
                Add-WatchdogLog "crash" "🚨 Connection offline for $($FailCount * 30)s — executing Level 2 recovery (Restart-NetAdapter $AdapterName)"
                Restart-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 10
                netsh wlan connect name="$TargetSSID" | Out-Null
            }
        }
    } catch {
        # Loop safety guard
    }

    Start-Sleep -Seconds $CheckIntervalSeconds
}
