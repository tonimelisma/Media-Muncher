# Changelog

All notable changes to Media Muncher will be documented in this file.

## [Unreleased]

### Added
- Support for importing from read-only volumes: originals are left intact and a non-fatal banner notifies the user once the import completes.
- New unit-test `ImportServiceIntegrationTests.testImport_readOnlySource_deletionFailsButImportSucceeds`.
- New **state-machine** unit tests covering scan cancellation and auto-eject logic (`AppStateWorkflowTests`).
- **Destination Path Recalculation System**: Automatic recalculation of file destination paths when users change the destination directory in Settings, preserving thumbnails and metadata while updating paths.
- Synchronous path calculation methods for improved test reliability and performance.

### Fixed
- Filename-collision handling now appends numeric suffixes ("_1", "_2", …) when a different file already exists at the destination.
- Pre-existing file detection improved: identical files are recognised even if modification timestamps differ slightly or filenames already match.
- Test reliability improved by eliminating all `Task.sleep()` operations and implementing deterministic testing patterns.
- Test `testAppStateHandlesDestinationChangesGracefully` now properly creates required directories before testing destination changes.

### Changed
- **Enhanced "Delete originals"**: When enabled, this setting now also deletes source files that are identified as duplicates already present in the destination, helping to clean up source media more effectively.
- `ImportService` treats failures to delete originals as warnings instead of errors, allowing the import process to continue.
- Bottom bar error banner now surfaces "Import succeeded with deletion errors" when originals could not be removed.
- **FileProcessorService Architecture**: Split file processing into sync path calculation and async file I/O operations for better testability and performance.
- Removed code duplication in collision detection logic by extracting shared destination resolution methods. 