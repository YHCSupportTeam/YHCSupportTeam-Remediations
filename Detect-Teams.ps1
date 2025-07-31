<#
.DESCRIPTION
    Detection script for Microsoft Teams presence on a device.
#>

$teamsPaths = @(
    "C:\Program Files (x86)\Teams Installer",
    "C:\Program Files\Microsoft Teams",
    "C:\Users\*\AppData\Local\Microsoft\Teams"
)

$found = $false

foreach ($path in $teamsPaths) {
    if (Test-Path $path) {
        Write-Output "Found Teams at: $path"
        $found = $true
    }
}

$installedApps = Get-WmiObject -Class Win32_Product | Where-Object {
    $_.Name -like "*Teams*" -or $_.Name -like "*Microsoft Teams*"
}

if ($installedApps) {
    $found = $true
    $installedApps | ForEach-Object { Write-Output "Installed: $($_.Name)" }
}

if ($found) {
    exit 1  # Teams is present
} else {
    exit 0  # Teams is not present
}
