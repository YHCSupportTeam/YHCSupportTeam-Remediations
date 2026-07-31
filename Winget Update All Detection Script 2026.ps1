<#
Version: 2.0
Run as: SYSTEM (64-bit)
Description: Detects if WinGet upgrade cooldown has expired.
Exit 0 = compliant | Exit 1 = trigger remediation
#>

$stampFile     = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.stamp"
$detectLog     = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.detect.log"
$cooldownHours = 24

function Write-DLog($m) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m" | Out-File $detectLog -Append -Encoding UTF8
}

# Cooldown check
if (Test-Path $stampFile) {
    try {
        $lastRun = (Get-Item $stampFile).LastWriteTime
        if ((Get-Date) -lt $lastRun.AddHours($cooldownHours)) {
            Write-DLog "Within cooldown window. Compliant."
            exit 0
        }
    } catch {
        Write-DLog "Stamp unreadable - proceeding to remediation check."
    }
}

# Version-aware winget locator (2026 fix)
try {
    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller `
           -ErrorAction Stop |
           Where-Object { $_.Architecture -eq 'X64' } |
           Sort-Object { [version]$_.Version } -Descending |
           Select-Object -First 1

    if (-not $pkg) {
        Write-DLog "DesktopAppInstaller MSIX not registered for SYSTEM. Remediation needed."
        exit 1
    }

    $wingetExe = Join-Path $pkg.InstallLocation "winget.exe"
    if (-not (Test-Path $wingetExe)) {
        Write-DLog "winget.exe missing at $wingetExe. Remediation needed."
        exit 1
    }
} catch {
    Write-DLog "Detection error: $($_.Exception.Message). Triggering remediation."
    exit 1
}

Write-DLog "Cooldown expired. WinGet present. Triggering remediation."
exit 1
