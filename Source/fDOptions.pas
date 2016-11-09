unit fDOptions;

interface {********************************************************************}

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, ComCtrls, StdCtrls,
  SynEdit, SynEditHighlighter, SynHighlighterSQL, SynMemo,
  ExtCtrls_Ext, StdCtrls_Ext, ComCtrls_Ext, Forms_Ext,
  fPreferences, fSession,
  fBase;

type
  TIniFileRecord = record
    Name: string;
    Filename: TFileName;
  end;

  TDOptions = class (TForm_Ext)
    ColorDialog: TColorDialog;
    FAssociateSQL: TCheckBox;
    FBackground: TCheckBox;
    FBBackground: TButton;
    FBCancel: TButton;
    FBEditorFont: TButton;
    FBForeground: TButton;
    FBGridFont: TButton;
    FBHelp: TButton;
    FBOk: TButton;
    FBold: TCheckBox;
    FEditorCompletionEnabled: TCheckBox;
    FEditorCompletionTime: TEdit;
    FEditorCurrRowBGColorEnabled: TCheckBox;
    FEditorFont: TEdit;
    FForeground: TCheckBox;
    FGridCurrRowBGColorEnabled: TCheckBox;
    FGridFont: TEdit;
    FGridNullText: TCheckBox;
    FGridShowMemoContent: TCheckBox;
    FItalic: TCheckBox;
    FL2LogSize: TLabel;
    FLanguage: TComboBox_Ext;
    FLAssociate: TLabel;
    FLEditorCompletion: TLabel;
    FLEditorCompletionTime: TLabel;
    FLEditorCurrRowBGColor: TLabel;
    FLEditorFont: TLabel;
    FLGridCurrRowBGColor: TLabel;
    FLGridFont: TLabel;
    FLGridNullValues: TLabel;
    FLLanguage: TLabel;
    FLLogFont: TLabel;
    FLLogLinenumbers: TLabel;
    FLLogSize: TLabel;
    FLMaxColumnWidth: TLabel;
    FLMaxColumnWidthCharacters: TLabel;
    FLogFont: TEdit;
    FLogResult: TCheckBox;
    FLogSize: TEdit;
    FLogTime: TCheckBox;
    FLTabsVisible: TLabel;
    FLUpdateCheck: TLabel;
    FLViewDatas: TLabel;
    FMaxColumnWidth: TEdit;
    FontDialog: TFontDialog;
    FPreview: TSynMemo;
    FStyles: TListView;
    FTabsVisible: TCheckBox;
    FUDEditorCompletionTime: TUpDown;
    FUDLogSize: TUpDown;
    FUDMaxColumnWidth: TUpDown;
    FUnderline: TCheckBox;
    FUpdateCheckDaily: TRadioButton;
    FUpdateCheckNever: TRadioButton;
    GAssociate: TGroupBox_Ext;
    GColors: TGroupBox_Ext;
    GEditor: TGroupBox_Ext;
    GGrid: TGroupBox_Ext;
    GLog: TGroupBox_Ext;
    GProgram: TGroupBox_Ext;
    GTabs: TGroupBox_Ext;
    GUpdates: TGroupBox_Ext;
    Highlighter: TSynSQLSyn;
    PageControl: TPageControl;
    PEditorCurrRowBGColor: TPanel_Ext;
    PEditorFont: TPanel_Ext;
    PGridCurrRowBGColor: TPanel_Ext;
    PGridFont: TPanel_Ext;
    PGridNullBGColor: TPanel_Ext;
    PGridNullBGColorEnabled: TCheckBox;
    PLogFont: TPanel_Ext;
    PQuery: TPanel_Ext;
    Sizer: TCheckBox;
    TSBrowser: TTabSheet;
    TSEditor: TTabSheet;
    TSExtras: TTabSheet;
    TSHighlighter: TTabSheet;
    TSLog: TTabSheet;
    TSUpdates: TTabSheet;
    TSView: TTabSheet;
    FBLogFont: TButton;
    procedure FBackgroundClick(Sender: TObject);
    procedure FBackgroundKeyPress(Sender: TObject; var Key: Char);
    procedure FBBackgroundClick(Sender: TObject);
    procedure FBEditorCurrRowBGColorClick(Sender: TObject);
    procedure FBEditorFontClick(Sender: TObject);
    procedure FBForegroundClick(Sender: TObject);
    procedure FBGridCurrRowBGColorClick(Sender: TObject);
    procedure FBGridFontClick(Sender: TObject);
    procedure FBHelpClick(Sender: TObject);
    procedure FBLogFontClick(Sender: TObject);
    procedure FBoldClick(Sender: TObject);
    procedure FEditorFontKeyPress(Sender: TObject; var Key: Char);
    procedure FForegroundClick(Sender: TObject);
    procedure FForegroundKeyPress(Sender: TObject; var Key: Char);
    procedure FGridFontKeyPress(Sender: TObject; var Key: Char);
    procedure FItalicClick(Sender: TObject);
    procedure FLogFontKeyPress(Sender: TObject; var Key: Char);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FStylesSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure FUnderlineClick(Sender: TObject);
    procedure PEditorCurrRowBGColorClick(Sender: TObject);
    procedure PGridCurrRowBGColorClick(Sender: TObject);
    procedure PGridNullBGColorClick(Sender: TObject);
    procedure TSHighlighterShow(Sender: TObject);
    procedure TSBrowserResize(Sender: TObject);
    procedure TSEditorResize(Sender: TObject);
    procedure FBGridFontKeyPress(Sender: TObject; var Key: Char);
    procedure TSLogResize(Sender: TObject);
    procedure FBLogFontKeyPress(Sender: TObject; var Key: Char);
  private
    LineNumbersAttri: TSynHighlighterAttributes;
    function Attribute(const Caption: string): TSynHighlighterAttributes;
    procedure FPreviewRefresh();
    procedure UMChangePreferences(var Message: TMessage); message UM_CHANGEPREFERENCES;
  public
    Languages: array of TIniFileRecord;
    function Execute(): Boolean;
  end;

