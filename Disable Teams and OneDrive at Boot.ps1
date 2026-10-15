<#
.SYNOPSIS
    Lab Startup Cleanup - Disable Teams startup and remove OneDrive startup/uninstall OneDrive
.DESCRIPTION
    Runs as SYSTEM in 64-bit PowerShell.
    - Disables Classic Teams autorun entries
    - Disables New Teams startup task in each user profile
    - Does NOT uninstall or remove Teams
    - Removes OneDrive autorun/startup shortcuts
    - Uninstalls OneDrive machine-wide
.NOTES
    Intended for shared/lab devices via Intune device context.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------
# 64-bit PowerShell enforcement
# ------------------------------------------------------------
if ($env:PROCESSOR_ARCHITEW6432) {
    $sysNativePwsh = "$env:WINDIR\SysNative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysNativePwsh) {
        Write-Output "Restarting script in 64-bit PowerShell..."
        & $sysNativePwsh -ExecutionPolicy Bypass -File $PSCommandPath
        exit $LASTEXITCODE
    }
}

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------
$logDir  = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$logFile = Join-Path $logDir "LabStartupCleanup.log"

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $line | Out-File -FilePath $logFile -Append -Encoding UTF8
    Write-Output $line
}

# ------------------------------------------------------------
# Constants
# ------------------------------------------------------------
$ClassicTeamsRunKeys = @(
    'com.squirrel.Teams.Teams',
    'com.squirrel.teams.Teams',
    'MicrosoftTeams',
    'TeamsMachineInstaller'
)

$StartupShortcuts = @(
    'OneDrive.lnk',
    'Teams.lnk',
    'Microsoft Teams.lnk'
)

$NewTeamsStartupRelativePath = 'Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MSTeams_8wekyb3d8bbwe\TeamsTfwStartupTask'
$RunRelativePath             = 'Software\Microsoft\Windows\CurrentVersion\Run'

# ------------------------------------------------------------
# Helper: get real user profiles from ProfileList
# ------------------------------------------------------------
function Get-UserProfiles {
    $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

    $profiles = foreach ($key in Get-ChildItem $profileListPath -ErrorAction SilentlyContinue) {
        try {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction Stop
            $profilePath = $props.ProfileImagePath
            $sid = Split-Path $key.PSChildName -Leaf

            if ([string]::IsNullOrWhiteSpace($profilePath)) { continue }
            if (-not (Test-Path $profilePath)) { continue }

            $leaf = Split-Path $profilePath -Leaf

            if ($profilePath -notlike 'C:\Users\*') { continue }
            if ($leaf -in @('Public','Default','Default User','All Users','defaultuser0')) { continue }
            if ($sid -match '^S-1-5-18$|^S-1-5-19$|^S-1-5-20$') { continue }

            [pscustomobject]@{
                SID         = $sid
                UserName    = $leaf
                ProfilePath = $profilePath
                NtUserDat   = Join-Path $profilePath 'NTUSER.DAT'
            }
        } catch {
            Write-Log "Failed to inspect profile key $($key.PSChildName): $($_.Exception.Message)" 'WARN'
        }
    }

    $profiles | Sort-Object UserName -Unique
}

# ------------------------------------------------------------
# Helper: resolve HKU path for a user
# Uses loaded hive if present, otherwise loads NTUSER.DAT temporarily
# ------------------------------------------------------------
function Open-UserHive {
    param(
        [Parameter(Mandatory)] [string]$SID,
        [Parameter(Mandatory)] [string]$NtUserDatPath,
        [Parameter(Mandatory)] [string]$UserName
    )

    $loadedPath = "Registry::HKEY_USERS\$SID"
    if (Test-Path $loadedPath) {
        Write-Log "Using already-loaded hive for $UserName ($SID)"
        return [pscustomobject]@{
            RegistryRoot = $loadedPath
            WasLoaded    = $false
            TempHiveName = $null
        }
    }

    if (-not (Test-Path $NtUserDatPath)) {
        Write-Log "NTUSER.DAT not found for $UserName at $NtUserDatPath" 'WARN'
        return $null
    }

    $tempHiveName = "LabCleanup_$([regex]::Replace($UserName, '[^a-zA-Z0-9]', '_'))"
    $regTarget = "HKU\$tempHiveName"

    try {
        reg.exe load $regTarget $NtUserDatPath | Out-Null
        Write-Log "Loaded hive for $UserName from $NtUserDatPath"

        return [pscustomobject]@{
            RegistryRoot = "Registry::HKEY_USERS\$tempHiveName"
            WasLoaded    = $true
            TempHiveName = $tempHiveName
        }
    } catch {
        Write-Log "Failed to load hive for $UserName: $($_.Exception.Message)" 'WARN'
        return $null
    }
}

