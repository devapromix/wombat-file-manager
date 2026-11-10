unit WombatFM.History;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  THistoryDirection = (hdBack, hdForward);

  TPathHistory = class
  private
    FStacks: array[THistoryDirection] of TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddVisit(const APath: string);
    procedure Pop(ADirection: THistoryDirection; out APath: string);
    procedure Push(ADirection: THistoryDirection; const APath: string);
  end;

function GetOppositeDirection(ADirection: THistoryDirection): THistoryDirection;
procedure TrimRecentPaths(AList: TStrings; AMaxCount: Integer);
procedure AddRecentPath(AList: TStrings; const APath: string; AMaxCount: Integer);

implementation

function GetOppositeDirection(ADirection: THistoryDirection): THistoryDirection;
begin
  if ADirection = hdBack then
    Result := hdForward
  else
    Result := hdBack;
end;

procedure TrimRecentPaths(AList: TStrings; AMaxCount: Integer);
begin
  while AList.Count > AMaxCount do
    AList.Delete(AList.Count - 1);
end;

procedure AddRecentPath(AList: TStrings; const APath: string; AMaxCount: Integer);
var
  LIndex: integer;
begin
  LIndex := AList.IndexOf(APath);
  if LIndex >= 0 then
    AList.Delete(LIndex);
  AList.Insert(0, APath);
  TrimRecentPaths(AList, AMaxCount);
end;

constructor TPathHistory.Create;
var
  LDirection: THistoryDirection;
begin
  inherited Create;
  for LDirection := Low(THistoryDirection) to High(THistoryDirection) do
    FStacks[LDirection] := TStringList.Create;
end;

destructor TPathHistory.Destroy;
var
  LDirection: THistoryDirection;
begin
  for LDirection := Low(THistoryDirection) to High(THistoryDirection) do
    FStacks[LDirection].Free;
  inherited Destroy;
end;

procedure TPathHistory.Push(ADirection: THistoryDirection; const APath: string);
begin
  FStacks[ADirection].Add(APath);
end;

procedure TPathHistory.Pop(ADirection: THistoryDirection; out APath: string);
var
  LStack: TStringList;
begin
  LStack := FStacks[ADirection];
  if LStack.Count = 0 then
    APath := ''
  else
  begin
    APath := LStack[LStack.Count - 1];
    LStack.Delete(LStack.Count - 1);
  end;
end;

procedure TPathHistory.AddVisit(const APath: string);
begin
  Push(hdBack, APath);
  FStacks[hdForward].Clear;
end;

end.
