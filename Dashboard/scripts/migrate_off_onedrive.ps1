# ===========================================================================
# Genesis OneDrive Exit & Local Directory Migration Tool
# Compatible with Windows PowerShell 5.1 & PowerShell Core
# ===========================================================================

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("CheckOnly", "Hydrate", "Migrate", "Verify", "DisableOneDrive")]
    [string]$Mode,

    [string]$OneDriveRoot = (Join-Path $env:USERPROFILE "OneDrive"),
    [string]$DevRoot = "C:\Dev",
    [string]$ArchiveRoot = (Join-Path $env:USERPROFILE "OneDriveArchive"),
    [int]$HydratePollIntervalSeconds = 10,
    [int]$HydrateTimeoutMinutes = 30
)

# --- Constants & Folder Mapping ---
$DesktopThaiName = -join ([char[]](0x0E40, 0x0E14, 0x0E2A, 0x0E01, 0x0E4C, 0x0E17, 0x0E47, 0x0E2D, 0x0E1B))
$PicturesThaiName = -join ([char[]](0x0E23, 0x0E39, 0x0E1B, 0x0E20, 0x0E32, 0x0E1E))
$ThaiVaultName = -join ([char[]](0x0E17, 0x0E35, 0x0E48, 0x0E40, 0x0E01, 0x0E47, 0x0E1A, 0x0E19, 0x0E34, 0x0E23, 0x0E20, 0x0E31, 0x0E22, 0x0E2A, 0x0E48, 0x0E27, 0x0E19, 0x0E15, 0x0E31, 0x0E27))

$DesktopSrc = Join-Path $OneDriveRoot $DesktopThaiName
if (-not (Test-Path -LiteralPath $DesktopSrc)) {
    $DesktopSrc = Join-Path $OneDriveRoot "Desktop"
}

$PicturesSrc = Join-Path $OneDriveRoot $PicturesThaiName
if (-not (Test-Path -LiteralPath $PicturesSrc)) {
    $PicturesSrc = Join-Path $OneDriveRoot "Pictures"
}

$GitHubSrc = Join-Path $OneDriveRoot "Documents\GitHub"
$DocumentsSrc = Join-Path $OneDriveRoot "Documents"

$MigrationMap = @(
    @{
        Name             = "GitHub"
        Source           = $GitHubSrc
        Destination      = $DevRoot
        ExcludeDirs      = @()
        ExcludeFiles     = @()
    },
    @{
        Name             = "Desktop"
        Source           = $DesktopSrc
        Destination      = (Join-Path $env:USERPROFILE "Desktop")
        ExcludeDirs      = @()
        ExcludeFiles     = @("desktop.ini")
    },
    @{
        Name             = "Pictures"
        Source           = $PicturesSrc
        Destination      = (Join-Path $env:USERPROFILE "Pictures")
        ExcludeDirs      = @()
        ExcludeFiles     = @("desktop.ini")
    },
    @{
        Name             = "Documents"
        Source           = $DocumentsSrc
        Destination      = (Join-Path $env:USERPROFILE "Documents")
        ExcludeDirs      = @($GitHubSrc)
        ExcludeFiles     = @("desktop.ini")
    },
    @{
        Name             = ".LOGOComfort7.0"
        Source           = (Join-Path $OneDriveRoot ".LOGOComfort7.0")
        Destination      = (Join-Path $ArchiveRoot ".LOGOComfort7.0")
        ExcludeDirs      = @()
        ExcludeFiles     = @()
    },
    @{
        Name             = "Apps"
        Source           = (Join-Path $OneDriveRoot "Apps")
        Destination      = (Join-Path $ArchiveRoot "Apps")
        ExcludeDirs      = @()
        ExcludeFiles     = @()
    },
    @{
        Name             = "Attachments"
        Source           = (Join-Path $OneDriveRoot "Attachments")
        Destination      = (Join-Path $ArchiveRoot "Attachments")
        ExcludeDirs      = @()
        ExcludeFiles     = @()
    },
    @{
        Name             = "Videos"
        Source           = (Join-Path $OneDriveRoot "Videos")
        Destination      = (Join-Path $ArchiveRoot "Videos")
        ExcludeDirs      = @()
        ExcludeFiles     = @()
    }
)

