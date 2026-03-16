<#
.DESCRIPTION
  Removes Microsoft Teams (Classic 1.0 + New/2.0 MSIX) from the device.
  - Stops running processes
  - Uninstalls classic (Squirrel) per-user
  - Removes New Teams MSIX for all users and de-provisions
  - Cleans per-user + machine artifacts (folders, Run entries, tasks, registry)
  Intended for Intune Proactive Remediations "Remediate" phase, run as SYSTEM.
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

function Write-Info($msg) { Write-Output "[INFO] $msg" }
function Write-Warn($msg) { Write-Output "[WARN] $msg" }

function Try-StopProcess {
    param([string[]]$Names)
    foreach ($n in $Names) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Stop-Process -Id $_.Id -Force -ErrorAction Stop
                Write-Info "Stopped process: $($n) (PID=$($_.Id))"
            } catch {
                Write-Warn "Failed to stop $n (PID=$($_.Id)): $_"
            }
        }
    }
}

# --- Resolve real user profiles via ProfileList (SID + path) ---
$profiles = @()
try {
    $profileRoot = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    $profiles = Get-ChildItem $profileRoot | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath
        if ($p.ProfileImagePath -and (Test-Path $p.ProfileImagePath)) {
            if ($p.ProfileImagePath -match '\\(Default|Public|All Users|Default User)$') { return }
            # Skip service/local-system SIDs
            if ($_.PSChildName -match '^S-1-5-18|^S-1-5-19|^S-1-5-20') { return }
            [PSCustomObject]@{
                Sid  = $_.PSChildName
                Path = $p.ProfileImagePath
            }
        }
    }
} catch {
    Write-Warn "Failed to enumerate profiles from ProfileList: $_"
}

# --- 1) Stop known Teams-related processes (classic + new) ---
Try-StopProcess -Names @('Teams', 'ms-teams', 'Update')

# --- 2) Per-user cleanup (Classic + New Teams data + Startup + Add-in traces) ---
foreach ($prof in $profiles) {
    $u   = $prof.Path
    $sid = $prof.Sid
    Write-Info "Processing user SID=$sid Path=$u"

    # Classic uninstall if Update.exe present
    $classicRoot = Join-Path $u "AppData\Local\Microsoft\Teams"
    $updateExe   = Join-Path $classicRoot "Update.exe"
    if (Test-Path $updateExe) {
        try {
            Write-Info "Running classic Teams uninstaller for SID $sid"
            Start-Process -FilePath $updateExe -ArgumentList "--uninstall -s" -Wait -WindowStyle Hidden
        } catch {
            Write-Warn "Classic uninstaller failed for SID $sid: $_"
        }
    }

    # Classic + add-in + cache folders
    $userFolders = @(
        $classicRoot,
        (Join-Path $u "AppData\Roaming\Microsoft\Teams"),
        (Join-Path $u "AppData\Local\Microsoft\TeamsMeetingAddin"),
        (Join-Path $u "AppData\Local\SquirrelTemp")
    )
    foreach ($f in $userFolders) {
        if (Test-Path $f) {
            try {
                Remove-Item -Path $f -Recurse -Force -ErrorAction Stop
                Write-Info "Removed folder: $f"
            } catch {
                Write-Warn "Failed removing $f: $_"
            }
        }
    }

    # New Teams per-user MSIX data folder
    $msixData = Join-Path $u "AppData\Local\Packages\MSTeams_8wekyb3d8bbwe"
    if (Test-Path $msixData) {
        try {
            Remove-Item -Path $msixData -Recurse -Force -ErrorAction Stop
            Write-Info "Removed New Teams MSIX data: $msixData"
        } catch {
            Write-Warn "Failed removing $msixData: $_"
        }
    }

    # HKU Run entries indicating classic auto-start
    $hkcuRun = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $hkcuRun) {
        $toRemove = @('Teams', 'com.squirrel.Teams.Teams')
        foreach ($name in $toRemove) {
            try {
                if (Get-ItemProperty -Path $hkcuRun -Name $name -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $hkcuRun -Name $name -ErrorAction Stop
                    Write-Info "Removed HKU Run entry [$name] for SID $sid"
                }
            } catch {
                Write-Warn "Failed removing HKU Run entry [$name] for SID $sid: $_"
            }
        }
    }

    # HKU Teams registry keys (classic) — aligned with detection script
    $hkuKeys = @(
        "Registry::HKEY_USERS\$sid\Software\Microsoft\Teams",
        "Registry::HKEY_USERS\$sid\Software\Microsoft\Office\Teams"
    )
    foreach ($k in $hkuKeys) {
        if (Test-Path $k) {
            try {
                Remove-Item -Path $k -Recurse -Force -ErrorAction Stop
                Write-Info "Removed HKU key: $k"
            } catch {
                Write-Warn "Failed removing HKU key $k: $_"
            }
        }
    }

    # Per-user Start Menu shortcuts
    $userStart = Join-Path $u "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
    Get-ChildItem $userStart -Filter "*Teams*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Remove-Item $_.FullName -Force -ErrorAction Stop
            Write-Info "Removed user Start Menu link: $($_.FullName)"
        } catch {
            Write-Warn "Failed removing user Start Menu link $($_.FullName): $_"
        }
    }

    # Per-user Desktop shortcuts
    $userDesktop = Join-Path $u "Desktop"
    Get-ChildItem $userDesktop -Filter "*Teams*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Remove-Item $_.FullName -Force -ErrorAction Stop
            Write-Info "Removed user Desktop link: $($_.FullName)"
        } catch {
            Write-Warn "Failed removing user Desktop link $($_.FullName): $_"
        }
    }
}

