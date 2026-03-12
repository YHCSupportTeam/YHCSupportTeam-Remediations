<#
.SYNOPSIS
    Detection Script - Lab Computer Cleanup (Downloads + Recycle Bin)
.DESCRIPTION
    Always returns exit 1 to ensure the remediation runs on every scheduled cycle.
    This is intentional for lab computers where cleanup should be enforced regularly.
    Exit 1 = always trigger remediation
.NOTES
    Version: 2.0
    Run as:  System
    Context: 64-bit
    Designed for use with Microsoft Intune Proactive Remediations.
    Log path: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\LabCleanup-Detection.log
#>

# ── Logging ───────────────────────────────────────────────────────────────────
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\LabCleanup-Detection.log"
Start-Transcript -Path $LogPath -Append -Force | Out-Null

Write-Output "=== Lab Cleanup Detection Started: $(Get-Date) ==="
Write-Output "Result: Always triggering remediation for lab computer cleanup."

Stop-Transcript | Out-Null
exit 1
