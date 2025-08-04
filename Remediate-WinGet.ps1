# Silent remediation to install WinGet (App Installer)

# Ensure script runs as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    exit 1
}

# Check if winget is already installed
if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    exit 0
}

# Define the App Installer package URI (offline installer)
$installerUrl = "https://aka.ms/getwinget"

# Define temp path
$tempInstaller = "$env:TEMP\AppInstaller.msixbundle"

# Download the installer silently
Invoke-WebRequest -Uri $installerUrl -OutFile $tempInstaller -UseBasicParsing

# Install the package silently
Add-AppxPackage -Path $tempInstaller -ForceApplicationShutdown

# Clean up
Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue

# Final check
if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    exit 0
} else {
    exit 1
}
