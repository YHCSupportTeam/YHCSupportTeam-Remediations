$Desktop = [Environment]::GetFolderPath("Desktop")
Remove-Item "$Desktop\Chrome MLC.lnk" -Force
Remove-Item "$Desktop\Edge MLC.lnk" -Force

$TaskbarFolder = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
Remove-Item "$TaskbarFolder\Chrome MLC.lnk" -Force
Remove-Item "$TaskbarFolder\Edge MLC.lnk" -Force