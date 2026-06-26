; mender-setup.nsi - NSIS installer for the Mender client (Windows port)
;
; Compile from the repository root with the version and payload passed in, e.g.:
;   makensis /DVERSION=1.2.3 /DPAYLOAD=C:\path\to\payload support\windows\installer\mender-setup.nsi
;
; The payload tree is produced by Stage-Payload.ps1:
;   <PAYLOAD>\program\  -> %ProgramFiles%\Mender   (mender-update.exe + DLLs)
;   <PAYLOAD>\data\     -> %ProgramData%\Mender     (scripts, nssm, modules)

Unicode true
ManifestDPIAware true

!ifndef VERSION
  !define VERSION "0.0.0-dev"
!endif
!ifndef PAYLOAD
  !define PAYLOAD "payload"
!endif
; OUTFILE may be an absolute path; OutFile is otherwise resolved relative to
; this .nsi file's directory, which is rarely what the caller wants.
!ifndef OUTFILE
  !define OUTFILE "mender-setup-${VERSION}.exe"
!endif

!define PRODUCT       "Mender"
!define PUBLISHER     "Northern.tech AS"
!define SERVICE_NAME  "MenderClient"
!define ARP_KEY       "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT}"

Name "${PRODUCT} ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\Mender"
RequestExecutionLevel admin
ShowInstDetails show
ShowUnInstDetails show

!include "MUI2.nsh"
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

; ---------------------------------------------------------------------------
Section "Mender client" SecMain
  SectionIn RO
  SetShellVarContext all          ; $APPDATA -> C:\ProgramData

  ; 1. Program files (binary + runtime DLLs)
  SetOutPath "$INSTDIR"
  File /r "${PAYLOAD}\program\*"

  ; 2. Data tree (scripts, nssm, modules) under %ProgramData%\Mender
  SetOutPath "$APPDATA\Mender"
  File /r "${PAYLOAD}\data\*"
  CreateDirectory "$APPDATA\Mender\conf"
  CreateDirectory "$APPDATA\Mender\logs"

  ; 3. Register the Windows service (reuse the existing script; nssm bundled, no download)
  DetailPrint "Registering ${SERVICE_NAME} service..."
  nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy Bypass -File "$APPDATA\Mender\service\install-service.ps1" -MenderPath "$INSTDIR\mender-update.exe" -NssmPath "$APPDATA\Mender\tools\nssm.exe" -ServiceName "${SERVICE_NAME}"'
  Pop $0
  DetailPrint "install-service.ps1 exit code: $0"
  ${If} $0 != 0
    DetailPrint "WARNING: service registration returned $0 (the binary is installed; you can re-run install-service.ps1 manually)."
  ${EndIf}

  ; 4. Uninstaller + Add/Remove Programs entry
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr   HKLM "${ARP_KEY}" "DisplayName"     "${PRODUCT} client"
  WriteRegStr   HKLM "${ARP_KEY}" "DisplayVersion"  "${VERSION}"
  WriteRegStr   HKLM "${ARP_KEY}" "Publisher"       "${PUBLISHER}"
  WriteRegStr   HKLM "${ARP_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${ARP_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKLM "${ARP_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${ARP_KEY}" "NoRepair" 1
SectionEnd

; ---------------------------------------------------------------------------
Section "Uninstall"
  SetShellVarContext all

  ; Stop + remove the service first
  IfFileExists "$APPDATA\Mender\service\uninstall-service.ps1" 0 +3
    nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy Bypass -File "$APPDATA\Mender\service\uninstall-service.ps1" -ServiceName "${SERVICE_NAME}"'
    Pop $0

  ; Remove program files
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR"

  ; Remove the scripts/tools/modules we installed, but preserve user data (conf, logs, device_type)
  RMDir /r "$APPDATA\Mender\service"
  RMDir /r "$APPDATA\Mender\tools"
  RMDir /r "$APPDATA\Mender\modules"
  RMDir /r "$APPDATA\Mender\identity"
  RMDir /r "$APPDATA\Mender\inventory"

  DeleteRegKey HKLM "${ARP_KEY}"
SectionEnd
