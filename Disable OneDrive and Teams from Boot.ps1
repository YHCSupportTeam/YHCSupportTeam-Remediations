# ============================================================
# Lab Computer Startup Cleanup - Intune Deployment 2026
# Run as: SYSTEM | 64-bit PowerShell | Device Context
# ============================================================

# --- Ensure script runs in 64-bit PowerShell ---
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Write-Output "Restarting script in 64-bit PowerShell..."
    $ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    & "$env:WINDIR\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File $ScriptPath
    exit
}

# --- Get valid user profiles ---
$UserProfiles = Get-ChildItem "C:\Users" -Directory |
    Where-Object { $_.Name -notin @("Public", "Default", "Default User", "All Users") }

# Classic Teams Run key entries (includes case variations)
$ClassicRunKeys = @(
    "com.squirrel.Teams.Teams",
    "com.squirrel.teams.Teams",
    "MicrosoftTeams",
    "TeamsMachineInstaller"
)

# New Teams startup task registry path (does not use Run key)
$NewTeamsStartupPath = "Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MSTeams_8wekyb3d8bbwe\TeamsTfwStartupTask"

foreach ($Profile in $UserProfiles) {
    $AppData = Join-Path $Profile.FullName "AppData\Roaming"

    # --- Remove startup folder shortcuts ---
    @("OneDrive.lnk", "Teams.lnk", "Microsoft Teams.lnk") | ForEach-Object {
        $ShortcutPath = Join-Path $AppData "Microsoft\Windows\Start Menu\Programs\Startup" $_
        if (Test-Path $ShortcutPath) {
            Remove-Item $ShortcutPath -Force
            Write-Output "Removed startup shortcut: $ShortcutPath"
        }
    }

    # --- Load user hive ---
    $UserHivePath = Join-Path $Profile.FullName "NTUSER.DAT"
    if (-not (Test-Path $UserHivePath)) { continue }

    $HiveKey = "LabClean_$($Profile.Name -replace '[^a-zA-Z0-9]', '_')"
    $Loaded = $false

    try {
        reg load "HKU\$HiveKey" "$UserHivePath" | Out-Null
        $Loaded = $true

        $RunPath = "Registry::HKU\$HiveKey\Software\Microsoft\Windows\CurrentVersion\Run"

        # --- Classic Teams: remove Run key entries ---
        foreach ($Key in $ClassicRunKeys) {
            if (Get-ItemProperty -Path $RunPath -Name $Key -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -Path $RunPath -Name $Key -ErrorAction SilentlyContinue
                Write-Output "Removed classic Teams Run key '$Key' for: $($Profile.Name)"
            }
        }

        # --- New Teams: disable startup task via registry state ---
        $TaskPath = "Registry::HKU\$HiveKey\$NewTeamsStartupPath"
        if (Test-Path $TaskPath) {
            Set-ItemProperty -Path $TaskPath -Name "State" -Value 0 -Type DWord -ErrorAction SilentlyContinue
            Write-Output "Disabled new Teams startup task for: $($Profile.Name)"
        }

        # --- Remove OneDrive Run entry if present ---
        if (Get-ItemProperty -Path $RunPath -Name "OneDrive" -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $RunPath -Name "OneDrive" -ErrorAction SilentlyContinue
            Write-Output "Removed OneDrive Run entry for: $($Profile.Name)"
        }
    }
    catch {
        Write-Warning "Hive processing failed for $($Profile.Name): $_"
    }
    finally {
        if ($Loaded) {
            [gc]::Collect()
            Start-Sleep -Milliseconds 500
            reg unload "HKU\$HiveKey" 2>$null | Out-Null
        }
    }
}

# --- Kill OneDrive processes before uninstall ---
Get-Process "OneDrive*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# --- Uninstall OneDrive machine-wide ---
$ODPaths = @(
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
    "$env:SystemRoot\System32\OneDriveSetup.exe"
)
$Uninstalled = $false
foreach ($Path in $ODPaths) {
    if (Test-Path $Path) {
        & $Path /uninstall /allusers | Out-Null
        Write-Output "Executed OneDrive uninstall: $Path"
        $Uninstalled = $true
    }
}
if (-not $Uninstalled) {
    Write-Output "No OneDriveSetup.exe found to uninstall."
}

Write-Output "Lab computer cleanup finished."