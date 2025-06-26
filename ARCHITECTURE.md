# Media Muncher – Architecture Guide

> **Purpose** – This document explains how the application is structured **today**. It doubles as a contributor guide: follow the conventions here when adding new functionality.

---
## 1. High-Level Overview

```
┌───────────────┐        insert/eject       ┌────────────────────┐
│ macOS System  │ ───────────────────────▶ │  VolumeManager     │
└───────────────┘  NSWorkspace events      │ (Service)          │
                                           └────────┬───────────┘
┌───────────────┐ scan files                        │ volumes
│  SwiftUI View │ ◀──────────────────────────────┐  │
└───────────────┘                                 │  │
      ▲                                           ▼  │
      │ UI Events, Data Binding              ┌───────────────┐
      └─────────────────────────────────────▶│   AppState    │
                                             │ (Orchestrator)│
                                             └───────┬───────┘
                                                     │
               ┌────────────────────┐ scan(volume)   │
               │ FileProcessorService├────────────────┘
               │ (Service Actor)    │◀───────────────────┐
               └────────────────────┘ files, progress    │
                                             ┌───────────────┐
                                             │ ImportService │
                                             │  (Service Actor)    │
                                             └───────────────┘
```

* The **SwiftUI layer** presents a sidebar of volumes, a grid of media files, and a settings panel. It binds to data published by the `AppState` and individual services.
* **Services** (`VolumeManager`, `FileProcessorService`, `SettingsStore`, `ImportService`) are focused classes/actors responsible for a single domain. They own their data and expose it via Combine publishers or async streams.
* **`AppState`** is a singleton `ObservableObject` that acts as an **Orchestrator** or **Facade**. It wires together the services and the UI, acting as a state machine manager for the UI. It contains very little business logic itself.
* **Models** (`Volume`, `File`, `AppError`) are simple value types passed between layers.
* All file-system work is done asynchronously so the UI never blocks.

---
## 2. Source-Code Map (current)

