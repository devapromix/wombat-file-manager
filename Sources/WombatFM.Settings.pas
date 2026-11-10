unit WombatFM.Settings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ButtonPanel, WombatFM.Options;

type
  TSettingsForm = class(TForm)
    ButtonPanel: TButtonPanel;
    cbMaxPathHistory: TComboBox;
    chkShowHidden: TCheckBox;
    lblMaxPathHistory: TLabel;
  private
    function GetOptions: TAppOptions;
    procedure SetOptions(const AValue: TAppOptions);
  public
    property Options: TAppOptions read GetOptions write SetOptions;
  end;

implementation

uses
  Math;

{$R *.lfm}

function TSettingsForm.GetOptions: TAppOptions;
begin
  Result.OptionMaxPathHistory := StrToInt(cbMaxPathHistory.Text);
  Result.OptionShowHidden := chkShowHidden.Checked;
end;

procedure TSettingsForm.SetOptions(const AValue: TAppOptions);
begin
  cbMaxPathHistory.ItemIndex :=
    Max(0, cbMaxPathHistory.Items.IndexOf(IntToStr(AValue.OptionMaxPathHistory)));
  chkShowHidden.Checked := AValue.OptionShowHidden;
end;

end.
