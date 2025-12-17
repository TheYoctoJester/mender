@echo off
REM Mender Inventory Script - Device Type
REM Reads device type from the device_type file and outputs it as inventory

setlocal enabledelayedexpansion

set "DEVICE_TYPE_FILE=%ProgramData%\Mender\device_type"

if exist "%DEVICE_TYPE_FILE%" (
    for /f "tokens=2 delims==" %%a in ('type "%DEVICE_TYPE_FILE%" 2^>nul') do (
        echo device_type=%%a
    )
) else (
    echo device_type=windows-x64
)

exit /b 0
