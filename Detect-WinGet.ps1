# Silent detection of winget
if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    exit 0  # WinGet is installed
} else {
    exit 1  # WinGet is not installed
}
