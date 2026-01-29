#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the Mender client as a Windows service.

.DESCRIPTION
    This script installs mender-update as a Windows service using NSSM
    (Non-Sucking Service Manager). The service will run in daemon mode
    and start automatically on system boot.

.PARAMETER MenderPath
    Path to mender-update.exe. If not specified, the script searches in:
    - %ProgramFiles%\Mender\mender-update.exe (production install)
    - Repository build directory (Release and Debug)
    - %USERPROFILE%\mender\build\... (user home builds)

.PARAMETER NssmPath
    Path to nssm.exe. If not specified, the script will look for NSSM in PATH
    or download it automatically.

.PARAMETER ServiceName
    Name of the Windows service. Defaults to "MenderClient"

.PARAMETER NoDownload
    If specified, the script will not attempt to download NSSM automatically.

.EXAMPLE
    .\install-service.ps1

.EXAMPLE
    .\install-service.ps1 -MenderPath "D:\Mender\mender-update.exe"

.EXAMPLE
    .\install-service.ps1 -NssmPath "C:\tools\nssm.exe"
#>

param(
    [string]$MenderPath = "",
    [string]$NssmPath = "",
    [string]$ServiceName = "MenderClient",
    [switch]$NoDownload
)

$ErrorActionPreference = "Stop"

# Script directory (for referencing sibling scripts)
$ScriptDir = $PSScriptRoot

# Repository root (script is in support/windows/service/)
$RepoRoot = (Get-Item "$ScriptDir\..\..\..").FullName

function Find-MenderBinary {
    # Check locations in order of preference
    $locations = @(
        # 1. Production install location
        "$env:ProgramFiles\Mender\mender-update.exe",
        # 2. Repository build (Release)
        "$RepoRoot\build\src\mender-update\Release\mender-update.exe",
        # 3. Repository build (Debug)
        "$RepoRoot\build\src\mender-update\Debug\mender-update.exe",
        # 4. User home directory build
        "$env:USERPROFILE\mender\build\src\mender-update\Release\mender-update.exe"
    )

    foreach ($loc in $locations) {
        if (Test-Path $loc) {
            return (Get-Item $loc).FullName
        }
    }

    return $null
}

# NSSM download URLs (multiple sources for reliability)
$NssmVersion = "2.24"
$NssmDownloadUrls = @(
    "https://nssm.cc/release/nssm-$NssmVersion.zip",
    "https://nssm.cc/ci/nssm-$NssmVersion.zip",
    "https://github.com/kirillkovalenko/nssm/releases/download/v$NssmVersion/nssm-$NssmVersion.zip"
)
$NssmLocalDir = "$env:ProgramData\Mender\tools"

function Write-Status {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[-] $Message" -ForegroundColor Red
}

