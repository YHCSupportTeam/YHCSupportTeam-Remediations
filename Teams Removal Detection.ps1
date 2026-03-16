<#
.DESCRIPTION
    Detection script for Microsoft Teams presence (Classic + New/2.0).
    Returns exit 1 if any trace of Teams is found, exit 0 if clean.
    Intended for Intune Proactive Remediation "Detect" phase.
#>

$ErrorActionPreference = 'SilentlyContinue'
$found = $false

function Write-Find($msg) {
    Write-Output $msg
    $script:found = $true
}

# --- Resolve actual user profiles via ProfileList (more reliable than C:\Users scan) ---
$profileKeys = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
$profiles = Get-ChildItem $profileKeys |
    ForEach-Object {
        $p = Get-ItemProperty $_.PSPath
        if ($p.ProfileImagePath -and
            ($p.ProfileImagePath -notmatch '\\(Default|Public|All Users|Default User)$') -and
            (Test-Path $p.ProfileImagePath)) {
            [PSCustomObject]@{
                UserProfilePath = $p.ProfileImagePath
                Sid             = $_.PSChildName
            }
        }
    }

# --- Machine-wide classic installations ---
$machinePaths = @(
    "C:\Program Files (x86)\Teams Installer",
    "C:\Program Files\Microsoft Teams"
)
foreach ($path in $machinePaths) {
    if (Test-Path $path) { Write-Find "Found Teams folder: $path" }
}

# --- Per-user classic + New Teams artifacts ---
foreach ($prof in $profiles) {
    $u = $prof.UserProfilePath

    $userPaths = @(
        Join-Path $u "AppData\Local\Microsoft\Teams",                       # Classic app
        Join-Path $u "AppData\Roaming\Microsoft\Teams",                     # Classic data/logs
        Join-Path $u "AppData\Local\Microsoft\TeamsMeetingAddin",           # Meeting Add-in remnants
        Join-Path $u "AppData\Local\SquirrelTemp",                          # Classic installer traces
        Join-Path $u "AppData\Local\Packages\MSTeams_8wekyb3d8bbwe"         # New Teams per-user data
    )
    foreach ($path in $userPaths) {
        if (Test-Path $path) { Write-Find "Found per-user Teams path: $path" }
    }

    # Per-user startup entries (classic Teams auto-launch)
    $hkcuRun = "Registry::HKEY_USERS\$($prof.Sid)\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $hkcuRun) {
        $runProps = Get-ItemProperty $hkcuRun
        $runProps.PSObject.Properties | Where-Object {
            $_.Value -match 'Teams|com\.squirrel\.Teams\.Teams'
        } | ForEach-Object {
            Write-Find "Found per-user startup entry: HKU:\$($prof.Sid)\...\Run\$($_.Name) = $($_.Value)"
        }
    }

    # Per-user Teams registry keys — checked in remediation but missing from original detection
    $hkuRegPaths = @(
        "Registry::HKEY_USERS\$($prof.Sid)\Software\Microsoft\Teams",
        "Registry::HKEY_USERS\$($prof.Sid)\Software\Microsoft\Office\Teams"
    )
    foreach ($regPath in $hkuRegPaths) {
        if (Test-Path $regPath) { Write-Find "Found per-user registry key: $regPath" }
    }
}

# --- MSIX package (New Teams) across all users ---
# MSTeams = New Teams 2.0; MicrosoftTeams = legacy MSIX wrapper — flag both
$msix = Get-AppxPackage -AllUsers | Where-Object {
    $_.PackageFamilyName -eq "MSTeams_8wekyb3d8bbwe" -or    # New Teams 2.0
    $_.Name -eq "MicrosoftTeams"                             # Legacy MSIX wrapper
}
if ($msix) {
    $msix | ForEach-Object {
        Write-Find "Found MSIX package: $($_.Name) [$($_.PackageFullName)]"
    }
}

# --- Registry-based uninstall entries (Classic + machine-wide installer) ---
$uninstallRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($root in $uninstallRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath
        if ($props -and $props.DisplayName -and ($props.DisplayName -match 'Teams')) {
            Write-Find "Found installed entry: $($props.DisplayName) [$($_.PSChildName)]"
        }
    }
}

# --- Machine-wide Teams registry keys ---
$machineRegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Teams",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Teams"
)
foreach ($regPath in $machineRegPaths) {
    if (Test-Path $regPath) { Write-Find "Found machine registry key: $regPath" }
}

# --- Teams Meeting Addin COM registration (survives folder deletion) ---
$addinReg = "HKLM:\SOFTWARE\Microsoft\Office\Teams"
if (Test-Path $addinReg) { Write-Find "Found Teams Meeting Addin registry: $addinReg" }

# --- Scheduled tasks ---
# Note: Per-user tasks registered outside SYSTEM context may not be visible here.
$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -like "*Teams*" -or $_.TaskPath -like "*Teams*" -or $_.Author -like "*Teams*" }
if ($tasks) {
    $tasks | ForEach-Object { Write-Find "Found scheduled task: $($_.TaskPath)$($_.TaskName)" }
}

if ($found) {
    exit 1  # Teams traces present — remediation needed
} else {
    Write-Output "No Microsoft Teams traces found."
    exit 0  # Clean
}