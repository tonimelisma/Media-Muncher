# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Thumbnail Generation**: The grid view now displays asynchronously-loaded thumbnails for image and video files, replacing the generic SF Symbol icons. This provides a much richer visual preview of media on a volume. (Addresses PRD Story: MD-3)

## [0.2.0] - 2025-06-22

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