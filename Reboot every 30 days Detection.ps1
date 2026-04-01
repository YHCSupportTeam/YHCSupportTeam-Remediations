$currentTime = Get-Date
$lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptimeDays = ($currentTime - $lastBoot).Days

if ($uptimeDays -ge 29) {
    Write-Output "Uptime is $uptimeDays days. Remediation required."
    exit 1
}
else {
    exit 0
}