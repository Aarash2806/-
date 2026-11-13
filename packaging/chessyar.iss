; ============================================================
;  ChessYar Professional - Windows installer (Inno Setup 6)
;  Input : build\windows\x64\runner\Release\  (flutter build output)
;  Output: dist\ChessYar-Setup.exe
;  Installs the app, creates Start-Menu shortcuts and (by default)
;  a Desktop shortcut with the ChessYar icon.
; ============================================================

#define MyAppName "ChessYar Professional"
#define MyAppExeName "chessyar.exe"
#define MyAppVersion "0.1.0"

[Setup]
AppId={{0583DF7D-76ED-4381-A2B7-3F54D3B93558}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=ChessYar
DefaultDirName={autopf}\ChessYar
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=dist
OutputBaseFilename=ChessYar-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; Desktop shortcut is CHECKED by default (user requirement).
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
