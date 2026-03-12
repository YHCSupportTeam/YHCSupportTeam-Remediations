$logFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\ODTCleanup.log"

function Write-Log {
    param($Message)
    "$( Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" | 
        Out-File -FilePath $logFile -Append -Encoding UTF8
}

try {
    # Stop any running ODT processes
    $processes = Get-Process -Name "odt*" -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Log "Stopping ODT processes: $($processes.Name -join ', ')"
        $processes | Stop-Process -Force
        Start-Sleep -Seconds 2
    } else {
        Write-Log "No ODT processes running"
    }

    # Remove ONLY odt* files, not everything in SystemTemp
    $filesToRemove = Get-ChildItem -Path "C:\Windows\SystemTemp\" -Filter "odt*" -Recurse -ErrorAction SilentlyContinue
    if ($filesToRemove) {
        foreach ($file in $filesToRemove) {
            Remove-Item -Path $file.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed: $($file.FullName)"
        }
        Write-Log "ODT cleanup completed"
    } else {
        Write-Log "No ODT files to remove"
    }

    exit 0

} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}