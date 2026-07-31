<#
Version: 2.0
Run as: SYSTEM (64-bit)
Description: Detects whether WinGet is properly registered and functional for SYSTEM.
Exit 0 = installed | Exit 1 = needs bootstrap
#>

try {
    # Version-aware, architecture-aware lookup via MSIX registration (not filesystem)
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'Arm64' } else { 'X64' }

    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller `
           -ErrorAction SilentlyContinue |
           Where-Object { $_.Architecture -eq $arch } |
           Sort-Object { [version]$_.Version } -Descending |
           Select-Object -First 1

    if (-not $pkg) { exit 1 }

    $wingetExe = Join-Path $pkg.InstallLocation "winget.exe"
    if (-not (Test-Path $wingetExe)) { exit 1 }

    # Also verify minimum version (adjust to your baseline)
    $minVersion = [version]"1.22.0.0"
    if ([version]$pkg.Version -lt $minVersion) { exit 1 }

    exit 0
} catch {
    exit 1
}