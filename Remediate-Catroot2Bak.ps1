<#
.SYNOPSIS
    Remediation Script - Catroot2.bak Cleanup
.DESCRIPTION
    Removes any C:\Windows\Catroot2.bak* folders found on the system.
    Exit 0 = success (folders removed or nothing to remove)
    Exit 1 = failure (error during removal)
.NOTES
    Author:  James Sanderson
    Version: 2.0
    Designed for use with Microsoft Intune Proactive Remediations.
    Log path: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Catroot2Cleanup-Remediation.log
#>

# ── Logging ───────────────────────────────────────────────────────────────────
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\Catroot2Cleanup-Remediation.log"
Start-Transcript -Path $LogPath -Append -Force | Out-Null

Write-Output "=== Catroot2.bak Remediation Started: $(Get-Date) ==="

# ── Remediation ───────────────────────────────────────────────────────────────
try {
    $targets = Get-Item -Path "C:\Windows\Catroot2.bak*" -ErrorAction SilentlyContinue

    if (-not $targets) {
        Write-Output "No Catroot2.bak folders found. Nothing to remove."
        Stop-Transcript | Out-Null
        exit 0
    }

    $errorOccurred = $false

    foreach ($item in $targets) {
        Write-Output "Removing: $($item.FullName)"
        try {
            Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
            Write-Output "  Successfully removed: $($item.FullName)"
        }
        catch {
            Write-Output "  ERROR: Failed to remove $($item.FullName) - $_"
            $errorOccurred = $true
        }
    }

    if ($errorOccurred) {
        Write-Output "Result: Completed with errors. One or more items could not be removed."
        Stop-Transcript | Out-Null
        exit 1
    }
    else {
        Write-Output "Result: All Catroot2.bak folders removed successfully."
        Stop-Transcript | Out-Null
        exit 0
    }
}
catch {
    Write-Output "ERROR: Unexpected error during remediation - $_"
    Stop-Transcript | Out-Null
    exit 1
}
