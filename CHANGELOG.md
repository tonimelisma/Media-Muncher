# Changelog

All notable changes to Media Muncher will be documented in this file.

## [Unreleased]

### Added
- Support for importing from read-only volumes: originals are left intact and a non-fatal banner notifies the user once the import completes.
- New unit-test `ImportServiceIntegrationTests.testImport_readOnlySource_deletionFailsButImportSucceeds`.
- New **state-machine** unit tests covering scan cancellation and auto-eject logic (`AppStateWorkflowTests`).

### Fixed
- Filename-collision handling now appends numeric suffixes ("_1", "_2", …) when a different file already exists at the destination.
- Pre-existing file detection improved: identical files are recognised even if modification timestamps differ slightly or filenames already match.

### Changed
- `ImportService` treats failures to delete originals as warnings instead of errors, allowing the import process to continue.
- Bottom bar error banner now surfaces "Import succeeded with deletion errors" when originals could not be removed. 