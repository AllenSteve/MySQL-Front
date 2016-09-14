unit fDServer;

interface {********************************************************************}

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, Menus,  ExtCtrls,
  SynEdit, SynMemo,
  Forms_Ext, StdCtrls_Ext, ExtCtrls_Ext,
  fSession,
  fBase;

type
  TDServer = class (TForm_Ext)
    FBCancel: TButton;
    FBHelp: TButton;
    FBShutdown: TButton;
    FCharacterSet: TLabel;
    FComment: TLabel;
    FHost: TLabel;
    FLCharacterSet: TLabel;
    FLComment: TLabel;
    FLHost: TLabel;
    FLibVersion: TLabel;
    FLLibVersion: TLabel;
    FLUptime: TLabel;
    FLUser: TLabel;
    FLVersion: TLabel;
    FPlugins: TListView;
    FSlowSQLLog: TSynMemo;
    FSQLLog: TSynMemo;
    FStartup: TSynMemo;
    FUptime: TLabel;
    FUser: TLabel;
    FVersion: TLabel;
    GConnection: TGroupBox_Ext;
    GServer: TGroupBox_Ext;
    GServiceServer: TGroupBox_Ext;
    msCopy: TMenuItem;
    msCut: TMenuItem;
    msDelete: TMenuItem;
    MSource: TPopupMenu;
    msPaste: TMenuItem;
    msSelectAll: TMenuItem;
    msUndo: TMenuItem;
    N1: TMenuItem;
    N2: TMenuItem;
    PageControl: TPageControl;
    TSBasics: TTabSheet;
    TSExtras: TTabSheet;
    TSPlugins: TTabSheet;
    TSSlowSQLLog: TTabSheet;
    TSSQLLog: TTabSheet;
    TSStartup: TTabSheet;
    PSQLWait: TPanel_Ext;
    FLThreadId: TLabel;
    FThreadId: TLabel;
    procedure FBFlushHostsClick(Sender: TObject);
    procedure FBHelpClick(Sender: TObject);
    procedure FBShutdownClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ListViewColumnClick(Sender: TObject; Column: TListColumn);
    procedure ListViewCompare(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
    procedure ListViewDblClick(Sender: TObject);
    procedure ListViewKeyPress(Sender: TObject; var Key: Char);
    procedure ListViewResize(Sender: TObject);
    procedure TSExtrasShow(Sender: TObject);
    procedure TSPluginsShow(Sender: TObject);
    procedure TSSlowSQLLogShow(Sender: TObject);
    procedure TSSQLLogShow(Sender: TObject);
    procedure TSStartupShow(Sender: TObject);
  private
    procedure Built();
    procedure FormSessionEvent(const Event: TSSession.TEvent);
    procedure ListViewShowSortDirection(const ListView: TListView);
    procedure UMChangePreferences(var Message: TMessage); message UM_CHANGEPREFERENCES;
  public
    Session: TSSession;
    Tab: TCustomFrame;
    function Execute(): Boolean;
  end;

function DServer(): TDServer;

implementation {***************************************************************}

{$R *.dfm}

uses
  Math, CommCtrl, StrUtils,
  MySQLConsts,
  CommCtrl_Ext,
  MySQLDB, SQLUtils,
  fPreferences;

var
  FServer: TDServer;

function DServer(): TDServer;
begin
  if (not Assigned(FServer)) then
  begin
    Application.CreateForm(TDServer, FServer);
    FServer.Perform(UM_CHANGEPREFERENCES, 0, 0);
  end;

  Result := FServer;
end;

{TDServer *********************************************************************}

procedure TDServer.Built();
begin
  PageControl.Visible := True;
  PSQLWait.Visible := not PageControl.Visible;
end;

function TDServer.Execute(): Boolean;
begin
  ShowModal();
  Result := ModalResult = mrOk;
end;

procedure TDServer.FBFlushHostsClick(Sender: TObject);
begin
  Session.FlushHosts();
end;

procedure TDServer.FBHelpClick(Sender: TObject);
begin
  Application.HelpContext(HelpContext);
end;

procedure TDServer.FBShutdownClick(Sender: TObject);
begin
  if (MsgBox(Preferences.LoadStr(679, Session.Caption), Preferences.LoadStr(101), MB_YESNOCANCEL + MB_ICONQUESTION) = IDYES) then
    if (Boolean(SendMessage(Tab.Handle, UM_CLOSE_TAB_QUERY, 0, 0))) then
      if (Session.Connection.Shutdown()) then
      begin
        PostMessage(TForm(Tab.Owner).Handle, UM_CLOSE_TAB, 0, LPARAM(Tab));
        FBCancel.Click();
      end;

  ActiveControl := FBCancel;
end;

procedure TDServer.FormSessionEvent(const Event: TSSession.TEvent);
begin
  if ((Event.EventType = etItemsValid) and (Assigned(Session.Plugins) and (Event.SItems = Session.Plugins))
    and (not Assigned(Session.Plugins) or Session.Plugins.Valid)) then
    Built()
  else if ((Event.EventType = etAfterExecuteSQL) and (Event.Session.Connection.ErrorCode <> 0)) then
  begin
    PageControl.Visible := True;
    PSQLWait.Visible := not PageControl.Visible;
  end;
end;

procedure TDServer.FormCreate(Sender: TObject);
begin
  Preferences.SmallImages.GetIcon(iiServer, Icon);

  FStartup.Highlighter := MainHighlighter;
  FPlugins.SmallImages := Preferences.SmallImages;

  FSQLLog.Highlighter := MainHighlighter;
  FSlowSQLLog.Highlighter := MainHighlighter;

  Constraints.MinWidth := Width;
  Constraints.MinHeight := Height;

  BorderStyle := bsSizeable;

  PageControl.ActivePage := TSBasics;
end;

procedure TDServer.FormHide(Sender: TObject);
begin
  Session.UnRegisterEventProc(FormSessionEvent);

  Preferences.Server.Width := Width;
  Preferences.Server.Height := Height;

  FSQLLog.Lines.Clear();

  FPlugins.DisableAlign(); FPlugins.Items.BeginUpdate();
  FPlugins.Items.Clear();
  FPlugins.EnableAlign(); FPlugins.Items.EndUpdate();
end;

procedure TDServer.FormShow(Sender: TObject);
var
  List: TList;
begin
  Session.RegisterEventProc(FormSessionEvent);

  if ((Preferences.Server.Width >= Width) and (Preferences.Server.Height >= Height)) then
  begin
    Width := Preferences.Server.Width;
    Height := Preferences.Server.Height;
  end;

  Caption := Preferences.LoadStr(842, Session.Caption);

  FHost.Caption := Session.Connection.HostInfo;
  FVersion.Caption := Session.Connection.ServerVersionStr;
  FComment.Visible := Assigned(Session.VariableByName('version_comment'));
  FLComment.Visible := FComment.Visible;
  if (FComment.Visible) then
    FComment.Caption := Session.VariableByName('version_comment').Value;
  if (Session.Connection.LibraryType = ltDLL) then
    FLibVersion.Caption := Session.Connection.Lib.VersionStr
  else
    FLibVersion.Caption := Preferences.LoadStr(649);
  if (Session.CurrentUser = '') then
    FUser.Caption := '???'
  else
    FUser.Caption := Session.CurrentUser;
  FCharacterSet.Caption := Session.Connection.Charset;
  FThreadId.Visible := Session.Connection.ThreadId > 0;
  FLThreadId.Visible := FThreadId.Visible;
  FThreadId.Caption := IntToStr(Session.Connection.ThreadId);
  FUptime.Caption := '???';

  FStartup.Lines.Clear();

  TSSQLLog.TabVisible := Session.LogActive;
  TSSlowSQLLog.TabVisible := Session.SlowLogActive;
  TSStartup.TabVisible := Assigned(Session.VariableByName('init_connect')) and (Session.VariableByName('init_connect').Value <> '');
  TSPlugins.TabVisible := Assigned(Session.Plugins);

  PageControl.ActivePage := TSBasics;

  List := TList.Create();
  if (not Session.Stati.Valid) then
    List.Add(Session.Stati);
  if (Assigned(Session.Plugins) and not Session.Plugins.Valid) then
    List.Add(Session.Plugins);
  PageControl.Visible := Session.Update(List);
  PSQLWait.Visible := not PageControl.Visible;
  List.Free();

  ActiveControl := FBCancel;
end;

procedure TDServer.ListViewColumnClick(Sender: TObject; Column: TListColumn);
var
  I: Integer;
  ListView: TListView;
begin
  if (Sender is TListView) then
  begin
    ListView := TListView(Sender);

    for I := 0 to ListView.Columns.Count - 1 do
      if (ListView.Columns[I] <> Column) then
        ListView.Columns[I].Tag := 0
      else if (ListView.Columns[I].Tag < 0) then
        ListView.Columns[I].Tag := 1
      else if (ListView.Columns[I].Tag > 0) then
        ListView.Columns[I].Tag := -1
      else
        ListView.Columns[I].Tag := 1;

    ListView.Tag := Column.Index;
    ListView.AlphaSort();

    ListViewShowSortDirection(ListView);
  end;
end;

procedure TDServer.ListViewCompare(Sender: TObject; Item1, Item2: TListItem;
  Data: Integer; var Compare: Integer);
var
  Column: TListColumn;
  ListView: TListView;
begin
  ListView := TListView(Sender);
  Column := ListView.Columns[ListView.Tag];

  if (Column.Index = 0) then
    Compare := Sign(lstrcmpi(PChar(Item1.Caption), PChar(Item2.Caption)))
  else
    Compare := Sign(lstrcmpi(PChar(Item1.SubItems[Column.Index - 1]), PChar(Item2.SubItems[Column.Index - 1])));

  if (Column.Tag < 0) then
    Compare := - Compare;
end;

procedure TDServer.ListViewDblClick(Sender: TObject);
var
  I: Integer;
  ListView: TListView;
  MenuItem: TMenuItem;
begin
  MenuItem := nil;

  ListView := TListView(Sender);
  if (Assigned(ListView.PopupMenu)) then
    for I := 0 to ListView.PopupMenu.Items.Count - 1 do
      if (ListView.PopupMenu.Items.Items[I].Default) and (ListView.PopupMenu.Items.Items[I].Enabled) then
        MenuItem := ListView.PopupMenu.Items.Items[I];
  if (Assigned(MenuItem) and Assigned(ListView.Selected)) then MenuItem.Click();
end;

procedure TDServer.ListViewKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key = #13) then
    ListViewDblClick(Sender);
end;

procedure TDServer.ListViewResize(Sender: TObject);
begin
  if (Sender is TListView) then
    ListViewShowSortDirection(TListView(Sender));
end;

procedure TDServer.ListViewShowSortDirection(const ListView: TListView);
var
  Column: TListColumn;
  HDItem: THDItem;
  I: Integer;
begin
  Column := ListView.Columns[ListView.Tag];

  HDItem.Mask := HDI_FORMAT;
  for I := 0 to ListView.Columns.Count - 1 do
    if (BOOL(SendMessage(ListView_GetHeader(ListView.Handle), HDM_GETITEM, I, LParam(@HDItem)))) then
    begin
      case (ListView.Columns[I].Tag) of
        -1: HDItem.fmt := HDItem.fmt and not HDF_SORTUP or HDF_SORTDOWN;
        1: HDItem.fmt := HDItem.fmt and not HDF_SORTDOWN or HDF_SORTUP;
        else HDItem.fmt := HDItem.fmt and not HDF_SORTUP and not HDF_SORTDOWN;
      end;
      SendMessage(ListView_GetHeader(ListView.Handle), HDM_SETITEM, I, LParam(@HDItem));
    end;

  if ((ComCtl32MajorVersion >= 6) and not CheckWin32Version(6, 1)) then
    SendMessage(ListView.Handle, LVM_SETSELECTEDCOLUMN, Column.Index, 0);
end;

procedure TDServer.TSExtrasShow(Sender: TObject);
begin
  FUptime.Caption := SysUtils.DateTimeToStr(Session.StartTime, LocaleFormatSettings);

  FBShutdown.Enabled := Session.Connection.CanShutdown and (not Assigned(Session.UserRights) or Session.UserRights.RShutdown);
end;

procedure TDServer.TSPluginsShow(Sender: TObject);
var
  I: Integer;
  Item: TListItem;
begin
  if (FPlugins.Items.Count = 0) then
  begin
    FPlugins.DisableAlign(); FPlugins.Items.BeginUpdate();

    for I := 0 to Session.Plugins.Count - 1 do
    begin
      Item := FPlugins.Items.Add();
      Item.Caption := Session.Plugins[I].Name;
      Item.ImageIndex := iiPlugin;
      Item.SubItems.Add(Session.Plugins[I].Comment);
    end;
    if (FPlugins.Items.Count = 0) then
      FPlugins.Selected := nil
    else
      FPlugins.Selected := FPlugins.Items[0];
    FPlugins.ItemFocused := FPlugins.Selected;

    FPlugins.Columns[0].Tag := 1;
    FPlugins.Columns[1].Tag := 0;
    ListViewShowSortDirection(FPlugins);

    FPlugins.EnableAlign(); FPlugins.Items.EndUpdate();

    FPlugins.Columns[0].Width := FPlugins.ClientWidth div 2;
    FPlugins.Columns[1].Width := FPlugins.ClientWidth - FPlugins.Columns[0].Width;
  end;
end;

procedure TDServer.TSSlowSQLLogShow(Sender: TObject);
begin
  if (FSlowSQLLog.Lines.Text = '') then
  begin
    FSlowSQLLog.Text := Session.SlowLog;
    SendMessage(FSlowSQLLog.Handle, WM_VSCROLL, SB_BOTTOM, 0);
  end
end;

procedure TDServer.TSSQLLogShow(Sender: TObject);
begin
  if (FSQLLog.Lines.Text = '') then
  begin
    FSQLLog.Text := Session.Log;
    SendMessage(FSQLLog.Handle, WM_VSCROLL, SB_BOTTOM, 0);
  end
end;

procedure TDServer.TSStartupShow(Sender: TObject);
begin
  if (FStartup.Lines.Count = 0) then
    FStartup.Text := Trim(Session.VariableByName('init_connect').Value) + #13#10;
end;

procedure TDServer.UMChangePreferences(var Message: TMessage);
begin
  PSQLWait.Caption := Preferences.LoadStr(882) + '...';

  TSBasics.Caption := Preferences.LoadStr(108);
  GServer.Caption := Preferences.LoadStr(906);
  FLVersion.Caption := Preferences.LoadStr(169) + ':';
  FLComment.Caption := Preferences.LoadStr(111) + ':';
  GConnection.Caption := Preferences.LoadStr(486);
  FLHost.Caption := Preferences.LoadStr(305) + ':';
  FLLibVersion.Caption := Preferences.LoadStr(568) + ':';
  FLUser.Caption := Preferences.LoadStr(561) + ':';
  FLCharacterSet.Caption := Preferences.LoadStr(682) + ':';
  FLThreadId.Caption := Preferences.LoadStr(269) + ':';

  TSSQLLog.Caption := Preferences.LoadStr(11);
  FSQLLog.Font.Name := Preferences.SQLFontName;
  FSQLLog.Font.Style := Preferences.SQLFontStyle;
  FSQLLog.Font.Color := Preferences.SQLFontColor;
  FSQLLog.Font.Size := Preferences.SQLFontSize;
  FSQLLog.Font.Charset := Preferences.SQLFontCharset;
  if (Preferences.Editor.LineNumbersForeground = clNone) then
    FSQLLog.Gutter.Font.Color := clWindowText
  else
    FSQLLog.Gutter.Font.Color := Preferences.Editor.LineNumbersForeground;
  if (Preferences.Editor.LineNumbersBackground = clNone) then
    FSQLLog.Gutter.Color := clBtnFace
  else
    FSQLLog.Gutter.Color := Preferences.Editor.LineNumbersBackground;
  FSQLLog.Gutter.Font.Style := Preferences.Editor.LineNumbersStyle;

  TSSlowSQLLog.Caption := Preferences.LoadStr(847);
  FSlowSQLLog.Font.Name := Preferences.SQLFontName;
  FSlowSQLLog.Font.Style := Preferences.SQLFontStyle;
  FSlowSQLLog.Font.Color := Preferences.SQLFontColor;
  FSlowSQLLog.Font.Size := Preferences.SQLFontSize;
  FSlowSQLLog.Font.Charset := Preferences.SQLFontCharset;
  if (Preferences.Editor.LineNumbersForeground = clNone) then
    FSlowSQLLog.Gutter.Font.Color := clWindowText
  else
    FSlowSQLLog.Gutter.Font.Color := Preferences.Editor.LineNumbersForeground;
  if (Preferences.Editor.LineNumbersBackground = clNone) then
    FSlowSQLLog.Gutter.Color := clBtnFace
  else
    FSlowSQLLog.Gutter.Color := Preferences.Editor.LineNumbersBackground;
  FSlowSQLLog.Gutter.Font.Style := Preferences.Editor.LineNumbersStyle;

  TSStartup.Caption := Preferences.LoadStr(805);
  FStartup.Font.Name := Preferences.SQLFontName;
  FStartup.Font.Style := Preferences.SQLFontStyle;
  FStartup.Font.Color := Preferences.SQLFontColor;
  FStartup.Font.Size := Preferences.SQLFontSize;
  FStartup.Font.Charset := Preferences.SQLFontCharset;
  if (Preferences.Editor.LineNumbersForeground = clNone) then
    FStartup.Gutter.Font.Color := clWindowText
  else
    FStartup.Gutter.Font.Color := Preferences.Editor.LineNumbersForeground;
  if (Preferences.Editor.LineNumbersBackground = clNone) then
    FStartup.Gutter.Color := clBtnFace
  else
    FStartup.Gutter.Color := Preferences.Editor.LineNumbersBackground;
  FStartup.Gutter.Font.Style := Preferences.Editor.LineNumbersStyle;

  TSPlugins.Caption := Preferences.LoadStr(811);
  FPlugins.Columns[0].Caption := Preferences.LoadStr(35);
  FPlugins.Columns[1].Caption := Preferences.LoadStr(111);

  TSExtras.Caption := Preferences.LoadStr(73);
  GServiceServer.Caption := Preferences.LoadStr(37);
  FLUptime.Caption := Preferences.LoadStr(520) + ':';
  FBShutdown.Caption := Preferences.LoadStr(323);

  msUndo.Action := MainAction('aEUndo'); msCut.ShortCut := 0;
  msCut.Action := MainAction('aECut'); msCut.ShortCut := 0;
  msCopy.Action := MainAction('aECopy'); msCopy.ShortCut := 0;
  msPaste.Action := MainAction('aEPaste'); msPaste.ShortCut := 0;
  msDelete.Action := MainAction('aEDelete'); msDelete.ShortCut := 0;
  msSelectAll.Action := MainAction('aESelectAll'); msSelectAll.ShortCut := 0;

  FBHelp.Caption := Preferences.LoadStr(167);
  FBCancel.Caption := Preferences.LoadStr(231);
end;

initialization
  FServer := nil;
end.
