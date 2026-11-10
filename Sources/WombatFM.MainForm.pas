unit WombatFM.MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, Menus, WombatFM.FilePanel,
  WombatFM.History, WombatFM.Options;

type
  TMainForm = class(TForm)
    FilePanel1: TFilePanelFrame;
    PanelSplitter: TSplitter;
    FilePanel2: TFilePanelFrame;
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
    FLayoutClientWidth: Integer;
    FPendingLeftPanelWidth: Integer;
    FLeftPanelRatio: Double;
    FOptions: TAppOptions;
    procedure ApplyOptions;
    procedure ApplyPanelRatio;
    function ClampLeftPanelWidth(AWidth: Integer): Integer;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure PanelActivate(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

uses
  Dialogs, LCLType, Math, WombatFM.Settings;

{$R *.lfm}

procedure TMainForm.FormCreate(Sender: TObject);
var
  LLeftPath, LRightPath: string;
  LLayout: TWindowLayout;
begin
  FLeftPanelRatio := 0.5;
  FilePanel1.OnActivate := @PanelActivate;
  FilePanel2.OnActivate := @PanelActivate;
  FilePanel1.GoHome;
  FilePanel2.GoHome;
  LLeftPath := FilePanel1.cbPath.Text;
  LRightPath := FilePanel2.cbPath.Text;
  try
    LoadSettings(FilePanel1.cbPath.Items, FilePanel2.cbPath.Items, LLayout, FOptions);
    ApplyOptions;
    if (LLayout.Width > 0) and (LLayout.Height > 0) then
      SetBounds(Left, Top, Min(LLayout.Width, Screen.WorkAreaWidth),
        Min(LLayout.Height, Screen.WorkAreaHeight));
    FPendingLeftPanelWidth := LLayout.LeftPanelWidth;
  except
    on E: Exception do
      ShowMessage('Could not load settings: ' + E.Message);
  end;
  FilePanel1.cbPath.Text := LLeftPath;
  FilePanel2.cbPath.Text := LRightPath;
  OnClose := @FormClose;
  PanelActivate(FilePanel1);
  ActiveControl := FilePanel1.lvFiles;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key <> VK_TAB) or ((Shift - [ssShift]) <> []) then
    Exit;

  Key := VK_UNKNOWN;
  if FActivePanel = FilePanel1 then
    FilePanel2.lvFiles.SetFocus
  else
    FilePanel1.lvFiles.SetFocus;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if Assigned(FilePanel1) and Assigned(PanelSplitter) and
    (ClientWidth <> FLayoutClientWidth) then
  begin
    FLayoutClientWidth := ClientWidth;
    if FLeftPanelRatio > 0 then
      ApplyPanelRatio;
  end;
end;

function TMainForm.ClampLeftPanelWidth(AWidth: Integer): Integer;
var
  LAvailableWidth, LMinPanelWidth: Integer;
begin
  LAvailableWidth := Max(0, ClientWidth - PanelSplitter.Width);
  LMinPanelWidth := Min(Ceil(ClientWidth / 10), LAvailableWidth div 2);
  Result := EnsureRange(AWidth, LMinPanelWidth, LAvailableWidth - LMinPanelWidth);
end;

procedure TMainForm.ApplyPanelRatio;
var
  LAvailableWidth: Integer;
begin
  LAvailableWidth := Max(0, ClientWidth - PanelSplitter.Width);
  FilePanel1.Width := ClampLeftPanelWidth(Round(LAvailableWidth * FLeftPanelRatio));
end;

procedure TMainForm.PanelSplitterCanResize(Sender: TObject; var NewSize: Integer;
  var Accept: Boolean);
begin
  NewSize := ClampLeftPanelWidth(NewSize);
end;

procedure TMainForm.FormShow(Sender: TObject);
var
  LAvailableWidth: Integer;
begin
  LAvailableWidth := ClientWidth - PanelSplitter.Width;
  if (FPendingLeftPanelWidth > 0) and (LAvailableWidth > 0) then
    FLeftPanelRatio := Min(FPendingLeftPanelWidth, LAvailableWidth) / LAvailableWidth;
  FPendingLeftPanelWidth := 0;
  OnShow := nil;
  FLayoutClientWidth := ClientWidth;
  ApplyPanelRatio;
end;

procedure TMainForm.PanelSplitterMoved(Sender: TObject);
var
  LAvailableWidth: Integer;
begin
  LAvailableWidth := ClientWidth - PanelSplitter.Width;
  if (LAvailableWidth > 0) and (FilePanel1.Width > 0) then
    FLeftPanelRatio := Min(FilePanel1.Width, LAvailableWidth) / LAvailableWidth;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  LLayout: TWindowLayout;
begin
  LLayout.Width := Width;
  LLayout.Height := Height;
  LLayout.LeftPanelWidth := FilePanel1.Width;
  try
    SaveSettings(FilePanel1.cbPath.Items, FilePanel2.cbPath.Items, LLayout, FOptions);
  except
    on E: Exception do
      ShowMessage('Could not save settings: ' + E.Message);
  end;
end;

procedure TMainForm.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.ApplyOptions;
begin
  FilePanel1.ApplyOptions(FOptions);
  FilePanel2.ApplyOptions(FOptions);
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
