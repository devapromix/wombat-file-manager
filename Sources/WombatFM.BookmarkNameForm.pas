unit WombatFM.BookmarkNameForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ButtonPanel;

type
  TBookmarkNameForm = class(TForm)
    ButtonPanel: TButtonPanel;
    edtName: TEdit;
    lblName: TLabel;
    procedure FormShow(Sender: TObject);
    procedure NameChanged(Sender: TObject);
  public
    function Prompt(var AName: string): boolean;
  end;

implementation

{$R *.lfm}

procedure TBookmarkNameForm.FormShow(Sender: TObject);
begin
  edtName.SelectAll;
  NameChanged(nil);
end;

procedure TBookmarkNameForm.NameChanged(Sender: TObject);
begin
  if Assigned(ButtonPanel) and Assigned(ButtonPanel.OKButton) then
    ButtonPanel.OKButton.Enabled := Trim(edtName.Text) <> '';
end;

function TBookmarkNameForm.Prompt(var AName: string): boolean;
begin
  edtName.Text := AName;
  Result := (ShowModal = mrOK) and (Trim(edtName.Text) <> '');
  if Result then
    AName := Trim(edtName.Text);
end;

end.