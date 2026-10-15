<#
.SYNOPSIS
    Detection Script - Disk Cleanup (Free Space Below 20 GB)
.DESCRIPTION
    Checks free space on C: drive using Win32_LogicalDisk.
    Exit 1 = Free space below threshold (Remediation required)
    Exit 0 = Free space at or above threshold (Compliant)
.NOTES
    Version: 3.0
    Run as:  SYSTEM (64-bit PowerShell)
    Log:     C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\DiskCleanup-Detection.log
#>

# ── Configuration ─────────────────────────────────────────────────────────────
$ThresholdGB = 20

# ── Logging ───────────────────────────────────────────────────────────────────
$LogDir  = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogPath = Join-Path $LogDir "DiskCleanup-Detection.log"

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

Start-Transcript -Path $LogPath -Append -Force | Out-Null
Write-Output "=== Disk Cleanup Detection Started: $(Get-Date) ==="
Write-Output "Threshold: $ThresholdGB GB"

# ── Detection ─────────────────────────────────────────────────────────────────
try {
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop

    if (-not $disk) {
        Write-Output "ERROR: Could not query C: drive via Win32_LogicalDisk."
        Stop-Transcript | Out-Null
        exit 1
    }

    $freeSpaceGB  = [math]::Round($disk.FreeSpace / 1GB, 2)
    $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)

    Write-Output "Total space : $totalSpaceGB GB"
    Write-Output "Free space  : $freeSpaceGB GB"
    Write-Output "Threshold   : $ThresholdGB GB"

    if ($disk.FreeSpace -lt ($ThresholdGB * 1GB)) {
        Write-Output "Result: Free space ($freeSpaceGB GB) is below threshold ($ThresholdGB GB). Triggering remediation."
        Stop-Transcript | Out-Null
        exit 1
    }
    else {
        Write-Output "Result: Free space ($freeSpaceGB GB) is at or above threshold ($ThresholdGB GB). Compliant."
        Stop-Transcript | Out-Null
        exit 0
    }
}
catch {
    Write-Output "ERROR: Unexpected error during detection - $_"
    Stop-Transcript | Out-Null
    exit 1
}