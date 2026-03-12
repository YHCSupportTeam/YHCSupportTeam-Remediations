# WinGet installation with dependencies - compatible with SYSTEM context

$ErrorActionPreference = "Stop"
$tempDir = "$env:TEMP\WinGetInstall"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # --- Download Dependencies ---

    # 1. VCLibs
    $vcLibsUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
    $vcLibsPath = "$tempDir\VCLibs.appx"
    Invoke-WebRequest -Uri $vcLibsUrl -OutFile $vcLibsPath -UseBasicParsing

    # 2. Microsoft.UI.Xaml (required for WinGet 1.x+)
    $xamlUrl = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
    $xamlPath = "$tempDir\Microsoft.UI.Xaml.appx"
    Invoke-WebRequest -Uri $xamlUrl -OutFile $xamlPath -UseBasicParsing

    # 3. WinGet itself (direct from GitHub latest release)
    $wingetApiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
    $release = Invoke-RestMethod -Uri $wingetApiUrl -UseBasicParsing
    $msixBundle = $release.assets | Where-Object { $_.name -match "\.msixbundle$" } | Select-Object -First 1
    $wingetPath = "$tempDir\WinGet.msixbundle"
    Invoke-WebRequest -Uri $msixBundle.browser_download_url -OutFile $wingetPath -UseBasicParsing

    # --- Install via Add-AppxProvisionedPackage (works under SYSTEM) ---
    Add-AppxProvisionedPackage -Online -PackagePath $wingetPath `
        -DependencyPackagePath $vcLibsPath, $xamlPath `
        -SkipLicense

    # --- Verify ---
    Start-Sleep -Seconds 5
    $installed = Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe" `
        -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($installed) {
        exit 0
    } else {
        exit 1
    }

} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}