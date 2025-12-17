@echo off
REM Mender Inventory Script - OS Information

echo os_type=Windows

REM Use PowerShell to get OS information reliably
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"`) do echo os_name=%%a
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Version"`) do echo os_version=%%a
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).BuildNumber"`) do echo os_build=%%a

exit /b 0
