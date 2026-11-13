unit WombatFM.BookmarkForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, Controls, StdCtrls, ExtCtrls, Dialogs;

type
  TBookmarkForm = class(TForm)
    lbBookmarks: TListBox;
    pnlButtons: TPanel;
    btnMoveUp: TButton;
    btnMoveDown: TButton;
    btnDelete: TButton;
    btnClose: TButton;
    procedure UpdateButtons(Sender: TObject; User: boolean);
    procedure MoveBookmark(Sender: TObject);
    procedure DeleteBookmark(Sender: TObject);
  public
    procedure EditBookmarks(ABookmarks: TStrings);
  end;

implementation

{$R *.lfm}

procedure TBookmarkForm.EditBookmarks(ABookmarks: TStrings);
begin
  lbBookmarks.Items.Assign(ABookmarks);
  if lbBookmarks.Count > 0 then
    lbBookmarks.ItemIndex := 0;
  UpdateButtons(nil, False);
  ShowModal;
  ABookmarks.Assign(lbBookmarks.Items);
end;


procedure TBookmarkForm.UpdateButtons(Sender: TObject; User: boolean);
var
  LIndex: integer;
begin
  LIndex := lbBookmarks.ItemIndex;
  btnMoveUp.Enabled := LIndex > 0;
  btnMoveDown.Enabled := (LIndex >= 0) and (LIndex < lbBookmarks.Count - 1);
  btnDelete.Enabled := LIndex >= 0;
end;

procedure TBookmarkForm.MoveBookmark(Sender: TObject);
var
  LIndex, LTarget: integer;
begin
  LIndex := lbBookmarks.ItemIndex;
  LTarget := LIndex + (Sender as TButton).Tag;
  if (LIndex < 0) or (LTarget < 0) or (LTarget >= lbBookmarks.Count) then
    Exit;
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
  lbBookmarks.Items.Delete(LIndex);
  if LIndex >= lbBookmarks.Count then
    LIndex := lbBookmarks.Count - 1;
  lbBookmarks.ItemIndex := LIndex;
  UpdateButtons(nil, False);
end;

end.
