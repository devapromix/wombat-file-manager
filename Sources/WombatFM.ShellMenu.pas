unit WombatFM.ShellMenu;

{$mode objfpc}{$H+}

interface

uses
  Classes;

procedure OpenShellItem(AOwner: THandle; const AFolder, AName: string;
  out AOpened: Boolean);
procedure ShowShellContextMenu(AOwner: THandle; const AFolder: string;
  ANames: TStrings; const AScreenPoint: TPoint);

implementation

uses
  Windows, ActiveX, LazUTF8;

type
  TInvokeCommandInfo = record
    Size: DWORD;
    Mask: DWORD;
    Owner: HWND;
    Verb: PAnsiChar;
    Parameters: PAnsiChar;
    Directory: PAnsiChar;
    ShowMode: Integer;
    HotKey: DWORD;
    Icon: THandle;
  end;

  IShellFolder = interface(IUnknown)
    ['{000214E6-0000-0000-C000-000000000046}']
    function ParseDisplayName(AOwner: HWND; ABindContext: Pointer;
      ADisplayName: PWideChar; out AEaten: ULONG; out APidl: Pointer;
      var AAttributes: ULONG): HRESULT; stdcall;
    function EnumObjects(AOwner: HWND; AFlags: DWORD;
      out AEnum: Pointer): HRESULT; stdcall;
    function BindToObject(APidl: Pointer; ABindContext: Pointer;
      const AIid: TGUID; out AObject): HRESULT; stdcall;
    function BindToStorage(APidl: Pointer; ABindContext: Pointer;
      const AIid: TGUID; out AObject): HRESULT; stdcall;
    function CompareIDs(AParam: LPARAM; APidl1, APidl2: Pointer): HRESULT; stdcall;
    function CreateViewObject(AOwner: HWND; const AIid: TGUID;
      out AObject): HRESULT; stdcall;
    function GetAttributesOf(ACount: UINT; APidls: PPointer;
      var AAttributes: ULONG): HRESULT; stdcall;
    function GetUIObjectOf(AOwner: HWND; ACount: UINT; APidls: PPointer;
      const AIid: TGUID; AReserved: Pointer; out AObject): HRESULT; stdcall;
    function GetDisplayNameOf(APidl: Pointer; AFlags: DWORD;
      AName: Pointer): HRESULT; stdcall;
    function SetNameOf(AOwner: HWND; APidl: Pointer; AName: PWideChar;
      AFlags: DWORD; out ANewPidl: Pointer): HRESULT; stdcall;
  end;

  IContextMenu = interface(IUnknown)
    ['{000214E4-0000-0000-C000-000000000046}']
    function QueryContextMenu(AMenu: HMENU; AIndex, AFirstCommand,
      ALastCommand, AFlags: UINT): HRESULT; stdcall;
    function InvokeCommand(var AInfo: TInvokeCommandInfo): HRESULT; stdcall;
    function GetCommandString(ACommand: UINT_PTR; AType: UINT;
      AReserved: Pointer; AName: PAnsiChar; ASize: UINT): HRESULT; stdcall;
  end;

  IContextMenu2 = interface(IContextMenu)
    ['{000214F4-0000-0000-C000-000000000046}']
    function HandleMenuMsg(AMessage: UINT; AWParam: WPARAM;
      ALParam: LPARAM): HRESULT; stdcall;
  end;

  IContextMenu3 = interface(IContextMenu2)
    ['{BCFCE0A0-EC17-11D0-8D10-00A0C90F2719}']
    function HandleMenuMsg2(AMessage: UINT; AWParam: WPARAM; ALParam: LPARAM;
      AResult: Pointer): HRESULT; stdcall;
  end;

const
  CWindowClassName = 'WombatFMShellMenuWindow';
  CFirstCommand = 1;
  CLastCommand = $7FFF;
  CFlagNormal = 0;
  CFlagExtendedVerbs = $100;
  CShellExecuteMinSuccess = 32;

var
  GContextMenu2: IContextMenu2;
  GContextMenu3: IContextMenu3;

function SHParseDisplayName(AName: PWideChar; ABindContext: Pointer;
  out APidl: Pointer; AAttributesIn: ULONG;
  out AAttributesOut: ULONG): HRESULT; stdcall;
  external 'shell32.dll' name 'SHParseDisplayName';

function ShellExecuteW(AOwner: HWND; AOperation, AFile, AParameters,
  ADirectory: PWideChar; AShowMode: Integer): HINST; stdcall;
  external 'shell32.dll' name 'ShellExecuteW';

function SHBindToParent(APidl: Pointer; const AIid: TGUID; out AObject;
  AChild: PPointer): HRESULT; stdcall;
  external 'shell32.dll' name 'SHBindToParent';

function ShellMenuWindowProc(AWindow: HWND; AMessage: UINT; AWParam: WPARAM;
  ALParam: LPARAM): LRESULT; stdcall;
begin
  case AMessage of
    WM_INITMENUPOPUP, WM_DRAWITEM, WM_MEASUREITEM, WM_MENUCHAR:
    begin
      Result := 0;
      if Assigned(GContextMenu3) then
        GContextMenu3.HandleMenuMsg2(AMessage, AWParam, ALParam, @Result)
      else if Assigned(GContextMenu2) then
        GContextMenu2.HandleMenuMsg(AMessage, AWParam, ALParam);
      if (AMessage = WM_DRAWITEM) or (AMessage = WM_MEASUREITEM) then
        Result := 1;
    end;
  else
    Result := DefWindowProc(AWindow, AMessage, AWParam, ALParam);
  end;
end;

function GetPidl(const APath: string): Pointer;
var
  LAttributes: ULONG;
