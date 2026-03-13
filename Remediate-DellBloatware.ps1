<#
.SYNOPSIS
    Remediation Script - Remove Dell Bloatware EXCLUDING Dell Command | Update
.DESCRIPTION
    Silently removes Dell bloatware via Win32 uninstall strings and Appx removal.
    Preserves Dell Command | Update in all known forms.
    Exit 0 = success
    Exit 1 = failure
.NOTES
    Designed for use with Microsoft Intune Proactive Remediations.
    Log path: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\DellBloatRemoval.log
#>

# ── Apps to remove ────────────────────────────────────────────────────────────
$DellBloat = @(
    "Dell SupportAssist",
    "Dell Optimizer",
    "Dell Power Manager",
    "Dell Digital Delivery",
    "Dell Customer Connect",
    "Dell Mobile Connect",
    "MyDell",
    "Dell PremierColor",
    "Dell CinemaColor",
    "Dell Data Vault",
    "Dell SupportAssist OS Recovery",
    "Dell SupportAssist Remediation",
    "Dell Update",
    "Dell Core Services",
    "Dell TechHub",
    "Dell Fusion Service",
    "Dell Foundation Services",
    "SupportAssist Remediation Service",
    "DellInc.SupportAssistRemediationService"
)

# ── Apps to always preserve ───────────────────────────────────────────────────
$KeepList = @(
    "Dell Command | Update",
    "Dell Command Update",
    "Dell-Command-Update",
    "Dell Update for Windows Universal"
)

# ── Registry hives to scan ────────────────────────────────────────────────────
$UninstallRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# ── Helpers ───────────────────────────────────────────────────────────────────
function Test-IsKept {
    param([string]$Name)
    foreach ($entry in $KeepList) {
        if ($Name -like "*$entry*") { return $true }
    }
    return $false
}

function Test-IsBloat {
    param([string]$Name)
    foreach ($entry in $DellBloat) {
        if ($Name -like "*$entry*") { return $true }
    }
    return $false
}

# ── Logging ───────────────────────────────────────────────────────────────────
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\DellBloatRemoval.log"
Start-Transcript -Path $LogPath -Append -Force | Out-Null
Write-Output "=== Dell Bloatware Remediation Started: $(Get-Date) ==="

# ── Stop known Dell background processes ─────────────────────────────────────
Write-Output "Stopping Dell background processes..."
$ProcessNames = @(
    "SupportAssist",
    "SupportAssistAgent",
    "DellOptimizer",
    "DellOptimizerService",
    "DellUpdate",
    "PCDr",
    "DellDataVault",
    "DellDataVaultWizard"
)
foreach ($proc in $ProcessNames) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

# ── Win32 uninstall function ──────────────────────────────────────────────────
function Remove-Win32App {
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][object]$Entry
    )

    $cmd = if ($Entry.QuietUninstallString) {
        $Entry.QuietUninstallString
    } else {
        $Entry.UninstallString
    }

    if (-not $cmd) {
        Write-Warning "  No uninstall string found for: $DisplayName - skipping."
        return
    }

    Write-Output "  Uninstalling: $DisplayName"
    Write-Output "  Command: $cmd"

    if ($cmd -match "msiexec") {
        $uninstallArgs = ($cmd -replace "msiexec\.exe\s*", "").Trim()
        $uninstallArgs = $uninstallArgs -replace "/I\{", "/X{"
        if ($uninstallArgs -notmatch "/qn")        { $uninstallArgs += " /qn" }
        if ($uninstallArgs -notmatch "/norestart") { $uninstallArgs += " /norestart" }
        Write-Output "  MSI args: $uninstallArgs"
        Start-Process -FilePath "msiexec.exe" -ArgumentList $uninstallArgs -Wait -ErrorAction SilentlyContinue
    } else {
        $exePath       = $null
        $uninstallArgs = ""
        if ($cmd -match '^"([^"]+)"\s*(.*)$') {
            $exePath       = $matches[1]
            $uninstallArgs = $matches[2].Trim()
        } elseif ($cmd -match '^(\S+)\s*(.*)$') {
            $exePath       = $matches[1]
            $uninstallArgs = $matches[2].Trim()
        } else {
            Write-Warning "  Unable to parse uninstall string for: $DisplayName - skipping."
            return
        }
        if ($uninstallArgs -notmatch "/quiet"  -and
            $uninstallArgs -notmatch "/qn"     -and
            $uninstallArgs -notmatch "/silent" -and
            $uninstallArgs -notmatch "/S") {
            $uninstallArgs += " /quiet /norestart"
        }
        Write-Output "  EXE: $exePath | Args: $uninstallArgs"
        Start-Process -FilePath $exePath -ArgumentList $uninstallArgs -Wait -ErrorAction SilentlyContinue
    }
}

# ── Main ──────────────────────────────────────────────────────────────────────
try {
    # Scan Win32 registry entries
    Write-Output "`n--- Scanning Win32 registry entries ---"
    foreach ($root in $UninstallRoots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($item in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            $props = Get-ItemProperty $item.PSPath -ErrorAction SilentlyContinue
            if (-not $props.DisplayName) { continue }
            if (Test-IsKept $props.DisplayName) {
                Write-Output "  Skipping (protected): $($props.DisplayName)"
                continue
            }
            if (Test-IsBloat $props.DisplayName) {
                Remove-Win32App -DisplayName $props.DisplayName -Entry $props
            }
        }
    }

    # Scan Appx / MSIX packages
    Write-Output "`n--- Scanning Appx packages ---"
    $bloatAppx = Get-AppxPackage -AllUsers -Name "*Dell*" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notlike "*DellCommandUpdate*" -and
            $_.Name -notlike "*Dell.CommandUpdate*"
        }
    if ($bloatAppx) {
        foreach ($pkg in $bloatAppx) {
            Write-Output "  Removing Appx: $($pkg.Name)"
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
    } else {
        Write-Output "  No Dell Appx packages to remove."
    }

    Write-Output "`n=== Dell Bloatware Remediation Completed: $(Get-Date) ==="
    Stop-Transcript | Out-Null
    exit 0
} catch {
    Write-Output "Remediation script error: $_"
    Stop-Transcript | Out-Null
    exit 1
}
