unit WombatFM.History;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, WombatFM.Options;

type
  TWindowLayout = record
    Width: Integer;
    Height: Integer;
    LeftPanelWidth: Integer;
  end;

  THistoryDirection = (hdBack, hdForward);

  TPathHistory = class
  private
    FStacks: array[THistoryDirection] of TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddVisit(const APath: string);
    procedure Pop(ADirection: THistoryDirection; out APath: string);
    procedure Push(ADirection: THistoryDirection; const APath: string);
  end;

function GetOppositeDirection(ADirection: THistoryDirection): THistoryDirection;
procedure TrimRecentPaths(AList: TStrings; AMaxCount: Integer);
procedure AddRecentPath(AList: TStrings; const APath: string; AMaxCount: Integer);

procedure LoadSettings(ALeft, ARight: TStrings; out ALayout: TWindowLayout;
  out AOptions: TAppOptions);
procedure SaveSettings(ALeft, ARight: TStrings; const ALayout: TWindowLayout;
  const AOptions: TAppOptions);

implementation

uses
  fpjson, jsonparser, LazFileUtils, LazUTF8{$IFDEF WINDOWS}, Windows{$ENDIF};

const
  CRecentPathsKey = 'recentPaths';
  CRightRecentPathsKey = 'rightRecentPaths';
  CWindowLayoutKey = 'windowLayout';
  COptionsKey = 'options';

function SettingsFileName: string;
begin
  Result := ExtractFilePath(ParamStrUTF8(0)) + 'settings.json';
end;

function ReadSettings(const AFileName: string): TJSONObject;
var
  LHandle: THandle;
  LStream: THandleStream;
  LData: TJSONData;
begin
  if not FileExistsUTF8(AFileName) then
    Exit(TJSONObject.Create);

  LHandle := FileOpenUTF8(AFileName, fmOpenRead or fmShareDenyNone);
  if LHandle = THandle(-1) then
    raise EInOutError.Create('Cannot read ' + AFileName);
  try
    LStream := THandleStream.Create(LHandle);
    try
      LData := GetJSON(LStream, True);
    finally
      LStream.Free;
    end;
  finally
    FileClose(LHandle);
  end;

  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise EConvertError.Create('Expected a JSON object in ' + AFileName);
  end;
  Result := TJSONObject(LData);
end;

procedure LoadPathList(ASettings: TJSONObject; const AKey: string; AList: TStrings;
  AMaxCount: Integer);
var
  LPaths: TJSONArray;
  LIndex: Integer;
begin
  if not ASettings.Find(AKey, LPaths) then
    Exit;
  AList.BeginUpdate;
  try
    AList.Clear;
    for LIndex := 0 to LPaths.Count - 1 do
    begin
      if (LPaths.Items[LIndex].JSONType = jtString) and
        (LPaths.Strings[LIndex] <> '') and
        (AList.IndexOf(LPaths.Strings[LIndex]) < 0) then
        AList.Add(LPaths.Strings[LIndex]);
    end;
    TrimRecentPaths(AList, AMaxCount);
  finally
    AList.EndUpdate;
  end;
end;

procedure LoadSettings(ALeft, ARight: TStrings; out ALayout: TWindowLayout;
  out AOptions: TAppOptions);
var
  LSettings, LLayout, LOptions: TJSONObject;
begin
  ALayout := Default(TWindowLayout);
  LSettings := ReadSettings(SettingsFileName);
  try
    if not LSettings.Find(COptionsKey, LOptions) then
      LOptions := nil;
    LoadOptions(LOptions, AOptions);
    LoadPathList(LSettings, CRecentPathsKey, ALeft, AOptions.OptionMaxPathHistory);
    LoadPathList(LSettings, CRightRecentPathsKey, ARight,
      AOptions.OptionMaxPathHistory);
    if LSettings.Find(CWindowLayoutKey, LLayout) then
    begin
      ALayout.Width := LLayout.Get('width', 0);
      ALayout.Height := LLayout.Get('height', 0);
      ALayout.LeftPanelWidth := LLayout.Get('leftPanelWidth', 0);
    end;
  finally
    LSettings.Free;
  end;
end;

procedure SavePathList(ASettings: TJSONObject; const AKey: string; AList: TStrings);
var
  LPaths: TJSONArray;
  LIndex: Integer;
begin
  ASettings.Delete(AKey);
  LPaths := TJSONArray.Create;
  ASettings.Add(AKey, LPaths);
  for LIndex := 0 to AList.Count - 1 do
    LPaths.Add(AList[LIndex]);
