# Changelog

All notable changes to Media Muncher will be documented in this file.

## [Unreleased]

### Added
- Support for importing from read-only volumes: originals are left intact and a non-fatal banner notifies the user once the import completes.
- New unit-test `ImportServiceIntegrationTests.testImport_readOnlySource_deletionFailsButImportSucceeds`.
- New **state-machine** unit tests covering scan cancellation and auto-eject logic (`AppStateWorkflowTests`).
- **Destination Path Recalculation System**: Automatic recalculation of file destination paths when users change the destination directory in Settings, preserving thumbnails and metadata while updating paths.
- Synchronous path calculation methods for improved test reliability and performance.
- **RecalculationManager**: New dedicated service that acts as a state machine for handling destination change recalculations with proper error handling and cancellation support.
- `recalculationFailed` error type in AppError with helper properties for better error identification.

### Fixed
- Filename-collision handling now appends numeric suffixes ("_1", "_2", …) when a different file already exists at the destination.
- Pre-existing file detection improved: identical files are recognised even if modification timestamps differ slightly or filenames already match.
- Test reliability improved by eliminating all `Task.sleep()` operations and implementing deterministic testing patterns.
- Test `testAppStateHandlesDestinationChangesGracefully` now properly creates required directories before testing destination changes.
- **Test State Pollution**: Fixed intermittent test failures caused by shared UserDefaults.standard across multiple test files. Implemented isolated UserDefaults instances in `SettingsStoreTests.swift`, `SettingsStorePersistenceTests.swift`, and `AppStateIntegrationTests.swift` ensuring complete test isolation.
- **Double assignment bug in SettingsStore**: Fixed unpredictable Combine publisher behavior caused by destinationURL being set twice during bookmark resolution.
- **Recalculation flow reliability**: Replaced brittle `.dropFirst()` workaround with robust RecalculationManager state machine.
- **Test reliability improvements**: Removed all `Task.sleep()` timeouts from tests, replacing with proper XCTestExpectation patterns for deterministic completion detection. Fixed hanging tests - all tests now complete in milliseconds instead of timing out.

### Changed
- **Enhanced "Delete originals"**: When enabled, this setting now also deletes source files that are identified as duplicates already present in the destination, helping to clean up source media more effectively.
- `ImportService` treats failures to delete originals as warnings instead of errors, allowing the import process to continue.
- Bottom bar error banner now surfaces "Import succeeded with deletion errors" when originals could not be removed.
- **FileProcessorService Architecture**: Split file processing into sync path calculation and async file I/O operations for better testability and performance.
- Removed code duplication in collision detection logic by extracting shared destination resolution methods.
- **Simplified SettingsStore**: Removed all security-scoped bookmark logic since the app is no longer sandboxed, making destination handling more direct and reliable.
- **AppState refactoring**: Delegated recalculation logic to RecalculationManager, making AppState a pure orchestrator with cleaner separation of concerns.
- **Production code cleanup**: Completely removed `setFilesForTesting()` method from AppState to eliminate test pollution in production code. Tests now use direct property assignment for setup.
- **ContentView preview cleanup**: Removed unnecessary environment object injections from ContentView preview, maintaining only essential dependencies.
- **Test file organization**: Renamed `AppStateRecalculationIsolationTest.swift` to `AppStateRecalculationIntegrationTests.swift` to accurately reflect its integration testing nature.
- **Architectural refinement**: Removed direct `updateFiles()` call from AppState to RecalculationManager, enforcing AppState as the single source of truth for file arrays.
- **Explicit error mapping**: Enhanced error handling to explicitly map recalculation errors to `.recalculationFailed` type for consistency.
- **Logging**: Refactored `LogManager` to create a new log file for each application session, removing the in-memory cache and log clearing functionality for a simpler, more robust design. 