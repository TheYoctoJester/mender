@echo off
REM Mender Inventory Script - Hardware Information

REM Get architecture from environment
echo device_arch=%PROCESSOR_ARCHITECTURE%

REM Get CPU info using PowerShell
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Select-Object -First 1).Name"`) do echo cpu_model=%%a
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Select-Object -First 1).NumberOfCores"`) do echo cpu_cores=%%a

REM Get system info
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).Manufacturer"`) do echo manufacturer=%%a
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).Model"`) do echo model=%%a

REM Get total memory in GB
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)"`) do echo memory_total_gb=%%a

exit /b 0