function Get-Nssm {
    # Check if NSSM path was provided
    if ($NssmPath -and (Test-Path $NssmPath)) {
        return $NssmPath
    }

    # Check if NSSM is in PATH
    $nssmInPath = Get-Command "nssm.exe" -ErrorAction SilentlyContinue
    if ($nssmInPath) {
        return $nssmInPath.Source
    }

    # Check local tools directory
    $localNssm = Join-Path $NssmLocalDir "nssm.exe"
    if (Test-Path $localNssm) {
        return $localNssm
    }

    # Download NSSM if allowed
    if ($NoDownload) {
        throw "NSSM not found. Please install NSSM or provide path with -NssmPath parameter."
    }

    Write-Status "NSSM not found. Downloading version $NssmVersion..."

    # Create tools directory
    New-Item -ItemType Directory -Path $NssmLocalDir -Force | Out-Null

    $zipPath = Join-Path $env:TEMP "nssm-$NssmVersion.zip"
    $extractPath = Join-Path $env:TEMP "nssm-$NssmVersion"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Try multiple download sources
    $downloaded = $false
    $lastError = $null

    foreach ($url in $NssmDownloadUrls) {
        try {
            Write-Status "Trying: $url"
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -TimeoutSec 30
            $downloaded = $true
            break
        }
        catch {
            $lastError = $_
            Write-Host "[!] Failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    if (-not $downloaded) {
        throw "Failed to download NSSM from all sources. Last error: $lastError`n`nPlease download NSSM manually from https://nssm.cc/ and use -NssmPath parameter."
    }

    try {
        # Extract
        Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force

        # Copy appropriate architecture
        $arch = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
        $nssmExe = Join-Path $extractPath "$arch\nssm.exe"

        Copy-Item -Path $nssmExe -Destination $localNssm -Force

        # Cleanup
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue

        Write-Success "NSSM downloaded to $localNssm"
        return $localNssm
    }
    catch {
        throw "Failed to extract NSSM: $_"
    }
}

function Test-ServiceExists {
    param([string]$Name)
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    return $null -ne $service
}

# Main installation logic
Write-Host ""
Write-Host "Mender Client Service Installer" -ForegroundColor White
Write-Host "================================" -ForegroundColor White
Write-Host ""

# Find mender-update.exe if not specified
if (-not $MenderPath) {
    Write-Status "Searching for mender-update.exe..."
    $MenderPath = Find-MenderBinary
}

# Verify mender-update.exe exists
if (-not $MenderPath -or -not (Test-Path $MenderPath)) {
    Write-Error-Custom "mender-update.exe not found"
    Write-Host ""
    Write-Host "Searched locations:" -ForegroundColor Yellow
    Write-Host "  - $env:ProgramFiles\Mender\mender-update.exe"
    Write-Host "  - $RepoRoot\build\src\mender-update\Release\mender-update.exe"
    Write-Host "  - $RepoRoot\build\src\mender-update\Debug\mender-update.exe"
    Write-Host ""
    Write-Host "Please specify the correct path:" -ForegroundColor Yellow
    Write-Host "  $ScriptDir\install-service.ps1 -MenderPath 'C:\path\to\mender-update.exe'" -ForegroundColor Yellow
    exit 1
}

Write-Status "Mender binary found: $MenderPath"

# Check if service already exists
if (Test-ServiceExists $ServiceName) {
    Write-Error-Custom "Service '$ServiceName' already exists."
    Write-Host ""
    Write-Host "To reinstall, first run:" -ForegroundColor Yellow
    Write-Host "  $ScriptDir\uninstall-service.ps1 -ServiceName '$ServiceName'" -ForegroundColor Yellow
    exit 1
}

# Get NSSM
try {
    $nssm = Get-Nssm
    Write-Status "Using NSSM: $nssm"
}
catch {
    Write-Error-Custom $_
    exit 1
}

# Install the service
Write-Status "Installing service '$ServiceName'..."

try {
    # Install service
    & $nssm install $ServiceName $MenderPath daemon
    if ($LASTEXITCODE -ne 0) { throw "Failed to install service" }

    # Configure service display name and description
    & $nssm set $ServiceName DisplayName "Mender Update Client"
    & $nssm set $ServiceName Description "Mender OTA update client for Windows. Manages software updates and system configuration."

    # Configure startup type (auto start)
    & $nssm set $ServiceName Start SERVICE_AUTO_START

    # Configure service to restart on failure
    & $nssm set $ServiceName AppExit Default Restart
    & $nssm set $ServiceName AppRestartDelay 10000

    # Configure stdout/stderr logging
    $logDir = "$env:ProgramData\Mender\logs"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null

    & $nssm set $ServiceName AppStdout "$logDir\mender-service.log"
    & $nssm set $ServiceName AppStderr "$logDir\mender-service.log"
    & $nssm set $ServiceName AppStdoutCreationDisposition 4
    & $nssm set $ServiceName AppStderrCreationDisposition 4
    & $nssm set $ServiceName AppRotateFiles 1
    & $nssm set $ServiceName AppRotateBytes 10485760

    Write-Success "Service installed successfully"
}
catch {
    Write-Error-Custom "Failed to install service: $_"
    # Attempt cleanup
    & $nssm remove $ServiceName confirm 2>$null
    exit 1
}

# Start the service
Write-Status "Starting service..."

try {
    Start-Service -Name $ServiceName
    $service = Get-Service -Name $ServiceName

    if ($service.Status -eq "Running") {
        Write-Success "Service started successfully"
    }
    else {
        Write-Host "[!] Service installed but not running. Status: $($service.Status)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[!] Service installed but failed to start: $_" -ForegroundColor Yellow
    Write-Host "    Check logs at: $logDir\mender-service.log" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Service Details:" -ForegroundColor White
Write-Host "  Name:        $ServiceName"
Write-Host "  Binary:      $MenderPath"
Write-Host "  Log file:    $logDir\mender-service.log"
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor White
Write-Host "  Start:       Start-Service $ServiceName"
Write-Host "  Stop:        Stop-Service $ServiceName"
Write-Host "  Status:      Get-Service $ServiceName"
Write-Host "  Uninstall:   $ScriptDir\uninstall-service.ps1"
Write-Host ""
