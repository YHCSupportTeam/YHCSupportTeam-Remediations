<#
Detection: Verifies winget.exe exists and responds under SYSTEM
Exit 0 = Installed & Working
Exit 1 = Trigger Bootstrap / Remediation
#>
try {
    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
           Where-Object { $_.Architecture -match '(?i)x64|arm64' } |
           Sort-Object { [version]$_.Version } -Descending |
           Select-Object -First 1

    if (-not $pkg) { exit 1 }

    $winget = Join-Path $pkg.InstallLocation "winget.exe"
    if (-not (Test-Path $winget)) { exit 1 }

    # Test execution
    $out = & $winget --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) {
        exit 0
    }
    exit 1
} catch {
    exit 1
}