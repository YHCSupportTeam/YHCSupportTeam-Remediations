# Check if winget exists and is callable by SYSTEM
$winget = Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe" `
    -ErrorAction SilentlyContinue | Select-Object -Last 1

if (-not $winget) {
    exit 1  # WinGet not found, skip remediation
}

# Always trigger remediation to run upgrades (by design)
# But at least we know winget exists
exit 1