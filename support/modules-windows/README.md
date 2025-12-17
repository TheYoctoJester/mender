# Windows Update Modules

This directory contains Update Module implementations for Windows systems.

## single-file-win

A PowerShell-based Update Module for deploying single files to Windows systems.

### Files

- `single-file-win.ps1` - PowerShell implementation of the Update Module
- `single-file-win.cmd` - CMD wrapper for invoking the PowerShell script

### Installation

Copy both files to the Mender modules directory:

```powershell
Copy-Item single-file-win.ps1, single-file-win.cmd C:\ProgramData\Mender\modules\v3\
```

### Creating an Artifact

The single-file-win module requires three payload files:
- The file to deploy
- `dest_dir` - A file containing the destination directory path
- `filename` - A file containing the target filename

#### Step 1: Prepare payload files

```powershell
# Create a working directory
New-Item -ItemType Directory -Path C:\Temp\mender-payload -Force

# Create the file to deploy
Set-Content -Path C:\Temp\mender-payload\myconfig.txt -Value "Configuration content here"

# Create metadata files (no trailing newline)
Set-Content -Path C:\Temp\mender-payload\dest_dir -Value "C:\MyApp\config" -NoNewline
Set-Content -Path C:\Temp\mender-payload\filename -Value "myconfig.txt" -NoNewline
```

#### Step 2: Create the artifact

```powershell
mender-artifact write module-image `
    --type single-file-win `
    --artifact-name "myconfig-v1.0" `
    --device-type windows-x64 `
    --file C:\Temp\mender-payload\myconfig.txt `
    --file C:\Temp\mender-payload\dest_dir `
    --file C:\Temp\mender-payload\filename `
    --output-path C:\Temp\myconfig.mender `
    --compression none
```

#### Step 3: Verify the artifact

```powershell
mender-artifact read C:\Temp\myconfig.mender
```

### Deploying an Artifact

#### Local installation (for testing)

```powershell
# Install the artifact
mender-update install C:\Temp\myconfig.mender

# If successful, commit the update
mender-update commit

# Or rollback if something went wrong
mender-update rollback
```

### Update Module States

The module implements the following states:

| State | Action |
|-------|--------|
| `NeedsArtifactReboot` | Returns "No" (no reboot required) |
| `SupportsRollback` | Returns "Yes" (rollback is supported) |
| `ArtifactInstall` | Backs up existing file, copies new file to destination |
| `ArtifactRollback` | Restores the backup file |
| `ArtifactCommit` | Logs commit success |
| `Cleanup` | Removes backup directory |

### Rollback Support

The module automatically backs up any existing file at the destination before installing the new file. If the update fails or `mender-update rollback` is called, the original file is restored.

### Error Handling

- If `dest_dir` or `filename` metadata files are missing, the install fails
- If the source file is not found in the artifact, the install fails
- Informational messages are written to stderr to avoid polluting the protocol stream on stdout