# --- Long-Path File Scanner ---
function ConvertTo-LongPath([string]$Path) {
    if ([string]::IsNullOrEmpty($Path)) { return $Path }
    if ($Path.StartsWith("\\?\")) { return $Path }
    if ($Path.StartsWith("\\")) { return "\\?\UNC\" + $Path.Substring(2) }
    return "\\?\" + $Path
}

function ConvertFrom-LongPath([string]$Path) {
    if ([string]::IsNullOrEmpty($Path)) { return $Path }
    if ($Path.StartsWith("\\?\UNC\")) { return "\\" + $Path.Substring(8) }
    if ($Path.StartsWith("\\?\")) { return $Path.Substring(4) }
    return $Path
}

function Test-IsVaultShortcut([string]$FileName) {
    if ($FileName -like "Personal Vault*.lnk") { return $true }
    if ($FileName -like "$ThaiVaultName*.lnk") { return $true }
    return $false
}

function Test-IsCloudOnlyAttribute([System.IO.FileAttributes]$Attributes) {
    $attrInt = [int]$Attributes
    return ((($attrInt -band 0x400000) -ne 0) -or (($attrInt -band 0x1000) -ne 0))
}

function Get-DirectoryStats {
    param (
        [string]$RootPath,
        [string[]]$ExcludeDirs = @(),
        [string[]]$ExcludeFiles = @()
    )

    $result = [PSCustomObject]@{
        Exists         = $false
        FileCount      = [long]0
        TotalBytes     = [long]0
        CloudOnlyCount = [long]0
        CloudOnlyPaths = [System.Collections.Generic.List[string]]::new()
        AccessErrors   = [System.Collections.Generic.List[string]]::new()
    }

    if (-not (Test-Path -LiteralPath $RootPath)) {
        return $result
    }
    $result.Exists = $true

    $normalizedExcludes = @()
    foreach ($ex in $ExcludeDirs) {
        if (-not [string]::IsNullOrWhiteSpace($ex)) {
            $normalizedExcludes += $ex.TrimEnd("\").ToLowerInvariant()
        }
    }

    $excludeFileSet = @{}
    foreach ($ef in $ExcludeFiles) {
        if (-not [string]::IsNullOrWhiteSpace($ef)) {
            $excludeFileSet[$ef.ToLowerInvariant()] = $true
        }
    }

    $stack = [System.Collections.Generic.Stack[object]]::new()
    $stack.Push(@{ Path = $RootPath.TrimEnd("\"); Depth = 0 })

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        $dirPath = $current.Path
        $depth = $current.Depth
        $longDir = ConvertTo-LongPath $dirPath

        try {
            $dirInfo = New-Object System.IO.DirectoryInfo($longDir)
            foreach ($entry in $dirInfo.EnumerateFileSystemInfos()) {
                if ($entry -is [System.IO.DirectoryInfo]) {
                    if ($depth -lt 128) {
                        $subPath = ConvertFrom-LongPath $entry.FullName
                        if ($normalizedExcludes -notcontains $subPath.TrimEnd("\").ToLowerInvariant()) {
                            $stack.Push(@{ Path = $subPath; Depth = ($depth + 1) })
                        }
                    }
                } elseif ($entry -is [System.IO.FileInfo]) {
                    $nameLower = $entry.Name.ToLowerInvariant()
                    if ($excludeFileSet.ContainsKey($nameLower)) {
                        continue
                    }
                    if (Test-IsVaultShortcut $entry.Name) {
                        continue
                    }

                    $result.FileCount++
                    $result.TotalBytes += $entry.Length

                    if (Test-IsCloudOnlyAttribute $entry.Attributes) {
                        $result.CloudOnlyCount++
                        if ($result.CloudOnlyPaths.Count -lt 25) {
                            $result.CloudOnlyPaths.Add((ConvertFrom-LongPath $entry.FullName))
                        }
                    }
                }
            }
        } catch {
            if ($result.AccessErrors.Count -lt 20) {
                $result.AccessErrors.Add("$dirPath => $($_.Exception.Message)")
            }
        }
    }

    return $result
}

function Get-AllSourceSummary {
    $summaries = @()
    $totalFiles = [long]0
    $totalBytes = [long]0
    $totalCloudOnly = [long]0
    $allCloudPaths = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $MigrationMap) {
        $stats = Get-DirectoryStats -RootPath $entry.Source -ExcludeDirs $entry.ExcludeDirs -ExcludeFiles $entry.ExcludeFiles
        $summaries += [PSCustomObject]@{
            Name           = $entry.Name
            Source         = $entry.Source
            Destination    = $entry.Destination
            Exists         = $stats.Exists
            FileCount      = $stats.FileCount
            TotalBytes     = $stats.TotalBytes
            CloudOnlyCount = $stats.CloudOnlyCount
            AccessErrors   = $stats.AccessErrors
        }
        $totalFiles += $stats.FileCount
        $totalBytes += $stats.TotalBytes
        $totalCloudOnly += $stats.CloudOnlyCount
        foreach ($p in $stats.CloudOnlyPaths) {
            if ($allCloudPaths.Count -lt 25) {
                $allCloudPaths.Add($p)
            }
        }
    }

    return [PSCustomObject]@{
        Entries        = $summaries
        TotalFiles     = $totalFiles
        TotalBytes     = $totalBytes
        CloudOnlyFiles = $totalCloudOnly
        CloudOnlyPaths = $allCloudPaths
    }
}

function Format-SizeText([long]$Bytes) {
    if ($Bytes -ge 1GB) {
        return ("{0:N2} GB" -f ($Bytes / 1GB))
    }
    return ("{0:N2} MB" -f ($Bytes / 1MB))
}

function Get-OneDriveLockingProcesses {
    $escapedRoot = [regex]::Escape($OneDriveRoot)
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -in @("OneDrive.exe", "MuMuNxMain.exe", "MuMuVMMHeadless.exe", "python.exe")) -or
        ($_.CommandLine -and $_.CommandLine -match $escapedRoot) -or
        ($_.ExecutablePath -and $_.ExecutablePath -match $escapedRoot)
    }
    return $procs
}

function Invoke-RobocopySafe {
    param (
        [string]$Source,
        [string]$Destination,
        [string[]]$ExcludeDirs = @(),
        [string[]]$ExcludeFiles = @()
    )

    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    $args = @($Source, $Destination, "/E", "/COPY:DAT", "/R:2", "/W:2", "/MT:16", "/NFL", "/NDL", "/NP")
    if ($ExcludeDirs.Count -gt 0) {
        $args += "/XD"
        foreach ($xd in $ExcludeDirs) {
            $args += $xd
        }
    }
    if ($ExcludeFiles.Count -gt 0) {
        $args += "/XF"
        foreach ($xf in $ExcludeFiles) {
            $args += $xf
        }
    }

    & robocopy @args | Out-Host
    $exitCode = $LASTEXITCODE
    if ($exitCode -ge 8) {
        throw "Robocopy failed for '$Source' -> '$Destination' with exit code $exitCode"
    }
    return $exitCode
}

# --- Mode: CheckOnly ---
function Invoke-CheckOnly {
    Write-Host ""
    Write-Host "=== OneDrive Migration Pre-Flight Check ===" -ForegroundColor Cyan
    $summary = Get-AllSourceSummary

    foreach ($item in $summary.Entries) {
        if (-not $item.Exists) {
            Write-Host ("  [SKIP] {0,-16} (Not found: {1})" -f $item.Name, $item.Source) -ForegroundColor DarkGray
            continue
        }
        $sizeStr = Format-SizeText $item.TotalBytes
        $color = if ($item.CloudOnlyCount -gt 0) { "Yellow" } else { "Green" }
        Write-Host ("  [{0,-16}] Files: {1,7} | Size: {2,10} | CloudOnly: {3}" -f $item.Name, $item.FileCount, $sizeStr, $item.CloudOnlyCount) -ForegroundColor $color
        foreach ($err in $item.AccessErrors) {
            Write-Host "    [ACCESS-ERR] $err" -ForegroundColor Red
        }
    }

    $driveC = Get-PSDrive -Name "C"
    Write-Host ""
    Write-Host ("Total Mapped Files : {0}" -f $summary.TotalFiles)
    Write-Host ("Total Mapped Size  : {0}" -f (Format-SizeText $summary.TotalBytes))
    Write-Host ("CloudOnlyFiles     : {0}" -f $summary.CloudOnlyFiles) -ForegroundColor $(if ($summary.CloudOnlyFiles -gt 0) { "Yellow" } else { "Green" })
    Write-Host ("Drive C Free Space : {0}" -f (Format-SizeText $driveC.Free))

    if ($summary.CloudOnlyPaths.Count -gt 0) {
        Write-Host ""
        Write-Host "Sample Cloud-Only Files:" -ForegroundColor Yellow
        foreach ($sample in $summary.CloudOnlyPaths) {
            Write-Host "  - $sample"
        }
    }

    Write-Host ""
    Write-Host "Active Processes Using OneDrive or Known Lock Holders:" -ForegroundColor Cyan
    $procs = Get-OneDriveLockingProcesses
    if (-not $procs) {
        Write-Host "  (None detected)" -ForegroundColor Green
    } else {
        foreach ($p in $procs) {
            Write-Host ("  - PID {0,-6} {1,-24} {2}" -f $p.ProcessId, $p.Name, $p.CommandLine)
        }
    }
    Write-Host ""
}

# --- Mode: Hydrate ---
function Invoke-Hydrate {
    Write-Host ""
    Write-Host "=== Hydrating OneDrive Cloud-Only Files ===" -ForegroundColor Cyan

    $odProc = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    if (-not $odProc) {
        $odCandidates = @(
            (Join-Path $env:ProgramFiles "Microsoft OneDrive\OneDrive.exe"),
            (Join-Path ${env:ProgramFiles(x86)} "Microsoft OneDrive\OneDrive.exe"),
            (Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive\OneDrive.exe")
        )
        $odExe = $odCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
        if (-not $odExe) {
            Write-Host "[ERROR] OneDrive.exe is not running and executable was not found." -ForegroundColor Red
            exit 1
        }
        Write-Host "  [LAUNCH] Starting OneDrive.exe from $odExe..." -ForegroundColor Yellow
        Start-Process -FilePath $odExe
        Start-Sleep -Seconds 5
        $odProc = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        if (-not $odProc) {
            Write-Host "[ERROR] Failed to start OneDrive.exe. Please open OneDrive manually and retry." -ForegroundColor Red
            exit 1
        }
        Write-Host "  [OK] OneDrive.exe started." -ForegroundColor Green
    }

    Write-Host "  [SCAN] Checking folders with pending Cloud-Only files..." -ForegroundColor Cyan
    $initialSummary = Get-AllSourceSummary
    $pendingNames = @($initialSummary.Entries | Where-Object { $_.Exists -and $_.CloudOnlyCount -gt 0 } | ForEach-Object { $_.Name })
    $pendingEntries = @($MigrationMap | Where-Object { $pendingNames -contains $_.Name })

    if ($pendingEntries.Count -eq 0) {
        Write-Host "[OK] Hydration already complete: CloudOnlyFiles == 0" -ForegroundColor Green
        return
    }

    foreach ($entry in $pendingEntries) {
        if ($entry.ExcludeDirs.Count -gt 0) {
            $excludedLower = @($entry.ExcludeDirs | ForEach-Object { $_.TrimEnd("\").ToLowerInvariant() })
            Write-Host "  [PIN] $($entry.Name) (excluding $($entry.ExcludeDirs -join ', '))" -ForegroundColor Yellow
            & attrib.exe +P -U "$($entry.Source)" 2>&1 | Out-Null
            $children = Get-ChildItem -LiteralPath $entry.Source -Force -ErrorAction SilentlyContinue
            foreach ($child in $children) {
                $childLower = $child.FullName.TrimEnd("\").ToLowerInvariant()
                if ($excludedLower -contains $childLower) {
                    continue
                }
                if (Test-IsVaultShortcut $child.Name) {
                    continue
                }
                if ($child.PSIsContainer) {
                    & attrib.exe +P -U "$($child.FullName)" 2>&1 | Out-Null
                    & attrib.exe +P -U "$($child.FullName)\*" /S /D 2>&1 | Out-Null
                } else {
                    & attrib.exe +P -U "$($child.FullName)" 2>&1 | Out-Null
                }
            }
        } else {
            Write-Host "  [PIN] $($entry.Name) ($($entry.Source))" -ForegroundColor Yellow
            & attrib.exe +P -U "$($entry.Source)" 2>&1 | Out-Null
            & attrib.exe +P -U "$($entry.Source)\*" /S /D 2>&1 | Out-Null
        }
    }

    $deadline = (Get-Date).AddMinutes($HydrateTimeoutMinutes)
    while ($true) {
        $remaining = [long]0
        $remainingPaths = [System.Collections.Generic.List[string]]::new()
        $folderBreakdown = [System.Collections.Generic.List[string]]::new()

        foreach ($entry in $pendingEntries) {
            $stats = Get-DirectoryStats -RootPath $entry.Source -ExcludeDirs $entry.ExcludeDirs -ExcludeFiles $entry.ExcludeFiles
            $remaining += $stats.CloudOnlyCount
            if ($stats.CloudOnlyCount -gt 0) {
                $folderBreakdown.Add("$($entry.Name)=$($stats.CloudOnlyCount)")
            }
            foreach ($p in $stats.CloudOnlyPaths) {
                if ($remainingPaths.Count -lt 25) {
                    $remainingPaths.Add($p)
                }
            }
        }

        $detailText = if ($folderBreakdown.Count -gt 0) { " (" + ($folderBreakdown -join ", ") + ")" } else { "" }
        Write-Host ("[{0}] Remaining CloudOnlyFiles: {1}{2}" -f (Get-Date).ToString("HH:mm:ss"), $remaining, $detailText) -ForegroundColor $(if ($remaining -eq 0) { "Green" } else { "Yellow" })

        if ($remaining -eq 0) {
            $finalSummary = Get-AllSourceSummary
            if ($finalSummary.CloudOnlyFiles -eq 0) {
                Write-Host "[OK] Hydration complete: CloudOnlyFiles == 0" -ForegroundColor Green
                return
            }
            $remaining = $finalSummary.CloudOnlyFiles
            $remainingPaths = $finalSummary.CloudOnlyPaths
        }

        if ((Get-Date) -ge $deadline) {
            Write-Host "[ERROR] Hydration timed out after $HydrateTimeoutMinutes minutes with $remaining CloudOnlyFiles remaining." -ForegroundColor Red
            foreach ($sample in $remainingPaths) {
                Write-Host "  - $sample" -ForegroundColor Yellow
            }
            exit 1
        }

        Start-Sleep -Seconds $HydratePollIntervalSeconds
    }
}

# --- Mode: Migrate ---
function Invoke-Migrate {
    Write-Host ""
    Write-Host "=== Migrating Files from OneDrive to Local Paths (Copy-First) ===" -ForegroundColor Cyan
    $summary = Get-AllSourceSummary

    if ($summary.CloudOnlyFiles -gt 0) {
        Write-Host "[ERROR] Aborting migration: $($summary.CloudOnlyFiles) CloudOnlyFiles remain. Run -Mode Hydrate first." -ForegroundColor Red
        foreach ($sample in $summary.CloudOnlyPaths) {
            Write-Host "  - $sample" -ForegroundColor Yellow
        }
        exit 1
    }

    $requiredBytes = [long]0
    foreach ($item in $MigrationMap) {
        $srcStats = $summary.Entries | Where-Object { $_.Name -eq $item.Name } | Select-Object -First 1
        if (-not $srcStats -or -not $srcStats.Exists) { continue }
        $dstStats = Get-DirectoryStats -RootPath $item.Destination -ExcludeFiles $item.ExcludeFiles
        $delta = $srcStats.TotalBytes - $dstStats.TotalBytes
        if ($delta -gt 0) {
            $requiredBytes += $delta
        }
    }

    $driveC = Get-PSDrive -Name "C"
    $safetyBuffer = [long]2GB
    if ($driveC.Free -lt ($requiredBytes + $safetyBuffer)) {
        Write-Host ("[ERROR] Insufficient free space on C:. Free: {0}, Estimated needed + 2GB buffer: {1}" -f (Format-SizeText $driveC.Free), (Format-SizeText ($requiredBytes + $safetyBuffer))) -ForegroundColor Red
        exit 1
    }

    foreach ($item in $MigrationMap) {
        if (-not (Test-Path -LiteralPath $item.Source)) {
            Write-Host "[SKIP] Source not found: $($item.Source)" -ForegroundColor DarkGray
            continue
        }
        Write-Host "[COPY] $($item.Name): $($item.Source) -> $($item.Destination)" -ForegroundColor Cyan
        $rc = Invoke-RobocopySafe -Source $item.Source -Destination $item.Destination -ExcludeDirs $item.ExcludeDirs -ExcludeFiles $item.ExcludeFiles
        Write-Host "  [OK] Robocopy completed (exit code: $rc)" -ForegroundColor Green
    }

    Write-Host "[OK] Copy-First migration complete. Source OneDrive files were preserved." -ForegroundColor Green
}

# --- Mode: Verify ---
function Invoke-Verify {
    Write-Host ""
    Write-Host "=== Verifying OneDrive Exit & Migration Integrity ===" -ForegroundColor Cyan
    $hasErrors = $false
    $summary = Get-AllSourceSummary

    Write-Host ("Source CloudOnlyFiles: {0}" -f $summary.CloudOnlyFiles) -ForegroundColor $(if ($summary.CloudOnlyFiles -eq 0) { "Green" } else { "Red" })
    if ($summary.CloudOnlyFiles -ne 0) {
        $hasErrors = $true
    }

    Write-Host ""
    Write-Host "--- Folder Count & Byte Comparison ---" -ForegroundColor Cyan
    foreach ($item in $MigrationMap) {
        $src = $summary.Entries | Where-Object { $_.Name -eq $item.Name } | Select-Object -First 1
        if (-not $src -or -not $src.Exists) { continue }
        $dst = Get-DirectoryStats -RootPath $item.Destination -ExcludeFiles $item.ExcludeFiles

        $ok = $dst.Exists -and ($dst.FileCount -ge $src.FileCount) -and ($dst.TotalBytes -ge $src.TotalBytes)
        if (-not $ok) { $hasErrors = $true }
        $tag = if ($ok) { "[OK]" } else { "[MISMATCH]" }
        $color = if ($ok) { "Green" } else { "Red" }
        Write-Host ("  {0} {1,-16} Src: {2,7} ({3}) | Dst: {4,7} ({5})" -f $tag, $item.Name, $src.FileCount, (Format-SizeText $src.TotalBytes), $dst.FileCount, (Format-SizeText $dst.TotalBytes)) -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "--- Git Repositories in $DevRoot ---" -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $DevRoot)) {
        Write-Host "  [ERROR] $DevRoot does not exist." -ForegroundColor Red
        $hasErrors = $true
    } else {
        $repos = Get-ChildItem -LiteralPath $DevRoot -Directory
        foreach ($repo in $repos) {
            $gitDir = Join-Path $repo.FullName ".git"
            if (-not (Test-Path -LiteralPath $gitDir)) {
                Write-Host "  [WARN] $($repo.Name) has no .git directory" -ForegroundColor Yellow
                continue
            }
            $remoteOut = & git -C $repo.FullName remote -v 2>&1
            $remoteExit = $LASTEXITCODE
            $statusOut = & git -C $repo.FullName status --short 2>&1
            $statusExit = $LASTEXITCODE
            if ($remoteExit -eq 0 -and $statusExit -eq 0) {
                $dirtyCount = @($statusOut | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
                $firstRemote = ($remoteOut | Select-Object -First 1)
                Write-Host ("  [OK] {0,-22} dirty={1,-3} remote={2}" -f $repo.Name, $dirtyCount, $firstRemote) -ForegroundColor Green
            } else {
                Write-Host "  [ERROR] git check failed in $($repo.FullName)" -ForegroundColor Red
                $hasErrors = $true
            }
        }
    }

    Write-Host ""
    Write-Host "--- User Shell Folders Registry Check ---" -ForegroundColor Cyan
    $usfPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $usf = Get-ItemProperty -Path $usfPath
    $badRefs = @()
    foreach ($prop in $usf.PSObject.Properties) {
        if ($prop.Name -in @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) { continue }
        $valStr = [string]$prop.Value
        if ($valStr -match "OneDrive") {
            $badRefs += "$($prop.Name) = $valStr"
        }
    }
    if ($badRefs.Count -gt 0) {
        Write-Host "  [WARN] Registry entries still pointing to OneDrive:" -ForegroundColor Yellow
        foreach ($r in $badRefs) { Write-Host "    - $r" -ForegroundColor Yellow }
    } else {
        Write-Host "  [OK] Zero OneDrive references in User Shell Folders" -ForegroundColor Green
    }

    if ($hasErrors) {
        Write-Host ""
        Write-Host "[FAIL] Verification detected mismatches or errors." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "[OK] Verification passed." -ForegroundColor Green
}

# --- Mode: DisableOneDrive ---
function Invoke-DisableOneDrive {
    Write-Host ""
    Write-Host "=== Disabling OneDrive & Restoring Local Shell Folders ===" -ForegroundColor Cyan
    Write-Host "[NOTE] Ensure you already turned off Manage Backup and clicked 'Unlink this PC' in OneDrive Settings UI." -ForegroundColor Yellow

    $odProcs = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    if ($odProcs) {
        Write-Host "  [STOP] Stopping OneDrive.exe..." -ForegroundColor Yellow
        $odProcs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    Write-Host "  [TASKS] Disabling OneDrive Scheduled Tasks..." -ForegroundColor Cyan
    $odTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "*OneDrive*" }
    foreach ($task in $odTasks) {
        try {
            Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
            Write-Host "    [OK] Disabled task: $($task.TaskName)" -ForegroundColor Green
        } catch {
            Write-Host "    [WARN] Task '$($task.TaskName)' requires Administrator privileges. Run in Admin PowerShell: Disable-ScheduledTask -TaskName `"$($task.TaskName)`"" -ForegroundColor Yellow
        }
    }

    Write-Host "  [REGISTRY] Removing OneDrive Startup Run keys..." -ForegroundColor Cyan
    $runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $runPath) {
        $runProps = Get-ItemProperty -Path $runPath
        foreach ($prop in $runProps.PSObject.Properties) {
            if ($prop.Name -like "*OneDrive*") {
                Remove-ItemProperty -Path $runPath -Name $prop.Name -ErrorAction SilentlyContinue
                Write-Host "    [OK] Removed Run key: $($prop.Name)" -ForegroundColor Green
            }
        }
    }

    Write-Host "  [SHELL] Restoring User Shell Folders to %USERPROFILE%..." -ForegroundColor Cyan
    $localFolders = @(
        (Join-Path $env:USERPROFILE "Desktop"),
        (Join-Path $env:USERPROFILE "Documents"),
        (Join-Path $env:USERPROFILE "Pictures"),
        (Join-Path $env:USERPROFILE "Pictures\Screenshots"),
        (Join-Path $env:USERPROFILE "Pictures\Camera Roll")
    )
    foreach ($lf in $localFolders) {
        if (-not (Test-Path -LiteralPath $lf)) {
            New-Item -ItemType Directory -Path $lf -Force | Out-Null
        }
    }

    $usfRegistryPath = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $usfMap = @{
        "Desktop"                                = "%USERPROFILE%\Desktop"
        "Personal"                               = "%USERPROFILE%\Documents"
        "My Pictures"                            = "%USERPROFILE%\Pictures"
        "{F42EE2D3-909F-4907-8871-4C22FC0BF756}" = "%USERPROFILE%\Documents"
        "{0DDD015D-B06C-45D5-8C4C-F59713854639}" = "%USERPROFILE%\Pictures"
        "{339719B5-8C47-4894-94C2-D8F77ADD44A6}" = "%USERPROFILE%\Pictures"
        "{B7BEDE81-DF94-4682-A7D8-57A52620B86F}" = "%USERPROFILE%\Pictures\Screenshots"
        "{767E6811-49CB-4273-87C2-20F355E1085B}" = "%USERPROFILE%\Pictures\Camera Roll"
        "{AB5FB87B-7CE2-4F83-915D-550846C9537B}" = "%USERPROFILE%\Pictures\Camera Roll"
    }

    $usfProps = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    if ($null -ne $usfProps.PSObject.Properties["{754AC886-DF64-4CBA-86B5-F7FBF4FBCEF5}"]) {
        $usfMap["{754AC886-DF64-4CBA-86B5-F7FBF4FBCEF5}"] = "%USERPROFILE%\Desktop"
    }

    foreach ($key in $usfMap.Keys) {
        [Microsoft.Win32.Registry]::SetValue($usfRegistryPath, $key, $usfMap[$key], [Microsoft.Win32.RegistryValueKind]::ExpandString)
        Write-Host "    [OK] $key => $($usfMap[$key])" -ForegroundColor Green
    }

    $sfPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
    if (Test-Path $sfPath) {
        Set-ItemProperty -Path $sfPath -Name "Desktop" -Value (Join-Path $env:USERPROFILE "Desktop") -Type String
        Set-ItemProperty -Path $sfPath -Name "Personal" -Value (Join-Path $env:USERPROFILE "Documents") -Type String
        Set-ItemProperty -Path $sfPath -Name "My Pictures" -Value (Join-Path $env:USERPROFILE "Pictures") -Type String
    }

    Write-Host ""
    Write-Host "[OK] OneDrive disabled and Shell Folders restored." -ForegroundColor Green
    Write-Host "[NEXT] Restart Windows Explorer for shell changes to take effect:" -ForegroundColor Yellow
    Write-Host "  Stop-Process -Name explorer -Force; Start-Process explorer.exe"
}

# --- Entrypoint Dispatch ---
switch ($Mode) {
    "CheckOnly"       { Invoke-CheckOnly }
    "Hydrate"         { Invoke-Hydrate }
    "Migrate"         { Invoke-Migrate }
    "Verify"          { Invoke-Verify }
    "DisableOneDrive" { Invoke-DisableOneDrive }
}
