# Seq Provider Unit Tests

## Overview

The unit tests for the Seq provider ensure that all functions work correctly and code quality is maintained.

## Test File

- **`DX.Logger.Tests.SeqProvider.pas`** - Contains all tests for the Seq provider

## Test Coverage

### 1. TestProviderCreation
**Purpose:** Ensures that the provider instance is created correctly.

**Tests:**
- Singleton pattern works
- Instance is not null

### 2. TestConfiguration
**Purpose:** Verifies that all configuration methods execute without errors.

**Tests:**
- `SetServerUrl()`
- `SetApiKey()`
- `SetBatchSize()`
- `SetFlushInterval()`

### 3. TestLogEntry
**Purpose:** Verifies that log entries are processed correctly.

**Tests:**
- Log entries are added to the queue
- Message and level are transferred correctly
- Asynchronous processing works

### 4. TestCLEFFormat
**Purpose:** Ensures that the CLEF format is generated correctly.

**Tests:**
- CLEF formatting works internally
- Log entries are formatted correctly

### 5. TestLogLevelMapping
**Purpose:** Verifies the mapping of DX.Logger log levels to Seq log levels.

**Tests:**
- Trace → Verbose
- Debug → Debug
- Info → Information
- Warn → Warning
- Error → Error

### 6. TestAsyncLogging
**Purpose:** Verifies that asynchronous logging is non-blocking.

**Tests:**
- Logging is fast (< 100ms for 3 messages)
- All messages are processed
- Queue-based processing works

### 7. TestBatching
**Purpose:** Ensures that batching works correctly.

**Tests:**
- Messages are collected
- Batches are sent when batch size is reached
- All messages arrive

### 8. TestFlush
**Purpose:** Verifies manual flush functionality.

**Tests:**
- `Flush()` sends all pending messages
- Messages are sent even with large batch size
- No messages are lost

### 9. TestThreadSafety
**Purpose:** Verifies thread safety with parallel access.

**Tests:**
- 10 threads send 50 messages each in parallel
- All 500 messages are processed correctly
- No race conditions
- No lost messages

### 10. TestShutdown
**Purpose:** Ensures safe shutdown.

**Tests:**
- Provider can be cleanly terminated
- No access violations during shutdown
- Worker thread is terminated correctly

## Test Utilities

### TMockSeqCapture
A mock provider that captures log entries without actually sending HTTP requests.

**Features:**
- Collects all log entries
- Allows verification of count
- Allows access to individual entries
- Thread-safe

## Running Tests

### Command Line
```batch
cd tests
dcc32 -B -U"..\source;DUnitX\Source" -I"..\source;DUnitX\Source" DX.Logger.Tests.dpr
DX.Logger.Tests.exe
```

### Delphi IDE
1. Open project `tests\DX.Logger.Tests.dproj`
2. Press F9 (Run)
3. View test results in the console

## Expected Results

```
Tests Found   : 25
Tests Ignored : 0
Tests Passed  : 25
Tests Leaked  : 0
Tests Failed  : 0
Tests Errored : 0
```

## Notes

- Tests use `Sleep()` to wait for asynchronous processing
- On slow systems, sleep times may need to be increased
- Tests are independent of a real Seq server
- HTTP communication is not tested (would require real server)

## Continuous Integration

The tests are CI-ready and can be used in automated build pipelines:

```batch
DX.Logger.Tests.exe --exitbehavior:Continue
```

Exit Code:
- `0` = All tests successful
- `!= 0` = At least one test failed

## Future Enhancements

Possible future tests:
- Integration tests with real Seq server
- Performance tests with high load
- Memory leak tests over extended periods
- Error handling for network issues

