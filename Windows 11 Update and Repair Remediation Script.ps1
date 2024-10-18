$CurrentWin10 = "10.0.19045"
$CurrentWin11 = "10.0.22631"

Start-Transcript -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\#Windows Updates - Health Check.log"

#Run Windows Update troubleshooter
Get-TroubleshootingPack -Path C:\Windows\diagnostics\system\WindowsUpdate | 
Invoke-TroubleshootingPack -Unattended

#Run DISM
Repair-WindowsImage -RestoreHealth -NoRestart -Online -LogPath "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\#DISM.log" -Verbose -ErrorAction SilentlyContinue

#Check registry for pauses
$Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$TestPath = Test-Path $Path
if  ($TestPath -eq $true)
    {
    Write-Output "Deleting $Path"
    Remove-Item -Path $Path -Recurse -Verbose
    }

$key = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings"
$key2 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
$key3 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
$key4 = "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Appraiser\GWX"
$val = (Get-Item $key);
$val2 = (Get-Item $key2);
$val3 = (Get-Item $key3);
$val4 = (Get-Item $key4);

$PausedQualityDate = (Get-Item $key -EA Ignore).Property -contains "PausedQualityDate"
$PausedFeatureDate = (Get-Item $key -EA Ignore).Property -contains "PausedFeatureDate"
$PausedQualityStatus = (Get-Item $key -EA Ignore).Property -contains "PausedQualityStatus"
$PausedQualityStatusValue = $val.GetValue("PausedQualityStatus");
$PausedFeatureStatus = (Get-Item $key -EA Ignore).Property -contains "PausedFeatureStatus"
$PausedFeatureStatusValue = $val.GetValue("PausedFeatureStatus");

$PauseQualityUpdatesStartTime = (Get-Item $key2 -EA Ignore).Property -contains "PauseQualityUpdatesStartTime"
$PauseFeatureUpdatesStartTime = (Get-Item $key2 -EA Ignore).Property -contains "PauseFeatureUpdatesStartTime"
$PauseQualityUpdates = (Get-Item $key2 -EA Ignore).Property -contains "PauseQualityUpdates"
$PauseQualityUpdatesValue = $val2.GetValue("PauseQualityUpdates");
$PauseFeatureUpdates = (Get-Item $key2 -EA Ignore).Property -contains "PauseFeatureUpdates"
$PauseFeatureUpdatesValue = $val2.GetValue("PauseFeatureUpdates");
$DeferFeatureUpdates = (Get-Item $key2 -EA Ignore).Property -contains "DeferFeatureUpdatesPeriodInDays"
$DeferFeatureUpdatesValue = $val2.GetValue("DeferFeatureUpdatesPeriodInDays");

$AllowDeviceNameInTelemetry = (Get-Item $key3 -EA Ignore).Property -contains "AllowDeviceNameInTelemetry"
$AllowTelemetry_PolicyManager = (Get-Item $key3 -EA Ignore).Property -contains "AllowTelemetry_PolicyManager"
$AllowDeviceNameInTelemetryValue = $val3.GetValue("AllowDeviceNameInTelemetry");
$AllowTelemetry_PolicyManagerValue = $val3.GetValue("AllowTelemetry_PolicyManager");

$GStatus = (Get-Item $key4 -EA Ignore).Property -contains "GStatus"
$GStatusValue = $val4.GetValue("GStatus");

if  ($PausedQualityDate -eq $true)
    {
    Write-Output "PausedQualityDate under $key present"
    Remove-ItemProperty -Path $key -Name "PausedQualityDate" -Verbose
    $PausedQualityDate = (Get-Item $key -EA Ignore).Property -contains "PausedQualityDate"
    }

if  ($PausedFeatureDate -eq $true)
    {
    Write-Output "PausedFeatureDate under $key present"
    Remove-ItemProperty -Path $key -Name "PausedFeatureDate" -Verbose
    $PausedFeatureDate = (Get-Item $key -EA Ignore).Property -contains "PausedFeatureDate"
    }

