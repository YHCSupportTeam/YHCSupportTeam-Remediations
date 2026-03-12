$locationEnabled = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -ErrorAction SilentlyContinue).Value

if ($locationEnabled -eq "Allow") {
    # Location is on — enable auto timezone service and let Windows adjust for travel
    Set-Service -Name "tzautoupdate" -StartupType Automatic
    Start-Service -Name "tzautoupdate" -ErrorAction SilentlyContinue
} else {
    # Location is off — force Eastern
    Set-TimeZone -Id "Eastern Standard Time"
    Set-Service -Name "tzautoupdate" -StartupType Disabled
}