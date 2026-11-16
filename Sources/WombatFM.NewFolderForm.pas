unit WombatFM.NewFolderForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ButtonPanel;

type
  TNewFolderForm = class(TForm)
    ButtonPanel: TButtonPanel;
    cbFolderName: TComboBox;
    lblFolderName: TLabel;
    procedure FolderNameChanged(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    function GetFolderName: string;
    procedure SetHistory(AValue: TStrings);
  public
    property FolderName: string read GetFolderName;
    property History: TStrings write SetHistory;
  end;

implementation

{$R *.lfm}

const
  CParentFolderName = '..';
  CCurrentFolderName = '.';
  {$IFDEF WINDOWS}
  CInvalidNameChars = ['\', '/', ':', '*', '?', '"', '<', '>', '|'];
  {$ELSE}
  CInvalidNameChars = ['/'];
  {$ENDIF}

function GetIsFolderNameValid(const AName: string): Boolean;
var
  LIndex: Integer;
begin
  Result := (AName <> '') and (AName <> CCurrentFolderName) and
    (AName <> CParentFolderName);
  if not Result then
    Exit;
  for LIndex := 1 to Length(AName) do
    if (AName[LIndex] < ' ') or (AName[LIndex] in CInvalidNameChars) then
      Exit(False);
end;

procedure TNewFolderForm.FormShow(Sender: TObject);
begin
  FolderNameChanged(nil);
end;

procedure TNewFolderForm.FolderNameChanged(Sender: TObject);
begin
  ButtonPanel.OKButton.Enabled := GetIsFolderNameValid(GetFolderName);
end;

function TNewFolderForm.GetFolderName: string;
begin
  Result := Trim(cbFolderName.Text);
end;

procedure TNewFolderForm.SetHistory(AValue: TStrings);
begin
  cbFolderName.Items.Assign(AValue);
  cbFolderName.Text := '';
end;

end.
