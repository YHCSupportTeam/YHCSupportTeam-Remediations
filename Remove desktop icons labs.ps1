<#
Version: 1.1
Run as: System
Context: 64 Bit
Description: Removes specific desktop shortcuts from all user profiles and Public Desktop.
#>

# List of shortcut names to remove (case-insensitive)
$shortcutsToRemove = @(
    "Google Chrome.lnk",
    "VLC media player.lnk",
    "Google Earth.lnk",
    "Google Earth Pro.lnk",
    "Adobe Acrobat Reader DC.lnk",
    "Adobe Reader.lnk",
    "Mozilla Firefox.lnk",
    "Firefox.lnk",
    "Microsoft Edge.lnk",
    "Audacity.lnk",
    "GIMP.lnk"
)

# Get all user profile directories except system profiles
$userProfiles = Get-ChildItem "C:\Users" -Directory | Where-Object {
    $_.Name -notin @("Public", "Default", "Default User", "All Users")
}

# Function to remove shortcuts from a given desktop path
function Remove-ShortcutsFromDesktop($desktopPath) {
    foreach ($shortcut in $shortcutsToRemove) {
        $target = Join-Path $desktopPath $shortcut
        if (Test-Path $target) {
            try {
                Remove-Item -Path $target -Force
                Write-Output "Removed: $target"
            } catch {
                Write-Output "Failed to remove $target. Error: $_"
            }
        }
    }

    # Remove any GIMP shortcuts with version numbers (e.g., GIMP 2.10.lnk)
    Get-ChildItem -Path $desktopPath -Filter "GIMP*.lnk" -Force | ForEach-Object {
        try {
            Remove-Item -Path $_.FullName -Force
            Write-Output "Removed versioned GIMP shortcut: $($_.FullName)"
        } catch {
            Write-Output "Failed to remove GIMP shortcut: $_"
        }
    }
}

# Remove from each user's desktop
foreach ($profile in $userProfiles) {
    $desktopPath = Join-Path $profile.FullName "Desktop"
    if (Test-Path $desktopPath) {
        Remove-ShortcutsFromDesktop -desktopPath $desktopPath
    }
}

# Also remove from Public Desktop
$publicDesktop = "C:\Users\Public\Desktop"
if (Test-Path $publicDesktop) {
    Remove-ShortcutsFromDesktop -desktopPath $publicDesktop
}
