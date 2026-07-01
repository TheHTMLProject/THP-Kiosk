!include "MUI2.nsh"

Name "THP Kiosk"
OutFile "THPKiosk-Setup.exe"
InstallDir "$LOCALAPPDATA\THPKiosk"
RequestExecutionLevel user
BrandingText "The HTML Project"

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Launch THP Kiosk now"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchKiosk
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function LaunchKiosk
    ExecShell "open" "powershell.exe" '-WindowStyle Hidden -ExecutionPolicy Bypass -File "$INSTDIR\kiosk.ps1"' SW_SHOWMINIMIZED
FunctionEnd

Section "Install"
    ; Hide this command using nsExec::Exec so it never flashes the big blue PS window
    nsExec::Exec 'powershell.exe -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force"'
    
    SetOutPath "$INSTDIR"
    File "src\kiosk.ps1"
    File "src\config-gui.ps1"

    SetFileAttributes "$INSTDIR\kiosk.ps1" HIDDEN
    SetFileAttributes "$INSTDIR\config-gui.ps1" HIDDEN

    ; Rename desktop shortcut
    CreateShortcut "$DESKTOP\Launch THP Kiosk.lnk" "powershell.exe" '-WindowStyle Hidden -ExecutionPolicy Bypass -File "$INSTDIR\kiosk.ps1"' "$SYSDIR\shell32.dll" 13 SW_SHOWMINIMIZED
    
    CreateDirectory "$SMPROGRAMS\THP Kiosk"
    CreateShortcut "$SMPROGRAMS\THP Kiosk\THP Kiosk.lnk" "powershell.exe" '-WindowStyle Hidden -ExecutionPolicy Bypass -File "$INSTDIR\kiosk.ps1"' "$SYSDIR\shell32.dll" 13 SW_SHOWMINIMIZED
    CreateShortcut "$SMPROGRAMS\THP Kiosk\THP Kiosk Config.lnk" "powershell.exe" '-WindowStyle Hidden -ExecutionPolicy Bypass -File "$INSTDIR\config-gui.ps1"' "$SYSDIR\imageres.dll" 114 SW_SHOWMINIMIZED
    CreateShortcut "$SMPROGRAMS\THP Kiosk\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
    
    CreateShortcut "$SMSTARTUP\THP Kiosk.lnk" "powershell.exe" '-WindowStyle Hidden -ExecutionPolicy Bypass -File "$INSTDIR\kiosk.ps1"' "$SYSDIR\shell32.dll" 13 SW_SHOWMINIMIZED
    SetFileAttributes "$SMSTARTUP\THP Kiosk.lnk" HIDDEN|SYSTEM
    
    ; Add Registry Run Key for Startup Redundancy
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "THPKiosk" '"powershell.exe" -WindowStyle Hidden -ExecutionPolicy Bypass -File "$INSTDIR\kiosk.ps1"'

    WriteUninstaller "$INSTDIR\Uninstall.exe"
    SetFileAttributes "$INSTDIR\Uninstall.exe" HIDDEN
    SetFileAttributes "$INSTDIR" HIDDEN
    
    ; Run config silently
    nsExec::Exec 'powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "$INSTDIR\config-gui.ps1"'
SectionEnd

Section "Uninstall"
    Delete "$INSTDIR\kiosk.ps1"
    Delete "$INSTDIR\config-gui.ps1"
    Delete "$INSTDIR\config.json"
    Delete "$INSTDIR\kiosk.log"
    Delete "$INSTDIR\Uninstall.exe"
    Delete "$DESKTOP\Launch THP Kiosk.lnk"
    Delete "$SMSTARTUP\THP Kiosk.lnk"
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "THPKiosk"
    RMDir /r "$SMPROGRAMS\THP Kiosk"
    RMDir /r "$INSTDIR"
SectionEnd
