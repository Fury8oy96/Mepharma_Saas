; ==============================================================================
; MePharma Pharmacy Management System - Inno Setup Script
; ==============================================================================

#define MyAppName "MePharma"
#define MyAppVersion "2.0.3"
#define MyAppPublisher "MePharma Systems"
#define MyAppURL "https://github.com/Fury8oy96/Mepharma_Saas"
#define MyAppExeName "mepharma.exe"
#define SourceDir "..\frontend\build\windows\x64\runner\Release"
#define AppIconPath "..\frontend\windows\runner\resources\app_icon.ico"

[Setup]
; App Information
AppId={{D819C456-9B38-4F7E-9031-FA15093EAE72}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppMutex=MePharmaSingletonMutex

; Destination Directories
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Output Configuration
OutputDir=Output
OutputBaseFilename=MePharma_Setup_2.03
SetupIconFile={#AppIconPath}
UninstallDisplayIcon={app}\{#MyAppExeName}

; Compression & Modern Visual Style
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
DisableWelcomePage=no
CloseApplications=yes
RestartApplications=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

#if defined(SignToolCmd)
SignTool={#SignToolCmd}
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Launch MePharma automatically on Windows startup"; GroupDescription: "Windows Integration"; Flags: unchecked

[Files]
; Release bundle (all binaries, Flutter engine, assets, dynamic native libraries)
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "MePharma POS"; ValueData: """{app}\{#MyAppExeName}"""; Tasks: startupicon; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  AppGuid = '{D819C456-9B38-4F7E-9031-FA15093EAE72}';

var
  EnvironmentPage: TWizardPage;
  LocalModeRadio: TRadioButton;
  OnlineModeRadio: TRadioButton;
  CleanInstallCheckBox: TCheckBox;
  DomainLabel: TLabel;
  DomainEdit: TNewEdit;
  DomainHintLabel: TLabel;
  LicenseKeyLabel: TLabel;
  LicenseKeyEdit: TNewEdit;
  LicenseKeyHintLabel: TLabel;
  OnlineNoteLabel: TLabel;
  IsUpgradeMode: Boolean;

procedure ModeRadioOnClick(Sender: TObject);
begin
  DomainLabel.Enabled := OnlineModeRadio.Checked;
  DomainEdit.Enabled := OnlineModeRadio.Checked;
  DomainHintLabel.Enabled := OnlineModeRadio.Checked;
  LicenseKeyLabel.Enabled := OnlineModeRadio.Checked;
  LicenseKeyEdit.Enabled := OnlineModeRadio.Checked;
  LicenseKeyHintLabel.Enabled := OnlineModeRadio.Checked;
  OnlineNoteLabel.Visible := OnlineModeRadio.Checked;

  // When Standalone Local SQLite is selected on fresh installation, default CleanInstall to True
  if LocalModeRadio.Checked and not IsUpgradeMode then
  begin
    CleanInstallCheckBox.Checked := True;
  end;
end;

procedure CreateEnvironmentPage;
var
  LocalDescLabel, OnlineDescLabel: TLabel;
begin
  EnvironmentPage := CreateCustomPage(
    wpSelectDir,
    'Database & Environment Setup',
    'Choose your pharmacy connection mode and activate your 1-year license.'
  );

  // 1. Standalone Local SQLite Option
  LocalModeRadio := TRadioButton.Create(EnvironmentPage);
  LocalModeRadio.Parent := EnvironmentPage.Surface;
  LocalModeRadio.Left := ScaleX(10);
  LocalModeRadio.Top := ScaleY(10);
  LocalModeRadio.Width := ScaleX(390);
  LocalModeRadio.Height := ScaleY(20);
  LocalModeRadio.Font.Style := [fsBold];
  LocalModeRadio.Caption := '1. Standalone Local SQLite (Offline Mode)';
  LocalModeRadio.Checked := False;
  LocalModeRadio.OnClick := @ModeRadioOnClick;

  LocalDescLabel := TLabel.Create(EnvironmentPage);
  LocalDescLabel.Parent := EnvironmentPage.Surface;
  LocalDescLabel.Left := ScaleX(30);
  LocalDescLabel.Top := ScaleY(32);
  LocalDescLabel.Width := ScaleX(370);
  LocalDescLabel.Height := ScaleY(28);
  LocalDescLabel.AutoSize := False;
  LocalDescLabel.WordWrap := True;
  LocalDescLabel.Caption := 'All sales, users, and stock are saved locally on this machine. No server or internet connection required.';

  // 2. Online Server / Cloud API Option
  OnlineModeRadio := TRadioButton.Create(EnvironmentPage);
  OnlineModeRadio.Parent := EnvironmentPage.Surface;
  OnlineModeRadio.Left := ScaleX(10);
  OnlineModeRadio.Top := ScaleY(65);
  OnlineModeRadio.Width := ScaleX(390);
  OnlineModeRadio.Height := ScaleY(20);
  OnlineModeRadio.Font.Style := [fsBold];
  OnlineModeRadio.Caption := '2. Online Server / Cloud Network (Recommended)';
  OnlineModeRadio.Checked := True;
  OnlineModeRadio.OnClick := @ModeRadioOnClick;

  OnlineDescLabel := TLabel.Create(EnvironmentPage);
  OnlineDescLabel.Parent := EnvironmentPage.Surface;
  OnlineDescLabel.Left := ScaleX(30);
  OnlineDescLabel.Top := ScaleY(87);
  OnlineDescLabel.Width := ScaleX(370);
  OnlineDescLabel.Height := ScaleY(28);
  OnlineDescLabel.AutoSize := False;
  OnlineDescLabel.WordWrap := True;
  OnlineDescLabel.Caption := 'Connects to your MePharma centralized pharmacy domain for multi-terminal sync and live telemetry.';

  // Pharmacy Domain / Host Field
  DomainLabel := TLabel.Create(EnvironmentPage);
  DomainLabel.Parent := EnvironmentPage.Surface;
  DomainLabel.Left := ScaleX(30);
  DomainLabel.Top := ScaleY(122);
  DomainLabel.Width := ScaleX(110);
  DomainLabel.Caption := 'Pharmacy Domain:';

  DomainEdit := TNewEdit.Create(EnvironmentPage);
  DomainEdit.Parent := EnvironmentPage.Surface;
  DomainEdit.Left := ScaleX(145);
  DomainEdit.Top := ScaleY(119);
  DomainEdit.Width := ScaleX(255);
  DomainEdit.Height := ScaleY(22);
  DomainEdit.Text := 'main.localhost:8000';

  DomainHintLabel := TLabel.Create(EnvironmentPage);
  DomainHintLabel.Parent := EnvironmentPage.Surface;
  DomainHintLabel.Left := ScaleX(145);
  DomainHintLabel.Top := ScaleY(143);
  DomainHintLabel.Width := ScaleX(255);
  DomainHintLabel.Font.Size := 7;
  DomainHintLabel.Font.Color := clGray;
  DomainHintLabel.Caption := 'e.g. main.localhost:8000 or pharmacy.domain.com';

  // License Key Field
  LicenseKeyLabel := TLabel.Create(EnvironmentPage);
  LicenseKeyLabel.Parent := EnvironmentPage.Surface;
  LicenseKeyLabel.Left := ScaleX(30);
  LicenseKeyLabel.Top := ScaleY(165);
  LicenseKeyLabel.Width := ScaleX(110);
  LicenseKeyLabel.Caption := 'License Number:';

  LicenseKeyEdit := TNewEdit.Create(EnvironmentPage);
  LicenseKeyEdit.Parent := EnvironmentPage.Surface;
  LicenseKeyEdit.Left := ScaleX(145);
  LicenseKeyEdit.Top := ScaleY(162);
  LicenseKeyEdit.Width := ScaleX(255);
  LicenseKeyEdit.Height := ScaleY(22);
  LicenseKeyEdit.Text := '';

  LicenseKeyHintLabel := TLabel.Create(EnvironmentPage);
  LicenseKeyHintLabel.Parent := EnvironmentPage.Surface;
  LicenseKeyHintLabel.Left := ScaleX(145);
  LicenseKeyHintLabel.Top := ScaleY(186);
  LicenseKeyHintLabel.Width := ScaleX(255);
  LicenseKeyHintLabel.Font.Size := 7;
  LicenseKeyHintLabel.Font.Color := clGray;
  LicenseKeyHintLabel.Caption := 'Enter the 1-year cryptographic key (starts with LIC-)';

  // Online Note
  OnlineNoteLabel := TLabel.Create(EnvironmentPage);
  OnlineNoteLabel.Parent := EnvironmentPage.Surface;
  OnlineNoteLabel.Left := ScaleX(30);
  OnlineNoteLabel.Top := ScaleY(205);
  OnlineNoteLabel.Width := ScaleX(370);
  OnlineNoteLabel.Height := ScaleY(24);
  OnlineNoteLabel.AutoSize := False;
  OnlineNoteLabel.WordWrap := True;
  OnlineNoteLabel.Font.Color := clHighlight;
  OnlineNoteLabel.Caption := 'Pharmacy branding and terminal seats will be auto-grabbed from the server.';
  OnlineNoteLabel.Visible := True;

  // Clean Install Option (Wipes previous SQLite database for fresh start)
  CleanInstallCheckBox := TCheckBox.Create(EnvironmentPage);
  CleanInstallCheckBox.Parent := EnvironmentPage.Surface;
  CleanInstallCheckBox.Left := ScaleX(10);
  CleanInstallCheckBox.Top := ScaleY(235);
  CleanInstallCheckBox.Width := ScaleX(390);
  CleanInstallCheckBox.Height := ScaleY(20);
  if RegKeyExists(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + AppGuid + '_is1') or
     RegKeyExists(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + AppGuid + '_is1') then
  begin
    CleanInstallCheckBox.Caption := 'Reset database: Wipe local database and start fresh (Caution: deletes offline sales)';
    CleanInstallCheckBox.Checked := False;
  end
  else
  begin
    CleanInstallCheckBox.Caption := 'Clean install: Wipe previous local database (fresh start for this installation)';
    CleanInstallCheckBox.Checked := True;
  end;
end;

function GetExistingInstallDir: String;
var
  InstallPath: String;
begin
  Result := '';
  if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + AppGuid + '_is1', 'Inno Setup: App Path', InstallPath) then
  begin
    if Length(InstallPath) > 0 then
    begin
      Result := InstallPath;
      Exit;
    end;
  end;
  if RegQueryStringValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + AppGuid + '_is1', 'Inno Setup: App Path', InstallPath) then
  begin
    if Length(InstallPath) > 0 then
    begin
      Result := InstallPath;
      Exit;
    end;
  end;
  if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + AppGuid + '_is1', 'InstallLocation', InstallPath) then
  begin
    if Length(InstallPath) > 0 then
    begin
      Result := InstallPath;
      Exit;
    end;
  end;
  if RegQueryStringValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + AppGuid + '_is1', 'InstallLocation', InstallPath) then
  begin
    if Length(InstallPath) > 0 then
    begin
      Result := InstallPath;
      Exit;
    end;
  end;
