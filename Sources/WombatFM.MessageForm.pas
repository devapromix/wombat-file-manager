unit WombatFM.MessageForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Forms, Controls, StdCtrls, Buttons, Dialogs;

type
  TMessageForm = class(TForm)
    lblMessage: TLabel;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    FCancelResult: TModalResult;
    FIconIndex: Integer;
    FIconRect: TRect;
    procedure CreateButtons(AButtons: TMsgDlgButtons; ADefaultButton: TMsgDlgBtn);
    function GetButtonKind(AButton: TMsgDlgBtn): TBitBtnKind;
    function GetCancelResult(AButtons: TMsgDlgButtons): TModalResult;
    function GetDialogId(ADialogType: TMsgDlgType): Integer;
    procedure LayoutContent;
  public
    procedure Setup(const AMessage: string; ADialogType: TMsgDlgType;
      AButtons: TMsgDlgButtons; ADefaultButton: TMsgDlgBtn; const ACaption: string);
  end;

function GetMessageResult(const AMessage: string; ADialogType: TMsgDlgType = mtInformation;
  AButtons: TMsgDlgButtons = [mbOK]; ADefaultButton: TMsgDlgBtn = mbOK;
  const ACaption: string = ''): TModalResult;

implementation

uses
  Math, LCLType, LCLIntf, DialogRes;

{$R *.lfm}

const
  CMargin = 16;
  CSpacing = 10;
  CButtonSpacing = 8;
  CIconSize = 32;
  CMaxTextWidth = 480;
  CMinButtonWidth = 80;
  CMinButtonHeight = 28;
  CTextSlack = 2;

function GetMessageResult(const AMessage: string; ADialogType: TMsgDlgType;
  AButtons: TMsgDlgButtons; ADefaultButton: TMsgDlgBtn;
  const ACaption: string): TModalResult;
var
  LForm: TMessageForm;
begin
  LForm := TMessageForm.Create(Application);
  try
    LForm.Setup(AMessage, ADialogType, AButtons, ADefaultButton, ACaption);
    Result := LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

procedure TMessageForm.FormCreate(Sender: TObject);
begin
  FCancelResult := mrNone;
  FIconIndex := -1;
  RegisterDialogForCopyToClipboard(Self);
end;

procedure TMessageForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if (ModalResult = mrCancel) and (FCancelResult <> mrNone) then
    ModalResult := FCancelResult;
end;

procedure TMessageForm.FormPaint(Sender: TObject);
begin
  if FIconIndex >= 0 then
    DialogGlyphs.StretchDraw(Canvas, FIconIndex, FIconRect);
end;

function TMessageForm.GetDialogId(ADialogType: TMsgDlgType): Integer;
begin
  case ADialogType of
    mtWarning: Result := idDialogWarning;
    mtError: Result := idDialogError;
    mtInformation: Result := idDialogInfo;
    mtConfirmation: Result := idDialogConfirm;
    else
      Result := -1;
  end;
end;

function TMessageForm.GetButtonKind(AButton: TMsgDlgBtn): TBitBtnKind;
begin
  case AButton of
    mbYes: Result := bkYes;
    mbNo: Result := bkNo;
    mbOK: Result := bkOK;
    mbCancel: Result := bkCancel;
    mbAbort: Result := bkAbort;
    mbRetry: Result := bkRetry;
    mbIgnore: Result := bkIgnore;
    mbAll: Result := bkAll;
    mbNoToAll: Result := bkNoToAll;
    mbYesToAll: Result := bkYesToAll;
    mbHelp: Result := bkHelp;
    mbClose: Result := bkClose;
    else
      Result := bkCustom;
  end;
end;

function TMessageForm.GetCancelResult(AButtons: TMsgDlgButtons): TModalResult;
begin
  if mbCancel in AButtons then
    Result := mrCancel
  else if mbNo in AButtons then
    Result := mrNo
  else if mbOK in AButtons then
    Result := mrOK
  else
    Result := mrNone;
end;

procedure TMessageForm.CreateButtons(AButtons: TMsgDlgButtons; ADefaultButton: TMsgDlgBtn);
var
  LButton: TMsgDlgBtn;
  LBitBtn: TBitBtn;
  LHasDefault: Boolean;
begin
  LHasDefault := ADefaultButton in AButtons;
  for LButton := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
  begin
    if not (LButton in AButtons) then
      Continue;
    if not LHasDefault then
    begin
      ADefaultButton := LButton;
      LHasDefault := True;
    end;
    LBitBtn := TBitBtn.Create(Self);
    LBitBtn.Parent := Self;
    LBitBtn.Layout := blGlyphLeft;
    LBitBtn.Kind := GetButtonKind(LButton);
    LBitBtn.Cancel := (FCancelResult <> mrNone) and (LBitBtn.ModalResult = FCancelResult);
    LBitBtn.Default := LButton = ADefaultButton;
    if LBitBtn.Default then
      ActiveControl := LBitBtn;
  end;
