<#
.SYNOPSIS
    Detection Script - Catroot2.bak Cleanup
.DESCRIPTION
    Checks for the presence of any C:\Windows\Catroot2.bak* folders.
    Exit 1 = folder(s) found, remediation required
    Exit 0 = clean, nothing to do
.NOTES
    Author:  James Sanderson
    Version: 2.0
    Designed for use with Microsoft Intune Proactive Remediations.
    Log path: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Catroot2Cleanup-Detection.log
#>

# ── Logging ───────────────────────────────────────────────────────────────────
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\Catroot2Cleanup-Detection.log"
Start-Transcript -Path $LogPath -Append -Force | Out-Null

Write-Output "=== Catroot2.bak Detection Started: $(Get-Date) ==="

# ── Detection ─────────────────────────────────────────────────────────────────
try {
    $targets = Get-Item -Path "C:\Windows\Catroot2.bak*" -ErrorAction SilentlyContinue

    if ($targets) {
        foreach ($item in $targets) {
            Write-Output "Detected: $($item.FullName)"
        }
        Write-Output "Result: Catroot2.bak folder(s) found. Remediation required."
        Stop-Transcript | Out-Null
        exit 1
    }
    else {
        Write-Output "Result: No Catroot2.bak folders found. Nothing to do."
        Stop-Transcript | Out-Null
        exit 0
    }
}
catch {
    Write-Output "ERROR: Unexpected error during detection - $_"
    Stop-Transcript | Out-Null
    exit 1
}
