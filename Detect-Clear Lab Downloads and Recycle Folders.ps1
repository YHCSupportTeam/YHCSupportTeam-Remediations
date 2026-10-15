<#
.SYNOPSIS
    Detection Script - Lab Computer Cleanup

.DESCRIPTION
    Always triggers remediation so lab cleanup runs on every scheduled cycle.

    Exit 0 = compliant / do nothing
    Exit 1 = trigger remediation

.NOTES
    Version: 3.0
    Run as: SYSTEM
    Context: 64-bit PowerShell
    Intended for Microsoft Intune Remediations
#>

$LogDir  = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogPath = Join-Path $LogDir "LabCleanup-Detection.log"

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    $line | Out-File -FilePath $LogPath -Append -Encoding UTF8
    Write-Output $line
}

Write-Log "=== Lab Cleanup Detection Started ==="
Write-Log "Result: Always triggering remediation for scheduled lab cleanup."

exit 1