$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$EdgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$URL = "https://www.yhc.edu/mountain-lion-central/"
$Desktop = [Environment]::GetFolderPath("Desktop")

$Shell = New-Object -ComObject WScript.Shell

# Chrome Shortcut
$ChromeShortcut = "$Desktop\Chrome MLC.lnk"
$ChromeLink = $Shell.CreateShortcut($ChromeShortcut)
$ChromeLink.TargetPath = $ChromePath
$ChromeLink.Arguments = "--incognito $URL"
$ChromeLink.IconLocation = "$ChromePath, 0"
$ChromeLink.Save()

# Edge Shortcut
$EdgeShortcut = "$Desktop\Edge MLC.lnk"
$EdgeLink = $Shell.CreateShortcut($EdgeShortcut)
$EdgeLink.TargetPath = $EdgePath
$EdgeLink.Arguments = "--inprivate $URL"
$EdgeLink.IconLocation = "$EdgePath, 0"
$EdgeLink.Save()

# Pin to Taskbar
function Pin-AppToTaskbar {
    param (
        [string]$ShortcutPath
    )
    $TaskbarFolder = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    if (!(Test-Path $TaskbarFolder)) {
        New-Item -ItemType Directory -Path $TaskbarFolder | Out-Null
    }
    Copy-Item $ShortcutPath -Destination $TaskbarFolder -Force
}

Pin-AppToTaskbar -ShortcutPath $ChromeShortcut
Pin-AppToTaskbar -ShortcutPath $EdgeShortcut