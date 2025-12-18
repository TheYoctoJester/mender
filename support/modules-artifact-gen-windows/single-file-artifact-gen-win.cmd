@echo off
REM Windows Single-File Artifact Generator Wrapper
REM Invokes the PowerShell script with the same arguments

powershell -ExecutionPolicy Bypass -File "%~dp0single-file-artifact-gen-win.ps1" %*
exit /b %ERRORLEVEL%
