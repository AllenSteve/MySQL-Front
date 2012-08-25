unit fTools;

interface {********************************************************************}

uses
  Windows, XMLDoc, XMLIntf, DBGrids, msxml, Zip, Printers,
  SysUtils, DB, Classes, Graphics, SyncObjs,
  ODBCAPI,
  DISQLite3Api,
  SynPDF,
  MySQLConsts, MySQLDB, SQLUtils, CSVUtils,
  fClient;

const
  CP_UNICODE = 1200;
  BOM_UTF8: PAnsiChar = Chr($EF) + Chr($BB) + Chr($BF);
  BOM_UNICODE: PAnsiChar = Chr($FF) + Chr($FE);

type
  TTools = class(TThread)
  type
    TItem = record
      Client: TCClient;
      DatabaseName: string;
      TableName: string;
    end;
    TErrorType = (TE_Database, TE_NoPrimaryIndex, TE_DifferentPrimaryIndex, TE_File, TE_ODBC, TE_SQLite, TE_XML, TE_Warning, TE_Printer);
    TError = record
      ErrorType: TErrorType;
      ErrorCode: Integer;
      ErrorMessage: string;
    end;
    TErrorEvent = procedure(const Sender: TObject; const Error: TError; const Item: TItem; const ShowRetry: Boolean; var Success: TDataAction) of object;
    TOnExecuted = procedure(const Success: Boolean) of object;
    PProgressInfos = ^TProgressInfos;
    TProgressInfos = record
      TablesDone, TablesSum: Integer;
      RecordsDone, RecordsSum: Int64;
      TimeDone, TimeSum: TDateTime;
      Progress: Byte;
    end;
    TOnUpdate = procedure(const ProgressInfos: TProgressInfos) of object;

    TDataFileBuffer = class
    private
      Buffer: record
        Mem: PAnsiChar;
        Size: Integer;
        Write: PAnsiChar;
      end;
      CodePage: Cardinal;
      MaxCharSize: Integer;
      Temp1: record
        Mem: Pointer;
        Size: Integer;
      end;
      Temp2: record
        Mem: my_char;
        Size: Integer;
      end;
      function GetData(): Pointer; inline;
      function GetSize(): Integer; inline;
      procedure Resize(const NeededSize: Integer);
    public
      procedure Clear();
      constructor Create(const ACodePage: Cardinal);
      destructor Destroy(); override;
      procedure Write(const Data: Pointer; const Size: Integer; const Quote: Boolean = False); overload;
      procedure WriteData(const Text: PChar; const Length: Integer; const Quote: Boolean = False); overload;
      procedure WriteText(const Text: PChar; const Length: Integer); overload;
      procedure WriteText(const Text: my_char; const Length: Integer; const CodePage: Cardinal); overload;
      procedure WriteBinary(const Value: PChar; const Length: Integer); overload;
      procedure WriteBinary(const Value: my_char; const Length: Integer); overload;
      property Data: Pointer read GetData;
      property Size: Integer read GetSize;
    end;

    TStringBuffer = class
    private
      Buffer: record
        Mem: PChar;
        Size: Integer;
        Write: PChar;
      end;
      function GetData(): Pointer; inline;
      function GetSize(): Integer; inline;
      procedure Resize(const NeededLength: Integer);
    public
      procedure Clear(); virtual;
      constructor Create(const MemSize: Integer);
      destructor Destroy(); override;
      function Read(): string; virtual;
      procedure Write(const Text: string); overload; inline;
      property Data: Pointer read GetData;
      property Size: Integer read GetSize;
    end;

  private
    CriticalSection: TCriticalSection;
    FOnExecuted: TOnExecuted;
    FErrorCount: Integer;
    FOnError: TErrorEvent;
    FOnUpdate: TOnUpdate;
    FUserAbort: TEvent;
    ProgressInfos: TProgressInfos;
  protected
    StartTime: TDateTime;
    Success: TDataAction;
    procedure AfterExecute(); virtual;
    procedure BackupTable(const Item: TItem; const Rename: Boolean = False); virtual;
    procedure BeforeExecute(); virtual;
    function DatabaseError(const Client: TCClient): TError; virtual;
    procedure DoError(const Error: TError; const Item: TItem; const ShowRetry: Boolean); overload; virtual;
    procedure DoError(const Error: TError; const Item: TItem; const ShowRetry: Boolean; var SQL: string); overload; virtual;
    procedure DoUpdateGUI(); virtual; abstract;
    function EmptyToolsItem(): TItem; virtual;
    function NoPrimaryIndexError(): TError; virtual;
    property OnError: TErrorEvent read FOnError write FOnError;
  public
    Wnd: HWND;
    constructor Create(); virtual;
    destructor Destroy(); override;
    property ErrorCount: Integer read FErrorCount;
    property OnExecuted: TOnExecuted read FOnExecuted write FOnExecuted;
    property OnUpdate: TOnUpdate read FOnUpdate write FOnUpdate;
    property UserAbort: TEvent read FUserAbort;
  end;

  TTImport = class(TTools)
  type
    TImportType = (itInsert, itReplace, itUpdate);
    PItem = ^TItem;
    TItem = record
      TableName: string;
      RecordsDone, RecordsSum: Integer;
      Done: Boolean;
      SourceTableName: string;
    end;
  private
    EscapedFieldNames: string;
    FClient: TCClient;
    FDatabase: TCDatabase;
  protected
    Items: array of TItem;
    procedure AfterExecute(); override;
    procedure AfterExecuteData(var Item: TItem); virtual;
    procedure BeforeExecute(); override;
    procedure BeforeExecuteData(var Item: TItem); virtual;
    procedure Close(); virtual;
    function DoExecuteSQL(const Item: TItem; var SQL: string): Boolean; virtual;
    procedure DoUpdateGUI(); override;
    procedure ExecuteData(var Item: TItem; const Table: TCTable); virtual;
    procedure ExecuteStructure(var Item: TItem); virtual;
    function GetValues(const Item: TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean; overload; virtual;
    function GetValues(const Item: TItem; var Values: TSQLStrings): Boolean; overload; virtual;
    procedure Open(); virtual;
    function ToolsItem(const Item: TItem): TTools.TItem; virtual;
    property Client: TCClient read FClient;
    property Database: TCDatabase read FDatabase;
  public
    Fields: array of TCTableField;
    Data: Boolean;
    Error: Boolean;
    SourceFields: array of record
      Name: string;
    end;
    ImportType: TImportType;
    Structure: Boolean;
    constructor Create(const AClient: TCClient; const ADatabase: TCDatabase); reintroduce; virtual;
    procedure Execute(); override;
    property OnError;
  end;

  TTImportFile = class(TTImport)
  private
    BytesPerSector: DWord;
    FFilename: TFileName;
    FileBuffer: record
      Mem: PAnsiChar;
      Index: DWord;
      Size: DWord;
    end;
    FFileSize: DWord;
  protected
    BOMLength: TLargeInteger;
    FCodePage: Cardinal;
    FileContent: record
      Str: string;
      Index: Integer;
    end;
    FilePos: TLargeInteger;
    Handle: THandle;
    function DoOpenFile(const Filename: TFileName; out Handle: THandle; out Error: TTools.TError): Boolean; virtual;
    function ReadContent(const NewFilePos: TLargeInteger = -1): Boolean; virtual;
    procedure DoUpdateGUI(); override;
    procedure Open(); override;
    property FileSize: DWord read FFileSize;
  public
    procedure Close(); override;
    constructor Create(const AFilename: TFileName; const ACodePage: Cardinal; const AClient: TCClient; const ADatabase: TCDatabase); reintroduce; virtual;
    property CodePage: Cardinal read FCodePage;
    property Filename: TFileName read FFilename;
  end;

  TTImportSQL = class(TTImportFile)
  private
    FSetCharacterSetApplied: Boolean;
  public
    Text: PString;
    constructor Create(const AFilename: TFileName; const ACodePage: Cardinal; const AClient: TCClient; const ADatabase: TCDatabase); override;
    procedure Execute(); overload; override;
    property SetCharacterSetApplied: Boolean read FSetCharacterSetApplied;
  end;

  TTImportText = class(TTImportFile)
  private
    CSVColumns: array of Integer;
    CSVValues: TCSVValues;
    FileFields: array of record
      Name: string;
      FieldTypes: set of Byte;
    end;
    CSVUnquoteMem: PChar;
    CSVUnquoteMemSize: Integer;
    function GetHeadlineNameCount(): Integer;
    function GetHeadlineName(Index: Integer): string;
  protected
    procedure AfterExecuteData(var Item: TTImport.TItem); override;
    procedure BeforeExecuteData(var Item: TTImport.TItem); override;
    procedure ExecuteStructure(var Item: TTImport.TItem); override;
    function GetValues(const Item: TTImport.TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean; override;
    function GetValues(const Item: TTImport.TItem; var Values: TSQLStrings): Boolean; overload; override;
  public
    Charset: string;
    Collation: string;
    Delimiter: Char;
    Engine: string;
    Quoter: Char;
    RowType: TMySQLRowType;
    UseHeadline: Boolean;
    procedure Add(const TableName: string); virtual;
    procedure Close(); override;
    constructor Create(const AFilename: TFileName; const ACodePage: Cardinal; const AClient: TCClient; const ADatabase: TCDatabase); reintroduce; virtual;
    destructor Destroy(); override;
    function GetPreviewValues(var Values: TSQLStrings): Boolean; virtual;
    procedure Open(); override;
    property HeadlineNameCount: Integer read GetHeadlineNameCount;
    property HeadlineNames[Index: Integer]: string read GetHeadlineName;
  end;

  TTImportODBC = class(TTImport)
  private
    ColumnDesc: array of record
      ColumnName: PSQLTCHAR;
      SQLDataType: SQLSMALLINT;
      MaxDataSize: SQLUINTEGER;
      DecimalDigits: SQLSMALLINT;
      Nullable: SQLSMALLINT;
      SQL_C_TYPE: SQLSMALLINT;
    end;
    FHandle: SQLHANDLE;
    ODBCData: SQLPOINTER;
    ODBCMem: Pointer;
    ODBCMemSize: Integer;
    Stmt: SQLHANDLE;
  protected
    procedure AfterExecuteData(var Item: TTImport.TItem); override;
    procedure BeforeExecute(); override;
    procedure BeforeExecuteData(var Item: TTImport.TItem); override;
    function GetValues(const Item: TTImport.TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean; override;
    function GetValues(const Item: TTImport.TItem; var Values: TSQLStrings): Boolean; overload; override;
    procedure ExecuteStructure(var Item: TTImport.TItem); override;
    function ODBCStmtException(const Handle: SQLHSTMT): Exception;
  public
    Charset: string;
    Collation: string;
    Engine: string;
    RowType: TMySQLRowType;
    procedure Add(const TableName: string; const SourceTableName: string); virtual;
    constructor Create(const AHandle: SQLHANDLE; const ADatabase: TCDatabase); reintroduce; virtual;
    destructor Destroy(); override;
  end;

  TTImportSQLite = class(TTImport)
  private
    Handle: sqlite3_ptr;
    Stmt: sqlite3_stmt_ptr;
  protected
    procedure AfterExecuteData(var Item: TTImport.TItem); override;
    procedure BeforeExecute(); override;
    procedure BeforeExecuteData(var Item: TTImport.TItem); override;
    procedure ExecuteStructure(var Item: TTImport.TItem); override;
    function GetValues(const Item: TTImport.TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean; override;
    function GetValues(const Item: TTImport.TItem; var Values: TSQLStrings): Boolean; overload; override;
  public
    Charset: string;
    Collation: string;
    Engine: string;
    RowType: TMySQLRowType;
    procedure Add(const TableName: string; const SheetName: string); virtual;
    constructor Create(const AHandle: sqlite3_ptr; const ADatabase: TCDatabase); reintroduce; virtual;
  end;

  TTImportXML = class(TTImport)
  private
    XMLDocument: IXMLDOMDocument;
    XMLNode: IXMLDOMNode;
  protected
    procedure BeforeExecute(); override;
    procedure BeforeExecuteData(var Item: TTImport.TItem); override;
    function GetValues(const Item: TTImport.TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean; override;
    function GetValues(const Item: TTImport.TItem; var Values: TSQLStrings): Boolean; overload; override;
  public
    RecordTag: string;
    procedure Add(const TableName: string); virtual;
    constructor Create(const AFilename: TFileName; const ATable: TCBaseTable); reintroduce; virtual;
    destructor Destroy(); override;
  end;

  TTExport = class(TTools)
  type
    PExportObject = ^TExportObject;
    TExportObject = record
      DBObject: TCDBObject;
      RecordsDone, RecordsSum: Integer;
      Done: Boolean;
    end;
    TExportDBGrid = record
      DBGrid: TDBGrid;
      RecordsDone, RecordsSum: Integer;
      Done: Boolean;
    end;
    TExportDBGrids = array of TExportDBGrid;
  private
    DataTables: TList;
    FDBGrids: TExportDBGrids;
    FClient: TCClient;
    ExportObjects: array of TExportObject;
  protected
    procedure AfterExecute(); override;
    procedure BeforeExecute(); override;
    procedure DoUpdateGUI(); override;
    function EmptyToolsItem(): TTools.TItem; override;
    procedure ExecuteDatabaseFooter(const Database: TCDatabase); virtual;
    procedure ExecuteDatabaseHeader(const Database: TCDatabase); virtual;
    procedure ExecuteDBGrid(var ExportDBGrid: TExportDBGrid); virtual;
    procedure ExecuteEvent(const Event: TCEvent); virtual;
    procedure ExecuteFooter(); virtual;
    procedure ExecuteHeader(); virtual;
    procedure ExecuteRoutine(const Routine: TCRoutine); virtual;
    procedure ExecuteTable(var ExportObject: TExportObject; const DataHandle: TMySQLConnection.TDataResult); virtual;
    procedure ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); virtual;
    procedure ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); virtual;
    procedure ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); virtual; abstract;
    procedure ExecuteTrigger(const Trigger: TCTrigger); virtual;
    function ToolsItem(const ExportDBGrid: TExportDBGrid): TTools.TItem; overload; virtual;
    function ToolsItem(const ExportObject: TExportObject): TTools.TItem; overload; virtual;
    property DBGrids: TExportDBGrids read FDBGrids;
  public
    Data: Boolean;
    DestinationFields: array of record
      Name: string;
    end;
    Fields: array of TField;
    Structure: Boolean;
    TableFields: array of TCTableField;
    procedure Add(const ADBGrid: TDBGrid); overload; virtual;
    procedure Add(const ADBObject: TCDBObject); overload; virtual;
    constructor Create(const AClient: TCClient); reintroduce; virtual;
    destructor Destroy(); override;
    procedure Execute(); override;
    property Client: TCClient read FClient;
    property OnError;
  end;

  TTExportFile = class(TTExport)
  private
    ContentBuffer: TTools.TStringBuffer;
    FCodePage: Cardinal;
    FileBuffer: record
      Mem: PAnsiChar;
      Size: Cardinal;
    end;
    FFilename: TFileName;
    Handle: THandle;
    procedure Flush();
  protected
    procedure CloseFile(); virtual;
    procedure DoFileCreate(const Filename: TFileName); virtual;
    function FileCreate(const Filename: TFileName; out Error: TTools.TError): Boolean; virtual;
    procedure WriteContent(const Content: string); virtual;
  public
    constructor Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal); reintroduce; virtual;
    destructor Destroy(); override;
    property CodePage: Cardinal read FCodePage;
    property Filename: TFileName read FFilename;
  end;

  TTExportSQL = class(TTExportFile)
  private
    ForeignKeySources: string;
    SQLInsertPacketLen: Integer;
    SQLInsertPostfix: string;
    SQLInsertPostfixPacketLen: Integer;
    SQLInsertPrefix: string;
    SQLInsertPrefixPacketLen: Integer;
  protected
    procedure ExecuteDatabaseFooter(const Database: TCDatabase); override;
    procedure ExecuteDatabaseHeader(const Database: TCDatabase); override;
    procedure ExecuteEvent(const Event: TCEvent); override;
    procedure ExecuteFooter(); override;
    procedure ExecuteHeader(); override;
    procedure ExecuteRoutine(const Routine: TCRoutine); override;
    procedure ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTrigger(const Trigger: TCTrigger); override;
    function FileCreate(const Filename: TFileName; out Error: TTools.TError): Boolean; override;
  public
    CreateDatabaseStmts: Boolean;
    DisableKeys: Boolean;
    IncludeDropStmts: Boolean;
    ReplaceData: Boolean;
    UseDatabaseStmts: Boolean;
    constructor Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal); override;
  end;

  TTExportText = class(TTExportFile)
  private
    TempFilename: string;
    Zip: TZipFile;
  protected
    procedure AfterExecute(); override;
    procedure BeforeExecute(); override;
    procedure ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    function FileCreate(const Filename: TFileName; out Error: TTools.TError): Boolean; override;
  public
    Quoter: Char;
    Delimiter: string;
    QuoteStringValues: Boolean;
    QuoteValues: Boolean;
    constructor Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal); override;
    destructor Destroy(); override;
  end;

  TTExportUML = class(TTExportFile)
  protected
    procedure ExecuteHeader(); override;
  end;

  TTExportHTML = class(TTExportUML)
  private
    CSS: array of string;
    FieldOfPrimaryIndex: array of Boolean;
    Font: TFont;
    SQLFont: TFont;
    RowOdd: Boolean;
    function Escape(const Str: string): string;
  protected
    procedure ExecuteDatabaseHeader(const Database: TCDatabase); override;
    procedure ExecuteFooter(); override;
    procedure ExecuteHeader(); override;
    procedure ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
  public
    TextContent: Boolean;
    NULLText: Boolean;
    RowBackground: Boolean;
    constructor Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal); override;
    destructor Destroy(); override;
  end;

  TTExportXML = class(TTExportUML)
  private
    function Escape(const Str: string): string; virtual;
  protected
    procedure ExecuteDatabaseFooter(const Database: TCDatabase); override;
    procedure ExecuteDatabaseHeader(const Database: TCDatabase); override;
    procedure ExecuteFooter(); override;
    procedure ExecuteHeader(); override;
    procedure ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
  public
    DatabaseTag, DatabaseAttribute: string;
    FieldTag, FieldAttribute: string;
    RecordTag: string;
    RootTag: string;
    TableTag, TableAttribute: string;
    constructor Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal); override;
  end;

  TTExportODBC = class(TTExport)
  private
    FHandle: SQLHDBC;
    FODBC: SQLHENV;
    FStmt: SQLHSTMT;
    Parameter: array of record
      Buffer: SQLPOINTER;
      BufferSize: SQLINTEGER;
      Size: SQLINTEGER;
    end;
  protected
    TableName: string;
    procedure ExecuteHeader(); override;
    procedure ExecuteFooter(); override;
    procedure ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    property Handle: SQLHDBC read FHandle;
    property ODBC: SQLHENV read FODBC;
    property Stmt: SQLHSTMT read FStmt;
  public
    constructor Create(const AClient: TCClient; const AODBC: SQLHDBC = SQL_NULL_HANDLE; const AHandle: SQLHDBC = SQL_NULL_HANDLE); reintroduce; virtual;
  end;

  TTExportAccess = class(TTExportODBC)
  private
    Filename: TFileName;
  protected
    procedure ExecuteFooter(); override;
    procedure ExecuteHeader(); override;
  public
    constructor Create(const AClient: TCClient; const AFilename: TFileName); reintroduce; virtual;
  end;

  TTExportExcel = class(TTExportODBC)
  private
    Filename: TFileName;
    Sheet: Integer;
  protected
    procedure ExecuteFooter(); override;
    procedure ExecuteHeader(); override;
    procedure ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
  public
    constructor Create(const AClient: TCClient; const AFilename: TFileName); reintroduce; virtual;
  end;

  TTExportSQLite = class(TTExport)
  private
    Filename: TFileName;
    Handle: sqlite3_ptr;
    Stmt: sqlite3_stmt_ptr;
    Text: array of RawByteString;
  protected
    procedure ExecuteFooter(); override;
    procedure ExecuteHeader(); override;
    procedure ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
  public
    constructor Create(const AClient: TCClient; const AFilename: TFileName); reintroduce; virtual;
  end;

  TTExportCanvas = class(TTExport)
  type
    TColumn = record
      Canvas: TCanvas;
      HeaderBold: Boolean;
      HeaderText: string;
      Left: Integer;
      Width: Integer;
    end;
    TGridData = array of array of record
      Bold: Boolean;
      Gray: Boolean;
      Text: string;
    end;
  const
    PaddingMilliInch = 20;
    LineHeightMilliInch = 10;
    LineWidthMilliInch = 10;
    MarginsMilliInch: TRect = (Left: 1000; Top: 500; Right: 500; Bottom: 500);
  private
    Columns: array of TColumn;
    ContentArea: TRect;
    ContentFont: TFont;
    DateTime: TDateTime;
    GridFont: TFont;
    GridTop: Integer;
    MaxFieldsCharLengths: array of array of Integer;
    PageFont: TFont;
    PageNumber: record Row, Column: Integer; end;
    SQLFont: TFont;
    Y: Integer;
    function AllocateHeight(const Height: Integer): Boolean;
    procedure ContentTextOut(Text: string; const ExtraPadding: Integer = 0);
    procedure GridDrawHorzLine(const Y: Integer);
    procedure GridDrawVertLines();
    procedure GridHeader();
    procedure GridOut(var GridData: TGridData);
    function GridTextOut(const Column: Integer; Text: string; const TextFormat: TTextFormat; const Bold, Gray: Boolean): Integer;
    procedure PageBreak(const NewPageRow: Boolean);
    procedure PageFooter();
  protected
    Canvas: TCanvas;
    LineHeight: Integer;
    LineWidth: Integer;
    Margins: TRect;
    Padding: Integer;
    PageHeight: Integer;
    PageWidth: Integer;
    procedure AddPage(const NewPageRow: Boolean); virtual; abstract;
    procedure ExecuteDatabaseHeader(const Database: TCDatabase); override;
    procedure ExecuteFooter(); override;
    procedure ExecuteHeader(); override;
    procedure ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
    procedure ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery); override;
  public
    IndexBackground: Boolean;
    NULLText: Boolean;
    constructor Create(const AClient: TCClient); override;
    destructor Destroy(); override;
  end;

  TTExportPrint = class(TTExportCanvas)
  private
    Printer: TPrinter;
  protected
    procedure AddPage(const NewPageRow: Boolean); override;
    procedure ExecuteHeader(); override;
    procedure ExecuteFooter(); override;
  public
    constructor Create(const AClient: TCClient; const ATitle: string); reintroduce; virtual;
    destructor Destroy(); override;
  end;

  TTExportPDF = class(TTExportCanvas)
  private
    PDF: TPDFDocumentGDI;
    Filename: TFileName;
  protected
    procedure AddPage(const NewPageRow: Boolean); override;
    procedure ExecuteHeader(); override;
    procedure ExecuteFooter(); override;
  public
    constructor Create(const AClient: TCClient; const AFilename: TFileName); reintroduce; virtual;
    destructor Destroy(); override;
  end;

  TTFind = class(TTools)
  type
    PItem = ^TItem;
    TItem = record
      DatabaseName: string;
      TableName: string;
      FieldNames: array of string;
      RecordsFound, RecordsDone, RecordsSum: Integer;
      Done: Boolean;
    end;
  private
    FClient: TCClient;
  protected
    FItem: PItem;
    Items: array of TItem;
    procedure AfterExecute(); override;
    procedure BeforeExecute(); override;
    function DoExecuteSQL(const Client: TCClient; var Item: TItem; var SQL: string): Boolean; virtual;
    procedure DoUpdateGUI(); override;
    procedure ExecuteDefault(var Item: TItem; const Table: TCBaseTable); virtual;
    procedure ExecuteMatchCase(var Item: TItem; const Table: TCBaseTable); virtual;
    procedure ExecuteWholeValue(var Item: TItem; const Table: TCBaseTable); virtual;
    function ToolsItem(const Item: TItem): TTools.TItem; virtual;
    property Client: TCClient read FClient;
  public
    FindText: string;
    MatchCase: Boolean;
    WholeValue: Boolean;
    RegExpr: Boolean;
    procedure Add(const Table: TCBaseTable; const Field: TCTableField = nil); virtual;
    constructor Create(const AClient: TCClient); reintroduce; virtual;
    destructor Destroy(); override;
    procedure Execute(); override;
  end;

  TTReplace = class(TTFind)
  private
    FReplaceClient: TCClient;
  protected
    procedure ExecuteMatchCase(var Item: TTFind.TItem; const Table: TCBaseTable); override;
    property ReplaceConnection: TCClient read FReplaceClient;
  public
    ReplaceText: string;
    Backup: Boolean;
    constructor Create(const AClient, AReplaceClient: TCClient); reintroduce; virtual;
    property OnError;
  end;

  TTTransfer = class(TTools)
  type
    TItem = record
      Client: TCClient;
      DatabaseName: string;
      TableName: string;
      RecordsSum, RecordsDone: Integer;
      Done: Boolean;
    end;
    TElement = record
      Source: TItem;
      Destination: TItem;
    end;
  private
    DataHandle: TMySQLConnection.TDataResult;
    Elements: TList;
  protected
    procedure AfterExecute(); override;
    procedure BeforeExecute(); override;
    procedure CloneTable(var Source, Destination: TItem); virtual;
    function DifferentPrimaryIndexError(): TTools.TError; virtual;
    function DoExecuteSQL(var Item: TItem; const Client: TCClient; var SQL: string): Boolean; virtual;
    procedure DoUpdateGUI(); override;
    procedure ExecuteData(var Source, Destination: TItem); virtual;
    procedure ExecuteForeignKeys(var Source, Destination: TItem); virtual;
    procedure ExecuteStructure(const Source, Destination: TItem); virtual;
    procedure ExecuteTable(var Source, Destination: TItem); virtual;
    function ToolsItem(const Item: TItem): TTools.TItem; virtual;
  public
    Data: Boolean;
    Structure: Boolean;
    procedure Add(const SourceClient: TCClient; const SourceDatabaseName, SourceTableName: string; const DestinationClient: TCClient; const DestinationDatabaseName, DestinationTableName: string); virtual;
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Execute(); override;
    property OnError;
  end;

  EODBCError = EDatabaseError;

function SQLiteException(const Handle: sqlite3_ptr; const ReturnCode: Integer; const AState: PString = nil): SQLRETURN;
function ODBCException(const Stmt: SQLHSTMT; const ReturnCode: SQLRETURN; const AState: PString = nil): SQLRETURN;

const
  BackupExtension = '_bak';

implementation {***************************************************************}

uses
  ActiveX, SysConst,
  Forms, DBConsts, Registry, DBCommon, StrUtils, Math, Variants,
  PerlRegEx,
  SynCommons,
  fPreferences;

resourcestring
  SSourceParseError = 'Source code of "%s" cannot be analyzed (%d):' + #10#10 + '%s';
  SInvalidQuoter = 'Quoter "%s" not supported for SQL Values import';

const
  SQLPacketSize = 100 * 1024;
  FilePacketSize = 32768;
  ODBCDataSize = 65536;

  daSuccess = daRetry;

  STR_LEN = 128;

function UMLEncoding(const Codepage: Cardinal): string;
var
  Reg: TRegistry;
begin
  Result := '';

  Reg := TRegistry.Create();
  Reg.RootKey := HKEY_CLASSES_ROOT;
  if (Reg.OpenKey('\MIME\Database\Codepage\' + IntToStr(Codepage), False)) then
  begin
    if (Reg.ValueExists('WebCharset')) then
      Result := Reg.ReadString('WebCharset')
    else if (Reg.ValueExists('BodyCharset')) then
      Result := Reg.ReadString('BodyCharset');
    Reg.CloseKey();
  end;
  Reg.Free();
end;

function GetUTCDateTime(Date: TDateTime): string;
const
  EnglishShortMonthNames : array[1..12] of string
    = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  EnglishShortDayNames : array[1..7] of string
    = ('Sun', 'Mon', 'Thu', 'Wed', 'Thu', 'Fri', 'Sat');
const
  TIME_ZONE_ID_UNKNOWN = 0;
  TIME_ZONE_ID_STANDARD = 1;
  TIME_ZONE_ID_DAYLIGHT = 2;
var
  Day: Byte;
  Month: Byte;
  S: string;
  TempShortDayNames: array[1..12] of string;
  TempShortMonthNames: array[1..12] of string;
  TimeZoneInformation: TTimeZoneInformation;
  TZIBias: Integer;
  TZIName: string;
begin
  case GetTimeZoneInformation(TimeZoneInformation) of
    TIME_ZONE_ID_STANDARD:
      begin
        TZIName := TimeZoneInformation.StandardName;
        TZIBias := TimeZoneInformation.Bias + TimeZoneInformation.StandardBias;
      end;
    TIME_ZONE_ID_DAYLIGHT:
      begin
        TZIName := TimeZoneInformation.DaylightName;
        TZIBias := TimeZoneInformation.Bias + TimeZoneInformation.DaylightBias;
      end;
    else
      begin
        TZIName := '';
        TZIBias := TimeZoneInformation.Bias;
      end;
  end;
  S := TimeToStr(EncodeTime(Abs(TZIBias div 60), Abs(TZIBias mod 60), 0, 0), FileFormatSettings);
  S := Copy(S, 1, 2) + Copy(S, 4, 2);
  if TZIBias>0 then S := '-' + S else S := '+' + S;
  for Month := 1 to 12 do TempShortMonthNames[Month] := FormatSettings.ShortMonthNames[Month];
  for Month := 1 to 12 do FormatSettings.ShortMonthNames[Month] := EnglishShortMonthNames[Month];
  for Day := 1 to 7 do TempShortDayNames[Day] := FormatSettings.ShortDayNames[Day];
  for Day := 1 to 7 do FormatSettings.ShortDayNames[Day] := EnglishShortDayNames[Day];
  S := FormatDateTime('ddd, dd mmm yyyy hh:nn:ss "' + S + '"', Now());
  for Day := 1 to 7 do FormatSettings.ShortDayNames[Day] := TempShortDayNames[Day];
  for Month := 1 to 12 do FormatSettings.ShortMonthNames[Month] := TempShortMonthNames[Month];
  if (Pos('(', TZIName)>0) and (Pos(')', TZIName)>0) then
    S := S + ' ' + Copy(TZIName, Pos('(', TZIName), Pos(')', TZIName)-Pos('(', TZIName) + 1);
  Result := S;
end;

function SQLLoadDataInfile(const Database: TCDatabase; const Replace: Boolean; const Filename, FileCharset, DatabaseName, TableName: string; const FieldNames: string): string;
var
  Client: TCClient;
begin
  Client := Database.Client;

  Result := 'LOAD DATA LOCAL INFILE ' + SQLEscape(Filename) + #13#10;
  if (Replace) then
    Result := Result + '  REPLACE' + #13#10;
  Result := Result + '  INTO TABLE ' + Client.EscapeIdentifier(DatabaseName) + '.' + Client.EscapeIdentifier(TableName) + #13#10;
  if (((50038 <= Client.ServerVersion) and (Client.ServerVersion < 50100) or (50117 <= Client.ServerVersion)) and (FileCharset <> '')) then
    Result := Result + '  CHARACTER SET ' + FileCharset + #13#10;
  Result := Result + '  FIELDS' + #13#10;
  Result := Result + '    TERMINATED BY ' + SQLEscape(',') + #13#10;
  Result := Result + '    OPTIONALLY ENCLOSED BY ' + SQLEscape('''') + #13#10;
  Result := Result + '    ESCAPED BY ' + SQLEscape('\') + #13#10;
  Result := Result + '  LINES' + #13#10;
  Result := Result + '    TERMINATED BY ' + SQLEscape(#10) + #13#10;
  if (FieldNames <> '') then
    Result := Result + '  (' + FieldNames + ')' + #13#10;
  Result := SysUtils.Trim(Result) + ';' + #13#10;

  if (((Client.ServerVersion < 50038) or (50100 <= Client.ServerVersion)) and (Client.ServerVersion < 50117) and (FileCharset <> '')) then
    if ((Client.ServerVersion < 40100) or not Assigned(Client.VariableByName('character_set_database'))) then
      Client.Charset := FileCharset
    else if ((Client.VariableByName('character_set_database').Value <> FileCharset) and (Client.LibraryType <> ltHTTP)) then
      Result :=
        'SET SESSION character_set_database=' + SQLEscape(FileCharset) + ';' + #13#10
        + Result
        + 'SET SESSION character_set_database=' + SQLEscape(Client.VariableByName('character_set_database').Value) + ';' + #13#10;
end;

function SQLiteException(const Handle: sqlite3_ptr; const ReturnCode: Integer; const AState: PString = nil): SQLRETURN;
begin
  if ((ReturnCode = SQLITE_MISUSE)) then
    raise Exception.Create('Invalid SQLite Handle')
  else if ((ReturnCode <> SQLITE_OK) and (ReturnCode < SQLITE_ROW)) then
    raise EODBCError.Create(UTF8ToString(sqlite3_errmsg(@Handle)) + ' (' + IntToStr(ReturnCode) + ')');

  Result := ReturnCode;
end;

function ODBCError(const HandleType: SQLSMALLINT; const Handle: SQLHSTMT): TTools.TError;
var
  cbMessageText: SQLSMALLINT;
  MessageText: PSQLTCHAR;
  SQLState: array [0 .. SQL_SQLSTATE_SIZE] of SQLTCHAR;
begin
  Result.ErrorType := TE_ODBC;
  Result.ErrorCode := 0;
  case (SQLGetDiagRec(HandleType, Handle, 1, @SQLState, nil, nil, 0, @cbMessageText)) of
    SQL_SUCCESS,
    SQL_SUCCESS_WITH_INFO:
      begin
        GetMem(MessageText, (cbMessageText + 1) * SizeOf(SQLTCHAR));
        SQLGetDiagRec(HandleType, Handle, 1, nil, nil, MessageText, cbMessageText + 1, nil);
        Result.ErrorMessage := PChar(MessageText) + ' (' + SQLState + ')';
        FreeMem(MessageText);
      end;
    SQL_INVALID_HANDLE:
      Result.ErrorMessage := 'Invalid ODBC Handle.';
    SQL_ERROR,
    SQL_NO_DATA:
      Result.ErrorMessage := 'Unknown ODBC Error.';
  end;
end;

function ODBCException(const Stmt: SQLHSTMT; const ReturnCode: SQLRETURN; const AState: PString = nil): SQLRETURN;
var
  cbMessageText: SQLSMALLINT;
  MessageText: PSQLTCHAR;
  Msg: string;
  SQLState: array [0 .. SQL_SQLSTATE_SIZE] of SQLTCHAR;
begin
  ZeroMemory(@SQLState, SizeOf(SQLState));

  if ((ReturnCode < SQL_SUCCESS) or (ReturnCode = SQL_SUCCESS_WITH_INFO)) then
    if (SQLGetDiagRec(SQL_HANDLE_STMT, Stmt, 1, @SQLState, nil, nil, 0, @cbMessageText) = SQL_INVALID_HANDLE) then
      raise Exception.Create('Invalid ODBC Handle')
    else if ((SQLState <> '') and (SQLState <> '01004')) then
    begin
      GetMem(MessageText, (cbMessageText + 1) * SizeOf(SQLTChar));
      SQLGetDiagRec(SQL_HANDLE_STMT, Stmt, 1, nil, nil, MessageText, cbMessageText + 1, nil);
      Msg := PChar(MessageText) + ' (' + SQLState + ')';
      FreeMem(MessageText);
      raise EODBCError.Create(Msg);
    end;

  if (Assigned(AState)) then
    AState^ := SQLState;

  Result := ReturnCode;
end;

function GetTempFileName(): string;
var
  FilenameP: array [0 .. MAX_PATH] of Char;
begin
  if ((GetTempPath(MAX_PATH, @FilenameP) > 0) and (Windows.GetTempFileName(FilenameP, '~MF', 0, FilenameP) <> 0)) then
    Result := StrPas(PChar(@FilenameP[0]))
  else
    Result := '';
end;

function SysError(): TTools.TError;
begin
  Result.ErrorType := TE_File;
  Result.ErrorCode := GetLastError();
  Result.ErrorMessage := SysErrorMessage(GetLastError());
end;

function ZipError(const Zip: TZipFile; const ErrorMessage: string): TTools.TError;
begin
  Result.ErrorType := TE_File;
  Result.ErrorCode := 0;
  Result.ErrorMessage := ErrorMessage;
end;

{ TTools.TTDataFileBuffer *****************************************************}

procedure TTools.TDataFileBuffer.Clear();
begin
  Buffer.Write := Buffer.Mem;
end;

constructor TTools.TDataFileBuffer.Create(const ACodePage: Cardinal);
var
  CPInfoEx: TCpInfoEx;
begin
  inherited Create();

  CodePage := ACodePage;
  Buffer.Mem := nil;
  Buffer.Size := 0;
  Buffer.Write := nil;
  Temp1.Mem := nil;
  Temp1.Size := 0;
  Temp2.Mem := nil;
  Temp2.Size := 0;

  if (not GetCPInfoEx(CodePage, 0, CPInfoEx)) then
    RaiseLastOSError()
  else
    MaxCharSize := CPInfoEx.MaxCharSize;

  Resize(2 * NET_BUFFER_LENGTH);
end;

destructor TTools.TDataFileBuffer.Destroy();
begin
  if (Assigned(Buffer.Mem)) then FreeMem(Buffer.Mem);
  if (Assigned(Temp1.Mem)) then FreeMem(Temp1.Mem);
  if (Assigned(Temp2.Mem)) then FreeMem(Temp2.Mem);

  inherited;
end;

function TTools.TDataFileBuffer.GetData(): Pointer;
begin
  Result := Pointer(Buffer.Mem);
end;

function TTools.TDataFileBuffer.GetSize(): Integer;
begin
  Result := Integer(Buffer.Write) - Integer(Buffer.Mem);
end;

procedure TTools.TDataFileBuffer.Write(const Data: Pointer; const Size: Integer; const Quote: Boolean = False);
begin
  if (not Quote) then
  begin
    Resize(Size);
    MoveMemory(Buffer.Write, Data, Size); Buffer.Write := @Buffer.Write[Size];
  end
  else
  begin
    Resize(1 + Size + 1);
    Buffer.Write[0] := ''''; Buffer.Write := @Buffer.Write[1];
    MoveMemory(Buffer.Write, Data, Size); Buffer.Write := @Buffer.Write[Size];
    Buffer.Write[0] := ''''; Buffer.Write := @Buffer.Write[1];
  end;
end;

procedure TTools.TDataFileBuffer.WriteData(const Text: PChar; const Length: Integer; const Quote: Boolean = False);
label
  StringL,
  Finish;
var
  Len: Integer;
  Write: PAnsiChar;
begin
  if (not Quote) then
    Len := Length
  else
    Len := 1 + Length + 1;

  Resize(Len);

  Write := Buffer.Write;
  asm
        PUSH ES
        PUSH ESI
        PUSH EDI

        PUSH DS                          // string operations uses ES
        POP ES
        CLD                              // string operations uses forward direction

        MOV ESI,Text                     // Copy characters from Text
        MOV EDI,Write                    //   to Write
        MOV ECX,Length                   // Character count

        CMP Quote,False                  // Quote Value?
        JE StringL                       // No!
        MOV AL,''''                      // Starting quoter
        STOSB                            //   into Write

      StringL:
        LODSW                            // Load WideChar from Text
        STOSB                            // Store AnsiChar into Buffer.Mem
        LOOP StringL                     // Repeat for all characters

        CMP Quote,False                  // Quote Value?
        JE Finish                        // No!
        MOV AL,''''                      // Ending quoter
        STOSB                            //   into Write

      Finish:
        POP EDI
        POP ESI
        POP ES
    end;

  Buffer.Write := @Buffer.Write[Len];
end;

procedure TTools.TDataFileBuffer.WriteText(const Text: PChar; const Length: Integer);
var
  Len: Integer;
  Size: Integer;
begin
  Size := (1 + 2 * Length + 1) * SizeOf(Char);
  if (Size > Temp2.Size) then
  begin
    Temp2.Size := Temp2.Size + 2 * (Size - Temp2.Size);
    ReallocMem(Temp2.Mem, Temp2.Size);
  end;
  Len := SQLEscape(Text, Length, PChar(Temp2.Mem), Size);
  if (Len = 0) then
    raise ERangeError.Create(SRangeError);

  Size := MaxCharSize * Len;
  Resize(Size);
  Len := WideCharToAnsiChar(CodePage, PChar(Temp2.Mem), Len, Buffer.Write, Buffer.Size - Self.Size);
  Buffer.Write := @Buffer.Write[Len];
end;

procedure TTools.TDataFileBuffer.WriteText(const Text: my_char; const Length: Integer; const CodePage: Cardinal);
var
  Len: Integer;
  Size: Integer;
begin
  Size := SizeOf(Char) * Length;
  if (Size = 0) then
  begin
    Resize(2);
    Buffer.Write[0] := ''''; Buffer.Write := @Buffer.Write[1];
    Buffer.Write[0] := ''''; Buffer.Write := @Buffer.Write[1];
  end
  else
  begin
    if (Size > Temp1.Size) then
    begin
      ReallocMem(Temp1.Mem, Size);
      Temp1.Size := Size;
    end;
    Len := AnsiCharToWideChar(CodePage, Text, Length, PChar(Temp1.Mem), Temp1.Size div SizeOf(Char));
    WriteText(PChar(Temp1.Mem), Len);
  end;
end;

procedure TTools.TDataFileBuffer.WriteBinary(const Value: PChar; const Length: Integer);
label
  StringL;
var
  Len: Integer;
  Size: Integer;
  Write: my_char;
begin
  if (Length = 0) then
  begin
    Resize(2);
    Buffer.Write[0] := ''''; Buffer.Write := @Buffer.Write[1];
    Buffer.Write[0] := ''''; Buffer.Write := @Buffer.Write[1];
  end
  else
  begin
    Len := 1 + 2 * Length + 1;
    Size := Len * SizeOf(Char);
    if (Size > Temp1.Size) then
    begin
      Temp1.Size := Size;
      ReallocMem(Temp1.Mem, Temp1.Size);
    end;
    Len := SQLEscape(Value, Length, PChar(Temp1.Mem), Len);
    if (Len = 0) then
      raise ERangeError.Create(SRangeError);

    Resize(Len);

    Write := Buffer.Write;
    asm
        PUSH ES
        PUSH ESI
        PUSH EDI

        PUSH DS                          // string operations uses ES
        POP ES
        CLD                              // string operations uses forward direction

        MOV ESI,Temp1.Mem                // Copy characters from Temp1.Mem
        MOV EDI,Write                    //   to Buffer.Write
        MOV ECX,Len                      // Character count

      StringL:
        LODSW                            // Load WideChar
        STOSB                            // Store AnsiChar
        LOOP StringL                     // Repeat for all characters

        POP EDI
        POP ESI
        POP ES
    end;
    Buffer.Write := @Buffer.Write[Len];
  end;
end;

procedure TTools.TDataFileBuffer.WriteBinary(const Value: my_char; const Length: Integer);
label
  StringL;
var
  Size: Integer;
begin
  if (Length = 0) then
  begin
    Resize(2);
    Buffer.Write[0] := ''''; Buffer.Write := @Buffer.Write[1];
    Buffer.Write[0] := ''''; Buffer.Write := @Buffer.Write[1];
  end
  else
  begin
    Size := Length * SizeOf(Char);
    if (Size > Temp2.Size) then
    begin
      Temp2.Size := Size;
      ReallocMem(Temp2.Mem, Temp2.Size);
    end;

    asm
        PUSH ES
        PUSH ESI
        PUSH EDI

        PUSH DS                          // string operations uses ES
        POP ES
        CLD                              // string operations uses forward direction

        MOV ESI,Value                    // Copy characters from Value
        MOV EDI,Temp2.Mem                //   to Temp2.Mem
        MOV ECX,Length                   // Character count

      StringL:
        LODSB                            // Load WideChar
        STOSW                            // Store AnsiChar
        LOOP StringL                     // Repeat for all characters

        POP EDI
        POP ESI
        POP ES
    end;

    WriteBinary(PChar(Temp2.Mem), Length);
  end;
end;

procedure TTools.TDataFileBuffer.Resize(const NeededSize: Integer);
var
  Len: Integer;
begin
  if (Buffer.Size = 0) then
  begin
    Buffer.Size := NeededSize;
    GetMem(Buffer.Mem, Buffer.Size);
    Buffer.Write := Buffer.Mem;
  end
  else if (Size + NeededSize > Buffer.Size) then
  begin
    Len := Size;
    Buffer.Size := Buffer.Size + 2 * (Len + NeededSize - Buffer.Size);
    ReallocMem(Buffer.Mem, Buffer.Size);
    Buffer.Write := @Buffer.Mem[Len];
  end;
end;

{ TTools.TStringBuffer ********************************************************}

procedure TTools.TStringBuffer.Clear();
begin
  Buffer.Write := Buffer.Mem;
end;

constructor TTools.TStringBuffer.Create(const MemSize: Integer);
begin
  Buffer.Size := 0;
  Buffer.Mem := nil;
  Buffer.Write := nil;

  Resize(MemSize);
end;

destructor TTools.TStringBuffer.Destroy();
begin
  FreeMem(Buffer.Mem);

  inherited;
end;

function TTools.TStringBuffer.GetData(): Pointer;
begin
  Result := Pointer(Buffer.Mem);
end;

function TTools.TStringBuffer.GetSize(): Integer;
begin
  Result := Integer(Buffer.Write) - Integer(Buffer.Mem);
end;

function TTools.TStringBuffer.Read(): string;
begin
  SetString(Result, PChar(Buffer.Mem), Size div SizeOf(Result[1]));
  Clear();
end;

procedure TTools.TStringBuffer.Resize(const NeededLength: Integer);
var
  Index: Integer;
begin
  if (Buffer.Size = 0) then
  begin
    Buffer.Size := NeededLength * SizeOf(Char);
    GetMem(Buffer.Mem, Buffer.Size);
    Buffer.Write := Buffer.Mem;
  end
  else if (Size + NeededLength * SizeOf(Char) > Buffer.Size) then
  begin
    Index := Size * SizeOf(Buffer.Write[0]);
    Inc(Buffer.Size, 2 * (Size + NeededLength * SizeOf(Char) - Buffer.Size));
    ReallocMem(Buffer.Mem, Buffer.Size);
    Buffer.Write := @Buffer.Mem[Index];
  end;
end;

procedure TTools.TStringBuffer.Write(const Text: string);
var
  Size: Integer;
begin
  Size := System.Length(Text) * SizeOf(Text[1]);

  if (Size > 0) then
  begin
    Resize(Size);

    MoveMemory(Buffer.Write, PChar(Text), Size);
    Buffer.Write := @Buffer.Write[System.Length(Text)];
  end;
end;

{ TTools **********************************************************************}

procedure TTools.AfterExecute();
begin
  DoUpdateGUI();

  if (Assigned(OnExecuted)) then
    OnExecuted(Success = daSuccess);
end;

procedure TTools.BackupTable(const Item: TTools.TItem; const Rename: Boolean = False);
var
  Database: TCDatabase;
  NewTableName: string;
  Table: TCBaseTable;
begin
  Database := Item.Client.DatabaseByName(Item.DatabaseName);

  if (Assigned(Database)) then
  begin
    Table := Database.BaseTableByName(Item.TableName);
    if (Assigned(Table)) then
    begin
      NewTableName := Item.TableName + BackupExtension;

      if (Assigned(Database.BaseTableByName(NewTableName))) then
        while ((Success <> daAbort) and not Database.DeleteObject(Database.BaseTableByName(NewTableName))) do
          DoError(DatabaseError(Item.Client), Item, True);

      if (Rename) then
        while (Success <> daAbort) do
        begin
          Database.RenameTable(Table, NewTableName);
          if (Item.Client.ErrorCode <> 0) then
            DoError(DatabaseError(Item.Client), Item, True)
        end
      else
        while ((Success <> daAbort) and not Database.CloneTable(Table, NewTableName, True)) do
          DoError(DatabaseError(Item.Client), Item, True);
    end;
  end;
end;

procedure TTools.BeforeExecute();
begin
  StartTime := Now();
  Success := daSuccess;

  DoUpdateGUI();
end;

constructor TTools.Create();
begin
  inherited Create(True);

  Success := daSuccess;

  FErrorCount := 0;

  FUserAbort := TEvent.Create(nil, True, False, '');
  CriticalSection := TCriticalSection.Create();
end;

function TTools.DatabaseError(const Client: TCClient): TTools.TError;
begin
  Result.ErrorType := TE_Database;
  Result.ErrorCode := Client.ErrorCode;
  Result.ErrorMessage := Client.ErrorMessage;
end;

destructor TTools.Destroy();
begin
  CriticalSection.Free();
  FUserAbort.Free();

  inherited;
end;

procedure TTools.DoError(const Error: TTools.TError; const Item: TTools.TItem; const ShowRetry: Boolean);
var
  ErrorTime: TDateTime;
begin
  Inc(FErrorCount);
  if (Success <> daAbort) then
    if (not Assigned(OnError)) then
      Success := daAbort
    else
    begin
      ErrorTime := Now();
      OnError(Self, Error, Item, ShowRetry, Success);
      StartTime := StartTime + ErrorTime - Now();
    end;
end;

procedure TTools.DoError(const Error: TTools.TError; const Item: TTools.TItem; const ShowRetry: Boolean; var SQL: string);
begin
  DoError(Error, Item, ShowRetry);
  if (Success = daFail) then
  begin
    Delete(SQL, 1, SQLStmtLength(SQL));
    Success := daSuccess;
  end;
end;

function TTools.EmptyToolsItem(): TTools.TItem;
begin
  Result.Client := nil;
  Result.DatabaseName := '';
  Result.TableName := '';
end;

function TTools.NoPrimaryIndexError(): TTools.TError;
begin
  Result.ErrorType := TE_NoPrimaryIndex;
end;

{ TTImport ********************************************************************}

procedure TTImport.AfterExecute();
begin
  Close();

  Client.EndSilent();
  Client.EndSynchron();

  inherited;
end;

procedure TTImport.AfterExecuteData(var Item: TItem);
begin
end;

procedure TTImport.BeforeExecute();
begin
  inherited;

  Client.BeginSilent();
  Client.BeginSynchron(); // We're still in a thread
end;

procedure TTImport.BeforeExecuteData(var Item: TItem);
var
  I: Integer;
begin
  EscapedFieldNames := '';
  if (not Structure and (Length(Fields) > 0)) then
    for I := 0 to Length(Fields) - 1 do
    begin
      if (I > 0) then EscapedFieldNames := EscapedFieldNames + ',';
      EscapedFieldNames := EscapedFieldNames + Client.EscapeIdentifier(Fields[I].Name);
    end;
end;

procedure TTImport.Close();
begin
end;

constructor TTImport.Create(const AClient: TCClient; const ADatabase: TCDatabase);
begin
  inherited Create();

  FClient := AClient;
  FDatabase := ADatabase;

  Data := False;
  Structure := False;
end;

function TTImport.DoExecuteSQL(const Item: TItem; var SQL: string): Boolean;
begin
  Result := Client.ExecuteSQL(SQL);
  if (not Result) then
  begin
    Delete(SQL, 1, Client.ExecutedSQLLength);
    SQL := SysUtils.Trim(SQL);
    DoError(DatabaseError(Client), ToolsItem(Item), True, SQL);
  end
  else
    SQL := '';
end;

procedure TTImport.DoUpdateGUI();
var
  I: Integer;
begin
  CriticalSection.Enter();

  ProgressInfos.TablesDone := 0;
  ProgressInfos.TablesSum := Length(Items);
  ProgressInfos.RecordsDone := 0;
  ProgressInfos.RecordsSum := 0;
  ProgressInfos.TimeDone := 0;
  ProgressInfos.TimeSum := 0;

  for I := 0 to Length(Items) - 1 do
  begin
    if (Items[I].Done) then
      Inc(ProgressInfos.TablesDone);

    Inc(ProgressInfos.RecordsDone, Items[I].RecordsDone);
    Inc(ProgressInfos.RecordsSum, Items[I].RecordsSum);
  end;

  ProgressInfos.TimeDone := Now() - StartTime;

  if ((ProgressInfos.RecordsDone = 0) and (ProgressInfos.TablesDone = 0)) then
  begin
    ProgressInfos.Progress := 0;
    ProgressInfos.TimeSum := 0;
  end
  else if (ProgressInfos.RecordsDone = 0) then
  begin
    ProgressInfos.Progress := Round(ProgressInfos.TablesDone / ProgressInfos.TablesSum * 100);
    ProgressInfos.TimeSum := ProgressInfos.TimeDone / ProgressInfos.TablesDone * ProgressInfos.TablesSum;
  end
  else if (ProgressInfos.RecordsDone < ProgressInfos.RecordsSum) then
  begin
    ProgressInfos.Progress := Round(ProgressInfos.RecordsDone / ProgressInfos.RecordsSum * 100);
    ProgressInfos.TimeSum := ProgressInfos.TimeDone / ProgressInfos.RecordsDone * ProgressInfos.RecordsSum;
  end
  else
  begin
    ProgressInfos.Progress := 100;
    ProgressInfos.TimeSum := ProgressInfos.TimeDone;
  end;

  CriticalSection.Leave();

  if (Assigned(FOnUpdate)) then
    FOnUpdate(ProgressInfos);
end;

procedure TTImport.Execute();
var
  DataSet: TMySQLQuery;
  I: Integer;
  OLD_FOREIGN_KEY_CHECKS: string;
  OLD_UNIQUE_CHECKS: string;
  SQL: string;
begin
  BeforeExecute();

  Open();

  if (Data and (Client.ServerVersion >= 40014)) then
  begin
    if (Assigned(Client.VariableByName('UNIQUE_CHECKS'))
      and Assigned(Client.VariableByName('FOREIGN_KEY_CHECKS'))) then
    begin
      OLD_UNIQUE_CHECKS := Client.VariableByName('UNIQUE_CHECKS').Value;
      OLD_FOREIGN_KEY_CHECKS := Client.VariableByName('FOREIGN_KEY_CHECKS').Value;
    end
    else
    begin
      DataSet := TMySQLQuery.Create(nil);
      DataSet.Connection := Client;
      DataSet.CommandText := 'SELECT @@UNIQUE_CHECKS,@@FOREIGN_KEY_CHECKS';

      while ((Success <> daAbort) and not DataSet.Active) do
      begin
        DataSet.Open();
        if (Client.ErrorCode > 0) then
          DoError(DatabaseError(Client), ToolsItem(Items[0]), True, SQL);
      end;

      if (DataSet.Active) then
      begin
        OLD_UNIQUE_CHECKS := DataSet.Fields[0].AsString;
        OLD_FOREIGN_KEY_CHECKS := DataSet.Fields[1].AsString;
        DataSet.Close();
      end;

      DataSet.Free();
    end;

    SQL := 'SET UNIQUE_CHECKS=0,FOREIGN_KEY_CHECKS=0;';
    while ((Success <> daAbort) and not Client.ExecuteSQL(SQL)) do
      DoError(DatabaseError(Client), ToolsItem(Items[0]), True, SQL);
  end;

  for I := 0 to Length(Items) - 1 do
    if (Success <> daAbort) then
    begin
      Success := daSuccess;

      if (Structure) then
      begin
        if (Assigned(Database.TableByName(Items[I].TableName))) then
          while ((Success <> daAbort) and not Database.DeleteObject(Database.TableByName(Items[I].TableName))) do
            DoError(DatabaseError(Client), ToolsItem(Items[I]), True);
        if (Success = daSuccess) then
          ExecuteStructure(Items[I]);
      end;

      if ((Success = daSuccess) and Data) then
      begin
        if (not Assigned(Database.TableByName(Items[I].TableName))) then
          raise Exception.Create('Table "' + Items[I].TableName + '" does not exists.');
        ExecuteData(Items[I], Database.TableByName(Items[I].TableName));
      end;

      Items[I].Done := True;
    end;

  if (Data and (Client.ServerVersion >= 40014)) then
  begin
    SQL := 'SET UNIQUE_CHECKS=' + OLD_UNIQUE_CHECKS + ',FOREIGN_KEY_CHECKS=' + OLD_FOREIGN_KEY_CHECKS + ';' + #13#10;
    while (not Client.ExecuteSQL(SQL) and (Success = daSuccess)) do
      DoError(DatabaseError(Client), ToolsItem(Items[0]), True, SQL);
  end;

  AfterExecute();
end;

procedure TTImport.ExecuteData(var Item: TItem; const Table: TCTable);
var
  BytesWritten: DWord;
  DataSet: TMySQLQuery;
  DataFileBuffer: TDataFileBuffer;
  DBValues: RawByteString;
  Error: TTools.TError;
  EscapedFieldName: array of string;
  EscapedTableName: string;
  I: Integer;
  InsertStmtInSQL: Boolean;
  Pipe: THandle;
  Pipename: string;
  SQL: string;
  SQLExecuted: TEvent;
  SQLExecuteLength: Integer;
  SQLValues: TSQLStrings;
  Values: string;
  WhereClausel: string;
begin
  BeforeExecuteData(Item);

  EscapedTableName := Client.EscapeIdentifier(Table.Name);

  if (Success = daSuccess) then
  begin
    SQLExecuted := TEvent.Create(nil, False, False, '');

    SQL := '';
    if (Client.DatabaseName <> Database.Name) then
      SQL := SQL + Database.SQLUse() + #13#10;
    if (Structure) then
    begin
      SQL := SQL + 'LOCK TABLES ' + EscapedTableName + ' WRITE;' + #13#10;
      if ((Client.ServerVersion >= 40000) and (Table is TCBaseTable) and TCBaseTable(Table).Engine.IsMyISAM) then
        SQL := SQL + 'ALTER TABLE ' + EscapedTableName + ' DISABLE KEYS;' + #13#10;
    end;
    if (Client.Lib.LibraryType <> ltHTTP) then
      if (Client.ServerVersion < 40011) then
        SQL := SQL + 'BEGIN;' + #13#10
      else
        SQL := SQL + 'START TRANSACTION;' + #13#10;

    if ((ImportType <> itUpdate) and Client.DataFileAllowed) then
    begin
      Pipename := '\\.\pipe\' + LoadStr(1000);
      Pipe := CreateNamedPipe(PChar(Pipename),
                              PIPE_ACCESS_OUTBOUND, PIPE_TYPE_MESSAGE or PIPE_READMODE_BYTE or PIPE_WAIT,
                              1, 2 * NET_BUFFER_LENGTH, 0, 0, nil);
      if (Pipe = INVALID_HANDLE_VALUE) then
        DoError(SysError(), ToolsItem(Item), False)
      else
      begin
        SQL := SQL + SQLLoadDataInfile(Database, ImportType = itReplace, Pipename, Client.Charset, Database.Name, Table.Name, EscapedFieldNames);

        Client.SendSQL(SQL, SQLExecuted);

        if (ConnectNamedPipe(Pipe, nil)) then
        begin
          DataFileBuffer := TDataFileBuffer.Create(Client.CodePage);

          Item.RecordsDone := 0;
          while ((Success = daSuccess) and GetValues(Item, DataFileBuffer)) do
          begin
            DataFileBuffer.Write(PAnsiChar(#10 + '_'), 1); // Two characters are needed to instruct the compiler to give a pointer - but the first character should be placed in the file only

            if (DataFileBuffer.Size > NET_BUFFER_LENGTH) then
              if (not WriteFile(Pipe, DataFileBuffer.Data^, DataFileBuffer.Size, BytesWritten, nil)) then
                DoError(SysError(), ToolsItem(Item), False)
              else
                DataFileBuffer.Clear();

            Inc(Item.RecordsDone);
            if (Item.RecordsDone mod 100 = 0) then DoUpdateGUI();

            if (UserAbort.WaitFor(IGNORE) = wrSignaled) then
              Success := daAbort;
          end;

          if (DataFileBuffer.Size > 0) then
            if (not WriteFile(Pipe, DataFileBuffer.Data^, DataFileBuffer.Size, BytesWritten, nil)) then
              DoError(SysError(), ToolsItem(Item), False)
            else
              DataFileBuffer.Clear();

          if (FlushFileBuffers(Pipe) and WriteFile(Pipe, PAnsiChar(DBValues)^, 0, BytesWritten, nil) and FlushFileBuffers(Pipe)) then
            SQLExecuted.WaitFor(INFINITE);
          DisconnectNamedPipe(Pipe);

          if ((Success = daSuccess) and (ImportType = itInsert) and (Client.WarningCount > 0)) then
          begin
            DataSet := TMySQLQuery.Create(nil);
            DataSet.Connection := Client;
            DataSet.CommandText := 'SHOW WARNINGS';

            DataSet.Open();
            if (DataSet.Active and not DataSet.IsEmpty()) then
            begin
              Error.ErrorType := TE_Warning;
              Error.ErrorCode := 1;
              repeat
                Error.ErrorMessage := Error.ErrorMessage + SysUtils.Trim(DataSet.FieldByName('Message').AsString) + #13#10;
              until (not DataSet.FindNext());
              DoError(Error, ToolsItem(Item), False);
            end;
            DataSet.Free();
          end;

          if (Client.ErrorCode <> 0) then
            DoError(DatabaseError(Client), ToolsItem(Item), False, SQL);

          SQL := '';
          if (Structure) then
          begin
            if ((Client.ServerVersion >= 40000) and (Table is TCBaseTable) and TCBaseTable(Table).Engine.IsMyISAM) then
              SQL := SQL + 'ALTER TABLE ' + EscapedTableName + ' ENABLE KEYS;' + #13#10;
            SQL := SQL + 'UNLOCK TABLES;' + #13#10;
          end;
          if (Client.Lib.LibraryType <> ltHTTP) then
            if (Client.ErrorCode <> 0) then
              SQL := SQL + 'ROLLBACK;' + #13#10
            else
              SQL := SQL + 'COMMIT;' + #13#10;
          Client.ExecuteSQL(SQL);

          DataFileBuffer.Free();
        end;

        CloseHandle(Pipe);
      end;
    end
    else
    begin
      SQLExecuteLength := 0; InsertStmtInSQL := False;

      SetLength(EscapedFieldName, Length(Fields));
      for I := 0 to Length(Fields) - 1 do
        EscapedFieldName[I] := Client.EscapeIdentifier(Fields[I].Name);

      SetLength(SQLValues, Length(Fields));
      while ((Success = daSuccess) and GetValues(Item, SQLValues)) do
      begin
        Values := ''; WhereClausel := '';
        for I := 0 to Length(Fields) - 1 do
          if (ImportType <> itUpdate) then
          begin
            if (Values <> '') then Values := Values + ',';
            Values := Values + SQLValues[I];
          end
          else if (not Fields[I].InPrimaryKey) then
          begin
            if (Values <> '') then Values := Values + ',';
            Values := Values + EscapedFieldName[I] + '=' + SQLValues[I];
          end
          else
          begin
            if (WhereClausel <> '') then WhereClausel := WhereClausel + ' AND ';
            WhereClausel := WhereClausel + EscapedFieldName[I] + '=' + SQLValues[I];
          end;

        if (ImportType = itUpdate) then
        begin
          if (not InsertStmtInSQL) then
            SQL := SQL + ';' + #13#10;
          SQL := SQL + 'UPDATE ' + EscapedTableName + ' SET ' + Values + ' WHERE ' + WhereClausel + ';' + #13#10;
          InsertStmtInSQL := False;
        end
        else if (not InsertStmtInSQL) then
        begin
          if (ImportType = itReplace) then
            SQL := SQL + 'REPLACE INTO ' + EscapedTableName
          else
            SQL := SQL + 'INSERT INTO ' + EscapedTableName;
          if (EscapedFieldNames <> '') then
            SQL := SQL + ' (' + EscapedFieldNames + ')';
          SQL := SQL + ' VALUES (' + Values + ')';
          InsertStmtInSQL := True;
        end
        else
          SQL := SQL + ',(' + Values + ')';

        if ((ImportType = itUpdate) and not Client.MultiStatements or (Length(SQL) - SQLExecuteLength >= SQLPacketSize)) then
        begin
          if (InsertStmtInSQL) then
          begin
            SQL := SQL + ';' + #13#10;
            InsertStmtInSQL := False;
          end;

          if (SQLExecuteLength > 0) then
          begin
            SQLExecuted.WaitFor(INFINITE);
            Delete(SQL, 1, Client.ExecutedSQLLength);
            SQLExecuteLength := 0;
            if (Client.ErrorCode <> 0) then
              DoError(DatabaseError(Client), ToolsItem(Item), False, SQL);
          end;

          if (SQL <> '') then
          begin
            Client.SendSQL(SQL, SQLExecuted);
            SQLExecuteLength := Length(SQL);
          end;
        end;

        Inc(Item.RecordsDone);
        if (Item.RecordsDone mod 100 = 0) then DoUpdateGUI();

        if (UserAbort.WaitFor(IGNORE) = wrSignaled) then
        begin
          if (SQL <> '') then
            Client.Terminate();
          Success := daAbort;
        end;
      end;
      SetLength(SQLValues, 0);

      if ((Success = daSuccess) and (SQLExecuteLength > 0)) then
      begin
        SQLExecuted.WaitFor(INFINITE);
        Delete(SQL, 1, Client.ExecutedSQLLength);
        if (Client.ErrorCode <> 0) then
          DoError(DatabaseError(Client), ToolsItem(Item), False, SQL);
      end;

      if (InsertStmtInSQL) then
        SQL := SQL + ';' + #13#10;
      if (Structure) then
      begin
        if ((Client.ServerVersion >= 40000) and (Table is TCBaseTable) and TCBaseTable(Table).Engine.IsMyISAM) then
          SQL := SQL + 'ALTER TABLE ' + EscapedTableName + ' ENABLE KEYS;' + #13#10;
        SQL := SQL + 'UNLOCK TABLES;' + #13#10;
      end;
      if (Client.Lib.LibraryType <> ltHTTP) then
        SQL := SQL + 'COMMIT;' + #13#10;

      while ((Success <> daAbort) and not DoExecuteSQL(Item, SQL)) do
        DoError(DatabaseError(Client), ToolsItem(Item), True, SQL);
    end;

    SQLExecuted.Free();
  end;

  AfterExecuteData(Item);
end;

procedure TTImport.ExecuteStructure(var Item: TItem);
begin
end;

function TTImport.GetValues(const Item: TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean;
begin
  Result := False;
end;

function TTImport.GetValues(const Item: TItem; var Values: TSQLStrings): Boolean;
begin
  Result := False;
end;

procedure TTImport.Open();
begin
end;

function TTImport.ToolsItem(const Item: TItem): TTools.TItem;
begin
  Result.Client := FClient;
  if (not Assigned(FDatabase)) then
    Result.DatabaseName := ''
  else
    Result.DatabaseName := FDatabase.Name;
  Result.TableName := Item.TableName;
end;

{ TTImportFile ****************************************************************}

procedure TTImportFile.Close();
begin
  if (Handle <> INVALID_HANDLE_VALUE) then
  begin
    CloseHandle(Handle);
    Handle := INVALID_HANDLE_VALUE;
  end;

  if (Assigned(FileBuffer.Mem)) then
    VirtualFree(FileBuffer.Mem, FileBuffer.Size, MEM_RELEASE);
  FileBuffer.Index := 0;
  FileBuffer.Size := 0;

  FileContent.Str := '';
  FileContent.Index := 1;
end;

constructor TTImportFile.Create(const AFilename: TFileName; const ACodePage: Cardinal; const AClient: TCClient; const ADatabase: TCDatabase);
begin
  inherited Create(AClient, ADatabase);

  FFilename := AFilename;
  FCodePage := ACodePage;

  FilePos := 0;
  FileBuffer.Mem := nil;
  FileBuffer.Index := 0;
  FileBuffer.Size := 0;
  FileContent.Str := '';
  FileContent.Index := 1;
  FFileSize := 0;

  Handle := INVALID_HANDLE_VALUE;
end;

procedure TTImportFile.DoUpdateGUI();
begin
  CriticalSection.Enter();

  ProgressInfos.TablesDone := -1;
  ProgressInfos.TablesSum := -1;
  ProgressInfos.RecordsDone := FilePos;
  ProgressInfos.RecordsSum := FileSize;
  ProgressInfos.TimeDone := 0;
  ProgressInfos.TimeSum := 0;

  ProgressInfos.TimeDone := Now() - StartTime;

  if ((ProgressInfos.RecordsDone = 0) or (ProgressInfos.RecordsSum = 0)) then
  begin
    ProgressInfos.Progress := 0;
    ProgressInfos.TimeSum := 0;
  end
  else if (ProgressInfos.RecordsDone < ProgressInfos.RecordsSum) then
  begin
    ProgressInfos.Progress := Round(ProgressInfos.RecordsDone / ProgressInfos.RecordsSum * 100);
    ProgressInfos.TimeSum := ProgressInfos.TimeDone / ProgressInfos.RecordsDone * ProgressInfos.RecordsSum;
  end
  else
  begin
    ProgressInfos.Progress := 100;
    ProgressInfos.TimeSum := ProgressInfos.TimeDone;
  end;

  CriticalSection.Leave();

  if (Assigned(OnUpdate)) then
    OnUpdate(ProgressInfos);
end;

function TTImportFile.DoOpenFile(const Filename: TFileName; out Handle: THandle; out Error: TTools.TError): Boolean;
var
  NumberofFreeClusters: DWord;
  SectorsPerCluser: DWord;
  TotalNumberOfClusters: DWord;
begin
  Result := True;

  try
    Handle := CreateFile(PChar(Filename),
                         GENERIC_READ,
                         FILE_SHARE_READ,
                         nil,
                         OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, 0);

    if (Handle = INVALID_HANDLE_VALUE) then
      DoError(SysError(), EmptyToolsItem(), False)
    else
    begin
      FFileSize := GetFileSize(Handle, nil);
      if (FFileSize = 0) then
        FileBuffer.Mem := nil
      else
      begin
        if (not GetDiskFreeSpace(PChar(ExtractFileDrive(Filename)), SectorsPerCluser, BytesPerSector, NumberofFreeClusters, TotalNumberOfClusters)) then
          RaiseLastOSError();
        FileBuffer.Size := BytesPerSector + Min(FFileSize, FilePacketSize);
        Inc(FileBuffer.Size, BytesPerSector - FileBuffer.Size mod BytesPerSector);
        FileBuffer.Mem := VirtualAlloc(nil, FileBuffer.Size, MEM_COMMIT, PAGE_READWRITE);
        FileBuffer.Index := BytesPerSector;

        ReadContent();
      end;
    end;
  except
    Error := SysError();

    Result := False;
  end;
end;

function TTImportFile.ReadContent(const NewFilePos: TLargeInteger = -1): Boolean;
var
  DistanceToMove: TLargeInteger;
  Index: Integer;
  Len: Integer;
  ReadSize: DWord;
  UTF8Bytes: Byte;
begin
  // The file will be read without buffering in Windows OS. Because of this,
  // we have to read complete sectors...

  if ((Success = daSuccess) and (NewFilePos >= 0)) then
  begin
    FileContent.Str := '';

    DistanceToMove := NewFilePos - NewFilePos mod BytesPerSector;
    if ((SetFilePointer(Handle, LARGE_INTEGER(DistanceToMove).LowPart, @LARGE_INTEGER(DistanceToMove).HighPart, FILE_BEGIN) = INVALID_FILE_SIZE) and (GetLastError() <> 0)) then
      DoError(SysError(), EmptyToolsItem(), False);
    FileBuffer.Index := BytesPerSector + NewFilePos mod BytesPerSector;

    FilePos := NewFilePos;
  end
  else
  begin
    FileBuffer.Index := BytesPerSector;
    if (FileContent.Index > 1) then
      Delete(FileContent.Str, 1, FileContent.Index - 1);
  end;
  FileContent.Index := 1;

  if ((Success = daSuccess) and ReadFile(Handle, FileBuffer.Mem[BytesPerSector], FileBuffer.Size - BytesPerSector, ReadSize, nil) and (ReadSize > 0)) then
  begin
    if (FilePos = 0) then
    begin
      if (CompareMem(@FileBuffer.Mem[FileBuffer.Index + 0], BOM_UTF8, Length(BOM_UTF8))) then
      begin
        BOMLength := Length(BOM_UTF8);
        FCodePage := CP_UTF8;
      end
      else if (CompareMem(@FileBuffer.Mem[FileBuffer.Index + 0], BOM_UNICODE, Length(BOM_UNICODE))) then
      begin
        BOMLength := Length(BOM_UNICODE);
        FCodePage := CP_UNICODE;
      end
      else
        BOMLength := 0;

      FilePos := BOMLength;
      Inc(FileBuffer.Index, FilePos);
    end;
    Inc(FilePos, ReadSize - (FileBuffer.Index - BytesPerSector));

    case (CodePage) of
      CP_UNICODE:
        begin
          Index := 1 + Length(FileContent.Str);
          Len := Integer(ReadSize - (FileBuffer.Index - BytesPerSector));
          SetLength(FileContent.Str, Length(FileContent.Str) + Len div SizeOf(Char));
          MoveMemory(@FileContent.Str[Index], @FileBuffer.Mem[FileBuffer.Index], Len);
        end;
      else
        begin
          // UTF-8 coded bytes has to be separated well for the
          // MultiByteToWideChar function.

          UTF8Bytes := 0;
          if (CodePage = CP_UTF8) then
            while ((ReadSize > 0) and (Byte(FileBuffer.Mem[BytesPerSector + ReadSize - UTF8Bytes]) and $C0 = $80)) do
              Inc(UTF8Bytes);

          if (BytesPerSector + ReadSize - FileBuffer.Index > 0) then
          begin
            Len := AnsiCharToWideChar(CodePage, @FileBuffer.Mem[FileBuffer.Index], BytesPerSector + ReadSize - FileBuffer.Index, nil, 0);
            if (Len > 0) then
            begin
              SetLength(FileContent.Str, Length(FileContent.Str) + Len);
              AnsiCharToWideChar(CodePage, @FileBuffer.Mem[FileBuffer.Index], BytesPerSector + ReadSize - FileBuffer.Index, @FileContent.Str[Length(FileContent.Str) - Len + 1], Len)
            end;
          end;

          if (UTF8Bytes > 0) then
            MoveMemory(@FileBuffer.Mem[BytesPerSector - UTF8Bytes], @FileBuffer.Mem[BytesPerSector + ReadSize - UTF8Bytes], UTF8Bytes);
          FileBuffer.Index := BytesPerSector - UTF8Bytes;
        end;
    end;
  end;

  Result := (Success = daSuccess) and (ReadSize > 0);
end;

procedure TTImportFile.Open();
var
  Error: TTools.TError;
begin
  FilePos := 0;

  while ((Success <> daAbort) and not DoOpenFile(FFilename, Handle, Error)) do
    DoError(Error, EmptyToolsItem(), True);
end;

{ TTImportSQL *************************************************************}

constructor TTImportSQL.Create(const AFilename: TFileName; const ACodePage: Cardinal; const AClient: TCClient; const ADatabase: TCDatabase);
begin
  inherited;

  SetLength(Items, 1);
  Items[0].TableName := '';
  Items[0].RecordsDone := 0;
  Items[0].RecordsSum := 0;
  Items[0].Done := False;

  FSetCharacterSetApplied := False;
  Text := nil
end;

procedure TTImportSQL.Execute();
var
  CLStmt: TSQLCLStmt;
  CompleteStmt: Boolean;
  Eof: Boolean;
  Index: Integer;
  Len: Integer;
  SetCharacterSet: Boolean;
  SQL: string;
  SQLFilePos: TLargeInteger;
begin
  if (not Assigned(Text)) then
    BeforeExecute();

  Open();

  if (Assigned(Text)) then
    Text^ := ''
  else if ((Success = daSuccess) and Assigned(Database) and (Client.DatabaseName <> Database.Name)) then
  begin
    SQL := Database.SQLUse();
    while ((Success <> daAbort) and not DoExecuteSQL(Items[0], SQL)) do
      DoError(DatabaseError(Client), ToolsItem(Items[0]), True, SQL);
  end;

  Index := 1; Eof := False; SQLFilePos := BOMLength;
  while ((Success = daSuccess) and (not Eof or (Index <= Length(FileContent.Str)))) do
  begin
    repeat
      Len := SQLStmtLength(FileContent.Str, Index, @CompleteStmt);
      if (not CompleteStmt) then
      begin
        Eof := not ReadContent();
        if (not Eof) then
          Len := 0
        else
          Len := Length(FileContent.Str) - Index + 1;
      end;
    until ((Len > 0) or Eof);

    if (Len > 0) then
      case (CodePage) of
        CP_UNICODE: Inc(SQLFilePos, Len * SizeOf(Char));
        else Inc(SQLFilePos, WideCharToAnsiChar(CodePage, PChar(@FileContent.Str[Index]), Len, nil, 0));
      end;

    SetCharacterSet := not EOF
      and SQLParseCLStmt(CLStmt, @FileContent.Str[Index], Length(FileContent.Str), Client.ServerVersion)
      and (CLStmt.CommandType in [ctSetNames, ctSetCharacterSet]);

    if ((Index > 1) and (SetCharacterSet or (Index - 1 + Len >= SQLPacketSize))) then
    begin
      if (Assigned(Text)) then
        Text^ := Text^ + Copy(FileContent.Str, 1, Index - 1)
      else
      begin
        SQL := Copy(FileContent.Str, 1, Index - 1);
        while ((Success <> daAbort) and not DoExecuteSQL(Items[0], SQL)) do
          DoError(DatabaseError(Client), ToolsItem(Items[0]), True, SQL);
      end;
      Delete(FileContent.Str, 1, Index - 1); Index := 1;

      DoUpdateGUI();
    end;

    if (Success = daSuccess) then
    begin
      if (SetCharacterSet) then
      begin
        FSetCharacterSetApplied := True;

        FCodePage := Client.CharsetToCodePage(CLStmt.ObjectName);

        ReadContent(SQLFilePos); // Clear FileContent
      end
      else
        Inc(Index, Len);
    end;

    if (UserAbort.WaitFor(IGNORE) = wrSignaled) then
      Success := daAbort;
  end;

  if (Success = daSuccess) then
    if (Assigned(Text)) then
      Text^ := Text^ + FileContent.Str
    else
    begin
      SQL := FileContent.Str;
      while ((Success <> daAbort) and not DoExecuteSQL(Items[0], SQL)) do
        DoError(DatabaseError(Client), ToolsItem(Items[0]), True, SQL);
    end;

  Close();

  if (not Assigned(Text)) then
    AfterExecute();
end;

{ TTImportText ****************************************************************}

procedure TTImportText.Add(const TableName: string);
begin
  SetLength(Items, Length(Items) + 1);
  Items[Length(Items) - 1].TableName := TableName;
  Items[Length(Items) - 1].RecordsDone := 0;
  Items[Length(Items) - 1].RecordsSum := 0;
  Items[Length(Items) - 1].Done := False;
end;

procedure TTImportText.AfterExecuteData(var Item: TTImport.TItem);
begin
  SetLength(CSVValues, 0);

  inherited;
end;

procedure TTImportText.BeforeExecuteData(var Item: TTImport.TItem);
var
  I: Integer;
  J: Integer;
begin
  inherited;

  SetLength(CSVColumns, Length(SourceFields));
  for I := 0 to Length(SourceFields) - 1 do
  begin
    CSVColumns[I] := -1;
    for J := 0 to HeadlineNameCount - 1 do
      if (SourceFields[I].Name = HeadlineNames[J]) then
        CSVColumns[I] := J;
  end;
end;

procedure TTImportText.Close();
begin
  inherited;

  SetLength(FileFields, 0);
end;

constructor TTImportText.Create(const AFilename: TFileName; const ACodePage: Cardinal; const AClient: TCClient; const ADatabase: TCDatabase);
begin
  inherited Create(AFilename, ACodePage, AClient, ADatabase);

  SetLength(CSVValues, 0);
  Data := True;
  Delimiter := ',';
  Quoter := '"';
  CSVUnquoteMemSize := NET_BUFFER_LENGTH;
  GetMem(CSVUnquoteMem, CSVUnquoteMemSize);
end;

destructor TTImportText.Destroy();
begin
  SetLength(Fields, 0);
  FreeMem(CSVUnquoteMem);

  inherited;
end;

procedure TTImportText.ExecuteStructure(var Item: TTImport.TItem);
var
  I: Integer;
  NewField: TCBaseTableField;
  NewTable: TCBaseTable;
begin
  NewTable := TCBaseTable.Create(Database.Tables);

  for I := 0 to Length(FileFields) - 1 do
  begin
    NewField := TCBaseTableField.Create(NewTable.Fields);

    NewField.Name := Client.ApplyIdentifierName(HeadlineNames[I]);

    if (SQL_INTEGER in FileFields[I].FieldTypes) then
      NewField.FieldType := mfInt
    else if (SQL_FLOAT in FileFields[I].FieldTypes) then
      NewField.FieldType := mfFloat
    else if (SQL_DATE in FileFields[I].FieldTypes) then
      NewField.FieldType := mfDate
    else
      NewField.FieldType := mfText;

    if (I > 0) then
      NewField.FieldBefore := NewTable.Fields[NewTable.Fields.Count - 1];

    NewTable.Fields.AddField(NewField);
    NewField.Free();
  end;

  NewTable.Name := Client.ApplyIdentifierName(Item.TableName);

  while ((Success <> daAbort) and not Database.AddTable(NewTable)) do
    DoError(DatabaseError(Client), ToolsItem(Item), True);

  NewTable.Free();

  if (Success = daSuccess) then
  begin
    NewTable := Database.BaseTableByName(Item.TableName);
    while ((Success <> daAbort) and not NewTable.Update()) do
      DoError(DatabaseError(Client), ToolsItem(Item), True);

    SetLength(Fields, NewTable.Fields.Count);
    for I := 0 to NewTable.Fields.Count - 1 do
      Fields[I] := NewTable.Fields[I];

    SetLength(SourceFields, NewTable.Fields.Count);
    for I := 0 to HeadlineNameCount - 1 do
      SourceFields[I].Name := HeadlineNames[I];
  end;
end;

function TTImportText.GetHeadlineNameCount(): Integer;
begin
  Result := Length(FileFields);
end;

function TTImportText.GetHeadlineName(Index: Integer): string;
begin
  Result := FileFields[Index].Name;
end;

function TTImportText.GetPreviewValues(var Values: TSQLStrings): Boolean;
var
  Eof: Boolean;
  I: Integer;
  RecordComplete: Boolean;
begin
  RecordComplete := False; Eof := False;
  while ((Success = daSuccess) and not RecordComplete and not Eof) do
  begin
    RecordComplete := CSVSplitValues(FileContent.Str, FileContent.Index, Delimiter, Quoter, CSVValues);
    if (not RecordComplete) then
      Eof := not ReadContent();
  end;

  Result := (Success = daSuccess) and RecordComplete;
  if (Result) then
  begin
    SetLength(Values, Length(CSVValues));
    for I := 0 to Length(CSVValues) - 1 do
      if (CSVValues[I].Length = 0) then
        if (not Preferences.GridNullText) then
          Values[I] := ''
        else
          Values[I] := '<NULL>'
      else
        Values[I] := CSVUnescape(CSVValues[I].Text, CSVValues[I].Length, Quoter);
  end;
end;

function TTImportText.GetValues(const Item: TTImport.TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean;
var
  EOF: Boolean;
  I: Integer;
  Len: Integer;
  OldFileContentIndex: Integer;
  RecordComplete: Boolean;
begin
  RecordComplete := False; EOF := False; OldFileContentIndex := FileContent.Index;
  while ((Success = daSuccess) and not RecordComplete and not EOF) do
  begin
    RecordComplete := CSVSplitValues(FileContent.Str, FileContent.Index, Delimiter, Quoter, CSVValues);
    if (not RecordComplete) then
    begin
      FileContent.Index := OldFileContentIndex;
      EOF := not ReadContent();
    end;
  end;

  Result := RecordComplete;
  if (Result) then
    for I := 0 to Length(Fields) - 1 do
    begin
      if (I > 0) then
        DataFileBuffer.Write(PAnsiChar(',_'), 1); // Two characters are needed to instruct the compiler to give a pointer - but the first character should be placed in the file only
      if ((I >= Length(CSVValues)) or (CSVValues[CSVColumns[I]].Length = 0)) then
        DataFileBuffer.Write(PAnsiChar('NULL'), 4)
      else
      begin
        if (not Assigned(CSVValues[CSVColumns[I]].Text) or (CSVValues[CSVColumns[I]].Length = 0)) then
          Len := 0
        else
        begin
          if (CSVValues[CSVColumns[I]].Length > CSVUnquoteMemSize) then
          begin
            CSVUnquoteMemSize := CSVUnquoteMemSize + 2 * (CSVValues[CSVColumns[I]].Length - CSVUnquoteMemSize);
            ReallocMem(CSVUnquoteMem, CSVUnquoteMemSize);
          end;
          Len := CSVUnquote(CSVValues[CSVColumns[I]].Text, CSVValues[CSVColumns[I]].Length, CSVUnquoteMem, CSVUnquoteMemSize, Quoter);
        end;

        if (Fields[I].FieldType in BinaryFieldTypes) then
          DataFileBuffer.WriteBinary(CSVUnquoteMem, Len)
        else if (Fields[I].FieldType in TextFieldTypes) then
          DataFileBuffer.WriteText(CSVUnquoteMem, Len)
        else
          DataFileBuffer.WriteData(CSVUnquoteMem, Len, not (Fields[I].FieldType in NotQuotedFieldTypes));
      end;
    end;
end;

function TTImportText.GetValues(const Item: TTImport.TItem; var Values: TSQLStrings): Boolean;
var
  Eof: Boolean;
  I: Integer;
  RecordComplete: Boolean;
  S: string;
begin
  RecordComplete := False; Eof := False;
  while ((Success = daSuccess) and not RecordComplete and not Eof) do
  begin
    RecordComplete := CSVSplitValues(FileContent.Str, FileContent.Index, Delimiter, Quoter, CSVValues);
    if (not RecordComplete) then
      Eof := not ReadContent();
  end;

  Result := RecordComplete;
  if (Result) then
    for I := 0 to Length(Fields) - 1 do
      if ((I >= Length(CSVValues)) or (CSVValues[CSVColumns[I]].Length = 0)) then
        Values[I] := 'NULL'
      else if (Fields[I].FieldType = mfBit) then
      begin
        S := CSVUnescape(CSVValues[CSVColumns[I]].Text, CSVValues[CSVColumns[I]].Length, Quoter);
        Values[I] := IntToStr(BitStringToInt(PChar(S), Length(S)));
      end
      else if (Fields[I].FieldType in NotQuotedFieldTypes) then
        Values[I] := CSVUnescape(CSVValues[CSVColumns[I]].Text, CSVValues[CSVColumns[I]].Length, Quoter)
      else if (Fields[I].FieldType in BinaryFieldTypes) then
        Values[I] := SQLEscapeBin(CSVUnescape(CSVValues[CSVColumns[I]].Text, CSVValues[CSVColumns[I]].Length, Quoter), Client.ServerVersion <= 40000)
      else
        Values[I] := SQLEscape(CSVUnescape(CSVValues[CSVColumns[I]].Text, CSVValues[CSVColumns[I]].Length, Quoter));
end;

procedure TTImportText.Open();
var
  DT: TDateTime;
  EOF: Boolean;
  F: Double;
  FirstRecordFilePos: Integer;
  I: Integer;
  Int: Integer;
  OldSuccess: TDataAction;
  OldFileContentIndex: Integer;
  RecNo: Integer;
  RecordComplete: Boolean;
  Value: string;
begin
  inherited;

  OldSuccess := Success; OldFileContentIndex := FileContent.Index;
  FirstRecordFilePos := BOMLength;

  RecordComplete := False; Eof := False;
  while (not RecordComplete and not Eof) do
  begin
    RecordComplete := CSVSplitValues(FileContent.Str, FileContent.Index, Delimiter, Quoter, CSVValues);
    if (not RecordComplete) then
      Eof := not ReadContent();
  end;

  if (UseHeadline) then
  begin
    case (CodePage) of
      CP_Unicode: FirstRecordFilePos := BOMLength + (FileContent.Index - 1) * SizeOf(Char);
      else FirstRecordFilePos := BOMLength + WideCharToAnsiChar(CodePage, PChar(@FileContent.Str[OldFileContentIndex]), FileContent.Index - OldFileContentIndex, nil, 0);
    end;
    SetLength(FileFields, Length(CSVValues));
    for I := 0 to Length(FileFields) - 1 do
      FileFields[I].Name := CSVUnescape(CSVValues[I].Text, CSVValues[I].Length, Quoter);
  end
  else
  begin
    SetLength(FileFields, Length(CSVValues));
    for I := 0 to Length(FileFields) - 1 do
      FileFields[I].Name := 'Field_' + IntToStr(I);
  end;

  for I := 0 to Length(FileFields) - 1 do
    FileFields[I].FieldTypes := [SQL_INTEGER, SQL_FLOAT, SQL_DATE, Byte(SQL_LONGVARCHAR)];

  RecNo := 0; EOF := False;
  while ((RecNo < 20) and not EOF and RecordComplete) do
  begin
    RecordComplete := (RecNo = 0) and not UseHeadline;
    while (not RecordComplete and not Eof) do
    begin
      RecordComplete := CSVSplitValues(FileContent.Str, FileContent.Index, Delimiter, Quoter, CSVValues);
      if (not RecordComplete) then
        Eof := not ReadContent();
    end;

    if (RecordComplete and (Length(CSVValues) = Length(FileFields))) then
    begin
      for I := 0 to Length(CSVValues) - 1 do
        if (CSVValues[I].Length > 0) then
        begin
          Value := CSVUnescape(CSVValues[I].Text, CSVValues[I].Length, Quoter);
          if ((SQL_INTEGER in FileFields[I].FieldTypes) and not TryStrToInt(Value, Int)) then
            Exclude(FileFields[I].FieldTypes, SQL_INTEGER);
          if ((SQL_FLOAT in FileFields[I].FieldTypes) and not TryStrToFloat(Value, F, Client.FormatSettings)) then
            Exclude(FileFields[I].FieldTypes, SQL_FLOAT);
          if ((SQL_DATE in FileFields[I].FieldTypes) and (not TryStrToDate(Value, DT, Client.FormatSettings) or (DT < EncodeDate(1900, 1, 1)))) then
            Exclude(FileFields[I].FieldTypes, SQL_DATE);
        end;

      Inc(RecNo);
    end;
  end;

  Success := OldSuccess; ReadContent(FirstRecordFilePos);
end;

{ TTImportODBC ****************************************************************}

function SQLDataTypeToMySQLType(const SQLType: SQLSMALLINT; const Size: Integer; const FieldName: string): TMySQLFieldType;
begin
  case (SQLType) of
    SQL_CHAR: Result := mfChar;
    SQL_VARCHAR: Result := mfVarChar;
    SQL_LONGVARCHAR: Result := mfText;
    SQL_WCHAR: Result := mfChar;
    SQL_WVARCHAR: Result := mfVarChar;
    SQL_WLONGVARCHAR: Result := mfText;
    SQL_DECIMAL: Result := mfDecimal;
    SQL_NUMERIC: Result := mfDecimal;
    SQL_BIT: Result := mfBit;
    SQL_TINYINT: Result := mfTinyInt;
    SQL_SMALLINT: Result := mfSmallInt;
    SQL_INTEGER: Result := mfInt;
    SQL_BIGINT: Result := mfBigInt;
    SQL_REAL: Result := mfFloat;
    SQL_FLOAT: Result := mfFloat;
    SQL_DOUBLE: Result := mfDouble;
    SQL_BINARY: Result := mfBinary;
    SQL_VARBINARY: Result := mfVarBinary;
    SQL_LONGVARBINARY: Result := mfBlob;
    SQL_TYPE_DATE: Result := mfDate;
    SQL_TYPE_TIME: Result := mfTime;
    SQL_TYPE_TIMESTAMP: Result := mfDateTime;
    SQL_TIMESTAMP: Result := mfTimestamp;
    SQL_GUID: Result := mfChar;
    else raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [FieldName, SQLType]);
  end;
end;

procedure TTImportODBC.Add(const TableName: string; const SourceTableName: string);
begin
  SetLength(Items, Length(Items) + 1);

  Items[Length(Items) - 1].TableName := TableName;
  Items[Length(Items) - 1].RecordsDone := 0;
  Items[Length(Items) - 1].RecordsSum := 0;
  Items[Length(Items) - 1].Done := False;
  Items[Length(Items) - 1].SourceTableName := SourceTableName;
end;

procedure TTImportODBC.AfterExecuteData(var Item: TTImport.TItem);
var
  I: Integer;
begin
  Item.RecordsSum := Item.RecordsDone;

  for I := 0 to Length(ColumnDesc) - 1 do
    FreeMem(ColumnDesc[I].ColumnName);
  SetLength(ColumnDesc, 0);

  if (Assigned(ODBCData)) then
    FreeMem(ODBCData);
  if (Stmt <> SQL_NULL_HANDLE) then
    SQLFreeHandle(SQL_HANDLE_STMT, Stmt);
end;

procedure TTImportODBC.BeforeExecute();
var
  cbRecordsSum: SQLINTEGER;
  Handle: SQLHSTMT;
  I: Integer;
  RecordsSum: array [0..20] of SQLTCHAR;
  SQL: string;
begin
  inherited;

  for I := 0 to Length(Items) - 1 do
    if ((Success <> daAbort) and Data) then
    begin
      Success := daSuccess;

      if (SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_STMT, FHandle, @Handle))) then
      begin
        SQL := 'SELECT COUNT(*) FROM "' + Items[I].SourceTableName + '"';
        if (SQL_SUCCEEDED(SQLExecDirect(Handle, PSQLTCHAR(SQL), SQL_NTS))
          and SQL_SUCCEEDED(SQLFetch(Handle))
          and SQL_SUCCEEDED(SQLGetData(Handle, 1, SQL_C_WCHAR, @RecordsSum, SizeOf(RecordsSum) - 1, @cbRecordsSum))) then
            Items[I].RecordsSum := StrToInt(PChar(@RecordsSum));

        SQLFreeHandle(SQL_HANDLE_STMT, Handle);
      end;
    end;
end;

procedure TTImportODBC.BeforeExecuteData(var Item: TTImport.TItem);
var
  cbColumnName: SQLSMALLINT;
  ColumnNums: SQLSMALLINT;
  Error: TTools.TError;
  I: Integer;
  SQL: string;
  Unsigned: SQLINTEGER;
begin
  inherited;

  if (not SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_STMT, FHandle, @Stmt))) then
  begin
    Error := ODBCError(SQL_HANDLE_DBC, FHandle);
    DoError(Error, ToolsItem(Item), False);
    Stmt := SQL_NULL_HANDLE;
    ODBCData := nil;
    SetLength(ColumnDesc, 0);
  end
  else
  begin
    GetMem(ODBCData, ODBCDataSize);

    SQL := '';
    if (not Structure and (Length(SourceFields) > 1)) then
      for I := 0 to Length(SourceFields) - 1 do
      begin
        if (I > 0) then SQL := SQL + ',';
        SQL := SQL + '"' + SourceFields[I].Name + '"';
      end
    else
      SQL := '*';
    SQL := 'SELECT ' + SQL + ' FROM "' + Item.SourceTableName + '"';

    while ((Success <> daAbort) and not SQL_SUCCEEDED(SQLExecDirect(Stmt, PSQLTCHAR(SQL), SQL_NTS))) do
      DoError(ODBCError(SQL_HANDLE_STMT, Stmt), ToolsItem(Item), True);

    if (Success = daSuccess) then
    begin
      ODBCException(Stmt, SQLNumResultCols(Stmt, @ColumnNums));

      SetLength(ColumnDesc, ColumnNums);
      if (Success = daSuccess) then
        for I := 0 to Length(ColumnDesc) - 1 do
        begin
          ODBCException(Stmt, SQLDescribeCol(Stmt, I + 1, nil, 0, @cbColumnName, nil, nil, nil, nil));
          GetMem(ColumnDesc[I].ColumnName, (cbColumnName + 1) * SizeOf(SQLTCHAR));

          ODBCException(Stmt, SQLDescribeCol(Stmt, I + 1, ColumnDesc[I].ColumnName, cbColumnName, nil, @ColumnDesc[I].SQLDataType, @ColumnDesc[I].MaxDataSize, @ColumnDesc[I].DecimalDigits, @ColumnDesc[I].Nullable));
          case (ColumnDesc[I].SQLDataType) of
            SQL_TINYINT,
            SQL_SMALLINT,
            SQL_INTEGER,
            SQL_BIGINT:
              begin
                ODBCException(Stmt, SQLColAttribute(Stmt, I + 1, SQL_DESC_UNSIGNED, nil, 0, nil, @Unsigned));
                if (Unsigned = SQL_TRUE) then
                  case (ColumnDesc[I].SQLDataType) of
                    SQL_TINYINT: ColumnDesc[I].SQL_C_TYPE := SQL_C_UTINYINT;
                    SQL_SMALLINT: ColumnDesc[I].SQL_C_TYPE := SQL_C_USHORT;
                    SQL_INTEGER: ColumnDesc[I].SQL_C_TYPE := SQL_C_ULONG;
                    SQL_BIGINT: ColumnDesc[I].SQL_C_TYPE := SQL_C_UBIGINT;
                  end
                else
                  case (ColumnDesc[I].SQLDataType) of
                    SQL_TINYINT: ColumnDesc[I].SQL_C_TYPE := SQL_C_STINYINT;
                    SQL_SMALLINT: ColumnDesc[I].SQL_C_TYPE := SQL_C_SSHORT;
                    SQL_INTEGER: ColumnDesc[I].SQL_C_TYPE := SQL_C_SLONG;
                    SQL_BIGINT: ColumnDesc[I].SQL_C_TYPE := SQL_C_SBIGINT;
                  end;
              end
          end;
        end;
    end;
  end;
end;

constructor TTImportODBC.Create(const AHandle: SQLHANDLE; const ADatabase: TCDatabase);
begin
  inherited Create(ADatabase.Client, ADatabase);

  FHandle := AHandle;

  SetLength(Items, 0);
  ODBCMemSize := 256;
  GetMem(ODBCMem, ODBCMemSize);
end;

destructor TTImportODBC.Destroy();
begin
  SetLength(Items, 0);
  FreeMem(ODBCMem);

  inherited;
end;

function TTImportODBC.GetValues(const Item: TTImport.TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean;
var
  cbData: SQLINTEGER;
  I: Integer;
  ReturnCode: SQLRETURN;
  Size: Integer;
begin
  Result := SQL_SUCCEEDED(ODBCException(Stmt, SQLFetch(Stmt)));

  if (Result) then
  begin
    for I := 0 to Length(Fields) - 1 do
    begin
      if (I > 0) then
        DataFileBuffer.Write(PAnsiChar(',_'), 1); // Two characters are needed to instruct the compiler to give a pointer - but the first character should be placed in the file only

      case (ColumnDesc[I].SQLDataType) of
        SQL_BIT,
        SQL_TINYINT,
        SQL_SMALLINT,
        SQL_INTEGER,
        SQL_BIGINT,
        SQL_DECIMAL,
        SQL_NUMERIC,
        SQL_REAL,
        SQL_FLOAT,
        SQL_DOUBLE,
        SQL_TYPE_DATE,
        SQL_TYPE_TIME,
        SQL_TYPE_TIMESTAMP:
          if (not SQL_SUCCEEDED(SQLGetData(Stmt, I + 1, SQL_C_CHAR, ODBCData, ODBCDataSize, @cbData))) then
            ODBCException(Stmt, SQL_ERROR)
          else if (cbData = SQL_NULL_DATA) then
            DataFileBuffer.Write(PAnsiChar('NULL'), 4)
          else
            DataFileBuffer.Write(PSQLACHAR(ODBCData), cbData div SizeOf(SQLACHAR), ColumnDesc[I].SQLDataType in [SQL_TYPE_DATE, SQL_TYPE_TIMESTAMP, SQL_TYPE_TIME]);
        SQL_CHAR,
        SQL_VARCHAR,
        SQL_LONGVARCHAR,
        SQL_WCHAR,
        SQL_WVARCHAR,
        SQL_WLONGVARCHAR:
          begin
            Size := 0;
            repeat
              ReturnCode := SQLGetData(Stmt, I + 1, SQL_C_WCHAR, ODBCData, ODBCDataSize, @cbData);
              if ((cbData <> SQL_NULL_DATA) and (cbData > 0)) then
              begin
                if (ODBCMemSize < Size + cbData) then
                begin
                  ODBCMemSize := ODBCMemSize + 2 * (Size + cbData - ODBCMemSize);
                  ReallocMem(ODBCMem, ODBCMemSize);
                end;
                MoveMemory(@PAnsiChar(ODBCMem)[Size], ODBCData, cbData);
                Inc(Size, cbData);
              end;
            until (ReturnCode <> SQL_SUCCESS_WITH_INFO);
            if (not SQL_SUCCEEDED(ReturnCode)) then
              ODBCException(Stmt, ReturnCode)
            else if ((Size = 0) and (cbData = SQL_NULL_DATA)) then
              DataFileBuffer.Write(PAnsiChar('NULL'), 4)
            else
              DataFileBuffer.WriteText(PChar(ODBCMem), Size div SizeOf(Char));
          end;
        SQL_BINARY,
        SQL_VARBINARY,
        SQL_LONGVARBINARY:
          begin
            Size := 0;
            repeat
              ReturnCode := SQLGetData(Stmt, I + 1, SQL_C_BINARY, ODBCData, ODBCDataSize, @cbData);
              if ((cbData <> SQL_NULL_DATA) and (cbData > 0)) then
              begin
                if (ODBCMemSize < Size) then
                begin
                  ODBCMemSize := ODBCMemSize + 2 * (Size + cbData - ODBCMemSize);
                  ReallocMem(ODBCMem, ODBCMemSize);
                end;
                MoveMemory(@PAnsiChar(ODBCMem)[Size], ODBCData, cbData);
                Inc(Size, cbData);
              end;
            until (ReturnCode <> SQL_SUCCESS_WITH_INFO);
            if (not SQL_SUCCEEDED(ReturnCode)) then
              ODBCException(Stmt, ReturnCode)
            else if (cbData = SQL_NULL_DATA) then
              DataFileBuffer.Write(PAnsiChar('NULL'), 4)
            else
              DataFileBuffer.WriteBinary(my_char(ODBCMem), Size);
          end;
        else
          raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [Fields[I].Name, ColumnDesc[I].SQLDataType]);
      end;
    end;
  end;
end;

function TTImportODBC.GetValues(const Item: TTImport.TItem; var Values: TSQLStrings): Boolean;
var
  Bytes: TBytes;
  cbData: SQLINTEGER;
  D: Double;
  I: Integer;
  ReturnCode: SQLRETURN;
  S: string;
  Timestamp: tagTIMESTAMP_STRUCT;
begin
  Result := SQL_SUCCEEDED(ODBCException(Stmt, SQLFetch(Stmt)));
  if (Result) then
    for I := 0 to Length(Fields) - 1 do
      case (ColumnDesc[I].SQLDataType) of
        SQL_BIT,
        SQL_TINYINT,
        SQL_SMALLINT,
        SQL_INTEGER,
        SQL_BIGINT:
          if (not SQL_SUCCEEDED(SQLGetData(Stmt, I + 1, SQL_C_WCHAR, ODBCData, ODBCDataSize, @cbData))) then
            ODBCException(Stmt, SQL_ERROR)
          else if (cbData = SQL_NULL_DATA) then
            Values[I] := 'NULL'
          else
          begin
            SetString(S, PChar(ODBCData), cbData div SizeOf(Char));
            Values[I] := Fields[I].EscapeValue(S);
          end;
        SQL_DECIMAL,
        SQL_NUMERIC,
        SQL_REAL,
        SQL_FLOAT,
        SQL_DOUBLE:
          if (not SQL_SUCCEEDED(SQLGetData(Stmt, I + 1, SQL_C_DOUBLE, @D, SizeOf(D), @cbData))) then
            ODBCException(Stmt, SQL_ERROR)
          else if (cbData = SQL_NULL_DATA) then
            Values[I] := 'NULL'
          else
            Values[I] := Fields[I].EscapeValue(FloatToStr(D, Client.FormatSettings));
        SQL_TYPE_DATE,
        SQL_TYPE_TIME,
        SQL_TYPE_TIMESTAMP:
          if (not SQL_SUCCEEDED(SQLGetData(Stmt, I + 1, SQL_C_TYPE_TIMESTAMP, @Timestamp, SizeOf(Timestamp), @cbData))) then
            ODBCException(Stmt, SQL_ERROR)
          else if (cbData = SQL_NULL_DATA) then
            Values[I] := 'NULL'
          else
            with (Timestamp) do
              if (ColumnDesc[I].SQLDataType = SQL_TYPE_TIME) then
                Values[I] := SQLEscape(TimeToStr(EncodeTime(hour, minute, second, 0), Client.FormatSettings))
              else if (ColumnDesc[I].SQLDataType = SQL_TYPE_TIMESTAMP) then
                Values[I] := SQLEscape(MySQLDB.DateTimeToStr(EncodeDate(year, month, day) + EncodeTime(hour, minute, second, 0), Client.FormatSettings))
              else if (ColumnDesc[I].SQLDataType = SQL_TYPE_DATE) then
                Values[I] := SQLEscape(MySQLDB.DateToStr(EncodeDate(year, month, day) + EncodeTime(hour, minute, second, 0), Client.FormatSettings));
        SQL_CHAR,
        SQL_VARCHAR,
        SQL_LONGVARCHAR,
        SQL_WCHAR,
        SQL_WVARCHAR,
        SQL_WLONGVARCHAR:
          begin
            SetLength(S, 0);
            repeat
              ReturnCode := SQLGetData(Stmt, I + 1, SQL_C_WCHAR, ODBCData, ODBCDataSize, @cbData);
              if (cbData <> SQL_NULL_DATA) then
              begin
                SetLength(S, Length(S) + cbData div SizeOf(SQLTCHAR));
                if (cbData > 0) then
                  MoveMemory(@S[1 + Length(S) - cbData div SizeOf(SQLTCHAR)], ODBCData, cbData);
              end;
            until (ReturnCode <> SQL_SUCCESS_WITH_INFO);
            if (not SQL_SUCCEEDED(ReturnCode)) then
              ODBCException(Stmt, ReturnCode)
            else if (cbData = SQL_NULL_DATA) then
              Values[I] := 'NULL'
            else
              Values[I] := Fields[I].EscapeValue(S);
          end;
        SQL_BINARY,
        SQL_VARBINARY,
        SQL_LONGVARBINARY:
          begin
            SetLength(Bytes, 0);
            repeat
              ReturnCode := SQLGetData(Stmt, I + 1, SQL_C_BINARY, ODBCData, ODBCDataSize, @cbData);
              if (cbData <> SQL_NULL_DATA) then
              begin
                SetLength(Bytes, Length(Bytes) + cbData);
                if (cbData > 0) then
                  MoveMemory(@Bytes[Length(Bytes) - cbData], ODBCData, cbData);
              end;
            until (ReturnCode <> SQL_SUCCESS_WITH_INFO);
            if (not SQL_SUCCEEDED(ReturnCode)) then
              ODBCException(Stmt, ReturnCode)
            else if (cbData = SQL_NULL_DATA) then
              Values[I] := 'NULL'
            else if (Length(Bytes) = 0) then
              Values[I] := SQLEscapeBin(nil, 0, Client.ServerVersion <= 40000)
            else
              Values[I] := SQLEscapeBin(@Bytes[0], Length(Bytes), Client.ServerVersion <= 40000);
          end;
        else
          raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [Fields[I].Name, Ord(Fields[I].FieldType)]);
      end;
end;

procedure TTImportODBC.ExecuteStructure(var Item: TTImport.TItem);
var
  AscOrDesc: array [0 .. 2 - 1] of SQLTCHAR;
  AutoUniqueValue: SQLINTEGER;
  cbAscOrDesc: SQLINTEGER;
  cbColumnDef: SQLINTEGER;
  cbColumnName: SQLINTEGER;
  cbColumnSize: SQLINTEGER;
  cbDecimalDigits: SQLINTEGER;
  cbIndexName: SQLINTEGER;
  cbIndexType: SQLINTEGER;
  cbNonUnique: SQLINTEGER;
  cbNullable: SQLINTEGER;
  cbOrdinalPosition: SQLINTEGER;
  cbRemarks: SQLINTEGER;
  cbSQLDataType: SQLINTEGER;
  cbSQLDataType2: SQLINTEGER;
  ColumnDef: array [0 .. STR_LEN] of SQLTCHAR;
  ColumnName: array [0 .. STR_LEN] of SQLTCHAR;
  ColumnNumber: SQLINTEGER;
  ColumnSize: SQLINTEGER;
  DecimalDigits: SQLSMALLINT;
  Found: Boolean;
  I: Integer;
  Key: TCKey;
  IndexName: array [0 .. STR_LEN] of SQLTCHAR;
  IndexType: SQLSMALLINT;
  J: Integer;
  Len: SQLINTEGER;
  NewKeyColumn: TCKeyColumn;
  NewField: TCBaseTableField;
  NewTable: TCBaseTable;
  NonUnique: SQLSMALLINT;
  Nullable: SQLSMALLINT;
  OrdinalPosition: SQLSMALLINT;
  Remarks: array [0 .. 256 - 1] of SQLTCHAR;
  S: string;
  SQLDataType: SQLSMALLINT;
  SQLDataType2: SQLSMALLINT;
  Stmt: SQLHSTMT;
  Table: TCBaseTable;
  Unsigned: SQLINTEGER;
begin
  SetLength(SourceFields, 0);

  NewTable := TCBaseTable.Create(Database.Tables);
  NewTable.DefaultCharset := Charset;
  NewTable.Collation := Collation;
  NewTable.Engine := Client.EngineByName(Engine);
  NewTable.RowType := RowType;

  if (SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_STMT, FHandle, @Stmt))) then
  begin
    ODBCException(Stmt, SQLColumns(Stmt, nil, 0, nil, 0, PSQLTCHAR(Item.SourceTableName), SQL_NTS, nil, 0));

    ODBCException(Stmt, SQLBindCol(Stmt, 4, SQL_C_WCHAR, @ColumnName, SizeOf(ColumnName), @cbColumnName));

    ODBCException(Stmt, SQLBindCol(Stmt, 5, SQL_C_SSHORT, @SQLDataType, SizeOf(SQLDataType), @cbSQLDataType));
    ODBCException(Stmt, SQLBindCol(Stmt, 7, SQL_C_SLONG, @ColumnSize, SizeOf(ColumnSize), @cbColumnSize));
    ODBCException(Stmt, SQLBindCol(Stmt, 9, SQL_C_SSHORT, @DecimalDigits, SizeOf(DecimalDigits), @cbDecimalDigits));
    ODBCException(Stmt, SQLBindCol(Stmt, 11, SQL_C_SSHORT, @Nullable, SizeOf(Nullable), @cbNullable));
    if (not SQL_SUCCEEDED(SQLBindCol(Stmt, 12, SQL_C_WCHAR, @Remarks, SizeOf(Remarks), @cbRemarks))) then
      begin ZeroMemory(@Remarks, SizeOf(Remarks)); cbRemarks := 0; end;
    if (not SQL_SUCCEEDED(SQLBindCol(Stmt, 13, SQL_C_WCHAR, @ColumnDef, SizeOf(ColumnDef), @cbColumnDef))) then
      begin ZeroMemory(@ColumnDef, SizeOf(ColumnDef)); cbColumnDef := 0; end;
    if (not SQL_SUCCEEDED(SQLBindCol(Stmt, 14, SQL_C_SSHORT, @SQLDataType2, SizeOf(SQLDataType2), @cbSQLDataType2))) then
      begin ZeroMemory(@SQLDataType2, SizeOf(SQLDataType2)); cbSQLDataType2 := 0; end;

    while (SQL_SUCCEEDED(ODBCException(Stmt, SQLFetch(Stmt)))) do
      if (not Assigned(NewTable.FieldByName(ColumnName))) then
      begin
        SetLength(SourceFields, Length(SourceFields) + 1);
        SourceFields[Length(SourceFields) - 1].Name := ColumnName;


        NewField := TCBaseTableField.Create(NewTable.Fields);
        NewField.Name := Client.ApplyIdentifierName(ColumnName);
        if (NewTable.Fields.Count > 0) then
          NewField.FieldBefore := NewTable.Fields[NewTable.Fields.Count - 1];
        if (SQLDataType <> SQL_UNKNOWN_TYPE) then
          NewField.FieldType := SQLDataTypeToMySQLType(SQLDataType, ColumnSize, NewField.Name)
        else if (cbSQLDataType2 > 0) then
          NewField.FieldType := SQLDataTypeToMySQLType(SQLDataType2, ColumnSize, NewField.Name)
        else
          raise EODBCError.CreateFMT(SUnknownFieldType + ' (%d)', [ColumnName, SQLDataType]);
        if (not (NewField.FieldType in [mfFloat, mfDouble, mfDecimal]) or (DecimalDigits > 0)) then
        begin
          NewField.Size := ColumnSize;
          NewField.Decimals := DecimalDigits;
        end;
        if (cbColumnDef > 0) then
        begin
          SetString(S, ColumnDef, cbColumnDef);
          while ((Length(S) > 0) and (S[Length(S)] = #0)) do
            Delete(S, Length(S), 1);
          if (SysUtils.UpperCase(S) = 'NULL') then
            NewField.Default := 'NULL'
          else if ((NewField.FieldType in [mfTinyInt, mfSmallInt, mfMediumInt, mfInt, mfBigInt]) and (SysUtils.LowerCase(S) = '(newid())')) then
            NewField.AutoIncrement := True
          else if (SysUtils.LowerCase(S) = '(getdate())') then
          begin
            NewField.FieldType := mfTimestamp;
            NewField.Default := 'CURRENT_TIMESTAMP';
          end
          else if (NewField.FieldType in NotQuotedFieldTypes) then
          begin
            S := NewField.UnescapeValue(S);
            if ((LeftStr(S, 1) = '(') and (RightStr(S, 1) = ')')) then
              S := Copy(S, 2, Length(S) - 2);
            NewField.Default := S;
          end
          else if ((LeftStr(S, 1) <> '(') or (RightStr(S, 1) <> ')')) then
            NewField.Default := NewField.EscapeValue(NewField.UnescapeValue(S));
        end;
        NewField.NullAllowed := (Nullable <> SQL_NO_NULLS) or (NewField.Default = 'NULL');
        NewField.Comment := Remarks;

        NewTable.Fields.AddField(NewField);
        FreeAndNil(NewField);
      end;

    SQLFreeHandle(SQL_HANDLE_STMT, Stmt);


    if (SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_STMT, FHandle, @Stmt))) then
    begin
      if (SQL_SUCCEEDED(SQLExecDirect(Stmt, PSQLTCHAR(string('SELECT * FROM "' + Item.SourceTableName + '" WHERE 0<>0')), SQL_NTS))) then
      begin
        ColumnNumber := 1;
        while (SQL_SUCCEEDED(SQLColAttribute(Stmt, ColumnNumber, SQL_DESC_BASE_COLUMN_NAME, @ColumnName, SizeOf(ColumnName), @cbColumnName, nil))) do
        begin
          ODBCException(Stmt, SQLColAttribute(Stmt, ColumnNumber, SQL_DESC_AUTO_UNIQUE_VALUE, nil, 0, nil, @AutoUniqueValue));
          ODBCException(Stmt, SQLColAttribute(Stmt, ColumnNumber, SQL_DESC_UNSIGNED, nil, 0, nil, @Unsigned));
          NewField := NewTable.FieldByName(ColumnName);
          if (Assigned(NewField)) then
          begin
            NewField.AutoIncrement := AutoUniqueValue = SQL_TRUE;
            NewField.Unsigned := Unsigned = SQL_TRUE;
          end;

          Inc(ColumnNumber)
        end;
      end;
      SQLFreeHandle(SQL_HANDLE_STMT, Stmt);
    end;
  end;

  if (NewTable.Fields.Count = 0) then
    raise Exception.CreateFMT('Can''t read column definition from NewTable "%s"!', [Item.SourceTableName]);

  if (Success = daSuccess) and SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_STMT, FHandle, @Stmt)) then
  begin
    ODBCException(Stmt, SQLStatistics(Stmt, nil, 0, nil, 0, PSQLTCHAR(Item.SourceTableName), SQL_NTS, SQL_INDEX_UNIQUE, SQL_QUICK));

    ODBCException(Stmt, SQLBindCol(Stmt, 4, SQL_C_SSHORT, @NonUnique, SizeOf(NonUnique), @cbNonUnique));
    ODBCException(Stmt, SQLBindCol(Stmt, 6, SQL_C_WCHAR, @IndexName, SizeOf(IndexName), @cbIndexName));
    ODBCException(Stmt, SQLBindCol(Stmt, 7, SQL_C_SSHORT, @IndexType, SizeOf(IndexType), @cbIndexType));
    ODBCException(Stmt, SQLBindCol(Stmt, 8, SQL_C_SSHORT, @OrdinalPosition, SizeOf(OrdinalPosition), @cbOrdinalPosition));
    ODBCException(Stmt, SQLBindCol(Stmt, 9, SQL_C_WCHAR, @ColumnName, SizeOf(ColumnName), @cbColumnName));
    ODBCException(Stmt, SQLBindCol(Stmt, 10, SQL_C_WCHAR, @AscOrDesc[0], SizeOf(AscOrDesc), @cbAscOrDesc));

    while (SQL_SUCCEEDED(ODBCException(Stmt, SQLFetch(Stmt)))) do
      if ((IndexType in [SQL_INDEX_CLUSTERED, SQL_INDEX_HASHED, SQL_INDEX_OTHER])) then
      begin
        Key := NewTable.IndexByName(IndexName);

        if (not Assigned(Key)) then
        begin
          Key := TCKey.Create(NewTable.Keys);
          Key.Name := Client.ApplyIdentifierName(IndexName);
          Key.Unique := NonUnique = SQL_FALSE;
          NewTable.Keys.AddKey(Key);
          Key.Free();

          Key := NewTable.IndexByName(IndexName);
        end;

        NewKeyColumn := TCKeyColumn.Create(Key.Columns);
        NewKeyColumn.Field := NewTable.FieldByName(ColumnName);
        NewKeyColumn.Ascending := AscOrDesc[0] = 'A';
        Key.Columns.AddColumn(NewKeyColumn);
        FreeAndNil(NewKeyColumn);
      end;

    SQLFreeHandle(SQL_HANDLE_STMT, Stmt);


    if ((NewTable.Keys.Count > 0) and not Assigned(NewTable.IndexByName(''))) then
    begin
      Key := nil;
      for I := NewTable.Keys.Count - 1 downto 0 do
        if ((SysUtils.UpperCase(NewTable.Keys[I].Name) = 'PRIMARYKEY') and NewTable.Keys[0].Unique) then
          Key := NewTable.Keys[I];
      if (Assigned(Key)) then
      begin
        Key.Primary := True;
        Key.Name := '';
      end;
    end;

    if ((NewTable.Keys.Count > 0) and not NewTable.Keys[0].Primary and NewTable.Keys[0].Unique) then
    begin
      NewTable.Keys[0].Primary := True;
      NewTable.Keys[0].Name := '';
    end;

    for I := 0 to NewTable.Fields.Count -1 do
      if ((NewTable.Keys.Count = 0) and NewTable.Fields[I].AutoIncrement) then
      begin
        Key := TCKey.Create(NewTable.Keys);
        Key.Primary := True;
        NewTable.Keys.AddKey(Key);
        Key.Free();

        Key := NewTable.Keys[0];

        NewKeyColumn := TCKeyColumn.Create(Key.Columns);
        NewKeyColumn.Field := TCBaseTableField(NewTable.Fields[I]);
        Key.Columns.AddColumn(NewKeyColumn);
        FreeAndNil(NewKeyColumn);
      end;

    for I := NewTable.Keys.Count - 1 downto 1 do
      for J := I - 1 downto 0 do
        if (I <> J) then
          if (NewTable.Keys[J].Equal(NewTable.Keys[I])) then
            NewTable.Keys.DeleteKey(NewTable.Keys[J])
          else if (SysUtils.UpperCase(NewTable.Keys[I].Name) = SysUtils.UpperCase(NewTable.Keys[J].Name)) then
            NewTable.Keys[I].Name := 'Index_' + IntToStr(I);

    Found := False;
    for I := 0 to NewTable.Fields.Count - 1 do
    begin
      NewTable.Fields[I].AutoIncrement := not Found and NewTable.Fields[I].AutoIncrement and (NewTable.Keys.Count > 0) and (NewTable.Keys[0].Name = '') and (NewTable.Keys[0].Columns.KeyByField(NewTable.Fields[I]) >= 0);
      Found := Found or NewTable.Fields[I].AutoIncrement;
      if (NewTable.Fields[I].AutoIncrement) then
        NewTable.Fields[I].Default := '';
    end;

    Found := False;
    for I := 0 to NewTable.Fields.Count - 1 do
    begin
      if (Found and (NewTable.Fields[I].Default = 'CURRENT_TIMESTAMP')) then
        NewTable.Fields[I].Default := '';
      Found := Found or (NewTable.Fields[I].Default = 'CURRENT_TIMESTAMP');
    end;

    NewTable.Name := Client.ApplyIdentifierName(Item.TableName);

    while ((Success <> daAbort) and not Database.AddTable(NewTable)) do
      DoError(DatabaseError(Client), ToolsItem(Item), True);
  end;

  NewTable.Free();

  Table := Database.BaseTableByName(Item.TableName);
  if (not Assigned(Table)) then
    SetLength(Fields, 0)
  else
  begin
    SetLength(Fields, Table.Fields.Count);
    for I := 0 to Table.Fields.Count - 1 do
      Fields[I] := Table.Fields[I];
  end;
end;

function TTImportODBC.ODBCStmtException(const Handle: SQLHANDLE): Exception;
var
  MessageText: array [0 .. STR_LEN] of SQLTCHAR;
  NativeErrorPtr: SQLSMALLINT;
  SQLState: array [0 .. SQL_SQLSTATE_SIZE] of SQLTCHAR;
  TextLengthPtr: SQLSMALLINT;
begin
  SQLGetDiagRec(SQL_HANDLE_STMT, Handle, 1, @SQLState, @NativeErrorPtr, @MessageText, Length(MessageText), @TextLengthPtr);
  Result := Exception.Create(string(MessageText) + ' (' + SQLState + ')');
end;

{ TTImportSQLite *****************************************************************}

procedure TTImportSQLite.Add(const TableName: string; const SheetName: string);
begin
  SetLength(Items, Length(Items) + 1);

  Items[Length(Items) - 1].TableName := TableName;
  Items[Length(Items) - 1].RecordsDone := 0;
  Items[Length(Items) - 1].RecordsSum := 0;
  Items[Length(Items) - 1].Done := False;
  Items[Length(Items) - 1].SourceTableName := SheetName;
end;

procedure TTImportSQLite.AfterExecuteData(var Item: TTImport.TItem);
begin
  sqlite3_finalize(Stmt); Stmt := nil;
end;

procedure TTImportSQLite.BeforeExecute();
var
  I: Integer;
begin
  inherited;

  if ((Success = daSuccess) and Data) then
    for I := 0 to Length(Items) - 1 do
    begin
      SQLiteException(Handle, sqlite3_prepare_v2(Handle, PAnsiChar(UTF8Encode('SELECT COUNT(*) FROM "' + Items[I].SourceTableName + '"')), -1, @Stmt, nil));
      if (sqlite3_step(Stmt) = SQLITE_ROW) then
        Items[I].RecordsSum := sqlite3_column_int(Stmt, 0);
      sqlite3_finalize(Stmt); Stmt := nil;
    end;
end;

procedure TTImportSQLite.BeforeExecuteData(var Item: TTImport.TItem);
var
  I: Integer;
  SQL: string;
begin
  inherited;

  SQL := '';
  if (not Structure and (Length(Items) = 1)) then
    for I := 0 to Length(SourceFields) - 1 do
    begin
      if (I > 0) then SQL := SQL + ',';
      SQL := SQL + '"' + SourceFields[I].Name + '"';
    end
  else
    SQL := '*';
  SQL := 'SELECT ' + SQL + ' FROM "' + Item.SourceTableName + '"';

  SQLiteException(Handle, sqlite3_prepare_v2(Handle, PAnsiChar(UTF8Encode(SQL)), -1, @Stmt, nil));
end;

constructor TTImportSQLite.Create(const AHandle: sqlite3_ptr; const ADatabase: TCDatabase);
begin
  inherited Create(ADatabase.Client, ADatabase);

  ImportType := itInsert;

  Handle := AHandle;
end;

function TTImportSQLite.GetValues(const Item: TTImport.TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean;
var
  I: Integer;
begin
  Result := sqlite3_step(Stmt) = SQLITE_ROW;
  if (Result) then
  begin
    for I := 0 to Length(Fields) - 1 do
    begin
      if (I > 0) then
        DataFileBuffer.Write(PAnsiChar(',_'), 1); // Two characters are needed to instruct the compiler to give a pointer - but the first character should be placed in the file only
      if (sqlite3_column_type(Stmt, I) = SQLITE_NULL) then
        DataFileBuffer.Write(PAnsiChar('NULL'), 4)
      else if (Fields[I].FieldType in BinaryFieldTypes) then
        DataFileBuffer.WriteBinary(my_char(sqlite3_column_blob(Stmt, I)), sqlite3_column_bytes(Stmt, I))
      else if (Fields[I].FieldType in TextFieldTypes) then
        DataFileBuffer.WriteText(sqlite3_column_text(Stmt, I), sqlite3_column_bytes(Stmt, I), CP_UTF8)
      else
        DataFileBuffer.Write(sqlite3_column_text(Stmt, I), sqlite3_column_bytes(Stmt, I), not (Fields[I].FieldType in NotQuotedFieldTypes));
    end;
  end;
end;

function TTImportSQLite.GetValues(const Item: TTImport.TItem; var Values: TSQLStrings): Boolean;
var
  I: Integer;
  RBS: RawByteString;
begin
  Result := sqlite3_step(Stmt) = SQLITE_ROW;
  if (Result) then
    for I := 0 to Length(Fields) - 1 do
      case (sqlite3_column_type(Stmt, I)) of
        SQLITE_NULL:
          if (Fields[I].NullAllowed) then
            Values[I] := 'NULL'
          else
            Values[I] := Fields[I].EscapeValue('');
        SQLITE_INTEGER:
          Values[I] := Fields[I].EscapeValue(IntToStr(sqlite3_column_int64(Stmt, I)));
        SQLITE_FLOAT:
          Values[I] := Fields[I].EscapeValue(FloatToStr(sqlite3_column_double(Stmt, I), Client.FormatSettings));
        SQLITE3_TEXT:
          begin
            SetString(RBS, sqlite3_column_text(Stmt, I), sqlite3_column_bytes(Stmt, I));
            Values[I] := SQLEscape(UTF8ToString(RBS));
          end;
        SQLITE_BLOB:
          Values[I] := SQLEscapeBin(sqlite3_column_blob(Stmt, I), sqlite3_column_bytes(Stmt, I), Client.ServerVersion <= 40000);
        else
          raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [SourceFields[I].Name, Integer(sqlite3_column_type(Stmt, I))]);
      end;
end;

procedure TTImportSQLite.ExecuteStructure(var Item: TTImport.TItem);
var
  Error: TTools.TError;
  I: Integer;
  Name: string;
  NewField: TCBaseTableField;
  NewKey: TCKey;
  NewKeyColumn: TCKeyColumn;
  NewTable: TCBaseTable;
  Parse: TSQLParse;
  ParseSQL: string;
  Primary: Boolean;
  RBS: RawByteString;
  SQL: string;
  Stmt: sqlite3_stmt_ptr;
  Table: TCBaseTable;
  Unique: Boolean;
begin
  SetLength(SourceFields, 0);


  NewTable := nil;

  SQLiteException(Handle, sqlite3_prepare_v2(Handle, PAnsiChar(UTF8Encode('SELECT "sql" FROM "sqlite_master" WHERE type=''table'' AND name=''' + Item.TableName + '''')), -1, @Stmt, nil));
  if (sqlite3_step(Stmt) = SQLITE_ROW) then
  begin
    ParseSQL := UTF8ToString(sqlite3_column_text(Stmt, 0));
    if (not SQLCreateParse(Parse, PChar(ParseSQL), Length(ParseSQL), 0)) then
    begin
      Error.ErrorType := TE_SQLite;
      Error.ErrorCode := 0;
      Error.ErrorMessage := 'Empty Result';
      DoError(Error, EmptyToolsItem(), False);
    end
    else
    begin
      SQL := UTF8ToString(sqlite3_column_text(Stmt, 0));

      NewTable := TCBaseTable.Create(Database.Tables, Item.TableName);
      NewTable.DefaultCharset := Charset;
      NewTable.Collation := Collation;
      NewTable.Engine := Client.EngineByName(Engine);
      NewTable.RowType := RowType;

      if (not SQLParseKeyword(Parse, 'CREATE TABLE')) then raise EConvertError.CreateFmt(SSourceParseError, [Item.TableName, 1, SQL]);

      NewTable.Name := Client.ApplyIdentifierName(SQLParseValue(Parse));

      if (not SQLParseChar(Parse, '(')) then raise EConvertError.CreateFmt(SSourceParseError, [Item.TableName, 2, SQL]);

      repeat
        Name := Client.ApplyIdentifierName(SQLParseValue(Parse));
        Primary := False;

        SetLength(SourceFields, Length(SourceFields) + 1);
        SourceFields[Length(SourceFields) - 1].Name := Name;


        NewField := TCBaseTableField.Create(NewTable.Fields);
        NewField.Name := Name;
        if (SQLParseKeyword(Parse, 'INTEGER PRIMARY KEY')) then
        begin
          Primary := True;
          NewField.FieldType := mfBigInt;
          NewField.Unsigned := False;
          NewField.AutoIncrement := SQLParseKeyword(Parse, 'AUTOINCREMENT');
        end
        else if (SQLParseKeyword(Parse, 'INTEGER')) then
          NewField.FieldType := mfBigInt
        else if (SQLParseKeyword(Parse, 'REAL')) then
          NewField.FieldType := mfDouble
        else if (SQLParseKeyword(Parse, 'TEXT')) then
          NewField.FieldType := mfLongText
        else if (SQLParseKeyword(Parse, 'BLOB')) then
          NewField.FieldType := mfLongBlob
        else
          raise EConvertError.CreateFmt(SSourceParseError, [Item.TableName, 3, SQL]);

        if (SQLParseChar(Parse, '(')) then
        begin
          if (TryStrToInt(SQLParseValue(Parse), I)) then
            NewField.Size := I;
          if (SQLParseChar(Parse, ',')) then
            if (TryStrToInt(SQLParseValue(Parse), I)) then
              NewField.Decimals := I;
          SQLParseChar(Parse, ')');
        end;

        // Ignore all further field properties like keys and foreign keys
        while (not SQLParseChar(Parse, ',', False) and not SQLParseChar(Parse, ')', False) and (SQLParseGetIndex(Parse) <= Length(SQL))) do
          SQLParseValue(Parse);

        if (NewTable.Fields.Count > 0) then
          NewField.FieldBefore := NewTable.Fields[NewTable.Fields.Count - 1];
        NewTable.Fields.AddField(NewField);
        NewField.Free();

        if (Primary) then
        begin
          NewKey := TCKey.Create(NewTable.Keys);
          NewKey.Primary := True;
          NewKeyColumn := TCKeyColumn.Create(NewKey.Columns);
          NewKeyColumn.Field := TCBaseTableField(NewTable.Fields[NewTable.Fields.Count - 1]);
          NewKeyColumn.Ascending := True;
          NewKey.Columns.AddColumn(NewKeyColumn);
          NewKeyColumn.Free();
          NewTable.Keys.AddKey(NewKey);
          NewKey.Free();
        end;
      until (not SQLParseChar(Parse, ',') and SQLParseChar(Parse, ')'));
    end;
  end;
  SQLiteException(Handle, sqlite3_finalize(Stmt));

  if (Assigned(NewTable)) then
  begin
    RBS := UTF8Encode('SELECT "sql" FROM "sqlite_master" WHERE type=''index''');
    SQLiteException(Handle, sqlite3_prepare_v2(Handle, PAnsiChar(RBS), -1, @Stmt, nil));
    while (sqlite3_step(Stmt) = SQLITE_ROW) do
    begin
      SQL := UTF8ToString(sqlite3_column_text(Stmt, 0));

      if (not SQLParseKeyword(Parse, 'CREATE')) then raise EConvertError.CreateFmt(SSourceParseError, [Item.TableName, 3, SQL]);

      Unique := SQLParseKeyword(Parse, 'UNIQUE');

      if (not SQLParseKeyword(Parse, 'INDEX')) then raise EConvertError.CreateFmt(SSourceParseError, [Item.TableName, 4, SQL]);

      Name := SQLParseValue(Parse);

      if (not SQLParseKeyword(Parse, 'ON')) then raise EConvertError.CreateFmt(SSourceParseError, [Item.TableName, 5, SQL]);

      if (SQLParseValue(Parse) = NewTable.Name) then
      begin
        NewKey := TCKey.Create(NewTable.Keys);
        NewKey.Name := Client.ApplyIdentifierName(Name);
        NewKey.Unique := Unique;

        NewKeyColumn := TCKeyColumn.Create(NewKey.Columns);
        NewKeyColumn.Field := NewTable.FieldByName(SQLParseValue(Parse));
        if (SQLParseKeyword(Parse, 'COLLATE')) then
          SQLParseValue(Parse);
        NewKeyColumn.Ascending := SQLParseKeyword(Parse, 'ASC') or not SQLParseKeyword(Parse, 'DESC');
        NewKey.Columns.AddColumn(NewKeyColumn);
        NewKeyColumn.Free();

        NewTable.Keys.AddKey(NewKey);
        NewKey.Free();
      end;
    end;
    SQLiteException(Handle, sqlite3_finalize(Stmt));

    while ((Success <> daAbort) and not Database.AddTable(NewTable)) do
      DoError(DatabaseError(Client), ToolsItem(Item), True);

    NewTable.Free();
  end;

  if (Success = daSuccess) then
  begin
    Table := Database.BaseTableByName(Client.ApplyIdentifierName(Item.TableName));
    if (Assigned(Table)) then
    begin
      SetLength(Fields, Table.Fields.Count);
      for I := 0 to Table.Fields.Count - 1 do
        Fields[I] := Table.Fields[I];
    end;
  end;
end;

{ TTImportXML *****************************************************************}

procedure TTImportXML.Add(const TableName: string);
begin
  SetLength(Items, Length(Items) + 1);

  Items[Length(Items) - 1].TableName := TableName;
  Items[Length(Items) - 1].RecordsDone := 0;
  Items[Length(Items) - 1].RecordsSum := 0;
  Items[Length(Items) - 1].Done := False;
end;

procedure TTImportXML.BeforeExecute();
var
  Error: TTools.TError;
begin
  inherited;

  XMLNode := XMLDocument.documentElement.selectSingleNode('//*/' + RecordTag);

  if (not Assigned(XMLNode)) then
  begin
    Error.ErrorType := TE_XML;
    Error.ErrorCode := 0;
    Error.ErrorMessage := 'Node not found.';
    DoError(Error, EmptyToolsItem(), False);
  end;
end;

procedure TTImportXML.BeforeExecuteData(var Item: TTImport.TItem);
begin
  inherited;

  if (Assigned(XMLNode)) then
    Item.RecordsSum := XMLNode.parentNode.childNodes.length;
end;

constructor TTImportXML.Create(const AFilename: TFileName; const ATable: TCBaseTable);
begin
  inherited Create(ATable.Database.Client, ATable.Database);

  Add(ATable.Name);

  Data := True;
  RecordTag := 'row';

  CoInitialize(nil);

  XMLDocument := CoDOMDocument30.Create();
  if (not XMLDocument.load(AFilename)) then
    CoUninitialize();
end;

destructor TTImportXML.Destroy();
begin
  CoUninitialize();

  inherited;
end;

function TTImportXML.GetValues(const Item: TTImport.TItem; const DataFileBuffer: TTools.TDataFileBuffer): Boolean;
var
  I: Integer;
  J: Integer;
  XMLValueNode: IXMLDOMNode;
begin
  Result := Assigned(XMLNode);
  if (Result) then
  begin
    for I := 0 to Length(Fields) - 1 do
    begin
      XMLValueNode := XMLNode.selectSingleNode('@' + SysUtils.LowerCase(SourceFields[I].Name));
      if (not Assigned(XMLValueNode)) then
      begin
        XMLValueNode := XMLNode.selectSingleNode(SysUtils.LowerCase(SourceFields[I].Name));
        for J := 0 to XMLNode.childNodes.length - 1 do
          if (not Assigned(XMLValueNode) and (XMLNode.childNodes[J].nodeName = 'field') and Assigned(XMLNode.childNodes[J].selectSingleNode('@name')) and (lstrcmpI(PChar(XMLNode.childNodes[J].selectSingleNode('@name').text), PChar(SourceFields[I].Name)) = 0)) then
            XMLValueNode := XMLNode.childNodes[J];
      end;

      if (I > 0) then
        DataFileBuffer.Write(PAnsiChar(',_'), 1); // Two characters are needed to instruct the compiler to give a pointer - but the first character should be placed in the file only
      if (not Assigned(XMLValueNode) or (XMLValueNode.text = '') and Assigned(XMLValueNode.selectSingleNode('@xsi:nil')) and (XMLValueNode.selectSingleNode('@xsi:nil').text = 'true')) then
        DataFileBuffer.Write(PAnsiChar('NULL'), 4)
      else if (Fields[I].FieldType in BinaryFieldTypes) then
        DataFileBuffer.WriteBinary(PChar(XMLValueNode.text), Length(XMLValueNode.text))
      else if (Fields[I].FieldType in TextFieldTypes) then
        DataFileBuffer.WriteText(PChar(XMLValueNode.text), Length(XMLValueNode.text))
      else
        DataFileBuffer.WriteData(PChar(XMLValueNode.text), Length(XMLValueNode.text), not (Fields[I].FieldType in NotQuotedFieldTypes));
    end;

    repeat
      XMLNode := XMLNode.nextSibling;
    until (not Assigned(XMLNode) or (XMLNode.nodeName = RecordTag));
  end;
end;

function TTImportXML.GetValues(const Item: TTImport.TItem; var Values: TSQLStrings): Boolean;
var
  I: Integer;
  J: Integer;
  XMLValueNode: IXMLDOMNode;
begin
  Result := Assigned(XMLNode);
  if (Result) then
  begin
    for I := 0 to Length(Fields) - 1 do
    begin
      XMLValueNode := XMLNode.selectSingleNode('@' + SysUtils.LowerCase(SourceFields[I].Name));
      if (not Assigned(XMLValueNode)) then
      begin
        XMLValueNode := XMLNode.selectSingleNode(SysUtils.LowerCase(SourceFields[I].Name));
        for J := 0 to XMLNode.childNodes.length - 1 do
          if (not Assigned(XMLValueNode) and (XMLNode.childNodes[J].nodeName = 'field') and Assigned(XMLNode.childNodes[J].selectSingleNode('@name')) and (XMLNode.childNodes[J].selectSingleNode('@name').text = SourceFields[I].Name)) then
            XMLValueNode := XMLNode.childNodes[J];
      end;

      if (not Assigned(XMLValueNode) or (XMLValueNode.text = '') and Assigned(XMLValueNode.selectSingleNode('@xsi:nil')) and (XMLValueNode.selectSingleNode('@xsi:nil').text = 'true')) then
        Values[I] := 'NULL'
      else
        Values[I] := Fields[I].EscapeValue(XMLValueNode.text);
    end;

    repeat
      XMLNode := XMLNode.nextSibling;
    until (not Assigned(XMLNode) or (XMLNode.nodeName = RecordTag));
  end;
end;

{ TTExport ********************************************************************}

procedure TTExport.Add(const ADBGrid: TDBGrid);
begin
  SetLength(FDBGrids, Length(DBGrids) + 1);

  DBGrids[Length(DBGrids) - 1].DBGrid := ADBGrid;
  DBGrids[Length(DBGrids) - 1].RecordsDone := 0;
  DBGrids[Length(DBGrids) - 1].RecordsSum := 0;
end;

procedure TTExport.Add(const ADBObject: TCDBObject);
begin
  SetLength(ExportObjects, Length(ExportObjects) + 1);
  ExportObjects[Length(ExportObjects) - 1].DBObject := ADBObject;
end;

procedure TTExport.AfterExecute();
var
  I: Integer;
begin
  for I := 0 to Length(DBGrids) - 1 do
    DBGrids[I].DBGrid.DataSource.DataSet.EnableControls();

  FClient.EndSilent();

  inherited;
end;

procedure TTExport.BeforeExecute();
var
  I: Integer;
begin
  inherited;

  FClient.BeginSilent();

  for I := 0 to Length(DBGrids) - 1 do
    DBGrids[I].DBGrid.DataSource.DataSet.DisableControls();
end;

constructor TTExport.Create(const AClient: TCClient);
begin
  inherited Create();

  FClient := AClient;

  Data := False;
  SetLength(FDBGrids, 0);
  SetLength(ExportObjects, 0);
  Structure := False;
end;

destructor TTExport.Destroy();
begin
  SetLength(FDBGrids, 0);
  SetLength(ExportObjects, 0);

  inherited;
end;

procedure TTExport.DoUpdateGUI();
var
  I: Integer;
begin
  if (Assigned(OnUpdate)) then
  begin
    CriticalSection.Enter();

    ProgressInfos.TablesDone := 0;
    ProgressInfos.TablesSum := Length(DBGrids) + Length(ExportObjects);
    ProgressInfos.RecordsDone := 0;
    ProgressInfos.RecordsSum := 0;
    ProgressInfos.TimeDone := 0;
    ProgressInfos.TimeSum := 0;

    for I := 0 to Length(DBGrids) - 1 do
    begin
      if (DBGrids[I].Done) then
        Inc(ProgressInfos.TablesDone);

      Inc(ProgressInfos.RecordsDone, DBGrids[I].RecordsDone);
      Inc(ProgressInfos.RecordsSum, DBGrids[I].RecordsSum);
    end;

    for I := 0 to Length(ExportObjects) - 1 do
    begin
      if (ExportObjects[I].Done) then
        Inc(ProgressInfos.TablesDone);

      Inc(ProgressInfos.RecordsDone, ExportObjects[I].RecordsDone);
      Inc(ProgressInfos.RecordsSum, ExportObjects[I].RecordsSum);
    end;

    ProgressInfos.TimeDone := Now() - StartTime;

    if ((ProgressInfos.RecordsDone = 0) and (ProgressInfos.TablesDone = 0)) then
    begin
      ProgressInfos.Progress := 0;
      ProgressInfos.TimeSum := 0;
    end
    else if (ProgressInfos.RecordsDone = 0) then
    begin
      ProgressInfos.Progress := Round(ProgressInfos.TablesDone / ProgressInfos.TablesSum * 100);
      ProgressInfos.TimeSum := ProgressInfos.TimeDone / ProgressInfos.TablesDone * ProgressInfos.TablesSum;
    end
    else if (ProgressInfos.RecordsDone < ProgressInfos.RecordsSum) then
    begin
      ProgressInfos.Progress := Round(ProgressInfos.RecordsDone / ProgressInfos.RecordsSum * 100);
      ProgressInfos.TimeSum := ProgressInfos.TimeDone / ProgressInfos.RecordsDone * ProgressInfos.RecordsSum;
    end
    else
    begin
      ProgressInfos.Progress := 100;
      ProgressInfos.TimeSum := ProgressInfos.TimeDone;
    end;

    CriticalSection.Leave();

    OnUpdate(ProgressInfos);
  end;
end;

function TTExport.EmptyToolsItem(): TTools.TItem;
begin
  Result.Client := Client;
  Result.DatabaseName := '';
  Result.TableName := '';
end;

procedure TTExport.Execute();
var
  DataHandle: TMySQLConnection.TDataResult;
  FieldNames: string;
  I: Integer;
  Index: Integer;
  J: Integer;
  SQL: string;
  Table: TCTable;
begin
  if (not Data or (Length(ExportObjects) = 0)) then
    DataTables := nil
  else
    DataTables := TList.Create();

  BeforeExecute();

  for I := 0 to Length(DBGrids) - 1 do
  begin
    DBGrids[I].Done := False;

    DBGrids[I].RecordsSum := DBGrids[I].DBGrid.DataSource.DataSet.RecordCount;
    DBGrids[I].RecordsDone := 0;
  end;

  SQL := '';
  for I := 0 to Length(ExportObjects) - 1 do
  begin
    if (not (ExportObjects[I].DBObject is TCBaseTable)) then
      ExportObjects[I].RecordsSum := 0
    else
      ExportObjects[I].RecordsSum := TCBaseTable(ExportObjects[I].DBObject).Rows;
    ExportObjects[I].RecordsDone := 0;
    ExportObjects[I].Done := False;

    if (Data and (ExportObjects[I].DBObject is TCTable) and (not (ExportObjects[I].DBObject is TCBaseTable) or not TCBaseTable(ExportObjects[I].DBObject).Engine.IsMerge)) then
      DataTables.Add(ExportObjects[I].DBObject);
  end;

  if ((Success <> daAbort) and Assigned(DataTables) and (DataTables.Count > 0)) then
  begin
    Success := daSuccess;

    for I := 0 to DataTables.Count - 1 do
    begin
      Table := TCTable(DataTables[I]);

      if (Length(TableFields) = 0) then
        FieldNames := '*'
      else
      begin
        FieldNames := '';
        for J := 0 to Length(TableFields) - 1 do
        begin
          if (FieldNames <> '') then FieldNames := FieldNames + ',';
          FieldNames := FieldNames + Client.EscapeIdentifier(TableFields[J].Name);
        end;
      end;

      SQL := SQL + 'SELECT ' + FieldNames + ' FROM ' + Client.EscapeIdentifier(Table.Database.Name) + '.' + Client.EscapeIdentifier(Table.Name);
      if ((Table is TCBaseTable) and Assigned(TCBaseTable(Table).PrimaryKey)) then
      begin
        SQL := SQL + ' ORDER BY ';
        for J := 0 to TCBaseTable(Table).PrimaryKey.Columns.Count - 1 do
        begin
          if (J > 0) then SQL := SQL + ',';
          SQL := SQL + Client.EscapeIdentifier(TCBaseTable(Table).PrimaryKey.Columns[J].Field.Name);
        end;
      end;
      SQL := SQL + ';' + #13#10;
    end;
  end;

  if (Success <> daAbort) then
  begin
    Success := daSuccess;
    ExecuteHeader();

    if (Success = daSuccess) then
      for I := 0 to Length(DBGrids) - 1 do
        if (Success <> daAbort) then
        begin
          Success := daSuccess;

          ExecuteDBGrid(DBGrids[I]);

          DBGrids[I].Done := True;

          if (Success = daFail) then Success := daSuccess;
        end;

    if (Success = daSuccess) then
      for I := 0 to Length(ExportObjects) - 1 do
      begin
        if ((Success <> daAbort) and Data) then
        begin
          Index := DataTables.IndexOf(ExportObjects[I].DBObject);
          if (Index >= 0) then
            if (Index = 0) then
              while ((Success = daSuccess) and not Client.FirstResult(DataHandle, SQL)) do
                DoError(DatabaseError(Client), EmptyToolsItem(), True, SQL)
            else
              if ((Success = daSuccess) and not Client.NextResult(DataHandle)) then
                DoError(DatabaseError(Client), EmptyToolsItem(), False);
        end;

        if ((Success <> daAbort) and ((I = 0) or (ExportObjects[I - 1].DBObject.Database <> ExportObjects[I].DBObject.Database))) then
        begin
          Success := daSuccess;
          ExecuteDatabaseHeader(ExportObjects[I].DBObject.Database);
        end;

        if (Success <> daAbort) then
        begin
          Success := daSuccess;

          if (ExportObjects[I].DBObject is TCTable) then
            ExecuteTable(ExportObjects[I], DataHandle)
          else if (ExportObjects[I].DBObject is TCRoutine) then
            ExecuteRoutine(TCRoutine(ExportObjects[I].DBObject))
          else if (ExportObjects[I].DBObject is TCEvent) then
            ExecuteEvent(TCEvent(ExportObjects[I].DBObject))
          else if (ExportObjects[I].DBObject is TCTrigger) then
            ExecuteTrigger(TCTrigger(ExportObjects[I].DBObject));

          if (Success = daFail) then Success := daSuccess;
        end;

        ExportObjects[I].Done := True;

        if (((I = Length(ExportObjects) - 1) or (ExportObjects[I + 1].DBObject.Database <> ExportObjects[I].DBObject.Database))) then
        begin
          if (Success <> daAbort) then
            Success := daSuccess;
          ExecuteDatabaseFooter(ExportObjects[I].DBObject.Database);
        end;
      end;

    if (Success <> daAbort) then
      Success := daSuccess;
    ExecuteFooter();
  end;

  AfterExecute();

  if (Data and (Length(ExportObjects) > 0)) then
  begin
    Client.CloseResult(DataHandle);
    DataTables.Free();
  end;
end;

procedure TTExport.ExecuteDatabaseFooter(const Database: TCDatabase);
begin
end;

procedure TTExport.ExecuteDatabaseHeader(const Database: TCDatabase);
begin
end;

procedure TTExport.ExecuteDBGrid(var ExportDBGrid: TExportDBGrid);
var
  Database: TCDatabase;
  DataSet: TMySQLDataSet;
  Index: Integer;
  OldBookmark: TBookmark;
  OldLoadNextRecords: Boolean;
  Table: TCTable;
begin
  DataSet := TMySQLDataSet(ExportDBGrid.DBGrid.DataSource.DataSet);
  if (ExportDBGrid.DBGrid.DataSource.DataSet is TMySQLTable) then
  begin
    Database := Client.DatabaseByName(TMySQLTable(DataSet).DatabaseName);
    Table := Database.BaseTableByName(TMySQLTable(DataSet).TableName);
  end
  else
  begin
    Database := Client.DatabaseByName(DataSet.DatabaseName);
    if (not Assigned(Database)) then
      Table := nil
    else
      Table := Database.TableByName(DataSet.TableName);
  end;

  if (not (DataSet is TMySQLTable)) then
    OldLoadNextRecords := False // hide compiler warning
  else
  begin
    OldLoadNextRecords := TMySQLTable(DataSet).AutomaticLoadNextRecords;
    TMySQLTable(DataSet).AutomaticLoadNextRecords := False;
  end;
  OldBookmark := DataSet.Bookmark;

  if (DataSet.FindFirst()) then
  begin
    if (Success <> daAbort) then
    begin
      Success := daSuccess;
      ExecuteDatabaseHeader(Database);
      ExecuteTableHeader(Table, Fields, DataSet);
    end;

    Index := 0;
    if (Success <> daAbort) then
      repeat
        if (ExportDBGrid.DBGrid.SelectedRows.Count > Index) then
        begin
          DataSet.Bookmark := ExportDBGrid.DBGrid.SelectedRows[Index];
          Inc(Index);
        end;

        ExecuteTableRecord(Table, Fields, DataSet);

        Inc(ExportDBGrid.RecordsDone);
        if (ExportDBGrid.RecordsDone mod 100 = 0) then DoUpdateGUI();

        if (UserAbort.WaitFor(IGNORE) = wrSignaled) then
          Success := daAbort;
      until ((Success <> daSuccess) or ((ExportDBGrid.DBGrid.SelectedRows.Count < 1) and not DataSet.FindNext()) or (ExportDBGrid.DBGrid.SelectedRows.Count >= 1) and (Index = ExportDBGrid.DBGrid.SelectedRows.Count));

    if (Success <> daAbort) then
    begin
      Success := daSuccess;
      ExecuteTableFooter(Table, Fields, DataSet);
      ExecuteDatabaseFooter(Database);
    end;
  end;

  DataSet.Bookmark := OldBookmark;
  if (DataSet is TMySQLTable) then
    TMySQLTable(DataSet).AutomaticLoadNextRecords := OldLoadNextRecords;

  if (Success = daSuccess) then
    ExportDBGrid.RecordsSum := ExportDBGrid.RecordsDone;
end;

procedure TTExport.ExecuteEvent(const Event: TCEvent);
begin
end;

procedure TTExport.ExecuteFooter();
begin
end;

procedure TTExport.ExecuteHeader();
begin
end;

procedure TTExport.ExecuteRoutine(const Routine: TCRoutine);
begin
end;

procedure TTExport.ExecuteTable(var ExportObject: TExportObject; const DataHandle: TMySQLConnection.TDataResult);
var
  DataSet: TMySQLQuery;
  Fields: array of TField;
  I: Integer;
  SQL: string;
  Table: TCTable;
begin
  Table := TCTable(ExportObject.DBObject);

  if (not Data or (Table is TCBaseTable) and TCBaseTable(Table).Engine.IsMerge) then
    DataSet := nil
  else
  begin
    DataSet := TMySQLQuery.Create(nil);
    while ((Success <> daAbort) and not DataSet.Active) do
    begin
      DataSet.Open(DataHandle);
      if (not DataSet.Active) then
        DoError(DatabaseError(Client), ToolsItem(ExportObject), False, SQL);
    end;
  end;

  if ((Success <> daSuccess) or not Data) then
    SetLength(Fields, 0)
  else
  begin
    SetLength(Fields, DataSet.FieldCount);
    for I := 0 to DataSet.FieldCount - 1 do
      Fields[I] := DataSet.Fields[I];
  end;

  if (Success <> daAbort) then
  begin
    Success := daSuccess;

    ExecuteTableHeader(Table, Fields, DataSet);

    if ((Success <> daAbort) and Data and ((Table is TCBaseTable) or (Table is TCView) and (Length(ExportObjects) = 1)) and Assigned(DataSet) and not DataSet.IsEmpty()) then
      repeat
        ExecuteTableRecord(Table, Fields, DataSet);

        Inc(ExportObject.RecordsDone);
        if ((ExportObject.RecordsDone mod 1000 = 0)
          or ((ExportObject.RecordsDone mod 100 = 0) and ((Self is TTExportSQLite) or (Self is TTExportODBC)))) then
          DoUpdateGUI();

        if (UserAbort.WaitFor(IGNORE) = wrSignaled) then
          Success := daAbort;
      until ((Success <> daSuccess) or not DataSet.FindNext());

    if (Success <> daAbort) then
      Success := daSuccess;
    ExecuteTableFooter(Table, Fields, DataSet);
  end;

  if (Success = daSuccess) then
    ExportObject.RecordsSum := ExportObject.RecordsDone;

  if (Assigned(DataSet) and (Success <> daAbort)) then
    DataSet.Free();
end;

procedure TTExport.ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
begin
end;

procedure TTExport.ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
begin
end;

procedure TTExport.ExecuteTrigger(const Trigger: TCTrigger);
begin
end;

function TTExport.ToolsItem(const ExportDBGrid: TExportDBGrid): TTools.TItem;
begin
  Result.Client := Client;
  Result.DatabaseName := '';
  Result.TableName := '';
end;

function TTExport.ToolsItem(const ExportObject: TExportObject): TTools.TItem;
begin
  Result.Client := Client;
  Result.DatabaseName := ExportObject.DBObject.Database.Name;
  Result.TableName := ExportObject.DBObject.Name;
end;

{ TTExportFile ****************************************************************}

procedure TTExportFile.CloseFile();
begin
  if (Handle <> INVALID_HANDLE_VALUE) then
  begin
    Flush();

    CloseHandle(Handle);
    Handle := INVALID_HANDLE_VALUE;
  end;
end;

constructor TTExportFile.Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal);
begin
  inherited Create(AClient);

  ContentBuffer := TStringBuffer.Create(FilePacketSize);
  FCodePage := ACodePage;
  if (CodePage = CP_UNICODE) then
  begin
    FileBuffer.Size := 0;
    FileBuffer.Mem := nil;
  end
  else
  begin
    FileBuffer.Size := FilePacketSize;
    GetMem(FileBuffer.Mem, FileBuffer.Size);
  end;
  FFilename := AFilename;
  Handle := INVALID_HANDLE_VALUE;
end;

destructor TTExportFile.Destroy();
begin
  CloseFile();
  if (Assigned(FileBuffer.Mem)) then
    FreeMem(FileBuffer.Mem);
  ContentBuffer.Free();

  inherited;

  if (Success = daAbort) then
    DeleteFile(FFilename);
end;

procedure TTExportFile.DoFileCreate(const Filename: TFileName);
var
  Error: TTools.TError;
begin
  while ((Success <> daAbort) and not FileCreate(Filename, Error)) do
    DoError(Error, EmptyToolsItem(), True);
end;

function TTExportFile.FileCreate(const Filename: TFileName; out Error: TTools.TError): Boolean;
var
  Attributes: DWord;
begin
  if ((Self is TTExportText) and Assigned(TTExportText(Self).Zip)) then
    Attributes := FILE_ATTRIBUTE_TEMPORARY
  else
    Attributes := FILE_ATTRIBUTE_NORMAL;

  Handle := CreateFile(PChar(Filename),
                       GENERIC_WRITE,
                       FILE_SHARE_READ,
                       nil,
                       CREATE_ALWAYS, Attributes, 0);
  Result := Handle <> INVALID_HANDLE_VALUE;

  if (not Result) then
    Error := SysError();
end;

procedure TTExportFile.Flush();
var
  Buffer: PAnsiChar;
  BytesToWrite: DWord;
  BytesWritten: DWord;
  Size: DWord;
begin
  case (CodePage) of
    CP_UNICODE:
      begin
        Buffer := ContentBuffer.Data;
        BytesToWrite := ContentBuffer.Size;
      end;
    else
      begin
        BytesToWrite := WideCharToAnsiChar(CodePage, PChar(ContentBuffer.Data), ContentBuffer.Size div SizeOf(Char), nil, 0);
        if (BytesToWrite > FileBuffer.Size) then
        begin
          FileBuffer.Size := BytesToWrite;
          ReallocMem(FileBuffer.Mem, FileBuffer.Size);
        end;
        Buffer := FileBuffer.Mem;
        WideCharToAnsiChar(CodePage, PChar(ContentBuffer.Data), ContentBuffer.Size div SizeOf(Char), Buffer, BytesToWrite);
      end;
  end;

  BytesWritten := 0;
  while ((Success = daSuccess) and (BytesWritten < BytesToWrite)) do
    if (not WriteFile(Handle, Buffer[BytesWritten], BytesToWrite - BytesWritten, Size, nil)) then
      DoError(SysError(), EmptyToolsItem(), False)
    else
      Inc(BytesWritten, Size);

  ContentBuffer.Clear();
end;

procedure TTExportFile.WriteContent(const Content: string);
begin
  if (Content <> '') then
  begin
    if ((ContentBuffer.Size > 0) and (ContentBuffer.Size + Length(Content) * SizeOf(Content[1]) > FilePacketSize)) then
      Flush();

    ContentBuffer.Write(Content);
  end;
end;

{ TTExportSQL *****************************************************************}

constructor TTExportSQL.Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal);
begin
  inherited;

  CreateDatabaseStmts := False;
  DisableKeys := False;
  ForeignKeySources := '';
  IncludeDropStmts := False;
  UseDatabaseStmts := True;
end;

procedure TTExportSQL.ExecuteDatabaseFooter(const Database: TCDatabase);
begin
  if (ForeignKeySources <> '') then
    WriteContent(ForeignKeySources + #13#10);
end;

procedure TTExportSQL.ExecuteDatabaseHeader(const Database: TCDatabase);
var
  Content: string;
begin
  if (Assigned(Database)) then
  begin
    Content := '';

    if (UseDatabaseStmts or CreateDatabaseStmts) then
    begin
      Content := Content + #13#10;

      if (CreateDatabaseStmts) then
        Content := Content + Database.GetSourceEx(IncludeDropStmts) + #13#10;

      Content := Content + Database.SQLUse();
    end;

    WriteContent(Content);
  end;
end;

procedure TTExportSQL.ExecuteEvent(const Event: TCEvent);
var
  Content: string;
begin
  Content := #13#10;
  Content := Content + '#' + #13#10;
  Content := Content + '# Source for event "' + Event.Name + '"' + #13#10;
  Content := Content + '#' + #13#10;
  Content := Content + #13#10;
  Content := Content + ReplaceStr(Event.Source, Client.EscapeIdentifier(Event.Database.Name) + '.', '') + #13#10;

  WriteContent(Content);
end;

procedure TTExportSQL.ExecuteFooter();
var
  Content: string;
begin
  Content := '';

  if (DisableKeys and (Client.ServerVersion >= 40014)) then
  begin
    Content := Content + '/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;' + #13#10;
    Content := Content + '/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;' + #13#10;
  end;
  if (Assigned(Client.VariableByName('SQL_NOTES')) and (Client.ServerVersion >= 40111)) then
    Content := Content + '/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;' + #13#10;
  if (Assigned(Client.VariableByName('SQL_MODE')) and (Client.ServerVersion >= 40101)) then
    Content := Content + '/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;' + #13#10;
  if (Assigned(Client.VariableByName('TIME_ZONE')) and (Client.VariableByName('TIME_ZONE').Value <> 'SYSTEM') and (Client.ServerVersion >= 40103)) then
    Content := Content + '/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;' + #13#10;
  if ((CodePage <> CP_UNICODE) and (Client.CodePageToCharset(CodePage) <> '') and (Client.ServerVersion >= 40101)) then
  begin
    Content := Content + '/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;' + #13#10;
    Content := Content + '/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;' + #13#10;
    Content := Content + '/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;' + #13#10;
  end;

  WriteContent(#13#10 + Content);
end;

procedure TTExportSQL.ExecuteHeader();
var
  Content: string;
begin
  DoFileCreate(Filename);

  Content := Content + '# Host: ' + Client.Host;
  if (Client.Port <> MYSQL_PORT) then
    Content := Content + ':' + IntToStr(Client.Port);
  Content := Content + '  (Version: ' + Client.ServerVersionStr + ')' + #13#10;
  Content := Content + '# Date: ' + MySQLDB.DateTimeToStr(Now(), Client.FormatSettings) + #13#10;
  Content := Content + '# Generator: ' + LoadStr(1000) + ' ' + Preferences.VersionStr + #13#10;
  Content := Content + #13#10;

  if ((CodePage <> CP_UNICODE) and (Client.CodePageToCharset(CodePage) <> '') and (Client.ServerVersion >= 40101)) then
  begin
    Content := Content + '/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;' + #13#10;
    Content := Content + '/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;' + #13#10;
    Content := Content + '/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;' + #13#10;
    Content := Content + '/*!40101 SET NAMES ' + Client.CodePageToCharset(CodePage) + ' */;' + #13#10;
  end;
  if (Assigned(Client.VariableByName('TIME_ZONE')) and (Client.VariableByName('TIME_ZONE').Value <> 'SYSTEM')) then
  begin
    Content := Content + '/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;' + #13#10;
    Content := Content + '/*!40103 SET TIME_ZONE=' + SQLEscape(Client.VariableByName('TIME_ZONE').Value) + ' */;' + #13#10;
  end;
  if (Assigned(Client.VariableByName('SQL_MODE')) and (Client.ServerVersion >= 40101)) then
  begin
    Content := Content + '/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE */;' + #13#10;
    Content := Content + '/*!40101 SET SQL_MODE=' + SQLEscape(Client.VariableByName('SQL_MODE').Value) + ' */;' + #13#10;
  end;
  if (Assigned(Client.VariableByName('SQL_NOTES'))) then
  begin
    Content := Content + '/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES */;' + #13#10;
    Content := Content + '/*!40103 SET SQL_NOTES=' + SQLEscape(Client.VariableByName('SQL_NOTES').Value) + ' */;' + #13#10;
  end;
  if (DisableKeys and (Client.ServerVersion >= 40014)) then
  begin
    Content := Content + '/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS */;' + #13#10;
    Content := Content + '/*!40014 SET UNIQUE_CHECKS=0 */;' + #13#10;
    Content := Content + '/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS */;' + #13#10;
    Content := Content + '/*!40014 SET FOREIGN_KEY_CHECKS=0 */;' + #13#10;
  end;

  WriteContent(Content);
end;

procedure TTExportSQL.ExecuteRoutine(const Routine: TCRoutine);
var
  Content: string;
begin
  Content := #13#10;
  if (Routine is TCProcedure) then
  begin
    Content := Content + '#' + #13#10;
    Content := Content + '# Source for procedure "' + Routine.Name + '"' + #13#10;
    Content := Content + '#' + #13#10;
  end
  else if (Routine is TCFunction) then
  begin
    Content := Content + '#' + #13#10;
    Content := Content + '# Source for function "' + Routine.Name + '"' + #13#10;
    Content := Content + '#' + #13#10;
  end;
  Content := Content + #13#10;
  Content := Content + Routine.GetSourceEx(IncludeDropStmts) + #13#10;

  WriteContent(Content);
end;

procedure TTExportSQL.ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  Content: string;
begin
  if (SQLInsertPacketLen > 0) then
  begin
    WriteContent(SQLInsertPostfix);
    SQLInsertPacketLen := 0;
  end;

  if (Assigned(Table) and Data) then
  begin
    Content := '';

    if (DisableKeys and (Table is TCBaseTable) and TCBaseTable(Table).Engine.IsMyISAM) then
      Content := Content + '/*!40000 ALTER TABLE ' + Client.EscapeIdentifier(Table.Name) + ' ENABLE KEYS */;' + #13#10;

    if (Content <> '') then
      WriteContent(Content);
  end;
end;

procedure TTExportSQL.ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  Content: string;
  ForeignKeySource: string;
  I: Integer;
begin
  Content := '';

  if (Structure and Assigned(Table)) then
  begin
    if (Table is TCBaseTable) then
    begin
      Content := Content + #13#10;
      Content := Content + '#' + #13#10;
      Content := Content + '# Source for table "' + Table.Name + '"' + #13#10;
      Content := Content + '#' + #13#10;
    end
    else if (Table is TCView) then
    begin
      Content := Content + #13#10;
      Content := Content + '#' + #13#10;
      Content := Content + '# Source for view "' + Table.Name + '"' + #13#10;
      Content := Content + '#' + #13#10;
    end;
    Content := Content + '' + #13#10;

    if (Table is TCBaseTable) then
    begin
      Content := Content + Table.GetSourceEx(IncludeDropStmts, False, @ForeignKeySource) + #13#10;

      if (ForeignKeySource <> '') then
      begin
        ForeignKeySources := ForeignKeySources + #13#10;
        ForeignKeySources := ForeignKeySources + '#' + #13#10;
        ForeignKeySources := ForeignKeySources + '#  Foreign keys for table ' + Table.Name + #13#10;
        ForeignKeySources := ForeignKeySources + '#' + #13#10;
        ForeignKeySources := ForeignKeySources + #13#10;
        ForeignKeySources := ForeignKeySources + ForeignKeySource + #13#10;
      end;
    end
    else if (Table is TCView) then
      Content := Content + Table.GetSourceEx(IncludeDropStmts, False) + #13#10;
  end;

  if (Assigned(Table) and Data) then
  begin
    if (Data) then
    begin
      Content := Content + #13#10;
      Content := Content + '#' + #13#10;
      Content := Content + '# Data for table "' + Table.Name + '"' + #13#10;
      Content := Content + '#' + #13#10;
    end;

    Content := Content + #13#10;

    if (DisableKeys and (Table is TCBaseTable) and TCBaseTable(Table).Engine.IsMyISAM) then
      Content := Content + '/*!40000 ALTER TABLE ' + Client.EscapeIdentifier(Table.Name) + ' DISABLE KEYS */;' + #13#10;
  end;

  if (Content <> '') then
    WriteContent(Content);


  if (Data) then
  begin
    if (ReplaceData) then
      SQLInsertPrefix := 'REPLACE INTO '
    else
      SQLInsertPrefix := 'INSERT INTO ';

    SQLInsertPrefix := SQLInsertPrefix + Client.EscapeIdentifier(Table.Name);

    if (not Structure and Data and Assigned(Table)) then
    begin
      SQLInsertPrefix := SQLInsertPrefix + ' (';
      for I := 0 to Length(Fields) - 1 do
      begin
        if (I > 0) then SQLInsertPrefix := SQLInsertPrefix + ',';
        SQLInsertPrefix := SQLInsertPrefix + Client.EscapeIdentifier(Fields[I].FieldName);
      end;
      SQLInsertPrefix := SQLInsertPrefix + ')';
    end;

    SQLInsertPrefix := SQLInsertPrefix + ' VALUES ';
    SQLInsertPrefixPacketLen := SizeOf(COM_QUERY) + WideCharToAnsiChar(Client.CodePage, PChar(SQLInsertPrefix), Length(SQLInsertPrefix), nil, 0);

    SQLInsertPostfix := ';' + #13#10;
    SQLInsertPrefixPacketLen := WideCharToAnsiChar(Client.CodePage, PChar(SQLInsertPostfix), Length(SQLInsertPostfix), nil, 0);

    SQLInsertPacketLen := 0;
  end;
end;

procedure TTExportSQL.ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  I: Integer;
  Values: string;
  ValuesPacketLen: Integer;
begin
  Values := '(';
  for I := 0 to Length(Fields) - 1 do
  begin
    if (I > 0) then Values := Values + ',';
    Values := Values + DataSet.SQLFieldValue(Fields[I]);
  end;
  Values := Values + ')';

  ValuesPacketLen := WideCharToAnsiChar(Client.CodePage, PChar(Values), Length(Values), nil, 0);

  if ((SQLInsertPacketLen > 0) and (SQLInsertPacketLen + ValuesPacketLen + SQLInsertPostfixPacketLen >= SQLPacketSize)) then
  begin
    WriteContent(SQLInsertPostfix);
    SQLInsertPacketLen := 0;
  end;

  if (SQLInsertPacketLen = 0) then
  begin
    WriteContent(SQLInsertPrefix);
    Inc(SQLInsertPacketLen, SQLInsertPrefixPacketLen);
  end
  else
  begin
    WriteContent(',');
    Inc(SQLInsertPacketLen, 1);
  end;

  WriteContent(Values);
  Inc(SQLInsertPacketLen, ValuesPacketLen);
end;

procedure TTExportSQL.ExecuteTrigger(const Trigger: TCTrigger);
var
  Content: string;
begin
  Content := #13#10;
  Content := Content + '#' + #13#10;
  Content := Content + '# Source for trigger "' + Trigger.Name + '"' + #13#10;
  Content := Content + '#' + #13#10;
  Content := Content + #13#10;
  Content := Content + Trigger.GetSourceEx(IncludeDropStmts) + #13#10;

  WriteContent(Content);
end;

function TTExportSQL.FileCreate(const Filename: TFileName; out Error: TTools.TError): Boolean;
var
  Size: DWord;
begin
  Result := inherited FileCreate(Filename, Error);

  if (Result) then
  begin
    case (CodePage) of
      CP_UTF8: Result := WriteFile(Handle, BOM_UTF8^, Length(BOM_UTF8), Size, nil) and (Integer(Size) = Length(BOM_UTF8));
      CP_UNICODE: Result := WriteFile(Handle, BOM_UNICODE^, Length(BOM_UNICODE), Size, nil) and (Integer(Size) = Length(BOM_UNICODE));
    end;

    if (not Result) then
      Error := SysError();
  end;
end;

{ TTExportText ****************************************************************}

procedure TTExportText.AfterExecute();
begin
  if (Assigned(Zip)) then
    Zip.Free();

  inherited;
end;

procedure TTExportText.BeforeExecute();
begin
  inherited;

  if (Length(ExportObjects) + Length(DBGrids) > 1) then
  begin
    Zip := TZipFile.Create();

    while ((Success <> daAbort) and (Zip.Mode <> zmWrite)) do
      try
        Zip.Open(Filename, zmWrite);
      except
        on E: EZipException do
          DoError(ZipError(Zip, E.Message), EmptyToolsItem(), True);
      end;
  end;
end;

constructor TTExportText.Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal);
begin
  inherited;

  Delimiter := ',';
  Quoter := '"';
  QuoteStringValues := True;
  QuoteValues := False;
  Zip := nil;
end;

destructor TTExportText.Destroy();
begin
  SetLength(DestinationFields, 0);
  SetLength(Fields, 0);
  SetLength(TableFields, 0);

  inherited;
end;

procedure TTExportText.ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
begin
  CloseFile();

  if (Length(ExportObjects) + Length(DBGrids) > 1) then
  begin
    if (Success = daSuccess) then
      try
        Zip.Add(TempFilename, Table.Name + '.csv');
      except
        on E: EZipException do
          DoError(ZipError(Zip, E.Message), EmptyToolsItem(), False);
      end;
    DeleteFile(TempFilename);
  end;
end;

procedure TTExportText.ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  Content: string;
  I: Integer;
  Value: string;
begin
  if (Length(ExportObjects) + Length(DBGrids) = 1) then
    DoFileCreate(Filename)
  else
  begin
    TempFilename := GetTempFileName();
    DoFileCreate(TempFilename);
  end;

  if ((Success = daSuccess) and Structure) then
  begin
    Content := '';

    for I := 0 to Length(Fields) - 1 do
    begin
      if (I > 0) then Content := Content + Delimiter;

      if (not Assigned(Table)) then
        Value := Fields[I].DisplayName
      else if (Length(DestinationFields) > 0) then
        Value := DestinationFields[I].Name
      else
        Value := Table.Fields[I].Name;

      if (QuoteValues or QuoteStringValues) then
        Content := Content + Quoter + Value + Quoter
      else
        Content := Content + Value;
    end;

    WriteContent(Content + #13#10);
  end;
end;

procedure TTExportText.ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  Content: string;
  I: Integer;
begin
  Content := '';
  for I := 0 to Length(Fields) - 1 do
  begin
    if (I > 0) then Content := Content + Delimiter;
    if (not Assigned(DataSet.LibRow^[Fields[I].FieldNo - 1])) then
      // NULL values are empty in MS Text files
    else if (BitField(Fields[I])) then
      Content := Content + CSVEscape(UInt64ToStr(Fields[I].AsLargeInt), Quoter, QuoteValues)
    else if (Fields[I].DataType in BinaryDataTypes) then
      Content := Content + CSVEscape(DataSet.LibRow^[Fields[I].FieldNo - 1], DataSet.LibLengths^[Fields[I].FieldNo - 1], Quoter, QuoteStringValues)
    else
      Content := Content + CSVEscape(DataSet.GetAsString(Fields[I].FieldNo), Quoter, ((Fields[I].DataType in NotQuotedDataTypes)) and QuoteValues or not (Fields[I].DataType in NotQuotedDataTypes) and QuoteStringValues);
  end;
  WriteContent(Content + #13#10);
end;

function TTExportText.FileCreate(const Filename: TFileName; out Error: TTools.TError): Boolean;
var
  Size: DWord;
begin
  Result := inherited FileCreate(Filename, Error);

  if (Result) then
  begin
    case (CodePage) of
      CP_UTF8: Result := WriteFile(Handle, BOM_UTF8^, Length(BOM_UTF8), Size, nil) and (Integer(Size) = Length(BOM_UTF8));
      CP_UNICODE: Result := WriteFile(Handle, BOM_UNICODE^, Length(BOM_UNICODE), Size, nil) and (Integer(Size) = Length(BOM_UNICODE));
    end;

    if (not Result) then
      Error := SysError();
  end;
end;

{ TTExportUML *****************************************************************}

procedure TTExportUML.ExecuteHeader();
begin
  DoFileCreate(Filename);
end;

{ TTExportHTML ****************************************************************}

constructor TTExportHTML.Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal);
begin
  inherited;

  TextContent := False;
  NULLText := True;
  RowBackground := True;

  Font := TFont.Create();
  Font.Name := Preferences.GridFontName;
  Font.Style := Preferences.GridFontStyle;
  Font.Charset := Preferences.GridFontCharset;
  Font.Color := Preferences.GridFontColor;
  Font.Size := Preferences.GridFontSize;

  SQLFont := TFont.Create();
  SQLFont.Name := Preferences.SQLFontName;
  SQLFont.Style := Preferences.SQLFontStyle;
  SQLFont.Charset := Preferences.SQLFontCharset;
  SQLFont.Color := Preferences.SQLFontColor;
  SQLFont.Size := Preferences.SQLFontSize;
end;

destructor TTExportHTML.Destroy();
begin
  Font.Free();
  SQLFont.Free();

  inherited;
end;

function TTExportHTML.Escape(const Str: string): string;
label
  StartL,
  StringL, String2,
  PositionL, PositionE,
  MoveReplaceL, MoveReplaceE,
  FindPos, FindPos2,
  Finish;
const
  SearchLen = 6;
  Search: array [0 .. SearchLen - 1] of Char = (#0, #10, #13, '"', '<', '>');
  Replace: array [0 .. SearchLen - 1] of PChar = ('', '<br>' + #13#10, '', '&quot;', '&lt;', '&gt;');
var
  Len: Integer;
  Positions: packed array [0 .. SearchLen - 1] of Cardinal;
begin
  Len := Length(Str);

  if (Len = 0) then
    Result := ''
  else
  begin
    SetLength(Result, 6 * Len); // reserve space

    asm
        PUSH ES
        PUSH ESI
        PUSH EDI
        PUSH EBX

        PUSH DS                          // string operations uses ES
        POP ES
        CLD                              // string operations uses forward direction

        MOV ESI,PChar(Str)               // Copy characters from Str
        MOV EAX,Result                   //   to Result
        MOV EDI,[EAX]
        MOV ECX,Len                      // Length of Str string

      // -------------------

        MOV EBX,0                        // Numbers of characters in Search
      StartL:
        CALL FindPos                     // Find Search character position
        INC EBX                          // Next character in Search
        CMP EBX,SearchLen                // All Search characters handled?
        JNE StartL                       // No!

      // -------------------

      StringL:
        PUSH ECX

        MOV ECX,0                        // Numbers of characters in Search
        MOV EBX,-1                       // Index of first position
        MOV EAX,0                        // Last character
        LEA EDX,Positions
      PositionL:
        CMP [EDX + ECX * 4],EAX          // Position before other positions?
        JB PositionE                     // No!
        MOV EBX,ECX                      // Index of first position
        MOV EAX,[EDX + EBX * 4]          // Value of first position
      PositionE:
        INC ECX                          // Next Position
        CMP ECX,SearchLen                // All Positions compared?
        JNE PositionL                    // No!

        POP ECX

        SUB ECX,EAX                      // Copy normal characters from Str
        CMP ECX,0                        // Is there something to copy?
        JE String2                       // No!
        REPNE MOVSW                      //   to Result

        MOV ECX,EAX

      String2:
        CMP ECX,0                        // Is there an character to replace?
        JE Finish                        // No!

        ADD ESI,2                        // Step of Search character

        PUSH ESI
        LEA EDX,Replace                  // Insert Replace string
        MOV ESI,[EDX + EBX * 4]
      MoveReplaceL:
        LODSW                            // Get Replace character
        CMP AX,0                         // End of Replace?
        JE MoveReplaceE                  // Yes!
        STOSW                            // Put character in Result
        JMP MoveReplaceL
      MoveReplaceE:
        POP ESI

        DEC ECX                          // Ignore Search character
        JZ Finish                        // All character in Value handled!

        CALL FindPos                     // Find Search character
        JMP StringL

      // -------------------

      FindPos:
        PUSH ECX
        PUSH EDI
        LEA EDI,Search                   // Character to Search
        MOV AX,[EDI + EBX * 2]
        MOV EDI,ESI                      // Search in Value
        REPNE SCASW                      // Find Search character
        JNE FindPos2                     // Search character not found!
        INC ECX
      FindPos2:
        LEA EDI,Positions
        MOV [EDI + EBX * 4],ECX          // Store found position
        POP EDI
        POP ECX
        RET

      // -------------------

      Finish:
        MOV EAX,Result                   // Calculate new length of Result
        MOV EAX,[EAX]
        SUB EDI,EAX
        SHR EDI,1                        // 2 Bytes = 1 character
        MOV Len,EDI

        POP EBX
        POP EDI
        POP ESI
        POP ES
    end;

    SetLength(Result, Len);
  end;
end;

procedure TTExportHTML.ExecuteDatabaseHeader(const Database: TCDatabase);
begin
  if (Assigned(Database)) then
    WriteContent('<h1 class="DatabaseTitle">' + ReplaceStr(Preferences.LoadStr(38), '&', '') + ': ' + Escape(Database.Name) + '</h1>' + #13#10);
end;

procedure TTExportHTML.ExecuteFooter();
var
  Content: string;
begin
  Content := '';
  Content := Content + '</body>' + #13#10;
  Content := Content + '</html>' + #13#10;

  WriteContent(Content);

  inherited;
end;

procedure TTExportHTML.ExecuteHeader();
var
  Content: string;
  Title: string;
begin
  inherited;

  Title := ExtractFileName(Filename);
  if (Pos('.', Title) > 0) then
  begin
    while (Title[Length(Title)] <> '.') do Delete(Title, Length(Title), 1);
    Delete(Title, Length(Title), 1);
  end;

  Content := '';
  Content := Content + '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"' + #13#10;
  Content := Content + ' "http://www.w3.org/TR/html4/strict.dtd">' + #13#10;
  Content := Content + '<html>' + #13#10;
  Content := Content + '<head>' + #13#10;
  Content := Content + #9 + '<title>' + Escape(Title) + '</title>' + #13#10;
  if (UMLEncoding(CodePage) <> '') then
    Content := Content + #9 + '<meta http-equiv="Content-Type" content="text/html; charset=' + UMLEncoding(CodePage) + '">' + #13#10;
  Content := Content + #9 + '<meta name="date" content="' + GetUTCDateTime(Now()) + '">' + #13#10;
  Content := Content + #9 + '<meta name="generator" content="' + LoadStr(1000) + ' ' + Preferences.VersionStr + '">' + #13#10;
  Content := Content + #9 + '<style type="text/css"><!--' + #13#10;
  Content := Content + #9#9 + 'body {font-family: Arial,Helvetica,sans-serif; font-size: ' + IntToStr(-Font.Height) + 'px;}' + #13#10;
  Content := Content + #9#9 + 'h1 {font-size: ' + IntToStr(-Font.Height + 6) + 'px; text-decoration: bold;}' + #13#10;
  Content := Content + #9#9 + 'h2 {font-size: ' + IntToStr(-Font.Height + 4) + 'px; text-decoration: bold;}' + #13#10;
  Content := Content + #9#9 + 'h3 {font-size: ' + IntToStr(-Font.Height + 2) + 'px; text-decoration: bold;}' + #13#10;
  Content := Content + #9#9 + 'th,' + #13#10;
  Content := Content + #9#9 + 'td {font-size: ' + IntToStr(-Font.Height) + 'px; border-style: solid; border-width: 1px; padding: 1px; font-weight: normal;}' + #13#10;
  Content := Content + #9#9 + 'code {font-size: ' + IntToStr(-SQLFont.Height) + 'px; white-space: pre;}' + #13#10;
  Content := Content + #9#9 + '.TableObject {border-collapse: collapse; border-color: #000000; font-family: ' + Escape(Font.Name) + '}' + #13#10;
  Content := Content + #9#9 + '.TableData {border-collapse: collapse; border-color: #000000; font-family: ' + Escape(Font.Name) + '}' + #13#10;
  Content := Content + #9#9 + '.TableHeader {border-color: #000000; text-decoration: bold; background-color: #e0e0e0;}' + #13#10;
  Content := Content + #9#9 + '.ObjectHeader {padding-left: 5px; text-align: left; border-color: #000000; text-decoration: bold;}' + #13#10;
  Content := Content + #9#9 + '.Object {text-align: left; border-color: #aaaaaa;}' + #13#10;
  Content := Content + #9#9 + '.odd {}' + #13#10;
  if (RowBackground) then
    Content := Content + #9#9 + '.even {background-color: #f0f0f0;}' + #13#10
  else
    Content := Content + #9#9 + '.even {}' + #13#10;
  Content := Content + #9#9 + '.DataHeader {padding-left: 5px; text-align: left; border-color: #000000; background-color: #e0e0e0;}' + #13#10;
  Content := Content + #9#9 + '.Data {border-color: #aaaaaa;}' + #13#10;
  Content := Content + #9#9 + '.DataNull {color: #999999; border-color: #aaaaaa;}' + #13#10;
  Content := Content + #9#9 + '.PrimaryKey {font-weight: bold;}' + #13#10;
  Content := Content + #9#9 + '.RightAlign {text-align: right;}' + #13#10;
  Content := Content + #9 + '--></style>' + #13#10;
  Content := Content + '</head>' + #13#10;
  Content := Content + '<body>' + #13#10;

  WriteContent(Content);
end;

procedure TTExportHTML.ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
begin
  if (Data) then
    WriteContent('</table><br style="page-break-after: always">' + #13#10);

  SetLength(CSS, 0);
  SetLength(FieldOfPrimaryIndex, 0);
end;

procedure TTExportHTML.ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  ClassAttr: string;
  Content: string;
  FieldInfo: TFieldInfo;
  I: Integer;
  J: Integer;
  S: string;
  S2: string;
begin
  Content := '';

  if (Table is TCBaseTable) then
  begin
    Content := '<h2 class="TableTitle">' + ReplaceStr(Preferences.LoadStr(302), '&', '') + ': ' + Escape(Table.Name) + '</h2>' + #13#10;
    if (TCBaseTable(Table).Comment <> '') then
      Content := Content + '<p>' + ReplaceStr(Preferences.LoadStr(111), '&', '') + ': ' + Escape(TCBaseTable(Table).Comment) + '</p>' + #13#10;
  end
  else if (Table is TCView) then
    Content := '<h2 class="TableTitle">' + ReplaceStr(Preferences.LoadStr(738), '&', '') + ': ' + Escape(Table.Name) + '</h2>' + #13#10
  else if (Structure) then
    Content := Content + '<h2 class="TableTitle">' + ReplaceStr(Preferences.LoadStr(216), '&', '') + ':</h2>' + #13#10;

  if (Structure) then
    if (Length(DBGrids) > 0) then
    begin
      Content := Content + '<h2>' + ReplaceStr(Preferences.LoadStr(794), '&', '') + ':</h2>' + #13#10;
      Content := Content + '<code>' + DataSet.CommandText + '</code>' + #13#10;
    end
    else
    begin
      if ((Table is TCBaseTable) and (TCBaseTable(Table).Keys.Count > 0)) then
      begin
        Content := Content + '<h3>' + Preferences.LoadStr(458) + ':</h3>' + #13#10;

        Content := Content + '<table border="0" cellspacing="0" summary="' + Escape(Table.Name) + '" class="TableObject">' + #13#10;
        Content := Content + #9 + '<tr class="TableHeader ObjectHeader">';
        Content := Content + '<th>' + Escape(ReplaceStr(Preferences.LoadStr(35), '&', '')) + '</th>';
        Content := Content + '<th>' + Escape(Preferences.LoadStr(69)) + '</th>';
        Content := Content + '<th>' + Escape(ReplaceStr(Preferences.LoadStr(73), '&', '')) + '</th>';
        if (Client.ServerVersion >= 50503) then
          Content := Content + '<th>' + Escape(ReplaceStr(Preferences.LoadStr(111), '&', '')) + '</th>';
        Content := Content + '</tr>' + #13#10;
        for I := 0 to TCBaseTable(Table).Keys.Count - 1 do
        begin
          if (TCBaseTable(Table).Keys[I].Primary) then
            ClassAttr := ' class="PrimaryKey"'
          else
            ClassAttr := '';

          Content := Content + #9 + '<tr class="Object">';
          Content := Content + '<td ' + ClassAttr + '>' + Escape(TCBaseTable(Table).Keys[I].Caption) + '</td>';
          S := '';
          for J := 0 to TCBaseTable(Table).Keys[I].Columns.Count - 1 do
            begin
              if (S <> '') then S := S + ', ';
              S := S + TCBaseTable(Table).Keys[I].Columns[J].Field.Name;
            end;
          Content := Content + '<td>' + Escape(S) + '</td>';
          if (TCBaseTable(Table).Keys[I].Unique) then
            Content := Content + '<td>unique</td>'
          else if (TCBaseTable(Table).Keys[I].Fulltext) then
            Content := Content + '<td>fulltext</td>'
          else
            Content := Content + '<td>&nbsp;</td>';
          if (Client.ServerVersion >= 50503) then
            Content := Content + '<td>' + Escape(TCBaseTable(Table).Keys[I].Comment) + '</td>';
          Content := Content + '</tr>' + #13#10;
        end;
        Content := Content + '</table><br>' + #13#10;
      end;

      Content := Content + '<h3>' + Preferences.LoadStr(253) + ':</h3>' + #13#10;

      Content := Content + '<table border="0" cellspacing="0" summary="' + Escape(Table.Name) + '" class="TableObject">' + #13#10;
      Content := Content + #9 + '<tr class="TableHeader ObjectHeader">';
      Content := Content + '<th>' + Escape(ReplaceStr(Preferences.LoadStr(35), '&', '')) + '</th>';
      Content := Content + '<th>' + Escape(Preferences.LoadStr(69)) + '</th>';
      Content := Content + '<th>' + Escape(Preferences.LoadStr(71)) + '</th>';
      Content := Content + '<th>' + Escape(Preferences.LoadStr(72)) + '</th>';
      Content := Content + '<th>' + Escape(ReplaceStr(Preferences.LoadStr(73), '&', '')) + '</th>';
      if (Client.ServerVersion >= 40100) then
        Content := Content + '<th>' + Escape(ReplaceStr(Preferences.LoadStr(111), '&', '')) + '</th>';
      Content := Content + '</tr>' + #13#10;
      for I := 0 to Table.Fields.Count - 1 do
      begin
        if (Table.Fields[I].InPrimaryKey) then
          ClassAttr := ' class="PrimaryKey"'
        else
          ClassAttr := '';

        Content := Content + #9 + '<tr class="Object">';
        Content := Content + '<td' + ClassAttr + '>' + Escape(Table.Fields[I].Name) + '</td>';
        Content := Content + '<td>' + Escape(Table.Fields[I].DBTypeStr()) + '</td>';
        if (Table.Fields[I].NullAllowed) then
          Content := Content + '<td>' + Escape(Preferences.LoadStr(74)) + '</td>'
        else
          Content := Content + '<td>' + Escape(Preferences.LoadStr(75)) + '</td>';
        if (Table.Fields[I].AutoIncrement) then
          Content := Content + '<td>&lt;auto_increment&gt;</td>'
        else if (Table.Fields[I].Default = 'NULL') then
          Content := Content + '<td class="DataNull">&lt;' + Preferences.LoadStr(71) + '&gt;</td>'
        else if (Table.Fields[I].Default = 'CURRENT_TIMESTAMP') then
          Content := Content + '<td>&lt;INSERT-TimeStamp&gt;</td>'
        else if (Table.Fields[I].Default <> '') then
          Content := Content + '<td>' + Escape(Table.Fields[I].UnescapeValue(Table.Fields[I].Default)) + '</td>'
        else
          Content := Content + '<td>&nbsp;</td>';
        S := '';
        if ((Table is TCBaseTable) and (Table.Fields[I].FieldType in TextFieldTypes)) then
        begin
          if ((Table.Fields[I].Charset <> '') and (Table.Fields[I].Charset <> TCBaseTable(Table).DefaultCharset)) then
            S := S + Table.Fields[I].Charset;
          if ((Table.Fields[I].Collation <> '') and (Table.Fields[I].Collation <> TCBaseTable(Table).Collation)) then
          begin
            if (S <> '') then S := S + ', ';
            S := S + Table.Fields[I].Collation;
          end;
        end;
        if (S <> '') then
          Content := Content + '<td>' + Escape(S) + '</td>'
        else
          Content := Content + '<td>&nbsp;</td>';
        if (Client.ServerVersion >= 40100) then
          if (TCBaseTableField(Table.Fields[I]).Comment <> '') then
            Content := Content + '<td>' + Escape(TCBaseTableField(Table.Fields[I]).Comment) + '</td>'
          else
            Content := Content + '<td>&nbsp;</td>';
        Content := Content + #9 + '</tr>' + #13#10;
      end;
      Content := Content + '</table><br>' + #13#10;

      if ((Table is TCBaseTable) and (TCBaseTable(Table).ForeignKeys.Count > 0)) then
      begin
        Content := Content + '<h3>' + Preferences.LoadStr(459) + ':</h3>' + #13#10;

        Content := Content + '<table border="0" cellspacing="0" summary="' + Escape(Table.Name) + '" class="TableObject">' + #13#10;
        Content := Content + #9 + '<tr class="TableHeader ObjectHeader">';
        Content := Content + '<th>' + Escape(ReplaceStr(Preferences.LoadStr(35), '&', '')) + '</th>';
        Content := Content + '<th>' + Escape(Preferences.LoadStr(69)) + '</th>';
        Content := Content + '<th>' + Escape(Preferences.LoadStr(73)) + '</th>';
        Content := Content + '</tr>' + #13#10;
        for I := 0 to TCBaseTable(Table).ForeignKeys.Count - 1 do
        begin
          Content := Content + #9 + '<tr>';
          Content := Content + '<th>' + Escape(TCBaseTable(Table).ForeignKeys[I].Name) + '</th>';
          Content := Content + '<td>' + Escape(TCBaseTable(Table).ForeignKeys[I].DBTypeStr()) + '</td>';
          S := '';
          if (TCBaseTable(Table).ForeignKeys[I].OnDelete = dtCascade) then S := 'cascade on delete';
          if (TCBaseTable(Table).ForeignKeys[I].OnDelete = dtSetNull) then S := 'set NULL on delete';
          if (TCBaseTable(Table).ForeignKeys[I].OnDelete = dtSetDefault) then S := 'set default on delete';
          if (TCBaseTable(Table).ForeignKeys[I].OnDelete = dtNoAction) then S := 'no action on delete';
          S2 := '';
          if (TCBaseTable(Table).ForeignKeys[I].OnUpdate = utCascade) then S2 := 'cascade on update';
          if (TCBaseTable(Table).ForeignKeys[I].OnUpdate = utSetNull) then S2 := 'set NULL on update';
          if (TCBaseTable(Table).ForeignKeys[I].OnUpdate = utSetDefault) then S2 := 'set default on update';
          if (TCBaseTable(Table).ForeignKeys[I].OnUpdate = utNoAction) then S2 := 'no action on update';
          if (S <> '') and (S2 <> '') then S := S + ', ';
          S := S + S2;
          Content := Content + '<td>' + Escape(S) + '</td>';
          Content := Content + '</tr>' + #13#10;
        end;
        Content := Content + '</table><br>' + #13#10;
      end;
    end;

  if (Data) then
  begin
    if (Structure) then
      Content := Content + '<h3>' + Preferences.LoadStr(580) + ':</h3>' + #13#10;

    if (Assigned(Table)) then
      Content := Content + '<table border="0" cellspacing="0" summary="' + Escape(Table.Name) + '" class="TableData">' + #13#10
    else
      Content := Content + '<table border="0" cellspacing="0" class="TableData">' + #13#10;
    Content := Content + #9 + '<tr class="TableHeader">';

    SetLength(FieldOfPrimaryIndex, Length(Fields));
    for I := 0 to Length(Fields) - 1 do
    begin
      FieldOfPrimaryIndex[I] := Fields[I].IsIndexField;

      if (FieldOfPrimaryIndex[I]) then
        Content := Content + '<th class="DataHeader PrimaryKey">'
      else
        Content := Content + '<th class="DataHeader">';

      if (I < Length(DestinationFields)) then
        Content := Content + Escape(DestinationFields[I].Name) + '</th>'
      else
        Content := Content + Escape(Fields[I].DisplayName) + '</th>';
    end;
    Content := Content + '</tr>' + #13#10;


    SetLength(CSS, Length(Fields));
    for I := 0 to Length(Fields) - 1 do
    begin
      CSS[I] := 'Data';
      if (FieldOfPrimaryIndex[I]) then
        CSS[I] := CSS[I] + ' PrimaryKey';
      if (Fields[I].Alignment = taRightJustify) then
        CSS[I] := CSS[I] + ' RightAlign';

      RowOdd := True;
    end;
  end;

  WriteContent(Content);
end;

procedure TTExportHTML.ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  Content: string;
  I: Integer;
  Value: string;
begin
  Content := '';

  if (RowOdd) then
    Content := Content + #9 + '<tr class="odd">'
  else
    Content := Content + #9 + '<tr class="even">';
  RowOdd := not RowOdd;

  for I := 0 to Length(Fields) - 1 do
    if (Fields[I].IsNull) then
      if (NULLText) then
        Content := Content + '<td class="Null">&lt;NULL&gt;</td>'
      else
        Content := Content + '<td class="Null">&nbsp;</td>'
    else
    begin
      if (DataSet.LibLengths^[I] = 0) then
        Value := '&nbsp;'
      else if (GeometryField(Fields[I])) then
        Value := '&lt;GEO&gt;'
      else if (not TextContent and (Fields[I].DataType = ftWideMemo)) then
        Value := '&lt;MEMO&gt;'
      else if (Fields[I].DataType = ftBytes) then
        Value := '&lt;BINARY&gt;'
      else if (Fields[I].DataType = ftBlob) then
        Value := '&lt;BLOB&gt;'
      else if (Fields[I].DataType in TextDataTypes) then
        Value := Escape(DataSet.GetAsString(Fields[I].FieldNo))
      else
        Value := DataSet.GetAsString(Fields[I].FieldNo);

      if (FieldOfPrimaryIndex[I]) then
        Content := Content + '<th class="' + CSS[I] + '">' + Value + '</th>'
      else
        Content := Content + '<td class="' + CSS[I] + '">' + Value + '</td>';
    end;

  Content := Content + '</tr>' + #13#10;

  WriteContent(Content);
end;

{ TTExportXML *****************************************************************}

constructor TTExportXML.Create(const AClient: TCClient; const AFilename: TFileName; const ACodePage: Cardinal);
begin
  inherited;

  DatabaseTag := '';
  RootTag := '';
  TableTag := '';
end;

function TTExportXML.Escape(const Str: string): string;
label
  StartL,
  StringL, String2,
  PositionL, PositionE,
  MoveReplaceL, MoveReplaceE,
  FindPos, FindPos2,
  Finish;
const
  SearchLen = 5;
  Search: array [0 .. SearchLen - 1] of Char = ('&', '"', '''', '<', '>');
  Replace: array [0 .. SearchLen - 1] of PChar = ('&amp;', '&quot;', '&apos;', '&lt;', '&gt;');
var
  Len: Integer;
  Positions: packed array [0 .. SearchLen - 1] of Cardinal;
begin
  Len := Length(Str);

  if (Len = 0) then
    Result := ''
  else
  begin
    SetLength(Result, 6 * Len); // reserve space

    asm
        PUSH ES
        PUSH ESI
        PUSH EDI
        PUSH EBX

        PUSH DS                          // string operations uses ES
        POP ES
        CLD                              // string operations uses forward direction

        MOV ESI,PChar(Str)               // Copy characters from Str
        MOV EAX,Result                   //   to Result
        MOV EDI,[EAX]
        MOV ECX,Len                      // Length of Str string

      // -------------------

        MOV EBX,0                        // Numbers of characters in Search
      StartL:
        CALL FindPos                     // Find Search character position
        INC EBX                          // Next character in Search
        CMP EBX,SearchLen                // All Search characters handled?
        JNE StartL                       // No!

      // -------------------

      StringL:
        PUSH ECX

        MOV ECX,0                        // Numbers of characters in Search
        MOV EBX,-1                       // Index of first position
        MOV EAX,0                        // Last character
        LEA EDX,Positions
      PositionL:
        CMP [EDX + ECX * 4],EAX          // Position before other positions?
        JB PositionE                     // No!
        MOV EBX,ECX                      // Index of first position
        MOV EAX,[EDX + EBX * 4]          // Value of first position
      PositionE:
        INC ECX                          // Next Position
        CMP ECX,SearchLen                // All Positions compared?
        JNE PositionL                    // No!

        POP ECX

        SUB ECX,EAX                      // Copy normal characters from Str
        CMP ECX,0                        // Is there something to copy?
        JE String2                       // No!
        REPNE MOVSW                      //   to Result

        MOV ECX,EAX

      String2:
        CMP ECX,0                        // Is there an character to replace?
        JE Finish                        // No!

        ADD ESI,2                        // Step of Search character

        PUSH ESI
        LEA EDX,Replace                  // Insert Replace string
        MOV ESI,[EDX + EBX * 4]
      MoveReplaceL:
        LODSW                            // Get Replace character
        CMP AX,0                         // End of Replace?
        JE MoveReplaceE                  // Yes!
        STOSW                            // Put character in Result
        JMP MoveReplaceL
      MoveReplaceE:
        POP ESI

        DEC ECX                          // Ignore Search character
        JZ Finish                        // All character in Value handled!

        CALL FindPos                     // Find Search character
        JMP StringL

      // -------------------

      FindPos:
        PUSH ECX
        PUSH EDI
        LEA EDI,Search                   // Character to Search
        MOV AX,[EDI + EBX * 2]
        MOV EDI,ESI                      // Search in Value
        REPNE SCASW                      // Find Search character
        JNE FindPos2                     // Search character not found!
        INC ECX
      FindPos2:
        LEA EDI,Positions
        MOV [EDI + EBX * 4],ECX          // Store found position
        POP EDI
        POP ECX
        RET

      // -------------------

      Finish:
        MOV EAX,Result                   // Calculate new length of Result
        MOV EAX,[EAX]
        SUB EDI,EAX
        SHR EDI,1                        // 2 Bytes = 1 character
        MOV Len,EDI

        POP EBX
        POP EDI
        POP ESI
        POP ES
    end;

    SetLength(Result, Len);
  end;
end;

procedure TTExportXML.ExecuteDatabaseFooter(const Database: TCDatabase);
begin
  if (Assigned(Database)) then
    if (DatabaseAttribute <> '') then
      WriteContent('</' + DatabaseTag + '>' + #13#10)
    else if (DatabaseTag <> '') then
      WriteContent('</' + SysUtils.LowerCase(Escape(Database.Name)) + '>' + #13#10);
end;

procedure TTExportXML.ExecuteDatabaseHeader(const Database: TCDatabase);
begin
  if (Assigned(Database)) then
    if (DatabaseAttribute <> '') then
      WriteContent('<' + DatabaseTag + ' ' + DatabaseAttribute + '="' + Escape(Database.Name) + '">' + #13#10)
    else if (DatabaseTag <> '') then
      WriteContent('<' + SysUtils.LowerCase(Escape(Database.Name)) + '>' + #13#10);
end;

procedure TTExportXML.ExecuteFooter();
begin
  WriteContent('</' + RootTag + '>' + #13#10);
end;

procedure TTExportXML.ExecuteHeader();
begin
  DoFileCreate(FFilename);

  if (UMLEncoding(CodePage) = '') then
    WriteContent('<?xml version="1.0"?>' + #13#10)
  else
    WriteContent('<?xml version="1.0" encoding="' + UMLEncoding(CodePage) + '"?>' + #13#10);
  WriteContent('<' + RootTag + ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' + #13#10);
end;

procedure TTExportXML.ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
begin
  if (Assigned(Table)) then
    if (TableAttribute <> '') then
      WriteContent('</' + TableTag + '>' + #13#10)
    else if (TableTag <> '') then
      WriteContent('</' + SysUtils.LowerCase(Escape(Table.Name)) + '>' + #13#10);
end;

procedure TTExportXML.ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
begin
  if (Assigned(Table)) then
    if (TableAttribute <> '') then
      WriteContent('<' + TableTag + ' ' + TableAttribute + '="' + Escape(Table.Name) + '">' + #13#10)
    else if (TableTag <> '') then
      WriteContent('<' + SysUtils.LowerCase(Escape(Table.Name)) + '>' + #13#10);
end;

procedure TTExportXML.ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  Content: string;
  I: Integer;
begin
  Content := #9 + '<' + RecordTag + '>' + #13#10;

  for I := 0 to Length(Fields) - 1 do
  begin
    if (FieldAttribute = '') then
      if (Length(DestinationFields) > 0) then
        Content := Content + #9#9 + '<' + SysUtils.LowerCase(Escape(DestinationFields[I].Name)) + ''
      else
        Content := Content + #9#9 + '<' + SysUtils.LowerCase(Escape(Fields[I].DisplayName)) + ''
    else
      if (Length(DestinationFields) > 0) then
        Content := Content + #9#9 + '<' + FieldTag + ' ' + FieldAttribute + '="' + Escape(DestinationFields[I].Name) + '"'
      else
        Content := Content + #9#9 + '<' + FieldTag + ' ' + FieldAttribute + '="' + Escape(Fields[I].DisplayName) + '"';
    if (Fields[I].IsNull) then
      Content := Content + ' xsi:nil="true" />' + #13#10
    else
    begin
      if (Fields[I].DataType in TextDataTypes + BinaryDataTypes) then
        Content := Content + '>' + Escape(DataSet.GetAsString(Fields[I].FieldNo))
      else
        Content := Content + '>' + DataSet.GetAsString(Fields[I].FieldNo);

      if (FieldAttribute = '') then
        if (Length(DestinationFields) > 0) then
          Content := Content + '</' + SysUtils.LowerCase(Escape(DestinationFields[I].Name)) + '>' + #13#10
        else
          Content := Content + '</' + SysUtils.LowerCase(Escape(Fields[I].DisplayName)) + '>' + #13#10
      else
        Content := Content + '</' + FieldTag + '>' + #13#10;
    end;
  end;

  Content := Content + #9 + '</' + RecordTag + '>' + #13#10;

  WriteContent(Content);
end;

{ TTExportODBC ****************************************************************}

constructor TTExportODBC.Create(const AClient: TCClient; const AODBC: SQLHDBC = SQL_NULL_HANDLE; const AHandle: SQLHDBC = SQL_NULL_HANDLE);
begin
  inherited Create(AClient);

  FODBC := AODBC;
  FHandle := AHandle;

  FStmt := SQL_NULL_HANDLE;
  TableName := '';
end;

procedure TTExportODBC.ExecuteFooter();
begin
  inherited;

  if (Stmt <> SQL_NULL_HANDLE) then
    begin SQLFreeHandle(SQL_HANDLE_STMT, FStmt); FStmt := SQL_NULL_HANDLE; end;

  if (Handle <> SQL_NULL_HANDLE) then
  begin
    SQLEndTran(SQL_HANDLE_DBC, Handle, SQL_COMMIT);

    SQLDisconnect(Handle);
    SQLFreeHandle(SQL_HANDLE_DBC, FHandle); FHandle := SQL_NULL_HANDLE;
  end;
  if (ODBC <> SQL_NULL_HANDLE) then
    begin SQLFreeHandle(SQL_HANDLE_ENV, FODBC); FODBC := SQL_NULL_HANDLE; end;
end;

procedure TTExportODBC.ExecuteHeader();
begin
  if (Success = daSuccess) then
  begin
    SQLSetConnectAttr(Handle, SQL_ATTR_AUTOCOMMIT, SQLPOINTER(SQL_AUTOCOMMIT_OFF), 1);
    if (not SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_STMT, Handle, @Stmt))) then
      DoError(ODBCError(SQL_HANDLE_DBC, Handle), EmptyToolsItem(), False);
  end;

  inherited;
end;

procedure TTExportODBC.ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  I: Integer;
begin
  inherited;

  TableName := '';

  for I := 0 to Length(Parameter) - 1 do
    case (Fields[I].DataType) of
      ftString,
      ftShortInt,
      ftByte,
      ftSmallInt,
      ftWord,
      ftInteger,
      ftLongWord,
      ftLargeint,
      ftSingle,
      ftFloat,
      ftExtended,
      ftDate,
      ftDateTime,
      ftTimestamp,
      ftTime:
        FreeMem(Parameter[I].Buffer);
      ftWideString:
        if (Fields[I].Size < 256) then
          FreeMem(Parameter[I].Buffer);
    end;
  SetLength(Parameter, 0);
end;

procedure TTExportODBC.ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  ColumnSize: SQLUINTEGER;
  Error: TTools.TError;
  I: Integer;
  J: Integer;
  SQL: string;
  ValueType: SQLSMALLINT;
  ParameterType: SQLSMALLINT;
begin
  if (not (Self is TTExportExcel)) then
  begin
    if (TableName = '') then
      TableName := Table.Name;

    SQL := 'CREATE TABLE "' + TableName + '" (';
    for I := 0 to Length(Fields) - 1 do
    begin
      if (I > 0) then SQL := SQL + ',';
      SQL := SQL + '"' + Table.Fields[I].Name + '" ';

      if (Table.Fields[I].AutoIncrement and (Table.Fields[I].FieldType in [mfTinyInt, mfSmallInt, mfMediumInt, mfInt])) then
        SQL := SQL + 'COUNTER'
      else
        case (Table.Fields[I].FieldType) of
          mfBit:
            if ((Self is TTExportAccess) and (Table.Fields[I].Size = 1)) then
              SQL := SQL + 'BIT'
            else
              SQL := SQL + 'BINARY(' + IntToStr(Table.Fields[I].Size div 8) + ')';
          mfTinyInt:
            if (Table.Fields[I].Unsigned) then
              SQL := SQL + 'BYTE'
            else
              SQL := SQL + 'SMALLINT';
          mfSmallInt, mfYear:
            if (not Table.Fields[I].Unsigned) then
              SQL := SQL + 'SMALLINT'
            else
              SQL := SQL + 'INTEGER';
          mfMediumInt:
            SQL := SQL + 'INTEGER';
          mfInt:
            if (not Table.Fields[I].Unsigned) then
              SQL := SQL + 'INTEGER'
            else
              SQL := SQL + 'VARCHAR(10)';
          mfBigInt:
            SQL := SQL + 'VARCHAR(20)';
          mfFloat:
            SQL := SQL + 'REAL';
          mfDouble:
            SQL := SQL + 'FLOAT';
          mfDecimal:
            SQL := SQL + 'CURRENCY';
          mfDate:
            SQL := SQL + 'DATE';
          mfDateTime, mfTimeStamp:
            SQL := SQL + 'TIMESTAMP';
          mfTime:
            SQL := SQL + 'TIME';
          mfChar:
            SQL := SQL + 'CHAR(' + IntToStr(Table.Fields[I].Size) + ')';
          mfEnum, mfSet:
            SQL := SQL + 'VARCHAR';
          mfVarChar:
            if (Table.Fields[I].Size <= 255) then
              SQL := SQL + 'VARCHAR(' + IntToStr(Table.Fields[I].Size) + ')'
            else
              SQL := SQL + 'LONGTEXT';
          mfTinyText, mfText, mfMediumText, mfLongText:
            SQL := SQL + 'LONGTEXT';
          mfBinary:
            SQL := SQL + 'BINARY(' + IntToStr(Table.Fields[I].Size) + ')';
          mfVarBinary:
            if (Table.Fields[I].Size <= 255) then
              SQL := SQL + 'VARBINARY(' + IntToStr(Table.Fields[I].Size) + ')'
            else
              SQL := SQL + 'LONGBINARY';
          mfTinyBlob, mfBlob, mfMediumBlob, mfLongBlob,
          mfGeometry, mfPoint, mfLineString, mfPolygon, mfMultiPoint, mfMultiLineString, mfMultiPolygon, mfGeometryCollection:
            SQL := SQL + 'LONGBINARY';
          else
            raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [Table.Fields[I].Name, Ord(Table.Fields[I].FieldType)]);
        end;
      if (not Table.Fields[I].NullAllowed) then
        SQL := SQL + ' NOT NULL';
    end;
    if ((Table is TCBaseTable) and Assigned(TCBaseTable(Table).PrimaryKey)) then
    begin
      SQL := SQL + ',PRIMARY KEY (';
      for I := 0 to TCBaseTable(Table).PrimaryKey.Columns.Count - 1 do
      begin
        if (I > 0) then SQL := SQL + ',';
        SQL := SQL + '"' + TCBaseTable(Table).PrimaryKey.Columns[I].Field.Name + '"';
      end;
      SQL := SQL + ')';
    end;
    SQL := SQL + ')';

    while ((Success <> daAbort) and not SQL_SUCCEEDED(SQLExecDirect(Stmt, PSQLTCHAR(SQL), SQL_NTS))) do
    begin
      Error := ODBCError(SQL_HANDLE_STMT, Stmt);
      Error.ErrorMessage := Error.ErrorMessage + ' - ' + SQL;
      DoError(Error, EmptyToolsItem(), True);
    end;


    if (Table is TCBaseTable) then
      for I := 0 to TCBaseTable(Table).Keys.Count - 1 do
        if (not TCBaseTable(Table).Keys[I].Primary) then
        begin
          SQL := 'CREATE';
          if (TCBaseTable(Table).Keys[I].Unique) then
            SQL := SQL + ' UNIQUE';
          SQL := SQL + ' INDEX "' + TCBaseTable(Table).Keys[I].Name + '"';
          SQL := SQL + ' ON "' + Table.Name + '"';
          SQL := SQL + ' (';
          for J := 0 to TCBaseTable(Table).Keys[I].Columns.Count - 1 do
          begin
            if (J > 0) then SQL := SQL + ',';
            SQL := SQL + '"' + TCBaseTable(Table).Keys[I].Columns[J].Field.Name + '"';
          end;
          SQL := SQL + ');';

          // Execute silent, since some ODBC drivers doesn't support keys
          // and the user should know that...
          SQLExecDirect(Stmt, PSQLTCHAR(SQL), SQL_NTS);
        end;
  end;

  SetLength(Parameter, Length(Fields));

  for I := 0 to Length(Fields) - 1 do
  begin
    if (BitField(Fields[I])) then
      begin
        ValueType := SQL_C_ULONG;
        ParameterType := SQL_INTEGER;
        ColumnSize := 8;
        Parameter[I].BufferSize := Fields[I].DataSize;
        GetMem(Parameter[I].Buffer, Parameter[I].BufferSize);
      end
    else
      case (Fields[I].DataType) of
        ftString:
          begin
            ValueType := SQL_C_BINARY;
            ParameterType := SQL_BINARY;
            ColumnSize := Fields[I].Size;
            Parameter[I].BufferSize := ColumnSize;
            GetMem(Parameter[I].Buffer, Parameter[I].BufferSize);
          end;
        ftShortInt,
        ftByte,
        ftSmallInt,
        ftWord,
        ftInteger,
        ftLongWord,
        ftLargeint:
          begin
            ValueType := SQL_C_CHAR;
            ParameterType := SQL_CHAR;
            ColumnSize := 100;
            Parameter[I].BufferSize := ColumnSize;
            GetMem(Parameter[I].Buffer, Parameter[I].BufferSize);
          end;
        ftSingle,
        ftFloat,
        ftExtended:
          begin
            ValueType := SQL_C_CHAR;
            ParameterType := SQL_C_DOUBLE;
            ColumnSize := 100;
            Parameter[I].BufferSize := ColumnSize;
            GetMem(Parameter[I].Buffer, Parameter[I].BufferSize);
          end;
        ftTimestamp:
          begin
            ValueType := SQL_C_CHAR;
            ParameterType := SQL_CHAR;
            ColumnSize := 100;
            Parameter[I].BufferSize := ColumnSize;
            GetMem(Parameter[I].Buffer, Parameter[I].BufferSize);
          end;
        ftDate:
          begin
            ValueType := SQL_C_CHAR;
            ParameterType := SQL_TYPE_DATE;
            ColumnSize := 10; // 'yyyy-mm-dd'
            Parameter[I].BufferSize := ColumnSize;
            GetMem(Parameter[I].Buffer, Parameter[I].BufferSize);
          end;
        ftDateTime:
          begin
            ValueType := SQL_C_CHAR;
            ParameterType := SQL_TYPE_TIMESTAMP;
            ColumnSize := 19; // 'yyyy-mm-dd hh:hh:ss'
            Parameter[I].BufferSize := ColumnSize;
            GetMem(Parameter[I].Buffer, Parameter[I].BufferSize);
          end;
        ftTime:
          begin
            ValueType := SQL_C_CHAR;
            ParameterType := -154; // SQL_SS_TIME2
            ColumnSize := 8; // 'hh:mm:ss'
            Parameter[I].BufferSize := ColumnSize;
            GetMem(Parameter[I].Buffer, Parameter[I].BufferSize);
          end;
        ftWideString:
          begin
            if (Fields[I].Size < 256) then
            begin
              ValueType := SQL_C_WCHAR;
              ParameterType := SQL_WCHAR;
              ColumnSize := Fields[I].Size;
              Parameter[I].BufferSize := ColumnSize * SizeOf(Char);
              GetMem(Parameter[I].Buffer, Parameter[I].BufferSize);
            end
            else
            begin
              ValueType := SQL_C_WCHAR;
              ParameterType := SQL_WLONGVARCHAR;
              ColumnSize := Fields[I].Size;
              Parameter[I].BufferSize := ODBCDataSize;
              Parameter[I].Buffer := SQLPOINTER(I);
            end;
          end;
        ftWideMemo:
          begin
            ValueType := SQL_C_WCHAR;
            ParameterType := SQL_WLONGVARCHAR;
            ColumnSize := Fields[I].Size;
            Parameter[I].BufferSize := ODBCDataSize;
            Parameter[I].Buffer := SQLPOINTER(I);
          end;
        ftBlob:
          begin
            ValueType := SQL_C_BINARY;
            ParameterType := SQL_LONGVARBINARY;
            ColumnSize := Fields[I].Size;
            Parameter[I].BufferSize := ODBCDataSize;
            Parameter[I].Buffer := SQLPOINTER(I);
          end;
        else
          raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [Fields[I].DisplayName, Ord(Fields[I].DataType)]);
      end;

    if ((Success = daSuccess) and not SQL_SUCCEEDED(SQLBindParameter(Stmt, 1 + I, SQL_PARAM_INPUT, ValueType, ParameterType,
      ColumnSize, 0, Parameter[I].Buffer, Parameter[I].BufferSize, @Parameter[I].Size))) then
    begin
      Error := ODBCError(SQL_HANDLE_STMT, Stmt);
      Error.ErrorMessage := Error.ErrorMessage;
      DoError(Error, EmptyToolsItem(), False);
    end;
  end;

  SQL := 'INSERT INTO "' + TableName + '" VALUES (';
  for I := 0 to Length(Fields) - 1 do
  begin
    if (I > 0) then SQL := SQL + ',';
    SQL := SQL + '?';
  end;
  SQL := SQL + ')';

  if ((Success = daSuccess) and not SQL_SUCCEEDED(SQLPrepare(Stmt, PSQLTCHAR(SQL), SQL_NTS))) then
  begin
    Error := ODBCError(SQL_HANDLE_STMT, Stmt);
    Error.ErrorMessage := Error.ErrorMessage + ' - ' + SQL;
    DoError(Error, EmptyToolsItem(), False);
  end;
end;

procedure TTExportODBC.ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  DateTime: TDateTime;
  Error: TTools.TError;
  Field: SQLPOINTER;
  I: Integer;
  Index: Integer;
  L: LargeInt;
  ReturnCode: SQLRETURN;
  S: string;
  Size: Integer;
begin
  for I := 0 to Length(Fields) - 1 do
    if (Fields[I].IsNull) then
      Parameter[I].Size := SQL_NULL_DATA
    else if (BitField(Fields[I])) then
      begin
        L := Fields[I].AsLargeInt;
        Parameter[I].Size := SizeOf(L);
        MoveMemory(Parameter[I].Buffer, @L, Parameter[I].Size);
      end
    else
      case (Fields[I].DataType) of
        ftString:
          begin
            Parameter[I].Size := Min(Parameter[I].BufferSize, DataSet.LibLengths^[I]);
            MoveMemory(Parameter[I].Buffer, DataSet.LibRow^[I], Parameter[I].Size);
          end;
        ftShortInt,
        ftByte,
        ftSmallInt,
        ftWord,
        ftInteger,
        ftLongWord,
        ftLargeint,
        ftSingle,
        ftFloat,
        ftExtended,
        ftTimestamp:
          begin
            Parameter[I].Size := Min(Parameter[I].BufferSize, DataSet.LibLengths^[I]);
            MoveMemory(Parameter[I].Buffer, DataSet.LibRow^[I], Parameter[I].Size);
          end;
        ftDate,
        ftTime,
        ftDateTime:
          begin
            SetString(S, DataSet.LibRow^[I], DataSet.LibLengths^[I]);
            if (not TryStrToDateTime(S, DateTime)) then // Dedect MySQL invalid dates like '0000-00-00' or '2012-02-30'
              Parameter[I].Size := SQL_NULL_DATA        // Handle them as NULL values
            else
            begin
              Parameter[I].Size := Min(Parameter[I].BufferSize, DataSet.LibLengths^[I]);
              MoveMemory(Parameter[I].Buffer, DataSet.LibRow^[I], Parameter[I].Size);
            end;
          end;
        ftWideString:
          if (Fields[I].Size < 256) then
            Parameter[I].Size := AnsiCharToWideChar(Client.CodePage, DataSet.LibRow^[I], DataSet.LibLengths^[I], Parameter[I].Buffer, Parameter[I].BufferSize div SizeOf(Char)) * SizeOf(Char)
          else
            Parameter[I].Size := SQL_LEN_DATA_AT_EXEC(AnsiCharToWideChar(Client.CodePage, DataSet.LibRow^[I], DataSet.LibLengths^[I], nil, 0) * SizeOf(Char));
        ftWideMemo:
          Parameter[I].Size := SQL_LEN_DATA_AT_EXEC(AnsiCharToWideChar(Client.CodePage, DataSet.LibRow^[I], DataSet.LibLengths^[I], nil, 0) * SizeOf(Char));
        ftBlob:
          Parameter[I].Size := SQL_LEN_DATA_AT_EXEC(DataSet.LibLengths^[I]);
        else
          raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [Fields[I].DisplayName, Ord(Fields[I].DataType)]);
      end;

  repeat
    ReturnCode := SQLExecute(Stmt);
    if (not SQL_SUCCEEDED(ReturnCode) and (ReturnCode <> SQL_NEED_DATA)) then
    begin
      Error := ODBCError(SQL_HANDLE_STMT, Stmt);
      Error.ErrorMessage := Error.ErrorMessage;
      DoError(Error, EmptyToolsItem(), True);
    end;
  until ((Success = daAbort) or SQL_SUCCEEDED(ReturnCode) or (ReturnCode = SQL_NEED_DATA));

  while ((Success = daSuccess) and (ReturnCode = SQL_NEED_DATA)) do
  begin
    ReturnCode := SQLParamData(Stmt, @Field);
    I := SQLINTEGER(Field);
    if (ReturnCode = SQL_NEED_DATA) then
      case (Fields[I].DataType) of
        ftWideString,
        ftWideMemo:
          begin
            Size := -(Parameter[I].Size - SQL_LEN_DATA_AT_EXEC_OFFSET);
            S := DataSet.GetAsString(Fields[I].FieldNo);
            Index := 0;
            if (Size > 0) then
              repeat
                ODBCException(Stmt, SQLPutData(Stmt, @S[1 + Index div 2], Min(ODBCDataSize, Size - Index)));
                Inc(Index, Min(ODBCDataSize, Size - Index));
              until (Index = Size);
          end;
        ftBlob:
          begin
            Size := DataSet.LibLengths^[I];
            Index := 0;
            if (Size > 0) then
              repeat
                ODBCException(Stmt, SQLPutData(Stmt, @DataSet.LibRow^[Fields[I].FieldNo - 1][Index], Min(ODBCDataSize, Size - Index)));
                Inc(Index, Min(ODBCDataSize, Size - Index));
              until (Index = Size);
          end;
        else
          raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [Fields[I].DisplayName, Ord(Fields[I].DataType)]);
      end;
  end;
end;

{ TTExportAccess **************************************************************}

constructor TTExportAccess.Create(const AClient: TCClient; const AFilename: TFileName);
begin
  inherited Create(AClient);

  Filename := AFilename;
end;

procedure TTExportAccess.ExecuteHeader();
var
  ConnStrIn: string;
  Error: TTools.TError;
  ErrorCode: DWord;
  ErrorMsg: PChar;
  Size: Word;
begin
  ConnStrIn := 'Driver={Microsoft Access Driver (*.mdb)};' + 'DBQ=' + Filename + ';' + 'READONLY=FALSE';

  while (FileExists(Filename) and not DeleteFile(Filename)) do
    DoError(SysError(), EmptyToolsItem(), True);

  if (Success = daSuccess) then
  begin
    if (not SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, @ODBC))) then
      DoError(ODBCError(0, SQL_NULL_HANDLE), EmptyToolsItem(), False)
    else if (not SQL_SUCCEEDED(SQLSetEnvAttr(ODBC, SQL_ATTR_ODBC_VERSION, SQLPOINTER(SQL_OV_ODBC3), SQL_IS_UINTEGER))) then
      DoError(ODBCError(SQL_HANDLE_ENV, ODBC), EmptyToolsItem(), False)
    else if (not SQLConfigDataSource(Application.Handle, ODBC_ADD_DSN, 'Microsoft Access Driver (*.mdb)', PChar('CREATE_DB=' + Filename + ' General'))) then
    begin
      Error.ErrorType := TE_ODBC;
      GetMem(ErrorMsg, SQL_MAX_MESSAGE_LENGTH * SizeOf(Char));
      SQLInstallerError(1, ErrorCode, ErrorMsg, SQL_MAX_MESSAGE_LENGTH - 1, Size);
      Error.ErrorCode := ErrorCode;
      SetString(Error.ErrorMessage, ErrorMsg, Size);
      Error.ErrorMessage := Error.ErrorMessage + '  (' + ConnStrIn + ')';
      FreeMem(ErrorMsg);
      DoError(Error, EmptyToolsItem(), False);
    end
    else if (not SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_DBC, ODBC, @Handle))) then
      DoError(ODBCError(SQL_HANDLE_ENV, ODBC), EmptyToolsItem(), False)
    else if (not SQL_SUCCEEDED(SQLDriverConnect(Handle, Application.Handle, PSQLTCHAR(ConnStrIn), SQL_NTS, nil, 0, nil, SQL_DRIVER_COMPLETE))
      or not SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_STMT, Handle, @Stmt))) then
      DoError(ODBCError(SQL_HANDLE_DBC, Handle), EmptyToolsItem(), False);
  end;

  inherited;
end;

procedure TTExportAccess.ExecuteFooter();
begin
  inherited;

  if (Success = daAbort) then
    DeleteFile(Filename);
end;

{ TTExportExcel ***************************************************************}

constructor TTExportExcel.Create(const AClient: TCClient; const AFilename: TFileName);
begin
  inherited Create(AClient);

  Filename := AFilename;

  Sheet := 0;
end;

procedure TTExportExcel.ExecuteHeader();
var
  ConnStrIn: WideString;
begin
  ConnStrIn := 'Driver={Microsoft Excel Driver (*.xls)};DBQ=' + Filename + ';DriverID=790;READONLY=FALSE';

  while (FileExists(Filename) and not DeleteFile(Filename)) do
    DoError(SysError(), EmptyToolsItem(), True);

  if (Success = daSuccess) then
  begin
    if (not SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, @ODBC))
      or not SQL_SUCCEEDED(SQLSetEnvAttr(ODBC, SQL_ATTR_ODBC_VERSION, SQLPOINTER(SQL_OV_ODBC3), SQL_IS_UINTEGER))) then
      DoError(ODBCError(0, SQL_NULL_HANDLE), EmptyToolsItem(), False)
    else if (not SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_DBC, ODBC, @Handle))
      or not SQL_SUCCEEDED(SQLDriverConnect(Handle, Application.Handle, PSQLTCHAR(ConnStrIn), SQL_NTS, nil, 0, nil, SQL_DRIVER_COMPLETE))) then
      DoError(ODBCError(SQL_HANDLE_ENV, ODBC), EmptyToolsItem(), False)
    else if (not SQL_SUCCEEDED(SQLAllocHandle(SQL_HANDLE_STMT, Handle, @Stmt))) then
      DoError(ODBCError(SQL_HANDLE_DBC, Handle), EmptyToolsItem(), False);
  end;

  inherited;
end;

procedure TTExportExcel.ExecuteFooter();
begin
  inherited;

  if (Success = daAbort) then
    DeleteFile(Filename);
end;

procedure TTExportExcel.ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  Error: TTools.TError;
  I: Integer;
  SQL: string;
begin
  Inc(Sheet);
  if (not Assigned(Table)) then
    TableName := 'Sheet' + IntToStr(Sheet)
  else
    TableName := Table.Name;

  SQL := 'CREATE TABLE "' + TableName + '" (';
  for I := 0 to Length(Fields) - 1 do
  begin
    if (I > 0) then SQL := SQL + ',';

    if (Length(DestinationFields) > 0) then
      SQL := SQL + '"' + DestinationFields[I].Name + '" '
    else if (Assigned(Table)) then
      SQL := SQL + '"' + Table.Fields[I].Name + '" '
    else
      SQL := SQL + '"' + Fields[I].DisplayName + '" ';

    if (BitField(Fields[I])) then
      if (Table.Fields[I].Size = 1) then
        SQL := SQL + 'BIT'
      else
        SQL := SQL + 'NUMERIC'
    else
    case (Fields[I].DataType) of
      ftString:
        SQL := SQL + 'STRING';
      ftShortInt,
      ftByte,
      ftSmallInt,
      ftWord,
      ftInteger,
      ftLongWord,
      ftLargeint,
      ftSingle,
      ftFloat,
      ftExtended:
        SQL := SQL + 'NUMERIC';
      ftDate,
      ftDateTime,
      ftTimestamp,
      ftTime:
        SQL := SQL + 'DATETIME';
      ftWideString,
      ftWideMemo,
      ftBlob:
        SQL := SQL + 'STRING';
      else
        raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [Fields[I].DisplayName, Ord(Fields[I].DataType)]);
    end;
  end;
  SQL := SQL + ')';

  while ((Success <> daAbort) and not SQL_SUCCEEDED(SQLExecDirect(Stmt, PSQLTCHAR(SQL), SQL_NTS))) do
  begin
    Error := ODBCError(SQL_HANDLE_STMT, Stmt);
    Error.ErrorMessage := Error.ErrorMessage + ' - ' + SQL;
    DoError(Error, EmptyToolsItem(), True);
  end;

  if (Success = daSuccess) then
    inherited;
end;

{ TTExportSQLite **************************************************************}

constructor TTExportSQLite.Create(const AClient: TCClient; const AFilename: TFileName);
begin
  inherited Create(AClient);

  Filename := AFilename;
end;

procedure TTExportSQLite.ExecuteHeader();
var
  Error: TTools.TError;
begin
  if (FileExists(Filename) and not DeleteFile(Filename)) then
    DoError(SysError(), EmptyToolsItem(), False)
  else if ((sqlite3_open_v2(PAnsiChar(UTF8Encode(Filename)), @Handle, SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE, nil) <> SQLITE_OK)
    or (sqlite3_exec(Handle, PAnsiChar(UTF8Encode('BEGIN TRANSACTION;')), nil, nil, nil) <> SQLITE_OK)) then
  begin
    Error.ErrorType := TE_SQLite;
    Error.ErrorCode := sqlite3_errcode(Handle);
    Error.ErrorMessage := UTF8ToString(sqlite3_errmsg(Handle));
    DoError(Error, EmptyToolsItem(), False);
  end;

  inherited;
end;

procedure TTExportSQLite.ExecuteFooter();
begin
  inherited;

  SQLiteException(Handle, sqlite3_exec(Handle, PAnsiChar(UTF8Encode('COMMIT;')), nil, nil, nil));
  sqlite3_close(Handle);

  if (Success = daAbort) then
    DeleteFile(Filename);
end;

procedure TTExportSQLite.ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
begin
  sqlite3_finalize(Stmt); Stmt := nil;

  SetLength(Text, 0);
end;

procedure TTExportSQLite.ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  Field: TCTableField;
  I: Integer;
  SQL: string;
begin
  SQL := 'CREATE TABLE "' + Table.Name + '" (';
  for I := 0 to Length(Fields) - 1 do
  begin
    Field := Table.FieldByName(Fields[I].Name);

    if (I > 0) then SQL := SQL + ', ';
    SQL := SQL + Field.Name + ' ';
    case (Field.FieldType) of
      mfBit, mfTinyInt, mfSmallInt, mfMediumInt, mfInt, mfBigInt:
        begin
          SQL := SQL + 'INTEGER';
          if ((Table is TCBaseTable)
            and Assigned(TCBaseTable(Table).PrimaryKey)
            and (TCBaseTable(Table).PrimaryKey.Columns.Count = 1)
            and (TCBaseTable(Table).PrimaryKey.Columns[0].Field = Table.Fields[I])) then
            SQL := SQL + ' PRIMARY KEY';
        end;
      mfFloat, mfDouble, mfDecimal:
        SQL := SQL + 'REAL';
      mfDate, mfDateTime, mfTimeStamp, mfTime, mfYear,
      mfEnum, mfSet,
      mfChar, mfVarChar, mfTinyText, mfText, mfMediumText, mfLongText:
        SQL := SQL + 'TEXT';
      mfBinary, mfVarBinary, mfTinyBlob, mfBlob, mfMediumBlob, mfLongBlob,
      mfGeometry, mfPoint, mfLineString, mfPolygon, mfMultiPoint, mfMultiLineString, mfMultiPolygon, mfGeometryCollection:
        SQL := SQL + 'BLOB';
    end;
  end;
  SQL := SQL + ');';
  SQLiteException(Handle, sqlite3_exec(Handle, PAnsiChar(UTF8Encode(SQL)), nil, nil, nil));


  SQL := 'INSERT INTO "' + Table.Name + '"';
  if (Length(DestinationFields) > 0) then
  begin
    SQL := SQL + '(';
    for I := 0 to Length(DestinationFields) - 1 do
    begin
      if (I > 0) then SQL := SQL + ',';
      SQL := SQL + '"' + DestinationFields[I].Name + '"';
    end;
    SQL := SQL + ')';
  end;
  SQL := SQL + ' VALUES (';
  for I := 0 to Length(Fields) - 1 do
  begin
    if (I > 0) then SQL := SQL + ',';
    SQL := SQL + '?' + IntToStr(1 + I)
  end;
  SQL := SQL + ')';
  SQLiteException(Handle, sqlite3_prepare_v2(Handle, PAnsiChar(UTF8Encode(SQL)), -1, @Stmt, nil));

  SetLength(Text, Length(Fields));
end;

procedure TTExportSQLite.ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  I: Integer;
  L: LargeInt;
begin
  for I := 0 to Length(Fields) - 1 do
    if (not Assigned(DataSet.LibRow^[I])) then
      sqlite3_bind_null(Stmt, 1 + I)
    else if (BitField(Fields[I])) then
    begin
      L := Fields[I].AsLargeInt;
      sqlite3_bind_blob(Stmt, 1 + I, @L, SizeOf(L), SQLITE_STATIC)
    end
    else
      case (Fields[I].DataType) of
        ftString:
          sqlite3_bind_blob(Stmt, 1 + I, DataSet.LibRow^[I], DataSet.LibLengths^[I], SQLITE_STATIC);
        ftShortInt,
        ftByte,
        ftSmallInt,
        ftWord,
        ftInteger,
        ftLongWord,
        ftLargeint,
        ftSingle,
        ftFloat,
        ftExtended,
        ftDate,
        ftDateTime,
        ftTimestamp,
        ftTime:
          sqlite3_bind_text(Stmt, 1 + I, DataSet.LibRow^[I], DataSet.LibLengths^[I], SQLITE_STATIC);
        ftWideString,
        ftWideMemo:
          if ((Client.CodePage = CP_UTF8) or (DataSet.LibLengths^[I] = 0)) then
            sqlite3_bind_text(Stmt, 1 + I, DataSet.LibRow^[I], DataSet.LibLengths^[I], SQLITE_STATIC)
          else
          begin
            Text[I] := UTF8Encode(DataSet.GetAsString(Fields[I].FieldNo));
            sqlite3_bind_text(Stmt, 1 + I, PAnsiChar(@Text[I][1]), Length(Text[I]), SQLITE_STATIC);
          end;
        ftBlob:
          sqlite3_bind_blob(Stmt, 1 + I, DataSet.LibRow^[I], DataSet.LibLengths^[I], SQLITE_STATIC);
        else
          raise EDatabaseError.CreateFMT(SUnknownFieldType + ' (%d)', [Fields[I].Name, Integer(Fields[I].DataType)]);
      end;

  SQLiteException(Handle, sqlite3_step(Stmt));
  SQLiteException(Handle, sqlite3_reset(Stmt));
end;

{ TTExportCanvas **************************************************************}

function WordBreak(const Canvas: TCanvas; const Text: string; const Width: Integer): String;
var
  I: Integer;
  Index: Integer;
  OldIndex: Integer;
  S: string;
  Size: TSize;
  StringList: TStringList;
begin
  StringList := TStringList.Create();
  StringList.Text := Text;

  I := 0;
  while (I < StringList.Count) do
  begin
    S := StringList[I];
    repeat
      Index := 1;
      repeat
        OldIndex := Index;
        while ((Index <= Length(S)) and CharInSet(S[Index], [#9, ' '])) do Inc(Index);
        while ((Index <= Length(S)) and not CharInSet(S[Index], [#9, ' '])) do Inc(Index);
        if (not GetTextExtentPoint32(Canvas.Handle, PChar(S), Index - 1, Size)) then
          RaiseLastOSError();
      until ((Size.cx > Width) or (Index >= Length(S)));
      if (Size.cx <= Width) then
        S := ''
      else
      begin
        StringList[I] := Copy(S, 1, OldIndex - 1);
        while ((OldIndex <= Length(S)) and CharInSet(S[OldIndex], [#9, ' '])) do Inc(OldIndex);
        Delete(S, 1, OldIndex - 1);
        if (S <> '') then
        begin
          Inc(I);
          StringList.Insert(I, S);
        end;
      end;
    until (S = '');
    Inc(I);
  end;

  Result := StringList.Text;
  StringList.Free();
end;

function TTExportCanvas.AllocateHeight(const Height: Integer): Boolean;
begin
  Result := Y + Height > ContentArea.Bottom;
  if (Result) then
  begin
    if (Length(Columns) > 0) then
      GridDrawVertLines();

    PageBreak(True);
  end;
end;

procedure TTExportCanvas.ContentTextOut(Text: string; const ExtraPadding: Integer = 0);
var
  R: TRect;
begin
  R := Rect(ContentArea.Left, Y, ContentArea.Right, ContentArea.Bottom);
  Canvas.TextRect(R, Text, [tfCalcRect, tfWordBreak]);

  AllocateHeight(ExtraPadding + R.Bottom - R.Top + Padding + ExtraPadding);

  if (Y > ContentArea.Top) then
    Inc(Y, ExtraPadding);
  R := Rect(ContentArea.Left, Y, ContentArea.Right, Y + R.Bottom - R.Top);
  Canvas.TextRect(R, Text, [tfWordBreak]);

  Inc(Y, R.Bottom - R.Top + Padding + ExtraPadding);
end;

constructor TTExportCanvas.Create(const AClient: TCClient);
var
  NonClientMetrics: TNonClientMetrics;
begin
  inherited Create(AClient);

  DateTime := Client.ServerDateTime;
  ContentFont := TFont.Create();
  GridFont := TFont.Create();
  IndexBackground := False;
  NULLText := True;
  PageFont := TFont.Create();
  PageNumber.Row := 1;
  SQLFont := TFont.Create();

  NonClientMetrics.cbSize := SizeOf(NonClientMetrics);
  if (SystemParametersInfo(SPI_GETNONCLIENTMETRICS, SizeOf(NonClientMetrics), @NonClientMetrics, 0)) then
    ContentFont.Handle := CreateFontIndirect(NonClientMetrics.lfMessageFont)
  else
    ContentFont.Assign(Canvas.Font);
  ContentFont.Color := clBlack;

  GridFont.Name := Preferences.GridFontName;
  GridFont.Style := Preferences.GridFontStyle;
  GridFont.Charset := Preferences.GridFontCharset;
  GridFont.Color := clBlack;
  GridFont.Size := Preferences.GridFontSize;

  SQLFont.Name := Preferences.SQLFontName;
  SQLFont.Style := Preferences.SQLFontStyle;
  SQLFont.Charset := Preferences.SQLFontCharset;
  SQLFont.Color := clBlack;
  SQLFont.Size := Preferences.SQLFontSize;

  PageFont.Assign(ContentFont);
  PageFont.Size := PageFont.Size - 2;

  Canvas.Font.Assign(PageFont);
  ContentArea.Left := Margins.Left;
  ContentArea.Top := Margins.Top;
  ContentArea.Right := PageWidth - Margins.Right;
  ContentArea.Bottom := PageHeight - (Margins.Bottom + -Canvas.Font.Height + Padding + LineHeight + 10);

  Y := ContentArea.Top;

  Canvas.Font.Assign(ContentFont);
end;

destructor TTExportCanvas.Destroy();
begin
  ContentFont.Free();
  GridFont.Free();
  PageFont.Free();
  SQLFont.Free();

  inherited;
end;

procedure TTExportCanvas.ExecuteDatabaseHeader(const Database: TCDatabase);
begin
  if (Assigned(Database)) then
  begin
    Canvas.Font.Assign(ContentFont);
    Canvas.Font.Size := Canvas.Font.Size + 6;
    Canvas.Font.Style := Canvas.Font.Style + [fsBold];

    ContentTextOut(ReplaceStr(Preferences.LoadStr(38), '&', '') + ': ' + Database.Name, 3 * Padding);
  end;
end;

procedure TTExportCanvas.ExecuteFooter();
begin
  PageFooter();

  inherited;
end;

procedure TTExportCanvas.ExecuteHeader();
var
  DataHandle: TMySQLConnection.TDataResult;
  DataSet: TMySQLQuery;
  I: Integer;
  J: Integer;
  K: Integer;
  SQL: string;
  Tables: TList;
begin
  if (Success = daSuccess) then
  begin
    SetLength(MaxFieldsCharLengths, 0);

    Tables := TList.Create();

    SQL := '';
    for I := 0 to Length(ExportObjects) - 1 do
      if (ExportObjects[I].DBObject is TCTable) then
      begin
        Tables.Add(ExportObjects[I].DBObject);

        SQL := SQL + 'SELECT ';
        for J := 0 to TCTable(ExportObjects[I].DBObject).Fields.Count - 1 do
        begin
          if (J > 0) then SQL := SQL + ',';
          if (TCTable(ExportObjects[I].DBObject).Fields[J].FieldType in LOBFieldTypes) then
            SQL := SQL + '0'
          else if (TCTable(ExportObjects[I].DBObject).Fields[J].FieldType = mfBit) then
            SQL := SQL + 'MAX(' + Client.EscapeIdentifier(TCTable(ExportObjects[I].DBObject).Fields[J].Name) + ')+0' // MySQL 5.5.22 reports without the "+0" the MYSQL_TYPE_BIT field_type, but a char result
          else
            SQL := SQL + 'MAX(CHAR_LENGTH(' + Client.EscapeIdentifier(TCTable(ExportObjects[I].DBObject).Fields[J].Name) + '))';
          SQL := SQL + ' AS ' + Client.EscapeIdentifier(TCTable(ExportObjects[I].DBObject).Fields[J].Name);
        end;
        SQL := SQL + ' FROM ' + Client.EscapeIdentifier(ExportObjects[I].DBObject.Database.Name) + '.' + Client.EscapeIdentifier(ExportObjects[I].DBObject.Name) + ';' + #13#10;
      end;

    if (Success = daSuccess) then
    begin
      for J := 0 to Tables.Count - 1 do
        if (Success = daSuccess) then
        begin
          if (J = 0) then
            while ((Success <> daAbort) and not Client.FirstResult(DataHandle, SQL)) do
              DoError(DatabaseError(Client), EmptyToolsItem(), True, SQL)
          else
            if ((Success = daSuccess) and not Client.NextResult(DataHandle)) then
              DoError(DatabaseError(Client), EmptyToolsItem(), False);
          if (Success = daSuccess) then
            for I := 0 to Length(ExportObjects) - 1 do
              if (Tables[J] = ExportObjects[I].DBObject) then
              begin
                SetLength(MaxFieldsCharLengths, Length(MaxFieldsCharLengths) + 1);
                SetLength(MaxFieldsCharLengths[Length(MaxFieldsCharLengths) - 1], TCTable(Tables[J]).Fields.Count);
                DataSet := TMySQLQuery.Create(nil);
                DataSet.Open(DataHandle);
                if (not DataSet.IsEmpty) then
                  for K := 0 to DataSet.FieldCount - 1 do
                    MaxFieldsCharLengths[Length(MaxFieldsCharLengths) - 1][K] := DataSet.Fields[K].AsInteger;
                DataSet.Free();
              end;
        end;
      Client.CloseResult(DataHandle);
    end;

    Tables.Free();
  end;

  inherited;
end;

procedure TTExportCanvas.ExecuteTableFooter(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
begin
  if (Length(Columns) > 0) then
  begin
    GridDrawVertLines();
    SetLength(Columns, 0);
  end;

  Inc(Y, -Canvas.Font.Height);
end;

procedure TTExportCanvas.ExecuteTableHeader(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);
var
  I: Integer;
  J: Integer;
  K: Integer;
  GridData: TGridData;
  MaxTextWidth: Integer;
  S: string;
  S2: string;
  StringList: TStringList;
begin
  Canvas.Font.Assign(ContentFont);
  Canvas.Font.Size := Canvas.Font.Size + 4;
  Canvas.Font.Style := Canvas.Font.Style + [fsBold];

  if (Length(DBGrids) = 0) then
    if (Table is TCBaseTable) then
    begin
      ContentTextOut(ReplaceStr(Preferences.LoadStr(302), '&', '') + ': ' + Table.Name, 2 * Padding);
      if (TCBaseTable(Table).Comment <> '') then
        ContentTextOut(ReplaceStr(Preferences.LoadStr(111), '&', '') + ': ' + TCBaseTable(Table).Comment, 2 * Padding);
    end
    else if (Table is TCView) then
      ContentTextOut(ReplaceStr(Preferences.LoadStr(738), '&', '') + ': ' + Table.Name, 2 * Padding)
    else if (Structure) then
      ContentTextOut(ReplaceStr(Preferences.LoadStr(216), '&', ''), 2 * Padding);

  if (Structure) then
    if (Length(DBGrids) > 0) then
    begin
      Canvas.Font.Assign(ContentFont);
      Canvas.Font.Size := Canvas.Font.Size + 2;
      Canvas.Font.Style := Canvas.Font.Style + [fsBold];
      ContentTextOut(ReplaceStr(Preferences.LoadStr(794), '&', '') + ':', Padding);

      Canvas.Font.Assign(SQLFont);

      StringList := TStringList.Create();
      StringList.Text := DataSet.CommandText + ';';
      for I := 0 to StringList.Count - 1 do
        ContentTextOut(StringList[I]);
      StringList.Free();
    end
    else
    begin
      if ((Table is TCBaseTable) and (TCBaseTable(Table).Keys.Count > 0)) then
      begin
        Canvas.Font.Assign(ContentFont);
        Canvas.Font.Size := Canvas.Font.Size + 2;
        Canvas.Font.Style := Canvas.Font.Style + [fsBold];
        ContentTextOut(Preferences.LoadStr(458) + ':', Padding);

        if (Client.ServerVersion < 50503) then
          SetLength(Columns, 3)
        else
          SetLength(Columns, 4);
        Columns[0].HeaderText := ReplaceStr(Preferences.LoadStr(35), '&', '');
        Columns[1].HeaderText := Preferences.LoadStr(69);
        Columns[2].HeaderText := ReplaceStr(Preferences.LoadStr(73), '&', '');
        if (Client.ServerVersion >= 50503) then
          Columns[3].HeaderText := ReplaceStr(Preferences.LoadStr(111), '&', '');

        SetLength(GridData, TCBaseTable(Table).Keys.Count);
        for I := 0 to TCBaseTable(Table).Keys.Count - 1 do
        begin
          SetLength(GridData[I], Length(Columns));

          for J := 0 to Length(Columns) - 1 do
          begin
            GridData[I][J].Bold := False;
            GridData[I][J].Gray := False;
          end;

          GridData[I][0].Bold := TCBaseTable(Table).Keys[I].Primary;
          GridData[I][0].Text := TCBaseTable(Table).Keys[I].Caption;
          S := '';
          for K := 0 to TCBaseTable(Table).Keys[I].Columns.Count - 1 do
            begin
              if (S <> '') then S := S + ', ';
              S := S + TCBaseTable(Table).Keys[I].Columns[K].Field.Name;
            end;
          GridData[I][1].Text := S;
          if (TCBaseTable(Table).Keys[I].Unique) then
            GridData[I][2].Text := 'unique'
          else if (TCBaseTable(Table).Keys[I].Fulltext) then
            GridData[I][2].Text := 'fulltext'
          else
            GridData[I][2].Text := '';
          if (Client.ServerVersion >= 50503) then
            GridData[I][3].Text := TCBaseTable(Table).Keys[I].Comment;
        end;

        GridOut(GridData);
      end;

      {------------------------------------------------------------------------}

      Canvas.Font.Assign(ContentFont);
      Canvas.Font.Size := Canvas.Font.Size + 2;
      Canvas.Font.Style := Canvas.Font.Style + [fsBold];
      ContentTextOut(Preferences.LoadStr(253) + ':', Padding);

      if (Client.ServerVersion < 40100) then
        SetLength(Columns, 5)
      else
        SetLength(Columns, 6);
      Columns[0].HeaderText := ReplaceStr(Preferences.LoadStr(35), '&', '');
      Columns[1].HeaderText := Preferences.LoadStr(69);
      Columns[2].HeaderText := Preferences.LoadStr(71);
      Columns[3].HeaderText := Preferences.LoadStr(72);
      Columns[4].HeaderText := ReplaceStr(Preferences.LoadStr(73), '&', '');
      if (Client.ServerVersion >= 40100) then
        Columns[5].HeaderText := ReplaceStr(Preferences.LoadStr(111), '&', '');


      SetLength(GridData, Table.Fields.Count);
      for I := 0 to Table.Fields.Count - 1 do
      begin
        SetLength(GridData[I], Length(Columns));

        for J := 0 to Length(Columns) - 1 do
        begin
          GridData[I][J].Bold := False;
          GridData[I][J].Gray := False;
        end;

        GridData[I][0].Bold := Table.Fields[I].InPrimaryKey;
        GridData[I][0].Text := Table.Fields[I].Name;
        GridData[I][1].Text := Table.Fields[I].DBTypeStr();
        if (Table.Fields[I].NullAllowed) then
          GridData[I][2].Text := Preferences.LoadStr(74)
        else
          GridData[I][2].Text := Preferences.LoadStr(75);
        if (Table.Fields[I].AutoIncrement) then
          GridData[I][3].Text := '<auto_increment>'
        else if (Table.Fields[I].Default = 'NULL') then
        begin
          GridData[I][3].Gray := True;
          GridData[I][3].Text := '<' + Preferences.LoadStr(71) + '>';
        end
        else if (Table.Fields[I].Default = 'CURRENT_TIMESTAMP') then
          GridData[I][3].Text := '<INSERT-TimeStamp>'
        else if (Table.Fields[I].Default <> '') then
          GridData[I][3].Text := Table.Fields[I].UnescapeValue(Table.Fields[I].Default)
        else
          GridData[I][3].Text := '';
        S := '';
        if ((Table is TCBaseTable) and (Table.Fields[I].FieldType in TextFieldTypes)) then
        begin
          if ((Table.Fields[I].Charset <> '') and (Table.Fields[I].Charset <> TCBaseTable(Table).DefaultCharset)) then
            S := S + Table.Fields[I].Charset;
          if ((Table.Fields[I].Collation <> '') and (Table.Fields[I].Collation <> TCBaseTable(Table).Collation)) then
          begin
            if (S <> '') then S := S + ', ';
            S := S + Table.Fields[I].Collation;
          end;
        end;
        GridData[I][4].Text := S;
        if (Client.ServerVersion >= 40100) then
          GridData[I][5].Text := TCBaseTableField(Table.Fields[I]).Comment;
      end;

      GridOut(GridData);

      {------------------------------------------------------------------------}

      if ((Table is TCBaseTable) and (TCBaseTable(Table).ForeignKeys.Count > 0)) then
      begin
        Canvas.Font.Assign(ContentFont);
        Canvas.Font.Size := Canvas.Font.Size + 2;
        Canvas.Font.Style := Canvas.Font.Style + [fsBold];
        ContentTextOut(Preferences.LoadStr(459) + ':', Padding);


        SetLength(Columns, 3);
        Columns[0].HeaderText := ReplaceStr(Preferences.LoadStr(35), '&', '');
        Columns[1].HeaderText := Preferences.LoadStr(69);
        Columns[2].HeaderText := Preferences.LoadStr(73);

        SetLength(GridData, TCBaseTable(Table).ForeignKeys.Count);
        for I := 0 to TCBaseTable(Table).ForeignKeys.Count - 1 do
        begin
          SetLength(GridData[I], Length(Columns));

          for J := 0 to Length(Columns) - 1 do
          begin
            GridData[I][J].Bold := False;
            GridData[I][J].Gray := False;
          end;

          GridData[I][0].Text := TCBaseTable(Table).ForeignKeys[I].Name;
          GridData[I][1].Text := TCBaseTable(Table).ForeignKeys[I].DBTypeStr();
          S := '';
          if (TCBaseTable(Table).ForeignKeys[I].OnDelete = dtCascade) then S := 'cascade on delete';
          if (TCBaseTable(Table).ForeignKeys[I].OnDelete = dtSetNull) then S := 'set NULL on delete';
          if (TCBaseTable(Table).ForeignKeys[I].OnDelete = dtSetDefault) then S := 'set default on delete';
          if (TCBaseTable(Table).ForeignKeys[I].OnDelete = dtNoAction) then S := 'no action on delete';
          S2 := '';
          if (TCBaseTable(Table).ForeignKeys[I].OnUpdate = utCascade) then S2 := 'cascade on update';
          if (TCBaseTable(Table).ForeignKeys[I].OnUpdate = utSetNull) then S2 := 'set NULL on update';
          if (TCBaseTable(Table).ForeignKeys[I].OnUpdate = utSetDefault) then S2 := 'set default on update';
          if (TCBaseTable(Table).ForeignKeys[I].OnUpdate = utNoAction) then S2 := 'no action on update';
          if (S <> '') and (S2 <> '') then S := S + ', ';
          S := S + S2;
          GridData[I][2].Text := S;
        end;

        GridOut(GridData);
      end;
    end;

  if (Data) then
  begin
    if (Structure) then
    begin
      Canvas.Font.Assign(ContentFont);
      Canvas.Font.Size := Canvas.Font.Size + 2;
      Canvas.Font.Style := Canvas.Font.Style + [fsBold];

      ContentTextOut(Preferences.LoadStr(580) + ':', Padding);
    end;

    Canvas.Font.Assign(GridFont);

    if (Length(DBGrids) > 0) then
    begin
      for I := 0 to Length(DBGrids) - 1 do
        if (DBGrids[I].DBGrid.DataSource.DataSet = DataSet) then
        begin
          SetLength(Columns, Length(Fields));

          for J := 0 to Length(Fields) - 1 do
          begin
            Columns[J].HeaderBold := Fields[J].IsIndexField;
            if (J < Length(DestinationFields)) then
              Columns[J].HeaderText := DestinationFields[J].Name
            else
              Columns[J].HeaderText := Fields[J].DisplayName;


            if (Columns[J].HeaderBold) then Canvas.Font.Style := Canvas.Font.Style + [fsBold];

            if (GeometryField(Fields[J])) then
              Columns[J].Width := Canvas.TextWidth('<GEO>')
            else if (Fields[J].DataType = ftWideMemo) then
              Columns[J].Width := Canvas.TextWidth('<MEMO>')
            else if (Fields[J].DataType = ftBytes) then
              Columns[J].Width := Canvas.TextWidth('<BINARY>')
            else if (Fields[J].DataType = ftBlob) then
              Columns[J].Width := Canvas.TextWidth('<BLOB>')
            else
              Columns[J].Width := TMySQLDataSet(DBGrids[I].DBGrid.DataSource.DataSet).GetMaxTextWidth(Fields[J], Canvas.TextWidth);
            Columns[J].Width := Max(Columns[J].Width, Canvas.TextWidth(Columns[J].HeaderText));
            if (NullText and not Fields[J].Required) then
              Columns[J].Width := Max(Columns[J].Width, Canvas.TextWidth('<NULL>'));
            Columns[J].Width := Min(Columns[J].Width, ContentArea.Right - ContentArea.Left - 2 * Padding - 2 * LineWidth);

            if (Columns[J].HeaderBold) then Canvas.Font.Style := Canvas.Font.Style - [fsBold];
          end;
        end;
    end
    else
    begin
      for I := 0 to Length(ExportObjects) - 1 do
        if (ExportObjects[I].DBObject = Table) then
        begin
          SetLength(Columns, Length(Fields));

          for J := 0 to Length(Fields) - 1 do
          begin
            Columns[J].HeaderBold := Fields[J].IsIndexField;
            if (J < Length(DestinationFields)) then
              Columns[J].HeaderText := DestinationFields[J].Name
            else
              Columns[J].HeaderText := Fields[J].DisplayName;


            if (Columns[J].HeaderBold) then Canvas.Font.Style := Canvas.Font.Style + [fsBold];

            Columns[J].Width := Canvas.TextWidth(StringOfChar('e', MaxFieldsCharLengths[I][J]));
            Columns[J].Width := Max(Columns[J].Width, Canvas.TextWidth(Columns[J].HeaderText));
            if (NullText and not Fields[J].Required) then
              Columns[J].Width := Max(Columns[J].Width, Canvas.TextWidth('<NULL>'));
            Columns[J].Width := Min(Columns[J].Width, ContentArea.Right - ContentArea.Left - 2 * Padding - 2 * LineWidth);

            if (Columns[J].HeaderBold) then Canvas.Font.Style := Canvas.Font.Style - [fsBold];
          end;
        end;
    end;

    GridHeader();
  end;
end;

procedure TTExportCanvas.ExecuteTableRecord(const Table: TCTable; const Fields: array of TField; const DataSet: TMySQLQuery);

  function FieldText(const Field: TField): string;
  begin
    if (GeometryField(Field)) then
      Result := '<GEO>'
    else if (Field.DataType = ftWideMemo) then
      Result := '<MEMO>'
    else if (Field.DataType = ftBytes) then
      Result := '<BINARY>'
    else if (Field.DataType = ftBlob) then
      Result := '<BLOB>'
    else if (Field.IsNull and NULLText) then
      Result := '<NULL>'
    else
      Result := DataSet.GetAsString(Field.FieldNo);
  end;

var
  I: Integer;
  MaxRowHeight: Integer;
  Text: string;
  TextFormat: TTextFormat;
begin
  MaxRowHeight := 0;
  for I := 0 to Length(Fields) - 1 do
  begin
    Text := FieldText(Fields[I]);
    if (Fields[I].DataType in RightAlignedDataTypes) then
      TextFormat := [tfRight]
    else if (Fields[I].DataType in NotQuotedDataTypes) then
      TextFormat := []
    else
      TextFormat := [tfWordBreak];
    MaxRowHeight := Max(MaxRowHeight, GridTextOut(I, Text, [tfCalcRect] + TextFormat, Fields[I].IsIndexField, Fields[I].IsNull));
  end;

  if (AllocateHeight(MaxRowHeight + LineHeight)) then
    GridHeader();

  for I := 0 to Length(Fields) - 1 do
  begin
    Text := FieldText(Fields[I]);
    if (Fields[I].DataType in RightAlignedDataTypes) then
      TextFormat := [tfRight]
    else if (Fields[I].DataType in NotQuotedDataTypes) then
      TextFormat := []
    else
      TextFormat := [tfWordBreak];
    GridTextOut(I, Text, TextFormat, Fields[I].IsIndexField, Fields[I].IsNull);
  end;

  Inc(Y, MaxRowHeight);
  GridDrawHorzLine(Y);
end;

procedure TTExportCanvas.GridDrawHorzLine(const Y: Integer);
var
  I: Integer;
  X: Integer;
begin
  Canvas.Pen.Width := LineHeight;

  X := Columns[0].Left - LineWidth;
  Canvas := Columns[0].Canvas;
  for I := 0 to Length(Columns) do
  begin
    if ((I = Length(Columns)) or (Columns[I].Left < X)) then
    begin
      Canvas.MoveTo(ContentArea.Left, Y);
      Canvas.LineTo(X + LineWidth, Canvas.PenPos.Y);

      if (I < Length(Columns)) then
        X := Columns[I].Left - LineWidth;
    end;

    if (I < Length(Columns)) then
    begin
      Inc(X, Padding + Columns[I].Width + Padding + LineWidth);
      Canvas := Columns[I].Canvas;
    end;
  end;
end;

procedure TTExportCanvas.GridDrawVertLines();
var
  I: Integer;
begin
  Canvas.Pen.Width := LineWidth;
  for I := 0 to Length(Columns) - 1 do
  begin
    if ((I = 0) or (Columns[I].Canvas <> Canvas)) then
    begin
      Canvas := Columns[I].Canvas;

      // Left vertical line
      Canvas.MoveTo(ContentArea.Left, GridTop);
      Canvas.LineTo(Canvas.PenPos.X, Y);
    end;

    // Right column vertical line
    Canvas.MoveTo(Columns[I].Left + Padding + Columns[I].Width + Padding + LineHeight, GridTop);
    Canvas.LineTo(Canvas.PenPos.X, Y);
  end;
end;

procedure TTExportCanvas.GridHeader();
var
  I: Integer;
  R: TRect;
  Text: string;
  X: Integer;
begin
  GridTop := Y;

  Canvas.Font.Assign(GridFont);
  X := ContentArea.Left + LineWidth; Y := GridTop + LineWidth;

  for I := 0 to Length(Columns) - 1 do
  begin
    if (X + Columns[I].Width > ContentArea.Right) then
    begin
      PageBreak(False);

      Canvas.Font.Assign(GridFont);
      X := ContentArea.Left + LineWidth; Y := GridTop + LineWidth;
    end;

    Columns[I].Canvas := Canvas;
    Columns[I].Left := X;

    if (Columns[I].HeaderBold) then Canvas.Font.Style := Canvas.Font.Style + [fsBold];

    Text := Columns[I].HeaderText;
    R := Rect(Columns[I].Left + Padding, Y + Padding - 1, Columns[I].Left + Padding + Columns[I].Width + Padding - 1, Y + Padding + -Canvas.Font.Height + Padding);
    Canvas.TextRect(R, Text, []);

    if (Columns[I].HeaderBold) then Canvas.Font.Style := Canvas.Font.Style - [fsBold];

    Inc(X, Padding + Columns[I].Width + Padding + LineWidth);
  end;

  for I := 0 to Length(Columns) - 1 do
    Columns[I].Canvas.Font.Assign(GridFont);

  GridDrawHorzLine(GridTop);
  Inc(Y, R.Bottom - R.Top + Padding);
  GridDrawHorzLine(Y);
end;

procedure TTExportCanvas.GridOut(var GridData: TGridData);
var
  I: Integer;
  J: Integer;
  MaxRowHeight: Integer;
  Text: string;
begin
  Canvas.Font.Assign(GridFont);

  SetLength(Columns, Length(GridData[0]));
  for J := 0 to Length(Columns) - 1 do
  begin
    Columns[J].Width := Canvas.TextWidth(Columns[J].HeaderText);
    for I := 0 to Length(GridData) - 1 do
    begin
      if (GridData[I][J].Bold) then Canvas.Font.Style := Canvas.Font.Style + [fsBold];
      Columns[J].Width := Max(Columns[J].Width, Canvas.TextWidth(GridData[I][J].Text));
      if (GridData[I][J].Bold) then Canvas.Font.Style := Canvas.Font.Style - [fsBold];
    end;
    Columns[J].Width := Min(Columns[J].Width, ContentArea.Right - ContentArea.Left - 2 * Padding - 2 * LineWidth);
  end;

  GridHeader();

  for I := 0 to Length(GridData) - 1 do
  begin
    MaxRowHeight := 0;
    for J := 0 to Length(GridData[I]) - 1 do
    begin
      if (GridData[I][J].Bold) then Canvas.Font.Style := Canvas.Font.Style + [fsBold];
      Text := GridData[I][J].Text;
      MaxRowHeight := Max(MaxRowHeight, GridTextOut(J, Text, [tfCalcRect], False, False));
      if (GridData[I][J].Bold) then Canvas.Font.Style := Canvas.Font.Style - [fsBold];
    end;

    if (AllocateHeight(MaxRowHeight + LineHeight)) then
      GridHeader();

    for J := 0 to Length(GridData[I]) - 1 do
    begin
      if (GridData[I][J].Bold) then Canvas.Font.Style := Canvas.Font.Style + [fsBold];
      if (GridData[I][J].Gray) then Canvas.Font.Color := clGray;
      Text := GridData[I][J].Text;
      GridTextOut(J, Text, [], False, False);
      if (GridData[I][J].Gray) then Canvas.Font.Color := clBlack;
      if (GridData[I][J].Bold) then Canvas.Font.Style := Canvas.Font.Style - [fsBold];
    end;

    Inc(Y, MaxRowHeight);
    GridDrawHorzLine(Y);
  end;

  GridDrawVertLines();

  Inc(Y, -Canvas.Font.Height);

  for J := 0 to Length(GridData) - 1 do
    SetLength(GridData[J], 0);
  SetLength(GridData, 0);
  SetLength(Columns, 0);
end;

function TTExportCanvas.GridTextOut(const Column: Integer; Text: string; const TextFormat: TTextFormat; const Bold, Gray: Boolean): Integer;
var
  CalcR: TRect;
  R: TRect;
begin
  if (Bold) then Columns[Column].Canvas.Font.Style := Columns[Column].Canvas.Font.Style + [fsBold];

  R := Rect(Columns[Column].Left + Padding, Y + Padding - 1, Columns[Column].Left + Padding + Columns[Column].Width + Padding - 1, Y + Padding + -Canvas.Font.Height + Padding);
  CalcR := R;
  Windows.DrawText(Columns[Column].Canvas.Handle, PChar(Text), Length(Text), CalcR, TTextFormatFlags([tfCalcRect] + TextFormat));
  R.Bottom := CalcR.Bottom;

  if (Text <> '') then
  begin
    if (Gray) then Columns[Column].Canvas.Font.Color := clGray;

    if ((CalcR.Right > R.Right) or (CalcR.Bottom > R.Bottom) or (tfRight in TextFormat)) then
      Windows.DrawText(Columns[Column].Canvas.Handle, PChar(Text), Length(Text), R, TTextFormatFlags(TextFormat))
    else
      Windows.ExtTextOut(Columns[Column].Canvas.Handle, R.Left, R.Top, ETO_CLIPPED, R, Text, Length(Text), nil);

    if (Gray) then Columns[Column].Canvas.Font.Color := clBlack;
  end;

  Result := R.Bottom - Y;

  if (Bold) then Columns[Column].Canvas.Font.Style := Columns[Column].Canvas.Font.Style - [fsBold];
end;

procedure TTExportCanvas.PageBreak(const NewPageRow: Boolean);
var
  Font: TFont;
begin
  if (not Assigned(Canvas)) then
    Font := nil
  else
  begin
    Font := TFont.Create();
    Font.Assign(Canvas.Font);
    PageFooter();
  end;

  if (not NewPageRow) then
    Inc(PageNumber.Column)
  else
  begin
    Inc(PageNumber.Row);
    PageNumber.Column := 0;
  end;

  AddPage(NewPageRow);

  if (Assigned(Font)) then
  begin
    Canvas.Font.Assign(Font);
    Font.Free();
  end;

  Y := ContentArea.Top;
end;

procedure TTExportCanvas.PageFooter();
var
  R: TRect;
  Text: string;
begin
  Y := ContentArea.Bottom + 5 * Padding;

  Canvas.Pen.Width := LineHeight;
  // Horizontal line
  Canvas.MoveTo(ContentArea.Left, Y);
  Canvas.LineTo(ContentArea.Right, Canvas.PenPos.Y);

  Inc (Y, LineHeight + Padding);


  Canvas.Font.Assign(PageFont);

  R := Rect(ContentArea.Left, Y, ContentArea.Right, PageHeight);
  Text := SysUtils.DateTimeToStr(DateTime, LocaleFormatSettings);
  Canvas.TextRect(R, Text, []);

  R := Rect(ContentArea.Left, Y, ContentArea.Right, PageHeight);
  Text := Client.Account.Connection.Host;
  if (Client.Account.Connection.Port <> MYSQL_PORT) then
    Text := Text + ':' + IntToStr(Client.Account.Connection.Port);
  Text := Text + '  (MySQL: ' + Client.ServerVersionStr + ')';
  Canvas.TextRect(R, Text, [tfCenter]);

  R := Rect(ContentArea.Left, Y, ContentArea.Right, PageHeight);
  Text := IntToStr(PageNumber.Row);
  if (PageNumber.Column > 0) then
    Text := Text + Chr(Ord('a') - 1 + PageNumber.Column);
  Canvas.TextRect(R, Text, [tfRight]);
end;

{ TTExportPrint ***************************************************************}

procedure TTExportPrint.AddPage(const NewPageRow: Boolean);
begin
  if (NewPageRow) then
  begin
    Printer.NewPage();
    Canvas := Printer.Canvas;
  end;
end;

constructor TTExportPrint.Create(const AClient: TCClient; const ATitle: string);
begin
  Printer := TPrinter.Create();
  Printer.Title := ATitle;

  PageWidth := Printer.PageWidth;
  PageHeight := Printer.PageHeight;

  Margins.Left := GetDeviceCaps(Printer.Handle, LOGPIXELSX) * MarginsMilliInch.Left div 1000;
  Margins.Top := GetDeviceCaps(Printer.Handle, LOGPIXELSY) * MarginsMilliInch.Top div 1000;
  Margins.Right := GetDeviceCaps(Printer.Handle, LOGPIXELSX) * MarginsMilliInch.Right div 1000;
  Margins.Bottom := GetDeviceCaps(Printer.Handle, LOGPIXELSY) * MarginsMilliInch.Bottom div 1000;

  Padding := GetDeviceCaps(Printer.Handle, LOGPIXELSY) * PaddingMilliInch div 1000;

  LineWidth := GetDeviceCaps(Printer.Handle, LOGPIXELSX) * LineWidthMilliInch div 1000;
  LineHeight := GetDeviceCaps(Printer.Handle, LOGPIXELSY) * LineHeightMilliInch div 1000;

  Canvas := Printer.Canvas;

  inherited Create(AClient);
end;

destructor TTExportPrint.Destroy();
begin
  Printer.EndDoc();

  inherited;

  Printer.Free();
end;

procedure TTExportPrint.ExecuteFooter();
begin
  inherited;
end;

procedure TTExportPrint.ExecuteHeader();
var
  Error: TError;
begin
  while ((Success <> daAbort) and not Printer.Printing) do
    try
      Printer.BeginDoc();
      if (GetLastError() > 0) then
        DoError(SysError(), EmptyToolsItem(), False);
      Canvas := Printer.Canvas;
    except
      on E: EPrinter do
        begin
          Error.ErrorType := TE_Printer;
          Error.ErrorCode := 1;
          Error.ErrorMessage := E.Message;
          DoError(Error, EmptyToolsItem(), False);
        end;
    end;

  inherited;
end;

{ TTExportPDF *****************************************************************}

procedure TTExportPDF.AddPage(const NewPageRow: Boolean);
begin
  PDF.AddPage();

  Canvas := PDF.VCLCanvas;
end;

constructor TTExportPDF.Create(const AClient: TCClient; const AFilename: TFileName);
begin
  PDF := TPDFDocumentGDI.Create(False, CP_UTF8, False);
  PDF.DefaultPaperSize := CurrentPrinterPaperSize();
  PDF.Info.Data.AddItemTextString('Producer', SysUtils.LoadStr(1000));
  AddPage(True);

  PageWidth := Trunc(Integer(PDF.DefaultPageWidth) * GetDeviceCaps(Canvas.Handle, LOGPIXELSX) / 72); // PDF expect 72 pixels per inch
  PageHeight := Trunc(Integer(PDF.DefaultPageHeight) * GetDeviceCaps(Canvas.Handle, LOGPIXELSY) / 72); // PDF expect 72 pixels per inch

  Margins.Left := GetDeviceCaps(Canvas.Handle, LOGPIXELSX) * MarginsMilliInch.Left div 1000;
  Margins.Top := GetDeviceCaps(Canvas.Handle, LOGPIXELSY) * MarginsMilliInch.Top div 1000;
  Margins.Right := GetDeviceCaps(Canvas.Handle, LOGPIXELSX) * MarginsMilliInch.Right div 1000;
  Margins.Bottom := GetDeviceCaps(Canvas.Handle, LOGPIXELSY) * MarginsMilliInch.Bottom div 1000;

  Padding := Round(GetDeviceCaps(Canvas.Handle, LOGPIXELSY) * PaddingMilliInch / 1000);

  LineWidth := Round(GetDeviceCaps(Canvas.Handle, LOGPIXELSX) * LineWidthMilliInch / 1000);
  LineHeight := Round(GetDeviceCaps(Canvas.Handle, LOGPIXELSY) * LineHeightMilliInch / 1000);

  inherited Create(AClient);

  Filename := AFilename;
end;

destructor TTExportPDF.Destroy();
begin
  inherited;

  PDF.Free();
end;

procedure TTExportPDF.ExecuteFooter();
begin
  inherited;

  while ((Success <> daAbort) and not PDF.SaveToFile(Filename)) do
    DoError(SysError(), EmptyToolsItem(), True);
end;

procedure TTExportPDF.ExecuteHeader();
begin
  while (FileExists(Filename) and not DeleteFile(Filename)) do
    DoError(SysError(), EmptyToolsItem(), True);

  inherited;
end;

{ TTFind **********************************************************************}

procedure TTFind.Add(const Table: TCBaseTable; const Field: TCTableField = nil);
var
  Found: Boolean;
  I: Integer;
begin
  SetLength(Items, Length(Items) + 1);

  Items[Length(Items) - 1].DatabaseName := Table.Database.Name;
  Items[Length(Items) - 1].TableName := Table.Name;
  SetLength(Items[Length(Items) - 1].FieldNames, 0);
  Items[Length(Items) - 1].RecordsSum := 0;
  Items[Length(Items) - 1].RecordsFound := 0;
  Items[Length(Items) - 1].RecordsDone := 0;
  Items[Length(Items) - 1].Done := False;

  if (Assigned(Field)) then
  begin
    Found := False;
    for I := 0 to Length(Items[Length(Items) - 1].FieldNames) - 1 do
      Found := Found or (Items[Length(Items) - 1].FieldNames[I] = Field.Name);
    if (not Found) then
    begin
      SetLength(Items[Length(Items) - 1].FieldNames, Length(Items[Length(Items) - 1].FieldNames) + 1);
      Items[Length(Items) - 1].FieldNames[Length(Items[Length(Items) - 1].FieldNames) - 1] := Field.Name;
    end;
  end;
end;

procedure TTFind.AfterExecute();
begin
  Client.EndSilent();
  Client.EndSynchron();

  inherited;
end;

procedure TTFind.BeforeExecute();
begin
  inherited;

  Client.BeginSilent();
  Client.BeginSynchron(); // We're still in a thread
end;

constructor TTFind.Create(const AClient: TCClient);
begin
  inherited Create();

  FClient := AClient;

  SetLength(Items, 0);
  FItem := nil;
end;

destructor TTFind.Destroy();
var
  I: Integer;
begin
  for I := 0 to Length(Items) - 1 do
    SetLength(Items[I].FieldNames, 0);
  SetLength(Items, 0);

  inherited;
end;

function TTFind.DoExecuteSQL(const Client: TCClient; var Item: TItem; var SQL: string): Boolean;
begin
  Result := (Success = daSuccess) and Client.ExecuteSQL(SQL);
  Delete(SQL, 1, Client.ExecutedSQLLength);
  SQL := SysUtils.Trim(SQL);
end;

procedure TTFind.Execute();
var
  Database: TCDatabase;
  I: Integer;
  J: Integer;
  Table: TCBaseTable;
begin
  BeforeExecute();

  for I := 0 to Length(Items) - 1 do
  begin
    FItem := @Items[I];

    if (Success = daSuccess) then
    begin
      Table := Client.DatabaseByName(Items[I].DatabaseName).BaseTableByName(Items[I].TableName);

      if (Length(Items[I].FieldNames) = 0) then
      begin
        SetLength(Items[I].FieldNames, Table.Fields.Count);
        for J := 0 to Table.Fields.Count - 1 do
          Items[I].FieldNames[J] := Table.Fields[J].Name;
      end;

      if (Table.Rows >= 0) then
        Items[I].RecordsSum := Table.Rows
      else
        Items[I].RecordsSum := Table.CountRecords();

      DoUpdateGUI();
    end;

    FItem := nil;
  end;

  for I := 0 to Length(Items) - 1 do
  begin
    FItem := @Items[I];

    if (Success = daSuccess) then
    begin
      if ((Self is TTReplace) and TTReplace(Self).Backup) then
      begin
        BackupTable(ToolsItem(Items[I]));
        if (Success = daFail) then Success := daSuccess;
      end;

      if (Success = daSuccess) then
      begin
        Database := Client.DatabaseByName(Items[I].DatabaseName);
        Table := Database.BaseTableByName(Items[I].TableName);

        if (RegExpr or (not WholeValue and not MatchCase)) then
          ExecuteDefault(Items[I], Table)
        else if (WholeValue) then
          ExecuteWholeValue(Items[I], Table)
        else
          ExecuteMatchCase(Items[I], Table);
      end;

      Items[I].Done := Success <> daAbort;

      if (Success = daFail) then Success := daSuccess;

      DoUpdateGUI();
    end;

    FItem := nil;
  end;

  AfterExecute();
end;

procedure TTFind.ExecuteDefault(var Item: TItem; const Table: TCBaseTable);
var
  Buffer: TStringBuffer;
  DataSet: TMySQLQuery;
  Fields: array of TField;
  Found: Boolean;
  I: Integer;
  J: Integer;
  NewValue: string;
  PerlRegEx: TPerlRegEx;
  SQL: string;
  Value: string;
  WhereClausel: string;
  UseIndexFields: Boolean;
begin
  if (Success = daSuccess) then
  begin
    if (not (Self is TTReplace) and not RegExpr) then
      SQL := 'COUNT(*)'
    else if (Length(Item.FieldNames) = Table.Fields.Count) then
      SQL := '*'
    else
    begin
      SQL := '';
      for I := 0 to Table.Fields.Count - 1 do
        if (Table.Fields[I].InPrimaryKey) then
        begin
          if (SQL <> '') then SQL := SQL + ',';
          SQL := SQL + Client.EscapeIdentifier(Table.Fields[I].Name);
        end
        else
          for J := 0 to Length(Item.FieldNames) - 1 do
            if (Item.FieldNames[J] = Table.Fields[I].Name) then
            begin
              if (SQL <> '') then SQL := SQL + ',';
              SQL := SQL + Client.EscapeIdentifier(Table.Fields[J].Name);
            end;
    end;

    WhereClausel := '';
    for I := 0 to Length(Item.FieldNames) - 1 do
    begin
      if (I > 0) then WhereClausel := WhereClausel + ' OR ';
      if (not RegExpr) then
        WhereClausel := WhereClausel + Client.EscapeIdentifier(Item.FieldNames[I]) + ' LIKE ' + SQLEscape('%' + FindText + '%')
      else
        WhereClausel := WhereClausel + Client.EscapeIdentifier(Item.FieldNames[I]) + ' REGEXP ' + SQLEscape(FindText);
    end;
    SQL := 'SELECT ' + SQL + ' FROM ' + Client.EscapeIdentifier(Item.DatabaseName) + '.' + Client.EscapeIdentifier(Item.TableName) + ' WHERE ' + WhereClausel;

    DataSet := TMySQLQuery.Create(nil);
    DataSet.Connection := Client;
    DataSet.CommandText := SQL;

    while ((Success <> daAbort) and not DataSet.Active) do
    begin
      DataSet.Open();
      if (not DataSet.Active) then
        DoError(DatabaseError(Client), ToolsItem(Item), True, SQL);
    end;

    if (Success = daSuccess) then
    begin
     if (DataSet.IsEmpty()) then
        Item.RecordsFound := 0
      else if (not (Self is TTReplace) and not RegExpr) then
        Item.RecordsFound := DataSet.Fields[0].AsInteger
      else
      begin
        SetLength(Fields, 0);
        for I := 0 to Length(Item.FieldNames) - 1 do
          if (Assigned(DataSet.FindField(Item.FieldNames[I]))) then
          begin
            SetLength(Fields, Length(Fields) + 1);
            Fields[Length(Fields) - 1] := DataSet.FindField(Item.FieldNames[I]);
          end;

        if (not RegExpr) then
          PerlRegEx := nil
        else
        begin
          PerlRegEx := TPerlRegEx.Create();
          PerlRegEx.RegEx := UTF8Encode(FindText);
          if (MatchCase) then
            PerlRegEx.Options := PerlRegEx.Options - [preCaseLess]
          else
            PerlRegEx.Options := PerlRegEx.Options + [preCaseLess];
          PerlRegEx.Study();
          if (Self is TTReplace) then
            PerlRegEx.Replacement := UTF8Encode(TTReplace(Self).ReplaceText);
        end;

        UseIndexFields := False;
        if (not (Self is TTReplace)) then
          Buffer := nil
        else
        begin
          TTReplace(Self).ReplaceConnection.StartTransaction();

          Buffer := TStringBuffer.Create(SQLPacketSize);

          if (Item.DatabaseName <> TTReplace(Self).ReplaceConnection.DatabaseName) then
            Buffer.Write(TTReplace(Self).ReplaceConnection.SQLUse(Item.DatabaseName));

          for I := 0 to DataSet.FieldCount - 1 do
            UseIndexFields := UseIndexFields or Fields[I].IsIndexField;
        end;

        repeat
          Found := False; SQL := '';
          for I := 0 to Length(Fields) - 1 do
            if (Assigned(DataSet.LibRow^[Fields[I].FieldNo - 1])) then
            begin
              Value := DataSet.GetAsString(Fields[I].FieldNo);

              if (not (Self is TTReplace)) then
                if (not RegExpr) then
                  // will never occur, since without RegExpr COUNT(*) will be used
                else
                begin
                  // not MatchCase, since otherwise ExecuteMatchCase will be used
                  PerlRegEx.Subject := UTF8Encode(Value);
                  Found := Found or PerlRegEx.Match();
                end
              else
              begin
                if (not RegExpr) then
                begin
                  // not MatchCase, since otherwise ExecuteMatchCase will be used
                  NewValue := StringReplace(Value, FindText, TTReplace(Self).ReplaceText, [rfReplaceAll, rfIgnoreCase]);
                  Found := NewValue <> Value;
                end
                else
                begin
                  PerlRegEx.Subject := UTF8Encode(Value);
                  Found := PerlRegEx.ReplaceAll();
                  if (Found) then
                    NewValue := UTF8ToWideString(PerlRegEx.Subject);
                end;

                if (Found) then
                begin
                  if (SQL <> '') then SQL := SQL + ',';
                  SQL := SQL + Client.EscapeIdentifier(Fields[I].FieldName) + '=';
                  if (BitField(Fields[I])) then
                    SQL := SQL + NewValue
                  else if (Fields[I].DataType in NotQuotedDataTypes + [ftTimestamp]) then
                    SQL := SQL + NewValue
                  else if (Fields[I].DataType in [ftDate, ftDateTime, ftTime]) then
                    SQL := SQL + '''' + NewValue + ''''
                  else
                    SQL := SQL + SQLEscape(NewValue);
                end;
              end;
            end;

          if (not (Self is TTReplace)) then
          begin
            if (Found) then
              Inc(Item.RecordsFound);
          end
          else
            if (SQL <> '') then
            begin
              Inc(Item.RecordsFound);

              SQL := 'UPDATE ' + Client.EscapeIdentifier(Item.TableName) + ' SET ' + SQL + ' WHERE ';
              Found := False;
              for I := 0 to Length(Fields) - 1 do
                if (not UseIndexFields or Fields[I].IsIndexField) then
                begin
                  if (Found) then SQL := SQL + ' AND ';
                  SQL := SQL + Client.EscapeIdentifier(Fields[I].FieldName) + '=';
                  if (not Assigned(DataSet.LibRow^[I])) then
                    SQL := SQL + 'NULL'
                  else if (BitField(Fields[I])) then
                    SQL := SQL + 'b''' + Fields[I].AsString + ''''
                  else if (Fields[I].DataType in NotQuotedDataTypes + [ftTimestamp]) then
                    SQL := SQL + DataSet.GetAsString(Fields[I].FieldNo)
                  else if (Fields[I].DataType in [ftDate, ftDateTime, ftTime]) then
                    SQL := SQL + '''' + DataSet.GetAsString(Fields[I].FieldNo) + ''''
                  else
                    SQL := SQL + SQLEscape(DataSet.GetAsString(Fields[I].FieldNo));
                  Found := True;
                end;
              SQL := SQL + ';' + #13#10;

              Buffer.Write(SQL);

              if ((Buffer.Size > 0) and (not Client.MultiStatements or (Buffer.Size >= SQLPacketSize))) then
              begin
                SQL := Buffer.Read();
                DoExecuteSQL(TTReplace(Self).ReplaceConnection, Item, SQL);
                Buffer.Write(SQL);
              end;
            end;

          Inc(Item.RecordsDone);
          if (Item.RecordsDone mod 100 = 0) then DoUpdateGUI();

          if (UserAbort.WaitFor(IGNORE) = wrSignaled) then
            Success := daAbort;
        until ((Success <> daSuccess) or not DataSet.FindNext());

        if (Buffer.Size > 0) then
        begin
          SQL := Buffer.Read();
          DoExecuteSQL(TTReplace(Self).ReplaceConnection, Item, SQL);
        end;

        Buffer.Free();

        if (Self is TTReplace) then
        begin
          if (Success = daSuccess) then
            TTReplace(Self).ReplaceConnection.CommitTransaction()
          else
            TTReplace(Self).ReplaceConnection.RollbackTransaction();
        end;

        if (Assigned(PerlRegEx)) then
          PerlRegEx.Free();
      end;
    end;

    DataSet.Free();
  end;
end;

procedure TTFind.ExecuteMatchCase(var Item: TItem; const Table: TCBaseTable);
var
  DataSet: TMySQLQuery;
  I: Integer;
  SQL: string;
begin
  SQL := '';
  for I := 0 to Length(Item.FieldNames) - 1 do
  begin
    if (I > 0) then SQL := SQL + ' OR ';
    SQL := SQL + 'BINARY(' + Client.EscapeIdentifier(Item.FieldNames[I]) + ') LIKE BINARY(' + SQLEscape('%' + FindText + '%') + ')';
  end;
  SQL := 'SELECT COUNT(*) FROM ' + Client.EscapeIdentifier(Table.Database.Name) + '.' + Client.EscapeIdentifier(Table.Name) + ' WHERE ' + SQL;

  DataSet := TMySQLQuery.Create(nil);
  DataSet.Connection := Client;
  DataSet.CommandText := SQL;
  while ((Success <> daAbort) and not DataSet.Active) do
  begin
    DataSet.Open();
    if (Client.ErrorCode > 0) then
      DoError(DatabaseError(Client), ToolsItem(Item), True, SQL);
  end;

  if ((Success = daSuccess) and not DataSet.IsEmpty()) then
    Item.RecordsFound := DataSet.Fields[0].AsInteger;

  DataSet.Free();
end;

procedure TTFind.ExecuteWholeValue(var Item: TItem; const Table: TCBaseTable);
var
  DataSet: TMySQLQuery;
  I: Integer;
  SQL: string;
begin
  SQL := '';
  for I := 0 to Length(Item.FieldNames) - 1 do
  begin
    if (I > 0) then SQL := SQL + ' OR ';
    if (MatchCase) then
      SQL := SQL + 'BINARY(' + Client.EscapeIdentifier(Item.FieldNames[I]) + ')=BINARY(' + SQLEscape(FindText) + ')'
    else
      SQL := SQL + Client.EscapeIdentifier(Item.FieldNames[I]) + '=' + SQLEscape(FindText)
  end;
  SQL := 'SELECT COUNT(*) FROM ' + Client.EscapeIdentifier(Table.Database.Name) + '.' + Client.EscapeIdentifier(Table.Name) + ' WHERE ' + SQL;

  DataSet := TMySQLQuery.Create(nil);
  DataSet.Connection := Client;
  DataSet.CommandText := SQL;

  while ((Success <> daAbort) and not DataSet.Active) do
  begin
    DataSet.Open();
    if (Client.ErrorCode > 0) then
      DoError(DatabaseError(Client), ToolsItem(Item), True, SQL);
  end;

  if ((Success = daSuccess) and not DataSet.IsEmpty()) then
    Item.RecordsFound := DataSet.Fields[0].AsInteger;

  FreeAndNil(DataSet);

  if (Self is TTReplace) then
  begin
    SQL := '';
    if (Client.DatabaseName = Table.Database.Name) then
      SQL := SQL + Table.Database.SQLUse();

    for I := 0 to Length(Item.FieldNames) - 1 do
    begin
      SQL := SQL + 'UPDATE ' + Client.EscapeIdentifier(Table.Database.Name) + '.' + Client.EscapeIdentifier(Item.TableName);
      SQL := SQL + ' SET ' + Client.EscapeIdentifier(Item.FieldNames[I]) + '=' + SQLEscape(TTReplace(Self).ReplaceText);
      if (MatchCase) then
        SQL := SQL + ' WHERE BINARY(' + Client.EscapeIdentifier(Item.FieldNames[I]) + ')=BINARY(' + SQLEscape(FindText) + ')'
      else
        SQL := SQL + ' WHERE ' + Client.EscapeIdentifier(Item.FieldNames[I]) + '=' + SQLEscape(FindText);
      SQL := SQL + ';' + #13#10;
    end;

    while ((Success <> daAbort) and not DoExecuteSQL(TTReplace(Self).ReplaceConnection, Item, SQL)) do
      if (Client.ErrorCode = ER_TRUNCATED_WRONG_VALUE) then
      begin
        Delete(SQL, 1, Length(Client.CommandText));
        Success := daSuccess;
      end
      else
        DoError(DatabaseError(Client), ToolsItem(Item), True, SQL);

    Item.RecordsDone := Item.RecordsSum;
  end;
end;

function TTFind.ToolsItem(const Item: TItem): TTools.TItem;
begin
  Result.Client := Client;
  Result.DatabaseName := Item.DatabaseName;
  Result.TableName := Item.TableName;
end;

procedure TTFind.DoUpdateGUI();
var
  I: Integer;
begin
  if (Assigned(OnUpdate)) then
  begin
    CriticalSection.Enter();

    ProgressInfos.TablesDone := 0;
    ProgressInfos.TablesSum := Length(Items);
    ProgressInfos.RecordsDone := 0;
    ProgressInfos.RecordsSum := 0;
    ProgressInfos.TimeDone := 0;
    ProgressInfos.TimeSum := 0;

    for I := 0 to Length(Items) - 1 do
    begin
      if (Items[I].Done) then
      begin
        Inc(ProgressInfos.TablesDone);
        Inc(ProgressInfos.RecordsDone, Items[I].RecordsSum);
      end;

      Inc(ProgressInfos.RecordsSum, Items[I].RecordsSum);
    end;

    ProgressInfos.TimeDone := Now() - StartTime;

    if ((ProgressInfos.RecordsDone = 0) and (ProgressInfos.TablesDone = 0)) then
    begin
      ProgressInfos.Progress := 0;
      ProgressInfos.TimeSum := 0;
    end
    else if (ProgressInfos.TablesDone < ProgressInfos.TablesSum) then
    begin
      ProgressInfos.Progress := Round(ProgressInfos.TablesDone / ProgressInfos.TablesSum * 100);
      ProgressInfos.TimeSum := ProgressInfos.TimeDone / ProgressInfos.TablesDone * ProgressInfos.TablesSum;
    end
    else
    begin
      ProgressInfos.Progress := 100;
      ProgressInfos.TimeSum := ProgressInfos.TimeDone;
    end;

    CriticalSection.Leave();

    OnUpdate(ProgressInfos);
  end;
end;

{ TTReplace *******************************************************************}

constructor TTReplace.Create(const AClient, AReplaceClient: TCClient);
begin
  inherited Create(AClient);

  FReplaceClient := AReplaceClient;
end;

procedure TTReplace.ExecuteMatchCase(var Item: TTFind.TItem; const Table: TCBaseTable);
var
  I: Integer;
  SQL: string;
begin
  SQL := '';
  for I := 0 to Length(Item.FieldNames) - 1 do
  begin
    if (I > 0) then SQL := SQL + ',';
    SQL := SQL + Client.EscapeIdentifier(Item.FieldNames[I]) + '=REPLACE(' + Client.EscapeIdentifier(Item.FieldNames[I]) + ',' + SQLEscape(FindText) + ',' + SQLEscape(ReplaceText) + ')';
  end;
  SQL := 'UPDATE ' + Client.EscapeIdentifier(Item.DatabaseName) + '.' + Client.EscapeIdentifier(Item.TableName) + ' SET ' + SQL + ';';

  while ((Success <> daAbort) and not Client.ExecuteSQL(SQL)) do
    DoError(DatabaseError(Client), ToolsItem(Item), True, SQL);

  Item.RecordsDone := Client.RowsAffected;
  Item.RecordsSum := Item.RecordsDone;
end;

{ TTTransfer  ******************************************************************}

procedure TTTransfer.Add(const SourceClient: TCClient; const SourceDatabaseName, SourceTableName: string; const DestinationClient: TCClient; const DestinationDatabaseName, DestinationTableName: string);
var
  Element: ^TElement;
begin
  GetMem(Element, SizeOf(Element^));
  ZeroMemory(Element, SizeOf(Element^));

  Element^.Source.Client := SourceClient;
  Element^.Source.DatabaseName := SourceDatabaseName;
  Element^.Source.TableName := SourceTableName;
  Element^.Destination.Client := DestinationClient;
  Element^.Destination.DatabaseName := DestinationDatabaseName;
  Element^.Destination.TableName := DestinationTableName;

  Elements.Add(Element);
end;

procedure TTTransfer.AfterExecute();
begin
  if (Elements.Count > 0) then
  begin
    TElement(Elements[0]^).Source.Client.EndSilent();
    TElement(Elements[0]^).Source.Client.EndSynchron();

    TElement(Elements[0]^).Destination.Client.EndSilent();
    TElement(Elements[0]^).Destination.Client.EndSynchron();
  end;

  inherited;
end;

procedure TTTransfer.BeforeExecute();
begin
  inherited;

  if (Elements.Count > 0) then
  begin
    TElement(Elements[0]^).Source.Client.BeginSilent();
    TElement(Elements[0]^).Source.Client.BeginSynchron(); // We're still in a thread

    TElement(Elements[0]^).Destination.Client.BeginSilent();
    TElement(Elements[0]^).Destination.Client.BeginSynchron(); // We're still in a thread
  end;
end;

procedure TTTransfer.CloneTable(var Source, Destination: TItem);
var
  DestinationDatabase: TCDatabase;
  SourceDatabase: TCDatabase;
  SourceTable: TCBaseTable;
begin
  SourceDatabase := Source.Client.DatabaseByName(Source.DatabaseName);
  DestinationDatabase := Destination.Client.DatabaseByName(Destination.DatabaseName);

  SourceTable := SourceDatabase.BaseTableByName(Source.TableName);

  while ((Success <> daAbort) and not DestinationDatabase.CloneTable(SourceTable, Destination.TableName, Data)) do
    DoError(DatabaseError(Source.Client), ToolsItem(Destination), True);

  if (Success = daSuccess) then
  begin
    Destination.Done := True;
    if (Data) then
    begin
      Destination.RecordsSum := DestinationDatabase.BaseTableByName(Destination.TableName).CountRecords();
      Destination.RecordsDone := Destination.RecordsSum;
    end;
  end;

  DoUpdateGUI();
end;

constructor TTTransfer.Create();
begin
  inherited;

  Elements := TList.Create();
end;

destructor TTTransfer.Destroy();
begin
  while (Elements.Count > 0) do
  begin
    TElement(Elements[0]^).Source.DatabaseName := '';
    TElement(Elements[0]^).Source.TableName := '';
    TElement(Elements[0]^).Destination.DatabaseName := '';
    TElement(Elements[0]^).Destination.TableName := '';
    FreeMem(Elements[0]);
    Elements.Delete(0);
  end;
  Elements.Free();

  inherited;
end;

function TTTransfer.DifferentPrimaryIndexError(): TTools.TError;
begin
  Result.ErrorType := TE_DifferentPrimaryIndex;
end;

function TTTransfer.DoExecuteSQL(var Item: TItem; const Client: TCClient; var SQL: string): Boolean;
begin
  Result := (Success = daSuccess) and Client.ExecuteSQL(SQL);
  Delete(SQL, 1, Client.ExecutedSQLLength);
  SQL := SysUtils.Trim(SQL);
end;

procedure TTTransfer.DoUpdateGUI();
var
  I: Integer;
begin
  if (Assigned(OnUpdate)) then
  begin
    CriticalSection.Enter();

    ProgressInfos.TablesDone := 0;
    ProgressInfos.TablesSum := Elements.Count;
    ProgressInfos.RecordsDone := 0;
    ProgressInfos.RecordsSum := 0;
    ProgressInfos.TimeDone := 0;
    ProgressInfos.TimeSum := 0;

    for I := 0 to Elements.Count - 1 do
    begin
      if (TElement(Elements[I]^).Destination.Done) then
        Inc(ProgressInfos.TablesDone);
      Inc(ProgressInfos.RecordsDone, TElement(Elements[I]^).Destination.RecordsDone);
      Inc(ProgressInfos.RecordsSum, TElement(Elements[I]^).Destination.RecordsSum);
    end;

    ProgressInfos.TimeDone := Now() - StartTime;

    if ((ProgressInfos.RecordsDone = 0) and (ProgressInfos.TablesDone = 0)) then
    begin
      ProgressInfos.Progress := 0;
      ProgressInfos.TimeSum := 0;
    end
    else if (ProgressInfos.RecordsDone = 0) then
    begin
      ProgressInfos.Progress := Round(ProgressInfos.TablesDone / ProgressInfos.TablesSum * 100);
      ProgressInfos.TimeSum := ProgressInfos.TimeDone / ProgressInfos.TablesDone * ProgressInfos.TablesSum;
    end
    else if (ProgressInfos.RecordsDone < ProgressInfos.RecordsSum) then
    begin
      ProgressInfos.Progress := Round(ProgressInfos.RecordsDone / ProgressInfos.RecordsSum * 100);
      ProgressInfos.TimeSum := ProgressInfos.TimeDone / ProgressInfos.RecordsDone * ProgressInfos.RecordsSum;
    end
    else
    begin
      ProgressInfos.Progress := 100;
      ProgressInfos.TimeSum := ProgressInfos.TimeDone;
    end;

    CriticalSection.Leave();

    OnUpdate(ProgressInfos);
  end;
end;

procedure TTTransfer.Execute();
var
  DataSet: TMySQLQuery;
  DestinationClient: TCClient;
  I: Integer;
  J: Integer;
  OLD_FOREIGN_KEY_CHECKS: string;
  OLD_UNIQUE_CHECKS: string;
  SourceClient: TCClient;
  SourceTable: TCBaseTable;
  SQL: string;
begin
  SourceClient := TElement(Elements[0]^).Source.Client;
  DestinationClient := TElement(Elements[0]^).Destination.Client;

  BeforeExecute();

  for I := 0 to Elements.Count - 1 do
  begin
    SourceTable := SourceClient.DatabaseByName(TElement(Elements[I]^).Source.DatabaseName).BaseTableByName(TElement(Elements[I]^).Source.TableName);

    TElement(Elements[I]^).Source.Done := False;
    TElement(Elements[I]^).Destination.Done := False;

    TElement(Elements[I]^).Source.RecordsSum := 0;
    TElement(Elements[I]^).Source.RecordsDone := 0;

    TElement(Elements[I]^).Destination.RecordsSum := SourceTable.Rows;
    TElement(Elements[I]^).Destination.RecordsDone := 0;

    DoUpdateGUI();
  end;

  if (Data and (DestinationClient.ServerVersion >= 40014)) then
  begin
    if (Assigned(DestinationClient.VariableByName('UNIQUE_CHECKS'))
      and Assigned(DestinationClient.VariableByName('FOREIGN_KEY_CHECKS'))) then
    begin
      OLD_UNIQUE_CHECKS := DestinationClient.VariableByName('UNIQUE_CHECKS').Value;
      OLD_FOREIGN_KEY_CHECKS := DestinationClient.VariableByName('FOREIGN_KEY_CHECKS').Value;
    end
    else
    begin
      DataSet := TMySQLQuery.Create(nil);
      DataSet.Connection := DestinationClient;
      DataSet.CommandText := 'SELECT @@UNIQUE_CHECKS, @@FOREIGN_KEY_CHECKS';

      while ((Success <> daAbort) and not DataSet.Active) do
      begin
        DataSet.Open();
        if (DestinationClient.ErrorCode > 0) then
          DoError(DatabaseError(DestinationClient), ToolsItem(TElement(Elements[0]^).Destination), True, SQL);
      end;

      if (DataSet.Active) then
      begin
        OLD_UNIQUE_CHECKS := DataSet.Fields[0].AsString;
        OLD_FOREIGN_KEY_CHECKS := DataSet.Fields[1].AsString;
        DataSet.Close();
      end;

      DataSet.Free();
    end;

    SQL := 'SET UNIQUE_CHECKS=0, FOREIGN_KEY_CHECKS=0;';
    while ((Success <> daAbort) and not DestinationClient.ExecuteSQL(SQL)) do
      DoError(DatabaseError(DestinationClient), ToolsItem(TElement(Elements[0]^).Destination), True, SQL);
  end;

  if (SourceClient = DestinationClient) then
  begin
    for I := 0 to Elements.Count - 1 do
      if (Success <> daAbort) then
      begin
        Success := daSuccess;

        CloneTable(TElement(Elements[I]^).Source, TElement(Elements[I]^).Destination);
      end;
  end
  else
  begin
    if (Success <> daAbort) then
    begin
      SQL := '';
      if (Data) then
        for I := 0 to Elements.Count - 1 do
        begin
          SourceTable := SourceClient.DatabaseByName(TElement(Elements[I]^).Source.DatabaseName).BaseTableByName(TElement(Elements[I]^).Source.TableName);

          SQL := SQL + 'SELECT * FROM ' + SourceClient.EscapeIdentifier(SourceTable.Database.Name) + '.' + SourceClient.EscapeIdentifier(SourceTable.Name);
          if (Assigned(SourceTable.PrimaryKey)) then
          begin
            SQL := SQL + ' ORDER BY ';
            for J := 0 to SourceTable.PrimaryKey.Columns.Count - 1 do
            begin
              if (J > 0) then SQL := SQL + ',';
              SQL := SQL + SourceClient.EscapeIdentifier(SourceTable.PrimaryKey.Columns[J].Field.Name);
            end;
          end;
          SQL := SQL + ';' + #13#10;
        end;

      for I := 0 to Elements.Count - 1 do
        if (Success <> daAbort) then
        begin
          Success := daSuccess;

          if (Data) then
            if (I = 0) then
              while ((Success <> daAbort) and not SourceClient.FirstResult(DataHandle, SQL)) do
                DoError(DatabaseError(SourceClient), ToolsItem(TElement(Elements[I]^).Source), True, SQL)
            else
              if ((Success = daSuccess) and not SourceClient.NextResult(DataHandle)) then
                DoError(DatabaseError(SourceClient), ToolsItem(TElement(Elements[I]^).Source), False);

          ExecuteTable(TElement(Elements[I]^).Source, TElement(Elements[I]^).Destination);
        end;

      if (Data) then
        SourceClient.CloseResult(DataHandle);
    end;

    // Handle Foreign Keys after tables executed to have more parent tables available
    for I := 0 to Elements.Count - 1 do
      if (Success <> daAbort) then
      begin
        Success := daSuccess;

        ExecuteForeignKeys(TElement(Elements[I]^).Source, TElement(Elements[I]^).Destination);
        if (Success = daFail) then Success := daSuccess;
      end;
  end;

  if (Data and (DestinationClient.ServerVersion >= 40014)) then
  begin
    SQL := 'SET UNIQUE_CHECKS=' + OLD_UNIQUE_CHECKS + ', FOREIGN_KEY_CHECKS=' + OLD_FOREIGN_KEY_CHECKS + ';' + #13#10;
    while ((Success <> daRetry) and not DestinationClient.ExecuteSQL(SQL)) do
      DoError(DatabaseError(DestinationClient), ToolsItem(TElement(Elements[0]^).Destination), True, SQL);
  end;

  AfterExecute();
end;

procedure TTTransfer.ExecuteData(var Source, Destination: TItem);
var
  Buffer: TTools.TStringBuffer;
  DataFileBuffer: TDataFileBuffer;
  DestinationDatabase: TCDatabase;
  DestinationField: TCTableField;
  DestinationTable: TCBaseTable;
  EscapedFieldName: array of string;
  EscapedTableName: string;
  FieldCount: Integer;
  FieldInfo: TFieldInfo;
  FilenameP: array [0 .. MAX_PATH] of Char;
  I: Integer;
  InsertStmtInSQL: Boolean;
  J: Integer;
  LibLengths: MYSQL_LENGTHS;
  LibRow: MYSQL_ROW;
  Pipe: THandle;
  Pipename: string;
  S: string;
  SourceDatabase: TCDatabase;
  SourceDataSet: TMySQLQuery;
  SourceTable: TCBaseTable;
  SourceValues: string;
  SQL: string;
  SQLExecuted: TEvent;
  SQLExecuteLength: Integer;
  WrittenSize: Cardinal;
  Values: string;
begin
  SourceValues := ''; FilenameP[0] := #0;
  SourceDatabase := Source.Client.DatabaseByName(Source.DatabaseName);
  DestinationDatabase := Destination.Client.DatabaseByName(Destination.DatabaseName);
  SourceTable := SourceDatabase.BaseTableByName(Source.TableName);
  DestinationTable := DestinationDatabase.BaseTableByName(Destination.TableName);

  FieldCount := 0;
  for I := 0 to SourceTable.Fields.Count - 1 do
    for J := 0 to DestinationTable.Fields.Count - 1 do
      if (lstrcmpi(PChar(SourceTable.Fields[I].Name), PChar(DestinationTable.Fields[J].Name)) = 0) then
        Inc(FieldCount);

  if ((Success = daSuccess) and (FieldCount > 0)) then
  begin
    SourceDataSet := TMySQLQuery.Create(nil);
    SourceDataSet.Open(DataHandle);
    while ((Success <> daRetry) and not SourceDataSet.Active) do
    begin
      SourceDataSet.Open();
      if (Source.Client.ErrorCode > 0) then
        DoError(DatabaseError(Source.Client), ToolsItem(TElement(Elements[0]^).Source), True, SQL);
    end;

    if ((Success = daSuccess) and not SourceDataSet.IsEmpty()) then
    begin
      SQLExecuted := TEvent.Create(nil, False, False, '');

      if (Destination.Client.DataFileAllowed) then
      begin
        Pipename := '\\.\pipe\' + LoadStr(1000);
        Pipe := CreateNamedPipe(PChar(Pipename),
                                PIPE_ACCESS_OUTBOUND, PIPE_TYPE_MESSAGE or PIPE_READMODE_BYTE or PIPE_WAIT,
                                1, 2 * NET_BUFFER_LENGTH, 0, 0, nil);
        if (Pipe = INVALID_HANDLE_VALUE) then
          DoError(SysError(), ToolsItem(Destination), False)
        else
        begin
          SQL := '';
          if (Destination.Client.Lib.LibraryType <> ltHTTP) then
            if (Destination.Client.ServerVersion < 40011) then
              SQL := SQL + 'BEGIN;' + #13#10
            else
              SQL := SQL + 'START TRANSACTION;' + #13#10;
          if ((Destination.Client.ServerVersion >= 40000) and DestinationTable.Engine.IsMyISAM) then
            SQL := SQL + 'ALTER TABLE ' + Destination.Client.EscapeIdentifier(DestinationTable.Name) + ' DISABLE KEYS;' + #13#10;
          if (DestinationDatabase.Name <> Destination.Client.DatabaseName) then
            SQL := SQL + DestinationDatabase.SQLUse();
          SQL := SQL + SQLLoadDataInfile(DestinationDatabase, False, Pipename, Destination.Client.Charset, DestinationDatabase.Name, DestinationTable.Name, '');
          if ((Destination.Client.ServerVersion >= 40000) and DestinationTable.Engine.IsMyISAM) then
            SQL := SQL + 'ALTER TABLE ' + Destination.Client.EscapeIdentifier(DestinationTable.Name) + ' ENABLE KEYS;' + #13#10;
          if (Destination.Client.Lib.LibraryType <> ltHTTP) then
            SQL := SQL + 'COMMIT;' + #13#10;

          Destination.Client.SendSQL(SQL, SQLExecuted);

          if (ConnectNamedPipe(Pipe, nil)) then
          begin
            DataFileBuffer := TDataFileBuffer.Create(TElement(Elements[0]^).Destination.Client.CodePage);

            repeat
              LibLengths := SourceDataSet.LibLengths;
              LibRow := SourceDataSet.LibRow;

              for I := 0 to DestinationTable.Fields.Count - 1 do
              begin
                DestinationField := DestinationTable.Fields[I];
                if (I > 0) then
                  DataFileBuffer.Write(PAnsiChar(',_'), 1); // Two characters are needed to instruct the compiler to give a pointer - but the first character should be placed in the file only
                if (not Assigned(LibRow^[I])) then
                  DataFileBuffer.Write(PAnsiChar('NULL'), 4)
                else if (BitField(SourceDataSet.Fields[I])) then
                  begin S := UInt64ToStr(SourceDataSet.Fields[I].AsLargeInt); DataFileBuffer.WriteData(PChar(S), Length(S)); end
                else if (DestinationTable.Fields[I].FieldType in BinaryFieldTypes) then
                  DataFileBuffer.WriteBinary(LibRow^[I], LibLengths^[I])
                else if (DestinationField.FieldType in TextFieldTypes) then
                  DataFileBuffer.WriteText(LibRow^[I], LibLengths^[I], Source.Client.CodePage)
                else
                  DataFileBuffer.Write(LibRow^[I], LibLengths^[I], not (DestinationField.FieldType in NotQuotedFieldTypes));
              end;
              DataFileBuffer.Write(PAnsiChar(#10 + '_'), 1); // Two characters are needed to instruct the compiler to give a pointer - but the first character should be placed in the file only

              if (DataFileBuffer.Size > NET_BUFFER_LENGTH) then
                if (not WriteFile(Pipe, DataFileBuffer.Data^, DataFileBuffer.Size, WrittenSize, nil) or (Abs(WrittenSize) < DataFileBuffer.Size)) then
                  DoError(SysError(), ToolsItem(Destination), False)
                else
                 DataFileBuffer.Clear();

              Inc(Destination.RecordsDone);
              if (Destination.RecordsDone mod 100 = 0) then
                DoUpdateGUI();

              if (UserAbort.WaitFor(IGNORE) = wrSignaled) then
                Success := daAbort;
            until ((Success <> daSuccess) or not SourceDataSet.FindNext());

            if (DataFileBuffer.Size > 0) then
              if (not WriteFile(Pipe, DataFileBuffer.Data^, DataFileBuffer.Size, WrittenSize, nil) or (Abs(WrittenSize) < DataFileBuffer.Size)) then
                DoError(SysError(), ToolsItem(Destination), False)
              else
                DataFileBuffer.Clear();

            if (not FlushFileBuffers(Pipe) or not WriteFile(Pipe, DataFileBuffer.Data^, 0, WrittenSize, nil) or not FlushFileBuffers(Pipe)) then
              DoError(SysError(), ToolsItem(Destination), False)
            else
            begin
              DoUpdateGUI();
              SQLExecuted.WaitFor(INFINITE);
            end;

            DisconnectNamedPipe(Pipe);

            if (Destination.Client.ErrorCode <> 0) then
              DoError(DatabaseError(Destination.Client), ToolsItem(Destination), False, SQL);

            DataFileBuffer.Free();
          end;

          CloseHandle(Pipe);
        end;
      end
      else
      begin
        SQL := ''; SQLExecuteLength := 0;

        InsertStmtInSQL := False;

        EscapedTableName := Destination.Client.EscapeIdentifier(DestinationTable.Name);
        SetLength(EscapedFieldName, DestinationTable.Fields.Count);
        for I := 0 to DestinationTable.Fields.Count - 1 do
           EscapedFieldName[I] := Destination.Client.EscapeIdentifier(DestinationTable.Fields[I].Name);

        if (Destination.Client.Lib.LibraryType <> ltHTTP) then
          if (Destination.Client.ServerVersion < 40011) then
            SQL := SQL + 'BEGIN;' + #13#10
          else
            SQL := SQL + 'START TRANSACTION;' + #13#10;
        SQL := SQL + 'LOCK TABLES ' + EscapedTableName + ' WRITE;' + #13#10;
        if ((Destination.Client.ServerVersion >= 40000) and DestinationTable.Engine.IsMyISAM) then
          SQL := SQL + 'ALTER TABLE ' + EscapedTableName + ' DISABLE KEYS;' + #13#10;

        if (DestinationDatabase.Name <> Destination.Client.DatabaseName) then
          SQL := SQL + DestinationDatabase.SQLUse();

        repeat
          if (not InsertStmtInSQL) then
          begin
            InsertStmtInSQL := True;

            SQL := SQL + 'INSERT INTO ' + EscapedTableName + ' VALUES (';
          end
          else
            SQL := SQL + ',(';
          Values := '';
          for I := 0 to SourceDataSet.FieldCount - 1 do
          begin
            if (I > 0) then Values := Values + ',';
            Values := Values + SourceDataSet.SQLFieldValue(SourceDataSet.Fields[I]);
          end;
          SQL := SQL + Values + ')';

          if (Length(SQL) - SQLExecuteLength >= SQLPacketSize) then
          begin
            if (InsertStmtInSQL) then
            begin
              SQL := SQL + ';' + #13#10;
              InsertStmtInSQL := False;
            end;

            if (SQLExecuteLength > 0) then
            begin
              SQLExecuted.WaitFor(INFINITE);
              Delete(SQL, 1, Destination.Client.ExecutedSQLLength);
              SQLExecuteLength := 0;
              if (Destination.Client.ErrorCode <> 0) then
                DoError(DatabaseError(Destination.Client), ToolsItem(Destination), False, SQL);
            end;

            if (SQL <> '') then
            begin
              Destination.Client.SendSQL(SQL, SQLExecuted);
              SQLExecuteLength := Length(SQL);
            end;
          end;

          Inc(Destination.RecordsDone);
          if (Destination.RecordsDone mod 100 = 0) then DoUpdateGUI();

          if (UserAbort.WaitFor(IGNORE) = wrSignaled) then
          begin
            if (SQL <> '') then
              Destination.Client.Terminate();
            Success := daAbort;
          end;
        until ((Success <> daSuccess) or not SourceDataSet.FindNext());

        if ((Success = daSuccess) and (SQLExecuteLength > 0)) then
        begin
          SQLExecuted.WaitFor(INFINITE);
          Delete(SQL, 1, Destination.Client.ExecutedSQLLength);
          if (Destination.Client.ErrorCode <> 0) then
            DoError(DatabaseError(Destination.Client), ToolsItem(Destination), False, SQL);
        end;

        if (InsertStmtInSQL) then
          SQL := SQL + ';' + #13#10;
        if ((Destination.Client.ServerVersion >= 40000) and DestinationTable.Engine.IsMyISAM) then
          SQL := SQL + 'ALTER TABLE ' + EscapedTableName + ' ENABLE KEYS;' + #13#10;
        SQL := SQL + 'UNLOCK TABLES;' + #13#10;
        if (Destination.Client.Lib.LibraryType <> ltHTTP) then
          SQL := SQL + 'COMMIT;' + #13#10;

        while ((Success <> daAbort) and not DoExecuteSQL(TElement(Elements[0]^).Destination, Destination.Client, SQL)) do
          DoError(DatabaseError(Destination.Client), ToolsItem(Destination), True, SQL);
      end;

      if (Success <> daSuccess) then
      begin
        SQL := '';
        if ((Destination.Client.ServerVersion >= 40000) and DestinationTable.Engine.IsMyISAM) then
          SQL := SQL + 'ALTER TABLE ' + EscapedTableName + ' ENABLE KEYS;' + #13#10;
        SQL := SQL + 'UNLOCK TABLES;' + #13#10;
        if (Destination.Client.Lib.LibraryType <> ltHTTP) then
          SQL := SQL + 'ROLLBACK;' + #13#10;
        DoExecuteSQL(TElement(Elements[0]^).Destination, Destination.Client, SQL);
      end;

      SQLExecuted.Free();
    end;

    if (Success <> daAbort) then
      SourceDataSet.Free();
  end;
end;

procedure TTTransfer.ExecuteForeignKeys(var Source, Destination: TItem);
var
  DestinationDatabase: TCDatabase;
  DestinationTable: TCBaseTable;
  I: Integer;
  NewTable: TCBaseTable;
  ParentTable: TCBaseTable;
  SourceDatabase: TCDatabase;
  SourceTable: TCBaseTable;
begin
  SourceDatabase := Source.Client.DatabaseByName(Source.DatabaseName);
  SourceTable := SourceDatabase.BaseTableByName(Source.TableName);
  DestinationDatabase := Destination.Client.DatabaseByName(Destination.DatabaseName);
  DestinationTable := DestinationDatabase.BaseTableByName(Destination.TableName);
  NewTable := nil;

  if (Assigned(DestinationTable)) then
    for I := 0 to SourceTable.ForeignKeys.Count - 1 do
      if (not Assigned(DestinationTable.ForeignKeyByName(SourceTable.ForeignKeys[I].Name))) then
      begin
        if (not Assigned(NewTable)) then
        begin
          NewTable := TCBaseTable.Create(DestinationDatabase.Tables);
          NewTable.Assign(DestinationTable);
        end;

        ParentTable := DestinationDatabase.BaseTableByName(SourceTable.ForeignKeys[I].Parent.TableName);
        if (Assigned(ParentTable)) then
          NewTable.ForeignKeys.AddForeignKey(SourceTable.ForeignKeys[I]);
      end;

  if (Assigned(NewTable)) then
  begin
    while ((Success <> daAbort) and not DestinationDatabase.UpdateTable(DestinationTable, NewTable)) do
      DoError(DatabaseError(Destination.Client), ToolsItem(Destination), True);
    NewTable.Free();
  end;
end;

procedure TTTransfer.ExecuteStructure(const Source, Destination: TItem);
var
  DeleteForeignKey: Boolean;
  DestinationDatabase: TCDatabase;
  DestinationTable: TCBaseTable;
  I: Integer;
  J: Integer;
  Modified: Boolean;
  NewDestinationTable: TCBaseTable;
  OldFieldBefore: TCTableField;
  SourceDatabase: TCDatabase;
  SourceTable: TCBaseTable;
begin
  SourceDatabase := Source.Client.DatabaseByName(Source.DatabaseName);
  SourceTable := SourceDatabase.BaseTableByName(Source.TableName);
  DestinationDatabase := Destination.Client.DatabaseByName(Destination.DatabaseName);
  DestinationTable := DestinationDatabase.BaseTableByName(Destination.TableName);

  if (Assigned(DestinationTable)) then
  begin
    while ((Success <> daAbort) and not DestinationDatabase.DeleteObject(DestinationTable)) do
      DoError(DatabaseError(Destination.Client), ToolsItem(Destination), True);
    DestinationTable := nil;
  end;

  NewDestinationTable := TCBaseTable.Create(DestinationDatabase.Tables);

  if (not Assigned(DestinationTable)) then
  begin
    NewDestinationTable.Assign(SourceTable);
    NewDestinationTable.Name := Destination.Client.ApplyIdentifierName(NewDestinationTable.Name);

    for I := 0 to NewDestinationTable.Keys.Count - 1 do
      NewDestinationTable.Keys[I].Name := Destination.Client.ApplyIdentifierName(NewDestinationTable.Keys[I].Name);
    for I := 0 to NewDestinationTable.Fields.Count - 1 do
      NewDestinationTable.Fields[I].Name := Destination.Client.ApplyIdentifierName(NewDestinationTable.Fields[I].Name);

    for I := NewDestinationTable.ForeignKeys.Count - 1 downto 0 do
    begin
      NewDestinationTable.ForeignKeys[I].Name := Destination.Client.ApplyIdentifierName(NewDestinationTable.ForeignKeys[I].Name);

      DeleteForeignKey := (Destination.Client.TableNameCmp(NewDestinationTable.ForeignKeys[I].Parent.DatabaseName, SourceTable.Database.Name) <> 0)
        or not Assigned(DestinationDatabase.BaseTableByName(NewDestinationTable.ForeignKeys[I].Parent.TableName));

      if (not DeleteForeignKey) then
      begin
        NewDestinationTable.ForeignKeys[I].Parent.DatabaseName := NewDestinationTable.Database.Name;
        NewDestinationTable.ForeignKeys[I].Parent.TableName := NewDestinationTable.Database.BaseTableByName(NewDestinationTable.ForeignKeys[I].Parent.TableName).Name;
        DeleteForeignKey := not Assigned(DestinationDatabase.TableByName(NewDestinationTable.ForeignKeys[I].Parent.TableName));
        for J := 0 to Length(NewDestinationTable.ForeignKeys[I].Parent.FieldNames) - 1 do
          if (not DeleteForeignKey) then
          begin
            NewDestinationTable.ForeignKeys[I].Parent.FieldNames[J] := DestinationDatabase.TableByName(NewDestinationTable.ForeignKeys[I].Parent.TableName).FieldByName(NewDestinationTable.ForeignKeys[I].Parent.FieldNames[J]).Name;
            DeleteForeignKey := not Assigned(NewDestinationTable.FieldByName(NewDestinationTable.ForeignKeys[I].Parent.FieldNames[J]));
          end;
      end;

      if (DeleteForeignKey) then
        NewDestinationTable.ForeignKeys.DeleteForeignKey(NewDestinationTable.ForeignKeys[I]);
    end;

    NewDestinationTable.AutoIncrement := 0;
    while ((Success <> daAbort) and not DestinationDatabase.AddTable(NewDestinationTable)) do
      DoError(DatabaseError(Destination.Client), ToolsItem(Destination), True);
  end;

  NewDestinationTable.Free();
end;

procedure TTTransfer.ExecuteTable(var Source, Destination: TItem);
var
  I: Integer;
  DestinationDatabase: TCDatabase;
  DestinationTable: TCBaseTable;
  NewTrigger: TCTrigger;
  SourceDatabase: TCDatabase;
  SourceTable: TCBaseTable;
begin
  DestinationDatabase := Destination.Client.DatabaseByName(Destination.DatabaseName);

  if ((Success = daSuccess) and Structure and not Assigned(DestinationDatabase)) then
  begin
    DestinationDatabase := TCDatabase.Create(Destination.Client, Destination.DatabaseName);
    while ((Success <> daAbort) and not Destination.Client.AddDatabase(DestinationDatabase)) do
      DoError(DatabaseError(Destination.Client), ToolsItem(Destination), True);
    DestinationDatabase.Free();

    DestinationDatabase := Destination.Client.DatabaseByName(Destination.DatabaseName);
  end;

  if (Success = daSuccess) then
  begin
    DestinationTable := DestinationDatabase.BaseTableByName(Destination.TableName);

    if (Structure and Data and not Assigned(DestinationTable) and (Source.Client = Destination.Client) and (Source.Client.DatabaseByName(Source.DatabaseName).BaseTableByName(Source.TableName).ForeignKeys.Count = 0)) then
    begin
      while ((Success <> daAbort) and not DestinationDatabase.CloneTable(Source.Client.DatabaseByName(Source.DatabaseName).BaseTableByName(Source.TableName), Destination.TableName, True)) do
        DoError(DatabaseError(Destination.Client), ToolsItem(Destination), True);

      if (Success = daSuccess) then
      begin
        DestinationTable := DestinationDatabase.BaseTableByName(Destination.TableName);

        Destination.RecordsDone := DestinationTable.Rows;
      end;
    end
    else
    begin
      if ((Success = daSuccess) and Structure) then
      begin
        ExecuteStructure(Source, Destination);
        DestinationTable := DestinationDatabase.BaseTableByName(Destination.TableName);

        if (UserAbort.WaitFor(IGNORE) = wrSignaled) then
          Success := daAbort;
      end;

      if ((Success = daSuccess) and Data and Assigned(DestinationTable) and (DestinationTable.Source <> '')) then
        ExecuteData(Source, Destination);
    end;

    if (Success = daSuccess) then
      Destination.RecordsSum := Destination.RecordsDone;

    SourceDatabase := Source.Client.DatabaseByName(Source.DatabaseName);
    SourceTable := SourceDatabase.BaseTableByName(Source.TableName);
    if (Assigned(SourceDatabase.Triggers) and Assigned(DestinationDatabase.Triggers)) then
      for I := 0 to SourceDatabase.Triggers.Count - 1 do
        if ((Success = daSuccess) and (SourceDatabase.Triggers[I].Table = SourceTable) and not Assigned(DestinationDatabase.TriggerByName(SourceDatabase.Triggers[I].Name))) then
        begin
          NewTrigger := TCTrigger.Create(DestinationDatabase.Tables);
          NewTrigger.Assign(SourceDatabase.Triggers[I]);
          while (Success <> daAbort) do
          begin
            DestinationDatabase.AddTrigger(NewTrigger);
            if (Destination.Client.ErrorCode <> 0) then
              DoError(DatabaseError(Destination.Client), ToolsItem(Destination), True);
          end;
          NewTrigger.Free();
        end;

    Destination.Done := Success = daSuccess;

    DoUpdateGUI();
  end;
end;

function TTTransfer.ToolsItem(const Item: TItem): TTools.TItem;
begin
  Result.Client := Item.Client;
  Result.DatabaseName := Item.DatabaseName;
  Result.TableName := Item.TableName;
end;

end.