begin
  if SHParseDisplayName(PWideChar(UTF8ToUTF16(APath)), nil, Result, 0,
    LAttributes) < 0 then
    Result := nil;
end;

function GetParentFolder(APidl: Pointer; out AChild: Pointer): IShellFolder;
begin
  Result := nil;
  if SHBindToParent(APidl, IShellFolder, Result, @AChild) < 0 then
    Result := nil;
end;

function GetContextMenu(AOwner: HWND; const AFolder: string;
  ANames: TStrings): IContextMenu;
var
  LPaths: TStringList;
  LPidls: array of Pointer;
  LChildren: array of Pointer;
  LParent: IShellFolder;
  LCurrent: IShellFolder;
  LFolder: IShellFolder;
  LIndex: integer;
  LCount: integer;
  LPidl: Pointer;
  LChild: Pointer;
begin
  Result := nil;
  LPaths := TStringList.Create;
  try
    if ANames.Count = 0 then
      LPaths.Add(AFolder)
    else
      for LIndex := 0 to ANames.Count - 1 do
        LPaths.Add(AFolder + ANames[LIndex]);
    SetLength(LPidls, LPaths.Count);
    SetLength(LChildren, LPaths.Count);
    LCount := 0;
    for LIndex := 0 to LPaths.Count - 1 do
    begin
      LPidl := GetPidl(LPaths[LIndex]);
      if LPidl = nil then
        Continue;
      LCurrent := GetParentFolder(LPidl, LChild);
      if LCurrent = nil then
        CoTaskMemFree(LPidl)
      else
      begin
        LParent := LCurrent;
        LPidls[LCount] := LPidl;
        LChildren[LCount] := LChild;
        Inc(LCount);
      end;
    end;
    if LCount > 0 then
    begin
      if ANames.Count = 0 then
      begin
        if LParent.BindToObject(LChildren[0], nil, IShellFolder, LFolder) >= 0 then
          LFolder.CreateViewObject(AOwner, IContextMenu, Result);
      end
      else
        LParent.GetUIObjectOf(AOwner, LCount, @LChildren[0], IContextMenu,
          nil, Result);
    end;
    for LIndex := 0 to LCount - 1 do
      CoTaskMemFree(LPidls[LIndex]);
  finally
    LPaths.Free;
  end;
end;

procedure TrackContextMenu(AOwner: HWND; const AFolder: string;
  ANames: TStrings; const AScreenPoint: TPoint);
var
  LContextMenu: IContextMenu;
  LWindow: HWND;
  LPopup: HMENU;
  LFlags: UINT;
  LCommand: integer;
  LInfo: TInvokeCommandInfo;
begin
  LContextMenu := GetContextMenu(AOwner, AFolder, ANames);
  if LContextMenu = nil then
    Exit;
  LWindow := CreateWindowEx(0, PChar(CWindowClassName), nil, WS_POPUP, 0, 0,
    0, 0, 0, 0, HInstance, nil);
  LPopup := CreatePopupMenu;
  try
    LFlags := CFlagNormal;
    if GetKeyState(VK_SHIFT) < 0 then
      LFlags := LFlags or CFlagExtendedVerbs;
    if LContextMenu.QueryContextMenu(LPopup, 0, CFirstCommand, CLastCommand,
      LFlags) < 0 then
      Exit;
    LContextMenu.QueryInterface(IContextMenu2, GContextMenu2);
    LContextMenu.QueryInterface(IContextMenu3, GContextMenu3);
    SetForegroundWindow(LWindow);
    LCommand := Integer(TrackPopupMenu(LPopup, TPM_RETURNCMD or TPM_RIGHTBUTTON,
      AScreenPoint.X, AScreenPoint.Y, 0, LWindow, nil));
    PostMessage(LWindow, WM_NULL, 0, 0);
    if LCommand >= CFirstCommand then
    begin
      FillChar(LInfo, SizeOf(LInfo), 0);
      LInfo.Size := SizeOf(LInfo);
      LInfo.Owner := AOwner;
      LInfo.Verb := PAnsiChar(PtrUInt(LCommand - CFirstCommand));
      LInfo.ShowMode := SW_SHOWNORMAL;
      LContextMenu.InvokeCommand(LInfo);
    end;
  finally
    GContextMenu3 := nil;
    GContextMenu2 := nil;
    DestroyMenu(LPopup);
    DestroyWindow(LWindow);
  end;
end;

procedure OpenShellItem(AOwner: THandle; const AFolder, AName: string;
  out AOpened: Boolean);
begin
  AOpened := ShellExecuteW(HWND(AOwner), nil,
    PWideChar(UTF8ToUTF16(AFolder + AName)), nil,
    PWideChar(UTF8ToUTF16(AFolder)), SW_SHOWNORMAL) > CShellExecuteMinSuccess;
end;

procedure ShowShellContextMenu(AOwner: THandle; const AFolder: string;
  ANames: TStrings; const AScreenPoint: TPoint);
var
  LComResult: HRESULT;
begin
  LComResult := CoInitialize(nil);
  try
    TrackContextMenu(HWND(AOwner), AFolder, ANames, AScreenPoint);
  finally
    if LComResult >= 0 then
      CoUninitialize;
  end;
end;

procedure RegisterWindowClass;
var
  LClass: TWndClass;
begin
  FillChar(LClass, SizeOf(LClass), 0);
  LClass.lpfnWndProc := @ShellMenuWindowProc;
  LClass.hInstance := HInstance;
  LClass.lpszClassName := PChar(CWindowClassName);
  Windows.RegisterClass(LClass);
end;

initialization
  RegisterWindowClass;

finalization
  Windows.UnregisterClass(PChar(CWindowClassName), HInstance);

end.
