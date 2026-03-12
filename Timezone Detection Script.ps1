$tz = (Get-TimeZone).Id

# Check if auto-timezone service is running and location is enabled
$autoTzService = (Get-Service -Name "tzautoupdate" -ErrorAction SilentlyContinue).StartType
$locationEnabled = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -ErrorAction SilentlyContinue).Value

# If location is on, trust auto-timezone (user may be traveling)
if ($locationEnabled -eq "Allow" -and $autoTzService -eq "Automatic") {
    exit 0  # Compliant - let Windows handle it
}

# If location is off, enforce Eastern
if ($tz -eq "Eastern Standard Time") {
    exit 0  # Compliant
} else {
    exit 1  # Non-compliant - trigger remediation
}