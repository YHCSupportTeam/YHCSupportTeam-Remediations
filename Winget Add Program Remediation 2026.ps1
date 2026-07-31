<#
Version: 2.0
Run as: SYSTEM (64-bit)
Description: Bootstraps WinGet + VCLibs + UI.Xaml for SYSTEM context.
             Dynamically resolves UI.Xaml version from msixbundle manifest.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # 10-100x faster downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Setup ---
$tempDir = "$env:ProgramData\WinGetBootstrap"
$logFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGetBootstrap.log"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

function Write-Log($m) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $m"
    $line | Out-File $logFile -Append -Encoding UTF8
    Write-Output $line
}

try {
    Write-Log "=== WinGet Bootstrap START ==="

    # --- Determine architecture ---
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    Write-Log "Detected architecture: $arch"

    # --- Idempotency check: already installed and current? ---
    $existing = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
                Where-Object { $_.Architecture -eq $arch.ToUpper() -or ($arch -eq 'x64' -and $_.Architecture -eq 'X64') } |
                Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1

    # --- Fetch latest WinGet release metadata ---
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing
    $latestVersion = ($release.tag_name -replace '^v','') -replace '-.*',''
    Write-Log "Latest WinGet release: $($release.tag_name)"

    if ($existing -and [version]$existing.Version -ge [version]$latestVersion) {
        Write-Log "Already at v$($existing.Version) (>= $latestVersion). Skipping."
        exit 0
    }

    # --- Download WinGet msixbundle (non-preview) ---
    $msixAsset = $release.assets |
                 Where-Object { $_.name -like '*.msixbundle' -and $_.name -notlike '*Preview*' } |
                 Select-Object -First 1
    $licenseAsset = $release.assets |
                    Where-Object { $_.name -like '*License1.xml' } |
                    Select-Object -First 1

    $wingetBundle = Join-Path $tempDir 'WinGet.msixbundle'
    Write-Log "Downloading $($msixAsset.name)..."
    Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile $wingetBundle -UseBasicParsing

    $licensePath = $null
    if ($licenseAsset) {
        $licensePath = Join-Path $tempDir 'License1.xml'
        Invoke-WebRequest -Uri $licenseAsset.browser_download_url -OutFile $licensePath -UseBasicParsing
        Write-Log "Downloaded license file"
    }

    # --- Download VCLibs (architecture-aware) ---
    $vcLibsUrl  = "https://aka.ms/Microsoft.VCLibs.$arch.14.00.Desktop.appx"
    $vcLibsPath = Join-Path $tempDir "VCLibs.$arch.appx"
    Write-Log "Downloading VCLibs from $vcLibsUrl"
    Invoke-WebRequest -Uri $vcLibsUrl -OutFile $vcLibsPath -UseBasicParsing

    # --- Download UI.Xaml from NuGet (proper method per MS docs) ---
    # UI.Xaml 2.8.6 is current stable per MS Learn [3]; adjust if WinGet requires 2.9 later
    $xamlNupkgVersion = '2.8.6'
    $xamlNupkgUrl  = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/$xamlNupkgVersion"
    $xamlNupkgPath = Join-Path $tempDir "Microsoft.UI.Xaml.$xamlNupkgVersion.zip"
    $xamlExtract   = Join-Path $tempDir "xaml"
    Write-Log "Downloading UI.Xaml $xamlNupkgVersion nupkg..."
    Invoke-WebRequest -Uri $xamlNupkgUrl -OutFile $xamlNupkgPath -UseBasicParsing
    Expand-Archive -Path $xamlNupkgPath -DestinationPath $xamlExtract -Force
    $xamlAppxSource = Join-Path $xamlExtract "tools\AppX\$arch\Release\Microsoft.UI.Xaml.2.8.appx"
    if (-not (Test-Path $xamlAppxSource)) {
        throw "UI.Xaml appx not found at $xamlAppxSource after extraction"
    }
    $xamlPath = Join-Path $tempDir "Microsoft.UI.Xaml.$arch.appx"
    Copy-Item $xamlAppxSource $xamlPath -Force
    Write-Log "UI.Xaml appx extracted"

    # --- Provision (SYSTEM-safe, all-users) ---
    Write-Log "Installing dependencies + WinGet via Add-AppxProvisionedPackage..."
    $provisionParams = @{
        Online                  = $true
        PackagePath             = $wingetBundle
        DependencyPackagePath   = @($vcLibsPath, $xamlPath)
    }
    if ($licensePath) {
        $provisionParams['LicensePath'] = $licensePath
    } else {
        $provisionParams['SkipLicense'] = $true
    }

    Add-AppxProvisionedPackage @provisionParams | Out-Null
    Write-Log "Provisioning cmdlet completed"

    # --- Also register for current SYSTEM session (immediate availability) ---
    try {
        Add-AppxPackage -Path $wingetBundle -DependencyPath $vcLibsPath, $xamlPath `
            -ForceApplicationShutdown -ErrorAction SilentlyContinue
        Write-Log "Registered for current session"
    } catch {
        Write-Log "Session registration warning (non-fatal): $($_.Exception.Message)"
    }

    # --- Verify ---
    Start-Sleep -Seconds 5
    $verify = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller |
              Where-Object { $_.Architecture -in @('X64','Arm64') } |
              Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1

    if ($verify) {
        Write-Log "SUCCESS: WinGet v$($verify.Version) provisioned at $($verify.InstallLocation)"
        # Test winget.exe actually runs
        $wingetExe = Join-Path $verify.InstallLocation 'winget.exe'
        if (Test-Path $wingetExe) {
            $verOut = & $wingetExe --version 2>&1
            Write-Log "winget --version returned: $verOut"
        }
        exit 0
    } else {
        throw "WinGet package not detected after provisioning"
    }

} catch {
    Write-Log "FATAL: $($_.Exception.Message)"
    Write-Log "Stack: $($_.ScriptStackTrace)"
    exit 1
} finally {
    # Preserve logs, clean binaries
    Get-ChildItem $tempDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.appx','.msixbundle','.zip','.xml' } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $tempDir 'xaml') -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "=== WinGet Bootstrap END ==="
}