function Close-UserHive {
    param(
        [Parameter(Mandatory)] $HiveInfo,
        [Parameter(Mandatory)] [string]$UserName
    )

    if ($HiveInfo.WasLoaded -and $HiveInfo.TempHiveName) {
        try {
            [gc]::Collect()
            Start-Sleep -Milliseconds 500
            reg.exe unload "HKU\$($HiveInfo.TempHiveName)" | Out-Null
            Write-Log "Unloaded hive for $UserName"
        } catch {
            Write-Log "Failed to unload hive for $UserName: $($_.Exception.Message)" 'WARN'
        }
    }
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
Write-Log "=== Lab startup cleanup START ==="

$profiles = Get-UserProfiles
Write-Log "Found $($profiles.Count) eligible user profile(s)"

foreach ($profile in $profiles) {
    Write-Log "Processing profile: $($profile.UserName)"

    try {
        # Remove startup folder shortcuts from profile filesystem
        $startupFolder = Join-Path $profile.ProfilePath 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
        foreach ($shortcut in $StartupShortcuts) {
            $shortcutPath = Join-Path $startupFolder $shortcut
            if (Test-Path $shortcutPath) {
                Remove-Item -Path $shortcutPath -Force -ErrorAction SilentlyContinue
                Write-Log "Removed startup shortcut for $($profile.UserName): $shortcutPath"
            }
        }

        # Open user hive
        $hiveInfo = Open-UserHive -SID $profile.SID -NtUserDatPath $profile.NtUserDat -UserName $profile.UserName
        if (-not $hiveInfo) {
            Write-Log "Skipping registry cleanup for $($profile.UserName) because hive could not be opened" 'WARN'
            continue
        }

        try {
            $runPath = Join-Path $hiveInfo.RegistryRoot $RunRelativePath
            $newTeamsPath = Join-Path $hiveInfo.RegistryRoot $NewTeamsStartupRelativePath

            # Remove Classic Teams Run entries
            if (Test-Path $runPath) {
                foreach ($keyName in $ClassicTeamsRunKeys) {
                    if (Get-ItemProperty -Path $runPath -Name $keyName -ErrorAction SilentlyContinue) {
                        Remove-ItemProperty -Path $runPath -Name $keyName -ErrorAction SilentlyContinue
                        Write-Log "Removed Teams Run key '$keyName' for $($profile.UserName)"
                    }
                }

                # Remove OneDrive autorun
                if (Get-ItemProperty -Path $runPath -Name 'OneDrive' -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $runPath -Name 'OneDrive' -ErrorAction SilentlyContinue
                    Write-Log "Removed OneDrive Run key for $($profile.UserName)"
                }
            }

            # Disable New Teams startup task
            if (Test-Path $newTeamsPath) {
                New-ItemProperty -Path $newTeamsPath -Name 'State' -Value 0 -PropertyType DWord -Force | Out-Null
                Write-Log "Disabled New Teams startup task for $($profile.UserName)"
            } else {
                Write-Log "New Teams startup task path not present for $($profile.UserName)"
            }
        }
        finally {
            Close-UserHive -HiveInfo $hiveInfo -UserName $profile.UserName
        }
    } catch {
        Write-Log "Profile processing failed for $($profile.UserName): $($_.Exception.Message)" 'WARN'
    }
}

# ------------------------------------------------------------
# Stop and uninstall OneDrive
# ------------------------------------------------------------
try {
    Get-Process -Name 'OneDrive*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Log "Stopped running OneDrive processes (if any)"
} catch {
    Write-Log "Failed stopping OneDrive processes: $($_.Exception.Message)" 'WARN'
}

$oneDriveSetupPaths = @(
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
    "$env:SystemRoot\System32\OneDriveSetup.exe"
)

$oneDriveUninstalled = $false

foreach ($path in $oneDriveSetupPaths) {
    if (Test-Path $path) {
        try {
            $proc = Start-Process -FilePath $path -ArgumentList '/uninstall /allusers' -Wait -PassThru -WindowStyle Hidden
            Write-Log "Executed OneDrive uninstall from $path with exit code $($proc.ExitCode)"
            $oneDriveUninstalled = $true
        } catch {
            Write-Log "Failed running OneDrive uninstall from $path: $($_.Exception.Message)" 'WARN'
        }
    }
}

if (-not $oneDriveUninstalled) {
    Write-Log "No OneDriveSetup.exe found to uninstall"
}

Write-Log "=== Lab startup cleanup COMPLETE ==="
exit 0