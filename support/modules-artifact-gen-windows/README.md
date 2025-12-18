# Windows Artifact Generator Scripts

This directory contains Windows-specific artifact generator scripts for creating Mender Artifacts compatible with Windows Update Modules.

## single-file-artifact-gen-win

Generates artifacts for the `single-file-win` Update Module, which deploys a single file to a specified destination directory.

### Prerequisites

- `mender-artifact.exe` must be available (in PATH, current directory, or specified via `-MenderArtifact`)
- PowerShell 5.1 or later (included with Windows 10+)

### Usage

```powershell
.\single-file-artifact-gen-win.ps1 `
    -ArtifactName "my-config-v1.0" `
    -DeviceType "windows-x64" `
    -DestDir "C:\App\Config" `
    -File "C:\Source\config.json" `
    -OutputPath "my-artifact.mender"
```

Or using short aliases:

```powershell
.\single-file-artifact-gen-win.ps1 -n "my-config-v1.0" -t "windows-x64" -d "C:\App\Config" -f "C:\Source\config.json" -o "my-artifact.mender"
```

### Parameters

| Parameter | Alias | Required | Description |
|-----------|-------|----------|-------------|
| `-ArtifactName` | `-n` | Yes | Name of the artifact |
| `-DeviceType` | `-t` | Yes | Target device type (can specify multiple) |
| `-DestDir` | `-d` | Yes | Absolute path to destination directory |
| `-File` | `-f` | Yes | Path to the file to deploy |
| `-OutputPath` | `-o` | No | Output artifact path (default: `single-file-artifact.mender`) |
| `-Compression` | | No | Compression: none, gzip, lzma, zstd_* (default: `none`) |
| `-SoftwareName` | | No | Custom software name key |
| `-SoftwareVersion` | | No | Software version value |
| `-MenderArtifact` | | No | Path to mender-artifact.exe |

### Examples

**Deploy a configuration file:**
```powershell
.\single-file-artifact-gen-win.ps1 `
    -ArtifactName "app-config-v2.0" `
    -DeviceType "windows-x64" `
    -DestDir "C:\ProgramData\MyApp" `
    -File ".\config.json"
```

**Deploy to multiple device types:**
```powershell
.\single-file-artifact-gen-win.ps1 `
    -ArtifactName "update-v1.0" `
    -DeviceType "windows-x64", "windows-arm64" `
    -DestDir "C:\App" `
    -File ".\update.dat"
```

**Using CMD wrapper:**
```cmd
single-file-artifact-gen-win.cmd -n "test-v1.0" -t "windows-x64" -d "C:\Temp\deploy" -f "C:\Source\file.txt"
```

### How It Works

1. Creates temporary metadata files:
   - `dest_dir` - Contains the destination directory path
   - `filename` - Contains the filename to deploy

2. Calls `mender-artifact write module-image` with:
   - Type: `single-file-win`
   - The metadata files and source file as payloads

3. The resulting artifact can be installed using:
   ```powershell
   mender-update.exe install path\to\artifact.mender
   mender-update.exe commit
   ```

### Related Files

- Update Module: `support/modules-windows/single-file-win.ps1`
- Linux equivalent: `support/modules-artifact-gen/single-file-artifact-gen`
