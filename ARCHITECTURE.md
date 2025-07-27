# Media Muncher – Architecture Guide

> **Purpose** – This document explains how the application is structured **today**. It doubles as a contributor guide: follow the conventions here when adding new functionality.

---
## 1. High-Level Overview

```
┌───────────────┐        insert/eject       ┌────────────────────┐
│ macOS System  │ ───────────────────────▶ │  VolumeManager     │
└───────────────┘  NSWorkspace events      │ (Service)          │
                                           └────────┬───────────┘
┌───────────────┐ scan results                      │ volumes
│  SwiftUI View │ ◀──────────────────────────────┐  │
└───────────────┘                                 │  │
      ▲                                           ▼  │
      │ UI Events, Data Binding              ┌───────────────┐
      └─────────────────────────────────────▶│   AppState    │
                                             │ (Orchestrator)│
                                             └───────┬───────┘
                                                     │
                                scan(volume)         │ import(files)
                       ┌────────────────────┐        │        ┌────────────────────┐
                       │ FileProcessorService├────────┘        └────────┤ ImportService │
                       │ (Service Actor)    │                         │ (Service Actor)    │
                       └────────────────────┘                         └────────────────────┘
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
| **Services/FileProcessorService.swift** | Scans a volume for media files on a background thread with **count-based batching (50-file groups)** for UI performance, maintains an **in-memory thumbnail cache (2,000 entry limit)**, and detects pre-existing files in the destination. Provides both legacy and streaming interfaces via `AsyncStream<[File]>`. | `FileProcessorService` |
| **Services/SettingsStore.swift**| Persists user settings via `UserDefaults`. Uses security-scoped resources for folder access when needed. | `SettingsStore` |
| **Services/RecalculationManager.swift**| Dedicated state machine for handling destination change recalculations. Manages file path updates with proper error handling and cancellation support. | `RecalculationManager` |
| **Services/ImportService.swift**| Copies files to the destination using security-scoped resource access. Delegates all path calculation to `DestinationPathBuilder`. Handles sidecar files (THM, XMP, LRC) automatically. | `ImportService` |
| **Services/ThumbnailCache.swift** | Actor-based thumbnail generation & dual LRU cache (Data + Image) shared across FileProcessorService and UI. Stores JPEG data for thread safety and SwiftUI Images for direct UI access. Keeps heavy QuickLook work off the MainActor. Available via SwiftUI environment injection. | `ThumbnailCache` |
| **Helpers/DestinationPathBuilder.swift** | Pure helper providing `relativePath(for:organizeByDate:renameByDate:)` and `buildFinalDestinationUrl(...)`; used by both **FileProcessorService** and **ImportService** to eliminate duplicated path-building logic and handle filename collisions. | `DestinationPathBuilder` |
| **LogEntry.swift** | JSON-encodable log entry model | `LogEntry`, `LogLevel` |
| **Services/LogManager.swift** | Custom logging system with file persistence and rotation | `LogManager` |
| **Models/VolumeModel.swift** | Immutable record for a removable drive | `Volume` |
| **Models/FileModel.swift** | Immutable record for a media file & helpers. Thread-safe with `thumbnailData: Data?` instead of `Image` for Sendable compliance. | `File`, `MediaType`, `FileStatus`, `MediaType.from(filePath:)` |
| **Models/AppError.swift**| Domain-specific error types. | `AppError` |
| **ContentView.swift** | Arranges split-view, toolbar, Import button. | `ContentView` |
| **VolumeView.swift** | Sidebar showing all volumes, eject button. Binds to `VolumeManager`. | `VolumeView` |
| **MediaView.swift** | Decides what to show in detail pane. Binds to `AppState`. | `MediaView` |
| **MediaFilesGridView.swift** | Adaptive grid of media icons/filenames. Binds to `AppState`. | `MediaFilesGridView` |
| **MediaFileCellView.swift** | A small view that represents a single cell in the `MediaFilesGridView`, displaying the thumbnail and status overlays. | `MediaFileCellView` |
| **BottomBarView.swift** | The view at the bottom of the window that shows scan progress, import progress, and action buttons. | `BottomBarView` |
| **ImportProgress.swift**| An observable object that encapsulates all state related to an ongoing import operation, simplifying `AppState`. | `ImportProgress` |
| **SettingsView.swift** | Toggles & destination folder picker. Binds to `SettingsStore`. | `SettingsView`, `DestinationFolderPicker` (AppKit wrapper) |
| **ErrorView.swift** | Inline error banner. Binds to `AppState`. | `ErrorView` |
| **Tests/ImportServiceIntegrationTests.swift** | End-to-end tests for the entire import pipeline, operating on real files in a temporary directory. | `ImportServiceIntegrationTests` |
| **Tests/Fixtures/** | A directory of sample media files (images, videos, duplicates) used by the integration tests. | - |

> **Observation** – The previous monolithic `AppState` has been refactored into focused services, improving separation of concerns.

---
## 3. Runtime Flow (today)
1. `Media_MuncherApp` instantiates `VolumeManager`, `FileProcessorService`, `SettingsStore`, `ImportService`, `RecalculationManager` and `AppState`. It injects them as `@EnvironmentObject`s.
2. `VolumeManager` uses `NSWorkspace` to discover and publish an array of `Volume`s.
3. `AppState` subscribes to `VolumeManager`'s volumes and automatically selects the first one.
4. The volume selection change is published by `AppState`.
5. On observing the change, `AppState` asks the `FileProcessorService` actor to begin scanning the selected volume using the streaming interface.
6. `FileProcessorService` traverses the volume on a background task, **batching results in groups of 50 files** before emitting via `AsyncStream<[File]>` to prevent UI jank.
7. `AppState` collects these batched stream results, buffers them further, and updates its `@Published` `files` and `filesScanned` properties on the **MainActor** only when the buffer reaches capacity or scanning completes.
8. `MediaFilesGridView` and `ContentView` observe `AppState` and display the new files and progress as they arrive.
9. When **Import** is clicked, `AppState` calls the `ImportService` to copy the scanned files to the destination set in `SettingsStore`.
10. When the destination changes in `SettingsStore`, `AppState` delegates to `RecalculationManager` to recalculate file paths and statuses.

---
## 4. Architectural Principles

| Module | Responsibility | Notes |
|--------|----------------|-------|
| `VolumeManager` | Discover, eject & monitor volumes, expose `Publisher<[Volume]>` | Wrap `NSWorkspace` & external devices (future PTP/MTP). |
| `FileProcessorService` | **Phase 1:** fast filesystem walk that emits basic `File` structs (path, name, size) immediately; **Phase 2:** schedules asynchronous enrichment tasks that add heavy metadata (EXIF, thumbnails) without blocking the UI | Move initial `enumerateFiles()` here and spin-off a `MetadataEnricher` actor (or background `Task`) for phase 2. |
| `ImportService` | Copy files, handle duplicates, **remove sidecar files (THM, XMP, LRC) after each successful copy**, and pre-calculate the aggregate byte total of an import queue to enable accurate progress reporting | Detached actor handling concurrency & error isolation. **Uses simple numerical suffix collision resolution (_1, _2, etc.) to ensure unique destination paths.** |
| `SettingsStore` | Type-safe wrapper around `UserDefaults` with synchronous initialization and security-scoped resource access when needed | Provides Combine `@Published` properties for all user settings including RAW file filtering. Uses deterministic constructor with immediate default destination availability. |
| `RecalculationManager` | Dedicated state machine for destination change recalculations | Handles file path updates when destination changes, with proper error handling and task cancellation. |
| `LogManager` | Custom JSON-based logging system with persistent file storage | Centralized logging with category-based organization, rotating log files, and structured metadata for debugging and monitoring. All logging calls are fully `async`. |
| `AppState` | Pure composition root that orchestrates above services | Slimmed down, no heavy logic. |

### Dependency Flow
`SwiftUI View → AppState (Facade) → Services (actors) → Foundation / OS`  
No service depends back on SwiftUI, keeping layers clean.

---
## 5. Concurrency Model & Async Patterns

Media Muncher follows a **"Hybrid with Clear Boundaries"** approach to async programming, leveraging different concurrency tools for their specific strengths.

### Architectural Async Patterns

| Layer | Pattern | Purpose | Usage |
|-------|---------|---------|-------|
| **UI Layer** | MainActor + Combine | SwiftUI reactive binding | `@MainActor` classes with `@Published` properties |
| **Service Layer** | Actors + Async/Await | Thread-safe file operations | `actor` for I/O, pure `async func` interfaces with no completion handlers. |
| **Cross-Layer** | Async/Await + Task | Background coordination | Service calls via `await`, `Task` for lifecycle |
| **Progress Reporting** | AsyncThrowingStream | Real-time updates | Only for import progress with backpressure |
| **State Management** | Combine Publishers | Reactive UI updates | Settings and configuration changes |
| **ThumbnailCache** | Actor | CPU-bound QuickLook thumbnail generation, shared across service & UI | `ThumbnailCache` actor handles IO & LRU eviction off main thread |

### Pattern Guidelines

#### When to Use Actors
- ✅ File system operations (`FileProcessorService`, `ImportService`)
- ✅ Shared mutable state that needs isolation
- ✅ Operations that must be serialized
- ❌ UI state management (use `@MainActor` instead)
- ❌ Simple configuration holders

#### When to Use AsyncThrowingStream
- ✅ Progress reporting with backpressure (`ImportService.importFiles`)
- ✅ Long-running operations that need incremental updates
- ❌ Simple request-response patterns (use `async func`)
- ❌ State synchronization (use Combine publishers)

#### When to Use Combine Publishers
- ✅ Reactive UI binding (`@Published` properties)
- ✅ Settings and configuration changes
- ✅ Volume mount/unmount events
- ❌ File system operations (use async/await)
- ❌ Complex data processing (use actors)

### Concurrency Implementation Details
* **Actors** – `FileProcessorService` & `ImportService` for file system isolation
* **MainActor** – `AppState` & `RecalculationManager` for UI coordination
* **No MainActor on DI Container** - The `AppContainer` is not MainActor-isolated, allowing its initialization and service creation to start off the main thread.
* **Task Management** – Explicit cancellation support via stored `Task` references
* **Publisher Chains** – Simplified with helper methods to improve readability

---
## 6. Error Handling Strategy
* Domain-specific `enum AppError : Error` with associated values for context.
* Services throw typed errors; `AppState` converts them into user-facing banners or alerts.
* Never crash on disk-I/O error – report errors to user via UI.

---
## 7. Persistence & Idempotency
* Destination file uniqueness is guaranteed by a combination of capture-date and file-size. This logic is centralized in `DestinationPathBuilder` to ensure consistency.
* The **filesystem is the single source of truth**. Import operations always recompute the expected destination path; if a file already exists it is skipped.
* User settings are stored in `UserDefaults` with standard file paths.

---
## 8. Security & Permissions
* **Application is not sandboxed** but uses security-scoped resources defensively for removable volumes and user-selected folders.
* SecurityScopedURLAccessWrapper provides fallback access when standard file system permissions are insufficient.
* Write-access validation is performed before setting destination folders.
* Destination folder paths are stored as standard file paths, with security-scoped resource access acquired as needed.

---
## 9. Testing Strategy
Our testing strategy prioritizes high-fidelity integration tests over mock-based unit tests for code that interacts with the file system. This gives us greater confidence that the application works correctly in real-world scenarios.

*   **Integration Tests (Primary)**: The core of our test suite is `ImportServiceIntegrationTests.swift`. These tests create temporary directories on disk, populate them with fixture files, and run the entire import pipeline (`FileProcessorService` and `ImportService`) from start to finish. This validates file discovery, metadata parsing, path generation, collision handling, and file copying/deletion in a realistic environment.
*   **Unit Tests (For Pure Logic)**: Unit tests are reserved for pure, isolated business logic that has no dependencies on the file system or other services. A key example is `DestinationPathBuilderTests.swift`, which can verify path-generation logic without needing to touch the disk. Time-dependent tests like `ImportProgressTests` use dependency injection for deterministic behavior.
*   **Test Fixtures**: A dedicated `Media MuncherTests/Fixtures/` directory contains a curated set of media files to cover various test cases (e.g., images with and without EXIF data, duplicates, videos with sidecars). A utility, `Z_ProjectFileFixer.swift`, contains a build-phase script to ensure these fixtures are correctly copied into the test bundle and are available to the integration tests at runtime.
*   **Test Reliability**: All tests avoid `Task.sleep()` operations, using deterministic dependency injection and publisher-based coordination instead. This ensures consistent execution times and eliminates flaky behavior across different system loads.

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
## 11. Logging & Debugging with LogManager

Media Muncher uses an **actor-based** JSON logging system. Each process (app run, XCTest host, command-line tool) opens **one** log file named `media-muncher-YYYY-MM-DD_HH-mm-ss-<pid>.log`, guaranteeing uniqueness without race conditions. The actor holds a single `FileHandle`, serialises all writes, and therefore provides atomic, thread-safe logging under Swift Concurrency. All logging functions are `async` and must be awaited.

**Convenient Log Access:** The project includes a symbolic link `./logs/` (git-ignored) that points to `~/Library/Logs/Media Muncher`, allowing developers to easily access logs using standard command-line tools:
```bash
ls logs/                    # Browse log files
cat logs/media-muncher-*.log    # View log contents  
tail -f logs/media-muncher-*.log # Real-time monitoring
```

To prevent log-directory bloat the logger prunes any file older than **30 days** at start-up; no size-based rotation is required.

Developers interact with the logger only through the `Logging` protocol injected into every service (`logManager: Logging = LogManager()`). A convenience extension provides `debug / info / error` helpers.

### Log File Format
**Location**: `~/Library/Logs/Media Muncher/`  
**Filename Format**: `media-muncher-YYYY-MM-DD_HH-mm-ss.log`  
**Content Format**: One JSON object per line

### JSON Log Entry Structure
```json
{
  "timestamp": 774334060.621426,
  "level": "DEBUG",
  "message": "Initializing SettingsStore", 
  "id": "573004EF-D3E6-453E-978D-0915FF4C9FFC",
  "category": "SettingsStore",
  "metadata": {
    "key": "value",
    "path": "/Users/user/Pictures"
  }
}
```

### Debugging Commands
```bash
# View recent logs
tail -f ~/Library/Logs/Media\ Muncher/media-muncher-*.log

