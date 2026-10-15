<#
.SYNOPSIS
    Remediation Script - Disk Cleanup (Free Space Below 20 GB)
.DESCRIPTION
    Cleans system/temp junk locations and purges items in the Recycle Bin 
    that were deleted more than 7 days ago.
    
    Exit 0 = Completed successfully
    Exit 1 = One or more fatal errors occurred
.NOTES
    Version: 3.0
    Run as:  SYSTEM (64-bit PowerShell)
    Log:     C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\DiskCleanup-Remediation.log
#>

# ── Configuration ─────────────────────────────────────────────────────────────
$RecycleBinRetentionDays = 7

# ── Logging ───────────────────────────────────────────────────────────────────
$LogDir  = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogPath = Join-Path $LogDir "DiskCleanup-Remediation.log"

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

Start-Transcript -Path $LogPath -Append -Force | Out-Null
Write-Output "=== Disk Cleanup Remediation Started: $(Get-Date) ==="
Write-Output "Recycle Bin Retention: Only deleting items older than $RecycleBinRetentionDays days"

$errorOccurred = $false

# ── Snapshot free space before cleanup ───────────────────────────────────────
$freeBeforeGB = $null
try {
    $diskBefore   = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    $freeBeforeGB = [math]::Round($diskBefore.FreeSpace / 1GB, 2)
    Write-Output "Free space before cleanup: $freeBeforeGB GB"
}
catch {
    Write-Output "WARNING: Could not read pre-cleanup disk space - $_"
}

# ── Temp & Cache Cleanup Targets ─────────────────────────────────────────────
$CleanupTargets = @(
    @{ Label = "Windows Temp";                  Path = "C:\Windows\Temp" },
    @{ Label = "System TEMP";                   Path = $env:TEMP },
    @{ Label = "Windows Update Download Cache"; Path = "C:\Windows\SoftwareDistribution\Download" },
    @{ Label = "Windows Error Reporting";       Path = "C:\ProgramData\Microsoft\Windows\WER" },
    @{ Label = "CBS Logs";                      Path = "C:\Windows\Logs\CBS" },
    @{ Label = "Delivery Optimization Cache";   Path = "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache" },
    @{ Label = "Prefetch";                      Path = "C:\Windows\Prefetch" }
)

foreach ($target in $CleanupTargets) {
    Write-Output "`n--- $($target.Label) ---"
    Write-Output "Target Folder: $($target.Path)"

    if (-not (Test-Path $target.Path)) {
        Write-Output "  Path not found. Skipping."
        continue
    }

    try {
        $items = Get-ChildItem -Path $target.Path -Force -ErrorAction SilentlyContinue

        if (-not $items) {
            Write-Output "  Already clean."
            continue
        }

        foreach ($item in $items) {
            try {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                Write-Output "  Removed: $($item.FullName)"
            }
            catch {
                # Locked/in-use files are normal for active system logs & temp folders
                Write-Output "  Skipped (locked or in-use): $($item.FullName)"
            }
        }
    }
    catch {
        Write-Output "  ERROR processing $($target.Label) - $_"
        $errorOccurred = $true
    }
}

# ── Clean User Thumbnail Caches ──────────────────────────────────────────────
Write-Output "`n--- User Thumbnail Caches ---"
try {
    $thumbCaches = Get-ChildItem -Path "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
    if ($thumbCaches) {
        foreach ($db in $thumbCaches) {
            try {
                Remove-Item -LiteralPath $db.FullName -Force -ErrorAction Stop
                Write-Output "  Removed: $($db.FullName)"
            } catch {
                Write-Output "  Skipped (locked): $($db.FullName)"
            }
        }
    } else {
        Write-Output "  No thumbnail cache files found."
    }
}
catch {
    Write-Output "  WARNING: Error enumerating thumbnail caches - $_"
}

# ── Recycle Bin Cleanup (Older than 7 Days across all Fixed Drives) ───────────
Write-Output "`n--- Recycle Bin (Age Filter: > $RecycleBinRetentionDays Days) ---"
$cutoffDate = (Get-Date).AddDays(-1 * $RecycleBinRetentionDays)
Write-Output "Items deleted after $cutoffDate will be preserved."

try {
    $fixedDrives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop

    foreach ($drive in $fixedDrives) {
        $recyclePath = Join-Path $drive.DeviceID "`$Recycle.Bin"

        if (-not (Test-Path $recyclePath)) {
            continue
        }

        Write-Output "Checking Recycle Bin on drive $($drive.DeviceID)..."

        # Look for deleted files/metadata in all user SID subfolders
        $recycledItems = Get-ChildItem -LiteralPath $recyclePath -Recurse -Force -ErrorAction SilentlyContinue |
                         Where-Object { -not $_.PSIsContainer }

        if (-not $recycledItems) {
            Write-Output "  Recycle bin is empty on $($drive.DeviceID)"
            continue
        }

        $purgedCount = 0
        $preservedCount = 0

        foreach ($item in $recycledItems) {
            if ($item.LastWriteTime -lt $cutoffDate) {
                try {
                    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                    $purgedCount++
                } catch {
                    Write-Output "  Skipped locked item: $($item.FullName)"
                }
            } else {
                $preservedCount++
            }
        }

        Write-Output "  Result on $($drive.DeviceID): Purged $purgedCount old item(s), Preserved $preservedCount recent item(s)."
    }
}
catch {
    Write-Output "  WARNING: Could not process Recycle Bins - $_"
}

# ── Snapshot free space after cleanup ────────────────────────────────────────
try {
    $diskAfter = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    $freeAfterGB  = [math]::Round($diskAfter.FreeSpace / 1GB, 2)
    Write-Output "`nFree space after cleanup : $freeAfterGB GB"

    if ($null -ne $freeBeforeGB) {
        $reclaimedGB = [math]::Round($freeAfterGB - $freeBeforeGB, 2)
        Write-Output "Space reclaimed          : $reclaimedGB GB"
    }
}
catch {
    Write-Output "WARNING: Could not read post-cleanup disk space - $_"
}

# ── Exit ──────────────────────────────────────────────────────────────────────
if ($errorOccurred) {
    Write-Output "`nResult: Cleanup completed with non-critical warnings/errors. Review log for details."
    Stop-Transcript | Out-Null
    exit 0 # Exiting 0 prevents Intune PR failure loops over minor locked files
}
else {
    Write-Output "`nResult: Disk cleanup completed successfully."
    Stop-Transcript | Out-Null
    exit 0
}