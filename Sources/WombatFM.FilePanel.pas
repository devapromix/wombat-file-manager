unit WombatFM.FilePanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, Math, Graphics, Forms, Controls, StdCtrls,
  ExtCtrls, ComCtrls, Buttons, Dialogs, LCLType, LazUTF8, WombatFM.Drives, WombatFM.Icons;

type
  TFileEntry = class
  public
    Name: string;
    BaseName: string;
    Ext: string;
    IsFolder: boolean;
    Size: int64;
    Age: longint;
    constructor Create(const AName: string; AIsFolder: boolean;
      ASize: int64; AAge: longint);
  end;

  TFilePanelFrame = class(TFrame)
    btnBrowse: TButton;
    cbPath: TComboBox;
    dlgSelectDir: TSelectDirectoryDialog;
    lvFiles: TListView;
    pnlDrives: TPanel;
    pnlPath: TPanel;
    sbStatus: TStatusBar;
    procedure btnBrowseClick(Sender: TObject);
    procedure btnRootClick(Sender: TObject);
    procedure cbPathKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure cbPathSelect(Sender: TObject);
    procedure ControlActivated(Sender: TObject);
    procedure lvFilesColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvFilesDblClick(Sender: TObject);
    procedure lvFilesKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
  private
    FCurrentPath: string;
    FBackStack: TStringList;
    FForwardStack: TStringList;
    FEntries: TFPObjectList;
    FOnActivate: TNotifyEvent;
    FOptionShowHidden: boolean;
    FSortColumn: integer;
    FSortDescending: boolean;
    procedure AddToHistory;
    procedure CreateDriveButtons;
    procedure DriveButtonClick(Sender: TObject);
    procedure FillList;
    function GetCompareResult(AEntry1, AEntry2: TFileEntry): integer;
    function GetInsertIndex(AEntry: TFileEntry): integer;
    function GetParentPath: string;
    procedure InsertEntry(AEntry: TFileEntry);
    procedure LoadDirectory(const APath: string);
    procedure MoveHistory(ASource, ATarget: TStringList);
    procedure OpenSelected;
    procedure ReportFolderError(const APath: string);
    procedure SetOptionShowHidden(AValue: boolean);
    procedure UpdateDriveButtons;
    procedure UpdateSortIndicator;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure GoBack;
    procedure GoForward;
    procedure GoHome;
    procedure GoUp;
    procedure NavigateTo(const APath: string);
    procedure Reload;
    procedure SetActive(AValue: boolean);
    property CurrentPath: string read FCurrentPath;
    property OnActivate: TNotifyEvent read FOnActivate write FOnActivate;
    property OptionShowHidden: boolean read FOptionShowHidden write SetOptionShowHidden;
  end;

implementation

{$R *.lfm}

const
  CMaxPathHistory = 20;
  CDriveButtonWidth = 36;
  CParentName = '..';
  CColumnExt = 1;
  CColumnSize = 2;
  CColumnDate = 3;
  CDirText = '<DIR>';
  CDateFormat = 'dd.mm.yyyy hh:nn';
  CStatusFormat = '%d objects (%s)';

function GetSizeText(ASize: int64): string;
const
  CUnits: array[0..4] of string = ('B', 'KB', 'MB', 'GB', 'TB');
  CUnitStep = 1024;
  CMaxWholeUnit = 1;
var
  LValue: double;
  LUnit: integer;
begin
  LValue := ASize;
  LUnit := 0;
  while (LValue >= CUnitStep) and (LUnit < High(CUnits)) do
  begin
    LValue := LValue / CUnitStep;
    Inc(LUnit);
  end;
  if LUnit <= CMaxWholeUnit then
    Result := FormatFloat('#,##0', LValue)
  else
    Result := FormatFloat('#,##0.0', LValue);
  Result := Result + ' ' + CUnits[LUnit];
end;

function GetFolderAge(const APath: string): longint;
var
  LRec: TSearchRec;
begin
  Result := -1;
  if (APath = '') or (APath = ExtractFileDrive(APath)) then
    Exit;
  if FindFirst(APath, faDirectory, LRec) = 0 then
  begin
    Result := LRec.Time;
    FindClose(LRec);
  end;
end;

function GetIsDirectoryAccessible(const APath: string): boolean;
var
  LRec: TSearchRec;
