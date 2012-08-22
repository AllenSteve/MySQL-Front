unit fPreferences;

interface {********************************************************************}

uses
  Controls, Forms, Graphics, Windows, XMLDoc, XMLIntf,
  ExtCtrls, Classes, SysUtils, Registry, IniFiles;

type
  TPPreferences = class;

  TPImportType = (itInsert, itReplace, itUpdate);
  TPSeparatorType = (stTab, stChar);
  TPUpdateCheckType = (utNever, utDaily);

  TMRUList = class
  private
    FMaxCount: Integer;
    FValues: array of string;
    function GetCount(): Integer;
    function GetValue(Index: Integer): string;
  public
    property Count: Integer read GetCount;
    property MaxCount: Integer read FMaxCount;
    property Values[Index: Integer]: string read GetValue; default;
    procedure Add(const Value: string); virtual;
    procedure Assign(const Source: TMRUList); virtual;
    procedure Clear(); virtual;
    constructor Create(const AMaxCount: Integer); virtual;
    procedure Delete(const Index: Integer);
    destructor Destroy(); override;
    function IndexOf(const Value: string): Integer; virtual;
    procedure LoadFromXML(const XML: IXMLNode; const NodeName: string); virtual;
    procedure SaveToXML(const XML: IXMLNode; const NodeName: string); virtual;
  end;

  TPWindow = class
  private
    FPreferences: TPPreferences;
  protected
    property Preferences: TPPreferences read FPreferences;
    procedure LoadFromXML(const XML: IXMLNode); virtual;
    procedure SaveToXML(const XML: IXMLNode); virtual;
  public
    Height: Integer;
    Width: Integer;
    constructor Create(const APreferences: TPPreferences); virtual;
  end;

  TPDatabase = class(TPWindow)
  end;

  TPDatabases = class
  public
    Height: Integer;
    Left: Integer;
    Top: Integer;
    Width: Integer;
    constructor Create(const APreferences: TPPreferences); virtual;
  end;

  TPEditor = class
  private
    FPreferences: TPPreferences;
  protected
    procedure LoadFromXML(const XML: IXMLNode); virtual;
    procedure SaveToXML(const XML: IXMLNode); virtual;
  public
    AutoIndent: Boolean;
    CodeCompletition: Boolean;
    CodeCompletionTime: Integer;
    ConditionalCommentForeground, ConditionalCommentBackground: TColor;
    ConditionalCommentStyle: TFontStyles;
    CommentForeground, CommentBackground: TColor;
    CommentStyle: TFontStyles;
    CurrRowBGColorEnabled: Boolean;
    CurrRowBGColor: TColor;
    DataTypeForeground, DataTypeBackground: TColor;
    DataTypeStyle: TFontStyles;
    FunctionForeground, FunctionBackground: TColor;
    FunctionStyle: TFontStyles;
    IdentifierForeground, IdentifierBackground: TColor;
    IdentifierStyle: TFontStyles;
    KeywordForeground, KeywordBackground: TColor;
    KeywordStyle: TFontStyles;
    NumberForeground, NumberBackground: TColor;
    NumberStyle: TFontStyles;
    LineNumbers: Boolean;
    LineNumbersForeground, LineNumbersBackground: TColor;
    LineNumbersStyle: TFontStyles;
    RightEdge: Integer;
    StringForeground, StringBackground: TColor;
    StringStyle: TFontStyles;
    SymbolForeground, SymbolBackground: TColor;
    SymbolStyle: TFontStyles;
    TabAccepted: Boolean;
    TabToSpaces: Boolean;
    TabWidth: Integer;
    VariableForeground, VariableBackground: TColor;
    VariableStyle: TFontStyles;
    WordWrap: Boolean;
    constructor Create(const APreferences: TPPreferences); virtual;
  end;

  TPEvent = class(TPWindow)
  end;

  TPExport = class
  private
    FPreferences: TPPreferences;
  protected
    procedure LoadFromXML(const XML: IXMLNode); virtual;
    procedure SaveToXML(const XML: IXMLNode); virtual;
  public
    CSVHeadline: Boolean;
    CSVQuote: Integer;
    CSVQuoteChar: string;
    CSVSeparator: string;
    CSVSeparatorType: TPSeparatorType;
    ExcelHeadline: Boolean;
    HTMLData: Boolean;
    HTMLStructure: Boolean;
    SQLCreateDatabase: Boolean;
    SQLData: Boolean;
    SQLDisableKeys: Boolean;
    SQLDropBeforeCreate: Boolean;
    SQLReplaceData: Boolean;
    SQLStructure: Boolean;
    SQLUseDatabase: Boolean;
    constructor Create(const APreferences: TPPreferences); virtual;
  end;

  TPField = class(TPWindow)
  end;

  TPFind = class(TPWindow)
  type
    TOption = (foMatchCase, foWholeValue, foRegExpr);
    TOptions = set of TOption;
  protected
    procedure LoadFromXML(const XML: IXMLNode); override;
    procedure SaveToXML(const XML: IXMLNode); override;
  public
    FindTextMRU: TMRUList;
    Left: Integer;
    Options: TOptions;
    Top: Integer;
    constructor Create(const APreferences: TPPreferences); override;
    destructor Destroy(); override;
  end;

  TPHost = class(TPWindow)
  end;

  TPForeignKey = class(TPWindow)
  end;

  TPImport = class
  private
    FPreferences: TPPreferences;
  protected
    procedure LoadFromXML(const XML: IXMLNode); virtual;
    procedure SaveToXML(const XML: IXMLNode); virtual;
  public
    CSVHeadline: Boolean;
    CSVQuote: Integer;
    CSVQuoteChar: string;
    CSVSeparator: string;
    CSVSeparatorType: TPSeparatorType;
    ExcelHeadline: Boolean;
    ImportType: TPImportType;
    ODBCData: Boolean;
    ODBCObjects: Boolean;
    ODBCRowType: Integer;
    SaveErrors: Boolean;
    constructor Create(const APreferences: TPPreferences); virtual;
  end;

  TPIndex = class(TPWindow)
  end;

  TPODBC = class(TPWindow)
  public
    Left: Integer;
    Top: Integer;
    constructor Create(const APreferences: TPPreferences); override;
  end;

  TPPaste = class
  private
    FPreferences: TPPreferences;
  protected
    property Preferences: TPPreferences read FPreferences;
    procedure LoadFromXML(const XML: IXMLNode); virtual;
    procedure SaveToXML(const XML: IXMLNode); virtual;
  public
    Data: Boolean;
    constructor Create(const APreferences: TPPreferences); virtual;
  end;

  TPReplace = class(TPWindow)
  type
    TOption = (roMatchCase, roWholeValue, roRegExpr);
    TOptions = set of TOption;
  protected
    procedure LoadFromXML(const XML: IXMLNode); override;
    procedure SaveToXML(const XML: IXMLNode); override;
  public
    FindTextMRU: TMRUList;
    ReplaceTextMRU: TMRUList;
    Backup: Boolean;
    Left: Integer;
    Options: TOptions;
    Top: Integer;
    constructor Create(const APreferences: TPPreferences); override;
    destructor Destroy(); override;
  end;

  TPRoutine = class(TPWindow)
  end;

  TPServer = class(TPWindow)
  public
    Left: Integer;
    Top: Integer;
    constructor Create(const APreferences: TPPreferences); override;
  end;

  TPSQLHelp = class(TPWindow)
  protected
    procedure LoadFromXML(const XML: IXMLNode); override;
    procedure SaveToXML(const XML: IXMLNode); override;
  public
    Left: Integer;
    Top: Integer;
    constructor Create(const APreferences: TPPreferences); override;
  end;

  TPAccounts = class(TPWindow)
  protected
    procedure LoadFromXML(const XML: IXMLNode); override;
    procedure SaveToXML(const XML: IXMLNode); override;
  public
    SelectOrder: Integer;
    constructor Create(const APreferences: TPPreferences); override;
  end;

  TPStatement = class(TPWindow)
  end;

  TPTable = class(TPWindow)
  end;

  TPTableService = class(TPWindow)
  protected
    procedure LoadFromXML(const XML: IXMLNode); override;
    procedure SaveToXML(const XML: IXMLNode); override;
  public
    Analyze: Boolean;
    Check: Boolean;
    Flush: Boolean;
    Optimize: Boolean;
    Repair: Boolean;
    constructor Create(const APreferences: TPPreferences); override;
  end;

  TPTransfer = class(TPWindow)
  public
    Left: Integer;
    Top: Integer;
  end;

  TPTrigger = class(TPWindow)
  end;

  TPUser = class(TPWindow)
  end;

  TPView = class(TPWindow)
  end;

  TPLanguage = class(TMemIniFile)
  private
    FActiveQueryBuilderLanguageName: string;
    FLanguageId: Integer;
    FStrs: array of string;
    function GetStr(Index: Integer): string;
  protected
    property Strs[Index: Integer]: string read GetStr;
  public
    property ActiveQueryBuilderLanguageName: string read FActiveQueryBuilderLanguageName;
    property LanguageId: Integer read FLanguageId;
    constructor Create(const FileName: string); reintroduce;
    destructor Destroy(); override;
  end;

  TPPreferences = class(TRegistry)
  type
    TToolbarTabs = set of (ttObjects, ttBrowser, ttIDE, ttBuilder, ttEditor, ttDiagram);
  private
    FInternetAgent: string;
    FLanguage: TPLanguage;
    FLargeImages: TImageList;
    FSmallImages: TImageList;
    FVerMajor, FVerMinor, FVerPatch, FVerBuild: Integer;
    FXMLDocument: IXMLDocument;
    OldAssociateSQL: Boolean;
    procedure LoadFromRegistry();
    function GetFilename(): TFileName;
    function GetLanguage(): TPLanguage;
    function GetLanguagePath(): TFileName;
    function GetVersion(var VerMajor, VerMinor, VerPatch, VerBuild: Integer): Boolean;
    function GetVersionInfo(): Integer;
    function GetVersionStr(): string;
    function GetXML(): IXMLNode;
  protected
    KeyBase: string;
    property Filename: TFileName read GetFilename;
    property XML: IXMLNode read GetXML;
  public
    Database: TPDatabase;
    Databases: TPDatabases;
    Editor: TPEditor;
    Event: TPEvent;
    Export: TPExport;
    Field: TPField;
    Find: TPFind;
    ForeignKey: TPForeignKey;
    Host: TPHost;
    Import: TPImport;
    Index: TPIndex;
    ODBC: TPODBC;
    Paste: TPPaste;
    Replace: TPReplace;
    Routine: TPRoutine;
    Server: TPServer;
    SQLHelp: TPSQLHelp;
    Accounts: TPAccounts;
    Statement: TPStatement;
    Table: TPTable;
    TableService: TPTableService;
    Transfer: TPTransfer;
    Trigger: TPTrigger;
    User: TPUser;
    View: TPView;
    SoundFileNavigating: string;
    LanguageFilename: TFileName;
    WindowState: TWindowState;
    Left, Top, Width, Height: Integer;
    AddressBarVisible: Boolean;
    GridFontName: TFontName;
    GridFontStyle: TFontStyles;
    GridFontColor: TColor;
    GridFontSize, GridFontCharset: Integer;
    GridMaxColumnWidth: Integer;
    GridRowBGColorEnabled: Boolean;
    GridCurrRowBGColorEnabled: Boolean;
    GridCurrRowBGColor: TColor;
    GridNullBGColorEnabled: Boolean;
    GridNullBGColor: TColor;
    GridNullText: Boolean;
    GridShowMemoContent: Boolean;
    GridDefaultSorting: Boolean;
    InstallDate: TDateTime;
    DonationVisible: Boolean;
    SQLFontName: TFontName;
    SQLFontStyle: TFontStyles;
    SQLFontColor: TColor;
    SQLFontSize, SQLFontCharset: Integer;
    LogFontName: TFontName;
    LogFontStyle: TFontStyles;
    LogFontColor: TColor;
    LogFontSize, LogFontCharset: Integer;
    LogHighlighting: Boolean;
    LogTime: Boolean;
    LogResult: Boolean;
    LogSize: Integer;
    Path: TFileName;
    UserPath: TFileName;
    AssociateSQL: Boolean;
    TabsVisible: Boolean;
    ToolbarTabs: TToolbarTabs;
    UpdateCheck: TPUpdateCheckType;
    UpdateChecked: TDateTime;
    SetupProgram: TFileName;
    SetupProgramInstalled: Boolean;
    property InternetAgent: string read FInternetAgent;
    property Language: TPLanguage read GetLanguage;
    property LanguagePath: TFileName read GetLanguagePath;
    property LargeImages: TImageList read FLargeImages;
    property SmallImages: TImageList read FSmallImages;
    property VerMajor: Integer read FVerMajor;
    property VerMinor: Integer read FVerMinor;
    property VerPatch: Integer read FVerPatch;
    property VerBuild: Integer read FVerBuild;
    property Version: Integer read GetVersionInfo;
    property VersionStr: string read GetVersionStr;
    constructor Create(); virtual;
    destructor Destroy(); override;
    procedure LoadFromXML(); virtual;
    function LoadStr(const Index: Integer; const Param1: string = ''; const Param2: string = ''; const Param3: string = ''): string; overload; virtual;
    procedure SaveToRegistry(); virtual;
    procedure SaveToXML(); virtual;
  end;

