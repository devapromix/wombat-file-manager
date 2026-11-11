unit WombatFM.Options;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  CPanelCount = 4;

type
  TPathLists = array[0..CPanelCount - 1] of TStrings;

  TWindowLayout = record
    Width: Integer;
    Height: Integer;
    LeftPanelWidth: Integer;
    BottomLeftPanelWidth: Integer;
    TopPanelHeight: Integer;
  end;

  TAppOptions = record
    OptionMaxPathHistory: Integer;
    OptionShowHidden: Boolean;
    OptionSyncSplitters: Boolean;
  end;

function GetDefaultOptions: TAppOptions;
procedure LoadSettings(const APaths: TPathLists; AFolderNames: TStrings;
  out ALayout: TWindowLayout; out AOptions: TAppOptions);
procedure SaveSettings(const APaths: TPathLists; AFolderNames: TStrings;
  const ALayout: TWindowLayout; const AOptions: TAppOptions);

implementation

uses
  fpjson, jsonparser, Math, LazFileUtils, LazUTF8{$IFDEF WINDOWS}, Windows{$ENDIF},
  WombatFM.History;

const
  CDefaultMaxPathHistory = 20;
  CRecentPathsKeys: array[0..CPanelCount - 1] of string = ('topLeftRecentPaths',
    'topRightRecentPaths', 'bottomLeftRecentPaths', 'bottomRightRecentPaths');
  CFolderNamesKey = 'folderNameHistory';
  CWindowLayoutKey = 'windowLayout';
  COptionsKey = 'options';

function GetDefaultOptions: TAppOptions;
begin
  Result := Default(TAppOptions);
  Result.OptionMaxPathHistory := CDefaultMaxPathHistory;
  Result.OptionSyncSplitters := True;
end;

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

procedure LoadOptions(ASettings: TJSONObject; out AOptions: TAppOptions);
var
  LOptions: TJSONObject;
begin
  AOptions := GetDefaultOptions;
  if ASettings.Find(COptionsKey, LOptions) then
  begin
    AOptions.OptionMaxPathHistory :=
      Max(1, LOptions.Get('maxPathHistory', AOptions.OptionMaxPathHistory));
    AOptions.OptionShowHidden :=
      LOptions.Get('showHidden', AOptions.OptionShowHidden);
    AOptions.OptionSyncSplitters :=
      LOptions.Get('syncSplitters', AOptions.OptionSyncSplitters);
  end;
end;

procedure LoadSettings(const APaths: TPathLists; AFolderNames: TStrings;
  out ALayout: TWindowLayout; out AOptions: TAppOptions);
var
  LSettings, LLayout: TJSONObject;
  LIndex: Integer;
begin
  ALayout := Default(TWindowLayout);
  LSettings := ReadSettings(SettingsFileName);
  try
    LoadOptions(LSettings, AOptions);
    for LIndex := 0 to CPanelCount - 1 do
      LoadPathList(LSettings, CRecentPathsKeys[LIndex], APaths[LIndex],
        AOptions.OptionMaxPathHistory);
    LoadPathList(LSettings, CFolderNamesKey, AFolderNames,
      AOptions.OptionMaxPathHistory);
    if LSettings.Find(CWindowLayoutKey, LLayout) then
    begin
      ALayout.Width := LLayout.Get('width', 0);
      ALayout.Height := LLayout.Get('height', 0);
      ALayout.LeftPanelWidth := LLayout.Get('topLeftPanelWidth', 0);
      ALayout.BottomLeftPanelWidth := LLayout.Get('bottomLeftPanelWidth', 0);
      ALayout.TopPanelHeight := LLayout.Get('topPanelHeight', 0);
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

procedure SaveOptions(ASettings: TJSONObject; const AOptions: TAppOptions);
var
  LOptions: TJSONObject;
begin
  LOptions := GetSettingsSection(ASettings, COptionsKey);
  LOptions.Integers['maxPathHistory'] := AOptions.OptionMaxPathHistory;
  LOptions.Booleans['showHidden'] := AOptions.OptionShowHidden;
  LOptions.Booleans['syncSplitters'] := AOptions.OptionSyncSplitters;
end;

procedure SaveSettings(const APaths: TPathLists; AFolderNames: TStrings;
  const ALayout: TWindowLayout; const AOptions: TAppOptions);
var
  LFileName, LTempName: string;
  LIndex: Integer;
  LId: TGUID;
  LSettings, LLayout: TJSONObject;
  LText: UTF8String;
  LHandle: THandle;
  LStream: THandleStream;
begin
  LFileName := SettingsFileName;
  LSettings := ReadSettings(LFileName);
  try
    for LIndex := 0 to CPanelCount - 1 do
      SavePathList(LSettings, CRecentPathsKeys[LIndex], APaths[LIndex]);
    SavePathList(LSettings, CFolderNamesKey, AFolderNames);
    LLayout := GetSettingsSection(LSettings, CWindowLayoutKey);
    LLayout.Integers['width'] := ALayout.Width;
    LLayout.Integers['height'] := ALayout.Height;
    LLayout.Integers['topLeftPanelWidth'] := ALayout.LeftPanelWidth;
    LLayout.Integers['bottomLeftPanelWidth'] := ALayout.BottomLeftPanelWidth;
    LLayout.Integers['topPanelHeight'] := ALayout.TopPanelHeight;
    SaveOptions(LSettings, AOptions);
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

end.
