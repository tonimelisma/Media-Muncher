# Media Muncher – UI Architecture & Screen Designs

> **Document scope** – This file captures every SwiftUI view that exists in the code-base today, how they compose into screens, and what the long-term product vision implies for the UI. Keep this section up to date any time views change.

---
## 1. High-Level Navigation Flow

```mermaid
flowchart LR
    A[WindowGroup] -->|NavigationSplitView| B[Sidebar – VolumeView]
    A --> C[Detail Pane]
    C -->|idle| D1[Placeholder Text]
    C -->|enumerating| D2[Progress + Grid]
    C -->|files loaded| D3[MediaFilesGridView]
    C --> E[Bottom Bar (Progress · Error · Import)]
    Settings[Settings Scene] --> F[SettingsView]
```

**Entry point** – `Media_MuncherApp` creates a single `WindowGroup` with `ContentView` and a separate **Settings** scene.

---
## 2. View Catalogue (current state)

| File | Responsibility | Key SwiftUI Containers |
|------|----------------|------------------------|
| **ContentView.swift** | Defines the main window as a `NavigationSplitView` (sidebar & detail) and bottom toolbar. Injects **Settings** button in the standard toolbar. | `NavigationSplitView`, `VStack`, `HStack`, `ToolbarItem` |
| **VolumeView.swift** | Sidebar that lists mounted volumes. Binding to `AppState.selectedVolumeID` provides 2-way selection. Each row shows SD-card icon, name, and an **eject** button. | `List`, `Section`, `ForEach` |
| **MediaView.swift** | Chooses what to show in the detail pane: a placeholder when no volume, a placeholder when no files are found, or the actual grid. | Conditional `if`/`else`, `Spacer` |
| **MediaFilesGridView.swift** | Adaptive icon grid of discovered files. Calculates column width based on window size. | `GeometryReader`, `ScrollView`, `LazyVGrid`, `VStack` |
| **MediaFileCellView.swift** | A small view that represents a single cell in the `MediaFilesGridView`, displaying the thumbnail and status overlays. | `Image`, `Text`, `Spacer` |
| **BottomBarView.swift** | The view at the bottom of the window that shows scan progress, import progress, and action buttons. | `HStack`, `ProgressView`, `Button` |
| **ErrorView.swift** | Tiny inline view for error banner (currently only "destination folder not writable"). | Conditional `if`, `Image`, `Text` |
| **SettingsView.swift** | Sheet shown via **Settings** scene. Contains toggles, media type filters, and a folder picker. | `Form`, custom `FolderPickerView` |
| **FolderPickerView** | Provides preset folder list + "Other…" path picker. | `Picker`, `HStack`, uses `NSOpenPanel` |

---
## 3. UI Component Details

### 3.1 ContentView Layout
```
NavigationSplitView
 ├─ Sidebar: VolumeView (fixed 150–250 pt)
 └─ Detail (VStack)
     │  MediaView               – dynamic content
     ├─ Spacer()
     └─ Bottom Bar (HStack, maxWidth = ∞)
          ├─ ProgressView + "N files" + Stop (when scanning)
          ├─ OR ProgressView + "X of Y files (Z MB of N GB)" + Cancel (when importing)
          ├─ ErrorView
          ├─ Spacer()
          └─ Import Button
```

### 3.2 Bottom Bar
*   **Button Lifecycle**: The main action button is context-aware:
    *   **Import**: The default state when files are enumerated and ready.
    *   **Cancel**: Replaces "Import" when an import is running.
    *   **Eject**: The eject button in the `VolumeView` is disabled during scanning and import operations.
*   **Determinate Progress Bar**: During an active import, a progress bar displays:
    *   A visual `ProgressView` showing overall progress based on byte count.
    *   Text labels showing files copied vs. total (`X of Y files`) and data size copied vs. total (`A of B GB`).
*   **Elapsed / Remaining Time**: The bar shows a concise elapsed timer and an ETA that auto-updates every second.
*   **Cancellability**: When the user clicks "Cancel", the system sets a flag that the background task checks. There may be a brief delay (typically <1s) before the operation fully stops. During this time, the UI should ideally show a "Cancelling..." state.

### 3.3 Media Grid (`MediaFilesGridView`)
*   **Status Indicators**: Each grid cell has a visual marker to indicate its status:
    *   A semi-transparent black overlay to darken the thumbnail.
    *   An SF Symbol in white to indicate the status:
        *   `checkmark.circle.fill`: The file already exists at the destination.
        *   `doc.on.doc.fill`: The file is a duplicate of another file in the source media.
        *   `xmark.circle.fill`: An error occurred during the import of this specific file.
*   **Smooth Updates**: Thumbnail loading and status changes use `withAnimation` to prevent jarring UI updates.

### 3.4 Empty States
*   The `MediaView` shows a helpful placeholder when no media files are found on a volume, specifying the types of files the app is looking for.

---
## 4. Future UI Vision (To-Do)

This section details planned UI work required to meet all remaining requirements in `PRD.md`.

*   **[To-Do] Design Automation Settings:** Create mockups and implementation plan for the "Automation" tab in the Settings window, covering how users will manage per-volume import behaviors.
*   **[To-Do] Design Richer Error States:** Design a more robust error reporting system. For example, an "Import Summary" sheet that appears after an import with partial failures, clearly listing which files succeeded and which failed, and why.

## 5. Notes on 2025-06-27
* No user-visible UI changes were made in this development cycle. All efforts focused on backend bug-fixing (EXIF time-zone) and expanding the automated test suite.
* A developer-mode toggle now surfaces additional `print` statements to aid debugging. These remain behind `#if DEBUG` and do **not** affect production builds.

### 2025-06-28
* **Bottom Bar** now reflects read-only import results: after an import that succeeded but could not delete originals, an inline red banner shows "Import successful, but failed to delete some original files…". This is surfaced by a new `AppError.importSucceededWithDeletionErrors` case.
* No visual changes – logic-only test coverage increase. Collision handling behaviour remains unchanged in UI.

### 2025-06-29
* No visual changes. Backend improvements (duplicate detection, mtime preservation, side-car handling) are invisible to the UI but ensure more accurate status icons in the grid.

### 2025-01-15
* No user-visible UI changes were made in this development cycle. All efforts focused on backend logging improvements. The `LogManager` system is designed for developer debugging and does not have a user-facing UI component. The `LogManager` was refactored to create a new log file for each application session, removing the in-memory cache and log clearing functionality for a simpler, more robust design.

### 2025-07-21
* No user-visible UI changes were made in this development cycle. Grid layout performance was improved through constants consolidation - MediaFilesGridView now uses centralized Constants.swift values instead of hard-coded numbers. The grid calculation logic was enhanced with helper functions for better maintainability, but the visual appearance and behavior remain unchanged.

### 2025-07-22
* Internal performance update: thumbnail generation now handled by new actor `ThumbnailCache`, reducing MainActor load and improving grid scrolling smoothness. No visual changes.

### 2025-07-23
* **Performance optimization**: Eliminated all Data→Image conversions from UI layer through direct ThumbnailCache integration
* **Architecture improvement**: MediaFileCellView now uses ThumbnailCache directly via SwiftUI environment injection
* **Memory efficiency**: Enhanced ThumbnailCache with dual storage (JPEG data + SwiftUI Images) and unified LRU eviction
* **Responsiveness**: Thumbnail Image generation moved completely off MainActor, improving grid scrolling performance
* No visual changes to user interface - all improvements are internal performance optimizations
