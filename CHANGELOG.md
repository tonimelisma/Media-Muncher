# Changelog

## 2025-07-21 - Async Pattern Standardization & Constants Consolidation
- **Async architecture documentation**: Added comprehensive documentation for "Hybrid with Clear Boundaries" async pattern approach across all services
- **Constants consolidation**: Created Constants.swift to centralize all magic numbers and configuration values with clear documentation
- **Publisher chain simplification**: Refactored complex Combine publisher chains in AppState into focused helper methods for improved readability
- **Service interface documentation**: Added detailed async pattern usage documentation to FileProcessorService, ImportService, VolumeManager, and SettingsStore
- **Architecture guidelines**: Updated ARCHITECTURE.md with clear async pattern guidelines and when to use each concurrency tool
- **Performance optimization**: Grid layout now uses centralized constants and helper functions for better maintainability
- **Technical debt addressed**: Marked async pattern inconsistencies and hard-coded constants as resolved in REFACTOR.md

## 2025-07-18 - SwiftUI Performance Optimization
- **Grid layout performance**: Optimized MediaFilesGridView to cache grid calculations and prevent redundant layout operations on every geometry change
- **Reduced UI overhead**: Grid columns now only recalculate when window width actually changes, improving responsiveness during window resizing
- **Deprecation fixes**: Updated onChange API to macOS 14.0+ syntax for forward compatibility

## 2025-07-18 - Logging Standardization
- **Complete print statement elimination**: Removed all print statements from production and test code across the entire codebase
- **Consistent structured logging**: Replaced all print statements in VolumeManager.swift with structured LogManager calls for better operational visibility
- **Improved log categorization**: All volume-related operations now use consistent "VolumeManager" category with structured metadata
- **Enhanced debugging**: Volume mount/unmount, enumeration, and eject operations now generate properly formatted JSON log entries
- **Code quality improvement**: Eliminated inconsistent console output in favor of structured logging infrastructure

## 2025-07-17 - Test Fixes & Stability
- **Fixed failing test**: Corrected the logic in `testImport_readOnlySource_deletionFailsButImportSucceeds` to check the *last* emitted value from the async stream, resolving a race condition where the test would check the file's state before the import and deletion-failure handling had completed.
- **Improved Test Reliability**: The test now correctly validates that the import succeeds and a non-fatal error is recorded when the source is read-only.

## 2025-07-15 – LogManager Improvements
- **Filename format fix**: LogManager now uses standardized ISO 8601-like format (`YYYY-MM-DD_HH-mm-ss`) for log filenames, replacing problematic locale-dependent formats
- **Expanded test coverage**: Added comprehensive LogManager test suite covering all log levels, metadata handling, JSON format validation, concurrent logging, and edge cases (10/11 tests passing)
- **Improved test isolation**: Enhanced metadata test with unique markers to handle singleton pattern challenges
- **Documentation updates**: Updated ARCHITECTURE.md with corrected log filename format and improved debugging commands

## 2025-07-15 – Custom Logging System Implementation
- **LogManager service**: Complete JSON-based logging system with persistent file storage replacing Apple Unified Logging
- **LogEntry model**: Structured log entries with timestamp, level, category, message, metadata, and unique IDs
- **Session-based logging**: New log file created for each application session with timestamp in filename
- **Async logging**: Background queue for file operations to maintain UI responsiveness 
- **Test support**: LogManager.getLogFileContents() method for test verification

### 2025-07-14 – Recalculation Flow Re-architecture

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

## [1.2.0] - 2025-07-21

### Added
- Created `Constants.swift` to centralize configuration values.
- Added comprehensive architecture and async pattern documentation in `ARCHITECTURE.md`.
- Introduced `ConstantsTests.swift` to validate key configuration values.

### Changed
- **Technical debt resolution**: Standardized async patterns across services to align with new architectural guidelines.
- **Code maintainability**: Simplified complex publisher chains and improved code organization for better readability.

## [1.2.1] - 2025-07-22

### Changed
- **Refactor (State Management)**: Encapsulated import progress tracking into a new `ImportProgress` observable object, simplifying `AppState` and improving separation of concerns.
- **Refactor (Type Safety)**: Changed volume selection logic to use a type-safe `Volume.ID` instead of a raw `String`, reducing the risk of stringly-typed errors.

---

## [1.1.0] - 2025-07-16 