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
│   └── mender-inventory-os.cmd
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

The `mender-device-identity.cmd` script provides a unique device identifier using the Windows Machine GUID. This GUID is:
- Unique per Windows installation
- Persistent across reboots
- Stored in the registry at `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid`

Output format:
```
mac=<machine-guid>
```

The key `mac` is used for compatibility with the Mender server, which expects this format.

## Inventory Scripts

The inventory scripts collect system information and report it to the Mender server:

| Script | Information Collected |
|--------|----------------------|
| `mender-inventory-device-type.cmd` | Device type from `device_type` file |
| `mender-inventory-hardware.cmd` | CPU, memory, manufacturer, model |
| `mender-inventory-network.cmd` | Hostname, IPv4 address |
| `mender-inventory-os.cmd` | OS name, version, build number |

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
ipv4=192.168.1.100
os_type=Windows
os_name=Microsoft Windows 11 Pro
os_version=10.0.22631
os_build=22631
```

## Requirements

- Windows 10 or later
- PowerShell 5.1 or later (included with Windows 10+)
- Administrator privileges may be required for some inventory queries

## Customization

You can add custom inventory scripts by creating additional `.cmd` files in the inventory directory. Each script should output key=value pairs, one per line.
