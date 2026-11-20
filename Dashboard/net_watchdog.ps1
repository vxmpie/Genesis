# ===========================================================================
# Genesis Autonomous Network & Service Watchdog v2.3
# Execution Environment: SYSTEM Task (Isolated in C:\Genesis)
# Compatible with Windows PowerShell 5.1 & PowerShell Core
# ===========================================================================

param (
    [string]$TargetSSID = "KMITL-HiSpeed",
    [string]$AdapterName = "Wi-Fi",
    [int]$CheckIntervalSeconds = 30,
    [string]$RuntimeDir = "C:\Genesis",
    [string[]]$CriticalServices = @("StarDeskService", "AnyDesk"),
    [int]$ServiceCooldownSeconds = 60,
    [string]$DashboardHost = "127.0.0.1",
    [int]$DashboardPort = 7700,
    [int]$DashboardWarnThreshold = 6
)

if (-not (Test-Path $RuntimeDir)) {
    New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
}

$LogPath = Join-Path $RuntimeDir "watchdog.log"
$LogOldPath = Join-Path $RuntimeDir "watchdog.log.old"
$script:ServiceLastRestart = @{}

# --- Log Management ---
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

# --- Connectivity & Service Checks ---
function Test-InternetConnectivity {
    $pinger = New-Object System.Net.NetworkInformation.Ping
    try {
        foreach ($ip in @("1.1.1.1", "8.8.8.8")) {
            try {
                $reply = $pinger.Send($ip, 2000)
                if ($reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                    return $true
                }
            } catch {}
        }
    } finally {
        $pinger.Dispose()
    }

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

function Test-CriticalServices {
    foreach ($svcName in $CriticalServices) {
        if ([string]::IsNullOrWhiteSpace($svcName)) {
            continue
        }

        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            continue
        }

        if ($svc.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
            $now = Get-Date
            if ($script:ServiceLastRestart.ContainsKey($svcName)) {
                $elapsed = ($now - $script:ServiceLastRestart[$svcName]).TotalSeconds
                if ($elapsed -lt $ServiceCooldownSeconds) {
                    continue
                }
            }

            $script:ServiceLastRestart[$svcName] = $now
            try {
                Start-Service -Name $svcName -ErrorAction Stop
                Start-Sleep -Seconds 2
                $recheck = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                if ($recheck -and $recheck.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
                    Write-WatchdogLog "INFO" "[SERVICE-RECOVERED] Started critical service '$svcName' (previous status: $($svc.Status))."
                } else {
                    $statusText = if ($recheck) { $recheck.Status } else { "Unknown" }
                    Write-WatchdogLog "ERROR" "[SERVICE-ERROR] Attempted to start '$svcName' but current status is '$statusText'."
                }
            } catch {
                Write-WatchdogLog "ERROR" "[SERVICE-ERROR] Failed to start '$svcName': $_"
            }
        }
    }
}

function Test-DashboardPort([string]$TargetHost, [int]$Port) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $tcp.BeginConnect($TargetHost, $Port, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne(1500, $false)
        if ($wait -and $tcp.Connected) {
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        $tcp.Close()
    }
}

# --- Single-Instance Mutex Guard ---
$MutexName = "Global\GenesisNetworkWatchdogMutex"
$mutex = $null
$hasMutex = $false

try {
    $mutex = New-Object System.Threading.Mutex($false, $MutexName)
    try {
        $hasMutex = $mutex.WaitOne(0, $false)
    } catch [System.Threading.AbandonedMutexException] {
        $hasMutex = $true
        Write-WatchdogLog "WARN" "Acquired abandoned global watchdog mutex."
    }
} catch [System.UnauthorizedAccessException] {
    Write-WatchdogLog "INFO" "Another watchdog instance holds the global mutex. Exiting duplicate."
    exit 0
} catch {
    Write-WatchdogLog "ERROR" "Failed to initialize watchdog mutex: $_"
    exit 1
}

