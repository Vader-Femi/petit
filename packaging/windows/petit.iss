; Inno Setup script for the Petit Windows installer.
;
; Compile (from the repository root, after `flutter build windows --release`):
;   ISCC /DAppVersion=1.0.25 /DAppBuild=25 packaging\windows\petit.iss
;
; Optional defines:
;   /DSourceDir=<folder>   the Flutter release folder (default below)
; Optional input:
;   packaging\windows\redist\vc_redist.x64.exe
;     When present it is bundled and installed silently if the Microsoft Visual C++
;     runtime is missing on the user's PC. The release workflow downloads it.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef AppBuild
  #define AppBuild "0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

#define AppName "Petit"
#define AppExe "petit.exe"
#define AppPublisher "Vader-Femi"
#define AppUrl "https://github.com/Vader-Femi/petit"
#define Redist AddBackslash(SourcePath) + "redist\vc_redist.x64.exe"

[Setup]
; Identifies this app for upgrades and uninstall. Never change it.
AppId={{717D5427-839B-4297-8B74-994DE9963E8B}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
VersionInfoVersion={#AppVersion}.{#AppBuild}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputBaseFilename=petit-windows-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Installs just for the current user without an admin prompt; the first page of
; the wizard lets the user choose "for all users" instead.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#if FileExists(Redist)
Source: "{#Redist}"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: VCRedistNeeded
#endif

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
#if FileExists(Redist)
; shellexec lets Windows ask for the admin rights the runtime installer needs,
; even when Petit itself is installed for the current user only.
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing the Microsoft Visual C++ runtime..."; Flags: shellexec waituntilterminated; Check: VCRedistNeeded
#endif
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
// True when the 64-bit Visual C++ 2015-2022 runtime is not installed yet.
function VCRedistNeeded(): Boolean;
var
  Installed: Cardinal;
begin
  Result := not (RegQueryDWordValue(HKLM64,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed)
    and (Installed = 1));
end;