function DOptions(): TDOptions;

implementation {***************************************************************}

{$R *.dfm}

uses
  IniFiles,
  StrUtils;

var
  FOptions: TDOptions;

function DOptions(): TDOptions;
begin
  if (not Assigned(FOptions)) then
  begin
    Application.CreateForm(TDOptions, FOptions);
    FOptions.Perform(UM_CHANGEPREFERENCES, 0, 0);
  end;

  Result := FOptions;
end;

function TDOptions.Attribute(const Caption: string): TSynHighlighterAttributes;
begin
  Result := nil;

  if (Caption = Preferences.LoadStr(461)) then Result := Highlighter.CommentAttri;
  if (Caption = Preferences.LoadStr(462)) then Result := Highlighter.StringAttri;
  if (Caption = Preferences.LoadStr(463)) then Result := Highlighter.KeyAttri;
  if (Caption = Preferences.LoadStr(464)) then Result := Highlighter.NumberAttri;
  if (Caption = Preferences.LoadStr(465)) then Result := Highlighter.IdentifierAttri;
  if (Caption = Preferences.LoadStr(466)) then Result := Highlighter.SymbolAttri;
  if (Caption = Preferences.LoadStr(467)) then Result := Highlighter.FunctionAttri;
  if (Caption = Preferences.LoadStr(468)) then Result := Highlighter.DataTypeAttri;
  if (Caption = Preferences.LoadStr(469)) then Result := Highlighter.VariableAttri;
  if (Caption = Preferences.LoadStr(735)) then Result := Highlighter.ConditionalCommentAttri;
  if (Caption = Preferences.LoadStr(526)) then Result := LineNumbersAttri;
end;

function TDOptions.Execute(): Boolean;
begin
  ShowModal();
  Result := ModalResult = mrOk;
end;

procedure TDOptions.FBackgroundClick(Sender: TObject);
begin
  if (not FBackground.Checked) and Assigned(FStyles.Selected) then
    Attribute(FStyles.Selected.Caption).Background := clNone;
  FPreviewRefresh();

  FBBackground.Enabled := FBackground.Checked;
end;

procedure TDOptions.FBackgroundKeyPress(Sender: TObject; var Key: Char);
begin
  FBackgroundClick(Sender);
end;

procedure TDOptions.FBBackgroundClick(Sender: TObject);
var
  Attri: TSynHighlighterAttributes;
begin
  if (Assigned(FStyles.Selected)) then
  begin
    Attri := Attribute(FStyles.Selected.Caption);
    if (Attri.Background = clNone) then
      ColorDialog.Color := FPreview.Color
    else
      ColorDialog.Color := Attri.Background;

    if (ColorDialog.Execute()) then
      Attri.Background := ColorDialog.Color;
    FPreviewRefresh();
  end;
end;

procedure TDOptions.FBEditorCurrRowBGColorClick(Sender: TObject);
begin
  if (PEditorCurrRowBGColor.Color = clNone) then
    ColorDialog.Color := clWindow
  else
    ColorDialog.Color := PEditorCurrRowBGColor.Color;

  if (ColorDialog.Execute()) then
    PEditorCurrRowBGColor.Color := ColorDialog.Color;
