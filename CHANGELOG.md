# Changelog

## [Unreleased]

### Fixed
- Repaired a broken build state caused by a failed refactoring attempt. The application now compiles and all tests pass.
- Corrected numerous compilation errors across the app and test targets.

### Changed
- Reverted `FileProcessorService` to a clean, actor-based implementation, removing complex and non-functional dependency injection logic. Its API was simplified to a single `processFiles` method.
- Refactored `ImportService` from a `class` to an `actor` to improve thread safety and align with modern Swift concurrency practices.
- Simplified the app's initialization logic in `Media_MuncherApp.swift` and `ContentView.swift`.

### Removed
- Deleted obsolete unit tests (`FileProcessorServiceTests`, `ImportServiceTests`, `FileProcessorServiceDuplicateTests`) and mock files (`MockFileManager`, `MockSecurityScopedURLAccessWrapper`) that were based on a flawed and abandoned architectural pattern.

### Added
- Implemented a comprehensive integration test suite (`ImportServiceIntegrationTests`) that validates the end-to-end media import pipeline using the real file system in a temporary directory.
- Added a test utility (`Z_ProjectFileFixer.swift`) with a build phase script to ensure test fixtures are reliably copied into the test bundle, resolving a critical testing roadblock.
