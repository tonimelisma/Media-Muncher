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
| **VolumeView.swift** | Sidebar that lists mounted volumes. Binding to `AppState.selectedVolume` provides 2-way selection. Each row shows SD-card icon, name, and an **eject** button. | `List`, `Section`, `ForEach` |
| **MediaView.swift** | Chooses what to show in the detail pane: a placeholder when no volume, placeholder when no files, or the actual grid. | Conditional `if`/`else`, `Spacer` |
| **MediaFilesGridView.swift** | Adaptive icon grid of discovered files. Calculates column width based on window size. Each file cell now shows an asynchronously-loaded thumbnail. If a thumbnail cannot be generated, it falls back to an SF-Symbol (driven by `MediaType.sfSymbolName`). | `GeometryReader`, `ScrollView`, `LazyVGrid`, `VStack` |
| **ErrorView.swift** | Tiny inline view for error banner (currently only "destination folder not writable"). | Conditional `if`, `Image`, `Text` |
| **SettingsView.swift** | Sheet shown via **Settings** scene. Contains two toggles and a folder picker. | `Form`, custom `FolderPickerView` |
| **FolderPickerView** | Provides preset folder list + "Other…" path picker. | `Picker`, `HStack`, uses `NSOpenPanel` |
| **MediaFileCellView** | A small view that represents a single cell in the `MediaFilesGridView`, displaying the thumbnail and status overlays. | `Image`, `Text`, `Spacer` |
| **BottomBarView** | The view at the bottom of the window that shows scan progress, import progress, and action buttons. | `HStack`, `ProgressView`, `Button` |

### 2.1 ContentView Layout Details
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
The bottom bar's background uses `.quinaryLabel` to visually separate controls.

### 2.2 VolumeView
* **List** with single `Section(header: DEVICES)`.
* `Image(systemName: "0.square")` placeholder when no devices.
* Each row has SD-card icon (blue), *name*, and right-aligned eject button.

### 2.3 MediaFilesGridView
* Calculates `columnWidth` 120 pt, spacing 10 pt.
* Column count adapts ⇒ (#windowWidth − 20)/(columnWidth + 10).
* Each cell  = symbol (resizable fit) + filename (`font(.caption)`, centered).

### 2.4 SettingsView
* `Form` with two toggles (`Delete originals after import` / `Delete previously imported originals`).
* `FolderPickerView` shows presets with folder icon & checkmark for selected.
* "Other…" launches `NSOpenPanel` and stores bookmark path via `UserDefaults`.

---
## 3. Runtime Relationships
* **AppState** is injected as `@EnvironmentObject` **everywhere**. Views observe `@Published` properties for reactive updates.
* `VolumeView` triggers `selectVolume()` which empties file array and starts async scan. The scan publishes to `files`, `filesScanned`, `state`.
* `MediaFilesGridView` instantly reflects new `files` as they append in batches.
* **Bottom bar** shows live scan statistics and cancellation control (implemented in `AppState.cancelEnumeration()`).

---
## 4. Future UI Vision (Strictly per PRD)

This section details how the UI will evolve to meet all remaining requirements in `PRD.md`. It replaces all previous "Gap Analysis", "End Vision", and "Blueprint" sections.

### 4.1 Main Window & Bottom Bar

The main window remains a `NavigationSplitView`. The key evolution is in the bottom bar:

*   **Button Lifecycle**: The main action button is context-aware:
    *   **Import**: The default state when files are enumerated and ready.
    *   **Cancel**: Replaces "Import" when an import is running.
    *   **Eject**: Replaces "Cancel" after a successful import if auto-eject is off. It is disabled during the import process.
*   **Determinate Progress Bar**: An import progress bar is now shown in the bottom bar during an active import (**UI-3, Finished**). It displays:
    *   A visual `ProgressView` showing overall progress based on byte count.
    *   Text labels showing the number of files copied versus the total (`X of Y files`) and the data size copied versus the total (`A of B GB`).
*   The "Import" button becomes a "Cancel" button during the operation. Time estimation is not yet implemented.
*   **Error View**: The existing `ErrorView` will be enhanced to show other critical errors inline, such as "insufficient disk space," as defined in **UI-4**.

### 4.2 Media Grid (`MediaFilesGridView`)

The grid of files will become richer to provide more immediate feedback:

*   **Status Indicators**: Each grid cell will get a visual marker to indicate its status:
    *   A semi-transparent black overlay to darken the thumbnail.
    *   An SF Symbol in white to indicate the status:
        *   `checkmark.circle.fill`: The file already exists at the destination.
        *   `doc.on.doc.fill`: The file is a duplicate of another file in the source media.
        *   `xmark.circle.fill`: An error occurred during the import of this specific file.
*   **Smooth Updates**: Thumbnail loading and status changes will use `withAnimation` to prevent jarring UI updates (**MD-5**).

### 4.3 Settings Window (`SettingsView`)

The `SettingsView` will remain a **single-pane** sheet containing one `