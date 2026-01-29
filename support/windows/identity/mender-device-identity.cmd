@echo off
REM Mender Device Identity Script for Windows
REM Outputs key=value pairs for device identification
REM
REM This script uses the MAC address of a physical network adapter,
REM matching the behavior of the Linux identity script.

setlocal enabledelayedexpansion

REM Use PowerShell to get the MAC address of the first physical adapter (lowest interface index)
REM Convert from Windows format (AA-BB-CC-DD-EE-FF) to Linux format (aa:bb:cc:dd:ee:ff)
for /f "delims=" %%a in ('powershell -NoProfile -Command "$adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.MacAddress } | Sort-Object InterfaceIndex | Select-Object -First 1; if ($adapter) { $adapter.MacAddress.Replace('-',':').ToLower() }"') do set "MAC_ADDR=%%a"

if "%MAC_ADDR%"=="" (
    echo No suitable network adapter found >&2
    exit /b 1
)

echo mac=%MAC_ADDR%
exit /b 0
