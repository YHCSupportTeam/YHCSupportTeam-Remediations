<#
.SYNOPSIS
    Invoke-WinGetUpgradeAll.ps1
.DESCRIPTION
    Package 2 Remediation — Runs winget upgrade --all under SYSTEM
    after Package 1 has already ensured WinGet is healthy.
.NOTES
    Version: 3.0
    Run as: SYSTEM (64-bit PowerShell)
#>

$ErrorActionPreference = "Stop"

$logFile   = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.log"
$stampFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.stamp"
$wingetOut = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.output.log"

function Write-Log($m) {
    $dir = Split-Path $logFile
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m" | Out-File $logFile -Append -Encoding UTF8
}

try {
    Write-Log "=== WinGet upgrade START ==="

    # SYSTEM-safe environment
    $systemProfile    = "$env:SystemDrive\Windows\System32\config\systemprofile"
    $env:LOCALAPPDATA = "$systemProfile\AppData\Local"
    $env:APPDATA      = "$systemProfile\AppData\Roaming"
    $env:TEMP         = "$env:SystemDrive\Windows\Temp"
    $env:TMP          = "$env:SystemDrive\Windows\Temp"

    foreach ($p in @($env:LOCALAPPDATA, $env:APPDATA, $env:TEMP)) {
        if (-not (Test-Path $p)) {
            New-Item -Path $p -ItemType Directory -Force | Out-Null
        }
    }

    # Locate WinGet
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'ARM64' } else { 'X64' }

    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction Stop |
           Where-Object { "$($_.Architecture)" -match "^(?i)$arch$" } |
           Sort-Object { [version]$_.Version } -Descending |
           Select-Object -First 1

    if (-not $pkg) {
        throw "DesktopAppInstaller not found. Package 1 repair must run first."
    }

    $winget = Join-Path $pkg.InstallLocation "winget.exe"
    if (-not (Test-Path $winget)) {
        throw "winget.exe missing at $winget"
    }

    $verOut = & $winget --version 2>&1
    if ($LASTEXITCODE -ne 0 -or -not $verOut) {
        throw "winget --version failed. Package 1 repair must run first."
    }

    Write-Log "Using WinGet: $winget"
    Write-Log "WinGet reports: $verOut"

    # Ensure LocalState exists
    $settingsDir = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState"
    if (-not (Test-Path $settingsDir)) {
        New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
    }

    # Refresh source metadata
    Write-Log "Running: winget source update --name winget"
    & $winget source update --name winget --accept-source-agreements 2>&1 |
        Out-File $wingetOut -Append -Encoding UTF8

    # Run upgrade all
    Write-Log "Running: winget upgrade --all"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $winget
    $psi.Arguments = "upgrade --all --source winget --silent --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    "=== STDOUT ===`n$stdout`n=== STDERR ===`n$stderr" |
        Out-File $wingetOut -Append -Encoding UTF8

    Write-Log "WinGet exit code: $($proc.ExitCode)"
    Write-Log "Full output written to $wingetOut"

    # Always stamp to prevent retry storms
    Set-Content -Path $stampFile -Value (Get-Date -Format "o") -Encoding UTF8
    Write-Log "Cooldown stamp written"

    # Non-zero exit may just mean one app failed, so do not fail the whole PR cycle
    if ($proc.ExitCode -ne 0) {
        Write-Log "WinGet completed with non-zero exit code. Review output log for package-specific failures."
    }

    Write-Log "=== WinGet upgrade COMPLETE ==="
    exit 0

} catch {
    Write-Log "FATAL: $($_.Exception.Message)"
    Write-Log "Stack: $($_.ScriptStackTrace)"

    # Optional: still stamp to avoid thrashing if desired
    # Set-Content -Path $stampFile -Value (Get-Date -Format "o") -Encoding UTF8

    exit 1
}