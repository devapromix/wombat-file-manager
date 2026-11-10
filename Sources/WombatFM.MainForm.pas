unit WombatFM.MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, Menus, WombatFM.FilePanel;

type
  TMainForm = class(TForm)
    FilePanel1: TFilePanelFrame;
    PanelSplitter: TSplitter;
    FilePanel2: TFilePanelFrame;
    MainMenu: TMainMenu;
    miFile: TMenuItem;
    miRefresh: TMenuItem;
    miExit: TMenuItem;
    tbBack: TToolButton;
    tbForward: TToolButton;
    tbHome: TToolButton;
    tbDownloads: TToolButton;
    tbRefresh: TToolButton;
    tbUp: TToolButton;
    tlbMain: TToolBar;
    ToolbarImages: TImageList;
    procedure FormCreate(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure tbBackClick(Sender: TObject);
    procedure tbForwardClick(Sender: TObject);
    procedure tbHomeClick(Sender: TObject);
    procedure tbDownloadsClick(Sender: TObject);
    procedure tbRefreshClick(Sender: TObject);
    procedure tbUpClick(Sender: TObject);
  private
    FActivePanel: TFilePanelFrame;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure PanelActivate(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

uses
  Dialogs, WombatFM.History;

{$R *.lfm}

procedure TMainForm.FormCreate(Sender: TObject);
var
  LLeftPath, LRightPath: string;
begin
  FilePanel1.OnActivate := @PanelActivate;
  FilePanel2.OnActivate := @PanelActivate;
  FilePanel1.GoHome;
  FilePanel2.GoHome;
  LLeftPath := FilePanel1.cbPath.Text;
  LRightPath := FilePanel2.cbPath.Text;
  try
    LoadRecentPaths(FilePanel1.cbPath.Items, FilePanel2.cbPath.Items);
  except
    on E: Exception do
      ShowMessage('Could not load folder history: ' + E.Message);
  end;
  FilePanel1.cbPath.Text := LLeftPath;
  FilePanel2.cbPath.Text := LRightPath;
  OnClose := @FormClose;
  PanelActivate(FilePanel1);
  ActiveControl := FilePanel1.lvFiles;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  try
    SaveRecentPaths(FilePanel1.cbPath.Items, FilePanel2.cbPath.Items);
  except
    on E: Exception do
      ShowMessage('Could not save folder history: ' + E.Message);
  end;
end;

procedure TMainForm.miExitClick(Sender: TObject);
begin
  Close;
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
