@echo off
REM Mender Service Uninstaller - CMD Wrapper
REM Runs the PowerShell uninstallation script with administrator privileges

echo Mender Client Service Uninstaller
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script requires administrator privileges.
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

REM Run the PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall-service.ps1" %*

pause
