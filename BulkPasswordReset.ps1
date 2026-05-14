#=============================================================================
# Bulk Password Reset & Session Revocation Script
# Environment: Hybrid (On-Premises AD + Entra ID)
# Author: YHC IT Admin
# Date: May 2026
#=============================================================================

# --- Configuration ---
$csvPath = "C:\Temp\expired.csv"
$logFile = "C:\Temp\PasswordResetLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# --- Import Modules ---
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "Active Directory module loaded." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to load Active Directory module. Exiting." -ForegroundColor Red
    exit
}

# --- Connect to Microsoft Graph (Entra ID) ---
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All" -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to connect to Microsoft Graph. Exiting." -ForegroundColor Red
    exit
}

# --- Function: Generate Random 16-Character Password ---
function Get-RandomPassword {
    $length = 16
    $charSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    return (-join ((1..$length) | ForEach-Object { $charSet[(Get-Random -Maximum $charSet.Length)] }))
}

# --- Load Users from CSV ---
if (!(Test-Path $csvPath)) {
    Write-Host "ERROR: CSV file not found at $csvPath" -ForegroundColor Red
    exit
}

$users = Import-Csv -Path $csvPath
$totalUsers = $users.Count
$currentUser = 0

Write-Host "`nStarting password reset for $totalUsers users...`n" -ForegroundColor Cyan
"Password Reset Log - $(Get-Date)" | Out-File -FilePath $logFile

# --- Process Each User ---
foreach ($row in $users) {
    $currentUser++
    $upn = $row.userPrincipalName
    $sam = $row.sAMAccountName
    $displayName = $row.Name
    $newPassword = Get-RandomPassword
    $securePassword = ConvertTo-SecureString $newPassword -AsPlainText -Force

    Write-Host "[$currentUser/$totalUsers] Processing: $displayName ($upn)" -ForegroundColor Cyan

    try {
        # --- Step 1: Reset On-Premises AD Password ---
        Set-ADAccountPassword -Identity $sam -NewPassword $securePassword -Reset -ErrorAction Stop
        Write-Host "  [ON-PREM] Password reset successful" -ForegroundColor Gray

        # --- Step 2: Force Password Change at Next Logon (On-Prem) ---
        Set-ADUser -Identity $sam -ChangePasswordAtLogon $true -ErrorAction Stop
        Write-Host "  [ON-PREM] Set to change password at next logon" -ForegroundColor Gray

        # --- Step 3: Reset Entra ID (Azure AD) Password ---
        Update-MgUser -UserId $upn -PasswordProfile @{
            Password = $newPassword
            ForceChangePasswordNextSignIn = $true
        } -ErrorAction Stop
        Write-Host "  [ENTRA ID] Password reset successful" -ForegroundColor Gray

        # --- Step 4: Revoke All Active Sign-In Sessions ---
        Revoke-MgUserSignInSession -UserId $upn -ErrorAction Stop
        Write-Host "  [ENTRA ID] All sessions revoked" -ForegroundColor Gray

        # --- Log Success ---
        $logMsg = "SUCCESS | $displayName | $upn | TempPassword: $newPassword"
        Write-Host "  COMPLETED SUCCESSFULLY" -ForegroundColor Green
        $logMsg | Out-File -FilePath $logFile -Append

    } catch {
        # --- Log Failure ---
        $errorMsg = "FAILED | $displayName | $upn | Error: $($_.Exception.Message)"
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $errorMsg | Out-File -FilePath $logFile -Append
    }

    Write-Host ""
}

# --- Cleanup ---
Disconnect-MgGraph
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Process Complete!" -ForegroundColor Yellow
Write-Host "Total Processed: $totalUsers" -ForegroundColor Yellow
Write-Host "Log File: $logFile" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow