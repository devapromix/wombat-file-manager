unit WombatFM.MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, WombatFM.FilePanel;

type
  TMainForm = class(TForm)
    FilePanel1: TFilePanelFrame;
    tbBack: TToolButton;
    tbForward: TToolButton;
    tbHome: TToolButton;
    tbRefresh: TToolButton;
    tbUp: TToolButton;
    tlbMain: TToolBar;
    procedure FormCreate(Sender: TObject);
    procedure tbBackClick(Sender: TObject);
    procedure tbForwardClick(Sender: TObject);
    procedure tbHomeClick(Sender: TObject);
    procedure tbRefreshClick(Sender: TObject);
    procedure tbUpClick(Sender: TObject);
  private
    procedure PanelActivate(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FilePanel1.OnActivate := @PanelActivate;
  FilePanel1.GoHome;
end;

procedure TMainForm.PanelActivate(Sender: TObject);
begin
  (Sender as TFilePanelFrame).SetActive(True);
end;

procedure TMainForm.tbBackClick(Sender: TObject);
begin
  FilePanel1.GoBack;
end;

procedure TMainForm.tbForwardClick(Sender: TObject);
begin
  FilePanel1.GoForward;
end;

procedure TMainForm.tbUpClick(Sender: TObject);
begin
  FilePanel1.GoUp;
end;

procedure TMainForm.tbHomeClick(Sender: TObject);
begin
  FilePanel1.GoHome;
end;

procedure TMainForm.tbRefreshClick(Sender: TObject);
begin
  FilePanel1.Reload;
end;

end.
