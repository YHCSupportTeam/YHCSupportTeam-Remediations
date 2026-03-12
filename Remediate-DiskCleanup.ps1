<#
.SYNOPSIS
    Remediation Script - Disk Cleanup (Free Space Below 20 GB)
.DESCRIPTION
    Cleans common high-volume temp/junk locations and empties the Recycle Bin.
    Does not use CleanMgr.exe — all cleanup is done via direct file removal,
    which is reliable in a System/non-interactive Intune context.
    Exit 0 = completed successfully
    Exit 1 = one or more errors occurred during cleanup
.NOTES
    Author:  Jannik Reinhard (jannikreinhard.com) - Updated
    Version: 2.0
    Designed for use with Microsoft Intune Proactive Remediations.
    Log path: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\DiskCleanup-Remediation.log

    Targets:
      - Windows Temp folder          (C:\Windows\Temp\*)
      - System TEMP folder           (%TEMP%\*)
      - Windows Update download cache(C:\Windows\SoftwareDistribution\Download\*)
      - Windows Error Reporting      (C:\ProgramData\Microsoft\Windows\WER\*)
      - CBS logs                     (C:\Windows\Logs\CBS\*)
      - Delivery Optimisation cache  (C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*)
      - Prefetch                     (C:\Windows\Prefetch\*)
      - Thumbnail cache              (C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db)
      - Recycle Bin                  (all drives)
#>

# ── Logging ───────────────────────────────────────────────────────────────────
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\DiskCleanup-Remediation.log"
Start-Transcript -Path $LogPath -Append -Force | Out-Null

Write-Output "=== Disk Cleanup Remediation Started: $(Get-Date) ==="

# ── Snapshot free space before cleanup ───────────────────────────────────────
try {
    $diskBefore = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    $freeBeforeGB = [math]::Round($diskBefore.FreeSpace / 1GB, 2)
    Write-Output "Free space before cleanup: $freeBeforeGB GB"
}
catch {
    Write-Output "WARNING: Could not read pre-cleanup disk space - $_"
}

# ── Cleanup targets ───────────────────────────────────────────────────────────
$CleanupTargets = @(
    @{ Label = "Windows Temp";                  Path = "C:\Windows\Temp\*" },
    @{ Label = "System TEMP";                   Path = "$env:TEMP\*" },
    @{ Label = "Windows Update Download Cache"; Path = "C:\Windows\SoftwareDistribution\Download\*" },
    @{ Label = "Windows Error Reporting";       Path = "C:\ProgramData\Microsoft\Windows\WER\*" },
    @{ Label = "CBS Logs";                      Path = "C:\Windows\Logs\CBS\*" },
    @{ Label = "Delivery Optimisation Cache";   Path = "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*" },
    @{ Label = "Prefetch";                      Path = "C:\Windows\Prefetch\*" },
    @{ Label = "Thumbnail Cache";               Path = "C:\Users\*\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db" }
)

$errorOccurred = $false

# ── Remove each target ────────────────────────────────────────────────────────
foreach ($target in $CleanupTargets) {
    Write-Output "`n--- $($target.Label) ---"
    Write-Output "Path: $($target.Path)"

    try {
        $items = Get-Item -Path $target.Path -ErrorAction SilentlyContinue

        if (-not $items) {
            Write-Output "  Nothing found at this path."
            continue
        }

        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                Write-Output "  Removed: $($item.FullName)"
            }
            catch {
                # Locked files (e.g. active logs) are expected — log and continue
                Write-Output "  Skipped (locked or access denied): $($item.FullName)"
            }
        }
    }
    catch {
        Write-Output "  ERROR processing $($target.Label) - $_"
        $errorOccurred = $true
    }
}

# ── Empty Recycle Bin (all drives) ────────────────────────────────────────────
Write-Output "`n--- Recycle Bin ---"
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Output "  Recycle Bin emptied successfully."
}
catch {
    Write-Output "  WARNING: Could not empty Recycle Bin - $_"
    # Not treated as a hard failure — Recycle Bin may already be empty
}

# ── Snapshot free space after cleanup ────────────────────────────────────────
try {
    $diskAfter = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    $freeAfterGB  = [math]::Round($diskAfter.FreeSpace / 1GB, 2)
    $reclaimedGB  = [math]::Round($freeAfterGB - $freeBeforeGB, 2)
    Write-Output "`nFree space after cleanup : $freeAfterGB GB"
    Write-Output "Space reclaimed          : $reclaimedGB GB"
}
catch {
    Write-Output "WARNING: Could not read post-cleanup disk space - $_"
}

# ── Exit ──────────────────────────────────────────────────────────────────────
if ($errorOccurred) {
    Write-Output "`nResult: Cleanup completed with errors. Review log for details."
    Stop-Transcript | Out-Null
    exit 1
}
else {
    Write-Output "`nResult: Disk cleanup completed successfully."
    Stop-Transcript | Out-Null
    exit 0
}