end;

procedure TDOptions.FBEditorFontClick(Sender: TObject);
begin
  FontDialog.Font := PEditorFont.Font;
  FontDialog.Options := FontDialog.Options + [fdFixedPitchOnly];
  if (FontDialog.Execute()) then
  begin
    FEditorFont.Text := FontDialog.Font.Name;
    PEditorFont.Font := FontDialog.Font;
  end;
end;

procedure TDOptions.FBForegroundClick(Sender: TObject);
var
  Attri: TSynHighlighterAttributes;
begin
  if (Assigned(FStyles.Selected)) then
  begin
    Attri := Attribute(FStyles.Selected.Caption);
    if (Attri.Foreground = clNone) then
      ColorDialog.Color := FPreview.Font.Color
    else
      ColorDialog.Color := Attri.Foreground;
    if (ColorDialog.Execute()) then
      Attri.Foreground := ColorDialog.Color;
    FPreviewRefresh();
  end;
end;

procedure TDOptions.FBGridCurrRowBGColorClick(Sender: TObject);
begin
  if (PGridCurrRowBGColor.Color = clNone) then
    ColorDialog.Color := clWindow
  else
    ColorDialog.Color := PGridCurrRowBGColor.Color;

  if (ColorDialog.Execute()) then
    PGridCurrRowBGColor.Color := ColorDialog.Color;
end;

procedure TDOptions.FBGridFontClick(Sender: TObject);
begin
  FontDialog.Font := PGridFont.Font;
  FontDialog.Options := FontDialog.Options - [fdFixedPitchOnly];
  if (FontDialog.Execute()) then
  begin
    FGridFont.Text := FontDialog.Font.Name;
    PGridFont.Font := FontDialog.Font;
  end;
end;

procedure TDOptions.FBGridFontKeyPress(Sender: TObject; var Key: Char);
begin
  FBGridFontClick(Sender);
end;

procedure TDOptions.FBHelpClick(Sender: TObject);
begin
  Application.HelpContext(HelpContext);
end;

procedure TDOptions.FBLogFontClick(Sender: TObject);
begin
  FontDialog.Font := PLogFont.Font;
  FontDialog.Options := FontDialog.Options + [fdFixedPitchOnly];
  if (FontDialog.Execute()) then
  begin
    FLogFont.Text := FontDialog.Font.Name;
    PLogFont.Font := FontDialog.Font;
  end;
end;

procedure TDOptions.FBLogFontKeyPress(Sender: TObject; var Key: Char);
begin
  FBLogFontClick(Sender);
end;

procedure TDOptions.FBoldClick(Sender: TObject);
var
  Attri: TSynHighlighterAttributes;
begin
  if (Assigned(FStyles.Selected)) then
  begin
    Attri := Attribute(FStyles.Selected.Caption);
    if (FBold.Checked) then
      Attri.Style := Attri.Style + [fsBold]
    else
      Attri.Style := Attri.Style - [fsBold];
    FPreviewRefresh();
  end;
end;

procedure TDOptions.FEditorFontKeyPress(Sender: TObject; var Key: Char);
begin
  FBEditorFontClick(Sender);
end;

procedure TDOptions.FForegroundClick(Sender: TObject);
begin
  if (not FForeground.Checked) and Assigned(FStyles.Selected) then
    Attribute(FStyles.Selected.Caption).Foreground := clNone;
  FPreviewRefresh();

  FBForeground.Enabled := FForeground.Checked;
end;

procedure TDOptions.FForegroundKeyPress(Sender: TObject; var Key: Char);
begin
  FForegroundClick(Sender);
end;

procedure TDOptions.FGridFontKeyPress(Sender: TObject; var Key: Char);
begin
  FBGridFontClick(Sender);
end;

procedure TDOptions.FItalicClick(Sender: TObject);
var
  Attri: TSynHighlighterAttributes;
begin
  if (Assigned(FStyles.Selected)) then
  begin
    Attri := Attribute(FStyles.Selected.Caption);
    if (FItalic.Checked) then
      Attri.Style := Attri.Style + [fsItalic]
    else
      Attri.Style := Attri.Style - [fsItalic];
    FPreviewRefresh();
  end;
end;

procedure TDOptions.FLogFontKeyPress(Sender: TObject; var Key: Char);
begin
  FBLogFontClick(Sender);
end;

{ TDOptions *******************************************************************}

procedure TDOptions.FormCreate(Sender: TObject);
begin
  LineNumbersAttri := TSynHighlighterAttributes.Create('', '');
