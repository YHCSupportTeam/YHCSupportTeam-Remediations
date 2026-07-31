<#
.SYNOPSIS
    AutoCAD 2023 Complete Removal - Intune Ready
.DESCRIPTION
    Removes all AutoCAD 2023 components listed by James Sanderson,
    then cleans leftover files and registry keys that cause 1603 errors.
#>

# ----- Setup Logging -----
$LogPath = "C:\Windows\Logs\ACAD2023-Removal.log"
Start-Transcript -Path $LogPath -Append -Force

Write-Host "===== AutoCAD 2023 Removal Started: $(Get-Date) ====="

# ----- Exact components from James's inventory -----
$ComponentsToRemove = @(
    "AutoCAD Open in Desktop",
    "Autodesk Access",
    "Autodesk App Manager",
    "Autodesk AutoCAD 2023 - English",
    "Autodesk AutoCAD Performance Feedback Tool 1.3.12",
    "Autodesk Featured Apps",
    "Autodesk Identity Manager",
    "Autodesk Material Library 2023",
    "Autodesk Material Library Base Resolution Image Library 2023",
    "Autodesk Save to Web and Mobile",
    "Autodesk Single Sign On Component"
    # Note: Autodesk Genuine Service handled separately at the end
)

# ----- Uninstall each component via registry lookup (most reliable in 2026) -----
$UninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($Component in $ComponentsToRemove) {
    Write-Host "`n--- Processing: $Component ---"
    
    $Found = Get-ItemProperty $UninstallKeys -ErrorAction SilentlyContinue |
             Where-Object { $_.DisplayName -like "*$Component*" }
    
    if ($Found) {
        foreach ($App in $Found) {
            Write-Host "Found: $($App.DisplayName) [$($App.DisplayVersion)]"
            
            if ($App.UninstallString) {
                # MSI-based uninstall
                if ($App.UninstallString -match "msiexec") {
                    $ProductCode = ($App.UninstallString -split " ")[1]
                    Write-Host "Running: msiexec /x $ProductCode /qn /norestart"
                    Start-Process "msiexec.exe" -ArgumentList "/x $ProductCode /qn /norestart" -Wait -NoNewWindow
                }
                # EXE-based uninstall (like Autodesk Access, ODIS installer)
                else {
                    $UninstallCmd = $App.QuietUninstallString
                    if (-not $UninstallCmd) { $UninstallCmd = $App.UninstallString + " --silent" }
                    Write-Host "Running: $UninstallCmd"
                    Start-Process "cmd.exe" -ArgumentList "/c $UninstallCmd" -Wait -NoNewWindow
                }
            }
        }
    } else {
        Write-Host "Not found (may already be removed)."
    }
}

# ----- Handle Autodesk Genuine Service LAST (stubborn component) -----
Write-Host "`n--- Processing: Autodesk Genuine Service ---"
$Genuine = Get-ItemProperty $UninstallKeys -ErrorAction SilentlyContinue |
           Where-Object { $_.DisplayName -like "*Autodesk Genuine Service*" }
if ($Genuine) {
    Write-Host "Note: Genuine Service 7.6.0.229 will be updated by AutoCAD 2027 installer."
    Write-Host "Skipping forced removal to avoid breaking supersedence."
}

# ----- Cleanup leftover folders (the #1 cause of 1603 errors) -----
Write-Host "`n--- Cleaning leftover files ---"
$FoldersToClean = @(
    "C:\Program Files\Autodesk\AutoCAD 2023",
    "C:\Program Files (x86)\Autodesk\AutoCAD 2023",
    "C:\ProgramData\Autodesk\AutoCAD 2023",
    "C:\ProgramData\Autodesk\ADUT",
    "C:\ProgramData\Autodesk\Genuine\R24.2"
)

foreach ($Folder in $FoldersToClean) {
    if (Test-Path $Folder) {
        Write-Host "Removing: $Folder"
        Remove-Item -Path $Folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Clean per-user AppData across all profiles
Get-ChildItem "C:\Users" -Directory | ForEach-Object {
    $UserPaths = @(
        "$($_.FullName)\AppData\Local\Autodesk\AutoCAD 2023",
        "$($_.FullName)\AppData\Roaming\Autodesk\AutoCAD 2023"
    )
    foreach ($p in $UserPaths) {
        if (Test-Path $p) {
            Write-Host "Removing user data: $p"
            Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ----- Cleanup registry stragglers -----
Write-Host "`n--- Cleaning registry ---"
$RegKeys = @(
    "HKLM:\SOFTWARE\Autodesk\AutoCAD\R24.2",
    "HKLM:\SOFTWARE\WOW6432Node\Autodesk\AutoCAD\R24.2"
)
foreach ($Key in $RegKeys) {
    if (Test-Path $Key) {
        Write-Host "Removing registry key: $Key"
        Remove-Item -Path $Key -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n===== AutoCAD 2023 Removal Complete: $(Get-Date) ====="
Stop-Transcript
exit 0