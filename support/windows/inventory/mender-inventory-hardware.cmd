@echo off
REM Mender Inventory Script - Hardware Information
REM
REM Everything is gathered in ONE PowerShell invocation: each cold PowerShell
REM start costs 1-2+ seconds (more on small CPUs or under load), and the
REM client runs inventory scripts with a hard 10 second timeout - the previous
REM five sequential invocations regularly exceeded it, dropping the whole
REM hardware inventory.

echo device_arch=%PROCESSOR_ARCHITECTURE%

powershell -NoProfile -Command ^
  "$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1;" ^
  "$cs = Get-CimInstance Win32_ComputerSystem;" ^
  "Write-Output ('cpu_model=' + $cpu.Name);" ^
  "Write-Output ('cpu_cores=' + $cpu.NumberOfCores);" ^
  "Write-Output ('manufacturer=' + $cs.Manufacturer);" ^
  "Write-Output ('model=' + $cs.Model);" ^
  "Write-Output ('memory_total_gb=' + [math]::Round($cs.TotalPhysicalMemory / 1GB, 2))"

exit /b 0