function EncodeVersion(const AMajor, AMinor, APatch, ABuild: Integer): Integer;
function XMLNode(const XML: IXMLNode; const Path: string; const NodeAutoCreate: Boolean = False): IXMLNode; overload;

function IsConnectedToInternet(): Boolean;
function VersionStrToVersion(VersionStr: string): Integer;
function CopyDir(const fromDir, toDir: string): Boolean;

var
  Preferences: TPPreferences;
  FileFormatSettings: TFormatSettings;

implementation {***************************************************************}

uses
  Consts, CommCtrl, SHFolder, WinInet, ShellAPI, ImgList, ShlObj,
  StrUtils, Math;

const
  INTERNET_CONNECTION_CONFIGURED = $40;

function VersionStrToVersion(VersionStr: string): Integer;
begin
  if (Pos('.', VersionStr) = 0) then
    Result := StrToInt(VersionStr) * 10000
  else
    Result := StrToInt(copy(VersionStr, 1, Pos('.', VersionStr) - 1)) * 10000
      + VersionStrToVersion(Copy(VersionStr, Pos('.', VersionStr) + 1, Length(VersionStr) - Pos('.', VersionStr))) div 100;
end;

function IsConnectedToInternet(): Boolean;
var
  ConnectionTypes: DWord;
begin
  ConnectionTypes := INTERNET_CONNECTION_MODEM or INTERNET_CONNECTION_LAN or INTERNET_CONNECTION_PROXY or INTERNET_CONNECTION_CONFIGURED;
  Result := InternetGetConnectedState(@ConnectionTypes, 0);
end;

function CopyDir(const fromDir, toDir: string): Boolean;
var
  fos: TSHFileOpStruct;
