unit DX.Logger.Provider.UI;

{
  DX.Logger.Provider.UI - UI logging provider for DX.Logger

  Copyright (c) 2025 Olaf Monien
  SPDX-License-Identifier: MIT

  Simple usage:
    uses
      DX.Logger,
      DX.Logger.Provider.UI;

    // Register UI provider with TMemo.Lines
    TUILogProvider.Instance.ExternalStrings := MemoInfo.Lines;
    TUILogProvider.Instance.AppendOnTop := False;
    TDXLogger.Instance.RegisterProvider(TUILogProvider.Instance);

    // Unregister when form closes
    TUILogProvider.Instance.ExternalStrings := nil;

  Features:
    - Thread-safe logging to TStrings (TMemo.Lines, etc.)
    - Synchronization to main thread via TThread.Queue
    - Optional append on top or bottom
    - Automatic batching for better performance
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DX.Logger;

type
  /// <summary>
  /// UI-based log provider for displaying logs in TMemo or similar controls
  /// </summary>
  TUILogProvider = class(TInterfacedObject, ILogProvider)
  private
    class var FInstance: TUILogProvider;
    class var FLock: TObject;
  private
    FExternalStrings: TStrings;
    FAppendOnTop: Boolean;
    FPendingMessages: TThreadedQueue<string>;
    FWorkerThread: TThread;
    FShutdown: Boolean;

    procedure WorkerThreadExecute;
    procedure UpdateExternalStrings(const AMessages: TArray<string>);
    function FormatLogEntry(const AEntry: TLogEntry): string;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Log message to UI (queued for async processing)
    /// </summary>
    procedure Log(const AEntry: TLogEntry);

    /// <summary>
    /// Set external strings (e.g., TMemo.Lines) to log to
    /// </summary>
    property ExternalStrings: TStrings read FExternalStrings write FExternalStrings;

    /// <summary>
    /// Insert new log messages on top (default: False)
    /// </summary>
    property AppendOnTop: Boolean read FAppendOnTop write FAppendOnTop;

    /// <summary>
    /// Get singleton instance
    /// </summary>
    class function Instance: TUILogProvider;

    /// <summary>
    /// Cleanup on application exit
    /// </summary>
    class destructor Destroy;
  end;

implementation

uses
  System.SyncObjs,
  System.DateUtils;

const
  C_QUEUE_DEPTH = 1000;
  C_FLUSH_INTERVAL = 100; // 100ms

{ TUILogProvider }

constructor TUILogProvider.Create;
begin
  inherited Create;
  FShutdown := False;
  FAppendOnTop := False;
  FExternalStrings := nil;
  FPendingMessages := TThreadedQueue<string>.Create(C_QUEUE_DEPTH, INFINITE, 100);

  // Start worker thread
  FWorkerThread := TThread.CreateAnonymousThread(WorkerThreadExecute);
  FWorkerThread.FreeOnTerminate := False;
  FWorkerThread.Start;
end;

destructor TUILogProvider.Destroy;
begin
  FShutdown := True;

  // Disconnect from external strings first to prevent UI updates during shutdown
  FExternalStrings := nil;

  // Wait for worker thread to finish
  if Assigned(FWorkerThread) then
  begin
    FWorkerThread.Terminate;
    FWorkerThread.WaitFor;
    FreeAndNil(FWorkerThread);
  end;

  FreeAndNil(FPendingMessages);
  inherited;
end;

class destructor TUILogProvider.Destroy;
begin
  // During shutdown, just set to nil without freeing
  // The instance will be freed by the reference counting
  FInstance := nil;
  FreeAndNil(FLock);
end;

class function TUILogProvider.Instance: TUILogProvider;
begin
  if not Assigned(FInstance) then
  begin
    if not Assigned(FLock) then
      FLock := TObject.Create;

    TMonitor.Enter(FLock);
    try
      if not Assigned(FInstance) then  // Double-checked locking
        FInstance := TUILogProvider.Create;
    finally
      TMonitor.Exit(FLock);
    end;
  end;
  Result := FInstance;
end;

procedure TUILogProvider.Log(const AEntry: TLogEntry);
var
  LFormattedMessage: string;
begin
  // Skip if no external strings assigned
  if not Assigned(FExternalStrings) then
    Exit;

  LFormattedMessage := FormatLogEntry(AEntry);
  FPendingMessages.PushItem(LFormattedMessage);
end;

function TUILogProvider.FormatLogEntry(const AEntry: TLogEntry): string;
begin
  Result := Format('[%s] [%s] %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AEntry.Timestamp),
     LogLevelToString(AEntry.Level),
     AEntry.Message]);
end;

procedure TUILogProvider.WorkerThreadExecute;
var
  LBatch: TList<string>;
  LMessage: string;
  LWaitResult: TWaitResult;
  LLastFlush: TDateTime;
begin
  LBatch := TList<string>.Create;
  try
    LLastFlush := Now;

    while not FShutdown do
    begin
      // Try to get a message with timeout
      LWaitResult := FPendingMessages.PopItem(LMessage);

      // Exit if queue was shut down
      if LWaitResult = TWaitResult.wrAbandoned then
        Break;

      if LWaitResult = TWaitResult.wrSignaled then
      begin
        LBatch.Add(LMessage);
      end;

      // Flush batch if interval elapsed or we have messages
      if (LBatch.Count > 0) and
         ((MilliSecondsBetween(Now, LLastFlush) >= C_FLUSH_INTERVAL) or
          (LBatch.Count >= 10)) then
      begin
        UpdateExternalStrings(LBatch.ToArray);
        LBatch.Clear;
        LLastFlush := Now;
      end;
    end;

    // Final flush on shutdown
    if LBatch.Count > 0 then
      UpdateExternalStrings(LBatch.ToArray);
  finally
    LBatch.Free;
  end;
end;

procedure TUILogProvider.UpdateExternalStrings(const AMessages: TArray<string>);
begin
  // Skip if shutting down or no external strings
  if FShutdown or not Assigned(FExternalStrings) then
    Exit;

  // Synchronize to main thread for UI update
  TThread.Synchronize(nil,
    procedure
    var
      LMessage: string;
    begin
      if FShutdown or not Assigned(FExternalStrings) then
        Exit;

      try
        FExternalStrings.BeginUpdate;
        try
          if FAppendOnTop then
          begin
            // Insert at top in reverse order to maintain chronological order
            for var i := High(AMessages) downto Low(AMessages) do
              FExternalStrings.Insert(0, AMessages[i]);
          end
          else
          begin
            // Append at bottom
            for LMessage in AMessages do
              FExternalStrings.Add(LMessage);
          end;
        finally
          FExternalStrings.EndUpdate;
        end;
      except
        // Silently ignore UI update errors
      end;
    end);
end;

initialization
  TUILogProvider.FLock := TObject.Create;

end.

