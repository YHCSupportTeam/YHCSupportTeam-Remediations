<#
.SYNOPSIS
    Detection Script - Dell Bloatware EXCLUDING Dell Command | Update
.DESCRIPTION
    Checks for Dell bloatware via Win32 registry entries and Appx packages.
    Exit 1 = bloatware detected (Intune will trigger remediation)
    Exit 0 = clean
.NOTES
    Designed for use with Microsoft Intune Proactive Remediations.
#>

# ── Apps to flag for removal ──────────────────────────────────────────────────
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

# ── Registry hives to scan (32-bit + 64-bit) ─────────────────────────────────
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

# ── Main ──────────────────────────────────────────────────────────────────────
try {
    # Scan Win32 registry entries
    foreach ($root in $UninstallRoots) {
        if (-not (Test-Path $root)) { continue }

        foreach ($item in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            $props = Get-ItemProperty $item.PSPath -ErrorAction SilentlyContinue
            if (-not $props.DisplayName) { continue }
            if (Test-IsKept $props.DisplayName) { continue }

            if (Test-IsBloat $props.DisplayName) {
                Write-Output "Detected: $($props.DisplayName)"
                exit 1
            }
        }
    }

    # Scan Appx / MSIX packages
    $bloatAppx = Get-AppxPackage -AllUsers -Name "*Dell*" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notlike "*DellCommandUpdate*" -and
            $_.Name -notlike "*Dell.CommandUpdate*"
        }

    if ($bloatAppx) {
        foreach ($pkg in $bloatAppx) {
            Write-Output "Detected Appx: $($pkg.Name)"
        }
        exit 1
    }

    Write-Output "No Dell bloatware found."
    exit 0
}
catch {
    Write-Output "Detection script error: $_"
    exit 0   # Fail open — don't trigger remediation on a script error
}