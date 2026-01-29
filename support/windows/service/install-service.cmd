@echo off
REM Mender Service Installer - CMD Wrapper
REM Runs the PowerShell installation script with administrator privileges

echo Mender Client Service Installer
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-service.ps1" %*

pause
