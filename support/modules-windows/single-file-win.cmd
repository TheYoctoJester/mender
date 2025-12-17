@echo off
REM Windows Single-File Update Module - CMD Wrapper
REM This wrapper is needed because mender-update invokes update modules as executables.
REM It calls the PowerShell script with execution policy bypass.
REM
REM Usage: single-file-win.cmd <STATE> <FILES_DIR>

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0single-file-win.ps1" %*
exit /b %ERRORLEVEL%
