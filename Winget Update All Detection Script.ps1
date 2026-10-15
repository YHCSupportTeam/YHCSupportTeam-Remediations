<#
.SYNOPSIS
    Detect-WinGetUpgradeCooldown.ps1
.DESCRIPTION
    Package 2 Detection — Triggers upgrade remediation only when:
      1. Cooldown has expired
      2. WinGet is healthy under SYSTEM

    Exit 0 = Compliant / Do nothing
    Exit 1 = Trigger remediation
.NOTES
    Version: 3.0
    Run as: SYSTEM (64-bit PowerShell)
#>

$stampFile     = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.stamp"
$detectLog     = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.detect.log"
$cooldownHours = 7   # Change to 72 or 168 if you want less frequent runs

function Write-DLog($m) {
    try {
        $dir = Split-Path $detectLog
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m" | Out-File $detectLog -Append -Encoding UTF8
    } catch { }
}

try {
    Write-DLog "=== WinGet upgrade detection START ==="

    # Step 1: Cooldown check
    if (Test-Path $stampFile) {
        try {
            $lastRun = (Get-Item $stampFile).LastWriteTime
            $nextRun = $lastRun.AddHours($cooldownHours)

            if ((Get-Date) -lt $nextRun) {
                Write-DLog "Within cooldown window until $nextRun. Compliant."
                exit 0
            } else {
                Write-DLog "Cooldown expired. Continuing health check."
            }
        } catch {
            Write-DLog "Stamp file unreadable. Continuing health check."
        }
    } else {
        Write-DLog "No cooldown stamp found. Continuing health check."
    }

    # Step 2: WinGet health check
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'ARM64' } else { 'X64' }

    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
           Where-Object { "$($_.Architecture)" -match "^(?i)$arch$" } |
           Sort-Object { [version]$_.Version } -Descending |
           Select-Object -First 1

    if (-not $pkg) {
        Write-DLog "WinGet unhealthy: DesktopAppInstaller not found. Leaving repair to Package 1."
        exit 0
    }

    $wingetExe = Join-Path $pkg.InstallLocation "winget.exe"
    if (-not (Test-Path $wingetExe)) {
        Write-DLog "WinGet unhealthy: winget.exe missing at $wingetExe. Leaving repair to Package 1."
        exit 0
    }

    $verOut = & $wingetExe --version 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $verOut) {
        Write-DLog "WinGet unhealthy: --version failed. Output: $verOut. Leaving repair to Package 1."
        exit 0
    }

    Write-DLog "WinGet healthy and cooldown expired. Triggering remediation."
    exit 1

} catch {
    Write-DLog "Detection error: $($_.Exception.Message). Staying compliant and leaving repair to Package 1."
    exit 0
}