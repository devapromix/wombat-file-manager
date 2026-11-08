unit WombatFM.Icons;

{$mode objfpc}{$H+}

interface

uses
  Controls;

function GetIconIndex(const AName: string; AIsFolder: Boolean): Integer;
function GetIconList: TImageList;
function GetParentIconIndex: Integer;

implementation

uses
  Classes, SysUtils, Types{$IFDEF WINDOWS}, Windows, ShellApi{$ENDIF}, Graphics;

const
  CIconSize = 16;
  CFolderKey = '[dir]';
  CArrowPoints: array[0..6] of TPoint = (
    (X: 8; Y: 1), (X: 14; Y: 8), (X: 10; Y: 8), (X: 10; Y: 14),
    (X: 6; Y: 14), (X: 6; Y: 8), (X: 2; Y: 8));

var
  GIconList: TImageList = nil;
  GIconCache: TStringList = nil;
  GParentIndex: Integer = -1;

function GetIconList: TImageList;
begin
  if GIconList = nil then
  begin
    GIconList := TImageList.Create(nil);
    GIconList.Width := CIconSize;
    GIconList.Height := CIconSize;
  end;
  Result := GIconList;
end;

{$IFDEF WINDOWS}
function AddSystemIcon(const AName: string; AIsFolder: Boolean): Integer;
var
  LInfo: TSHFileInfoW;
  LIcon: TIcon;
  LAttr: DWORD;
begin
  Result := -1;
  if AIsFolder then
    LAttr := FILE_ATTRIBUTE_DIRECTORY
  else
    LAttr := FILE_ATTRIBUTE_NORMAL;
  LInfo := Default(TSHFileInfoW);
  if SHGetFileInfoW(PWideChar(UTF8Decode(AName)), LAttr, LInfo, SizeOf(LInfo),
    SHGFI_ICON or SHGFI_SMALLICON or SHGFI_USEFILEATTRIBUTES) = 0 then
    Exit;
  LIcon := TIcon.Create;
  try
    LIcon.Handle := LInfo.hIcon;
    Result := GetIconList.AddIcon(LIcon);
  finally
    LIcon.Free;
  end;
end;
{$ELSE}
function AddSystemIcon(const AName: string; AIsFolder: Boolean): Integer;
begin
  Result := -1;
end;
{$ENDIF}

function GetIconIndex(const AName: string; AIsFolder: Boolean): Integer;
var
  LKey: string;
  LName: string;
  LPosition: Integer;
begin
  if AIsFolder then
  begin
    LKey := CFolderKey;
    LName := 'folder';
  end
  else
  begin
    LKey := LowerCase(ExtractFileExt(AName));
    LName := 'file' + LKey;
  end;
  LPosition := GIconCache.IndexOf(LKey);
  if LPosition < 0 then
    LPosition := GIconCache.AddObject(LKey,
      TObject(PtrInt(AddSystemIcon(LName, AIsFolder))));
  Result := PtrInt(GIconCache.Objects[LPosition]);
end;

function GetParentIconIndex: Integer;
var
  LBitmap: TBitmap;
begin
  if GParentIndex < 0 then
  begin
    LBitmap := TBitmap.Create;
    try
      LBitmap.SetSize(CIconSize, CIconSize);
      LBitmap.Canvas.Brush.Color := clFuchsia;
      LBitmap.Canvas.FillRect(0, 0, CIconSize, CIconSize);
      LBitmap.Canvas.Brush.Color := clGray;
      LBitmap.Canvas.Pen.Color := clGray;
      LBitmap.Canvas.Polygon(CArrowPoints);
      GParentIndex := GetIconList.AddMasked(LBitmap, clFuchsia);
    finally
      LBitmap.Free;
    end;
  end;
  Result := GParentIndex;
end;

initialization
  GIconCache := TStringList.Create;
  GIconCache.CaseSensitive := True;
  GIconCache.Sorted := True;

finalization
  GIconCache.Free;
  GIconList.Free;

end.
