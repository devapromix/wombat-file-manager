unit WombatFM.Options;

{$mode objfpc}{$H+}

interface

uses
  fpjson;

const
  CDefaultMaxPathHistory = 20;

type
  TAppOptions = record
    OptionMaxPathHistory: Integer;
    OptionShowHidden: Boolean;
  end;

procedure LoadOptions(ASection: TJSONObject; out AOptions: TAppOptions);
procedure SaveOptions(ASection: TJSONObject; const AOptions: TAppOptions);

implementation

uses
  Math;

procedure LoadOptions(ASection: TJSONObject; out AOptions: TAppOptions);
begin
  AOptions := Default(TAppOptions);
  AOptions.OptionMaxPathHistory := CDefaultMaxPathHistory;
  if Assigned(ASection) then
  begin
    AOptions.OptionMaxPathHistory :=
      Max(1, ASection.Get('maxPathHistory', CDefaultMaxPathHistory));
    AOptions.OptionShowHidden := ASection.Get('showHidden', False);
  end;
end;

procedure SaveOptions(ASection: TJSONObject; const AOptions: TAppOptions);
begin
  ASection.Integers['maxPathHistory'] := AOptions.OptionMaxPathHistory;
  ASection.Booleans['showHidden'] := AOptions.OptionShowHidden;
end;

end.
