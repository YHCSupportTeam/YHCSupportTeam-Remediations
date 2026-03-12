# Check if any ODT files exist in SystemTemp
$FilePath = "C:\Windows\SystemTemp\odt*"

try {
    $files = Get-Item -Path $FilePath -ErrorAction SilentlyContinue

    if ($files) {
        Write-Host "ODT file(s) found: $($files.FullName -join ', ')"
        exit 1  # Non-compliant, trigger remediation
    } else {
        Write-Host "No ODT files found"
        exit 0  # Compliant
    }
} catch {
    Write-Host "Error during detection: $($_.Exception.Message)"
    exit 0  # Don't trigger remediation on error
}