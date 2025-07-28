
# Media Muncher Improvement Tasks

This document outlines the recommended improvement tasks for the Media Muncher project.

## High Priority

### 1. Resolve Duplicate Source Files

**Status: Completed**

**Issue:** There were multiple source files with the same name but different content in different subdirectories. This indicated an incomplete refactoring and could lead to confusion and bugs.

**Action:**
- Identified the correct and current versions of the files.
- Deleted the obsolete files and directories (`/Media Muncher/Models`, `/Media Muncher/Views`).
- Verified the Xcode project builds and all tests pass.

### 2. Unify Security Model Documentation

**Status: Completed**

**Issue:** The documentation contained conflicting information about the application's sandboxing status.

**Action:**
- Updated `PRD.md`, `ARCHITECTURE.md`, and `CLAUDE.md` to consistently state that the application is **not sandboxed** but uses **security-scoped bookmarks** for accessing removable volumes and user-selected folders.
- Verified that the implementation in `ImportService.swift` and `SettingsStore.swift` aligns with this security model.

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