end;

procedure TDOptions.FormDestroy(Sender: TObject);
begin
  LineNumbersAttri.Free();
end;

procedure TDOptions.FormHide(Sender: TObject);
var
  I: Integer;
begin
  if (ModalResult = mrOk) then
  begin
    if (FLanguage.ItemIndex >= 0) then
      for I := 0 to Length(Languages) - 1 do
        if (Trim(FLanguage.Text) = Languages[I].Name) then
          Preferences.LanguageFilename := Languages[I].Filename;

    Preferences.TabsVisible := FTabsVisible.Checked;

    Preferences.GridFontName := PGridFont.Font.Name;
    Preferences.GridFontStyle := PGridFont.Font.Style - [fsBold];
    Preferences.GridFontColor := PGridFont.Font.Color;
    Preferences.GridFontSize := PGridFont.Font.Size;
    Preferences.GridFontCharset := PGridFont.Font.Charset;
    Preferences.GridNullBGColorEnabled := PGridNullBGColorEnabled.Checked;
    Preferences.GridNullBGColor := PGridNullBGColor.Color;
    Preferences.GridNullText := FGridNullText.Checked;
    Preferences.GridCurrRowBGColorEnabled := FGridCurrRowBGColorEnabled.Checked;
    Preferences.GridCurrRowBGColor := PGridCurrRowBGColor.Color;

    Preferences.SQLFontName := PEditorFont.Font.Name;
    Preferences.SQLFontStyle := PEditorFont.Font.Style;
    Preferences.SQLFontColor := PEditorFont.Font.Color;
    Preferences.SQLFontSize := PEditorFont.Font.Size;
    Preferences.SQLFontCharset := PEditorFont.Font.Charset;
    Preferences.Editor.CurrRowBGColorEnabled := FEditorCurrRowBGColorEnabled.Checked;
    Preferences.Editor.CurrRowBGColor := PEditorCurrRowBGColor.Color;
    Preferences.Editor.CodeCompletion := FEditorCompletionEnabled.Checked;
    TryStrToInt(FEditorCompletionTime.Text, Preferences.Editor.CodeCompletionTime);

    Preferences.LogFontName := PLogFont.Font.Name;
    Preferences.LogFontStyle := PLogFont.Font.Style;
    Preferences.LogFontColor := PLogFont.Font.Color;
    Preferences.LogFontSize := PLogFont.Font.Size;
    Preferences.LogFontCharset := PLogFont.Font.Charset;
    Preferences.LogTime := FLogTime.Checked;
    Preferences.LogResult := FLogResult.Checked;
    Preferences.LogSize := FUDLogSize.Position * 1024;

    Preferences.GridMaxColumnWidth := FUDMaxColumnWidth.Position;

    Preferences.GridMemoContent := FGridShowMemoContent.Checked;

    Preferences.AssociateSQL := FAssociateSQL.Checked;

    Preferences.Editor.ConditionalCommentForeground := Highlighter.ConditionalCommentAttri.Foreground;
    Preferences.Editor.ConditionalCommentBackground := Highlighter.ConditionalCommentAttri.Background;
    Preferences.Editor.ConditionalCommentStyle := Highlighter.ConditionalCommentAttri.Style;
    Preferences.Editor.CommentForeground := Highlighter.CommentAttri.Foreground;
    Preferences.Editor.CommentBackground := Highlighter.CommentAttri.Background;
    Preferences.Editor.CommentStyle := Highlighter.CommentAttri.Style;
    Preferences.Editor.DataTypeForeground := Highlighter.DataTypeAttri.Foreground;
    Preferences.Editor.DataTypeBackground := Highlighter.DataTypeAttri.Background;
    Preferences.Editor.DataTypeStyle := Highlighter.DataTypeAttri.Style;
    Preferences.Editor.FunctionForeground := Highlighter.FunctionAttri.Foreground;
    Preferences.Editor.FunctionBackground := Highlighter.FunctionAttri.Background;
    Preferences.Editor.FunctionStyle := Highlighter.FunctionAttri.Style;
    Preferences.Editor.IdentifierForeground := Highlighter.IdentifierAttri.Foreground;
    Preferences.Editor.IdentifierBackground := Highlighter.IdentifierAttri.Background;
    Preferences.Editor.IdentifierStyle := Highlighter.IdentifierAttri.Style;
    Preferences.Editor.KeywordForeground := Highlighter.KeyAttri.Foreground;
    Preferences.Editor.KeywordBackground := Highlighter.KeyAttri.Background;
    Preferences.Editor.KeywordStyle := Highlighter.KeyAttri.Style;
    Preferences.Editor.NumberForeground := Highlighter.NumberAttri.Foreground;
    Preferences.Editor.NumberBackground := Highlighter.NumberAttri.Background;
    Preferences.Editor.NumberStyle := Highlighter.NumberAttri.Style;
    Preferences.Editor.StringForeground := Highlighter.StringAttri.Foreground;
    Preferences.Editor.StringBackground := Highlighter.StringAttri.Background;
    Preferences.Editor.StringStyle := Highlighter.StringAttri.Style;
    Preferences.Editor.SymbolForeground := Highlighter.SymbolAttri.Foreground;
    Preferences.Editor.SymbolBackground := Highlighter.SymbolAttri.Background;
    Preferences.Editor.SymbolStyle := Highlighter.SymbolAttri.Style;
    Preferences.Editor.VariableForeground := Highlighter.VariableAttri.Foreground;
    Preferences.Editor.VariableBackground := Highlighter.VariableAttri.Background;
    Preferences.Editor.VariableStyle := Highlighter.VariableAttri.Style;
    Preferences.Editor.LineNumbersForeground := LineNumbersAttri.Foreground;
    Preferences.Editor.LineNumbersBackground := LineNumbersAttri.Background;
    Preferences.Editor.LineNumbersStyle := LineNumbersAttri.Style;

    if (FUpdateCheckNever.Checked) then Preferences.UpdateCheck := utNever;
    if (FUpdateCheckDaily.Checked) then Preferences.UpdateCheck := utDaily;
  end;
