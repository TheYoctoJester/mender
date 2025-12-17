@echo off
REM Mender Device Identity Script for Windows
REM Outputs key=value pairs for device identification
REM
REM This script uses the Windows Machine GUID as the device identifier.
REM The Machine GUID is unique per Windows installation and persists
REM across reboots, making it suitable for device identification.

REM Get the machine GUID (unique per Windows installation)
for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Cryptography" /v MachineGuid 2^>nul') do set "MACHINE_GUID=%%b"

if "%MACHINE_GUID%"=="" (
    echo Failed to retrieve Machine GUID >&2
    exit /b 1
)

REM Output the identity - use mac as the key for compatibility with Mender server
echo mac=%MACHINE_GUID%

exit /b 0
