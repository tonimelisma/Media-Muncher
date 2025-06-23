# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-06-22
### Added
- Users can now enable a setting to automatically delete original files from the source volume after a successful import.
- A new setting allows users to automatically eject the source volume after a successful import, further streamlining the workflow.
- New error state to inform the user when an import succeeds but the deletion of original files fails.

### Changed
- The settings screen now includes a toggle for the new auto-eject feature.
- Import logic now includes post-import steps for deletion and ejection.

## [Unreleased]

### Added
- **File Organization and Renaming**: Added options in Settings to automatically organize imported files into date-based folders (`YYYY/MM`) and rename them using a `TYPE_YYYYMMDD_HHMMSS` format. This feature helps users keep their media libraries tidy. (Addresses PRD Story: IE-2, IE-7, IE-4, IE-10, ST-3)
- **Advanced Conflict Resolution**: The import service now detects filename collisions and appends a numerical suffix (`_1`, `_2`, etc.) to prevent overwriting existing files.
- **Thumbnail Generation**: The grid view now displays asynchronously-loaded thumbnails for image and video files, replacing the generic SF Symbol icons. This provides a much richer visual preview of media on a volume. (Addresses PRD Story: MD-3)

## [0.2.1] - 2025-06-17

### Added
- Core import functionality to copy files from a source volume to a user-selected destination folder.
- Use of security-scoped bookmarks to securely access the destination folder across app launches, a requirement for sandboxed macOS apps.
- A new `ImportService` to encapsulate all import-related logic, improving separation of concerns.
- A `ProgressView` in the UI to give users feedback during the import process.
- An `ImportError` enum and corresponding user-facing alerts for better error handling.
- Unit tests for `ImportService`, including tests for success, copy failures, and destination access denial.
- Mocking protocols (`FileManagerProtocol`, `SecurityScopedURLAccessWrapperProtocol`) to enable robust testing of the import service in isolation.

### Changed
- Refactored `SettingsStore` to save the destination folder's security-scoped bookmark (`Data`) instead of a raw `String` path.
- Updated `SettingsView` to be URL-based, improving its interaction with `SettingsStore`.
- Modified `AppState` to orchestrate the import process, manage import state, and handle errors.
- Updated `ContentView` to trigger the import and display the new progress indicator.
- Re-architected `ImportService` and tests to use dependency injection, making the code more modular and testable.
- Added necessary entitlements for App Sandboxing (`com.apple.security.app-sandbox`) and security-scoped bookmarks (`com.apple.security.files.bookmarks.app-scope`).

### Fixed
- Multiple build errors related to protocol conformance, equatable implementation, and incorrect mock usage during the development of the import feature.

## [0.1.0] - 2025-06-21

### Added
- Initial project setup.
- Basic volume detection and display.
- Media file scanning and listing.
- Basic import functionality.
- Settings screen with destination folder and delete options.

### Changed
- Updated PRD statuses: `UI-2` **Finished**; `MD-2` **Finished** (live progress & cancel).