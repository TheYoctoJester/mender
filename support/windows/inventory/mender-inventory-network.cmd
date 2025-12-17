@echo off
REM Mender Inventory Script - Network Information

REM Get hostname using environment variable
echo hostname=%COMPUTERNAME%

REM Get primary IPv4 address using PowerShell
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike '*Loopback*' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress"`) do echo ipv4=%%a

exit /b 0