# --- 3) New Teams MSIX removal for all users + de-provision ---
try {
    $allMSTeams = Get-AppxPackage -AllUsers | Where-Object {
        $_.Name -eq 'MicrosoftTeams' -or $_.PackageFamilyName -eq 'MSTeams_8wekyb3d8bbwe'
    }
    if ($allMSTeams) {
        $allMSTeams | ForEach-Object {
            try {
                Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
                Write-Info "Removed Appx (AllUsers): $($_.PackageFullName)"
            } catch {
                Write-Warn "AllUsers removal failed for $($_.PackageFullName). Trying per-user..."
                # Note: $_.UserSid is not always populated when running as SYSTEM — best-effort only
                if ($_.UserSid) {
                    try {
                        Remove-AppxPackage -Package $_.PackageFullName -User $_.UserSid -ErrorAction Stop
                        Write-Info "Removed Appx for User $($_.UserSid): $($_.PackageFullName)"
                    } catch {
                        Write-Warn "Per-user removal failed for $($_.PackageFullName) / SID=$($_.UserSid): $_"
                    }
                }
            }
        }
    } else {
        Write-Info "No MicrosoftTeams Appx packages found."
    }

    # De-provision so Teams doesn't return for new users
    $prov = Get-AppxProvisionedPackage -Online | Where-Object {
        $_.DisplayName -eq 'MicrosoftTeams' -or $_.PackageName -like 'MSTeams_*'
    }
    foreach ($p in $prov) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
            Write-Info "Removed provisioned package: $($p.PackageName)"
        } catch {
            Write-Warn "Failed de-provisioning $($p.PackageName): $_"
        }
    }
} catch {
    Write-Warn "MSIX removal/de-provision encountered an error: $_"
}

