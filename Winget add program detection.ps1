try {
    $wingetPath = (Get-Item "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe" -ErrorAction SilentlyContinue) |
        Select-Object -First 1

    if ($wingetPath -or (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        exit 0  # Compliant
    } else {
        exit 1  # Not found
    }
} catch {
    exit 1
}