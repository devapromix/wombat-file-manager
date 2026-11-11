unit WombatFM.MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, Menus, WombatFM.FilePanel,
  WombatFM.Options;

type
  TMainForm = class(TForm)
    BottomSplitter: TSplitter;
    FilePanel1: TFilePanelFrame;
    FilePanel2: TFilePanelFrame;
    FilePanel3: TFilePanelFrame;
    FilePanel4: TFilePanelFrame;
    PanelSplitter: TSplitter;
    pnlBottom: TPanel;
    pnlTop: TPanel;
    RowSplitter: TSplitter;
    MainMenu: TMainMenu;
    miFile: TMenuItem;
    miRefresh: TMenuItem;
    miExit: TMenuItem;
    miOptions: TMenuItem;
    miSettings: TMenuItem;
    tbBack: TToolButton;
    tbForward: TToolButton;
    tbHome: TToolButton;
    tbDownloads: TToolButton;
    tbRefresh: TToolButton;
    tbUp: TToolButton;
    tlbMain: TToolBar;
    ToolbarImages: TImageList;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PanelSplitterCanResize(Sender: TObject; var NewSize: Integer;
      var Accept: Boolean);
    procedure PanelSplitterMoved(Sender: TObject);
    procedure RowSplitterCanResize(Sender: TObject; var NewSize: Integer;
      var Accept: Boolean);
    procedure RowSplitterMoved(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure miSettingsClick(Sender: TObject);
    procedure tbBackClick(Sender: TObject);
    procedure tbForwardClick(Sender: TObject);
    procedure tbHomeClick(Sender: TObject);
    procedure tbDownloadsClick(Sender: TObject);
    procedure tbRefreshClick(Sender: TObject);
    procedure tbUpClick(Sender: TObject);
  private
    FActivePanel: TFilePanelFrame;
    FLayoutClientHeight: Integer;
    FLayoutClientWidth: Integer;
    FPanels: array[0..CPanelCount - 1] of TFilePanelFrame;
    FPendingLeftPanelWidth: Integer;
    FPendingTopPanelHeight: Integer;
    FLeftPanelRatio: Double;
    FTopPanelRatio: Double;
    FOptions: TAppOptions;
    procedure ApplyOptions;
    procedure ApplyPanelRatios;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    function GetBodyHeight: Integer;
    function GetClampedLeftWidth(AWidth: Integer): Integer;
    function GetClampedTopHeight(AHeight: Integer): Integer;
    function GetPanelIndex(APanel: TFilePanelFrame): Integer;
    function GetPathLists: TPathLists;
    procedure PanelActivate(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

uses
  Dialogs, LCLType, Math, WombatFM.Settings;

{$R *.lfm}

const
  CMinPanelHeight = 120;

function GetAvailableSize(ATotal, ASplitterSize: Integer): Integer;
begin
  Result := Max(0, ATotal - ASplitterSize);
end;

function GetClampedSize(AValue, ATotal, ASplitterSize, AMinSize: Integer): Integer;
var
  LAvailable, LMin: Integer;
begin
  LAvailable := GetAvailableSize(ATotal, ASplitterSize);
  LMin := Min(AMinSize, LAvailable div 2);
  Result := EnsureRange(AValue, LMin, LAvailable - LMin);
end;

function GetSplitRatio(ASize, ATotal, ASplitterSize: Integer;
  ADefault: Double): Double;
var
  LAvailable: Integer;
begin
  LAvailable := GetAvailableSize(ATotal, ASplitterSize);
  if (ASize > 0) and (LAvailable > 0) then
    Result := Min(ASize, LAvailable) / LAvailable
  else
    Result := ADefault;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  LPaths: array[0..CPanelCount - 1] of string;
  LIndex: Integer;
  LLayout: TWindowLayout;
begin
  FLeftPanelRatio := 0.5;
  FTopPanelRatio := 0.5;
  FPanels[0] := FilePanel1;
  FPanels[1] := FilePanel2;
  FPanels[2] := FilePanel3;
  FPanels[3] := FilePanel4;
  for LIndex := 0 to CPanelCount - 1 do
  begin
    FPanels[LIndex].OnActivate := @PanelActivate;
    FPanels[LIndex].GoHome;
    LPaths[LIndex] := FPanels[LIndex].cbPath.Text;
  end;
  try
    LoadSettings(GetPathLists, LLayout, FOptions);
    ApplyOptions;
    if (LLayout.Width > 0) and (LLayout.Height > 0) then
      SetBounds(Left, Top, Min(LLayout.Width, Screen.WorkAreaWidth),
        Min(LLayout.Height, Screen.WorkAreaHeight));
    FPendingLeftPanelWidth := LLayout.LeftPanelWidth;
    FPendingTopPanelHeight := LLayout.TopPanelHeight;
  except
    on E: Exception do
      ShowMessage('Could not load settings: ' + E.Message);
  end;
  for LIndex := 0 to CPanelCount - 1 do
    FPanels[LIndex].cbPath.Text := LPaths[LIndex];
  OnClose := @FormClose;
  PanelActivate(FilePanel1);
  ActiveControl := FilePanel1.lvFiles;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  LStep: Integer;
begin
  if (Key <> VK_TAB) or ((Shift - [ssShift]) <> []) then
    Exit;

  Key := VK_UNKNOWN;
  LStep := IfThen(ssShift in Shift, CPanelCount - 1, 1);
  FPanels[(GetPanelIndex(FActivePanel) + LStep) mod CPanelCount].lvFiles.SetFocus;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if Assigned(FilePanel4) and
    ((ClientWidth <> FLayoutClientWidth) or
    (ClientHeight <> FLayoutClientHeight)) then
  begin
    FLayoutClientWidth := ClientWidth;
    FLayoutClientHeight := ClientHeight;
    if (FLeftPanelRatio > 0) and (FTopPanelRatio > 0) then
      ApplyPanelRatios;
  end;
end;

function TMainForm.GetBodyHeight: Integer;
begin
  Result := ClientHeight - tlbMain.Height;
end;

function TMainForm.GetClampedLeftWidth(AWidth: Integer): Integer;
begin
  Result := GetClampedSize(AWidth, ClientWidth, PanelSplitter.Width,
    Ceil(ClientWidth / 10));
end;

function TMainForm.GetClampedTopHeight(AHeight: Integer): Integer;
begin
  Result := GetClampedSize(AHeight, GetBodyHeight, RowSplitter.Height,
    CMinPanelHeight);
end;

procedure TMainForm.ApplyPanelRatios;
var
  LLeftWidth: Integer;
begin
  LLeftWidth := GetClampedLeftWidth(Round(
    GetAvailableSize(ClientWidth, PanelSplitter.Width) * FLeftPanelRatio));
  FilePanel1.Width := LLeftWidth;
  FilePanel3.Width := LLeftWidth;
  pnlTop.Height := GetClampedTopHeight(Round(
    GetAvailableSize(GetBodyHeight, RowSplitter.Height) * FTopPanelRatio));
end;

procedure TMainForm.PanelSplitterCanResize(Sender: TObject; var NewSize: Integer;
  var Accept: Boolean);
begin
  NewSize := GetClampedLeftWidth(NewSize);
end;

procedure TMainForm.RowSplitterCanResize(Sender: TObject; var NewSize: Integer;
  var Accept: Boolean);
begin
  NewSize := GetClampedTopHeight(NewSize);
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  FLeftPanelRatio := GetSplitRatio(FPendingLeftPanelWidth, ClientWidth,
    PanelSplitter.Width, FLeftPanelRatio);
  FTopPanelRatio := GetSplitRatio(FPendingTopPanelHeight, GetBodyHeight,
    RowSplitter.Height, FTopPanelRatio);
  FPendingLeftPanelWidth := 0;
  FPendingTopPanelHeight := 0;
  OnShow := nil;
  FLayoutClientWidth := ClientWidth;
  FLayoutClientHeight := ClientHeight;
  ApplyPanelRatios;
end;

procedure TMainForm.PanelSplitterMoved(Sender: TObject);
var
  LLeftWidth: Integer;
begin
  LLeftWidth := (Sender as TSplitter).Left;
  FLeftPanelRatio := GetSplitRatio(LLeftWidth, ClientWidth, PanelSplitter.Width,
    FLeftPanelRatio);
  FilePanel1.Width := LLeftWidth;
  FilePanel3.Width := LLeftWidth;
end;

procedure TMainForm.RowSplitterMoved(Sender: TObject);
begin
  FTopPanelRatio := GetSplitRatio(pnlTop.Height, GetBodyHeight,
    RowSplitter.Height, FTopPanelRatio);
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  LLayout: TWindowLayout;
begin
  LLayout.Width := Width;
  LLayout.Height := Height;
  LLayout.LeftPanelWidth := FilePanel1.Width;
  LLayout.TopPanelHeight := pnlTop.Height;
  try
    SaveSettings(GetPathLists, LLayout, FOptions);
  except
    on E: Exception do
      ShowMessage('Could not save settings: ' + E.Message);
  end;
end;

function TMainForm.GetPanelIndex(APanel: TFilePanelFrame): Integer;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to CPanelCount - 1 do
    if FPanels[LIndex] = APanel then
      Result := LIndex;
end;

function TMainForm.GetPathLists: TPathLists;
var
  LIndex: Integer;
begin
  for LIndex := 0 to CPanelCount - 1 do
    Result[LIndex] := FPanels[LIndex].cbPath.Items;
end;

procedure TMainForm.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.ApplyOptions;
var
  LIndex: Integer;
begin
  for LIndex := 0 to CPanelCount - 1 do
    FPanels[LIndex].ApplyOptions(FOptions);
end;

procedure TMainForm.miSettingsClick(Sender: TObject);
var
  LForm: TSettingsForm;
begin
  LForm := TSettingsForm.Create(Self);
  try
    LForm.Options := FOptions;
    if LForm.ShowModal = mrOk then
    begin
      FOptions := LForm.Options;
      ApplyOptions;
    end;
  finally
    LForm.Free;
  end;
end;

procedure TMainForm.PanelActivate(Sender: TObject);
begin
  if Assigned(FActivePanel) then
    FActivePanel.SetActive(False);
  FActivePanel := Sender as TFilePanelFrame;
  FActivePanel.SetActive(True);
end;

procedure TMainForm.tbBackClick(Sender: TObject);
begin
  FActivePanel.GoBack;
end;

procedure TMainForm.tbForwardClick(Sender: TObject);
begin
  FActivePanel.GoForward;
end;

procedure TMainForm.tbUpClick(Sender: TObject);
begin
  FActivePanel.GoUp;
end;

procedure TMainForm.tbHomeClick(Sender: TObject);
begin
  FActivePanel.GoHome;
end;

procedure TMainForm.tbDownloadsClick(Sender: TObject);
var
  LDownloadsPath: string;
begin
  LDownloadsPath := IncludeTrailingPathDelimiter(GetUserDir) + 'Downloads';
  if DirectoryExists(LDownloadsPath) then
    FActivePanel.NavigateTo(LDownloadsPath);
end;

procedure TMainForm.tbRefreshClick(Sender: TObject);
begin
  FActivePanel.Reload;
end;

end.
