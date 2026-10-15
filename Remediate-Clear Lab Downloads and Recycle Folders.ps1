<#
.SYNOPSIS
    Remediation Script - Lab Computer Cleanup

.DESCRIPTION
    Clears Downloads folders for eligible local user profiles and empties
    Recycle Bin contents on local fixed drives.

    Designed for shared/lab computers managed by Microsoft Intune.

    Exit 0 = cleanup completed
    Exit 1 = cleanup completed with one or more significant errors

.NOTES
    Version: 3.0
    Run as: SYSTEM
    Context: 64-bit PowerShell
    Intended for Microsoft Intune Remediations

    Log path:
    C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\LabCleanup-Remediation.log
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

# ------------------------------------------------------------
# Settings
# ------------------------------------------------------------

$LogDir  = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogPath = Join-Path $LogDir "LabCleanup-Remediation.log"

# Set to 0 to remove all items.
# Set to 1, 3, 7, etc. if you want to preserve very recent downloads.
$MinimumAgeDays = 0

# If $true, failed deletions of individual files cause script exit 1.
# If $false, locked/access denied files are logged but script exits 0.
$FailOnItemDeleteError = $false

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    $line | Out-File -FilePath $LogPath -Append -Encoding UTF8
    Write-Output $line
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

function Get-FreeSpaceGB {
    param([string]$DriveLetter = "C:")

    try {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$DriveLetter'" -ErrorAction Stop
        return [math]::Round($disk.FreeSpace / 1GB, 2)
    }
    catch {
        Write-Log "Could not read free space for $DriveLetter. $($_.Exception.Message)" "WARN"
        return $null
    }
}

function Get-EligibleUserProfiles {
    $profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

    $excludedProfileNames = @(
        "Public",
        "Default",
        "Default User",
        "All Users",
        "defaultuser0",
        "WDAGUtilityAccount"
    )

    $excludedSids = @(
        "S-1-5-18",
        "S-1-5-19",
        "S-1-5-20"
    )

    $profiles = foreach ($key in Get-ChildItem -Path $profileListPath -ErrorAction SilentlyContinue) {
        try {
            $sid = $key.PSChildName

            if ($sid -in $excludedSids) {
                continue
            }

            # Most real user profiles are S-1-5-21-...
            if ($sid -notmatch "^S-1-5-21-") {
                continue
            }

            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction Stop
            $profilePath = $props.ProfileImagePath

            if ([string]::IsNullOrWhiteSpace($profilePath)) {
                continue
            }

            $expandedProfilePath = [Environment]::ExpandEnvironmentVariables($profilePath)

            if (-not (Test-Path $expandedProfilePath)) {
                continue
            }

            $profileName = Split-Path $expandedProfilePath -Leaf

            if ($profileName -in $excludedProfileNames) {
                continue
            }

            if ($expandedProfilePath -notlike "C:\Users\*") {
                Write-Log "Skipping non-standard profile path: $expandedProfilePath" "WARN"
                continue
            }

            [pscustomobject]@{
                SID         = $sid
                UserName    = $profileName
                ProfilePath = $expandedProfilePath
                Downloads   = Join-Path $expandedProfilePath "Downloads"
            }
        }
        catch {
            Write-Log "Failed to inspect profile key $($key.PSChildName). $($_.Exception.Message)" "WARN"
        }
    }

    $profiles | Sort-Object UserName -Unique
}

function Clear-FolderContents {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$OwnerName,

        [int]$MinimumAgeDays = 0
    )

    $result = [pscustomobject]@{
        RemovedCount = 0
        FailedCount  = 0
        SkippedCount = 0
    }

    if (-not (Test-Path $Path)) {
        Write-Log "Skipped $OwnerName - folder not found: $Path"
        return $result
    }

    Write-Log "Processing Downloads for $OwnerName`: $Path"

    try {
        $items = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "Could not enumerate $Path. $($_.Exception.Message)" "WARN"
        $result.FailedCount++
        return $result
    }

    if (-not $items) {
        Write-Log "Downloads already empty for $OwnerName"
        return $result
    }

    $cutoff = (Get-Date).AddDays(-1 * $MinimumAgeDays)

    foreach ($item in $items) {
        try {
            if ($MinimumAgeDays -gt 0 -and $item.LastWriteTime -gt $cutoff) {
                Write-Log "Skipped recent item: $($item.FullName)"
                $result.SkippedCount++
                continue
            }

            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
            Write-Log "Removed: $($item.FullName)"
            $result.RemovedCount++
        }
        catch {
            Write-Log "Could not remove item: $($item.FullName). $($_.Exception.Message)" "WARN"
            $result.FailedCount++
        }
    }

    return $result
}

