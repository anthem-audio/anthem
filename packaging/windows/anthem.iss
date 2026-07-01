#ifndef MyArch
#define MyArch "x64"
#endif

#define MyAppVersion "0.0.0-prealpha.1"
#define MyAppVersionNumeric "0.0.0.1"

[Setup]
AppId={{7C9E4F2A-3B6D-4E8C-9A1F-5D7E3B2C8A4F}
AppName=Anthem
AppVersion={#MyAppVersion}
AppPublisher=Anthem authors
VersionInfoVersion={#MyAppVersionNumeric}
DefaultDirName={autopf}\Anthem
DefaultGroupName=Anthem
DisableProgramGroupPage=yes
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Anthem.exe
OutputDir=..\..\build\windows\{#MyArch}\installer
OutputBaseFilename=anthem-windows-{#MyArch}
#if MyArch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\{#MyArch}\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\Anthem"; Filename: "{app}\Anthem.exe"
Name: "{group}\{cm:UninstallProgram,Anthem}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\Anthem"; Filename: "{app}\Anthem.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Anthem.exe"; Description: "{cm:LaunchProgram,Anthem}"; Flags: nowait postinstall skipifsilent
