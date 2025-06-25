# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-06-25

### Added
- **Transactional File Import**: The import process is now fully transactional and resilient. Each file is individually copied, verified, and marked as complete. This provides real-time progress updates in the UI (e.g., "Copying", "Verifying", "Imported") on a per-file basis.
- **Per-File Error Handling**: If a file fails during copy or verification, it is visually marked as failed in the grid, and the user can see the specific error message. The import process continues with the remaining files.
- **Source Duplicate Detection**: The app now detects and marks duplicate files within the source media itself, preventing them from being imported multiple times. An icon indicates these files in the grid.
- **Robust Collision Handling**: Implemented a sophisticated file-naming collision algorithm that handles three types of conflicts:
    1.  Files that are identical to files already in the destination.
    2.  Files that would have the same destination name as a different file already on disk.
    3.  Files within the same import session that would resolve to the same destination name.
- Suffixes (e.g., `_1`, `_2`) are now correctly appended to resolve naming conflicts.
- Thumbnail caching in `FileProcessorService` to improve performance.
- **Thumbnail Side-car Cleanup (IE-9)**: after each successful copy the app now deletes `.THM` / `.thm` side-car thumbnails that OEM cameras generate, saving disk space.
- **Import ETA & Elapsed Time**: the bottom bar now shows human-friendly elapsed time plus a dynamic time-remaining estimate based on current throughput.
- **Unified Test Framework**: migrated residual QuickCheck/Testing tests to pure XCTest; all unit tests now live in a single scheme and run via `xcodebuild test`.

### Changed
- **Refactored Core Logic**: Replaced the monolithic `MediaScanner` with a new `FileProcessorService` that uses a more efficient two-step process:
    1.  A fast initial scan to quickly populate the UI with file placeholders.
    2.  An asynchronous second pass to enrich each file with metadata, a thumbnail, and resolve its final destination path.
- **UI Performance**: The main file grid now populates almost instantly, with thumbnails and status icons loading in progressively. This provides a much more responsive user experience.
- Updated all relevant views and services to use the new `FileProcessorService`.
- Refactored UI into smaller, more manageable views: `BottomBarView` and `MediaFileCellView`.
- Refactored thumbnail generation to be self-contained in `FileProcessorService`.

### Removed
- Legacy `Testing` framework stubs and the obsolete `Media_MuncherTests.swift` placeholder file.

### Fixed
- Restored `FileProcessorServiceTests` by improving mocks and adjusting expectations.
- Rewritten test mocks to fix `FileProcessorServiceTests` failures.
- Fixed flaky mock behaviour that caused `FileProcessorServiceTests` to be skipped; the suite now passes except for an intentionally-failing regression guard.

## [0.1.0] - 2025-02-17

### Added
- Initial implementation of the Media Muncher application.
- Core features: volume detection, media file scanning, and importing. 