end;

procedure TDOptions.FormShow(Sender: TObject);
var
  I: Integer;
  IniFile: TMemIniFile;
  SearchRec: TSearchRec;
begin
  SetLength(Languages, 0);
  if (FindFirst(Preferences.LanguagePath + '*.ini', faAnyFile, SearchRec) = NO_ERROR) then
  begin
    repeat
      IniFile := TMemIniFile.Create(Preferences.LanguagePath + SearchRec.Name);

      if (UpperCase(IniFile.ReadString('Global', 'Type', '')) = 'LANGUAGE') then
      begin
        SetLength(Languages, Length(Languages) + 1);
        Languages[Length(Languages) - 1].Name := IniFile.ReadString('Global', 'Name', '');
        Languages[Length(Languages) - 1].Filename := SearchRec.Name;
      end;

      FreeAndNil(IniFile);
    until (FindNext(SearchRec) <> NO_ERROR);
    FindClose(SearchRec);
  end;

  FLanguage.Items.Clear();
  for I := 0 to Length(Languages) - 1 do
    FLanguage.Items.Add(Languages[I].Name);
  for I := 0 to Length(Languages) - 1 do
    if (lstrcmpi(PChar(Preferences.LanguageFilename), PChar(Languages[I].Filename)) = 0) then
      FLanguage.ItemIndex := FLanguage.Items.IndexOf(Languages[I].Name);


  FTabsVisible.Checked := Preferences.TabsVisible;

  FUDMaxColumnWidth.Position := Preferences.GridMaxColumnWidth;

  FGridShowMemoContent.Checked := Preferences.GridMemoContent;

  FGridFont.Text := Preferences.GridFontName;
  PGridFont.Font.Name := Preferences.GridFontName;
  PGridFont.Font.Style := Preferences.GridFontStyle;
  PGridFont.Font.Color := Preferences.GridFontColor;
  PGridFont.Font.Size := Preferences.GridFontSize;
  PGridFont.Font.Charset := Preferences.GridFontCharset;
  PGridNullBGColorEnabled.Checked := Preferences.GridNullBGColorEnabled;
  PGridNullBGColor.Color := Preferences.GridNullBGColor;
  FGridNullText.Checked := Preferences.GridNullText;
  FGridCurrRowBGColorEnabled.Checked := Preferences.GridCurrRowBGColorEnabled;
  PGridCurrRowBGColor.Color := Preferences.GridCurrRowBGColor;

  FEditorFont.Text := Preferences.SQLFontName;
  PEditorFont.Font.Name := Preferences.SQLFontName;
  PEditorFont.Font.Style := Preferences.SQLFontStyle;
  PEditorFont.Font.Color := Preferences.SQLFontColor;
  PEditorFont.Font.Size := Preferences.SQLFontSize;
  PEditorFont.Font.Charset := Preferences.SQLFontCharset;
  FEditorCurrRowBGColorEnabled.Checked := Preferences.Editor.CurrRowBGColorEnabled;
  PEditorCurrRowBGColor.Color := Preferences.Editor.CurrRowBGColor;
  FEditorCompletionEnabled.Checked := Preferences.Editor.CodeCompletion;
  FUDEditorCompletionTime.Position := Preferences.Editor.CodeCompletionTime;

  FLogFont.Text := Preferences.LogFontName;
  PLogFont.Font.Name := Preferences.LogFontName;
  PLogFont.Font.Style := Preferences.LogFontStyle;
  PLogFont.Font.Color := Preferences.LogFontColor;
  PLogFont.Font.Size := Preferences.LogFontSize;
  PLogFont.Font.Charset := Preferences.LogFontCharset;
  FLogTime.Checked := Preferences.LogTime;
  FLogResult.Checked := Preferences.LogResult;
  FUDLogSize.Position := Preferences.LogSize div 1024;

  FAssociateSQL.Checked := Preferences.AssociateSQL;

  Highlighter.ConditionalCommentAttri.Foreground := Preferences.Editor.ConditionalCommentForeground;
  Highlighter.ConditionalCommentAttri.Background := Preferences.Editor.ConditionalCommentBackground;
  Highlighter.ConditionalCommentAttri.Style := Preferences.Editor.ConditionalCommentStyle;
  Highlighter.CommentAttri.Foreground := Preferences.Editor.CommentForeground;
  Highlighter.CommentAttri.Background := Preferences.Editor.CommentBackground;
  Highlighter.CommentAttri.Style := Preferences.Editor.CommentStyle;
  Highlighter.DataTypeAttri.Foreground := Preferences.Editor.DataTypeForeground;
  Highlighter.DataTypeAttri.Background := Preferences.Editor.DataTypeBackground;
  Highlighter.DataTypeAttri.Style := Preferences.Editor.DataTypeStyle;
  Highlighter.FunctionAttri.Foreground := Preferences.Editor.FunctionForeground;
  Highlighter.FunctionAttri.Background := Preferences.Editor.FunctionBackground;
  Highlighter.FunctionAttri.Style := Preferences.Editor.FunctionStyle;
  Highlighter.IdentifierAttri.Foreground := Preferences.Editor.IdentifierForeground;
  Highlighter.IdentifierAttri.Background := Preferences.Editor.IdentifierBackground;
  Highlighter.IdentifierAttri.Style := Preferences.Editor.IdentifierStyle;
  Highlighter.DelimitedIdentifierAttri := Highlighter.IdentifierAttri;
  Highlighter.KeyAttri.Foreground := Preferences.Editor.KeywordForeground;
  Highlighter.KeyAttri.Background := Preferences.Editor.KeywordBackground;
  Highlighter.KeyAttri.Style := Preferences.Editor.KeywordStyle;
  Highlighter.NumberAttri.Foreground := Preferences.Editor.NumberForeground;
  Highlighter.NumberAttri.Background := Preferences.Editor.NumberBackground;
  Highlighter.NumberAttri.Style := Preferences.Editor.NumberStyle;
  Highlighter.StringAttri.Foreground := Preferences.Editor.StringForeground;
  Highlighter.StringAttri.Background := Preferences.Editor.StringBackground;
  Highlighter.StringAttri.Style := Preferences.Editor.StringStyle;
  Highlighter.SymbolAttri.Foreground := Preferences.Editor.SymbolForeground;
  Highlighter.SymbolAttri.Background := Preferences.Editor.SymbolBackground;
  Highlighter.SymbolAttri.Style := Preferences.Editor.SymbolStyle;
  Highlighter.VariableAttri.Foreground := Preferences.Editor.VariableForeground;
  Highlighter.VariableAttri.Background := Preferences.Editor.VariableBackground;
  Highlighter.VariableAttri.Style := Preferences.Editor.VariableStyle;
  LineNumbersAttri.Foreground := Preferences.Editor.LineNumbersForeground;
  LineNumbersAttri.Background := Preferences.Editor.LineNumbersBackground;
  LineNumbersAttri.Style := Preferences.Editor.LineNumbersStyle; FPreviewRefresh();
  FStyles.ItemIndex := 0; FStylesSelectItem(Self, FStyles.Selected, True);
  FUpdateCheckNever.Checked := Preferences.UpdateCheck = utNever;
  FUpdateCheckDaily.Checked := Preferences.UpdateCheck = utDaily;

  PageControl.ActivePage := TSView;
  ActiveControl := FLanguage;