end;

procedure LoadExistingConfig;
var
  InstallDir: String;
  ConfigFile: String;
  FileContent: AnsiString;
  P, PEnd: Integer;
begin
  InstallDir := GetExistingInstallDir;
  if Length(InstallDir) = 0 then
    Exit;

  ConfigFile := InstallDir + '\api_config.json';
  if FileExists(ConfigFile) then
  begin
    if LoadStringFromFile(ConfigFile, FileContent) then
    begin
      P := Pos('"pharmacyDomain": "', String(FileContent));
      if P > 0 then
      begin
        P := P + Length('"pharmacyDomain": "');
        PEnd := Pos('"', Copy(String(FileContent), P, Length(String(FileContent)) - P + 1));
        if PEnd > 1 then
          DomainEdit.Text := Copy(String(FileContent), P, PEnd - 1);
      end;
      P := Pos('"licenseKey": "', String(FileContent));
      if P > 0 then
      begin
        P := P + Length('"licenseKey": "');
        PEnd := Pos('"', Copy(String(FileContent), P, Length(String(FileContent)) - P + 1));
        if PEnd > 1 then
          LicenseKeyEdit.Text := Copy(String(FileContent), P, PEnd - 1);
      end;
      P := Pos('"mode": "local"', String(FileContent));
      if P > 0 then
      begin
        LocalModeRadio.Checked := True;
        OnlineModeRadio.Checked := False;
        ModeRadioOnClick(nil);
      end;
    end;
  end;
