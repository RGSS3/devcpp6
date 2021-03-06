####################################################################
# Startup

!define COMPILERNAME "TDM-GCC 9.2"
!define COMPILERFOLDER "MinGW64"
!define DEVCPP_VERSION "6.0g"
!define FINALNAME "Dev-Cpp ${DEVCPP_VERSION} ${COMPILERNAME} Setup.exe"
!define DISPLAY_NAME "Dev-C++ ${DEVCPP_VERSION}"

!include "MUI2.nsh"

####################################################################
# Installer Attributes

Name "${DISPLAY_NAME}"
OutFile "${FINALNAME}"
Caption "${DISPLAY_NAME}"

LicenseData "copying.txt"
InstallDir $PROGRAMFILES\Dev-Cpp

####################################################################
# Interface Settings

ShowInstDetails show
AutoCloseWindow false
SilentInstall normal
CRCCheck on
SetCompressor zlib
SetDatablockOptimize on
SetOverwrite try
XPStyle on

InstType "Full";1
#InstType "Minimal";2
#InstType "Safe";3

####################################################################
# Pages

!define MUI_ICON "devcpp.ico"
!define MUI_UNICON "devcpp.ico"
!define MUI_ABORTWARNING
!define MUI_LANGDLL_ALLLANGUAGES
!define MUI_FINISHPAGE_RUN "$INSTDIR\devcpp.exe"
!define MUI_FINISHPAGE_NOREBOOTSUPPORT
!define MUI_COMPONENTSPAGE_SMALLDESC

!insertmacro MUI_PAGE_LICENSE "copying.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

####################################################################
# Languages

!insertmacro MUI_LANGUAGE "SimpChinese"
#!insertmacro MUI_LANGUAGE "TradChinese"
#!insertmacro MUI_LANGUAGE "English"


####################################################################
# Files, by option section

