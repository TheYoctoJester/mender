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
├── service/
│   ├── install-service.ps1           # Service installation script
│   ├── install-service.cmd           # CMD wrapper for installation
│   ├── uninstall-service.ps1         # Service removal script
│   └── uninstall-service.cmd         # CMD wrapper for removal
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

## Mender Installation Layout

The scripts expect Mender components to be installed in standard locations:

```
%ProgramFiles%\Mender\
└── mender-update.exe              # Main Mender client binary

%ProgramData%\Mender\
├── device_type                    # Device type configuration
├── identity\
│   └── mender-device-identity.cmd
├── inventory\
│   └── *.cmd                      # Inventory scripts
├── logs\
│   └── mender-service.log         # Service log file
├── modules\
│   └── v3\                        # Update modules directory
│       ├── single-file-win.cmd
│       └── ...
└── tools\
    └── nssm.exe                   # Service manager (auto-downloaded)
```

### device_type File

The `device_type` file should contain a single line specifying the device type:

```
device_type=windows-x64
```

If this file does not exist, `mender-inventory-device-type.cmd` defaults to `windows-x64`.

### Update Modules

Update modules should be installed in `%ProgramData%\Mender\modules\v3\`. The `mender-inventory-update-modules.cmd` script lists all files in this directory.

## Running as a Windows Service

The Mender client can be installed as a Windows service to run automatically on system boot. The service scripts use [NSSM (Non-Sucking Service Manager)](https://nssm.cc/) to manage the service.

### Quick Install

Run from an elevated (Administrator) PowerShell prompt:

```powershell
.\service\install-service.ps1
```

Or double-click `service\install-service.cmd` and select "Run as administrator".

The script will:
1. Auto-detect `mender-update.exe` (searches multiple locations)
2. Download NSSM automatically (tries multiple sources)
3. Install the Mender client as a Windows service
4. Configure automatic startup and restart-on-failure
5. Set up logging to `%ProgramData%\Mender\logs\mender-service.log`
6. Start the service

### Binary Auto-Detection

The install script automatically searches for `mender-update.exe` in these locations:

1. `%ProgramFiles%\Mender\mender-update.exe` (production install)
2. `<repository>\build\src\mender-update\Release\mender-update.exe` (Release build)
3. `<repository>\build\src\mender-update\Debug\mender-update.exe` (Debug build)
4. `%USERPROFILE%\mender\build\src\mender-update\Release\mender-update.exe`

### NSSM (Service Manager)

The scripts use [NSSM (Non-Sucking Service Manager)](https://nssm.cc/) to run `mender-update daemon` as a Windows service. NSSM is downloaded automatically from multiple sources:

1. `nssm.cc/release` (primary)
2. `nssm.cc/ci` (CI builds)
3. GitHub mirror

If automatic download fails (e.g., network issues), download NSSM manually:

1. Download from https://nssm.cc/download
2. Extract `nssm.exe` from the `win64` folder (or `win32` for 32-bit systems)
3. Run the install script with the `-NssmPath` parameter:

```powershell
.\service\install-service.ps1 -NssmPath "C:\path\to\nssm.exe"
```

NSSM is installed to `%ProgramData%\Mender\tools\nssm.exe` for future use.

### Custom Installation

Specify a custom path to the Mender binary:

```powershell
.\service\install-service.ps1 -MenderPath "D:\Mender\mender-update.exe"
```

Use a custom service name:

```powershell
.\service\install-service.ps1 -ServiceName "MyMenderService"
```

Skip automatic NSSM download (fail if not found):

```powershell
.\service\install-service.ps1 -NoDownload
```

### Service Management

After installation, manage the service using standard Windows commands:

```powershell
# Check status
Get-Service MenderClient

# Stop service
Stop-Service MenderClient

# Start service
Start-Service MenderClient

# View logs
Get-Content "$env:ProgramData\Mender\logs\mender-service.log" -Tail 50
```

### Uninstall

Remove the service:

```powershell
.\service\uninstall-service.ps1
```

Remove service, logs, and NSSM:

```powershell
.\service\uninstall-service.ps1 -RemoveLogs -RemoveNssm
```

## Device Identity

The `mender-device-identity.cmd` script provides a unique device identifier using the MAC address of the first active network adapter (sorted by interface index). This matches the behavior of the Linux identity script.

Output format:
```
mac=bc:24:11:67:bd:86
```

The MAC address is converted from Windows format (AA-BB-CC-DD-EE-FF) to Linux format (aa:bb:cc:dd:ee:ff) for consistency.

**Note**: The device must have at least one active network adapter with a MAC address. If no suitable adapter is found, the script exits with an error.

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

### Script Details

**mender-inventory-provides.cmd**: Retrieves artifact provides by running `mender-update show-provides`. The script searches for `mender-update.exe` in the following locations (in order):
1. System PATH
2. `%ProgramFiles%\Mender\mender-update.exe`
3. `%USERPROFILE%\mender\build\src\mender-update\Release\mender-update.exe` (development builds)

If `mender-update.exe` is not found, the script exits silently without reporting any provides.

**mender-inventory-update-modules.cmd**: Lists all files in `%ProgramData%\Mender\modules\v3\` as a comma-separated list. Returns an empty value if the directory does not exist.

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
- At least one active network adapter (for device identity)
- Administrator privileges may be required for some inventory queries

## Customization

You can add custom inventory scripts by creating additional `.cmd` files in the inventory directory. Each script should output key=value pairs, one per line.
