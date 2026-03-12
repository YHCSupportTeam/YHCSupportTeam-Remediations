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

# ── Logging ───────────────────────────────────────────────────────────────────
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\DellBloatRemoval.log"
Start-Transcript -Path $LogPath -Append -Force | Out-Null

Write-Output "=== Dell Bloatware Remediation Started: $(Get-Date) ==="

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
    "Dell Update"
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

# ── Helper: test if a display name matches the keep list ─────────────────────
function Test-IsKept {
    param([string]$Name)
    foreach ($entry in $KeepList) {
        if ($Name -like "*$entry*") { return $true }
    }
    return $false
}

# ── Helper: test if a display name matches the bloat list ────────────────────
function Test-IsBloat {
    param([string]$Name)
    foreach ($entry in $DellBloat) {
        if ($Name -like "*$entry*") { return $true }
    }
    return $false
}

# ── Stop known Dell background processes before uninstalling ─────────────────
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

    # Prefer QuietUninstallString if available — it's pre-built for silent use
    $cmd = if ($Entry.QuietUninstallString) {
        $Entry.QuietUninstallString
    } else {
        $Entry.UninstallString
    }

    if (-not $cmd) {
        Write-Warning "  No uninstall string found for: $DisplayName — skipping."
        return
    }

    Write-Output "  Uninstalling: $DisplayName"
    Write-Output "  Command: $cmd"

    # ── MSI-based uninstall ──
    if ($cmd -match "msiexec") {
        # Use -replace (case-insensitive) to strip the exe name
        $args = ($cmd -replace "msiexec\.exe\s*", "").Trim()

        # Normalise /I{GUID} → /X{GUID} (some entries use /I instead of /X)
        $args = $args -replace "/I\{", "/X{"

        # Append silent flags if not already present
        if ($args -notmatch "/qn") { $args += " /qn" }
        if ($args -notmatch "/norestart") { $args += " /norestart" }

        Write-Output "  MSI args: $args"
        Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait -ErrorAction SilentlyContinue
    }
    # ── EXE-based uninstall ──
    else {
        # Safely parse quoted or unquoted paths
        if ($cmd -match '^"([^"]+)"\s*(.*)$') {
            $exe  = $matches[1]
            $args = $matches[2].Trim()
        } elseif ($cmd -match '^(\S+)\s*(.*)$') {
            $exe  = $matches[1]
            $args = $matches[2].Trim()
        } else {
            Write-Warning "  Unable to parse uninstall string for: $DisplayName — skipping."
            return
        }

        # Inject silent flags only if not already supplied
        if ($args -notmatch "/quiet" -and $args -notmatch "/qn" -and $args -notmatch "/silent" -and $args -notmatch "/S") {
            $args += " /quiet /norestart"
        }

        Write-Output "  EXE: $exe | Args: $args"
        Start-Process -FilePath $exe -ArgumentList $args -Wait -ErrorAction SilentlyContinue
    }
}

# ── Remove Win32 / MSI apps ───────────────────────────────────────────────────
Write-Output "`n--- Scanning Win32 registry entries ---"
foreach ($root in $UninstallRoots) {
    if (-not (Test-Path $root)) { continue }

    foreach ($item in Get-ChildItem $root -ErrorAction SilentlyContinue) {
        $props = Get-ItemProperty $item.PSPath -ErrorAction SilentlyContinue
        if (-not $props.DisplayName) { continue }

        # Always skip DCU
        if (Test-IsKept $props.DisplayName) {
            Write-Output "  Skipping (protected): $($props.DisplayName)"
            continue
        }

        if (Test-IsBloat $props.DisplayName) {
            Remove-Win32App -DisplayName $props.DisplayName -Entry $props
        }
    }
}

# ── Remove Appx / MSIX packages ───────────────────────────────────────────────
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

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Output "`n=== Dell Bloatware Remediation Completed: $(Get-Date) ==="
Stop-Transcript | Out-Null
exit 0