if  ($PausedQualityStatus -eq $true)
    {
    Write-Output "PausedQualityStatus under $key present"
    Write-Output "Currently set to $PausedQualityStatusValue"
    if  ($PausedQualityStatusValue -ne "0")
        {
        Set-ItemProperty -Path $key -Name "PausedQualityStatus" -Value "0" -Verbose
        $PausedQualityStatusValue = $val.GetValue("PausedQualityStatus");
        }
    }

if  ($PausedFeatureStatus -eq $true)
    {
    Write-Output "PausedFeatureStatus under $key present"
    Write-Output "Currently set to $PausedFeatureStatusValue"
    if  ($PausedFeatureStatusValue -ne "0")
        {
        Set-ItemProperty -Path $key -Name "PausedFeatureStatus" -Value "0" -Verbose
        $PausedFeatureStatusValue = $val.GetValue("PausedFeatureStatus");
        }
    }

if  ($DeferFeatureUpdates -eq $true)
    {
    Write-Output "DeferFeatureUpdatesPeriodInDays under $key2 present"
    Write-Output "Currently set to $DeferFeatureUpdatesValue"
    if  ($DeferFeatureUpdatesValue -ne "0")
        {
        Set-ItemProperty -Path $key2 -Name "DeferFeatureUpdatesPeriodInDays" -Value "0" -Verbose
        $DeferFeatureUpdatesValue = $val2.GetValue("DeferFeatureUpdatesPeriodInDays");
        }
    }    

if  ($PauseQualityUpdatesStartTime -eq $true)
    {
    Write-Output "PauseQualityUpdatesStartTime under $key2 present"
    Remove-ItemProperty -Path $key2 -Name "PauseQualityUpdatesStartTime" -Verbose
    Remove-ItemProperty -Path $key2 -Name "PauseQualityUpdatesStartTime_ProviderSet" -Verbose
    Remove-ItemProperty -Path $key2 -Name "PauseQualityUpdatesStartTime_WinningProvider" -Verbose
    $PauseQualityUpdatesStartTime = (Get-Item $key2 -EA Ignore).Property -contains "PauseQualityUpdatesStartTime"
    }

if  ($PauseFeatureUpdatesStartTime -eq $true)
    {
    Write-Output "PauseFeatureUpdatesStartTime under $key2 present"
    Remove-ItemProperty -Path $key2 -Name "PauseFeatureUpdatesStartTime" -Verbose
    Remove-ItemProperty -Path $key2 -Name "PauseFeatureUpdatesStartTime_ProviderSet" -Verbose
    Remove-ItemProperty -Path $key2 -Name "PauseFeatureUpdatesStartTime_WinningProvider" -Verbose
    $PauseFeatureUpdatesStartTime = (Get-Item $key2 -EA Ignore).Property -contains "PauseFeatureUpdatesStartTime"
    }

if  ($PauseQualityUpdates -eq $true)
    {
    Write-Output "PauseQualityUpdates under $key2 present"
    Write-Output "Currently set to $PauseQualityUpdatesValue"
    if  ($PauseQualityUpdatesValue -ne "0")
        {
        Set-ItemProperty -Path $key2 -Name "PauseQualityUpdates" -Value "0" -Verbose
        $PauseQualityUpdatesValue = $val2.GetValue("PausedQualityStatus");
        }
    }

if  ($PauseFeatureUpdates -eq $true)
    {
    Write-Output "PauseFeatureUpdates under $key2 present"
    Write-Output "Currently set to $PauseFeatureUpdatesValue"
    if  ($PauseFeatureUpdatesValue -ne "0")
        {
        Set-ItemProperty -Path $key2 -Name "PauseFeatureUpdates" -Value "0" -Verbose
        $PauseFeatureUpdatesValue = $val2.GetValue("PauseFeatureUpdates");
        }
    }

if  ($AllowDeviceNameInTelemetry -eq $true)
    {
    Write-Output "AllowDeviceNameInTelemetry under $key3 present"
    Write-Output "Currently set to $AllowDeviceNameInTelemetryValue"
    }
else{New-ItemProperty -Path $key3 -PropertyType DWORD -Name "AllowDeviceNameInTelemetry" -Value "1" -Verbose}

