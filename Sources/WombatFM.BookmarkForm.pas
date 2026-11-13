unit WombatFM.BookmarkForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, WombatFM.BookmarkList;

type
  TBookmarkForm = class(TForm)
    lbBookmarks: TListBox;
    pnlButtons: TPanel;
    btnMoveUp: TButton;
    btnMoveDown: TButton;
    btnDelete: TButton;
    btnRename: TButton;
    btnClose: TButton;
    procedure UpdateButtons(Sender: TObject; User: boolean);
    procedure MoveBookmark(Sender: TObject);
    procedure DeleteBookmark(Sender: TObject);
    procedure RenameBookmark(Sender: TObject);
  private
    FBookmarks: TBookmarkList;
  public
    procedure EditBookmarks(ABookmarks: TBookmarkList);
  end;

implementation

uses
  WombatFM.BookmarkNameForm;

{$R *.lfm}

procedure TBookmarkForm.EditBookmarks(ABookmarks: TBookmarkList);
var
  LIndex: integer;
begin
  FBookmarks := ABookmarks;
  lbBookmarks.Items.Clear;
  for LIndex := 0 to FBookmarks.Count - 1 do
    lbBookmarks.Items.Add(FBookmarks[LIndex].Name);
  if lbBookmarks.Count > 0 then
    lbBookmarks.ItemIndex := 0;
  UpdateButtons(nil, False);
  ShowModal;
end;


procedure TBookmarkForm.UpdateButtons(Sender: TObject; User: boolean);
var
  LIndex: integer;
begin
  LIndex := lbBookmarks.ItemIndex;
  btnMoveUp.Enabled := LIndex > 0;
  btnMoveDown.Enabled := (LIndex >= 0) and (LIndex < lbBookmarks.Count - 1);
  btnDelete.Enabled := LIndex >= 0;
  btnRename.Enabled := LIndex >= 0;
end;

procedure TBookmarkForm.MoveBookmark(Sender: TObject);
var
  LIndex, LTarget: integer;
begin
  LIndex := lbBookmarks.ItemIndex;
  LTarget := LIndex + (Sender as TButton).Tag;
  if (LIndex < 0) or (LTarget < 0) or (LTarget >= lbBookmarks.Count) then
    Exit;
  FBookmarks.Move(LIndex, LTarget);
  lbBookmarks.Items.Move(LIndex, LTarget);
  lbBookmarks.ItemIndex := LTarget;
  UpdateButtons(nil, False);
end;

procedure TBookmarkForm.DeleteBookmark(Sender: TObject);
var
  LIndex: integer;
begin
  LIndex := lbBookmarks.ItemIndex;
  if LIndex < 0 then
    Exit;
  if MessageDlg('Delete bookmark "' + lbBookmarks.Items[LIndex] + '"?',
    mtConfirmation, [mbYes, mbNo], 0, mbNo) <> mrYes then
    Exit;
  FBookmarks.Delete(LIndex);
  lbBookmarks.Items.Delete(LIndex);
  if LIndex >= lbBookmarks.Count then
    LIndex := lbBookmarks.Count - 1;
  lbBookmarks.ItemIndex := LIndex;
  UpdateButtons(nil, False);
end;

procedure TBookmarkForm.RenameBookmark(Sender: TObject);
var
  LIndex: integer;
  LBookmark: TBookmark;
  LForm: TBookmarkNameForm;
begin
  LIndex := lbBookmarks.ItemIndex;
  if LIndex < 0 then
    Exit;
  LBookmark := FBookmarks[LIndex];
  LForm := TBookmarkNameForm.Create(Self);
  try
    LForm.Caption := 'Rename bookmark';
    if LForm.Prompt(LBookmark.Name) then
    begin
      FBookmarks[LIndex] := LBookmark;
      lbBookmarks.Items[LIndex] := LBookmark.Name;
      lbBookmarks.ItemIndex := LIndex;
    end;
  finally
    LForm.Free;
  end;
end;

end.