end;

procedure TDOptions.FPreviewRefresh();
begin
  if (LineNumbersAttri.Foreground = clNone) then
    FPreview.Gutter.Font.Color := clWindowText
  else
    FPreview.Gutter.Font.Color := LineNumbersAttri.Foreground;
  if (LineNumbersAttri.Background = clNone) then
    FPreview.Gutter.Color := clBtnFace
  else
    FPreview.Gutter.Color := LineNumbersAttri.Background;
  FPreview.Gutter.Font.Style := LineNumbersAttri.Style;
  Highlighter.DelimitedIdentifierAttri := Highlighter.IdentifierAttri;
  FPreview.Refresh();
end;

procedure TDOptions.FStylesSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  Attri: TSynHighlighterAttributes;
begin
  if (not Assigned(Item)) then
    Attri := nil
  else
    Attri := Attribute(Item.Caption);

  FForeground.Checked := False;
  FBackground.Checked := False;
  FBold.Checked := False;
  FItalic.Checked := False;
  FUnderline.Checked := False;

  if (Selected and Assigned(Attri)) then
  begin
    FForeground.Checked := Attri.Foreground <> clNone;
    FBackground.Checked := Attri.Background <> clNone;
    FBold.Checked := fsBold in Attri.Style;
    FItalic.Checked := fsItalic in Attri.Style;
    FUnderline.Checked := fsUnderline in Attri.Style;
  end;

  FForeground.Enabled := Selected;
  FBackground.Enabled := Selected;
  FBold.Enabled := Selected;
  FItalic.Enabled := Selected;
  FUnderline.Enabled := Selected;

  FBForeground.Enabled := FForeground.Checked;
  FBBackground.Enabled := FBackground.Checked;