begin
  Result := False;
  if not DirectoryExists(APath) then
    Exit;
  if FindFirst(APath + '*', faAnyFile, LRec) = 0 then
  begin
    FindClose(LRec);
    Result := True;
  end
  else
    Result := APath = ExtractFileDrive(APath) + PathDelim;
end;

function GetDateText(AFileAge: longint): string;
begin
  if AFileAge < 0 then
    Result := ''
  else
    Result := FormatDateTime(CDateFormat, FileDateToDateTime(AFileAge));
end;

constructor TFileEntry.Create(const AName: string; AIsFolder: boolean;
  ASize: int64; AAge: longint);
begin
  inherited Create;
  Name := AName;
  IsFolder := AIsFolder;
  Age := AAge;
  if AIsFolder then
    BaseName := AName
  else
  begin
    Size := ASize;
    Ext := ExtractFileExt(AName);
    if Length(Ext) = Length(AName) then
      Ext := '';
    BaseName := Copy(AName, 1, Length(AName) - Length(Ext));
    Delete(Ext, 1, 1);
  end;
end;

constructor TFilePanelFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBackStack := TStringList.Create;
  FForwardStack := TStringList.Create;
  FEntries := TFPObjectList.Create(True);
  lvFiles.SmallImages := GetIconList;
  CreateDriveButtons;
  UpdateSortIndicator;
end;

destructor TFilePanelFrame.Destroy;
begin
  FEntries.Free;
  FForwardStack.Free;
  FBackStack.Free;
  inherited Destroy;
end;

procedure TFilePanelFrame.CreateDriveButtons;
var
  LDrives: TStringList;
  LIndex: integer;
  LButton: TSpeedButton;
begin
  LDrives := TStringList.Create;
  try
    FillDrives(LDrives);
    for LIndex := 0 to LDrives.Count - 1 do
    begin
      LButton := TSpeedButton.Create(Self);
      LButton.Parent := pnlDrives;
      LButton.SetBounds(LIndex * CDriveButtonWidth, 0, CDriveButtonWidth,
        pnlDrives.ClientHeight);
      LButton.Flat := True;
      LButton.GroupIndex := 1;
      LButton.Caption := Copy(LDrives[LIndex], 1, 1);
      LButton.Hint := LDrives[LIndex];
      LButton.ShowHint := True;
      LButton.OnClick := @DriveButtonClick;
    end;
  finally
    LDrives.Free;
  end;
end;

procedure TFilePanelFrame.DriveButtonClick(Sender: TObject);
begin
  ControlActivated(Sender);
  NavigateTo((Sender as TSpeedButton).Hint);
end;

procedure TFilePanelFrame.UpdateDriveButtons;
var
  LIndex: integer;
  LControl: TControl;
begin
  for LIndex := 0 to pnlDrives.ControlCount - 1 do
  begin
    LControl := pnlDrives.Controls[LIndex];
    if (LControl is TSpeedButton) and SameText(ExtractFileDrive(LControl.Hint),
      ExtractFileDrive(FCurrentPath)) then
      TSpeedButton(LControl).Down := True;
  end;
end;

procedure TFilePanelFrame.AddToHistory;
var
  LIndex: integer;
begin
  LIndex := cbPath.Items.IndexOf(FCurrentPath);
  if LIndex >= 0 then
    cbPath.Items.Delete(LIndex);
  cbPath.Items.Insert(0, FCurrentPath);
  while cbPath.Items.Count > CMaxPathHistory do
    cbPath.Items.Delete(cbPath.Items.Count - 1);
  cbPath.Text := FCurrentPath;
end;

procedure TFilePanelFrame.UpdateSortIndicator;
var
  LIndex: integer;
begin
  for LIndex := 0 to lvFiles.Columns.Count - 1 do
    lvFiles.Columns[LIndex].SortIndicator := siNone;
  if FSortDescending then
    lvFiles.Columns[FSortColumn].SortIndicator := siDescending
  else
    lvFiles.Columns[FSortColumn].SortIndicator := siAscending;
end;

