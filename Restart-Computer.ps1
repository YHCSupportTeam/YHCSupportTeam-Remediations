# Define restricted restart hours (no restarts allowed between 07:45 and 17:30)
$restrictedStart = [DateTime]::ParseExact("07:45", "HH:mm", $null)
$restrictedEnd = [DateTime]::ParseExact("17:30", "HH:mm", $null)
$currentTime = Get-Date

# Get system uptime in days
$uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$daysSinceLastRestart = ($currentTime - $uptime).Days

# Check conditions
if ($daysSinceLastRestart -ge 30) {
    if ($currentTime.TimeOfDay -ge $restrictedStart.TimeOfDay -and $currentTime.TimeOfDay -le $restrictedEnd.TimeOfDay) {
        Write-Output "System needs a restart but it's within restricted hours (07:45–17:30). Restart deferred."
    } else {
        Write-Output "System has not been restarted for $daysSinceLastRestart days. Restarting now..."
        Restart-Computer -Force
    }
} else {
    Write-Output "System does not require a restart."
}