begin
  ZeroMemory(@fos, SizeOf(fos));
  with fos do
  begin
    wFunc  := FO_COPY;
    fFlags := FOF_FILESONLY;
    pFrom  := PChar(fromDir + #0);
    pTo    := PChar(toDir)
  end;
  Result := (0 = ShFileOperation(fos));
end;

function TryStrToWindowState(const Str: string; var WindowState: TWindowState): Boolean;
begin
  Result := True;
  if (UpperCase(Str) = 'NORMAL') then WindowState := wsNormal
  else if (UpperCase(Str) = 'MINIMIZED') then WindowState := wsMinimized
  else if (UpperCase(Str) = 'MAXIMIZED') then WindowState := wsMaximized
  else Result := False;
end;

function WindowStateToStr(const WindowState: TWindowState): string;
begin
  case (WindowState) of
    wsMaximized: Result := 'Maximized';
    else Result := 'Normal';
  end;
end;

function TryStrToQuote(const Str: string; var Quote: Integer): Boolean;
begin
  Result := True;
  if (UpperCase(Str) = 'NOTHING') then Quote := 0
  else if (UpperCase(Str) = 'STRINGS') then Quote := 1
  else if (UpperCase(Str) = 'ALL') then Quote := 2
  else Result := False;
end;

function QuoteToStr(const Quote: Integer): string;
begin
  case Quote of
    1: Result := 'Stings';
    2: Result := 'All';
    else Result := 'Nothing';
  end;
end;

function TryStrToSeparatorType(const Str: string; var SeparatorType: TPSeparatorType): Boolean;
begin
  Result := True;
  if (UpperCase(Str) = 'STANDARD') then SeparatorType := stChar
  else if (UpperCase(Str) = 'TAB') then SeparatorType := stTab
  else Result := False;
end;

function SeparatorTypeToStr(const SeparatorType: TPSeparatorType): string;
begin
  case (SeparatorType) of
    stTab: Result := 'Tab';
    else Result := 'Standard';
  end;
end;

function TryStrToImportType(const Str: string; var ImportTypeType: TPImportType): Boolean;
begin
  Result := True;
  if (UpperCase(Str) = 'INSERT') then ImportTypeType := itInsert
  else if (UpperCase(Str) = 'REPLACE') then ImportTypeType := itReplace
  else if (UpperCase(Str) = 'UPDATE') then ImportTypeType := itUpdate
  else Result := False;
end;

function ImportTypeToStr(const ImportTypeType: TPImportType): string;
begin
  case (ImportTypeType) of
    itReplace: Result := 'Replace';
    itUpdate: Result := 'Update';
    else Result := 'Insert';
  end;
end;

function StrToStyle(const Str: string): TFontStyles;
begin
  Result := [];
  if (Pos('BOLD', UpperCase(Str)) > 0) then Result := Result + [fsBold];
  if (Pos('ITALIC', UpperCase(Str)) > 0) then Result := Result + [fsItalic];
  if (Pos('UNDERLINE', UpperCase(Str)) > 0) then Result := Result + [fsUnderline];
  if (Pos('STRIKEOUT', UpperCase(Str)) > 0) then Result := Result + [fsStrikeOut];
end;

function StyleToStr(const Style: TFontStyles): string;
begin
  Result := '';

  if (fsBold in Style) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'Bold'; end;
  if (fsItalic in Style) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'Italic'; end;
  if (fsUnderline in Style) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'Underline'; end;
  if (fsStrikeOut in Style) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'StrikeOut'; end;
end;

function StrToFindOptions(const Str: string): TPFind.TOptions;
begin
  Result := [];
  if (Pos('MATCHCASE', UpperCase(Str)) > 0) then Result := Result + [foMatchCase];
  if (Pos('WHOLEWORD', UpperCase(Str)) > 0) then Result := Result + [foWholeValue];
  if (Pos('REGEXPR', UpperCase(Str)) > 0) then Result := Result + [foRegExpr];
end;

function FindOptionsToStr(const FindOptions: TPFind.TOptions): string;
begin
  Result := '';

  if (foMatchCase in FindOptions) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'MatchCase'; end;
  if (foWholeValue in FindOptions) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'WholeValue'; end;
  if (foRegExpr in FindOptions) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'RegExpr'; end;
end;

function TryStrToUpdateCheck(const Str: string; var UpdateCheckType: TPUpdateCheckType): Boolean;
begin
  Result := True;
  if (UpperCase(Str) = 'NEVER') then UpdateCheckType := utNever
  else if (UpperCase(Str) = 'DAILY') then UpdateCheckType := utDaily
  else Result := False;
end;

function UpdateCheckToStr(const UpdateCheck: TPUpdateCheckType): string;
begin
  case UpdateCheck of
    utDaily: Result := 'Daily';
    else Result := 'Never';
  end;
end;

function TryStrToRowType(const Str: string; var RowType: Integer): Boolean;
begin
  Result := True;
  if (Str = '') then RowType := 0
  else if (UpperCase(Str) = 'FIXED') then RowType := 1
  else if (UpperCase(Str) = 'DYNAMIC') then RowType := 2
  else if (UpperCase(Str) = 'COMPRESSED') then RowType := 3
  else if (UpperCase(Str) = 'REDUNDANT') then RowType := 4
  else if (UpperCase(Str) = 'COMPACT') then RowType := 5
  else Result := False;
end;

function RowTypeToStr(const RowType: Integer): string;
begin
  case RowType of
    1: Result := 'Fixed';
    2: Result := 'Dynamic';
    3: Result := 'Compressed';
    4: Result := 'Redundant';
    5: Result := 'Compact';
    else Result := '';
  end;
end;

function EncodeVersion(const AMajor, AMinor, APatch, ABuild: Integer): Integer;
begin
  Result := AMajor * 100000000 + AMinor * 1000000 + APatch * 10000 + ABuild;
end;

function StrToReplaceOptions(const Str: string): TPReplace.TOptions;
begin
  Result := [];
  if (Pos('MATCHCASE', UpperCase(Str)) > 0) then Result := Result + [roMatchCase];
  if (Pos('WHOLEWORD', UpperCase(Str)) > 0) then Result := Result + [roWholeValue];
  if (Pos('REGEXPR', UpperCase(Str)) > 0) then Result := Result + [roRegExpr];
end;

function ReplaceOptionsToStr(const Options: TPReplace.TOptions): string;
begin
  Result := '';

  if (roMatchCase in Options) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'MatchCase'; end;
  if (roWholeValue in Options) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'WholeValue'; end;
  if (roRegExpr in Options) then begin if (Result <> '') then Result := Result + ','; Result := Result + 'RegExpr'; end;
end;

function ReplaceEnviromentVariables(const AStr: string): string;
var
  Len: Integer;
begin
  Len := ExpandEnvironmentStrings(PChar(AStr), nil, 0);
  SetLength(Result, Len);
  ExpandEnvironmentStrings(PChar(AStr), PChar(Result), Len);
  if (RightStr(Result, 1) = #0) then
    Delete(Result, Length(Result), 1);
end;

function XMLNode(const XML: IXMLNode; const Path: string; const NodeAutoCreate: Boolean = False): IXMLNode;
var
  ChildKey: string;
  CurrentKey: string;
begin
  if (not Assigned(XML)) then
    Result := nil
  else if (Path = '') then
    Result := XML
  else
  begin
    if (Pos('/', Path) = 0) then
    begin
      CurrentKey := Path;
      ChildKey := '';
    end
    else
    begin
      CurrentKey := Copy(Path, 1, Pos('/', Path) - 1);
      ChildKey := Path; Delete(ChildKey, 1, Length(CurrentKey) + 1);
    end;

    if (Assigned(XML.ChildNodes.FindNode(CurrentKey))) then
      Result := XMLNode(XML.ChildNodes.FindNode(CurrentKey), ChildKey, NodeAutoCreate)
    else if (NodeAutoCreate or (doNodeAutoCreate in XML.OwnerDocument.Options)) then
      Result := XMLNode(XML.AddChild(CurrentKey), ChildKey, NodeAutoCreate)
    else
      Result := nil;
  end;
end;

function GetFileIcon(const CSIDL: Integer): HIcon;
var
  FileInfo: TSHFileInfo;
  PIDL: PItemIDList;
begin
  PIDL := nil;
  SHGetFolderLocation(Application.Handle, CSIDL, 0, 0, PIDL);
  ZeroMemory(@FileInfo, SizeOf(FileInfo));
  SHGetFileInfo(PChar(PIDL), 0, FileInfo, SizeOf(FileInfo), SHGFI_PIDL or SHGFI_ICON or SHGFI_SMALLICON);
  Result := FileInfo.hIcon;
end;

{ TMRUList ********************************************************************}

procedure TMRUList.Add(const Value: string);
var
  I: Integer;
  Index: Integer;
begin
  if (Value <> '') then
  begin
    Index := IndexOf(Value);

    if (Index >= 0) then
      Delete(Index);

    while (Length(FValues) >= FMaxCount) do
      Delete(FMaxCount - 1);

    SetLength(FValues, Length(FValues) + 1);
    for I := Length(FValues) - 2 downto 0 do
      FValues[I + 1] := FValues[I];
    FValues[0] := Value;
  end;
end;

procedure TMRUList.Assign(const Source: TMRUList);
var
  I: Integer;
begin
  Clear();

  if (Assigned(Source)) then
  begin
    FMaxCount := Source.MaxCount;
    for I := Source.Count - 1 downto 0 do
      Add(Source.Values[I]);
  end;
end;

procedure TMRUList.Clear();
begin
  SetLength(FValues, 0);
end;

constructor TMRUList.Create(const AMaxCount: Integer);
begin
  FMaxCount := AMaxCount;

  Clear();
end;

procedure TMRUList.Delete(const Index: Integer);
var
  I: Integer;
begin
  if ((Index < 0) or (Length(FValues) <= Index)) then
    raise ERangeError.CreateRes(@SInvalidCurrentItem);

  for I := Index to Length(FValues) - 2 do
    FValues[I] := FValues[I + 1];
  SetLength(FValues, Length(FValues) - 1);
end;

destructor TMRUList.Destroy();
begin
  Clear();

  inherited;
end;

function TMRUList.GetCount(): Integer;
begin
  Result := Length(FValues);
end;

function TMRUList.GetValue(Index: Integer): string;
begin
  Result := FValues[Index];
end;

function TMRUList.IndexOf(const Value: string): Integer;
var
  I: Integer;
begin
  Result := -1;

  for I := 0 to Length(FValues) - 1 do
    if (lstrcmpi(PChar(Value), PChar(FValues[I])) = 0) then
      Result := I;
end;

procedure TMRUList.LoadFromXML(const XML: IXMLNode; const NodeName: string);
var
  I: Integer;
begin
  Clear();
  for I := 0 to XML.ChildNodes.Count - 1 do
    if ((XML.ChildNodes[I].NodeName = NodeName) and (Length(FValues) < MaxCount)) then
    begin
      SetLength(FValues, Length(FValues) + 1);
      FValues[Length(FValues) - 1] := XML.ChildNodes[I].Text;
    end;
end;

procedure TMRUList.SaveToXML(const XML: IXMLNode; const NodeName: string);
var
  I: Integer;
begin
  for I := XML.ChildNodes.Count - 1 downto 0 do
    if (XML.ChildNodes[I].NodeName = NodeName) then
      XML.ChildNodes.Delete(I);
  for I := 0 to Count - 1 do
    XML.AddChild(NodeName).Text := Values[I];
end;

{ TPWindow ******************************************************************}

constructor TPWindow.Create(const APreferences: TPPreferences);
begin
  FPreferences := APreferences;

  Height := -1;
  Width := -1;
end;

procedure TPWindow.LoadFromXML(const XML: IXMLNode);
begin
  if (Assigned(XMLNode(XML, 'height'))) then TryStrToInt(XMLNode(XML, 'height').Text, Height);
  if (Assigned(XMLNode(XML, 'width'))) then TryStrToInt(XMLNode(XML, 'width').Text, Width);
end;

procedure TPWindow.SaveToXML(const XML: IXMLNode);
begin
  XMLNode(XML, 'height').Text := IntToStr(Height);
  XMLNode(XML, 'width').Text := IntToStr(Width);
end;

{ TPDatabases *****************************************************************}

constructor TPDatabases.Create(const APreferences: TPPreferences);
begin
  Height := -1;
  Left := -1;
  Top := -1;
  Width := -1;
end;

{ TPEditor ********************************************************************}

constructor TPEditor.Create(const APreferences: TPPreferences);
begin
  FPreferences := APreferences;

  AutoIndent := True;
  CodeCompletition := True;
  CodeCompletionTime := 1000;
  ConditionalCommentForeground := clTeal; ConditionalCommentBackground := clNone; ConditionalCommentStyle := [];
  CommentForeground := clGreen; CommentBackground := clNone; CommentStyle := [fsItalic];
  CurrRowBGColorEnabled := True; CurrRowBGColor := $C0FFFF;
  DataTypeForeground := clMaroon; DataTypeBackground := clNone; DataTypeStyle := [fsBold];
  FunctionForeground := clNavy; FunctionBackground := clNone; FunctionStyle := [fsBold];
  IdentifierForeground := clNone; IdentifierBackground := clNone; IdentifierStyle := [];
  KeywordForeground := clNavy; KeywordBackground := clNone; KeywordStyle := [fsBold];
  LineNumbers := True;
  LineNumbersForeground := clNavy; LineNumbersBackground := clNone; LineNumbersStyle := [];
  NumberForeground := clBlue; NumberBackground := clNone; NumberStyle := [];
  RightEdge := 80;
  StringForeground := clBlue; StringBackground := clNone; StringStyle := [];
  SymbolForeground := clNone; SymbolBackground := clNone; SymbolStyle := [];
  TabAccepted := True;
  TabToSpaces := True;
  TabWidth := 4;
  VariableForeground := clGreen; VariableBackground := clNone; VariableStyle := [];
  WordWrap := False;
end;

procedure TPEditor.LoadFromXML(const XML: IXMLNode);
begin
  if (Assigned(XMLNode(XML, 'autoindent'))) then TryStrToBool(XMLNode(XML, 'autoindent').Attributes['enabled'], AutoIndent);
  if (Assigned(XMLNode(XML, 'autocompletition'))) then TryStrToBool(XMLNode(XML, 'autocompletition').Attributes['enabled'], CodeCompletition);
  if (Assigned(XMLNode(XML, 'autocompletition/time'))) then TryStrToInt(XMLNode(XML, 'autocompletition/time').Text, CodeCompletionTime);
  if (Assigned(XMLNode(XML, 'currentrow/background'))) then TryStrToBool(XMLNode(XML, 'currentrow/background').Attributes['visible'], CurrRowBGColorEnabled);
  if (Assigned(XMLNode(XML, 'currentrow/background/color'))) then CurrRowBGColor := StringToColor(XMLNode(XML, 'currentrow/background/color').Text);
  if (Assigned(XMLNode(XML, 'linenumbers'))) then TryStrToBool(XMLNode(XML, 'linenumbers').Attributes['visible'], LineNumbers);
  if (Assigned(XMLNode(XML, 'rightedge/position'))) then TryStrToInt(XMLNode(XML, 'rightedge/position').Text, RightEdge);
  if (Assigned(XMLNode(XML, 'tabs'))) then TryStrToBool(XMLNode(XML, 'tabs').Attributes['accepted'], TabAccepted);
  if (Assigned(XMLNode(XML, 'tabs'))) then TryStrToBool(XMLNode(XML, 'tabs').Attributes['tospace'], TabToSpaces);
  if (Assigned(XMLNode(XML, 'tabs/size'))) then TryStrToInt(XMLNode(XML, 'tabs/size').Text, TabWidth);
  if (Assigned(XMLNode(XML, 'wordwrap'))) then TryStrToBool(XMLNode(XML, 'wordwrap').Text, WordWrap);
end;

procedure TPEditor.SaveToXML(const XML: IXMLNode);
begin
  XMLNode(XML, 'autoindent').Attributes['enabled'] := AutoIndent;
  XMLNode(XML, 'autocompletition').Attributes['enabled'] := CodeCompletition;
  XMLNode(XML, 'autocompletition/time').Text := IntToStr(CodeCompletionTime);
  XMLNode(XML, 'currentrow/background').Attributes['visible'] := CurrRowBGColorEnabled;
  XMLNode(XML, 'currentrow/background/color').Text := ColorToString(CurrRowBGColor);
  XMLNode(XML, 'linenumbers').Attributes['visible'] := LineNumbers;
  XMLNode(XML, 'rightedge').Attributes['visible'] := RightEdge > 0;
  XMLNode(XML, 'rightedge/position').Text := IntToStr(RightEdge);
  XMLNode(XML, 'tabs').Attributes['accepted'] := TabAccepted;
  XMLNode(XML, 'tabs').Attributes['tospace'] := TabToSpaces;
  XMLNode(XML, 'tabs/size').Text := IntToStr(TabWidth);
  XMLNode(XML, 'wordwrap').Text := BoolToStr(WordWrap, True);
end;

{ TPExport ********************************************************************}

constructor TPExport.Create(const APreferences: TPPreferences);
begin
  FPreferences := APreferences;

  CSVHeadline := True;
  CSVQuote := 1;
  CSVQuoteChar := '"';
  CSVSeparator := ',';
  CSVSeparatorType := stChar;
  ExcelHeadline := False;
  HTMLData := True;
  HTMLStructure := False;
  SQLCreateDatabase := False;
  SQLData := True;
  SQLDisableKeys := True;
  SQLDropBeforeCreate := True;
  SQLStructure := True;
  SQLReplaceData := False;
  SQLUseDatabase := False;
end;

procedure TPExport.LoadFromXML(const XML: IXMLNode);
begin
  if (Assigned(XMLNode(XML, 'csv/headline'))) then TryStrToBool(XMLNode(XML, 'csv/headline').Attributes['enabled'], CSVHeadline);
  if (Assigned(XMLNode(XML, 'csv/quote/string'))) then CSVQuoteChar := XMLNode(XML, 'csv/quote/string').Text;
  if (Assigned(XMLNode(XML, 'csv/quote/type'))) then TryStrToQuote(XMLNode(XML, 'csv/quote/type').Text, CSVQuote);
  if (Assigned(XMLNode(XML, 'csv/separator/character/string'))) then CSVSeparator := XMLNode(XML, 'csv/separator/character/string').Text;
  if (Assigned(XMLNode(XML, 'csv/separator/character/type'))) then TryStrToSeparatorType(XMLNode(XML, 'csv/separator/character/type').Text, CSVSeparatorType);
  if (Assigned(XMLNode(XML, 'excel/headline'))) then TryStrToBool(XMLNode(XML, 'excel/headline').Attributes['enabled'], ExcelHeadline);
  if (Assigned(XMLNode(XML, 'html/data'))) then TryStrToBool(XMLNode(XML, 'html/data').Attributes['enabled'], HTMLData);
  if (Assigned(XMLNode(XML, 'html/structure'))) then TryStrToBool(XMLNode(XML, 'html/structure').Attributes['enabled'], HTMLStructure);
  if (Assigned(XMLNode(XML, 'sql/data'))) then TryStrToBool(XMLNode(XML, 'sql/data').Attributes['enabled'], SQLData);
  if (Assigned(XMLNode(XML, 'sql/data'))) then TryStrToBool(XMLNode(XML, 'sql/data').Attributes['replace'], SQLReplaceData);
  if (Assigned(XMLNode(XML, 'sql/data'))) then TryStrToBool(XMLNode(XML, 'sql/data').Attributes['disablekeys'], SQLDisableKeys);
  if (Assigned(XMLNode(XML, 'sql/structure'))) then TryStrToBool(XMLNode(XML, 'sql/structure').Attributes['enabled'], SQLStructure);
  if (Assigned(XMLNode(XML, 'sql/structure'))) then TryStrToBool(XMLNode(XML, 'sql/structure').Attributes['drop'], SQLDropBeforeCreate);
  if (Assigned(XMLNode(XML, 'sql/structure/database'))) then TryStrToBool(XMLNode(XML, 'sql/structure/database').Attributes['create'], SQLCreateDatabase);
  if (Assigned(XMLNode(XML, 'sql/structure/database'))) then TryStrToBool(XMLNode(XML, 'sql/structure/database').Attributes['change'], SQLUseDatabase);
end;

procedure TPExport.SaveToXML(const XML: IXMLNode);
begin
  XMLNode(XML, 'csv/headline').Attributes['enabled'] := CSVHeadline;
  XMLNode(XML, 'csv/quote/string').Text := CSVQuoteChar;
  XMLNode(XML, 'csv/quote/type').Text := QuoteToStr(CSVQuote);
  XMLNode(XML, 'csv/separator/character/string').Text := CSVSeparator;
  XMLNode(XML, 'csv/separator/character/type').Text := SeparatorTypeToStr(CSVSeparatorType);
  XMLNode(XML, 'excel/headline').Attributes['enabled'] := ExcelHeadline;
  XMLNode(XML, 'html/data').Attributes['enabled'] := HTMLData;
  XMLNode(XML, 'html/structure').Attributes['enabled'] := HTMLStructure;
  XMLNode(XML, 'sql/data').Attributes['enabled'] := SQLData;
  XMLNode(XML, 'sql/data').Attributes['replace'] := SQLReplaceData;
  XMLNode(XML, 'sql/data').Attributes['disablekeys'] := SQLDisableKeys;
  XMLNode(XML, 'sql/structure').Attributes['enabled'] := SQLStructure;
  XMLNode(XML, 'sql/structure').Attributes['drop'] := SQLDropBeforeCreate;
  XMLNode(XML, 'sql/structure/database').Attributes['create'] := SQLCreateDatabase;
  XMLNode(XML, 'sql/structure/database').Attributes['change'] := SQLUseDatabase;
end;

{ TPFind **********************************************************************}

constructor TPFind.Create(const APreferences: TPPreferences);
begin
  inherited;

  FindTextMRU := TMRUList.Create(10);
  Left := -1;
  Options := [foMatchCase];
  Top := -1;
end;

destructor TPFind.Destroy();
begin
  FindTextMRU.Free();

  inherited;
end;

procedure TPFind.LoadFromXML(const XML: IXMLNode);
var
  I: Integer;
begin
  inherited;

  FindTextMRU.Clear();
  if (Assigned(XMLNode(XML, 'findtext/mru'))) then
    for I := XMLNode(XML, 'findtext/mru').ChildNodes.Count - 1 downto 0 do
      if (XMLNode(XML, 'findtext/mru').ChildNodes[I].NodeName = 'text') then
        FindTextMRU.Add(XMLNode(XML, 'findtext/mru').ChildNodes[I].Text);
  if (Assigned(XMLNode(XML, 'options'))) then Options := StrToFindOptions(XMLNode(XML, 'options').Text);
end;

procedure TPFind.SaveToXML(const XML: IXMLNode);
var
  I: Integer;
begin
  inherited;

  XMLNode(XML, 'findtext/mru').ChildNodes.Clear();
  for I := 0 to FindTextMRU.Count - 1 do
    XMLNode(XML, 'findtext/mru').AddChild('text').Text := FindTextMRU.Values[I];
  XMLNode(XML, 'options').Text := FindOptionsToStr(Options);
end;

{ TPImport ********************************************************************}

constructor TPImport.Create(const APreferences: TPPreferences);
begin
  FPreferences := APreferences;

  CSVHeadline := True;
  CSVQuote := 1;
  CSVQuoteChar := '"';
  CSVSeparator := ',';
  CSVSeparatorType := stChar;
  ExcelHeadline := False;
  ImportType := itInsert;
  ODBCData := True;
  ODBCObjects := True;
  ODBCRowType := 0;
  SaveErrors := True;
end;

procedure TPImport.LoadFromXML(const XML: IXMLNode);
begin
  if (Assigned(XMLNode(XML, 'csv/headline'))) then TryStrToBool(XMLNode(XML, 'csv/headline').Attributes['enabled'], CSVHeadline);
  if (Assigned(XMLNode(XML, 'csv/quote/string'))) then CSVQuoteChar := XMLNode(XML, 'csv/quote/string').Text;
  if (Assigned(XMLNode(XML, 'csv/quote/type'))) then TryStrToQuote(XMLNode(XML, 'csv/quote/type').Text, CSVQuote);
  if (Assigned(XMLNode(XML, 'csv/separator/character/string'))) then CSVSeparator := XMLNode(XML, 'csv/separator/character/string').Text;
  if (Assigned(XMLNode(XML, 'csv/separator/character/type'))) then TryStrToSeparatorType(XMLNode(XML, 'csv/separator/character/type').Text, CSVSeparatorType);
  if (Assigned(XMLNode(XML, 'data/importtype'))) then TryStrToImportType(XMLNode(XML, 'data/importtype').Text, ImportType);
  if (Assigned(XMLNode(XML, 'errors/save'))) then TryStrToBool(XMLNode(XML, 'errors/save').Text, SaveErrors);
  if (Assigned(XMLNode(XML, 'excel/headline'))) then TryStrToBool(XMLNode(XML, 'excel/headline').Attributes['enabled'], ExcelHeadline);
  if (Assigned(XMLNode(XML, 'odbc/data'))) then TryStrToBool(XMLNode(XML, 'odbc/data').Attributes['enabled'], ODBCData);
  if (Assigned(XMLNode(XML, 'odbc/objects'))) then TryStrToBool(XMLNode(XML, 'odbc/objects').Attributes['enabled'], ODBCObjects);
  if (Assigned(XMLNode(XML, 'odbc/rowformat'))) then TryStrToRowType(XMLNode(XML, 'odbc/rowformat').Text, ODBCRowType);
end;

procedure TPImport.SaveToXML(const XML: IXMLNode);
begin
  XMLNode(XML, 'csv/headline').Attributes['enabled'] := CSVHeadline;
  XMLNode(XML, 'csv/quote/string').Text := CSVQuoteChar;
  XMLNode(XML, 'csv/quote/type').Text := QuoteToStr(CSVQuote);
  XMLNode(XML, 'csv/separator/character/string').Text := CSVSeparator;
  XMLNode(XML, 'csv/separator/character/type').Text := SeparatorTypeToStr(CSVSeparatorType);
  XMLNode(XML, 'data/importtype').Text := ImportTypeToStr(ImportType);
  XMLNode(XML, 'errors/save').Text := BoolToStr(SaveErrors, True);
  XMLNode(XML, 'excel/headline').Attributes['enabled'] := ExcelHeadline;
  XMLNode(XML, 'odbc/data').Attributes['enabled'] := ODBCData;
  XMLNode(XML, 'odbc/objects').Attributes['enabled'] := ODBCObjects;
  XMLNode(XML, 'odbc/rowformat').Text := RowTypeToStr(ODBCRowType);
end;

{ TPODBC **********************************************************************}

constructor TPODBC.Create(const APreferences: TPPreferences);
begin
  inherited;

  Left := -1;
  Top := -1;
end;

{ TPPaste *********************************************************************}

constructor TPPaste.Create(const APreferences: TPPreferences);
begin
  FPreferences := APreferences;

  Data := True;
end;

procedure TPPaste.LoadFromXML(const XML: IXMLNode);
begin
  if (Assigned(XMLNode(XML, 'data'))) then TryStrToBool(XMLNode(XML, 'data').Text, Data);
end;

procedure TPPaste.SaveToXML(const XML: IXMLNode);
begin
  XMLNode(XML, 'data').Text := BoolToStr(Data, True);
end;

{ TPReplace *******************************************************************}

constructor TPReplace.Create(const APreferences: TPPreferences);
begin
  inherited;

  FindTextMRU := TMRUList.Create(10);
  ReplaceTextMRU := TMRUList.Create(10);
  Backup := True;
  Left := -1;
  Options := [roMatchCase];
  Top := -1;
end;

destructor TPReplace.Destroy();
begin
  FindTextMRU.Free();
  ReplaceTextMRU.Free();

  inherited;
end;

procedure TPReplace.LoadFromXML(const XML: IXMLNode);
var
  I: Integer;
begin
  inherited;

  if (Assigned(XMLNode(XML, 'backup'))) then TryStrToBool(XMLNode(XML, 'backup').Attributes['enabled'], Backup);
  FindTextMRU.Clear();
  if (Assigned(XMLNode(XML, 'findtext/mru'))) then
    for I := XMLNode(XML, 'findtext/mru').ChildNodes.Count - 1 downto 0 do
      if (XMLNode(XML, 'findtext/mru').ChildNodes[I].NodeName = 'text') then
        FindTextMRU.Add(XMLNode(XML, 'findtext/mru').ChildNodes[I].Text);
  if (Assigned(XMLNode(XML, 'options'))) then Options := StrToReplaceOptions(XMLNode(XML, 'options').Text);
  ReplaceTextMRU.Clear();
  if (Assigned(XMLNode(XML, 'replacetext/mru'))) then
    for I := XMLNode(XML, 'replacetext/mru').ChildNodes.Count - 1 downto 0 do
      if (XMLNode(XML, 'replacetext/mru').ChildNodes[I].NodeName = 'text') then
        ReplaceTextMRU.Add(XMLNode(XML, 'replacetext/mru').ChildNodes[I].Text);
end;

procedure TPReplace.SaveToXML(const XML: IXMLNode);
var
  I: Integer;
begin
  inherited;

  XMLNode(XML, 'backup').Attributes['enabled'] := Backup;
  XMLNode(XML, 'findtext/mru').ChildNodes.Clear();
  for I := 0 to FindTextMRU.Count - 1 do
    XMLNode(XML, 'findtext/mru').AddChild('text').Text := FindTextMRU.Values[I];
  XMLNode(XML, 'options').Text := ReplaceOptionsToStr(Options);
  XMLNode(XML, 'replacetext/mru').ChildNodes.Clear();
  for I := 0 to ReplaceTextMRU.Count - 1 do
    XMLNode(XML, 'replacetext/mru').AddChild('text').Text := ReplaceTextMRU.Values[I];
end;

{ TPServer ********************************************************************}

constructor TPServer.Create(const APreferences: TPPreferences);
begin
  inherited;

  Left := -1;
  Top := -1;
end;

{ TPSQLHelp *******************************************************************}

constructor TPSQLHelp.Create(const APreferences: TPPreferences);
begin
  inherited;

  Left := -1;
  Top := -1;
end;

procedure TPSQLHelp.LoadFromXML(const XML: IXMLNode);
begin
  inherited;

  if (Assigned(XMLNode(XML, 'left'))) then TryStrToInt(XMLNode(XML, 'left').Text, Left);
  if (Assigned(XMLNode(XML, 'top'))) then TryStrToInt(XMLNode(XML, 'top').Text, Top);
end;

procedure TPSQLHelp.SaveToXML(const XML: IXMLNode);
begin
  inherited;

  XMLNode(XML, 'left').Text := IntToStr(Left);
  XMLNode(XML, 'top').Text := IntToStr(Top);
end;

{ TPAccounts ******************************************************************}

constructor TPAccounts.Create(const APreferences: TPPreferences);
begin
  inherited;

  SelectOrder := 0;
end;

procedure TPAccounts.LoadFromXML(const XML: IXMLNode);
begin
  inherited;

  if (Assigned(XMLNode(XML, 'selectorder'))) then TryStrToInt(XMLNode(XML, 'selectorder').Text, SelectOrder);
end;

procedure TPAccounts.SaveToXML(const XML: IXMLNode);
begin
  inherited;

  XMLNode(XML, 'selectorder').Text := IntToStr(SelectOrder);
end;

{ TPTableService **************************************************************}

constructor TPTableService.Create(const APreferences: TPPreferences);
begin
  inherited;

  Analyze := False;
  Check := False;
  Flush := False;
  Optimize := False;
  Repair := False;
end;

procedure TPTableService.LoadFromXML(const XML: IXMLNode);
begin
  inherited;

  if (Assigned(XMLNode(XML, 'analyze'))) then TryStrToBool(XMLNode(XML, 'analyze').Attributes['enabled'], Analyze);
  if (Assigned(XMLNode(XML, 'check'))) then TryStrToBool(XMLNode(XML, 'check').Attributes['enabled'], Check);
  if (Assigned(XMLNode(XML, 'flush'))) then TryStrToBool(XMLNode(XML, 'flush').Attributes['enabled'], Flush);
  if (Assigned(XMLNode(XML, 'optimize'))) then TryStrToBool(XMLNode(XML, 'optimize').Attributes['enabled'], Optimize);
  if (Assigned(XMLNode(XML, 'repair'))) then TryStrToBool(XMLNode(XML, 'repair').Attributes['enabled'], Repair);
end;

procedure TPTableService.SaveToXML(const XML: IXMLNode);
begin
  inherited;

  XMLNode(XML, 'analyze').Attributes['enabled'] := Analyze;
  XMLNode(XML, 'check').Attributes['enabled'] := Check;
  XMLNode(XML, 'flush').Attributes['enabled'] := Flush;
  XMLNode(XML, 'optimize').Attributes['enabled'] := Optimize;
  XMLNode(XML, 'repair').Attributes['enabled'] := Repair;
end;

{ TPTransfer ******************************************************************}

{ TPLanguage ******************************************************************}

constructor TPLanguage.Create(const FileName: string);
var
  I: Integer;
  Item: Integer;
  MaxItem: Integer;
  Strings: TStringList;
begin
  inherited;

  FActiveQueryBuilderLanguageName := 'English';
  if (not FileExists(Filename)) then
    FLanguageId := LANG_NEUTRAL
  else
  begin
    FLanguageId := ReadInteger('Global', 'LanguageId', LANG_NEUTRAL);
    FActiveQueryBuilderLanguageName := ReadString('Global', 'ActiveQueryBuilderLanguage', 'English');

    Strings := TStringList.Create();

    ReadSectionValues('Strings', Strings);

    MaxItem := 0;
    for I := 0 to Strings.Count - 1 do
      if (TryStrToInt(Strings.Names[I], Item)) then
        MaxItem := Item;

    SetLength(FStrs, MaxItem + 1);

    for I := 0 to Strings.Count - 1 do
      if (TryStrToInt(Strings.Names[I], Item)) then
        FStrs[Item] := Strings.ValueFromIndex[I];

    Strings.Free();
  end;
end;

destructor TPLanguage.Destroy();
begin
  SetLength(FStrs, 0);

  inherited;
end;

function TPLanguage.GetStr(Index: Integer): string;
begin
  if ((Index >= Length(FStrs)) or (FStrs[Index] = '')) then
    Result := SysUtils.LoadStr(10000 + Index)
  else
    Result := FStrs[Index];

  Result := ReplaceStr(ReplaceStr(Trim(Result), '\n', #10), '\r', #13);
end;

{ TPPreferences ***************************************************************}

constructor TPPreferences.Create();
var
  MaxIconIndex: Integer;
  Font: TFont;
  FontSize: Integer;
  Foldername: array [0..MAX_PATH] of Char;
  I: Integer;
  NonClientMetrics: TNonClientMetrics;
  Path: string;
  StringList: TStringList;
begin
  inherited Create(KEY_ALL_ACCESS);

  FXMLDocument := nil;

  NonClientMetrics.cbSize := SizeOf(NonClientMetrics);
  if (not SystemParametersInfo(SPI_GETNONCLIENTMETRICS, SizeOf(NonClientMetrics), @NonClientMetrics, 0)) then
    FontSize := 9
  else
  begin
    Font := TFont.Create();
    Font.Handle := CreateFontIndirect(NonClientMetrics.lfMessageFont);
    FontSize := Font.Size;
    Font.Free();
  end;

  WindowState := wsNormal;
  Top := 0;
  Left := 0;
  Height := 0;
  Width := 0;
  AddressBarVisible := False;
  GridFontName := 'Microsoft Sans Serif';
  GridFontColor := clWindowText;
  GridFontStyle := [];
  GridFontSize := FontSize;
  GridFontCharset := DEFAULT_CHARSET;
  GridMaxColumnWidth := 100;
  GridRowBGColorEnabled := True;
  GridCurrRowBGColor := $C0FFFF;
  GridCurrRowBGColorEnabled := True;
  GridNullBGColorEnabled := False;
  GridNullBGColor := $E0F0E0;
  GridNullText := True;
  GridShowMemoContent := False;
  GridDefaultSorting := True;
  InstallDate := Now();
  DonationVisible := False;
  SQLFontName := 'Courier New';
  SQLFontColor := clWindowText;
  SQLFontStyle := [];
  SQLFontSize := FontSize;
  SQLFontCharset := DEFAULT_CHARSET;
  LogFontName := 'Courier New';
  LogFontColor := clWindowText;
  LogFontStyle := [];
  LogFontSize := 8;
  LogFontCharset := DEFAULT_CHARSET;
  LogHighlighting := False;
  LogTime := False;
  LogResult := False;
  LogSize := 100 * 1024;
  LanguageFilename := 'English.ini';
  TabsVisible := False;
  ToolbarTabs := [ttObjects, ttBrowser, ttEditor];
  UpdateCheck := utNever;
  UpdateChecked := Now();


  KeyBase := SysUtils.LoadStr(1003);
  GetVersion(FVerMajor, FVerMinor, FVerPatch, FVerBuild);
  {$IFDEF Debug}
  if (SysUtils.LoadStr(1000) = '') then
    FInternetAgent := 'MySQL-Front'
  else
  {$ENDIF}
  FInternetAgent := SysUtils.LoadStr(1000) + '/' + IntToStr(VerMajor) + '.' + IntToStr(VerMinor);
  SHGetFolderPath(Application.Handle, CSIDL_PERSONAL, 0, 0, @Foldername);
  Path := IncludeTrailingPathDelimiter(PChar(@Foldername));
  if ((FileExists(ExtractFilePath(Application.ExeName) + '\Desktop.xml')) or (SHGetFolderPath(Application.Handle, CSIDL_APPDATA, 0, 0, @Foldername) <> S_OK)) then
    UserPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName))
  {$IFDEF Debug}
  else if (SysUtils.LoadStr(1002) = '') then
    UserPath := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(PChar(@Foldername)) + 'MySQL-Front')
  {$ENDIF}
  else
    UserPath := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(PChar(@Foldername)) + SysUtils.LoadStr(1002));

  SoundFileNavigating := '';
  if (OpenKeyReadOnly('\AppEvents\Schemes\Apps\Explorer\Navigating\.Current')) then
  begin
    if (ValueExists('')) then
      SoundFileNavigating := ReplaceEnviromentVariables(ReadString(''));

    CloseKey();
  end;


  if (DirectoryExists(PChar(@Foldername) + PathDelim + 'SQL-Front' + PathDelim)
    and not DirectoryExists(UserPath)) then
  begin
    Path := PChar(@Foldername) + PathDelim + 'SQL-Front' + PathDelim;
    CopyDir(Path, UserPath);
    StringList := TStringList.Create();
    StringList.LoadFromFile(Filename);
    StringList.Text := ReplaceStr(StringList.Text, '<session', '<account');
    StringList.Text := ReplaceStr(StringList.Text, '</session', '</account');
    StringList.SaveToFile(Filename);
    StringList.Free();
  end;


  MaxIconIndex := 0;
  for I := 1 to 200 do
    if (FindResource(HInstance, MAKEINTRESOURCE(10000 + I), RT_GROUP_ICON) > 0) then
      MaxIconIndex := I;

  FSmallImages := TImageList.Create(nil);
  FSmallImages.ColorDepth := cd32Bit;
  FSmallImages.Height := GetSystemMetrics(SM_CYSMICON);
  FSmallImages.Width := GetSystemMetrics(SM_CXSMICON);

  for I := 0 to MaxIconIndex do
    if (I = 13) then
      ImageList_AddIcon(FSmallImages.Handle, GetFileIcon(CSIDL_DRIVES))
    else if (FindResource(HInstance, MAKEINTRESOURCE(10000 + I), RT_GROUP_ICON) > 0) then
      ImageList_AddIcon(FSmallImages.Handle, LoadImage(hInstance, MAKEINTRESOURCE(10000 + I), IMAGE_ICON, GetSystemMetrics(SM_CYSMICON), GetSystemMetrics(SM_CXSMICON), LR_DEFAULTCOLOR))
    else if (I > 0) then
      ImageList_AddIcon(FSmallImages.Handle, ImageList_GetIcon(FSmallImages.Handle, 0, 0));

  FLargeImages := TImageList.Create(nil);
  FLargeImages.ColorDepth := cd32Bit;
  FLargeImages.Height := 24;
  FLargeImages.Width := 24;

  for I := 0 to MaxIconIndex do
    if (FindResource(HInstance, MAKEINTRESOURCE(10000 + I), RT_GROUP_ICON) > 0) then
      ImageList_AddIcon(FLargeImages.Handle, LoadImage(hInstance, MAKEINTRESOURCE(10000 + I), IMAGE_ICON, FLargeImages.Height, FLargeImages.Width, LR_DEFAULTCOLOR))
    else
      ImageList_AddIcon(FLargeImages.Handle, ImageList_GetIcon(FSmallImages.Handle, I, 0));


  Database := TPDatabase.Create(Self);
  Databases := TPDatabases.Create(Self);
  Editor := TPEditor.Create(Self);
  Event := TPEvent.Create(Self);
  Export := TPExport.Create(Self);
  Field := TPField.Create(Self);
  Find := TPFind.Create(Self);
  ForeignKey := TPForeignKey.Create(Self);
  Host := TPHost.Create(Self);
  Import := TPImport.Create(Self);
  Index := TPIndex.Create(Self);
  ODBC := TPODBC.Create(Self);
  Paste := TPPaste.Create(Self);
  Replace := TPReplace.Create(Self);
  Routine := TPRoutine.Create(Self);
  Server := TPServer.Create(Self);
  Accounts := TPAccounts.Create(Self);
  SQLHelp := TPSQLHelp.Create(Self);
  Statement := TPStatement.Create(Self);
  Table := TPTable.Create(Self);
  TableService := TPTableService.Create(Self);
  Transfer := TPTransfer.Create(Self);
  Trigger := TPTrigger.Create(Self);
  User := TPUser.Create(Self);
  View := TPView.Create(Self);

  LoadFromRegistry();
  LoadFromXML();
