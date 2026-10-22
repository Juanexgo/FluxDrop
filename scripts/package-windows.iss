#define AppVersion "0.4.0"
[Setup]
AppId={{B523C2B2-C06D-4D28-A27B-220242F1E938}
AppName=FluxDrop
AppVersion={#AppVersion}
AppPublisher=FluxDrop
AppPublisherURL=https://fluxdrop-ruby.vercel.app/
DefaultDirName={localappdata}\Programs\FluxDrop
DefaultGroupName=FluxDrop
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.22621
OutputDir=..\build\windows-installer
OutputBaseFilename=FluxDrop-0.4.0-windows-x64-dev-setup
SetupIconFile=..\apps\windows\FluxDrop.Windows\Assets\FluxDrop.ico
UninstallDisplayIcon={app}\FluxDrop.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo / Create desktop shortcut"; Flags: unchecked
Name: "ocr"; Description: "OCR local español e inglés (~8 MB) / Local Spanish and English OCR (~8 MB)"
[Files]
Source: "..\build\windows-publish\*"; DestDir: "{app}"; Excludes: "engines\tessdata\*"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\build\windows-publish\engines\tessdata\*"; DestDir: "{app}\engines\tessdata"; Tasks: ocr; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\FluxDrop"; Filename: "{app}\FluxDrop.exe"
Name: "{autodesktop}\FluxDrop"; Filename: "{app}\FluxDrop.exe"; Tasks: desktopicon
[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "FluxDrop"; Flags: uninsdeletevalue
[Run]
Filename: "{app}\FluxDrop.exe"; Description: "Abrir FluxDrop / Launch FluxDrop"; Flags: nowait postinstall skipifsilent
