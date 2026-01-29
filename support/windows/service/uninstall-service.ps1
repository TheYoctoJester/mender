#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uninstalls the Mender client Windows service.

.DESCRIPTION
    This script stops and removes the Mender client Windows service.
    Optionally removes NSSM and log files.

.PARAMETER ServiceName
    Name of the Windows service to remove. Defaults to "MenderClient"

.PARAMETER RemoveLogs
    If specified, also removes the service log files.

.PARAMETER RemoveNssm
    If specified, also removes the downloaded NSSM tool.

.EXAMPLE
    .\uninstall-service.ps1

.EXAMPLE
    .\uninstall-service.ps1 -RemoveLogs -RemoveNssm
#>

param(
    [string]$ServiceName = "MenderClient",
    [switch]$RemoveLogs,
    [switch]$RemoveNssm
)

$ErrorActionPreference = "Stop"

# Script directory (for referencing sibling scripts)
$ScriptDir = $PSScriptRoot

$NssmLocalDir = "$env:ProgramData\Mender\tools"
$LogDir = "$env:ProgramData\Mender\logs"

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

    return $null
}

function Test-ServiceExists {
    param([string]$Name)
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    return $null -ne $service
}

# Main uninstallation logic
Write-Host ""
Write-Host "Mender Client Service Uninstaller" -ForegroundColor White
Write-Host "==================================" -ForegroundColor White
Write-Host ""

# Check if service exists
if (-not (Test-ServiceExists $ServiceName)) {
    Write-Error-Custom "Service '$ServiceName' does not exist."
    exit 1
}

# Get NSSM
$nssm = Get-Nssm
if (-not $nssm) {
    Write-Error-Custom "NSSM not found. Cannot remove service."
    Write-Host ""
    Write-Host "Try removing manually with:" -ForegroundColor Yellow
    Write-Host "  sc.exe delete $ServiceName" -ForegroundColor Yellow
    exit 1
}

Write-Status "Using NSSM: $nssm"

# Stop the service if running
$service = Get-Service -Name $ServiceName
if ($service.Status -eq "Running") {
    Write-Status "Stopping service..."
    try {
        Stop-Service -Name $ServiceName -Force
        Write-Success "Service stopped"
    }
    catch {
        Write-Host "[!] Failed to stop service gracefully, forcing..." -ForegroundColor Yellow
        & $nssm stop $ServiceName
    }
}

# Remove the service
Write-Status "Removing service '$ServiceName'..."

try {
    & $nssm remove $ServiceName confirm
    if ($LASTEXITCODE -ne 0) { throw "Failed to remove service" }
    Write-Success "Service removed"
}
catch {
    Write-Error-Custom "Failed to remove service: $_"
    exit 1
}

# Remove logs if requested
if ($RemoveLogs) {
    Write-Status "Removing log files..."
    if (Test-Path $LogDir) {
        Remove-Item -Path "$LogDir\mender-service*.log" -Force -ErrorAction SilentlyContinue
        Write-Success "Log files removed"
    }
}

# Remove NSSM if requested
if ($RemoveNssm) {
    Write-Status "Removing NSSM..."
    $localNssm = Join-Path $NssmLocalDir "nssm.exe"
    if (Test-Path $localNssm) {
        Remove-Item -Path $localNssm -Force
        # Remove tools directory if empty
        $remaining = Get-ChildItem -Path $NssmLocalDir -ErrorAction SilentlyContinue
        if (-not $remaining) {
            Remove-Item -Path $NssmLocalDir -Force -ErrorAction SilentlyContinue
        }
        Write-Success "NSSM removed"
    }
}

Write-Host ""
Write-Host "Uninstallation complete!" -ForegroundColor Green
Write-Host ""

if (-not $RemoveLogs -and (Test-Path $LogDir)) {
    Write-Host "Note: Log files remain at $LogDir" -ForegroundColor Yellow
    Write-Host "      Run '$ScriptDir\uninstall-service.ps1 -RemoveLogs' to remove them" -ForegroundColor Yellow
    Write-Host ""
}
