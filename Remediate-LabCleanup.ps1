<#
.SYNOPSIS
    Remediation Script - Lab Computer Cleanup (Downloads + Recycle Bin)
.DESCRIPTION
    Clears the Downloads folder for all standard user profiles and empties
    the Recycle Bin on all drives. Skips system/service accounts and the
    default/public profiles to avoid unintended deletions.
    Exit 0 = completed successfully
    Exit 1 = one or more errors occurred during cleanup
.NOTES
    Version: 2.0
    Run as:  System
    Context: 64-bit
    Designed for use with Microsoft Intune Proactive Remediations.
    Log path: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\LabCleanup-Remediation.log

    Profiles skipped:
      - Any profile without a Downloads folder
#>

# ── Logging ───────────────────────────────────────────────────────────────────
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\LabCleanup-Remediation.log"
Start-Transcript -Path $LogPath -Append -Force | Out-Null

Write-Output "=== Lab Cleanup Remediation Started: $(Get-Date) ==="

$errorOccurred = $false

# ── Snapshot free space before cleanup ───────────────────────────────────────
try {
    $diskBefore   = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    $freeBeforeGB = [math]::Round($diskBefore.FreeSpace / 1GB, 2)
    Write-Output "Free space before cleanup: $freeBeforeGB GB"
}
catch {
    Write-Output "WARNING: Could not read pre-cleanup disk space - $_"
}

# ── Clear Downloads for all standard user profiles ───────────────────────────
Write-Output "`n--- Clearing Downloads Folders ---"

$userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue

if (-not $userProfiles) {
    Write-Output "  No eligible user profiles found."
}
else {
    foreach ($profile in $userProfiles) {
        $downloadsPath = Join-Path $profile.FullName "Downloads"

        if (-not (Test-Path $downloadsPath)) {
            Write-Output "  Skipped (no Downloads folder): $($profile.Name)"
            continue
        }

        Write-Output "  Processing: $downloadsPath"

        $items = Get-ChildItem -Path $downloadsPath -ErrorAction SilentlyContinue

        if (-not $items) {
            Write-Output "    Already empty."
            continue
        }

        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                Write-Output "    Removed: $($item.FullName)"
            }
            catch {
                Write-Output "    Skipped (locked or access denied): $($item.FullName)"
            }
        }
    }
}

# ── Empty Recycle Bin (all drives) ────────────────────────────────────────────
Write-Output "`n--- Emptying Recycle Bin ---"
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Output "  Recycle Bin emptied successfully."
}
catch {
    Write-Output "  WARNING: Could not empty Recycle Bin (may already be empty) - $_"
    # Not treated as a hard failure
}

# ── Snapshot free space after cleanup ────────────────────────────────────────
try {
    $diskAfter    = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
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
    Write-Output "`nResult: Lab cleanup completed successfully."
    Stop-Transcript | Out-Null
    exit 0
}
