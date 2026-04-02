# Register-RestartDot3SvcTask.ps1
# Intune Device Script – SYSTEM, 64-bit

$TaskName = "Restart Wired AutoConfig (Startup + Resume)"
$BasePath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Scripts"
$Script   = "$BasePath\Restart-dot3svc.ps1"
$LogPath  = "$BasePath\Logs"
$LogFile  = "$LogPath\Task-Registration.log"

function Write-Log {
    param([string]$Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Time] $Message"
}

if (-not (Test-Path $Script)) {
    Write-Log "ERROR: Remediation script not found at $Script"
    exit 1
}

if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

Write-Log "=== Scheduled Task Registration Started ==="

try {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Log "Existing task removed."
    }

    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Script`""

    # Trigger 1: System startup
    $StartupTrigger = New-ScheduledTaskTrigger -AtStartup

    # Trigger 2: Resume from sleep / hibernate
    $ResumeTrigger = New-ScheduledTaskTrigger -OnEvent `
        -Log "System" `
        -Source "Microsoft-Windows-Power-Troubleshooter" `
        -EventId 1

    $Principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    $Settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger @($StartupTrigger, $ResumeTrigger) `
        -Principal $Principal `
        -Settings $Settings `
        -Force | Out-Null

    Write-Log "SUCCESS: Scheduled task '$TaskName' registered."
    Write-Log "Triggers: Startup + Resume from Sleep (Power-Troubleshooter Event ID 1)"
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}