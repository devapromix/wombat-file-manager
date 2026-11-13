unit WombatFM.Bookmarks;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Menus, WombatFM.BookmarkList;

type
  TBookmarkSelectEvent = procedure(const APath: string) of object;

  TBookmarkPopupMenu = class(TPopupMenu)
  private
    FBookmarks: TBookmarkList;
    FCurrentPath: string;
    FOnBookmarksAccepted: TNotifyEvent;
    FOnBookmarkSelect: TBookmarkSelectEvent;
    procedure AddBookmarkClick(Sender: TObject);
    procedure AddMenuItem(const ACaption: string; AOnClick: TNotifyEvent;
      ATag: integer; AEnabled: boolean = True);
    procedure BookmarkClick(Sender: TObject);
    procedure EditBookmarksClick(Sender: TObject);
    procedure BuildItems;
  public
    procedure ShowFor(AControl: TControl; const APath: string);
    property Bookmarks: TBookmarkList read FBookmarks write FBookmarks;
    property OnBookmarksAccepted: TNotifyEvent read FOnBookmarksAccepted
      write FOnBookmarksAccepted;
    property OnBookmarkSelect: TBookmarkSelectEvent read FOnBookmarkSelect
      write FOnBookmarkSelect;
  end;

implementation

uses
  WombatFM.BookmarkForm, WombatFM.BookmarkNameForm;

const
  CAddBookmarkCaption = 'Add bookmark';
  CMenuSeparator = '-';

procedure TBookmarkPopupMenu.AddMenuItem(const ACaption: string;
  AOnClick: TNotifyEvent; ATag: integer; AEnabled: boolean);
var
  LItem: TMenuItem;
begin
  LItem := TMenuItem.Create(Self);
  LItem.Caption := ACaption;
  LItem.OnClick := AOnClick;
  LItem.Tag := ATag;
  LItem.Enabled := AEnabled;
  Items.Add(LItem);
end;

procedure TBookmarkPopupMenu.BuildItems;
var
  LIndex: integer;
begin
  Items.Clear;
  for LIndex := 0 to FBookmarks.Count - 1 do
    AddMenuItem(StringReplace(FBookmarks[LIndex].Name, '&', '&&', [rfReplaceAll]),
      @BookmarkClick, LIndex);
  if FBookmarks.Count > 0 then
    AddMenuItem(CMenuSeparator, nil, 0);
  AddMenuItem(CAddBookmarkCaption, @AddBookmarkClick, 0,
    FBookmarks.IndexOfPath(FCurrentPath) < 0);
  AddMenuItem('Edit Bookmarks', @EditBookmarksClick, 0);
end;

procedure TBookmarkPopupMenu.ShowFor(AControl: TControl; const APath: string);
var
  LPoint: TPoint;
begin
  FCurrentPath := APath;
  BuildItems;
  LPoint := AControl.ClientToScreen(Point(0, AControl.Height));
  PopUp(LPoint.X, LPoint.Y);
end;

procedure TBookmarkPopupMenu.BookmarkClick(Sender: TObject);
begin
  if Assigned(FOnBookmarkSelect) then
    FOnBookmarkSelect(FBookmarks[(Sender as TMenuItem).Tag].Path);
end;

procedure TBookmarkPopupMenu.EditBookmarksClick(Sender: TObject);
var
  LEditor: TBookmarkForm;
begin
  LEditor := TBookmarkForm.Create(nil);
  try
    if LEditor.EditBookmarks(FBookmarks) and Assigned(FOnBookmarksAccepted) then
      FOnBookmarksAccepted(Self);
  finally
    LEditor.Free;
  end;
end;

procedure TBookmarkPopupMenu.AddBookmarkClick(Sender: TObject);
var
  LForm: TBookmarkNameForm;
  LName: string;
begin
  LName := DefaultBookmarkName(FCurrentPath);
  LForm := TBookmarkNameForm.Create(nil);
  try
    if LForm.Prompt(LName) then
      FBookmarks.AddBookmark(LName, FCurrentPath);
  finally
    LForm.Free;
  end;
end;

end.