# --- 4) Uninstall MSI-based components (e.g., Teams Machine-Wide Installer) ---
$uninstallRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($root in $uninstallRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath
        if (-not $props.DisplayName) { return }

        if ($props.DisplayName -match '(?i)\bTeams\b') {
            $uninstall = $props.UninstallString
            if (-not $uninstall) { return }

            try {
                if ($uninstall -match '(?i)msiexec\.exe') {
                    # Fixed: separate the match from the assignment to avoid $guid = $false bug
                    $uninstall -match '\{[0-9A-Fa-f\-]{36}\}' | Out-Null
                    $guid = $Matches[0]

                    if ($guid) {
                        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Wait -WindowStyle Hidden
                        Write-Info "MSI uninstalled: $($props.DisplayName) ($guid)"
                    } else {
                        $args = $uninstall -replace '(?i)^.*msiexec\.exe', ''
                        if ($args -notmatch '(?i)/qn')       { $args += ' /qn' }
                        if ($args -notmatch '(?i)/norestart') { $args += ' /norestart' }
                        Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -WindowStyle Hidden
                        Write-Info "MSI uninstalled via original string: $($props.DisplayName)"
                    }
                } else {
                    # Fixed: robust quoted/unquoted path parsing for EXE uninstallers
                    if ($uninstall -match '^"([^"]+)"\s*(.*)$') {
                        $file = $Matches[1]
                        $args = $Matches[2]
                    } else {
                        $parts = $uninstall.Split(' ', 2)
                        $file  = $parts[0]
                        $args  = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                    }
                    if ($args -notmatch '(?i)(/quiet|/qn|/s|/silent)') { $args = "$args /quiet".Trim() }
                    Start-Process -FilePath $file -ArgumentList $args -Wait -WindowStyle Hidden
                    Write-Info "EXE uninstalled: $($props.DisplayName)"
                }
            } catch {
                Write-Warn "Uninstall failed for $($props.DisplayName): $_"
            }
        }
    }
}

# --- 5) Machine-wide residue (folders, registry, scheduled tasks, shortcuts) ---

# Machine-wide Teams installer folder residue
$machineFolders = @(
    "C:\Program Files (x86)\Teams Installer",
    "C:\Program Files\Microsoft Teams"
)
foreach ($f in $machineFolders) {
    if (Test-Path $f) {
        try {
            Remove-Item -Path $f -Recurse -Force -ErrorAction Stop
            Write-Info "Removed machine folder: $f"
        } catch {
            Write-Warn "Failed removing $f: $_"
        }
    }
}

# Machine-wide registry keys
$machineRegKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Teams",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Teams"
)
foreach ($k in $machineRegKeys) {
    if (Test-Path $k) {
        try {
            Remove-Item -Path $k -Recurse -Force -ErrorAction Stop
            Write-Info "Removed machine registry: $k"
        } catch {
            Write-Warn "Failed removing $k: $_"
        }
    }
}

# Teams Meeting Addin COM registration — added to match detection script
$addinReg = "HKLM:\SOFTWARE\Microsoft\Office\Teams"
if (Test-Path $addinReg) {
    try {
        Remove-Item -Path $addinReg -Recurse -Force -ErrorAction Stop
        Write-Info "Removed Teams Meeting Addin registry: $addinReg"
    } catch {
        Write-Warn "Failed removing $addinReg: $_"
    }
}

# Scheduled tasks — Author filter added to match detection script
Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object {
        $_.TaskName  -like "*Teams*" -or
        $_.TaskPath  -like "*Teams*" -or
        $_.Author    -like "*Teams*"
    } |
    ForEach-Object {
        try {
            Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction Stop
            Write-Info "Removed scheduled task: $($_.TaskPath)$($_.TaskName)"
        } catch {
            Write-Warn "Failed removing task $($_.TaskPath)$($_.TaskName): $_"
        }
    }

# Start Menu (machine-wide)
$programDataStart = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
Get-ChildItem $programDataStart -Filter "*Teams*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Remove-Item $_.FullName -Force -ErrorAction Stop
        Write-Info "Removed machine Start Menu link: $($_.FullName)"
    } catch {
        Write-Warn "Failed removing Start Menu link $($_.FullName): $_"
    }
}

# Public Desktop shortcuts — added to cover machine-wide desktop
$publicDesktop = "C:\Users\Public\Desktop"
Get-ChildItem $publicDesktop -Filter "*Teams*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Remove-Item $_.FullName -Force -ErrorAction Stop
        Write-Info "Removed public Desktop link: $($_.FullName)"
    } catch {
        Write-Warn "Failed removing public Desktop link $($_.FullName): $_"
    }
}

Write-Info "Teams remediation complete."
exit 0