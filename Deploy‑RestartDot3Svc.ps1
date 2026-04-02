# Deploy-RestartDot3Svc.ps1
# Intune Device Script – SYSTEM, 64-bit

$BasePath  = "C:\ProgramData\Microsoft\IntuneManagementExtension\Scripts"
$Script    = "$BasePath\Restart-dot3svc.ps1"
$LogPath   = "$BasePath\Logs"

# Ensure directories exist
foreach ($Path in @($BasePath, $LogPath)) {
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

$ScriptContent = @'
$LogFile = "C:\ProgramData\Microsoft\IntuneManagementExtension\Scripts\Logs\Restart-dot3svc.log"

function Write-Log {
    param([string]$Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Time] $Message"
}

Write-Log "=== Wired AutoConfig Remediation Triggered ==="

try {
    $wired = Get-NetAdapter -Physical | Where-Object {
        $_.Status -eq "Up" -and $_.PhysicalMediaType -eq "802.3"
    }

    if (-not $wired) {
        Write-Log "No active wired adapters detected. Exiting."
        exit 0
    }

    foreach ($nic in $wired) {
        Write-Log "Detected wired adapter: $($nic.Name) | $($nic.MacAddress)"
    }

    Restart-Service -Name dot3svc -Force -ErrorAction Stop
    Start-Sleep -Seconds 3

    if ((Get-Service dot3svc).Status -eq 'Running') {
        Write-Log "SUCCESS: dot3svc restarted successfully."
        exit 0
    }
    else {
        Write-Log "WARNING: dot3svc not running after restart."
        exit 1
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
'@

Set-Content -Path $Script -Value $ScriptContent -Encoding UTF8 -Force

Write-Output "Wired AutoConfig remediation script written to $Script"