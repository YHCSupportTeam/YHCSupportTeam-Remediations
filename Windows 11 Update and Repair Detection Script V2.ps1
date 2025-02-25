$CurrentWin10 = [Version]"10.0.19045"
$CurrentWin11 = [Version]"10.0.26100"

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

do  {
    try {
        $lastupdate = Get-HotFix | Sort-Object -Property InstalledOn | Select-Object -Last 1 -ExpandProperty InstalledOn
        $Date = Get-Date

        $diff = New-TimeSpan -Start $lastupdate -end $Date
        $days = $diff.Days
        }
    catch   {
            Write-Output "Attempting WMI repair"
            Start-Process "C:\Windows\System32\wbem\WMIADAP.exe" -ArgumentList "/f"
            Start-Sleep -Seconds 120
            }
    }
    until ($null -ne $days)

$Date = Get-Date

$diff = New-TimeSpan -Start $lastupdate -end $Date
$days = $diff.Days

if  ($days -ge 40 -or $null -eq $days)
    {
    Write-Output "Troubleshooting Updates - Last update was $days days ago"
    exit 1
    }
else{
    Write-Output "Windows Updates ran $days days ago"
    exit 0
    }