function Clear-RecycleBinsOnFixedDrives {
    $result = [pscustomobject]@{
        RemovedCount = 0
        FailedCount  = 0
    }

    try {
        $fixedDrives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
    }
    catch {
        Write-Log "Could not enumerate fixed drives. $($_.Exception.Message)" "WARN"
        $result.FailedCount++
        return $result
    }

    foreach ($drive in $fixedDrives) {
        $recyclePath = Join-Path $drive.DeviceID "\`$Recycle.Bin"

        if (-not (Test-Path $recyclePath)) {
            Write-Log "Recycle Bin path not found on $($drive.DeviceID): $recyclePath"
            continue
        }

        Write-Log "Clearing recycle bin path: $recyclePath"

        try {
            $items = Get-ChildItem -LiteralPath $recyclePath -Force -ErrorAction SilentlyContinue

            if (-not $items) {
                Write-Log "Recycle bin already empty on $($drive.DeviceID)"
                continue
            }

            foreach ($item in $items) {
                try {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                    Write-Log "Removed recycle bin item: $($item.FullName)"
                    $result.RemovedCount++
                }
                catch {
                    Write-Log "Could not remove recycle bin item: $($item.FullName). $($_.Exception.Message)" "WARN"
                    $result.FailedCount++
                }
            }
        }
        catch {
            Write-Log "Failed clearing recycle bin on $($drive.DeviceID). $($_.Exception.Message)" "WARN"
            $result.FailedCount++
        }
    }

    return $result
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

$errorOccurred = $false

Write-Log "=== Lab Cleanup Remediation Started ==="
Write-Log "MinimumAgeDays: $MinimumAgeDays"
Write-Log "FailOnItemDeleteError: $FailOnItemDeleteError"

$freeBeforeGB = Get-FreeSpaceGB -DriveLetter "C:"
if ($null -ne $freeBeforeGB) {
    Write-Log "Free space before cleanup: $freeBeforeGB GB"
}

# Clear Downloads folders
Write-Log "--- Clearing Downloads folders ---"

$profiles = Get-EligibleUserProfiles

if (-not $profiles -or $profiles.Count -eq 0) {
    Write-Log "No eligible user profiles found."
}
else {
    Write-Log "Eligible profiles found: $($profiles.Count)"

    $totalRemoved = 0
    $totalFailed  = 0
    $totalSkipped = 0

    foreach ($profile in $profiles) {
        $cleanupResult = Clear-FolderContents -Path $profile.Downloads -OwnerName $profile.UserName -MinimumAgeDays $MinimumAgeDays

        $totalRemoved += $cleanupResult.RemovedCount
        $totalFailed  += $cleanupResult.FailedCount
        $totalSkipped += $cleanupResult.SkippedCount
    }

    Write-Log "Downloads cleanup summary: removed=$totalRemoved, failed=$totalFailed, skipped=$totalSkipped"

    if ($totalFailed -gt 0 -and $FailOnItemDeleteError) {
        $errorOccurred = $true
    }
}

# Clear Recycle Bins
Write-Log "--- Clearing Recycle Bins ---"

$recycleResult = Clear-RecycleBinsOnFixedDrives
Write-Log "Recycle Bin cleanup summary: removed=$($recycleResult.RemovedCount), failed=$($recycleResult.FailedCount)"

if ($recycleResult.FailedCount -gt 0 -and $FailOnItemDeleteError) {
    $errorOccurred = $true
}

$freeAfterGB = Get-FreeSpaceGB -DriveLetter "C:"
if ($null -ne $freeAfterGB) {
    Write-Log "Free space after cleanup: $freeAfterGB GB"

    if ($null -ne $freeBeforeGB) {
        $reclaimedGB = [math]::Round($freeAfterGB - $freeBeforeGB, 2)
        Write-Log "Space reclaimed: $reclaimedGB GB"
    }
}

if ($errorOccurred) {
    Write-Log "Result: Cleanup completed with one or more significant errors." "ERROR"
    exit 1
}
else {
    Write-Log "Result: Lab cleanup completed successfully."
    exit 0
}