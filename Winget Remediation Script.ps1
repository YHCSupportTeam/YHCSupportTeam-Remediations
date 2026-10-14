<#
Run as: SYSTEM (64-bit)
Description: Runs winget upgrade --all safely under SYSTEM profile
#>
$ErrorActionPreference = "Stop"
$logFile   = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.log"
$stampFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.stamp"
$wingetOut = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetUpgrade.output.log"

function Write-Log($m) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m" | Out-File $logFile -Append -Encoding UTF8
}

try {
    Write-Log "=== WinGet Remediation Execution START ==="

    # Reconstruct standard systemprofile environment variables
    $sysProfile       = "$env:SystemDrive\Windows\System32\config\systemprofile"
    $env:LOCALAPPDATA = "$sysProfile\AppData\Local"
    $env:APPDATA      = "$sysProfile\AppData\Roaming"
    $env:TEMP         = "$env:SystemDrive\Windows\Temp"
    $env:TMP          = "$env:SystemDrive\Windows\Temp"

    foreach ($dir in @($env:LOCALAPPDATA, $env:APPDATA)) {
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    }

    $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction Stop |
           Where-Object { $_.Architecture -match '(?i)x64|arm64' } |
           Sort-Object { [version]$_.Version } -Descending |
           Select-Object -First 1

    if (-not $pkg) { throw "DesktopAppInstaller package not found." }

    $winget = Join-Path $pkg.InstallLocation "winget.exe"
    if (-not (Test-Path $winget)) { throw "winget.exe missing from $($pkg.InstallLocation)" }

    Write-Log "Executing upgrade with: $winget"

    # Refresh standard winget source catalog
    & $winget source update --name winget --accept-source-agreements 2>&1 | Out-File $wingetOut -Append -Encoding UTF8

    # Execute upgrade with system-safe flags
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

    "=== STDOUT ===`n$stdout`n=== STDERR ===`n$stderr" | Out-File $wingetOut -Append -Encoding UTF8

    Write-Log "Process exited with code: $($proc.ExitCode)"
    Set-Content -Path $stampFile -Value (Get-Date -Format "o") -Encoding UTF8
    Write-Log "=== WinGet Remediation Execution COMPLETE ==="
    exit 0

} catch {
    Write-Log "FATAL: $($_.Exception.Message)"
    exit 1
}