if (-not $hasMutex) {
    Write-WatchdogLog "INFO" "Another watchdog instance is already running. Exiting duplicate."
    if ($mutex) {
        $mutex.Dispose()
    }
    exit 0
}

try {
    # --- Boot Grace Period ---
    Write-WatchdogLog "INFO" "Watchdog initialized at boot. Entering 120s grace period..."
    Start-Sleep -Seconds 120
    Write-WatchdogLog "INFO" "Grace period ended. Active monitoring started (Target: $TargetSSID on $AdapterName)."

    $ConsecutiveFails = 0
    $RestartAttempts = 0
    $MaxRestartAttempts = 3
    $WasOffline = $false
    $DashboardConsecutiveFails = 0
    $DashboardWasDown = $false

    # --- Main Watchdog Loop ---
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

                if ($ConsecutiveFails -eq 3) {
                    Write-WatchdogLog "WARN" "[LEVEL 1] Offline for 90s. Reconnecting to '$TargetSSID' on interface '$AdapterName'..."
                    netsh wlan connect name="$TargetSSID" interface="$AdapterName" | Out-Null
                }

                $shouldRestart = ($ConsecutiveFails -eq 6 -or $ConsecutiveFails -eq 12 -or $ConsecutiveFails -eq 24) -and ($RestartAttempts -lt $MaxRestartAttempts)

                if ($shouldRestart) {
                    $RestartAttempts++
                    Write-WatchdogLog "CRITICAL" "[LEVEL 2] Offline for $($ConsecutiveFails * 30)s. Soft-restarting adapter '$AdapterName' (Attempt $RestartAttempts/$MaxRestartAttempts)..."

                    Restart-NetAdapter -Name $AdapterName -Confirm:$false -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 10
                    netsh wlan connect name="$TargetSSID" interface="$AdapterName" | Out-Null
                }

                if ($RestartAttempts -ge $MaxRestartAttempts -and ($ConsecutiveFails % 20 -eq 0)) {
                    Write-WatchdogLog "WARN" "[SUSPENDED] Max adapter restarts reached ($MaxRestartAttempts/$MaxRestartAttempts). Campus network likely down. Passive polling continues..."
                }
            }
        } catch {
            Write-WatchdogLog "ERROR" "Unhandled exception in network monitor loop: $_"
        }

        try {
            Test-CriticalServices
        } catch {
            Write-WatchdogLog "ERROR" "Unhandled exception in service watchdog check: $_"
        }

        try {
            $isDashboardUp = Test-DashboardPort -TargetHost $DashboardHost -Port $DashboardPort
            if ($isDashboardUp) {
                if ($DashboardWasDown) {
                    Write-WatchdogLog "INFO" "[DASHBOARD-RECOVERED] Dashboard on ${DashboardHost}:${DashboardPort} is reachable again (after $DashboardConsecutiveFails failed checks)."
                }
                $DashboardConsecutiveFails = 0
                $DashboardWasDown = $false
            } else {
                $DashboardConsecutiveFails++
                if ($DashboardConsecutiveFails -ge $DashboardWarnThreshold) {
                    $DashboardWasDown = $true
                    if ($DashboardConsecutiveFails -eq $DashboardWarnThreshold -or ($DashboardConsecutiveFails % 10 -eq 0)) {
                        Write-WatchdogLog "WARN" "[WARN] Dashboard on ${DashboardHost}:${DashboardPort} unresponsive for $DashboardConsecutiveFails consecutive cycles (~$($DashboardConsecutiveFails * $CheckIntervalSeconds)s)."
                    }
                }
            }
        } catch {
            Write-WatchdogLog "ERROR" "Unhandled exception in passive dashboard check: $_"
        }

        Start-Sleep -Seconds $CheckIntervalSeconds
    }
} finally {
    if ($hasMutex -and $mutex) {
        try {
            $mutex.ReleaseMutex()
        } catch {}
    }
    if ($mutex) {
        try {
            $mutex.Dispose()
        } catch {}
    }
}
