# Windows Single-File Update Module
# Implements the Mender Update Module v3 protocol for single-file updates
#
# Usage: single-file-win.ps1 <STATE> <FILES_DIR>
#
# Expected payload files in <FILES_DIR>/files/:
#   - dest_dir: File containing the destination directory path
#   - filename: File containing the target filename
#   - <filename>: The actual file to deploy

param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$State,

    [Parameter(Position=1, Mandatory=$true)]
    [string]$FilesDir
)

$ErrorActionPreference = "Stop"

# Define paths
$TmpBackupDir = Join-Path $FilesDir "tmp\backup"
$DestDirFile = Join-Path $FilesDir "files\dest_dir"
$FilenameFile = Join-Path $FilesDir "files\filename"
$PermissionsFile = Join-Path $FilesDir "files\permissions"

# Safe copy function - copies via temp file then atomic rename
function Safe-Copy {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination
    )

    $TempDest = "$Destination.tmp"

    # Copy to temporary location
    Copy-Item -Path $Source -Destination $TempDest -Force

    # Atomic rename (as atomic as Windows allows)
    Move-Item -Path $TempDest -Destination $Destination -Force
}

switch ($State) {
    "NeedsArtifactReboot" {
        # Single-file updates don't require a reboot
        [Console]::Out.WriteLine("No")
    }

    "SupportsRollback" {
        # We support rollback by keeping a backup
        [Console]::Out.WriteLine("Yes")
    }

    "ArtifactInstall" {
        # Read destination directory and filename from payload
        if (-not (Test-Path $DestDirFile)) {
            Write-Error "dest_dir file not found: $DestDirFile"
            exit 1
        }
        if (-not (Test-Path $FilenameFile)) {
            Write-Error "filename file not found: $FilenameFile"
            exit 1
        }

        $DestDir = (Get-Content $DestDirFile -Raw).Trim()
        $Filename = (Get-Content $FilenameFile -Raw).Trim()

        if ([string]::IsNullOrEmpty($DestDir) -or [string]::IsNullOrEmpty($Filename)) {
            Write-Error "Fatal error: dest_dir or filename are undefined."
            exit 1
        }

        # Create destination directory if it doesn't exist
        if (-not (Test-Path $DestDir)) {
            New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        }

        # Create backup directory
        New-Item -ItemType Directory -Path $TmpBackupDir -Force | Out-Null

        # Backup existing file if it exists
        $DestFile = Join-Path $DestDir $Filename
        if (Test-Path $DestFile) {
            try {
                Safe-Copy $DestFile (Join-Path $TmpBackupDir $Filename)
            }
            catch {
                # Make sure there is no half-backup lying around
                Remove-Item -Path $TmpBackupDir -Recurse -Force -ErrorAction SilentlyContinue
                throw $_
            }
        }

        # Install new file
        $SourceFile = Join-Path $FilesDir "files\$Filename"
        if (-not (Test-Path $SourceFile)) {
            Write-Error "Source file not found: $SourceFile"
            exit 1
        }

        Safe-Copy $SourceFile $DestFile

        # Use stderr for informational messages to avoid polluting stdout protocol stream
        [Console]::Error.WriteLine("Installed $Filename to $DestDir")
    }

    "ArtifactRollback" {
        # Restore from backup if it exists
        if (-not (Test-Path $FilenameFile)) {
            # No filename means nothing to rollback
            exit 0
        }

        $Filename = (Get-Content $FilenameFile -Raw).Trim()
        $BackupFile = Join-Path $TmpBackupDir $Filename

        if (-not (Test-Path $BackupFile)) {
            # No backup exists, nothing to rollback
            exit 0
        }

        $DestDir = (Get-Content $DestDirFile -Raw).Trim()

        if ([string]::IsNullOrEmpty($DestDir) -or [string]::IsNullOrEmpty($Filename)) {
            Write-Error "Fatal error: dest_dir or filename are undefined."
            exit 1
        }

        $DestFile = Join-Path $DestDir $Filename
        Safe-Copy $BackupFile $DestFile

        # Use stderr for informational messages
        [Console]::Error.WriteLine("Rolled back $Filename")
    }

    "ArtifactCommit" {
        # Nothing special needed for commit
        # Use stderr for informational messages
        [Console]::Error.WriteLine("Commit successful")
    }

    "Cleanup" {
        # Remove backup directory
        if (Test-Path $TmpBackupDir) {
            Remove-Item -Path $TmpBackupDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    default {
        # Ignore unknown states (required by protocol)
        # Return success silently
    }
}

exit 0
