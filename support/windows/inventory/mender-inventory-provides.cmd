@echo off
REM Mender Inventory Script - Provides
REM Returns the current list of provides for the device using mender-update show-provides
REM
REM Note: device_type is handled separately by mender-inventory-device-type.cmd

REM Try to find mender-update in standard locations
set "MENDER_UPDATE="

REM Check PATH first
where mender-update.exe >nul 2>&1
if %errorlevel%==0 (
    for /f "delims=" %%i in ('where mender-update.exe') do (
        set "MENDER_UPDATE=%%i"
        goto :found
    )
)

REM Check standard installation locations
if exist "%ProgramFiles%\Mender\mender-update.exe" (
    set "MENDER_UPDATE=%ProgramFiles%\Mender\mender-update.exe"
    goto :found
)

REM Check user home directory (development builds)
if exist "%USERPROFILE%\mender\build\src\mender-update\Release\mender-update.exe" (
    set "MENDER_UPDATE=%USERPROFILE%\mender\build\src\mender-update\Release\mender-update.exe"
    goto :found
)

REM Not found - exit silently (provides will not be reported)
exit /b 0

:found
"%MENDER_UPDATE%" show-provides
exit /b 0
