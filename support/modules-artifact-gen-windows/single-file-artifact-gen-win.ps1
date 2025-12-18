<#
.SYNOPSIS
    Generate Mender Artifact for Windows single-file Update Module

.DESCRIPTION
    Simple tool to generate Mender Artifact suitable for single-file-win Update Module.
    This is the Windows equivalent of single-file-artifact-gen.

.PARAMETER ArtifactName
    Name of the artifact (required)

.PARAMETER DeviceType
    Target device type identification. Can be specified multiple times.

.PARAMETER DestDir
    Target destination directory where to deploy the update (required)

.PARAMETER File
    Single file to bundle in the update (required)

.PARAMETER OutputPath
    Path to output file. Default: single-file-artifact.mender

.PARAMETER SoftwareName
    Name of the key to store the software version

.PARAMETER SoftwareVersion
    Value for the software version, defaults to the artifact name

.PARAMETER Compression
    Compression algorithm: none, gzip, lzma, zstd_fastest, zstd_default, zstd_better, zstd_best
    Default: none (best Windows client compatibility)

.PARAMETER MenderArtifact
    Path to mender-artifact.exe. Default: searches PATH, then common locations

.EXAMPLE
    .\single-file-artifact-gen-win.ps1 -ArtifactName "config-v1.0" -DeviceType "windows-x64" -DestDir "C:\App\Config" -File "C:\Source\config.json"

.EXAMPLE
    .\single-file-artifact-gen-win.ps1 -n "app-update" -t "windows-x64" -d "C:\Program Files\MyApp" -f "C:\Build\app.exe" -o "C:\Artifacts\app-update.mender"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [Alias("n")]
    [string]$ArtifactName,

    [Parameter(Mandatory=$true)]
    [Alias("t")]
    [string[]]$DeviceType,

    [Parameter(Mandatory=$true)]
    [Alias("d")]
    [string]$DestDir,

    [Parameter(Mandatory=$true)]
    [Alias("f")]
    [string]$File,

    [Parameter()]
    [Alias("o")]
    [string]$OutputPath = "single-file-artifact.mender",

    [Parameter()]
    [string]$SoftwareName,

    [Parameter()]
    [string]$SoftwareVersion,

    [Parameter()]
    [ValidateSet("none", "gzip", "lzma", "zstd_fastest", "zstd_default", "zstd_better", "zstd_best")]
    [string]$Compression = "none",

    [Parameter()]
    [string]$MenderArtifact
)

$ErrorActionPreference = "Stop"

# Find mender-artifact.exe
function Find-MenderArtifact {
    # Check if provided
    if ($MenderArtifact -and (Test-Path $MenderArtifact)) {
        return $MenderArtifact
    }

    # Check PATH
    $inPath = Get-Command "mender-artifact.exe" -ErrorAction SilentlyContinue
    if ($inPath) {
        return $inPath.Source
    }

    # Check common locations
    $commonPaths = @(
        ".\mender-artifact.exe",
        "$PSScriptRoot\mender-artifact.exe",
        "$env:USERPROFILE\Documents\mender-artifact\mender-artifact.exe",
        "$env:ProgramFiles\Mender\mender-artifact.exe"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

# Validate mender-artifact exists
$menderArtifactPath = Find-MenderArtifact
if (-not $menderArtifactPath) {
    Write-Error "mender-artifact.exe not found. Please install it or specify path with -MenderArtifact parameter."
    Write-Error "Download from: https://docs.mender.io/downloads#mender-artifact"
    exit 1
}

Write-Host "Using mender-artifact: $menderArtifactPath"

# Validate source file exists
if (-not (Test-Path $File)) {
    Write-Error "Source file does not exist: $File"
    exit 1
}

if ((Get-Item $File).PSIsContainer) {
    Write-Error "Source must be a file, not a directory: $File"
    Write-Error "Use directory-artifact-gen for directories."
    exit 1
}

# Validate dest_dir is an absolute path (Windows style)
if (-not [System.IO.Path]::IsPathRooted($DestDir)) {
    Write-Error "Destination directory must be an absolute path: $DestDir"
    exit 1
}

# Get filename from source file
$Filename = Split-Path $File -Leaf

# Create temporary directory for metadata files
$TempDir = Join-Path $env:TEMP "mender-artifact-gen-$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    # Create dest_dir file
    $DestDirFile = Join-Path $TempDir "dest_dir"
    Set-Content -Path $DestDirFile -Value $DestDir -NoNewline

    # Create filename file
    $FilenameFile = Join-Path $TempDir "filename"
    Set-Content -Path $FilenameFile -Value $Filename -NoNewline

    # Build mender-artifact command arguments
    # Note: File order matters for tar payload - actual file first, then metadata
    $args = @(
        "write", "module-image",
        "-T", "single-file-win",
        "-n", $ArtifactName,
        "-o", $OutputPath,
        "-f", $File,
        "-f", $DestDirFile,
        "-f", $FilenameFile
    )

    # Add device types
    foreach ($dt in $DeviceType) {
        $args += "-t"
        $args += $dt
    }

    # Add optional software version parameters
    if ($SoftwareName) {
        $args += "--software-name"
        $args += $SoftwareName
    }
    if ($SoftwareVersion) {
        $args += "--software-version"
        $args += $SoftwareVersion
    }

    # Add compression
    $args += "--compression"
    $args += $Compression

    Write-Host "Creating artifact..."
    Write-Host "  Artifact name: $ArtifactName"
    Write-Host "  Device type(s): $($DeviceType -join ', ')"
    Write-Host "  Source file: $File"
    Write-Host "  Destination: $DestDir\$Filename"
    Write-Host "  Compression: $Compression"
    Write-Host ""

    # Execute mender-artifact
    & $menderArtifactPath @args
    if ($LASTEXITCODE -ne 0) {
        Write-Error "mender-artifact failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }

    Write-Host ""
    Write-Host "Artifact created successfully: $OutputPath"
    Write-Host ""

    # Display artifact info
    & $menderArtifactPath read $OutputPath
}
finally {
    # Clean up temp directory
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
