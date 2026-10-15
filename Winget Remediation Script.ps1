<#
.SYNOPSIS
    Repair-WinGetHealth.ps1
.DESCRIPTION
    Package 1 Remediation — Repairs or bootstraps WinGet under SYSTEM.
    Strategy:
        1. Clean broken SYSTEM state
        2. Try re-registration from existing manifest
        3. If still broken, fully provision from GitHub
.NOTES
    Version: 3.0
    Run as:  SYSTEM (64-bit PowerShell)
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$logFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetRepair.log"
$tempDir = "$env:ProgramData\WinGetBootstrap"

New-Item -Path (Split-Path $logFile) -ItemType Directory -Force | Out-Null
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

function Write-Log($m) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m"
    $line | Out-File $logFile -Append -Encoding UTF8
    Write-Output $line
}

function Test-WinGetHealth {
    param([string]$ExpectedArch)
    try {
        $pkg = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
               Where-Object { "$($_.Architecture)" -match "^(?i)$ExpectedArch$" } |
               Sort-Object { [version]$_.Version } -Descending |
               Select-Object -First 1
        if (-not $pkg) { return $null }
        $exe = Join-Path $pkg.InstallLocation 'winget.exe'
        if (-not (Test-Path $exe)) { return $null }
        $ver = & $exe --version 2>&1
        if ($LASTEXITCODE -ne 0 -or -not $ver) { return $null }
        return [pscustomobject]@{ Package = $pkg; Exe = $exe; Version = $ver }
    } catch {
        return $null
    }
}

try {
    Write-Log "=== WinGet Repair START ==="

    $arch        = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $archUpper   = $arch.ToUpper()
    Write-Log "Architecture: $arch"

    # --- Step 1: Clean broken SYSTEM state ---
    Write-Log "Step 1: Cleaning broken SYSTEM state..."
    $systemProfile = "$env:SystemDrive\Windows\System32\config\systemprofile"
    $pathsToClean = @(
        "$systemProfile\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState",
        "$systemProfile\AppData\Local\Microsoft\WinGet",
        "$env:ProgramData\Microsoft\WinGet"
    )
    foreach ($path in $pathsToClean) {
        if (Test-Path $path) {
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Cleaned: $path"
            } catch {
                Write-Log "Warning cleaning $path : $($_.Exception.Message)"
            }
        }
    }

    # Set SYSTEM environment paths
    $env:LOCALAPPDATA = "$systemProfile\AppData\Local"
    $env:APPDATA      = "$systemProfile\AppData\Roaming"
    $env:TEMP         = "$env:SystemDrive\Windows\Temp"
    $env:TMP          = "$env:SystemDrive\Windows\Temp"
    foreach ($p in @($env:LOCALAPPDATA, $env:APPDATA)) {
        if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
    }

    # --- Step 2: Try re-registration from existing manifest ---
    Write-Log "Step 2: Attempting re-registration from existing manifest..."
    try {
        $manifest = Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_${arch}_*\AppxManifest.xml" `
                    -ErrorAction SilentlyContinue |
                    Sort-Object {
                        if ($_.Directory.Name -match '_(\d+\.\d+\.\d+\.\d+)_') { [version]$Matches[1] } else { [version]'0.0.0.0' }
                    } -Descending |
                    Select-Object -First 1

        if ($manifest) {
            Add-AppxPackage -DisableDevelopmentMode -Register $manifest.FullName -ErrorAction Stop
            Write-Log "Re-registered from $($manifest.FullName)"
            Start-Sleep -Seconds 3

            $health = Test-WinGetHealth -ExpectedArch $archUpper
            if ($health) {
                Write-Log "SUCCESS: Re-registration worked. WinGet v$($health.Package.Version), $($health.Version)"
                exit 0
            } else {
                Write-Log "Re-registration completed but WinGet still unhealthy. Falling through to full provision."
            }
        } else {
            Write-Log "No existing manifest found. Falling through to full provision."
        }
    } catch {
        Write-Log "Re-registration failed: $($_.Exception.Message). Falling through to full provision."
    }

    # --- Step 3: Full provision from GitHub ---
    Write-Log "Step 3: Full provision from GitHub..."

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
    Write-Log "Latest WinGet release: $($release.tag_name)"

    $msixAsset = $release.assets |
                 Where-Object { $_.name -like '*.msixbundle' -and $_.name -notlike '*Preview*' } |
                 Select-Object -First 1
    $licenseAsset = $release.assets |
                    Where-Object { $_.name -like '*License1.xml' } |
                    Select-Object -First 1

    if (-not $msixAsset) { throw "No msixbundle asset found in release." }

    $wingetBundle = Join-Path $tempDir 'WinGet.msixbundle'
    Write-Log "Downloading $($msixAsset.name)..."
    Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile $wingetBundle -UseBasicParsing

    $licensePath = $null
    if ($licenseAsset) {
        $licensePath = Join-Path $tempDir 'License1.xml'
        Invoke-WebRequest -Uri $licenseAsset.browser_download_url -OutFile $licensePath -UseBasicParsing
        Write-Log "Downloaded license file"
    }

    # VCLibs
    $vcLibsUrl  = "https://aka.ms/Microsoft.VCLibs.$arch.14.00.Desktop.appx"
    $vcLibsPath = Join-Path $tempDir "VCLibs.$arch.appx"
    Write-Log "Downloading VCLibs..."
    Invoke-WebRequest -Uri $vcLibsUrl -OutFile