end;

procedure InitializeWizard;
var
  ExistingDir: String;
begin
  IsUpgradeMode := RegKeyExists(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + AppGuid + '_is1') or
                   RegKeyExists(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + AppGuid + '_is1');
  CreateEnvironmentPage;
  if IsUpgradeMode then
  begin
    WizardForm.Caption := 'Update - ' + '{#MyAppName}';
    ExistingDir := GetExistingInstallDir;
    if Length(ExistingDir) > 0 then
    begin
      WizardForm.DirEdit.Text := ExistingDir;
    end;
    LoadExistingConfig;
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  // If this is an upgrade/update, skip the database & environment selection page
  if IsUpgradeMode and (PageID = EnvironmentPage.ID) then
  begin
    Result := True;
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  KeyText, DomainText: String;
begin
  Result := True;
  if CurPageID = EnvironmentPage.ID then
  begin
    if OnlineModeRadio.Checked then
    begin
      DomainText := Trim(DomainEdit.Text);
      if Length(DomainText) = 0 then
      begin
        MsgBox('Please enter the Pharmacy Domain or Server Host (e.g. main.localhost:8000).', mbError, MB_OK);
        Result := False;
        Exit;
      end;

      KeyText := Trim(LicenseKeyEdit.Text);
      if Length(KeyText) = 0 then
      begin
        MsgBox('Please enter the 1-year Cryptographic License Key (LIC-...) provided by your administrator.', mbError, MB_OK);
        Result := False;
        Exit;
      end;

      if Pos('LIC-', KeyText) <> 1 then
      begin
        MsgBox('Invalid license key format. The license key must begin with "LIC-".', mbError, MB_OK);
        Result := False;
        Exit;
      end;
    end;
  end;
