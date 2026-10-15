<#
.SYNOPSIS
    Detect-WinGetHealth.ps1
.DESCRIPTION
    Package 1 Detection — Verifies WinGet health under SYSTEM context.
    Exit 0 = WinGet is healthy, no action needed
    Exit 1 = WinGet is broken or missing, trigger remediation
.NOTES
    Version: 3.0
    Run as:  SYSTEM (64-bit PowerShell)
#>

$detectLog = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetHealth.detect.log"
$minVersion = [version]"1.22.0.0"

function Write-DLog($m) {
    try {
        $dir = Split-Path $detectLog
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m" | Out-File $detectLog -Append -Encoding UTF8
    } catch { }
}

try {
    Write-DLog "=== WinGet health detection START ==="

    # Determine expected architecture
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'ARM64' } else { 'X64' }
    Write-DLog "Expected architecture: $arch"

    # Locate DesktopAppInstaller package
    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
           Where-Object { "$($_.Architecture)" -match "^(?i)$arch$" } |
           Sort-Object { [version]$_.Version } -Descending |
           Select-Object -First 1

    if (-not $pkg) {
        Write-DLog "FAIL: DesktopAppInstaller MSIX not registered. Remediation needed."
        exit 1
    }
    Write-DLog "Found DesktopAppInstaller v$($pkg.Version) at $($pkg.InstallLocation)"

    # Minimum version check
    if ([version]$pkg.Version -lt $minVersion) {
        Write-DLog "FAIL: Version $($pkg.Version) below minimum $minVersion. Remediation needed."
        exit 1
    }

    # Verify winget.exe exists
    $wingetExe = Join-Path $pkg.InstallLocation "winget.exe"
    if (-not (Test-Path $wingetExe)) {
        Write-DLog "FAIL: winget.exe missing at $wingetExe. Remediation needed."
        exit 1
    }

    # Verify winget.exe actually executes
    $verOut = & $wingetExe --version 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $verOut) {
        Write-DLog "FAIL: winget --version failed. Output: $verOut. Remediation needed."
        exit 1
    }
    Write-DLog "winget --version reports: $verOut"

    Write-DLog "SUCCESS: WinGet is healthy. No remediation needed."
    exit 0

} catch {
    Write-DLog "FAIL: Detection error: $($_.Exception.Message). Remediation needed."
    exit 1
}