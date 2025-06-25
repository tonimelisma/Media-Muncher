# Changelog

## [Unreleased]

### Added
- **Source Duplicate Detection**: The app now detects and marks duplicate files within the source media itself, preventing them from being imported multiple times. An icon indicates these files in the grid.
- **Robust Collision Handling**: Implemented a sophisticated file-naming collision algorithm that handles three types of conflicts:
    1.  Files that are identical to files already in the destination.
    2.  Files that would have the same destination name as a different file already on disk.
    3.  Files within the same import session that would resolve to the same destination name.
- Suffixes (e.g., `_1`, `_2`) are now correctly appended to resolve naming conflicts.

### Changed
- **Refactored Core Logic**: Replaced the monolithic `MediaScanner` with a new `FileProcessorService` that uses a more efficient two-step process:
    1.  A fast initial scan to quickly populate the UI with file placeholders.
    2.  An asynchronous second pass to enrich each file with metadata, a thumbnail, and resolve its final destination path.
- **UI Performance**: The main file grid now populates almost instantly, with thumbnails and status icons loading in progressively. This provides a much more responsive user experience.
- Updated all relevant views and services to use the new `FileProcessorService`. 