end;

function ExtractTenantCode(DomainStr: String): String;
var
  CleanDomain: String;
  DotPos: Integer;
begin
  CleanDomain := DomainStr;
  if Pos('http://', CleanDomain) = 1 then
    Delete(CleanDomain, 1, 7);
  if Pos('https://', CleanDomain) = 1 then
    Delete(CleanDomain, 1, 8);
  
  DotPos := Pos(':', CleanDomain);
  if DotPos > 0 then
    CleanDomain := Copy(CleanDomain, 1, DotPos - 1);

  DotPos := Pos('.', CleanDomain);
  if DotPos > 1 then
    Result := Copy(CleanDomain, 1, DotPos - 1)
  else
    Result := 'main';
end;

function NormalizeBaseUrl(DomainStr: String): String;
var
  CleanDomain: String;
  PortStr: String;
  ColonPos: Integer;
begin
  CleanDomain := Trim(DomainStr);
  if Length(CleanDomain) = 0 then
    CleanDomain := 'main.localhost:8000';

  if Pos('http://', CleanDomain) = 1 then
    Delete(CleanDomain, 1, 7);
  if Pos('https://', CleanDomain) = 1 then
    Delete(CleanDomain, 1, 8);

  // If ends with / or /api, trim it
  if (Length(CleanDomain) > 0) and (CleanDomain[Length(CleanDomain)] = '/') then
    Delete(CleanDomain, Length(CleanDomain), 1);
  if Pos('/api', CleanDomain) = Length(CleanDomain) - 3 then
    Delete(CleanDomain, Length(CleanDomain) - 3, 4);

  // If subdomain of localhost (e.g. main.localhost:8000), target must be localhost:8000
  // because Windows WinSock cannot resolve *.localhost
  if Pos('.localhost', CleanDomain) > 0 then
  begin
    ColonPos := Pos(':', CleanDomain);
    if ColonPos > 0 then
      PortStr := Copy(CleanDomain, ColonPos, Length(CleanDomain) - ColonPos + 1)
    else
      PortStr := ':8000';
    Result := 'http://localhost' + PortStr + '/api';
  end
  else
  begin
    if (Pos('localhost', CleanDomain) > 0) or (Pos('127.0.0.1', CleanDomain) > 0) then
      Result := 'http://' + CleanDomain + '/api'
    else
      Result := 'https://' + CleanDomain + '/api';
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ConfigJson: String;
  ConfigPath: String;
  ModeStr: String;
  RawDomain: String;
  NormalizedUrl: String;
  TenantCode: String;
  LicenseKeyVal: String;
