@echo off
REM Mender Inventory Script - Update Modules
REM Lists all installed update modules

setlocal enabledelayedexpansion

set "MODULES_DIR=%ProgramData%\Mender\modules\v3"
set "MODULES="

if not exist "%MODULES_DIR%" (
    echo update_modules=
    exit /b 0
)

for %%f in ("%MODULES_DIR%\*") do (
    if "!MODULES!"=="" (
        set "MODULES=%%~nxf"
    ) else (
        set "MODULES=!MODULES!,%%~nxf"
    )
)

if "!MODULES!"=="" (
    echo update_modules=
) else (
    echo update_modules=!MODULES!
)

exit /b 0
