unit WombatFM.BookmarkList;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Generics.Collections;

type
  TBookmark = record
    Name: string;
    Path: string;
  end;

  TBookmarkList = class(specialize TList<TBookmark>)
  public
    procedure AddBookmark(const AName, APath: string);
    function IndexOfPath(const APath: string): integer;
  end;

function DefaultBookmarkName(const APath: string): string;

implementation

function DefaultBookmarkName(const APath: string): string;
begin
  Result := ExtractFileName(ExcludeTrailingPathDelimiter(APath));
  if (Result = '') or (ExtractFileDrive(APath) = ExcludeTrailingPathDelimiter(APath)) then
    Result := APath;
end;

procedure TBookmarkList.AddBookmark(const AName, APath: string);
var
  LBookmark: TBookmark;
begin
  LBookmark.Name := AName;
  LBookmark.Path := APath;
  Add(LBookmark);
end;

function TBookmarkList.IndexOfPath(const APath: string): integer;
var
  LIndex: integer;
begin
  for LIndex := 0 to Count - 1 do
    if SameText(Items[LIndex].Path, APath) then
      Exit(LIndex);
  Result := -1;
end;

end.