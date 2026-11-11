unit WombatFM.NewFolder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ButtonPanel;

type
  TNewFolderForm = class(TForm)
    ButtonPanel: TButtonPanel;
    cbFolderName: TComboBox;
    lblFolderName: TLabel;
  private
    function GetFolderName: string;
    procedure SetHistory(AValue: TStrings);
  public
    property FolderName: string read GetFolderName;
    property History: TStrings write SetHistory;
  end;

implementation

{$R *.lfm}

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
