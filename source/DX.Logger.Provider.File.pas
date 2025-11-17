unit DX.Logger.Provider.File;

{
  DX.Logger.Provider.File - File logging provider for DX.Logger

  Simple usage:
    uses
      DX.Logger,
      DX.Logger.Provider.File;

    // File logging is automatically activated by using this unit

  Configuration:
    TFileLogProvider.SetLogFileName('myapp.log');
    TFileLogProvider.SetMaxFileSize(10 * 1024 * 1024); // 10 MB
}

interface

uses
  System.SysUtils,
  System.Classes,
  DX.Logger;

type
  /// <summary>
  /// File-based log provider with automatic rotation
  /// </summary>
  TFileLogProvider = class(TInterfacedObject, ILogProvider)
  private
    class var FInstance: TFileLogProvider;
    class var FLogFileName: string;
    class var FMaxFileSize: Int64;
  private
    FFileStream: TFileStream;
    FWriter: TStreamWriter;
    FCriticalSection: TObject;
    FCurrentFileName: string;

    procedure CheckAndRotateFile;
    procedure OpenLogFile;
    procedure CloseLogFile;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Log message to file
    /// </summary>
    procedure Log(const AEntry: TLogEntry);

    /// <summary>
    /// Set log file name (default: application name + .log)
    /// </summary>
    class procedure SetLogFileName(const AFileName: string);

    /// <summary>
    /// Set maximum file size before rotation (default: 10 MB)
    /// </summary>
    class procedure SetMaxFileSize(ASize: Int64);

    /// <summary>
    /// Get singleton instance
    /// </summary>
    class function Instance: TFileLogProvider;

    /// <summary>
    /// Cleanup on application exit
    /// </summary>
    class destructor Destroy;
  end;

implementation

uses
  System.IOUtils,
  System.SyncObjs;

const
  cDefaultMaxFileSize = 10 * 1024 * 1024; // 10 MB

{ TFileLogProvider }

constructor TFileLogProvider.Create;
begin
  inherited Create;
  FCriticalSection := TCriticalSection.Create;
  FFileStream := nil;
  FWriter := nil;

  // Set default filename if not set
  if FLogFileName = '' then
    FLogFileName := TPath.ChangeExtension(ParamStr(0), '.log');

  OpenLogFile;
end;

destructor TFileLogProvider.Destroy;
begin
  CloseLogFile;
  FreeAndNil(FCriticalSection);
  inherited;
end;

class destructor TFileLogProvider.Destroy;
begin
  FreeAndNil(FInstance);
end;

class function TFileLogProvider.Instance: TFileLogProvider;
begin
  if not Assigned(FInstance) then
    FInstance := TFileLogProvider.Create;
  Result := FInstance;
end;

class procedure TFileLogProvider.SetLogFileName(const AFileName: string);
begin
  FLogFileName := AFileName;
end;

class procedure TFileLogProvider.SetMaxFileSize(ASize: Int64);
begin
  FMaxFileSize := ASize;
end;

procedure TFileLogProvider.OpenLogFile;
var
  LDirectory: string;
begin
  TMonitor.Enter(FCriticalSection);
  try
    // Ensure directory exists
    LDirectory := TPath.GetDirectoryName(FLogFileName);
    if (LDirectory <> '') and not TDirectory.Exists(LDirectory) then
      TDirectory.CreateDirectory(LDirectory);

    FCurrentFileName := FLogFileName;

    // Open or create log file (append mode)
    if TFile.Exists(FCurrentFileName) then
      FFileStream := TFileStream.Create(FCurrentFileName, fmOpenReadWrite or fmShareDenyWrite)
    else
      FFileStream := TFileStream.Create(FCurrentFileName, fmCreate or fmShareDenyWrite);

    FFileStream.Seek(0, soEnd); // Move to end for appending

    FWriter := TStreamWriter.Create(FFileStream, TEncoding.UTF8, 4096);
    FWriter.AutoFlush := True; // Ensure immediate write
  finally
    TMonitor.Exit(FCriticalSection);
  end;
end;

procedure TFileLogProvider.CloseLogFile;
begin
  TMonitor.Enter(FCriticalSection);
  try
    if Assigned(FWriter) then
    begin
      FWriter.Flush;
      FreeAndNil(FWriter);
    end;

    FreeAndNil(FFileStream);
  finally
    TMonitor.Exit(FCriticalSection);
  end;
end;

procedure TFileLogProvider.CheckAndRotateFile;
var
  LBackupFileName: string;
  LFileSize: Int64;
begin
  if not Assigned(FFileStream) then
    Exit;

  LFileSize := FFileStream.Size;

  // Check if rotation is needed
  if LFileSize >= FMaxFileSize then
  begin
    CloseLogFile;

    // Create backup filename with timestamp
    LBackupFileName := TPath.ChangeExtension(FCurrentFileName, '') +
      '.' + FormatDateTime('yyyymmdd-hhnnss', Now) +
      TPath.GetExtension(FCurrentFileName);

    // Rename current file to backup
    if TFile.Exists(FCurrentFileName) then
      TFile.Move(FCurrentFileName, LBackupFileName);

    // Open new log file
    OpenLogFile;
  end;
end;

procedure TFileLogProvider.Log(const AEntry: TLogEntry);
var
  LLogLine: string;
begin
  TMonitor.Enter(FCriticalSection);
  try
    if not Assigned(FWriter) then
      Exit;

    // Format log entry
    LLogLine := Format('[%s] [%s] [Thread:%d] %s',
      [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AEntry.Timestamp),
       LogLevelToString(AEntry.Level),
       AEntry.ThreadID,
       AEntry.Message]);

    // Write to file
    FWriter.WriteLine(LLogLine);

    // Check if rotation is needed
    CheckAndRotateFile;
  finally
    TMonitor.Exit(FCriticalSection);
  end;
end;

initialization
  // Set defaults
  TFileLogProvider.FMaxFileSize := cDefaultMaxFileSize;
  TFileLogProvider.FLogFileName := '';

  // Auto-register file provider with main logger
  TDXLogger.Instance.RegisterProvider(TFileLogProvider.Instance);

end.
