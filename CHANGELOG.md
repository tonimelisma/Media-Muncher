# Changelog

## [Unreleased]

### Added
- **Automation Engine**: The app can now be configured to automatically launch when a removable volume is connected.
- A new "Automation" section in Settings allows users to enable/disable the auto-launch feature globally.
- Per-volume automation settings: For each connected volume, users can choose to "Automatically Import", "Ask What to Do", or "Ignore".

### Changed
- The settings UI now shows automation controls only for currently connected volumes.

---

## [0.2.1] - 2025-06-19

### Added
- Files can now be automatically organized into date-based subfolders (e.g., `YYYY/MM/`).
- Files can be automatically renamed using a template (e.g., `IMG_YYYYMMDD_HHMMSS.jpg`).
- New toggles in Settings to control the new organization and renaming features.
- Unit tests for file organization and renaming logic.

### Fixed
- Corrected a concurrency issue where simultaneous file access could lead to errors during import.
- Ensured file extensions are consistently lowercased during the renaming process.
- Hardened the import process against invalid file metadata.

---

## [0.2.0] - 2025-05-22

### Added
- Files that already exist in the destination are now marked with a "PRE-EXISTING" badge and are not selected for import by default.
- The import service now correctly skips copying files that already exist at the destination based on a metadata hash check.
- Added a `pre-existing` status to the `File` model.

### Changed
- Refactored the `MediaScanner` to perform the pre-existence check during the initial file enumeration for better performance.

---

## [0.1.0] - 2025-02-13

### Added
- Initial release of Media Muncher.
- List connected removable volumes.
- Scan volumes for media files (images, videos, audio).
- Display discovered media in an adaptive grid.
- Select and import files to a user-defined destination.
- Option to delete original files after a successful import.
- Option to automatically eject the volume after import.
- Basic error handling for destination write failures.
- Rudimentary settings panel for controlling import options.
- Basic UI with light and dark mode support. 