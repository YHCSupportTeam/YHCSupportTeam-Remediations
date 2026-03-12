$logFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneSync-Remediation.log"

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

try {
    Write-Log "===== Remediation Script Started ====="
    Write-Log "Computer: $env:COMPUTERNAME"
    Write-Log "User: $env:USERNAME"
    Write-Log "Time: $(Get-Date)"

    # Find the Intune enrollment scheduled task
    Write-Log "Searching for Intune OMADMClient scheduled task..."
    $task = Get-ScheduledTask | Where-Object { 
        $_.TaskPath -like "*EnterpriseMgmt*" -and 
        $_.TaskName -like "*OMADMClient*" 
    } | Select-Object -First 1

    if (-not $task) {
        Write-Log "ERROR: No Intune enrollment found - cannot trigger sync"
        Write-Host "No Intune enrollment found - cannot sync"
        Write-Log "===== Remediation Script Ended - Exit 1 ====="
        exit 1
    }

    Write-Log "Found task: $($task.TaskName)"
    Write-Log "Task path: $($task.TaskPath)"
    Write-Log "Task state: $($task.State)"

    # Capture sync time BEFORE triggering so we can compare after
    $taskInfoBefore = $task | Get-ScheduledTaskInfo
    $syncBefore = $taskInfoBefore.LastRunTime
    Write-Log "Sync time BEFORE remediation: $syncBefore"
    Write-Log "Last result code BEFORE: $($taskInfoBefore.LastTaskResult)"

    # Extract enrollment GUID from task path
    Write-Log "Extracting enrollment ID from task path..."
    $enrollmentID = ($task.TaskPath -split "\\") | Where-Object { 
        $_ -match "^[{]?[0-9a-fA-F\-]{36}[}]?$" 
    } | Select-Object -First 1

    if (-not $enrollmentID) {
        Write-Log "ERROR: Could not extract enrollment ID from task path: $($task.TaskPath)"
        Write-Log "===== Remediation Script Ended - Exit 1 ====="
        exit 1
    }

    Write-Log "Enrollment ID found: $enrollmentID"

    # Trigger the Intune MDM sync
    Write-Log "Triggering Intune MDM sync..."
    Start-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\$enrollmentID\" `
        -TaskName "Schedule to run OMADMClient by client"

    Write-Log "Sync task triggered - waiting 30 seconds for completion..."
    Start-Sleep -Seconds 30

    # Verify sync completed by checking updated timestamp
    $taskInfoAfter = $task | Get-ScheduledTaskInfo
    $syncAfter = $taskInfoAfter.LastRunTime
    $lastResult = $taskInfoAfter.LastTaskResult

    Write-Log "Sync time AFTER remediation: $syncAfter"
    Write-Log "Last result code AFTER: $lastResult"

    # Compare before and after timestamps
    if ($syncAfter -gt $syncBefore) {
        Write-Log "SUCCESS: Sync timestamp updated from $syncBefore to $syncAfter"

        if ($lastResult -eq 0) {
            Write-Log "SUCCESS: Sync completed with no errors (result code 0)"
        } else {
            Write-Log "WARNING: Sync ran but returned error code $lastResult"
        }

        Write-Host "Intune sync triggered successfully"
        Write-Log "===== Remediation Script Ended - Exit 0 ====="
        exit 0
    } else {
        Write-Log "FAILURE: Sync timestamp did not update. Before: $syncBefore | After: $syncAfter"
        Write-Host "Sync may not have completed"
        Write-Log "===== Remediation Script Ended - Exit 1 ====="
        exit 1
    }
} catch {
    Write-Log "EXCEPTION: $($_.Exception.Message)"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Log "===== Remediation Script Ended - Exit 1 (Exception) ====="
    exit 1
}