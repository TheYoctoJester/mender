@echo off
REM Mender Inventory Script - Network Information
REM Reports network interfaces, MAC addresses, and IP addresses
REM Matches the format of the Linux mender-inventory-network script

REM Get hostname
echo hostname=%COMPUTERNAME%

REM Use PowerShell to enumerate network interfaces and their addresses
REM Output format matches Linux: mac_<iface>, network_interfaces, ipv4_<iface>, ipv6_<iface>
powershell -NoProfile -Command "$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Sort-Object InterfaceIndex; foreach ($adapter in $adapters) { $name = $adapter.Name -replace ' ','_'; $mac = $adapter.MacAddress.Replace('-',':').ToLower(); Write-Output \"mac_$name=$mac\"; Write-Output \"network_interfaces=$name\"; $ips = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue; foreach ($ip in $ips) { if ($ip.AddressFamily -eq 'IPv4' -and $ip.IPAddress -ne '127.0.0.1') { Write-Output \"ipv4_$name=$($ip.IPAddress)/$($ip.PrefixLength)\" }; if ($ip.AddressFamily -eq 'IPv6' -and -not $ip.IPAddress.StartsWith('::1') -and -not $ip.IPAddress.StartsWith('fe80::')) { Write-Output \"ipv6_$name=$($ip.IPAddress)/$($ip.PrefixLength)\" } } }"

exit /b 0
