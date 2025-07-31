<#
.DESCRIPTION
    Removes all versions of Microsoft Teams from a Windows device.
#>

# Remove per-user Teams installations
$users = Get-ChildItem "C:\Users" -Directory | Where-Object {
    $_.Name -notin @("Public", "Default", "Default User", "All Users")
}

foreach ($user in $users) {
    $teamsPath = Join-Path $user.FullName "AppData\Local\Microsoft\Teams"
    if (Test-Path $teamsPath) {
        try {
            Remove-Item -Path $teamsPath -Recurse -Force -ErrorAction Stop
            Write-Output "Removed Teams from $teamsPath"
        } catch {
            Write-Output "Failed to remove Teams from $teamsPath: $_"
        }
    }
}

# Remove machine-wide installer
$machineWidePath = "C:\Program Files (x86)\Teams Installer"
if (Test-Path $machineWidePath) {
    try {
        Remove-Item -Path $machineWidePath -Recurse -Force -ErrorAction Stop
        Write-Output "Removed machine-wide Teams installer."
    } catch {
        Write-Output "Failed to remove machine-wide installer: $_"
    }
}

# Uninstall Teams via MSI if present
$teamsProduct = Get-WmiObject -Class Win32_Product | Where-Object {
    $_.Name -like "*Teams*" -or $_.Name -like "*Microsoft Teams*"
}

foreach ($product in $teamsProduct) {
    try {
        $product.Uninstall()
        Write-Output "Uninstalled: $($product.Name)"
    } catch {
        Write-Output "Failed to uninstall $($product.Name): $_"
    }
}

exit 0