end;

destructor TPPreferences.Destroy();
begin
  SaveToRegistry();

  Database.Free();
  Databases.Free();
  Editor.Free();
  Event.Free();
  Export.Free();
  Field.Free();
  Find.Free();
  ForeignKey.Free();
  Host.Free();
  Import.Free();
  Index.Free();
  ODBC.Free();
  Paste.Free();
  Replace.Free();
  Routine.Free();
  Server.Free();
  Accounts.Free();
  SQLHelp.Free();
  Statement.Free();
  Table.Free();
  TableService.Free();
  Transfer.Free();
  Trigger.Free();
  User.Free();
  View.Free();

  FLargeImages.Free();
  FSmallImages.Free();

  if (Assigned(FLanguage)) then
    FLanguage.Free();

  inherited;
end;

function TPPreferences.GetFilename(): TFileName;
begin
  Result := UserPath + 'Desktop.xml';
end;

function TPPreferences.GetLanguage(): TPLanguage;
begin
  if (not Assigned(FLanguage)) then
    FLanguage := TPLanguage.Create(LanguagePath + LanguageFilename);

  Result := FLanguage;
end;

function TPPreferences.GetLanguagePath(): TFileName;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName) + 'Languages');

  {$IFDEF Debug}
    if (not FileExists(Result)) then
      Result := IncludeTrailingPathDelimiter('..\Languages\');
  {$ENDIF}
end;

function TPPreferences.GetVersion(var VerMajor, VerMinor, VerPatch, VerBuild: Integer): Boolean;
var
  Buffer: PChar;
  BufferSize: Cardinal;
  FileInfo: ^VS_FIXEDFILEINFO;
  FileInfoSize: UINT;
  FileVersionAvailable: Boolean;
  Handle: Cardinal;
begin
  Result := False;
  VerMajor := -1; VerMinor := -1; VerPatch := -1; VerBuild := -1;

  BufferSize := GetFileVersionInfoSize(PChar(Application.ExeName), Handle);

  if (BufferSize > 0) then
  begin
    GetMem(Buffer, BufferSize);
    if (Assigned(Buffer)) then
    begin
      FileVersionAvailable := GetFileVersionInfo(PChar(Application.ExeName), Application.Handle, BufferSize, Buffer);
      if (FileVersionAvailable) then
        if (VerQueryValue(Buffer, '\', Pointer(FileInfo), FileInfoSize)) then
          if (FileInfoSize >= SizeOf(FileInfo^)) then
          begin
            VerMajor := FileInfo.dwFileVersionMS shr 16;
            VerMinor := FileInfo.dwFileVersionMS and $FFFF;
            VerPatch := FileInfo.dwFileVersionLS shr 16;
            VerBuild := FileInfo.dwFileVersionLS and $FFFF;
            Result := (VerMajor > 0) and (VerMinor >= 0) and (VerPatch >= 0) and (VerBuild >= 0);
          end;
    end;
    FreeMem(Buffer);
  end;
end;

function TPPreferences.GetVersionInfo(): Integer;
var
  VerBuild: Integer;
  VerMajor: Integer;
  VerMinor: Integer;
  VerPatch: Integer;
begin
  if (not GetVersion(VerMajor, VerMinor, VerPatch, VerBuild)) then
    Result := -1
  else
    Result := EncodeVersion(VerMajor, VerMinor, VerPatch, VerBuild);
end;

function TPPreferences.GetVersionStr(): string;
var
  VerBuild: Integer;
  VerMajor: Integer;
  VerMinor: Integer;
  VerPatch: Integer;
begin
  if (not GetVersion(VerMajor, VerMinor, VerPatch, VerBuild)) then
    Result := '???'
  else
    Result := IntToStr(VerMajor) + '.' + IntToStr(VerMinor) + '  (Build ' + IntToStr(VerPatch) + '.' + IntToStr(VerBuild) + ')';
end;

function TPPreferences.GetXML(): IXMLNode;
begin
  if (not Assigned(FXMLDocument)) then
  begin
    if (FileExists(Filename)) then
      try
        FXMLDocument := LoadXMLDocument(Filename);

        if (VersionStrToVersion(FXMLDocument.DocumentElement.Attributes['version']) < 10002)  then
        begin
          XMLNode(FXMLDocument.DocumentElement, 'grid/maxcolumnwidth').Text := IntToStr(100);

          FXMLDocument.DocumentElement.Attributes['version'] := '1.0.2';
        end;

        if (VersionStrToVersion(FXMLDocument.DocumentElement.Attributes['version']) < 10100)  then
        begin
          FXMLDocument.DocumentElement.ChildNodes.Delete('session');
          FXMLDocument.DocumentElement.ChildNodes.Delete('sessions');

          FXMLDocument.DocumentElement.Attributes['version'] := '1.1.0';
        end;

        if (VersionStrToVersion(FXMLDocument.DocumentElement.Attributes['version']) < 10101)  then
        begin
          if (Assigned(XMLNode(FXMLDocument.DocumentElement, 'updates/check'))
            and (UpperCase(XMLNode(FXMLDocument.DocumentElement, 'updates/check').Text) = 'STARTUP')) then
            XMLNode(FXMLDocument.DocumentElement, 'updates/check').Text := 'Daily';

          FXMLDocument.DocumentElement.Attributes['version'] := '1.1.1';
        end;
      except
        FXMLDocument := nil;
      end;

    if (not Assigned(FXMLDocument)) then
    begin
      FXMLDocument := NewXMLDocument();
      FXMLDocument.Encoding := 'utf-8';
      FXMLDocument.Node.AddChild('desktop').Attributes['version'] := '1.1.0';
    end;

    FXMLDocument.Options := FXMLDocument.Options - [doAttrNull, doNodeAutoCreate];
  end;

  Result := FXMLDocument.DocumentElement;
end;

procedure TPPreferences.LoadFromRegistry();
var
  KeyName: string;
begin
  RootKey := HKEY_CLASSES_ROOT;

  AssociateSQL := False;
  if (OpenKeyReadOnly('.sql')) then
  begin
    if (ValueExists('')) then KeyName := ReadString('');
    CloseKey();

    if (OpenKeyReadOnly(KeyName + '\shell\open\command')) then
    begin
      AssociateSQL := Pos(UpperCase(Application.ExeName), UpperCase(ReadString(''))) > 0;
      CloseKey();
    end;
  end;
  OldAssociateSQL := AssociateSQL;

  RootKey := HKEY_CURRENT_USER;

  if (OpenKeyReadOnly(KeyBase)) then
  begin
    if (ValueExists('LanguageFile')) then LanguageFilename := ExtractFileName(ReadString('LanguageFile'));
    if (ValueExists('Path') and DirectoryExists(ReadString('Path'))) then Path := IncludeTrailingPathDelimiter(ReadString('Path'));
    if (ValueExists('SetupProgram') and FileExists(ReadString('SetupProgram'))) then SetupProgram := ReadString('SetupProgram');
    if (ValueExists('SetupProgramInstalled')) then SetupProgramInstalled := ReadBool('SetupProgramInstalled');
    if (ValueExists('UserPath')) then UserPath := IncludeTrailingPathDelimiter(ReadString('UserPath'));

    CloseKey();
  end;
end;

procedure TPPreferences.LoadFromXML();
var
  Visible: Boolean;
begin
  XML.OwnerDocument.Options := XML.OwnerDocument.Options - [doNodeAutoCreate];

  if (Assigned(XMLNode(XML, 'addressbar'))) then TryStrToBool(XMLNode(XML, 'addressbar').Attributes['visible'], AddressBarVisible);
  if (Assigned(XMLNode(XML, 'grid/currentrow/background'))) then TryStrToBool(XMLNode(XML, 'grid/currentrow/background').Attributes['visible'], GridCurrRowBGColorEnabled);
  if (Assigned(XMLNode(XML, 'grid/currentrow/background/color'))) then GridCurrRowBGColor := StringToColor(XMLNode(XML, 'grid/currentrow/background/color').Text);
  if (Assigned(XMLNode(XML, 'grid/font/charset'))) then TryStrToInt(XMLNode(XML, 'grid/font/charset').Text, GridFontCharset);
  if (Assigned(XMLNode(XML, 'grid/font/color'))) then GridFontColor := StringToColor(XMLNode(XML, 'grid/font/color').Text);
  if (Assigned(XMLNode(XML, 'grid/font/name'))) then GridFontName := XMLNode(XML, 'grid/font/name').Text;
  if (Assigned(XMLNode(XML, 'grid/font/size'))) then TryStrToInt(XMLNode(XML, 'grid/font/size').Text, GridFontSize);
  if (Assigned(XMLNode(XML, 'grid/font/style'))) then GridFontStyle := StrToStyle(XMLNode(XML, 'grid/font/style').Text);
  if (Assigned(XMLNode(XML, 'grid/memo'))) then TryStrToBool(XMLNode(XML, 'grid/memo').Attributes['visible'], GridShowMemoContent);
  if (Assigned(XMLNode(XML, 'grid/null'))) then TryStrToBool(XMLNode(XML, 'grid/null').Attributes['visible'], GridNullText);
  if (Assigned(XMLNode(XML, 'grid/null/background'))) then TryStrToBool(XMLNode(XML, 'grid/null/background').Attributes['visible'], GridNullBGColorEnabled);
  if (Assigned(XMLNode(XML, 'grid/null/background/color'))) then GridNullBGColor := StringToColor(XMLNode(XML, 'grid/null/background/color').Text);
  if (Assigned(XMLNode(XML, 'grid/maxcolumnwidth'))) then TryStrToInt(XMLNode(XML, 'grid/maxcolumnwidth').Text, GridMaxColumnWidth);
  if (Assigned(XMLNode(XML, 'grid/row/background'))) then TryStrToBool(XMLNode(XML, 'grid/row/background').Attributes['visible'], GridRowBGColorEnabled);
  if (Assigned(XMLNode(XML, 'height'))) then TryStrToInt(XMLNode(XML, 'height').Text, Height);
  if (Assigned(XMLNode(XML, 'installdate'))) then TryStrToDate(XMLNode(XML, 'information').Text, InstallDate);
  if (Assigned(XMLNode(XML, 'language/file'))) then LanguageFilename := ExtractFileName(XMLNode(XML, 'language/file').Text);
  if (Assigned(XMLNode(XML, 'left'))) then TryStrToInt(XMLNode(XML, 'left').Text, Left);
  if (Assigned(XMLNode(XML, 'log/font/charset'))) then TryStrToInt(XMLNode(XML, 'log/font/charset').Text, LogFontCharset);
  if (Assigned(XMLNode(XML, 'log/font/color'))) then LogFontColor := StringToColor(XMLNode(XML, 'log/font/color').Text);
  if (Assigned(XMLNode(XML, 'log/font/name'))) then LogFontName := XMLNode(XML, 'log/font/name').Text;
  if (Assigned(XMLNode(XML, 'log/font/size'))) then TryStrToInt(XMLNode(XML, 'log/font/size').Text, LogFontSize);
  if (Assigned(XMLNode(XML, 'log/font/style'))) then LogFontStyle := StrToStyle(XMLNode(XML, 'log/font/style').Text);
  if (Assigned(XMLNode(XML, 'log/highlighting'))) then TryStrToBool(XMLNode(XML, 'log/highlighting').Attributes['visible'], LogHighlighting);
  if (Assigned(XMLNode(XML, 'log/size'))) then TryStrToInt(XMLNode(XML, 'log/size').Text, LogSize);
  if (Assigned(XMLNode(XML, 'log/dbresult'))) then TryStrToBool(XMLNode(XML, 'log/dbresult').Attributes['visible'], LogResult);
  if (Assigned(XMLNode(XML, 'log/time'))) then TryStrToBool(XMLNode(XML, 'log/time').Attributes['visible'], LogTime);
//  if (Assigned(XMLNode(XML, 'donation'))) then TryStrToBool(XMLNode(XML, 'donation').Attributes['visible'], DonationVisible);
  if (Assigned(XMLNode(XML, 'installdate'))) then TryStrToDate(XMLNode(XML, 'information').Text, InstallDate);
  if (Assigned(XMLNode(XML, 'toolbar/objects')) and TryStrToBool(XMLNode(XML, 'toolbar/objects').Attributes['visible'], Visible)) then
    if (Visible) then ToolbarTabs := ToolbarTabs + [ttObjects] else ToolbarTabs := ToolbarTabs - [ttObjects];
  if (Assigned(XMLNode(XML, 'toolbar/browser')) and TryStrToBool(XMLNode(XML, 'toolbar/browser').Attributes['visible'], Visible)) then
    if (Visible) then ToolbarTabs := ToolbarTabs + [ttBrowser] else ToolbarTabs := ToolbarTabs - [ttBrowser];
  if (Assigned(XMLNode(XML, 'toolbar/ide')) and TryStrToBool(XMLNode(XML, 'toolbar/ide').Attributes['visible'], Visible)) then
    if (Visible) then ToolbarTabs := ToolbarTabs + [ttIDE] else ToolbarTabs := ToolbarTabs - [ttIDE];
  if (Assigned(XMLNode(XML, 'toolbar/builder')) and TryStrToBool(XMLNode(XML, 'toolbar/builder').Attributes['visible'], Visible)) then
    if (Visible) then ToolbarTabs := ToolbarTabs + [ttBuilder] else ToolbarTabs := ToolbarTabs - [ttBuilder];
  if (Assigned(XMLNode(XML, 'toolbar/editor')) and TryStrToBool(XMLNode(XML, 'toolbar/editor').Attributes['visible'], Visible)) then
    if (Visible) then ToolbarTabs := ToolbarTabs + [ttEditor] else ToolbarTabs := ToolbarTabs - [ttEditor];
  if (Assigned(XMLNode(XML, 'toolbar/diagram')) and TryStrToBool(XMLNode(XML, 'toolbar/diagram').Attributes['visible'], Visible)) then
    if (Visible) then ToolbarTabs := ToolbarTabs + [ttDiagram] else ToolbarTabs := ToolbarTabs - [ttDiagram];
  if (Assigned(XMLNode(XML, 'sql/font/charset'))) then TryStrToInt(XMLNode(XML, 'sql/font/charset').Text, SQLFontCharset);
  if (Assigned(XMLNode(XML, 'sql/font/color'))) then SQLFontColor := StringToColor(XMLNode(XML, 'sql/font/color').Text);
  if (Assigned(XMLNode(XML, 'sql/font/name'))) then SQLFontName := XMLNode(XML, 'sql/font/name').Text;
  if (Assigned(XMLNode(XML, 'sql/font/size'))) then TryStrToInt(XMLNode(XML, 'sql/font/size').Text, SQLFontSize);
  if (Assigned(XMLNode(XML, 'sql/font/style'))) then SQLFontStyle := StrToStyle(XMLNode(XML, 'sql/font/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/comment/color'))) then Editor.CommentForeground := StringToColor(XMLNode(XML, 'sql/highlighting/comment/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/comment/background/color'))) then Editor.CommentBackground := StringToColor(XMLNode(XML, 'sql/highlighting/comment/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/comment/style'))) then Editor.CommentStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/comment/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/conditional/color'))) then Editor.ConditionalCommentForeground := StringToColor(XMLNode(XML, 'sql/highlighting/conditional/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/conditional/background/color'))) then Editor.ConditionalCommentBackground := StringToColor(XMLNode(XML, 'sql/highlighting/conditional/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/conditional/style'))) then Editor.ConditionalCommentStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/conditional/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/datatype/color'))) then Editor.DataTypeForeground := StringToColor(XMLNode(XML, 'sql/highlighting/datatype/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/datatype/background/color'))) then Editor.DataTypeBackground := StringToColor(XMLNode(XML, 'sql/highlighting/datatype/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/datatype/style'))) then Editor.DataTypeStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/datatype/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/function/color'))) then Editor.FunctionForeground := StringToColor(XMLNode(XML, 'sql/highlighting/function/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/function/background/color'))) then Editor.FunctionBackground := StringToColor(XMLNode(XML, 'sql/highlighting/function/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/function/style'))) then Editor.FunctionStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/function/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/identifier/color'))) then Editor.IdentifierForeground := StringToColor(XMLNode(XML, 'sql/highlighting/identifier/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/identifier/background/color'))) then Editor.IdentifierBackground := StringToColor(XMLNode(XML, 'sql/highlighting/identifier/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/identifier/style'))) then Editor.IdentifierStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/identifier/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/keyword/color'))) then Editor.KeywordForeground := StringToColor(XMLNode(XML, 'sql/highlighting/keyword/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/keyword/background/color'))) then Editor.KeywordBackground := StringToColor(XMLNode(XML, 'sql/highlighting/keyword/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/keyword/style'))) then Editor.KeywordStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/keyword/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/linenumbers/color'))) then Editor.LineNumbersForeground := StringToColor(XMLNode(XML, 'sql/highlighting/linenumbers/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/linenumbers/background/color'))) then Editor.LineNumbersBackground := StringToColor(XMLNode(XML, 'sql/highlighting/linenumbers/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/linenumbers/style'))) then Editor.LineNumbersStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/linenumbers/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/number/color'))) then Editor.NumberForeground := StringToColor(XMLNode(XML, 'sql/highlighting/number/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/number/background/color'))) then Editor.NumberBackground := StringToColor(XMLNode(XML, 'sql/highlighting/number/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/number/style'))) then Editor.NumberStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/number/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/string/color'))) then Editor.StringForeground := StringToColor(XMLNode(XML, 'sql/highlighting/string/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/string/background/color'))) then Editor.StringBackground := StringToColor(XMLNode(XML, 'sql/highlighting/string/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/string/style'))) then Editor.StringStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/string/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/symbol/color'))) then Editor.SymbolForeground := StringToColor(XMLNode(XML, 'sql/highlighting/symbol/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/symbol/background/color'))) then Editor.SymbolBackground := StringToColor(XMLNode(XML, 'sql/highlighting/symbol/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/symbol/style'))) then Editor.SymbolStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/symbol/style').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/variable/color'))) then Editor.VariableForeground := StringToColor(XMLNode(XML, 'sql/highlighting/variable/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/variable/background/color'))) then Editor.VariableBackground := StringToColor(XMLNode(XML, 'sql/highlighting/variable/background/color').Text);
  if (Assigned(XMLNode(XML, 'sql/highlighting/variable/style'))) then Editor.VariableStyle := StrToStyle(XMLNode(XML, 'sql/highlighting/variable/style').Text);
  if (Assigned(XMLNode(XML, 'tabs'))) then TryStrToBool(XMLNode(XML, 'tabs').Attributes['visible'], TabsVisible);
  if (Assigned(XMLNode(XML, 'top'))) then TryStrToInt(XMLNode(XML, 'top').Text, Top);
  if (Assigned(XMLNode(XML, 'updates/check'))) then TryStrToUpdateCheck(XMLNode(XML, 'updates/check').Text, UpdateCheck);
  if (Assigned(XMLNode(XML, 'updates/lastcheck'))) then TryStrToDate(XMLNode(XML, 'updates/lastcheck').Text, UpdateChecked, FileFormatSettings);
  if (Assigned(XMLNode(XML, 'width'))) then TryStrToInt(XMLNode(XML, 'width').Text, Width);

  Database.LoadFromXML(XMLNode(XML, 'database'));
  Editor.LoadFromXML(XMLNode(XML, 'editor'));
  Event.LoadFromXML(XMLNode(XML, 'event'));
  Export.LoadFromXML(XMLNode(XML, 'export'));
  Field.LoadFromXML(XMLNode(XML, 'field'));
  Find.LoadFromXML(XMLNode(XML, 'find'));
  ForeignKey.LoadFromXML(XMLNode(XML, 'foreignkey'));
  Host.LoadFromXML(XMLNode(XML, 'host'));
  Import.LoadFromXML(XMLNode(XML, 'import'));
  Index.LoadFromXML(XMLNode(XML, 'index'));
  ODBC.LoadFromXML(XMLNode(XML, 'odbc'));
  Paste.LoadFromXML(XMLNode(XML, 'paste'));
  Replace.LoadFromXML(XMLNode(XML, 'replace'));
  Routine.LoadFromXML(XMLNode(XML, 'routine'));
  Server.LoadFromXML(XMLNode(XML, 'server'));
  Accounts.LoadFromXML(XMLNode(XML, 'accounts'));
  SQLHelp.LoadFromXML(XMLNode(XML, 'sqlhelp'));
  Statement.LoadFromXML(XMLNode(XML, 'statement'));
  Table.LoadFromXML(XMLNode(XML, 'table'));
  TableService.LoadFromXML(XMLNode(XML, 'tableservice'));
  Transfer.LoadFromXML(XMLNode(XML, 'transfer'));
  Trigger.LoadFromXML(XMLNode(XML, 'trigger'));
  User.LoadFromXML(XMLNode(XML, 'user'));
  View.LoadFromXML(XMLNode(XML, 'view'));


  FreeAndNil(FLanguage);
