# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **File Organization and Renaming**: Added options in Settings to automatically organize imported files into date-based folders (`YYYY/MM`) and rename them using a `TYPE_YYYYMMDD_HHMMSS` format. This feature helps users keep their media libraries tidy. (Addresses PRD Story: IE-2, IE-7, IE-4, IE-10, ST-3)
- **Advanced Conflict Resolution**: The import service now detects filename collisions and appends a numerical suffix (`_1`, `_2`, etc.) to prevent overwriting existing files.
- **Thumbnail Generation**: The grid view now displays asynchronously-loaded thumbnails for image and video files, replacing the generic SF Symbol icons. This provides a much richer visual preview of media on a volume. (Addresses PRD Story: MD-3)

## [0.6.0] - 2025-06-23
### Added
- Implemented a detailed import progress bar in the bottom toolbar (UI-3).
- The progress view shows the number of files copied, the total size of the import, and a visual progress bar.
- A "Cancel" button is now shown during import to allow the user to stop the operation.

## [0.5.0] - 2025-06-22
### Added
- **Thumbnail Folder Skipping**: The app now intelligently skips common thumbnail folders (e.g., `THMBNL`, `.thumbnails`) during media discovery. (Addresses PRD Story: MD-6)
- **Associated Thumbnail Deletion**: When deleting original media files after import, the app now also deletes any associated thumbnail files (e.g., `.THM`). (Addresses PRD Story: IE-9)

## [0.4.0] - 2025-06-22
### Added
- **Media Type Filtering**: Users can now select which media types (images, videos, audio) to scan for in the settings. This allows for more focused imports and avoids cluttering the file list with unwanted file types. (Addresses PRD Story: ST-5)

## [0.3.0] - 2025-06-22
### Added
- Users can now enable a setting to automatically delete original files from the source volume after a successful import.
- A new setting allows users to automatically eject the source volume after a successful import, further streamlining the workflow.
- New error state to inform the user when an import succeeds but the deletion of original files fails.

### Changed
- The settings screen now includes a toggle for the new auto-eject feature.
- Import logic now includes post-import steps for deletion and ejection.

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
- Files are now correctly renamed according to the `TYPE_YYYYMMDD_HHMMSS.ext` template when the setting is enabled.
- Destination subdirectories (`YYYY/MM`) are now created as expected when the setting is enabled.

## [0.2.0] - 2025-06-15
### Added
- Users can now choose to have files renamed by date (`TYPE_YYYYMMDD_HHMMSS.ext`) and organized into date-based subfolders (`YYYY/MM`).
- Added corresponding toggles to the Settings view.

## [0.1.0] - 2025-02-15
### Added
- Initial release.
- Lists removable volumes.
- Scans volumes for media files and displays them in a grid.
- Basic import functionality to a user-selected destination.
- Settings for choosing destination and deleting originals after import.
