@echo off
REM =====================================================
REM  AutoCAD 2023 Full Removal - Launcher
REM  Author: IT Admin (James)
REM  Date: 2026
REM =====================================================

echo Starting AutoCAD 2023 removal process...
echo This may take 10-20 minutes. Do not close this window.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Remove-ACAD2023.ps1"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Removal completed successfully.
    exit /b 0
) else (
    echo.
    echo Removal encountered errors. Check C:\Windows\Logs\ACAD2023-Removal.log
    exit /b %ERRORLEVEL%
)