# Filter by category using jq
jq 'select(.category == "ImportService")' ~/Library/Logs/Media\ Muncher/media-muncher-*.log

# Filter by log level
jq 'select(.level == "ERROR")' ~/Library/Logs/Media\ Muncher/media-muncher-*.log

# Search for specific content
grep -r "volume mounted" ~/Library/Logs/Media\ Muncher/

# View logs with metadata
jq 'select(.metadata) | {timestamp, category, message, metadata}' ~/Library/Logs/Media\ Muncher/media-muncher-*.log

# Count log entries by category
jq -r '.category' ~/Library/Logs/Media\ Muncher/media-muncher-*.log | sort | uniq -c
```

### Log Management
- **Session-based**: New log file created for each application session with timestamp in filename
- **No rotation**: Files persist until manually deleted (allows historical debugging)
- **Performance**: Asynchronous writing via an actor, minimal impact on UI responsiveness
- **Thread-safe**: Concurrent logging from multiple threads supported via actor serialization

---
---
## 12. Dependency Injection & Testing

Media Muncher uses a simple, manual dependency injection pattern centered around two container classes:

### Production Container
- **AppContainer.swift**: @MainActor-isolated, synchronous initialization
- Creates all services in dependency order
- Used by Media_MuncherApp.swift for production builds

### Test Container  
- **TestAppContainer.swift**: @MainActor-isolated, synchronous initialization
- Uses MockLogManager and isolated UserDefaults for testing
- Mirrors production patterns for consistency

### Key Design Principles
1. **Synchronous initialization**: All services, including @MainActor services, initialize synchronously
2. **Constructor injection**: Services receive dependencies via their initializers
3. **No async coordination**: Avoids deadlocks by keeping container creation simple
4. **Pattern consistency**: Test and production containers follow identical initialization patterns

### Recent Improvements (2025-07-23)
- **Resolved startup deadlock**: Fixed incorrect async/await usage in TestAppContainer
- **Improved consistency**: Aligned test container patterns with production
- **Enhanced reliability**: Eliminated thread coordination issues during startup

---
## 13. Build & Run (developers)
```