end;

procedure TDOptions.FUnderlineClick(Sender: TObject);
var
  Attri: TSynHighlighterAttributes;
begin
  if (Assigned(FStyles.Selected)) then
  begin
    Attri := Attribute(FStyles.Selected.Caption);
    if (FUnderline.Checked) then
      Attri.Style := Attri.Style + [fsUnderline]
    else
      Attri.Style := Attri.Style - [fsUnderline];
    FPreviewRefresh();
  end;
end;

procedure TDOptions.PEditorCurrRowBGColorClick(Sender: TObject);
begin
  FBEditorCurrRowBGColorClick(Sender);
end;

procedure TDOptions.PGridCurrRowBGColorClick(Sender: TObject);
begin
  FBGridCurrRowBGColorClick(Sender);
end;

procedure TDOptions.PGridNullBGColorClick(Sender: TObject);
begin
  if (PGridNullBGColor.Color = clNone) then
    ColorDialog.Color := clWindow
  else
    ColorDialog.Color := PGridNullBGColor.Color;

  if (ColorDialog.Execute()) then
    PGridNullBGColor.Color := ColorDialog.Color;
end;

procedure TDOptions.TSBrowserResize(Sender: TObject);
begin
  FBGridFont.Left := FGridFont.Left + FGridFont.Width;
  FBGridFont.Height := FGridFont.Height;
end;

procedure TDOptions.TSEditorResize(Sender: TObject);
begin
  FBEditorFont.Left := FEditorFont.Left + FEditorFont.Width;
  FBEditorFont.Height := FEditorFont.Height;
end;

procedure TDOptions.TSHighlighterShow(Sender: TObject);
begin
  FPreview.Font := PEditorFont.Font;
  FPreview.Gutter.Font := FPreview.Font;

  FStyles.Selected := FStyles.Items.Item[0];
  FStyles.ItemFocused := FStyles.Selected;
  ActiveControl := FStyles;
end;

procedure TDOptions.TSLogResize(Sender: TObject);
begin
  FBLogFont.Left := FLogFont.Left + FLogFont.Width;
  FBLogFont.Height := FLogFont.Height;
end;

