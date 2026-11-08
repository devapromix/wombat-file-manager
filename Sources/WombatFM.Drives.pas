unit WombatFM.Drives;

{$mode objfpc}{$H+}

interface

uses
  Classes;

procedure FillDrives(ADrives: TStrings);

implementation

{$IFDEF WINDOWS}
uses
  Windows;

const
  CDriveLetterCount = 26;

procedure FillDrives(ADrives: TStrings);
var
  LMask: DWORD;
  LIndex: Integer;
begin
  ADrives.Clear;
  LMask := GetLogicalDrives;
  for LIndex := 0 to CDriveLetterCount - 1 do
    if (LMask and (DWORD(1) shl LIndex)) <> 0 then
      ADrives.Add(Chr(Ord('A') + LIndex) + ':\');
end;
{$ELSE}
procedure FillDrives(ADrives: TStrings);
begin
  ADrives.Clear;
  ADrives.Add('/');
end;
{$ENDIF}

end.