if  ($AllowDeviceNameInTelemetryValue -ne "1")
    {Set-ItemProperty -Path $key3 -Name "AllowDeviceNameInTelemetry" -Value "1" -Verbose}

if  ($AllowTelemetry_PolicyManager -eq $true)
    {
    Write-Output "AllowTelemetry_PolicyManager under $key3 present"
    Write-Output "Currently set to $AllowTelemetry_PolicyManagerValue"
    }
else{New-ItemProperty -Path $key3 -PropertyType DWORD -Name "AllowTelemetry_PolicyManager" -Value "1" -Verbose}

if  ($AllowTelemetry_PolicyManagerValue -ne "1")
    {Set-ItemProperty -Path $key3 -Name "AllowTelemetry_PolicyManager" -Value "1" -Verbose}

if  ($GStatus -eq $true) 
    {
    Write-Output "GStatus under $key4 present"
    Write-Output "Currently set to $GStatusValue"
    }
else{New-ItemProperty -Path $key4 -PropertyType DWORD -Name "GStatus" -Value "2" -Verbose}

if  ($GStatusValue -ne "2")
    {Set-ItemProperty -Path $key4 -Name "GStatus" -Value "2" -Verbose}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Check for Nuget
$CheckNuget = Get-PackageProvider
if  ($CheckNuget.Name -eq "Nuget")
    {Write-Host "Nuget module found"}
else{
    Write-Host "Installing Nuget module"  
    Install-PackageProvider Nuget -Force -Verbose -ErrorAction SilentlyContinue
    }

#Check for Feature Update blocks
$GetOS = Get-ComputerInfo -property OsVersion
$OSversion = $GetOS.OsVersion

if  ($OSversion -match "10.0.1")
    {
    if  ($OSversion -lt $CurrentWin10)
        {
        $CheckWhyAmIBlocked = Get-InstalledModule
        if  ($CheckWhyAmIBlocked.Name -eq "FU.WhyAmIBlocked")
            {Write-Host "FU.WhyAmIBlocked module found"}
        else{
            Write-Host "Installing FU.WhyAmIBlocked module"  
            Install-Module FU.WhyAmIBlocked -Force -Verbose -ErrorAction SilentlyContinue
            }
        Import-Module FU.WhyAmIBlocked -Verbose 
        Get-FUBlocks -Verbose -ErrorAction SilentlyContinue
        }
    else{Write-Output "OS on version ""$OSversion"""}   
    } 

if  ($OSversion -match "10.0.2")
    {
    if  ($OSversion -lt $CurrentWin11)
        {
        $CheckWhyAmIBlocked = Get-InstalledModule
        if  ($CheckWhyAmIBlocked.Name -eq "FU.WhyAmIBlocked")
            {Write-Host "FU.WhyAmIBlocked module found"}
        else{
            Write-Host "Installing FU.WhyAmIBlocked module"  
            Install-Module FU.WhyAmIBlocked -Force -Verbose -ErrorAction SilentlyContinue
            }
        Import-Module FU.WhyAmIBlocked -Verbose
        Get-FUBlocks -Verbose -ErrorAction SilentlyContinue
        }
    else{Write-Output "OS on version ""$OSversion"""}
    } 

$CheckPSWindowsUpdate = Get-InstalledModule
if  ($CheckPSWindowsUpdate.Name -eq "PSWindowsUpdate")
    {Write-Host "PSWindowsUpdate module found"}
else{
    Write-Host "Installing PSWindowsUpdate module"  
    Install-Module PSWindowsUpdate -Force -Verbose -ErrorAction SilentlyContinue
    }

Import-Module PSWindowsUpdate -Verbose

try {
    Write-Output "Resetting Windows Update Components"
    Reset-WUComponents -Verbose -ErrorAction SilentlyContinue
    }

catch {Write-Output "An error occurred while resetting Windows Update Components: $_"}

# Check for Windows updates
try {
    Write-Output "Checking for Windows updates"
    Get-WindowsUpdate -Install -AcceptAll -UpdateType Software -IgnoreReboot -Verbose -ErrorAction SilentlyContinue
    }

catch {Write-Output "An error occurred while checking for Windows updates: $_"}

Stop-Transcript