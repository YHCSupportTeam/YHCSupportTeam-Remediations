$Shortcuts2Remove = "VLC media player.lnk", "Adobe Acrobat.lnk", "Google Earth Pro.lnk", "Firefox.lnk"
$DesktopPath = "C:\Users\Public\Desktop", "C:\Users\*\Desktop\*" # Public and User Desktop: "C:\Users\*\Desktop\*", for Public Desktop shortcuts only: "C:\Users\Public\Desktop" 
$ShortcutsOnClient = Get-ChildItem $DesktopPath

try{
    $($ShortcutsOnClient | Where-Object -FilterScript {$_.Name -in $Shortcuts2Remove }) | Remove-Item -Force
    Write-Host "Unwanted shortcut(s) removed."
}catch{
    Write-Error "Error removing shortcut(s)"
}
