# Windows Support Scripts

This directory contains Windows-specific scripts for the Mender client.

## Directory Structure

```
windows/
├── identity/
│   └── mender-device-identity.cmd    # Device identity script
├── inventory/
│   ├── mender-inventory-device-type.cmd
│   ├── mender-inventory-hardware.cmd
│   ├── mender-inventory-network.cmd
│   ├── mender-inventory-os.cmd
│   ├── mender-inventory-provides.cmd
│   └── mender-inventory-update-modules.cmd
└── README.md
```

## Installation

Copy the scripts to the appropriate Mender directories:

```powershell
# Create directories
New-Item -ItemType Directory -Path "$env:ProgramData\Mender\identity" -Force
New-Item -ItemType Directory -Path "$env:ProgramData\Mender\inventory" -Force

# Copy identity script
Copy-Item "identity\mender-device-identity.cmd" "$env:ProgramData\Mender\identity\"

# Copy inventory scripts
Copy-Item "inventory\*.cmd" "$env:ProgramData\Mender\inventory\"
```

## Device Identity

The `mender-device-identity.cmd` script provides a unique device identifier using the MAC address of the first active network adapter (sorted by interface index). This matches the behavior of the Linux identity script.

Output format:
```
mac=bc:24:11:67:bd:86
```

The MAC address is converted from Windows format (AA-BB-CC-DD-EE-FF) to Linux format (aa:bb:cc:dd:ee:ff) for consistency.

## Inventory Scripts

The inventory scripts collect system information and report it to the Mender server:

| Script | Information Collected |
|--------|----------------------|
| `mender-inventory-device-type.cmd` | Device type from `device_type` file |
| `mender-inventory-hardware.cmd` | CPU, memory, manufacturer, model |
| `mender-inventory-network.cmd` | Hostname, interfaces, MAC and IP addresses |
| `mender-inventory-os.cmd` | OS name, version, build number |
| `mender-inventory-provides.cmd` | Artifact provides (installed software) |
| `mender-inventory-update-modules.cmd` | Installed update modules |

### Example Output

```
device_type=windows-x64
device_arch=AMD64
cpu_model=Intel(R) Core(TM) i7-10700 CPU @ 2.90GHz
cpu_cores=8
manufacturer=Dell Inc.
model=XPS 15
memory_total_gb=32
hostname=WORKSTATION01
mac_Ethernet=bc:24:11:67:bd:86
network_interfaces=Ethernet
ipv4_Ethernet=192.168.1.100/24
os_type=Windows
os_name=Microsoft Windows 11 Pro
os_version=10.0.22631
os_build=22631
artifact_name=windows-demo-v1.0.0
rootfs-image.single-file-win.version=windows-demo-v1.0.0
update_modules=single-file-win.cmd,single-file-win.ps1
```

## Requirements

- Windows 10 or later
- PowerShell 5.1 or later (included with Windows 10+)
- Administrator privileges may be required for some inventory queries

## Customization

You can add custom inventory scripts by creating additional `.cmd` files in the inventory directory. Each script should output key=value pairs, one per line.
