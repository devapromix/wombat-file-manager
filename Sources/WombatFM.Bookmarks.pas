unit WombatFM.Bookmarks;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Menus;

type
  TBookmarkSelectEvent = procedure(const APath: string) of object;

  TBookmarkPopupMenu = class(TPopupMenu)
  private
    FBookmarks: TStrings;
    FCurrentPath: string;
    FOnBookmarkSelect: TBookmarkSelectEvent;
    procedure AddBookmarkClick(Sender: TObject);
    procedure AddMenuItem(const ACaption: string; AOnClick: TNotifyEvent;
      ATag: integer; AEnabled: boolean = True);
    procedure BookmarkClick(Sender: TObject);
    procedure BuildItems;
  public
    procedure ShowFor(AControl: TControl; const APath: string);
    property Bookmarks: TStrings read FBookmarks write FBookmarks;
    property OnBookmarkSelect: TBookmarkSelectEvent read FOnBookmarkSelect
      write FOnBookmarkSelect;
  end;

implementation

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
    AddMenuItem(StringReplace(FBookmarks[LIndex], '&', '&&', [rfReplaceAll]),
      @BookmarkClick, LIndex);
  if FBookmarks.Count > 0 then
    AddMenuItem(CMenuSeparator, nil, 0);
  AddMenuItem(CAddBookmarkCaption, @AddBookmarkClick, 0,
    FBookmarks.IndexOf(FCurrentPath) < 0);
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
    FOnBookmarkSelect(FBookmarks[(Sender as TMenuItem).Tag]);
end;

procedure TBookmarkPopupMenu.AddBookmarkClick(Sender: TObject);
begin
  FBookmarks.Add(FCurrentPath);
end;

end.