end;

function TPPreferences.LoadStr(const Index: Integer; const Param1: string = ''; const Param2: string = ''; const Param3: string = ''): string;
begin
  SetLength(Result, 100);
  if (Assigned(Language) and (Language.Strs[Index] <> '')) then
    Result := Language.Strs[Index]
  else
    Result := SysUtils.LoadStr(10000 + Index);
  if (Result = '') then
    Result := '<' + IntToStr(Index) + '>';

  Result := ReplaceStr(Result, '%1', Param1);
  Result := ReplaceStr(Result, '%2', Param2);
  Result := ReplaceStr(Result, '%3', Param3);
end;

procedure TPPreferences.SaveToRegistry();
var
  KeyName: string;
begin
  Access := KEY_ALL_ACCESS;

  if (AssociateSQL <> OldAssociateSQL) then
  begin
    RootKey := HKEY_CLASSES_ROOT;

    if (OpenKey('.sql', True)) then
    begin
      if (not ValueExists('')) then WriteString('', 'SQLFile');
      KeyName := ReadString('');
      CloseKey();
    end;

    if (not AssociateSQL) then
    begin
      if (OpenKey(KeyName + '\DefaultIcon', False)) then
      begin
        if (ValueExists('')) then
          DeleteValue('');
        CloseKey();
      end;
      if (OpenKey(KeyName + '\shell\open\command', False)) then
      begin
        if (ValueExists('')) then
          DeleteValue('');
        CloseKey();
      end;
    end
    else
    begin
      if (OpenKey(KeyName + '\DefaultIcon', True)) then
        begin WriteString('', Application.ExeName + ',0'); CloseKey(); end;
      if (OpenKey(KeyName + '\shell\open\command', True)) then
        begin WriteString('', '"' + Application.ExeName + '" "%0"'); CloseKey(); end;
    end;

    RootKey := HKEY_CURRENT_USER;
  end;

  RootKey := HKEY_CURRENT_USER;

  if (OpenKey(KeyBase, False) or (UserPath <> ExtractFilePath(Application.ExeName)) and OpenKey(KeyBase, True)) then
  begin
    if (SetupProgram <> '') then
      WriteString('SetupProgram', SetupProgram)
    else if (ValueExists('SetupProgram')) then
      DeleteValue('SetupProgram');
    if (SetupProgramInstalled) then
      WriteBool('SetupProgramInstalled', SetupProgramInstalled)
    else if (ValueExists('SetupProgramInstalled')) then
      DeleteValue('SetupProgramInstalled');
    WriteString('Path', Path);

    CloseKey();
  end;

  Access := KEY_READ;

  SaveToXML();