end;

function GetSettingsSection(ASettings: TJSONObject; const AKey: string): TJSONObject;
begin
  if not ASettings.Find(AKey, Result) then
  begin
    ASettings.Delete(AKey);
    Result := TJSONObject.Create;
    ASettings.Add(AKey, Result);
  end;
end;

procedure SaveSettings(ALeft, ARight: TStrings; const ALayout: TWindowLayout;
  const AOptions: TAppOptions);
var
  LFileName, LTempName: string;
  LId: TGUID;
  LSettings, LLayout: TJSONObject;
  LText: UTF8String;
  LHandle: THandle;
  LStream: THandleStream;
begin
  LFileName := SettingsFileName;
  LSettings := ReadSettings(LFileName);
  try
    SavePathList(LSettings, CRecentPathsKey, ALeft);
    SavePathList(LSettings, CRightRecentPathsKey, ARight);
    LLayout := GetSettingsSection(LSettings, CWindowLayoutKey);
    LLayout.Integers['width'] := ALayout.Width;
    LLayout.Integers['height'] := ALayout.Height;
    LLayout.Integers['leftPanelWidth'] := ALayout.LeftPanelWidth;
    SaveOptions(GetSettingsSection(LSettings, COptionsKey), AOptions);
    LText := LSettings.FormatJSON + LineEnding;
  finally
    LSettings.Free;
  end;

  if CreateGUID(LId) <> 0 then
    raise EInOutError.Create('Cannot create a temporary settings file');
  LTempName := LFileName + '.' + GUIDToString(LId) + '.tmp';
  LHandle := FileCreateUTF8(LTempName);
  if LHandle = THandle(-1) then
    raise EInOutError.Create('Cannot create ' + LTempName);
  try
    try
      LStream := THandleStream.Create(LHandle);
      try
        LStream.WriteBuffer(LText[1], Length(LText));
      finally
        LStream.Free;
      end;
    finally
      FileClose(LHandle);
    end;
    {$IFDEF WINDOWS}
    if not MoveFileExW(PWideChar(UTF8Decode(LTempName)),
      PWideChar(UTF8Decode(LFileName)), MOVEFILE_REPLACE_EXISTING) then
    {$ELSE}
    if not RenameFileUTF8(LTempName, LFileName) then
    {$ENDIF}
      raise EInOutError.Create('Cannot replace ' + LFileName);
  finally
    if FileExistsUTF8(LTempName) then
      DeleteFileUTF8(LTempName);
  end;
end;

function GetOppositeDirection(ADirection: THistoryDirection): THistoryDirection;
begin
  if ADirection = hdBack then
    Result := hdForward
  else
    Result := hdBack;
end;

procedure TrimRecentPaths(AList: TStrings; AMaxCount: Integer);
begin
  while AList.Count > AMaxCount do
    AList.Delete(AList.Count - 1);
end;

procedure AddRecentPath(AList: TStrings; const APath: string; AMaxCount: Integer);
var
  LIndex: integer;
begin
  LIndex := AList.IndexOf(APath);
  if LIndex >= 0 then
    AList.Delete(LIndex);
  AList.Insert(0, APath);
  TrimRecentPaths(AList, AMaxCount);
end;

constructor TPathHistory.Create;
var
  LDirection: THistoryDirection;
begin
  inherited Create;
  for LDirection := Low(THistoryDirection) to High(THistoryDirection) do
    FStacks[LDirection] := TStringList.Create;
end;

destructor TPathHistory.Destroy;
var
  LDirection: THistoryDirection;
begin
  for LDirection := Low(THistoryDirection) to High(THistoryDirection) do
    FStacks[LDirection].Free;
  inherited Destroy;
end;

procedure TPathHistory.Push(ADirection: THistoryDirection; const APath: string);
begin
  FStacks[ADirection].Add(APath);
end;

procedure TPathHistory.Pop(ADirection: THistoryDirection; out APath: string);
var
  LStack: TStringList;
begin
  LStack := FStacks[ADirection];
  if LStack.Count = 0 then
    APath := ''
  else
  begin
    APath := LStack[LStack.Count - 1];
    LStack.Delete(LStack.Count - 1);
  end;
end;

procedure TPathHistory.AddVisit(const APath: string);
begin
  Push(hdBack, APath);
  FStacks[hdForward].Clear;
end;

end.