end;

procedure TMessageForm.LayoutContent;
var
  LTextRect: TRect;
  LBitBtn: TBitBtn;
  LIndex, LButtonCount, LPreferredWidth, LPreferredHeight: Integer;
  LTextWidth, LTextHeight, LIconSize, LIconBlock: Integer;
  LContentWidth, LContentHeight, LButtonsWidth, LButtonWidth, LButtonHeight: Integer;
  LLeft, LButtonTop: Integer;
begin
  Canvas.Font.Assign(Font);
  LTextRect := Rect(0, 0, Min(Scale96ToFont(CMaxTextWidth), Screen.WorkAreaWidth div 2),
    Screen.WorkAreaHeight);
  DrawText(Canvas.Handle, PChar(lblMessage.Caption), Length(lblMessage.Caption), LTextRect,
    DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
  LTextWidth := LTextRect.Right;
  LTextHeight := Max(LTextRect.Bottom, Canvas.TextHeight('Wg'));

  LButtonWidth := Scale96ToFont(CMinButtonWidth);
  LButtonHeight := Scale96ToFont(CMinButtonHeight);
  LButtonCount := 0;
  for LIndex := 0 to ControlCount - 1 do
    if Controls[LIndex] is TBitBtn then
    begin
      LBitBtn := TBitBtn(Controls[LIndex]);
      LBitBtn.HandleNeeded;
      LBitBtn.GetPreferredSize(LPreferredWidth, LPreferredHeight);
      LButtonWidth := Max(LButtonWidth, LPreferredWidth);
      LButtonHeight := Max(LButtonHeight, LPreferredHeight);
      Inc(LButtonCount);
    end;
  LButtonsWidth := LButtonCount * LButtonWidth +
    (LButtonCount - 1) * Scale96ToFont(CButtonSpacing);

  LIconSize := 0;
  LIconBlock := 0;
  if FIconIndex >= 0 then
  begin
    LIconSize := Scale96ToFont(CIconSize);
    LIconBlock := LIconSize + Scale96ToFont(CSpacing);
  end;
  LContentWidth := LIconBlock + LTextWidth;
  LContentHeight := Max(LTextHeight, LIconSize);
  LButtonTop := Scale96ToFont(CMargin) * 2 + LContentHeight;

  ClientWidth := Scale96ToFont(CMargin) * 2 + Max(LContentWidth, LButtonsWidth);
  ClientHeight := LButtonTop + LButtonHeight + Scale96ToFont(CMargin);

  LLeft := (ClientWidth - LContentWidth) div 2;
  if FIconIndex >= 0 then
    FIconRect := Bounds(LLeft, Scale96ToFont(CMargin) + (LContentHeight - LIconSize) div 2,
      LIconSize, LIconSize);
  lblMessage.SetBounds(LLeft + LIconBlock,
    Scale96ToFont(CMargin) + (LContentHeight - LTextHeight) div 2,
    LTextWidth + Scale96ToFont(CTextSlack), LTextHeight);

  LLeft := (ClientWidth - LButtonsWidth) div 2;
  for LIndex := 0 to ControlCount - 1 do
    if Controls[LIndex] is TBitBtn then
    begin
      Controls[LIndex].SetBounds(LLeft, LButtonTop, LButtonWidth, LButtonHeight);
      Inc(LLeft, LButtonWidth + Scale96ToFont(CButtonSpacing));
    end;
end;

procedure TMessageForm.Setup(const AMessage: string; ADialogType: TMsgDlgType;
  AButtons: TMsgDlgButtons; ADefaultButton: TMsgDlgBtn; const ACaption: string);
var
  LDialogId: Integer;
  LCaption: string;
begin
  LDialogId := GetDialogId(ADialogType);
  if LDialogId >= 0 then
  begin
    FIconIndex := DialogGlyphs.DialogIcon[LDialogId];
    LCaption := GetDialogCaption(LDialogId);
  end
  else
    LCaption := Application.Title;
  if ACaption <> '' then
    LCaption := ACaption;
  Caption := LCaption;
  lblMessage.Caption := AMessage;
  if AButtons - [mbHelp] = [] then
    Include(AButtons, mbOK);
  FCancelResult := GetCancelResult(AButtons);
  CreateButtons(AButtons, ADefaultButton);
  LayoutContent;
end;

end.
