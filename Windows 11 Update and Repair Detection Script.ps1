$CurrentWin10 = [Version]"10.0.19045"
$CurrentWin11 = [Version]"10.0.22631"

$GetOS = Get-ComputerInfo -property OsVersion
$OSversion = [Version]$GetOS.OsVersion

if  ($OSversion -match [Version]"10.0.1")
    {
    if  ($OSversion -lt $CurrentWin10)
        {
        Write-Output "OS version currently on $OSversion"
        exit 1
        }
    }

if  ($OSversion -match [Version]"10.0.2")
    {
    if  ($OSversion -lt $CurrentWin11)
        {
        Write-Output "OS version currently on $OSversion"
        exit 1
        }
    }

$lastupdate = Get-HotFix | Sort-Object -Property @{Expression = { if ($_.InstalledOn) { [datetime]::Parse($_.InstalledOn) } else { [datetime]::MinValue } }} | Select-Object -Last 1 -ExpandProperty InstalledOn

$Date = Get-Date

$diff = New-TimeSpan -Start $lastupdate -end $Date
$days = $diff.Days
if  ($days -ge 40)
    {
     Write-Output "Troubleshooting Updates - Last update was $days days ago"
     exit 1
    }
else{
 Write-Output "Windows Updates ran $days days ago"
    exit 0
    }