procedure TDOptions.UMChangePreferences(var Message: TMessage);
begin
  Canvas.Font := Font;

  Caption := Preferences.LoadStr(52);

  TSView.Caption := Preferences.LoadStr(491);
  GProgram.Caption := Preferences.LoadStr(52);
  FLLanguage.Caption := Preferences.LoadStr(32) + ':';
  GTabs.Caption := Preferences.LoadStr(851);
  FLTabsVisible.Caption := Preferences.LoadStr(851) + ':';
  FTabsVisible.Caption := LowerCase(Preferences.LoadStr(699));

  TSExtras.Caption := Preferences.LoadStr(73);
  GAssociate.Caption := Preferences.LoadStr(108);
  FLAssociate.Caption := Preferences.LoadStr(566) + ':';
  FAssociateSQL.Caption := '.sql';

  TSBrowser.Caption := Preferences.LoadStr(739);
  GGrid.Caption := Preferences.LoadStr(17);
  FLGridFont.Caption := Preferences.LoadStr(430) + ':';
  FLGridNullValues.Caption := Preferences.LoadStr(498) + ':';
  FGridNullText.Caption := Preferences.LoadStr(499);
  FLMaxColumnWidth.Caption := Preferences.LoadStr(208) + ':';
  FLMaxColumnWidthCharacters.Caption := Preferences.LoadStr(869);
  FLMaxColumnWidthCharacters.Left := FUDMaxColumnWidth.Left + FUDMaxColumnWidth.Width + Canvas.TextWidth('  ');
  FLViewDatas.Caption := Preferences.LoadStr(574) + ':';
  FGridShowMemoContent.Caption := Preferences.LoadStr(575);
  FLGridCurrRowBGColor.Caption := Preferences.LoadStr(784) + ':';

  TSEditor.Caption := Preferences.LoadStr(473);
  GEditor.Caption := Preferences.LoadStr(473);
  FLEditorFont.Caption := Preferences.LoadStr(439) + ':';
  FLEditorCurrRowBGColor.Caption := Preferences.LoadStr(784) + ':';
  FLEditorCurrRowBGColor.Caption := Preferences.LoadStr(784) + ':';
  FLEditorCompletion.Caption := Preferences.LoadStr(660) + ':';
  FEditorCompletionEnabled.Width := FEditorCurrRowBGColorEnabled.Width + Canvas.TextWidth(FEditorCompletionEnabled.Caption);
  FLEditorCompletionTime.Caption := Preferences.LoadStr(843);
  FLEditorCompletionTime.Left := FUDEditorCompletionTime.Left + FUDEditorCompletionTime.Width + Canvas.TextWidth('  ');

  TSHighlighter.Caption := Preferences.LoadStr(528);
  GColors.Caption := Preferences.LoadStr(474);
  FStyles.Items.Clear();
  FStyles.Items.Add().Caption := Preferences.LoadStr(461);
  FStyles.Items.Add().Caption := Preferences.LoadStr(462);
  FStyles.Items.Add().Caption := Preferences.LoadStr(463);
  FStyles.Items.Add().Caption := Preferences.LoadStr(464);
  FStyles.Items.Add().Caption := Preferences.LoadStr(465);
  FStyles.Items.Add().Caption := Preferences.LoadStr(466);
  FStyles.Items.Add().Caption := Preferences.LoadStr(467);
  FStyles.Items.Add().Caption := Preferences.LoadStr(468);
  FStyles.Items.Add().Caption := Preferences.LoadStr(469);
  FStyles.Items.Add().Caption := Preferences.LoadStr(735);
  FStyles.Items.Add().Caption := Preferences.LoadStr(526);
  FStyles.SortType := Comctrls.stText;
  FBold.Caption := Preferences.LoadStr(477);
  FItalic.Caption := Preferences.LoadStr(478);
  FUnderline.Caption := Preferences.LoadStr(479);
  FForeground.Caption := Preferences.LoadStr(475);
  FForeground.Width := Sizer.Width + Canvas.TextWidth(FForeground.Caption);
  FBForeground.Left := FForeground.Left + FForeground.Width + 8;
  FBackground.Caption := Preferences.LoadStr(476);
  FBackground.Width := Sizer.Width + Canvas.TextWidth(FBackground.Caption);
  FBBackground.Left := FBackground.Left + FBackground.Width + 8;

  TSLog.Caption := Preferences.LoadStr(524);
  GLog.Caption := Preferences.LoadStr(524);
  FLLogFont.Caption := Preferences.LoadStr(525) + ':';
  FLLogLinenumbers.Caption := Preferences.LoadStr(527) + ':';
  FLogTime.Caption := Preferences.LoadStr(661);
  FLogResult.Caption := Preferences.LoadStr(662);
  FLLogSize.Caption := Preferences.LoadStr(844) + ':';
  FL2LogSize.Caption := 'KB';

  TSUpdates.Caption := Preferences.LoadStr(592);
  GUpdates.Caption := Preferences.LoadStr(592);
  FLUpdateCheck.Caption := Preferences.LoadStr(509) + ':';
  FUpdateCheckNever.Caption := Preferences.LoadStr(638);
  FUpdateCheckDaily.Caption := Preferences.LoadStr(640);


  FBHelp.Caption := Preferences.LoadStr(167);
  FBOk.Caption := Preferences.LoadStr(29);
  FBCancel.Caption := Preferences.LoadStr(30);
end;

initialization
  FOptions := nil;
end.
