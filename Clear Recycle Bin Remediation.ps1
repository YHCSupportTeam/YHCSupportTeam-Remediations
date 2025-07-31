<#
Version: 1.1
Run as: User
Context: 64 Bit
Description: Clears the Recycle Bin for all drives without prompting the user.
#>

try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Output "Recycle Bin cleared successfully."
} catch {
    Write-Output "Failed to clear Recycle Bin: $_"
}