function TFilePanelFrame.GetCompareResult(AEntry1, AEntry2: TFileEntry): integer;
begin
  Result := Ord(AEntry2.Name = CParentName) - Ord(AEntry1.Name = CParentName);
  if Result <> 0 then
    Exit;
  Result := Ord(AEntry2.IsFolder) - Ord(AEntry1.IsFolder);
  if Result <> 0 then
    Exit;
  case FSortColumn of
    CColumnExt:
      Result := UTF8CompareText(AEntry1.Ext, AEntry2.Ext);
    CColumnSize:
      Result := CompareValue(AEntry1.Size, AEntry2.Size);
    CColumnDate:
      Result := CompareValue(AEntry1.Age, AEntry2.Age);
    else
      Result := UTF8CompareText(AEntry1.Name, AEntry2.Name);
  end;
  if FSortDescending then
    Result := -Result;
  if Result = 0 then
    Result := UTF8CompareText(AEntry1.Name, AEntry2.Name);
end;

function TFilePanelFrame.GetInsertIndex(AEntry: TFileEntry): integer;
var
  LLow: integer;
  LHigh: integer;
  LMiddle: integer;
begin
  LLow := 0;
  LHigh := FEntries.Count;
  while LLow < LHigh do
  begin
    LMiddle := (LLow + LHigh) div 2;
    if GetCompareResult(TFileEntry(FEntries[LMiddle]), AEntry) <= 0 then
      LLow := LMiddle + 1
    else
      LHigh := LMiddle;
  end;
  Result := LLow;
end;

procedure TFilePanelFrame.InsertEntry(AEntry: TFileEntry);
begin
  FEntries.Insert(GetInsertIndex(AEntry), AEntry);
end;

procedure TFilePanelFrame.FillList;
var
  LIndex: integer;
  LEntry: TFileEntry;
  LItem: TListItem;
  LCaption: string;
  LSizeText: string;
  LImageIndex: integer;
begin
  lvFiles.Items.BeginUpdate;
  try
    for LIndex := 0 to FEntries.Count - 1 do
    begin
      LEntry := TFileEntry(FEntries[LIndex]);
      if LEntry.IsFolder then
      begin
        LCaption := '[' + LEntry.BaseName + ']';
        LSizeText := CDirText;
      end
      else
      begin
        LCaption := LEntry.BaseName;
        LSizeText := GetSizeText(LEntry.Size);
      end;
      if LEntry.Name = CParentName then
        LImageIndex := GetParentIconIndex
      else
        LImageIndex := GetIconIndex(LEntry.Name, LEntry.IsFolder);
      LItem := lvFiles.Items.Add;
      LItem.Caption := LCaption;
      LItem.ImageIndex := LImageIndex;
      LItem.Data := LEntry;
      LItem.SubItems.Add(LEntry.Ext);
      LItem.SubItems.Add(LSizeText);
      LItem.SubItems.Add(GetDateText(LEntry.Age));
    end;
  finally
    lvFiles.Items.EndUpdate;
  end;
end;

function TFilePanelFrame.GetParentPath: string;
var
  LCurrent: string;
begin
  LCurrent := ExcludeTrailingPathDelimiter(FCurrentPath);
  Result := ExtractFilePath(LCurrent);
  if Result = LCurrent then
    Result := '';
end;

procedure TFilePanelFrame.LoadDirectory(const APath: string);
var
  LRec: TSearchRec;
  LIsFolder: boolean;
  LCount: integer;
  LTotalSize: int64;
begin
  FCurrentPath := APath;
  LCount := 0;
  LTotalSize := 0;
  lvFiles.Items.Clear;
  FEntries.Clear;
  if GetParentPath <> '' then
    InsertEntry(TFileEntry.Create(CParentName, True, 0,
      GetFolderAge(ExcludeTrailingPathDelimiter(GetParentPath))));
  if FindFirst(APath + '*', faAnyFile, LRec) = 0 then
  try
    repeat
      LIsFolder := (LRec.Attr and faDirectory) <> 0;
      if (LRec.Name <> '.') and (LRec.Name <> CParentName) and
        (FOptionShowHidden or ((LRec.Attr and (faHidden or faSysFile)) = 0)) then
      begin
        InsertEntry(TFileEntry.Create(LRec.Name, LIsFolder, LRec.Size,
          LRec.Time));
        Inc(LCount);
        if not LIsFolder then
          Inc(LTotalSize, LRec.Size);
      end;
    until FindNext(LRec) <> 0;
  finally
    FindClose(LRec);
  end;
  FillList;
  AddToHistory;
  UpdateDriveButtons;
  sbStatus.SimpleText := Format(CStatusFormat, [LCount, GetSizeText(LTotalSize)]);
