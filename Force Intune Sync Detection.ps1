$logFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneSync-Detection.log"

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

try {
    Write-Log "===== Detection Script Started ====="
    Write-Log "Computer: $env:COMPUTERNAME"
    Write-Log "User: $env:USERNAME"

    # Find the Intune enrollment scheduled task
    Write-Log "Searching for Intune OMADMClient scheduled task..."
    $task = Get-ScheduledTask | Where-Object { 
        $_.TaskPath -like "*EnterpriseMgmt*" -and 
        $_.TaskName -like "*OMADMClient*" 
    } | Select-Object -First 1

    if (-not $task) {
        Write-Log "ERROR: No Intune enrollment found on this device"
        Write-Host "No Intune enrollment found on this device"
        exit 1
    }

    Write-Log "Found task: $($task.TaskName) at path: $($task.TaskPath)"

    # Get last sync time
    $taskInfo = $task | Get-ScheduledTaskInfo
    $lastSync = $taskInfo.LastRunTime
    $lastResult = $taskInfo.LastTaskResult
    [int]$lastSyncHours = (New-TimeSpan -Start $lastSync -End (Get-Date)).TotalHours
    [int]$lastSyncDays = (New-TimeSpan -Start $lastSync -End (Get-Date)).TotalDays

    Write-Log "Last sync time: $lastSync"
    Write-Log "Last sync result code: $lastResult"
    Write-Log "Hours since last sync: $lastSyncHours"
    Write-Log "Days since last sync: $lastSyncDays"

    # Check last task result code (0 = success)
    if ($lastResult -ne 0) {
        Write-Log "WARNING: Last sync completed with error code $lastResult"
    }

    if ($lastSyncDays -gt 1) {
        Write-Log "RESULT: Non-compliant - Last sync was $lastSyncDays day(s) ago (threshold: 1 day)"
        Write-Host "Non-compliant: Last sync was more than 1 day ago"
        Write