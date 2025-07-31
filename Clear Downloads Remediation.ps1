<#
Version: 1.1
Run as: System
Context: 64 Bit
Description: Clears the Downloads folder for all user profiles.
#>

$usersPath = "C:\Users"

# Get all user profile folders except system profiles
$profiles = Get-ChildItem -Path $usersPath -Directory | Where-Object {
    $_.Name -notin @("Public", "Default", "Default User", "All Users")
}

foreach ($profile in $profiles) {
    $downloadsPath = Join-Path -Path $profile.FullName -ChildPath "Downloads"
    if (Test-Path $downloadsPath) {
        try {
            Get-ChildItem -Path $downloadsPath -Recurse -Force -ErrorAction Stop | Remove-Item -Recurse -Force -ErrorAction Stop
            Write-Output "Cleared Downloads folder for user: $($profile.Name)"
        } catch {
            Write-Output "Failed to clear Downloads for user: $($profile.Name). Error: $_"
        }
    } else {
        Write-Output "Downloads folder not found for user: $($profile.Name)"
    }
}