Section "Dev-C++ program files (required)" SectionMain
  SectionIn 1 2 3 RO
  
  SetOutPath $INSTDIR

  ; Allways create an uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dev-C++" "DisplayName" "Dev-C++"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dev-C++" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dev-C++" "DisplayVersion" "${DEVCPP_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dev-C++" "DisplayIcon" "$INSTDIR\devcpp.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dev-C++" "Publisher" "Bloodshed Software"
  
  ; Write required files
  File "devcpp.exe"
  ; File "devcppPortable.exe"
  File "devcpp.map"
  File "ConsolePauser.exe"
  File "devcpp.exe.manifest"
  File "copying.txt"
  File "NEWS.txt"
  File "busybox.exe"
  File "Update.exe"
  File "ICSharpCode.SharpZipLib.dll"
  File version
  File DYNF.ttf
  ;File "DejaVuSansMono YaHei NF.ttf"
  ;StrCpy $0 "$INSTDIR\DejaVuSansMono YaHei NF.ttf"
  ;WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "DejaVuSansMono YaHei NF Devcpp" "$0"
  ;System::Call "GDI32::AddFontResource(t) i ('$0') .s"
  ;Pop $0
  ;IntCmp $0 0 0 +2 +2
  ;MessageBox MB_OK "注册字体失败"
  ;System::Call "User32::SendMessageTimeout(iiiiiii)i (${HWND_BROADCAST}, ${WM_FONTCHANGE}, 0, 0, 11, 5000, 0) .s"
  GetTempFileName $1
  FileOpen $0 $1 w
  FileWrite $0 `Set sh = CreateObject("Shell.Application")$\n`
  FileWrite $0 `sh.NameSpace(20).MoveHere sh.NameSpace("$INSTDIR").ParseName("DYNF.ttf")$\n`
  FileClose $0
  nsExec::ExecToStack `"$SYSDIR\CScript.exe" $1 //e:vbscript //B //NOLOGO`
  Pop $0
  Delete DYNF.ttf
  DetailPrint `Return Code = $0`

  SetOutPath $INSTDIR  
  File /nonfatal "Vendor.7z"
  Nsis7z::ExtractWithDetails "Vendor.7z" "Installing %s..."
  Delete "$OUTDIR\Vendor.7z"
  
  ; Write required paths
  SetOutPath $INSTDIR\Templates
  File /r "Templates\*"
  SetOutPath $INSTDIR\Help
  File /r "Help\*"
  SetOutPath $INSTDIR\AStyle
  File /r "AStyle\*"
  SetOutPath $INSTDIR\Photogram
  File /r "Photogram\*"
  SetOutPath $INSTDIR\Gstudio
  File /r "Gstudio\*"
  SetOutPath $INSTDIR\Build
  File /r "Build\empty.txt"
SectionEnd

Section "Icon files" SectionIcons
  SectionIn 1 3
  
  SetOutPath $INSTDIR\Icons
  File /nonfatal /r "Icons\*.*"
SectionEnd

Section "${COMPILERNAME} compiler" SectionMinGW
  SectionIn 1 2 3
  SetOutPath $INSTDIR

  File /nonfatal "${COMPILERFOLDER}.7z"
  Nsis7z::ExtractWithDetails "${COMPILERFOLDER}.7z" "Installing %s..."
  Delete "$OUTDIR\${COMPILERFOLDER}.7z"
SectionEnd

Section "Language files" SectionLangs
  SectionIn 1 2 3
  
  SetOutPath $INSTDIR\Lang
  File /nonfatal /r "Lang\*"
SectionEnd

####################################################################
# File association
SubSection "Associate C and C++ files to Dev-C++" SectionAssocs

Section "Associate .dev files to Dev-C++"
  SectionIn 1 3

  StrCpy $0 ".dev"
  Call BackupAssoc

  StrCpy $0 $INSTDIR\DevCpp.exe
  WriteRegStr HKCR ".dev" "" "DevCpp.dev"
  WriteRegStr HKCR "DevCpp.dev" "" "Dev-C++ Project File"
  WriteRegStr HKCR "DevCpp.dev\DefaultIcon" "" '$0,3'
  WriteRegStr HKCR "DevCpp.dev\Shell\Open\Command" "" '$0 "%1"'
  Call RefreshShellIcons
SectionEnd

Section "Associate .c files to Dev-C++"
  SectionIn 1 3

  StrCpy $0 ".c"
  Call BackupAssoc

  StrCpy $0 $INSTDIR\DevCpp.exe
  WriteRegStr HKCR ".c" "" "DevCpp.c"
  WriteRegStr HKCR "DevCpp.c" "" "C Source File"
  WriteRegStr HKCR "DevCpp.c\DefaultIcon" "" '$0,4'
  WriteRegStr HKCR "DevCpp.c\Shell\Open\Command" "" '$0 "%1"'
  Call RefreshShellIcons
SectionEnd

Section "Associate .cpp files to Dev-C++"
  SectionIn 1 3

  StrCpy $0 ".cpp"
  Call BackupAssoc

  StrCpy $0 $INSTDIR\DevCpp.exe
  WriteRegStr HKCR ".cpp" "" "DevCpp.cpp"
  WriteRegStr HKCR "DevCpp.cpp" "" "C++ Source File"
  WriteRegStr HKCR "DevCpp.cpp\DefaultIcon" "" '$0,5'
  WriteRegStr HKCR "DevCpp.cpp\Shell\Open\Command" "" '$0 "%1"'
  Call RefreshShellIcons
SectionEnd

Section "Associate .h files to Dev-C++"
  SectionIn 1 3

  StrCpy $0 ".h"
  Call BackupAssoc

  StrCpy $0 $INSTDIR\DevCpp.exe
  WriteRegStr HKCR ".h" "" "DevCpp.h"
  WriteRegStr HKCR "DevCpp.h" "" "C Header File"
  WriteRegStr HKCR "DevCpp.h\DefaultIcon" "" '$0,6'
  WriteRegStr HKCR "DevCpp.h\Shell\Open\Command" "" '$0 "%1"'
  Call RefreshShellIcons
SectionEnd

Section "Associate .hpp files to Dev-C++"
  SectionIn 1 3

  StrCpy $0 ".hpp"
  Call BackupAssoc

  StrCpy $0 $INSTDIR\DevCpp.exe
  WriteRegStr HKCR ".hpp" "" "DevCpp.hpp"
  WriteRegStr HKCR "DevCpp.hpp" "" "C++ Header File"
  WriteRegStr HKCR "DevCpp.hpp\DefaultIcon" "" '$0,7'
  WriteRegStr HKCR "DevCpp.hpp\Shell\Open\Command" "" '$0 "%1"'
  Call RefreshShellIcons
SectionEnd

Section "Associate .rc files to Dev-C++"
  SectionIn 1 3

  StrCpy $0 ".rc"
  Call BackupAssoc

  StrCpy $0 $INSTDIR\DevCpp.exe
  WriteRegStr HKCR ".rc" "" "DevCpp.rc"
  WriteRegStr HKCR "DevCpp.rc" "" "Resource Source File"
  WriteRegStr HKCR "DevCpp.rc\DefaultIcon" "" '$0,8'
  WriteRegStr HKCR "DevCpp.rc\Shell\Open\Command" "" '$0 "%1"'
  Call RefreshShellIcons
SectionEnd

Section "Associate .devpak files to Dev-C++"
  SectionIn 1 3

  StrCpy $0 ".devpak"
  Call BackupAssoc

  StrCpy $0 $INSTDIR\DevCpp.exe
  StrCpy $1 $INSTDIR\PackMan.exe
  WriteRegStr HKCR ".devpak" "" "DevCpp.devpak"
  WriteRegStr HKCR "DevCpp.devpak" "" "Dev-C++ Package File"
  WriteRegStr HKCR "DevCpp.devpak\DefaultIcon" "" '$0,9'
  WriteRegStr HKCR "DevCpp.devpak\Shell\Open\Command" "" '$1 "%1"'
  Call RefreshShellIcons
SectionEnd

Section "Associate .template files to Dev-C++"
  SectionIn 1 3

  StrCpy $0 ".template"
  Call BackupAssoc

  StrCpy $0 $INSTDIR\DevCpp.exe
  WriteRegStr HKCR ".template" "" "DevCpp.template"
  WriteRegStr HKCR "DevCpp.template" "" "Dev-C++ Template File"
  WriteRegStr HKCR "DevCpp.template\DefaultIcon" "" '$0,1'
  WriteRegStr HKCR "DevCpp.template\Shell\Open\Command" "" '$0 "%1"'
  Call RefreshShellIcons
SectionEnd

SubSectionEnd

####################################################################
# Shortcuts
SubSection "Shortcuts" SectionShortcuts

Section "Create Start Menu shortcuts" SectionMenuLaunch
  SectionIn 1 3
 
  ; always use all user start menu, normal users can delete these
  SetShellVarContext all 
  StrCpy $0 $SMPROGRAMS ; start menu Programs folder
  CreateDirectory "$0\Bloodshed Dev-C++"
  CreateShortCut "$0\Bloodshed Dev-C++\Dev-C++.lnk" "$INSTDIR\devcpp.exe"
  CreateShortCut "$0\Bloodshed Dev-C++\License.lnk" "$INSTDIR\copying.txt"
  CreateShortCut "$0\Bloodshed Dev-C++\Uninstall Dev-C++.lnk" "$INSTDIR\uninstall.exe"
SectionEnd

Section "Create Desktop shortcut" SectionDesktopLaunch
  SectionIn 1 3
  
  ; always use current user desktop, normal users can't delete all users' shortcuts
  SetShellVarContext current
  CreateShortCut "$DESKTOP\Dev-C++.lnk" "$INSTDIR\devcpp.exe"
SectionEnd

SubSectionEnd

Section "Remove old configuration files" SectionConfig
  SectionIn 1 2 3

  RMDir /r "$APPDATA\Dev-Cpp"
  
  Delete "$INSTDIR\devcpp.ini"
  Delete "$INSTDIR\devcpp.cfg"
  Delete "$INSTDIR\cache.ccc"
  Delete "$INSTDIR\defaultcode.cfg"
  Delete "$INSTDIR\devshortcuts.cfg"
  Delete "$INSTDIR\classfolders.dcf"
  Delete "$INSTDIR\mirrors.cfg"
  Delete "$INSTDIR\tools.ini"
  Delete "$INSTDIR\devcpp.ci"
SectionEnd

####################################################################
# TODO: Create language tables that describe installation components using LangString

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
!insertmacro MUI_DESCRIPTION_TEXT ${SectionMain}        "The Dev-C++ IDE (Integrated Development Environment), package manager and templates"
!insertmacro MUI_DESCRIPTION_TEXT ${SectionIcons}       "Various icons that you can use in your programs"
#!insertmacro MUI_DESCRIPTION_TEXT ${SectionMinGW}       "The ${COMPILERNAME} compiler and associated tools, headers and libraries"
!insertmacro MUI_DESCRIPTION_TEXT ${SectionLangs}       "The Dev-C++ interface translated to different languages (other than English which is built-in)"
!insertmacro MUI_DESCRIPTION_TEXT ${SectionAssocs}      "Use Dev-C++ as the default application for opening these types of files"
!insertmacro MUI_DESCRIPTION_TEXT ${SectionShortcuts}   "Create shortcuts to Dev-C++ in various folders"
!insertmacro MUI_DESCRIPTION_TEXT ${SectionConfig}      "Remove all leftover configuration files from previous installs"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

####################################################################
# Functions, utilities

Function .onInit
  !insertmacro MUI_LANGDLL_DISPLAY

  IfFileExists "C:\Dev-Cpp\devcpp.exe" 0 +2
    SectionSetFlags ${SectionConfig} ${SF_SELECTED} # Remove old Dev-Cpp config files
	
  IfFileExists "$APPDATA\Dev-Cpp\devcpp.cfg" 0 +2 # deprecated config file
    SectionSetFlags ${SectionConfig} ${SF_SELECTED}
FunctionEnd

;backup file association
Function BackupAssoc
  ;$0 is an extension - for example ".dev"

  ;check if backup already exists
  ReadRegStr $1 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dev-C++\Backup" "$0" 
  ;don't backup if backup exists in registry
  StrCmp $1 "" 0 no_assoc

  ReadRegStr $1 HKCR "$0" ""
  ;don't backup dev-cpp associations
  StrCmp $1 "DevCpp$0" no_assoc

  StrCmp $1 "" no_assoc
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dev-C++\Backup" "$0" "$1"
  no_assoc:
  
FunctionEnd

;restore file association
Function un.RestoreAssoc
  ;$0 is an extension - for example ".dev"

  DeleteRegKey HKCR "$0"
  ReadRegStr $1 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dev-C++\Backup" "$0"
  StrCmp $1 "" no_backup
    WriteRegStr HKCR "$0" "" "$1"
    Call un.RefreshShellIcons
  no_backup:
  
FunctionEnd

;http://nsis.sourceforge.net/archive/viewpage.php?pageid=202
;After changing file associations, you can call this macro to refresh the shell immediatly. 
;It calls the shell32 function SHChangeNotify. This will force windows to reload your changes from the registry.
!define SHCNE_ASSOCCHANGED 0x08000000
!define SHCNF_IDLIST 0

Function RefreshShellIcons
  ; By jerome tremblay - april 2003
  System::Call 'shell32.dll::SHChangeNotify(i, i, i, i) v \
  (${SHCNE_ASSOCCHANGED}, ${SHCNF_IDLIST}, 0, 0)'
FunctionEnd

Function un.RefreshShellIcons
  ; By jerome tremblay - april 2003
  System::Call 'shell32.dll::SHChangeNotify(i, i, i, i) v \
  (${SHCNE_ASSOCCHANGED}, ${SHCNF_IDLIST}, 0, 0)'
FunctionEnd

Function un.DeleteDirIfEmpty
  FindFirst $R0 $R1 "$0\*.*"
  strcmp $R1 "." 0 NoDelete
   FindNext $R0 $R1
   strcmp $R1 ".." 0 NoDelete
    ClearErrors
    FindNext $R0 $R1
    IfErrors 0 NoDelete
     FindClose $R0
     Sleep 1000
     RMDir "$0"
  NoDelete:
   FindClose $R0
FunctionEnd

####################################################################
# uninstall

UninstallText "This program will uninstall Dev-C++, continue?"
ShowUninstDetails show

Section "Uninstall"

  ; Remove uninstaller
  Delete "$INSTDIR\uninstall.exe"

  ; Remove start menu stuff, located in all users folder
  SetShellVarContext all 
  Delete "$SMPROGRAMS\Bloodshed Dev-C++\Dev-C++.lnk"
  Delete "$SMPROGRAMS\Bloodshed Dev-C++\License.lnk"
  Delete "$SMPROGRAMS\Bloodshed Dev-C++\Uninstall Dev-C++.lnk"
  RMDir "$SMPROGRAMS\Bloodshed Dev-C++"
  
  ; Remove desktop stuff, located in current user folder
  SetShellVarContext current
  Delete "$QUICKLAUNCH\Dev-C++.lnk"
  Delete "$DESKTOP\Dev-C++.lnk"

  ; Restore file associations
  StrCpy $0 ".dev"
  Call un.RestoreAssoc
  StrCpy $0 ".c"
  Call un.RestoreAssoc
  StrCpy $0 ".cpp"
  Call un.RestoreAssoc
  StrCpy $0 ".h"
  Call un.RestoreAssoc
  StrCpy $0 ".hpp"
  Call un.RestoreAssoc
  StrCpy $0 ".rc"
  Call un.RestoreAssoc
  StrCpy $0 ".devpak"
  Call un.RestoreAssoc
  StrCpy $0 ".devpackage"
  Call un.RestoreAssoc
  StrCpy $0 ".template"
  Call un.RestoreAssoc
 
  DeleteRegKey HKCR "DevCpp.dev"
  DeleteRegKey HKCR "DevCpp.c"
  DeleteRegKey HKCR "DevCpp.cpp"
  DeleteRegKey HKCR "DevCpp.h"
  DeleteRegKey HKCR "DevCpp.hpp"
  DeleteRegKey HKCR "DevCpp.rc"
  DeleteRegKey HKCR "DevCpp.devpak"
  DeleteRegKey HKCR "DevCpp.devpackage"
  DeleteRegKey HKCR "DevCpp.template"

  Delete "$INSTDIR\Packman.map"
  Delete "$INSTDIR\Packman.exe"
  Delete "$INSTDIR\NEWS.txt"
  Delete "$INSTDIR\devcpp.map"
  Delete "$INSTDIR\devcpp.exe"
  Delete "$INSTDIR\devcpp.exe.manifest"
  Delete "$INSTDIR\ConsolePauser.exe"
  Delete "$INSTDIR\copying.txt"

  RMDir /r "$INSTDIR\${COMPILERFOLDER}"
  RMDir /r "$INSTDIR\Lang"
  RMDir /r "$INSTDIR\Examples"
  RMDir /r "$INSTDIR\Help"
  RMDir /r "$INSTDIR\Icons"
  RMDir /r "$INSTDIR\Packages"
  RMDir /r "$INSTDIR\Templates"
  RMDir /r "$INSTDIR\Astyle"
  Delete "$INSTDIR\busybox.exe"
  RMDir /r "$INSTDIR\photogram\*"
  DetailPrint "正在卸载字体，需要一些时间来通知所有进程，请稍候"
  ;StrCpy $0 "$INSTDIR\DejaVuSansMono YaHei NF.ttf"
  ;DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "DejaVuSansMono YaHei NF Devcpp"
  ;System::Call "GDI32::RemoveFontResource(t) i ('$0') .s"
  ;System::Call "User32::SendMessageTimeout(iiiiiii)i (${HWND_BROADCAST}, ${WM_FONTCHANGE}, 0, 0, 11, 20000, 0) .s"
  ;Delete "$INSTDIR\DejaVuSansMono YaHei NF.ttf"
  
  GetTempFileName $1
  FileOpen $0 $1 w
  FileWrite $0 `Set sh = CreateObject("Shell.Application")$\n`
  FileWrite $0 `sh.NameSpace("$INSTDIR").MoveHere sh.NameSpace(20).ParseName("DYNF.ttf")$\n`
  FileClose $0
  nsExec::ExecToStack `"$SYSDIR\CScript.exe" $1 //e:vbscript //B //NOLOGO`
  Pop $0
  DetailPrint `Return Code = $0`
  Delete "$INSTDIR\DYNF.ttf"
  StrCpy $0 "$INSTDIR"
  Call un.DeleteDirIfEmpty

  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Dev-C++"

  IfSilent +2 ; Don't ask when running in silent mode
  MessageBox MB_YESNO "Do you want to remove all the remaining configuration files?" IDNO Done

  RMDir /r "$APPDATA\Dev-Cpp"
  
  Delete "$INSTDIR\devcpp.ini"
  Delete "$INSTDIR\devcpp.cfg"
  Delete "$INSTDIR\cache.ccc"
  Delete "$INSTDIR\defaultcode.cfg"
  Delete "$INSTDIR\devshortcuts.cfg"
  Delete "$INSTDIR\classfolders.dcf"
  Delete "$INSTDIR\mirrors.cfg"
  Delete "$INSTDIR\tools.ini"
  Delete "$INSTDIR\devcpp.ci"
  RMDir /r "$INSTDIR"
Done:
SectionEnd
