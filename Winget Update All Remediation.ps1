$ErrorActionPreference = "Stop"
$logFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.log"

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

try {
    # Locate winget under SYSTEM context (not in PATH for SYSTEM account)
    $winget = Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe" `
        -ErrorAction SilentlyContinue | Select-Object -Last 1

    if (-not $winget) {
        Write-Log "ERROR: winget.exe not found"
        exit 1
    }

    Write-Log "Found winget at: $($winget.FullName)"

    # Required for winget to run properly under SYSTEM
    $env:LOCALAPPDATA = "$env:SystemDrive\Windows\system32\config\systemprofile\AppData\Local"
    $env:TEMP = "$env:SystemDrive\Windows\Temp"

    Write-Log "Starting winget upgrade --all"

    $result = & $winget.FullName upgrade --all --silent --accept-source-agreements --accept-package-agreements 2>&1

    Write-Log "Output: $result"
    Write-Log "Upgrade completed successfully"
    exit 0

} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}