end;

procedure TPPreferences.SaveToXML();
var
  XML: IXMLNode;
begin
  XML := GetXML();

  XML.OwnerDocument.Options := XML.OwnerDocument.Options + [doNodeAutoCreate];

  XMLNode(XML, 'addressbar').Attributes['visible'] := AddressBarVisible;
  XMLNode(XML, 'grid/currentrow/background').Attributes['visible'] := GridCurrRowBGColorEnabled;
  XMLNode(XML, 'grid/currentrow/background/color').Text := ColorToString(GridCurrRowBGColor);
  XMLNode(XML, 'grid/font/charset').Text := IntToStr(GridFontCharset);
  XMLNode(XML, 'grid/font/color').Text := ColorToString(GridFontColor);
  XMLNode(XML, 'grid/font/name').Text := GridFontName;
  XMLNode(XML, 'grid/font/size').Text := IntToStr(GridFontSize);
  XMLNode(XML, 'grid/font/style').Text := StyleToStr(GridFontStyle);
  XMLNode(XML, 'grid/memo').Attributes['visible'] := GridShowMemoContent;
  XMLNode(XML, 'grid/null').Attributes['visible'] := GridNullText;
  XMLNode(XML, 'grid/null/background').Attributes['visible'] := GridNullBGColorEnabled;
  XMLNode(XML, 'grid/null/background/color').Text := ColorToString(GridNullBGColor);
  XMLNode(XML, 'grid/maxcolumnwidth').Text := IntToStr(GridMaxColumnWidth);
  XMLNode(XML, 'grid/row/background').Attributes['visible'] := GridRowBGColorEnabled;
  XMLNode(XML, 'height').Text := IntToStr(Height);
  XMLNode(XML, 'installdate').Text := DateToStr(InstallDate);