end;

procedure TFilePanelFrame.ReportFolderError(const APath: string);
begin
  ShowMessage('Cannot open folder: ' + APath);
  cbPath.Text := FCurrentPath;
end;

procedure TFilePanelFrame.NavigateTo(const APath: string);
var
  LPath: string;
begin
  LPath := IncludeTrailingPathDelimiter(ExpandFileName(APath));
  if not GetIsDirectoryAccessible(LPath) then
  begin
    ReportFolderError(APath);
    Exit;
  end;
  if (FCurrentPath <> '') and (FCurrentPath <> LPath) then
  begin
    FBackStack.Add(FCurrentPath);
    FForwardStack.Clear;
  end;
  LoadDirectory(LPath);
end;

procedure TFilePanelFrame.MoveHistory(ASource, ATarget: TStringList);
var
  LPath: string;
begin
  if ASource.Count = 0 then
    Exit;
  LPath := ASource[ASource.Count - 1];
  ASource.Delete(ASource.Count - 1);
  if not GetIsDirectoryAccessible(LPath) then
  begin
    ReportFolderError(LPath);
    Exit;
  end;
  ATarget.Add(FCurrentPath);
  LoadDirectory(LPath);
end;

procedure TFilePanelFrame.GoBack;
begin
  MoveHistory(FBackStack, FForwardStack);
end;

procedure TFilePanelFrame.GoForward;
begin
  MoveHistory(FForwardStack, FBackStack);
end;

procedure TFilePanelFrame.GoUp;
var
  LParent: string;
begin
  LParent := GetParentPath;
  if LParent <> '' then
    NavigateTo(LParent);
end;

procedure TFilePanelFrame.GoHome;
begin
  NavigateTo(GetUserDir);
end;

procedure TFilePanelFrame.Reload;
begin
  LoadDirectory(FCurrentPath);
end;

procedure TFilePanelFrame.SetActive(AValue: boolean);
begin
  if AValue then
    pnlDrives.Color := clSkyBlue
  else
    pnlDrives.Color := clDefault;
end;

procedure TFilePanelFrame.OpenSelected;
var
  LEntry: TFileEntry;
begin
  if lvFiles.Selected = nil then
    Exit;
  LEntry := TFileEntry(lvFiles.Selected.Data);
  if LEntry.Name = CParentName then
    GoUp
  else if LEntry.IsFolder then
    NavigateTo(FCurrentPath + LEntry.Name);
end;

procedure TFilePanelFrame.SetOptionShowHidden(AValue: boolean);
begin
  if FOptionShowHidden = AValue then
    Exit;
  FOptionShowHidden := AValue;
  if FCurrentPath <> '' then
    Reload;
end;

procedure TFilePanelFrame.ControlActivated(Sender: TObject);
begin
  if Assigned(FOnActivate) then
    FOnActivate(Self);
end;

procedure TFilePanelFrame.btnBrowseClick(Sender: TObject);
begin
  dlgSelectDir.InitialDir := FCurrentPath;
  if dlgSelectDir.Execute then
    NavigateTo(dlgSelectDir.FileName);
end;

procedure TFilePanelFrame.btnRootClick(Sender: TObject);
begin
  NavigateTo(ExtractFileDrive(FCurrentPath) + PathDelim);
end;

procedure TFilePanelFrame.cbPathKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    NavigateTo(cbPath.Text);
  end;
end;

procedure TFilePanelFrame.cbPathSelect(Sender: TObject);
begin
  NavigateTo(cbPath.Text);
end;

procedure TFilePanelFrame.lvFilesColumnClick(Sender: TObject; Column: TListColumn);
begin
  if FSortColumn = Column.Index then
    FSortDescending := not FSortDescending
  else
  begin
    FSortColumn := Column.Index;
    FSortDescending := False;
  end;
  UpdateSortIndicator;
  Reload;
end;

procedure TFilePanelFrame.lvFilesDblClick(Sender: TObject);
begin
  OpenSelected;
end;

procedure TFilePanelFrame.lvFilesKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    OpenSelected;
  end;
end;

end.