| File | Responsibility | Key Types / Functions |
|------|----------------|------------------------|
| **Media_MuncherApp.swift** | App entry point, service instantiation | `Media_MuncherApp` |
| **AppState.swift** | Orchestrates services and exposes unified state to the UI. Manages the UI state machine. | `AppState` |
| **Services/VolumeManager.swift** | Discovers, monitors, and ejects removable volumes. | `VolumeManager`|
| **Services/FileProcessorService.swift** | Scans a volume for media files on a background thread, maintains an in-actor **LRU thumbnail cache (2 000 entries)**, and detects pre-existing files in the destination. | `FileProcessorService` |
| **Services/SettingsStore.swift**| Persists user settings via `UserDefaults`. | `SettingsStore` |
| **Services/ImportService.swift**| Copies files to the destination using security-scoped bookmarks. Delegates all path calculation to `DestinationPathBuilder`. | `ImportService` |
| **Helpers/DestinationPathBuilder.swift** | Pure helper providing `relativePath(for:organizeByDate:renameByDate:)` and `buildFinalDestinationUrl(...)`; used by both **FileProcessorService** and **ImportService** to eliminate duplicated path-building logic and handle filename collisions. | `DestinationPathBuilder` |
| **Models/VolumeModel.swift** | Immutable record for a removable drive | `Volume` |
| **Models/FileModel.swift** | Immutable record for a media file & helpers | `File`, `MediaType`, `FileStatus`, `MediaType.from(filePath:)` |
| **Models/AppError.swift**| Domain-specific error types. | `AppError` |
| **ContentView.swift** | Arranges split-view, toolbar, Import button. | `ContentView` |
| **VolumeView.swift** | Sidebar showing all volumes, eject button. Binds to `VolumeManager`. | `VolumeView` |
| **MediaView.swift** | Decides what to show in detail pane. Binds to `AppState`. | `MediaView` |
| **MediaFilesGridView.swift** | Adaptive grid of media icons/filenames. Binds to `AppState`. | `MediaFilesGridView` |
| **MediaFileCellView.swift** | A small view that represents a single cell in the `MediaFilesGridView`, displaying the thumbnail and status overlays. | `MediaFileCellView` |
| **BottomBarView.swift** | The view at the bottom of the window that shows scan progress, import progress, and action buttons. | `BottomBarView` |
| **SettingsView.swift** | Toggles & folder picker. Binds to `SettingsStore`. | `SettingsView`, `FolderPickerView` |
| **ErrorView.swift** | Inline error banner. Binds to `AppState`. | `ErrorView` |
| **Tests/ImportServiceIntegrationTests.swift** | End-to-end tests for the entire import pipeline, operating on real files in a temporary directory. | `ImportServiceIntegrationTests` |
| **Tests/Z_ProjectFileFixer.swift** | A utility file containing a build script phase to ensure the `Fixtures` directory is copied into the test bundle. | `Z_ProjectFileFixer` |
| **Tests/Fixtures/** | A directory of sample media files (images, videos, duplicates) used by the integration tests. | - |

> **Observation** – The previous monolithic `AppState` has been refactored into focused services, improving separation of concerns.

---
## 3. Runtime Flow (today)
1. `Media_MuncherApp` instantiates `VolumeManager`, `FileProcessorService`, `SettingsStore`, `ImportService` and `AppState`. It injects them as `@EnvironmentObject`s.
2. `VolumeManager` uses `NSWorkspace` to discover and publish an array of `Volume`s.
3. `AppState` subscribes to `VolumeManager`'s volumes and automatically selects the first one.
4. The volume selection change is published by `AppState`.
5. On observing the change, `AppState` asks the `FileProcessorService` actor to begin scanning the selected volume.
6. `FileProcessorService` traverses the volume on a background task, batching results and progress into `AsyncStream`s.
7. `AppState` collects these stream results and updates its `@Published` `files` and `filesScanned` properties on the **MainActor**.
8. `MediaFilesGridView` and `ContentView` observe `AppState` and display the new files and progress as they arrive.
9. When **Import** is clicked, `AppState` calls the `ImportService` to copy the scanned files to the destination set in `SettingsStore`.

---
## 4. Planned Modularisation (to-be)

> This plan has now been implemented. The sections above reflect the new service-based architecture.

| Module | Responsibility | Notes |
|--------|----------------|-------|
| `VolumeManager` | Discover, eject & monitor volumes, expose `Publisher<[Volume]>` | Wrap `NSWorkspace` & external devices (future PTP/MTP). |
| `FileProcessorService` | **Phase 1:** fast filesystem walk that emits basic `File` structs (path, name, size) immediately; **Phase 2:** schedules asynchronous enrichment tasks that add heavy metadata (EXIF, thumbnails) without blocking the UI | Move initial `enumerateFiles()` here and spin-off a `MetadataEnricher` actor (or background `Task`) for phase 2. |
| `ImportService` | Copy files, handle duplicates, **remove thumbnail side-cars (".THM"/".thm") after each successful copy**, and pre-calculate the aggregate byte total of an import queue to enable accurate progress reporting | Detached actor handling concurrency & error isolation. **Handles file naming in a two-phase process: first it generates ideal destination paths based on templates; second it resolves any name collisions within that list before any copy operations begin.** |
| `SettingsStore` | Type-safe wrapper around `UserDefaults` & security bookmarks | Provides Combine `@Published` properties. |
| `Logger` | Structured logging (os
data, rotating file handler) | Respect user privacy; in dev builds default to `stdout`. |
| `AppState` | Pure composition root that orchestrates above services | Slimmed down, no heavy logic. |

### Dependency Flow (to-be)
`SwiftUI View → AppState (Facade) → Services (actors) → Foundation / OS`  
No service depends back on SwiftUI, keeping layers clean.

---
## 5. Concurrency Model
* **Actors** – `FileProcessorService` & `ImportService`
* **MainActor** – Only UI changes run here; services stay off the main thread.
* **Task Cancellation** – Long-running scans / imports call `Task.checkCancellation()` each iteration.

---
## 6. Error Handling Strategy
* Domain-specific `enum AppError : Error` with associated values for context.
* Services throw typed errors; `AppState` converts them into user-facing banners or alerts.
* Never crash on disk-I/O error – report & allow the user to retry.

---
## 7. Persistence & Idempotency
* Destination file uniqueness is guaranteed by a combination of capture-date and file-size. This logic is centralized in `DestinationPathBuilder` to ensure consistency.
* The **filesystem is the single source of truth**. Import operations always recompute the expected destination path; if a file already exists it is skipped.
* User settings are stored in `UserDefaults` (some as security-scoped bookmarks).

---
## 8. Security & Sandboxing
* Entitlements: `com.apple.security.device.usb`, `com.apple.security.files.user-selected.read-write`, `com.apple.security.files.removable`.
* Destination folder persisted as a security-scoped bookmark so user grants access once.
* No plain file paths are stored outside the sandbox container.

---
## 9. Testing Strategy
Our testing strategy prioritizes high-fidelity integration tests over mock-based unit tests for code that interacts with the file system. This gives us greater confidence that the application works correctly in real-world scenarios.

*   **Integration Tests (Primary)**: The core of our test suite is `ImportServiceIntegrationTests.swift`. These tests create temporary directories on disk, populate them with fixture files, and run the entire import pipeline (`FileProcessorService` and `ImportService`) from start to finish. This validates file discovery, metadata parsing, path generation, collision handling, and file copying/deletion in a realistic environment.
*   **Unit Tests (For Pure Logic)**: Unit tests are reserved for pure, isolated business logic that has no dependencies on the file system or other services. A key example is `DestinationPathBuilderTests.swift`, which can verify path-generation logic without needing to touch the disk.
*   **Test Fixtures**: A dedicated `Media MuncherTests/Fixtures/` directory contains a curated set of media files to cover various test cases (e.g., images with and without EXIF data, duplicates, videos with sidecars). A utility, `Z_ProjectFileFixer.swift`, contains a build-phase script to ensure these fixtures are correctly copied into the test bundle and are available to the integration tests at runtime.

---
## 10. Code Style & Contribution Guidelines
1. **Formatting** – `swiftformat` with repo-pinned rules.
2. **Naming** – Apple conventions; acronyms upper-cased (`UUID`, `URL`).
3. **Docs** – Every public symbol must have a Markdown doc comment.
4. **Commits** – Conventional Commits prefixed with PRD story ID.
5. **Branches** – `main`, `feature/<story-id>`, `bugfix/<issue>`, `release/*`.
6. **Pull Requests** – Must pass unit tests (`xcodebuild test`) and review; include before/after screenshots for UI.
7. **Feature Flags** – Use `#if DEBUG` or `UserDefaults` keys.

---
## 11. Build & Run (developers)
```bash
# prereqs
xcode-select --install  # command-line tools
brew install swiftformat swiftlint

open "Media Muncher.xcodeproj"
```
* Deployment target macOS 13+.
* Run the **Media Muncher** scheme; press ⌘U for tests.

---
## 12. Frequently Asked Questions
**Q:** Why not just use Photos.app import?  
**A:** Media Muncher offers a custom folder hierarchy, no proprietary library, automation hooks, and supports professional RAW/video formats that Photos ignores.

---
## 13. File Interaction Diagram
```mermaid
graph TD;
  subgraph Services
    VM(VolumeManager)
    FPS(FileProcessorService)
    SS(SettingsStore)
    IS(ImportService)
    DPB(DestinationPathBuilder)
  end

  subgraph UI
    CV(ContentView)
    VV(VolumeView)
    GV(MediaFilesGridView)
    SV(SettingsView)
    EV(ErrorView)
  end
  
  App(Media_MuncherApp) -- instantiates --> AS(AppState)
  App --> VM & FPS & SS & IS

  AS --> VM & FPS & SS & IS
  
  CV --> AS
  VV --> VM & AS
  GV --> AS
  SV --> SS
  EV --> AS

  VM -- publishes volumes --> AS
  FPS -- streams files --> AS
  FPS --> DPB
  IS --> DPB
```

---
## 14. Recent Maintenance (2025-06-25)
* **ALT-1** – Introduced `DestinationPathBuilder` helper; `ImportService` & `FileProcessorService` now delegate path logic → single source of truth.
* Purged all Automation/LaunchAgent code (Epic-7 reset).
* Added LRU thumbnail cache (2 000 entries) into `FileProcessorService` actor.
* Renamed `MediaScanner` to `FileProcessorService` for clarity.

## 15. Recent Maintenance (2025-06-27)
* Added four new pure-Swift **unit-test suites** covering `DestinationPathBuilder`, `FileProcessorService`, `ImportService`, and filename-collision edge cases. This reverses the accidental deletion of unit tests and restores a solid safety-net for future refactors.
* Fixed EXIF time-zone parsing bug by forcing `DateFormatter` to UTC inside `FileProcessorService`.
* Introduced `BUGS.md` to keep a living list of test-proven regressions. Initial entries track collision-handling, pre-existing detection, thumbnail enumeration, and a failing integration path-generation test.

## 16. Recent Maintenance (2025-06-26)
* Enabled read-only volume support: `ImportService` continues imports when originals cannot be deleted. The failure is surfaced via `.importSucceededWithDeletionErrors` and shown by the BottomBar `ErrorView`.
* Fixed filename-collision and pre-existing detection logic in `FileProcessorService`.
* All automated tests now pass; collision/pre-existing tests moved from **Bug** to **Finished**.