//  XMLNode(XML, 'donation').Attributes['visible'] := DonationVisible;
  XMLNode(XML, 'language/file').Text := ExtractFileName(LanguageFilename);
  XMLNode(XML, 'left').Text := IntToStr(Left);
  XMLNode(XML, 'log/font/charset').Text := IntToStr(LogFontCharset);
  XMLNode(XML, 'log/font/color').Text := ColorToString(LogFontColor);
  XMLNode(XML, 'log/font/name').Text := LogFontName;
  XMLNode(XML, 'log/font/size').Text := IntToStr(LogFontSize);
  XMLNode(XML, 'log/font/style').Text := StyleToStr(LogFontStyle);
  XMLNode(XML, 'log/highlighting').Attributes['visible'] := LogHighlighting;
  XMLNode(XML, 'log/size').Text := IntToStr(LogSize);
  XMLNode(XML, 'log/dbresult').Attributes['visible'] := LogResult;
  XMLNode(XML, 'log/time').Attributes['visible'] := LogTime;
  if (WindowState in [wsNormal, wsMaximized	]) then
    XMLNode(XML, 'windowstate').Text := WindowStateToStr(WindowState);
  XMLNode(XML, 'toolbar/objects').Attributes['visible'] := ttObjects in ToolbarTabs;
  XMLNode(XML, 'toolbar/browser').Attributes['visible'] := ttBrowser in ToolbarTabs;
  XMLNode(XML, 'toolbar/ide').Attributes['visible'] := ttIDE in ToolbarTabs;
  XMLNode(XML, 'toolbar/builder').Attributes['visible'] := ttBuilder in ToolbarTabs;
  XMLNode(XML, 'toolbar/editor').Attributes['visible'] := ttEditor in ToolbarTabs;
  XMLNode(XML, 'toolbar/diagram').Attributes['visible'] := ttDiagram in ToolbarTabs;
  XMLNode(XML, 'sql/font/charset').Text := IntToStr(SQLFontCharset);
  XMLNode(XML, 'sql/font/color').Text := ColorToString(SQLFontColor);
  XMLNode(XML, 'sql/font/name').Text := SQLFontName;
  XMLNode(XML, 'sql/font/size').Text := IntToStr(SQLFontSize);
  XMLNode(XML, 'sql/font/style').Text := StyleToStr(SQLFontStyle);
  XMLNode(XML, 'sql/highlighting/comment/color').Text := ColorToString(Editor.CommentForeground);
  XMLNode(XML, 'sql/highlighting/comment/background/color').Text := ColorToString(Editor.CommentBackground);
  XMLNode(XML, 'sql/highlighting/comment/style').Text := StyleToStr(Editor.CommentStyle);
  XMLNode(XML, 'sql/highlighting/conditional/color').Text := ColorToString(Editor.ConditionalCommentForeground);
  XMLNode(XML, 'sql/highlighting/conditional/background/color').Text := ColorToString(Editor.ConditionalCommentBackground);
  XMLNode(XML, 'sql/highlighting/conditional/style').Text := StyleToStr(Editor.ConditionalCommentStyle);
  XMLNode(XML, 'sql/highlighting/datatype/color').Text := ColorToString(Editor.DataTypeForeground);
  XMLNode(XML, 'sql/highlighting/datatype/background/color').Text := ColorToString(Editor.DataTypeBackground);
  XMLNode(XML, 'sql/highlighting/datatype/style').Text := StyleToStr(Editor.DataTypeStyle);
  XMLNode(XML, 'sql/highlighting/function/color').Text := ColorToString(Editor.FunctionForeground);
  XMLNode(XML, 'sql/highlighting/function/background/color').Text := ColorToString(Editor.FunctionBackground);
  XMLNode(XML, 'sql/highlighting/function/style').Text := StyleToStr(Editor.FunctionStyle);
  XMLNode(XML, 'sql/highlighting/identifier/color').Text := ColorToString(Editor.IdentifierForeground);
  XMLNode(XML, 'sql/highlighting/identifier/background/color').Text := ColorToString(Editor.IdentifierBackground);
  XMLNode(XML, 'sql/highlighting/identifier/style').Text := StyleToStr(Editor.IdentifierStyle);
  XMLNode(XML, 'sql/highlighting/keyword/color').Text := ColorToString(Editor.KeywordForeground);
  XMLNode(XML, 'sql/highlighting/keyword/background/color').Text := ColorToString(Editor.KeywordBackground);
  XMLNode(XML, 'sql/highlighting/keyword/style').Text := StyleToStr(Editor.KeywordStyle);
  XMLNode(XML, 'sql/highlighting/linenumbers/color').Text := ColorToString(Editor.LineNumbersForeground);
  XMLNode(XML, 'sql/highlighting/linenumbers/background/color').Text := ColorToString(Editor.LineNumbersBackground);
  XMLNode(XML, 'sql/highlighting/linenumbers/style').Text := StyleToStr(Editor.LineNumbersStyle);
  XMLNode(XML, 'sql/highlighting/number/color').Text := ColorToString(Editor.NumberForeground);
  XMLNode(XML, 'sql/highlighting/number/background/color').Text := ColorToString(Editor.NumberBackground);
  XMLNode(XML, 'sql/highlighting/number/style').Text := StyleToStr(Editor.NumberStyle);
  XMLNode(XML, 'sql/highlighting/string/color').Text := ColorToString(Editor.StringForeground);
  XMLNode(XML, 'sql/highlighting/string/background/color').Text := ColorToString(Editor.StringBackground);
  XMLNode(XML, 'sql/highlighting/string/style').Text := StyleToStr(Editor.StringStyle);
  XMLNode(XML, 'sql/highlighting/symbol/color').Text := ColorToString(Editor.SymbolForeground);
  XMLNode(XML, 'sql/highlighting/symbol/background/color').Text := ColorToString(Editor.SymbolBackground);
  XMLNode(XML, 'sql/highlighting/symbol/style').Text := StyleToStr(Editor.SymbolStyle);
  XMLNode(XML, 'sql/highlighting/variable/color').Text := ColorToString(Editor.VariableForeground);
  XMLNode(XML, 'sql/highlighting/variable/background/color').Text := ColorToString(Editor.VariableBackground);
  XMLNode(XML, 'sql/highlighting/variable/style').Text := StyleToStr(Editor.VariableStyle);
  XMLNode(XML, 'tabs').Attributes['visible'] := TabsVisible;
  XMLNode(XML, 'top').Text := IntToStr(Top);
  XMLNode(XML, 'updates/check').Text := UpdateCheckToStr(UpdateCheck);
  XMLNode(XML, 'updates/lastcheck').Text := DateToStr(UpdateChecked, FileFormatSettings);
  XMLNode(XML, 'width').Text := IntToStr(Width);

  Database.SaveToXML(XMLNode(XML, 'database'));
  Editor.SaveToXML(XMLNode(XML, 'editor'));
  Event.SaveToXML(XMLNode(XML, 'event'));
  Export.SaveToXML(XMLNode(XML, 'export'));
  Field.SaveToXML(XMLNode(XML, 'field'));
  Find.SaveToXML(XMLNode(XML, 'find'));
  ForeignKey.SaveToXML(XMLNode(XML, 'foreignkey'));
  Host.SaveToXML(XMLNode(XML, 'host'));
  Import.SaveToXML(XMLNode(XML, 'import'));
  Index.SaveToXML(XMLNode(XML, 'index'));
  ODBC.SaveToXML(XMLNode(XML, 'odbc'));
  Paste.SaveToXML(XMLNode(XML, 'paste'));
  Replace.SaveToXML(XMLNode(XML, 'replace'));
  Routine.SaveToXML(XMLNode(XML, 'routine'));
  Server.SaveToXML(XMLNode(XML, 'server'));
  Accounts.SaveToXML(XMLNode(XML, 'accounts'));
  SQLHelp.SaveToXML(XMLNode(XML, 'sqlhelp'));
  Statement.SaveToXML(XMLNode(XML, 'statement'));
  Table.SaveToXML(XMLNode(XML, 'table'));
  TableService.SaveToXML(XMLNode(XML, 'tableservice'));
  Transfer.SaveToXML(XMLNode(XML, 'transfer'));
  Trigger.SaveToXML(XMLNode(XML, 'trigger'));
  User.SaveToXML(XMLNode(XML, 'user'));
  View.SaveToXML(XMLNode(XML, 'view'));

  if (XML.OwnerDocument.Modified and ForceDirectories(ExtractFilePath(Filename))) then
    XML.OwnerDocument.SaveToFile(Filename);
end;

{******************************************************************************}

initialization
  Preferences := nil;

  FileFormatSettings := TFormatSettings.Create(LOCALE_SYSTEM_DEFAULT);
  FileFormatSettings.ThousandSeparator := ',';
  FileFormatSettings.DecimalSeparator := '.';
  FileFormatSettings.DateSeparator := '/';
  FileFormatSettings.TimeSeparator := ':';
  FileFormatSettings.ListSeparator := ',';
  FileFormatSettings.ShortDateFormat := 'dd/mm/yy';
  FileFormatSettings.LongDateFormat := 'dd/mm/yyyy';
  FileFormatSettings.TimeAMString := '';
  FileFormatSettings.TimePMString := '';
  FileFormatSettings.ShortTimeFormat := 'hh:mm';
  FileFormatSettings.LongTimeFormat := 'hh:mm:ss';
end.

