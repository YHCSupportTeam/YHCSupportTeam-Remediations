# ============================================================
# Taskbar Search Icon - Intune Deployment 2026
# Run as: LOGGED ON USER | 64-bit PowerShell | User Context
# ============================================================

$RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
$Name    = "SearchboxTaskbarMode"
$Value   = 1  # 1 = Icon only (works on both Windows 10 and 11)

# Create key if missing
if (!(Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}

# Apply setting
Set-ItemProperty -Path $RegPath -Name $Name -Type DWord -Value $Value
Write-Output "SearchboxTaskbarMode set to $Value for: $env:USERNAME"

# Restart Explorer to apply change
$ExplorerProc = Get-Process -Name explorer -ErrorAction SilentlyContinue
if ($ExplorerProc) {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer
    Write-Output "Explorer restarted."
} else {
    Start-Process explorer
    Write-Output "Explorer launched."
}