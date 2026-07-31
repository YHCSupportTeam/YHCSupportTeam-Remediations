<#
Version: 2.0
Run as: SYSTEM (64-bit)
Description: Runs winget upgrade --all with SYSTEM-hardened environment.
#>

$ErrorActionPreference = "Stop"
$logFile   = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.log"
$stampFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.stamp"
$wingetOut = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.output.log"

function Write-Log($m) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m" | Out-File $logFile -Append -Encoding UTF8
}

try {
    Write-Log "=== WinGet remediation START ==="

    # --- SYSTEM environment bootstrap FIRST ---
    $systemProfile    = "$env:SystemDrive\Windows\System32\config\systemprofile"
    $env:LOCALAPPDATA = "$systemProfile\AppData\Local"
    $env:APPDATA      = "$systemProfile\AppData\Roaming"
    $env:TEMP         = "$env:SystemDrive\Windows\Temp"
    $env:TMP          = "$env:SystemDrive\Windows\Temp"

    foreach ($p in @($env:LOCALAPPDATA, $env:APPDATA)) {
        if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
    }

    # --- Version-aware winget locator ---
    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller |
           Where-Object { $_.Architecture -eq 'X64' } |
           Sort-Object { 
[version]$_.Version } -Descending |
           Select-Object -First 1

    if (-not $pkg) {
        Write-Log "FATAL: DesktopAppInstaller not registered for SYSTEM. Attempting Add-AppxPackage repair..."
        # Attempt to re-register from disk
        $manifest = Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64_*\AppxManifest.xml" `
                    -ErrorAction SilentlyContinue |
                    Sort-Object { 
[version]($_.Directory.Name -replace '.*_(\d+\.\d+\.\d+\.\d+)_.*','$1') } -Descending |
                    Select-Object -First 1
        if ($manifest) {
            Add-AppxPackage -DisableDevelopmentMode -Register $manifest.FullName -ErrorAction Stop
            Write-Log "Re-registered DesktopAppInstaller from $($manifest.FullName)"
            $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller |
                   Where-Object { $_.Architecture -eq 'X64' } |
                   Sort-Object { 
[version]$_.Version } -Descending |
                   Select-Object -First 1
        }
        if (-not $pkg) { throw "Cannot locate or register DesktopAppInstaller." }
    }

    $winget = Join-Path $pkg.InstallLocation "winget.exe"
    Write-Log "Using WinGet: $winget (v$($pkg.Version))"

    # Version check
    $verOut = & $winget --version 2>&1
    Write-Log "WinGet reports: $verOut"

    # --- Ensure settings.json exists (minimal) ---
    $settingsDir = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState"
    if (-not (Test-Path $settingsDir)) { New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null }

    # --- Skip source reset unless truly needed ---
    # (Removed cache wipe + forced source reset — these caused most failures)
    Write-Log "Accepting source agreements (no reset)"
    & $winget source update --name winget --accept-source-agreements 2>&1 | 
        Out-File $wingetOut -Append -Encoding UTF8

    # --- Run upgrade with file redirection (captures ALL output) ---
    Write-Log "Running: winget upgrade --all"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $winget
    $psi.Arguments = "upgrade --all --source winget --silent --include-unknown " +
                     "--accept-source-agreements --accept-package-agreements --disable-interactivity"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true

    $proc = 
[System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    "=== STDOUT ===`n$stdout`n=== STDERR ===`n$stderr" | 
        Out-File $wingetOut -Append -Encoding UTF8
    Write-Log "WinGet exit code: $($proc.ExitCode)"
    Write-Log "Full output written to $wingetOut"

    # Stamp cooldown regardless (prevents runaway retries)
    Set-Content -Path $stampFile -Value (Get-Date -Format "o") -Encoding UTF8
    Write-Log "Cooldown stamp written"
    Write-Log "=== WinGet remediation COMPLETE ==="
    exit 0

} catch {
    Write-Log "FATAL: $($_.Exception.Message)"
    Write-Log "Stack: $($_.ScriptStackTrace)"
    exit 1
}