<#
Version: 3.0
Run as: SYSTEM (64-bit)
Description: Detects whether WinGet upgrade cooldown has expired AND WinGet is healthy.

Exit 0 = compliant / do nothing
Exit 1 = trigger remediation
#>

$stampFile     = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.stamp"
$detectLog     = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.detect.log"
$cooldownHours = 24

function Write-DLog($m) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m" | Out-File $detectLog -Append -Encoding UTF8
}

try {
    # Cooldown check first
    if (Test-Path $stampFile) {
        try {
            $lastRun = (Get-Item $stampFile).LastWriteTime
            if ((Get-Date) -lt $lastRun.AddHours($cooldownHours)) {
                Write-DLog "Within cooldown window. Compliant."
                exit 0
            }
        } catch {
            Write-DLog "Stamp unreadable. Continuing with health check."
        }
    }

    # Detect architecture
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'ARM64' } else { 'X64' }

    # Locate DesktopAppInstaller
    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
           Where-Object { "$($_.Architecture)" -eq $arch } |
           Sort-Object { [version]$_.Version } -Descending |
           Select-Object -First 1

    if (-not $pkg) {
        Write-DLog "WinGet not healthy: DesktopAppInstaller not found. Leaving repair to bootstrap package."
        exit 0
    }

    $wingetExe = Join-Path $pkg.InstallLocation "winget.exe"
    if (-not (Test-Path $wingetExe)) {
        Write-DLog "WinGet not healthy: winget.exe missing. Leaving repair to bootstrap package."
        exit 0
    }

    $verOut = & $wingetExe --version 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $verOut) {
        Write-DLog "WinGet not healthy: --version failed. Leaving repair to bootstrap package."
        exit 0
    }

    Write-DLog "Cooldown expired and WinGet healthy. Triggering remediation."
    exit 1

} catch {
    Write-DLog "Detection error: $($_.Exception.Message). Leaving repair to bootstrap package."
    exit 0
}