begin
  if CurStep = ssPostInstall then
  begin
    if LocalModeRadio.Checked then
    begin
      ModeStr := 'local';
      NormalizedUrl := 'http://localhost:8000/api';
      RawDomain := 'local';
      TenantCode := 'local';
      LicenseKeyVal := 'OFFLINE-STANDALONE-PERPETUAL';
    end
    else
    begin
      ModeStr := 'onlineApi';
      RawDomain := Trim(DomainEdit.Text);
      if Length(RawDomain) = 0 then
        RawDomain := 'main.localhost:8000';
      NormalizedUrl := NormalizeBaseUrl(RawDomain);
      TenantCode := ExtractTenantCode(RawDomain);
      LicenseKeyVal := Trim(LicenseKeyEdit.Text);
    end;

    ConfigJson := '{' + #13#10 +
      '  "mode": "' + ModeStr + '",' + #13#10 +
      '  "baseUrl": "' + NormalizedUrl + '",' + #13#10 +
      '  "pharmacyDomain": "' + RawDomain + '",' + #13#10 +
      '  "pharmacyCode": "' + TenantCode + '",' + #13#10 +
      '  "licenseKey": "' + LicenseKeyVal + '",' + #13#10 +
      '  "branchId": 1,' + #13#10 +
      '  "isConfigured": true,' + #13#10 +
      '  "isLicenseValid": true,' + #13#10 +
      '  "licensePlan": "offline_standalone",' + #13#10 +
      '  "validityDaysRemaining": 365,' + #13#10 +
      '  "pharmacyName": "MePharma Local",' + #13#10 +
      '  "pharmacyAddress": "Standalone SQLite Database",' + #13#10 +
      '  "currency": "SDG",' + #13#10 +
      '  "currencySymbol": "ج.س"' + #13#10 +
      '}';

    ConfigPath := ExpandConstant('{app}\api_config.json');
    // On update/upgrade, preserve existing api_config.json if already present
    if not IsUpgradeMode or not FileExists(ConfigPath) then
    begin
      SaveStringToFile(ConfigPath, ConfigJson, False);
    end;

    // Purge database ONLY if clean install was explicitly checked AND this is not an update!
    if CleanInstallCheckBox.Checked and not IsUpgradeMode then
    begin
      DeleteFile(ExpandConstant('{userdocs}\mepharma.sqlite'));
      DeleteFile(ExpandConstant('{userdocs}\mepharma.sqlite-shm'));
      DeleteFile(ExpandConstant('{userdocs}\mepharma.sqlite-wal'));
      DeleteFile(ExpandConstant('{localappdata}\mepharma.sqlite'));
      DeleteFile(ExpandConstant('{localappdata}\mepharma.sqlite-shm'));
      DeleteFile(ExpandConstant('{localappdata}\mepharma.sqlite-wal'));
      DeleteFile(ExpandConstant('{userappdata}\MePharma\api_config.json'));
      // Drop clean install flag next to mepharma.exe to guarantee in-app database reset on first launch
      SaveStringToFile(ExpandConstant('{app}\clean_install.flag'), 'CLEAN', False);
    end;
  end;
end;
