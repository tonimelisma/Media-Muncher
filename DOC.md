
# Media Muncher Improvement Tasks

This document outlines the recommended improvement tasks for the Media Muncher project.

## High Priority

### 1. Resolve Duplicate Source Files

**Issue:** There are multiple source files with the same name but different content in different subdirectories. This indicates an incomplete refactoring and can lead to confusion and bugs.

**Action:**
- Identify the correct and current versions of the following files:
    - `Media Muncher/FileModel.swift` vs. `Media Muncher/Models/FileModel.swift`
    - `Media Muncher/VolumeModel.swift` vs. `Media Muncher/Models/VolumeModel.swift`
    - `Media Muncher/ContentView.swift` vs. `Media Muncher/Views/ContentView.swift`
    - `Media Muncher/Protocols/Logging.swift` vs. the `Logging` protocol in `Media Muncher/Services/LogManager.swift`
- Delete the obsolete files.
- Ensure the Xcode project references only the correct files.

### 2. Unify Security Model Documentation

**Issue:** The documentation contains conflicting information about the application's sandboxing status.

**Action:**
- Update `PRD.md` and `ARCHITECTURE.md` to consistently state that the application is **not sandboxed** but uses **security-scoped bookmarks** for accessing removable volumes and user-selected folders.
- Verify that the implementation in `ImportService.swift` and `SettingsStore.swift` aligns with this security model.

## Medium Priority

### 3. Update `ARCHITECTURE.md`

**Issue:** The architecture document is slightly out of date.

**Action:**
- Add `FileStore.swift` and `DestinationPathBuilder.swift` to the "Source-Code Map".
- Mention `Media Muncher/Helpers/Glob.swift` in the documentation.
- Update the logging section to reflect the correct log file format: `media-muncher-YYYY-MM-DD_HH-mm-ss-<pid>.log`.

### 4. Refactor `CLAUDE.md`

**Issue:** The `CLAUDE.md` file contains redundant information from `ARCHITECTURE.md`.

**Action:**
- Remove the "Architecture Overview" and "File Organization" sections.
- Add a link to `ARCHITECTURE.md` for architecture-related information.
- Correct the log file path to `media-muncher-YYYY-MM-DD_HH-mm-ss-<pid>.log`.

## Low Priority

### 5. Refactor `DestinationFolderPicker`

**Issue:** The `DestinationFolderPicker` uses `NSViewRepresentable`, which is a valid approach but not a pure SwiftUI solution.

**Action:**
- Consider refactoring `DestinationFolderPicker` to use a native SwiftUI `Menu` for a more modern implementation. This is a "nice-to-have" improvement.
