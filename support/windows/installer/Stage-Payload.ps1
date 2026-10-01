<#
.SYNOPSIS
    Assembles the Windows installer payload for the Mender client.

.DESCRIPTION
    Collects the freshly built mender-update.exe, its runtime DLLs (vcpkg
    x64-windows + the MSVC runtime), the support scripts and a bundled copy of
    nssm.exe into a single staging tree that mender-setup.nsi turns into the
    installer. The tree is split so the NSIS script can drop it with two
    `File /r` calls:

        <OutDir>\program\   -> %ProgramFiles%\Mender   (binary + DLLs)
        <OutDir>\data\      -> %ProgramData%\Mender     (scripts, nssm, modules)

.PARAMETER RepoRoot
    Repository root. Defaults to two levels up from this script.

.PARAMETER BuildDir
    CMake build directory (contains src\mender-update\Release and
    vcpkg_installed). Defaults to <RepoRoot>\build.

.PARAMETER NssmExe
    Path to the nssm.exe to bundle (downloaded by the workflow).

.PARAMETER OutDir
    Staging output directory. Defaults to <RepoRoot>\payload.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path,
    [string]$BuildDir = "",
    [string]$NssmExe  = "",
    [string]$OutDir   = ""
)

$ErrorActionPreference = "Stop"

if (-not $BuildDir) { $BuildDir = Join-Path $RepoRoot "build" }
if (-not $OutDir)   { $OutDir   = Join-Path $RepoRoot "payload" }

function New-Dir([string]$Path) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

Write-Host "RepoRoot : $RepoRoot"
Write-Host "BuildDir : $BuildDir"
Write-Host "OutDir   : $OutDir"

# --- Clean / create the staging tree ----------------------------------------
if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
$programDir = Join-Path $OutDir "program"
$dataDir    = Join-Path $OutDir "data"
New-Dir $programDir
foreach ($sub in @("identity", "inventory", "modules\v3", "service", "tools")) {
    New-Dir (Join-Path $dataDir $sub)
}

# --- 1. The client binary -----------------------------------------------------
$exe = Join-Path $BuildDir "src\mender-update\Release\mender-update.exe"
if (-not (Test-Path $exe)) {
    # Fall back to a single-config layout just in case.
    $alt = Join-Path $BuildDir "src\mender-update\mender-update.exe"
    if (Test-Path $alt) { $exe = $alt } else { throw "mender-update.exe not found under $BuildDir" }
}
Copy-Item $exe (Join-Path $programDir "mender-update.exe") -Force
Write-Host "Staged binary: $exe"

# --- 2. Runtime DLLs (vcpkg x64-windows) -------------------------------------
$vcpkgBin = Join-Path $BuildDir "vcpkg_installed\x64-windows\bin"
if (Test-Path $vcpkgBin) {
    $dlls = Get-ChildItem -Path $vcpkgBin -Filter *.dll -ErrorAction SilentlyContinue
    foreach ($d in $dlls) { Copy-Item $d.FullName $programDir -Force }
    Write-Host "Staged $($dlls.Count) vcpkg runtime DLL(s) from $vcpkgBin"
} else {
    Write-Warning "vcpkg bin dir not found at $vcpkgBin - the installed client may fail to start without its DLLs."
}

# --- 3. MSVC runtime DLLs (app-local deployment) -------------------------------
# A clean target has no VC++ redistributable; missing satellites such as
# msvcp140_1/msvcp140_2/msvcp140_atomic_wait crash the client with
# STATUS_DLL_NOT_FOUND (0xC0000135). Prefer the full redist CRT directory
# from the build environment; fall back to globbing System32.
$staged = 0
if ($env:VCToolsRedistDir) {
    $crtDir = Get-ChildItem (Join-Path $env:VCToolsRedistDir "x64") -Directory -Filter "Microsoft.VC*.CRT" |
        Select-Object -First 1
    if ($crtDir) {
        foreach ($d in Get-ChildItem $crtDir.FullName -Filter *.dll) {
            Copy-Item $d.FullName $programDir -Force; $staged++
        }
        Write-Host "Staged $staged MSVC runtime DLL(s) from $($crtDir.FullName)"
    }
}
if ($staged -eq 0) {
    $sys32 = Join-Path $env:SystemRoot "System32"
    foreach ($rt in @("vcruntime140*.dll", "msvcp140*.dll", "concrt140.dll")) {
        foreach ($f in Get-ChildItem $sys32 -Filter $rt -ErrorAction SilentlyContinue) {
            Copy-Item $f.FullName $programDir -Force; $staged++
            Write-Host "Staged MSVC runtime: $($f.Name)"
        }
    }
}
if ($staged -eq 0) {
    Write-Warning "No MSVC runtime DLLs staged - the target machine will need the VC++ redistributable."
}

# --- 4. Support scripts -> data\ ---------------------------------------------
$support = Join-Path $RepoRoot "support\windows"
Copy-Item (Join-Path $support "identity\*")  (Join-Path $dataDir "identity")  -Recurse -Force
Copy-Item (Join-Path $support "inventory\*") (Join-Path $dataDir "inventory") -Recurse -Force
Copy-Item (Join-Path $support "service\install-service.ps1")   (Join-Path $dataDir "service") -Force
Copy-Item (Join-Path $support "service\uninstall-service.ps1") (Join-Path $dataDir "service") -Force

# Update module (single-file-win) -> data\modules\v3
$modules = Join-Path $RepoRoot "support\modules-windows"
if (Test-Path $modules) {
    Copy-Item (Join-Path $modules "single-file-win.*") (Join-Path $dataDir "modules\v3") -Force
}

# --- 5. Bundled NSSM ----------------------------------------------------------
if ($NssmExe -and (Test-Path $NssmExe)) {
    Copy-Item $NssmExe (Join-Path $dataDir "tools\nssm.exe") -Force
    Write-Host "Staged nssm.exe from $NssmExe"
} else {
    Write-Warning "No nssm.exe supplied (-NssmExe); the installer will rely on install-service.ps1 downloading it at install time."
}

Write-Host "`nPayload staged at $OutDir"
Get-ChildItem -Recurse $OutDir | Select-Object FullName | Format-Table -AutoSize
