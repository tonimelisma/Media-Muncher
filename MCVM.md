# Media Muncher – MVVM-C Refactoring Plan

> **Purpose** – This document outlines a pragmatic plan to refactor the application's UI layer using a Model-View-ViewModel-Coordinator (MVVM-C) pattern. This approach builds on the existing architecture's strengths while improving separation of concerns in the UI. It is a more targeted alternative to the original proposal in `MVVM.md`.

---

## 1. Rationale & Goals

The current architecture uses a service-oriented approach with a centralized `AppState` object acting as a Façade/Orchestrator. While effective, the `AppState` object still manages state for multiple, distinct parts of the UI (volume selection and media content).

The goal of this refactoring is to introduce a clearer separation of concerns for the UI state, making the system easier to reason about and test, without the overhead of a "pure" MVVM implementation.

**Key Goals:**
1.  Isolate the state and logic for the media content grid (files, progress, errors) from the window-level state (volume selection).
2.  Formalize the role of `AppState` as a high-level **Coordinator**.
3.  Improve the testability of the UI logic by extracting it into a dedicated ViewModel.
4.  Avoid a disruptive, wholesale rewrite of the application.

---

## 2. Proposed Architecture (MVVM-C)

We will adopt a **Model-View-ViewModel-Coordinator** pattern.

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

### Component Responsibilities:

*   **Views (`VolumeView`, `MediaFilesGridView`, `BottomBarView`):** Remain lightweight SwiftUI views responsible only for rendering data and forwarding user events.
*   **ViewModel (`MediaContentViewModel`):** A new `ObservableObject` that manages all state and logic for the main content area. This includes the list of files, scan/import progress, error messages, and the actions (`importFiles`, `cancelScan`).
*   **Coordinator (`AppCoordinator`, formerly `AppState`):** The top-level `ObservableObject` that owns the services and the `MediaContentViewModel`. It handles window-level concerns, primarily observing volume changes and telling the `MediaContentViewModel` when to start a new scan.
*   **Models/Services (`FileProcessorService`, `ImportService`, `FileStore`, etc.):** Remain unchanged. They continue to handle the core business logic and file system interactions. `FileStore` will become a private dependency of the `MediaContentViewModel`.

---

## 3. Refactoring Plan

The refactoring will be executed in the following steps:

### Step 1: Create `MediaContentViewModel.swift`

-   Create a new `final class MediaContentViewModel: ObservableObject` that is `@MainActor`-isolated.
-   Move the following `@Published` properties from `AppState` and `FileStore` into this new ViewModel:
    -   `files: [File]`
    -   `state: ProgramState`
    -   `error: AppError?`
    -   `filesScanned: Int`
    -   `importProgress: ImportProgress`
    -   `isRecalculating: Bool`
-   Move the computed properties from `FileStore` (e.g., `filesToImport`, `importedFiles`) into the ViewModel.
-   Move the user-facing action methods from `AppState` into the ViewModel:
    -   `importFiles()`
    -   `cancelScan()`
    -   `cancelImport()`
-   The ViewModel will take the required services (`FileProcessorService`, `ImportService`, `SettingsStore`, `FileStore`, `RecalculationManager`, `LogManager`) in its initializer. `FileStore` will be used internally and no longer exposed to the View layer.

### Step 2: Refactor `AppState` to `AppCoordinator`

-   Rename `AppState.swift` to `AppCoordinator.swift` and the class `AppState` to `AppCoordinator`.
-   Remove the properties and methods that were moved to `MediaContentViewModel`.
-   The `AppCoordinator` will now hold a reference to the `MediaContentViewModel`:
    ```swift
    @Published var mediaContentViewModel: MediaContentViewModel
    ```
-   The `AppCoordinator`'s primary responsibility will be to observe `selectedVolumeID` and, when it changes, call a new method on the `MediaContentViewModel`, such as `startScan(for: Volume)`.

### Step 3: Update the Dependency Injection Container

-   In `AppContainer.swift`, instantiate the new `MediaContentViewModel`.
-   Update the `AppCoordinator`'s initializer to accept the `MediaContentViewModel`.

### Step 4: Update the Views

-   Inject the `MediaContentViewModel` as an `@EnvironmentObject` into the view hierarchy.
-   `MediaView`, `MediaFilesGridView`, and `BottomBarView` will be refactored to bind to the `MediaContentViewModel` instead of `AppState` and `FileStore`.
    -   Example: `appState.state` becomes `mediaContentViewModel.state`.
    -   Example: `fileStore.files` becomes `mediaContentViewModel.files`.
-   `VolumeView` will continue to bind to the `AppCoordinator` for volume selection.

---

## 4. Benefits of this Approach

*   **Improved Separation of Concerns:** UI logic for the media grid is now fully contained within its own ViewModel, separate from the high-level application coordination.
*   **Reduced Complexity:** We avoid creating a ViewModel for every single view, which would add unnecessary boilerplate. We create one ViewModel for one logical "screen."
*   **Enhanced Testability:** The `MediaContentViewModel` can be unit-tested more easily than the monolithic `AppState`. We can test the logic of file filtering, state transitions, and error handling without needing to involve the entire application.
*   **Clearer Data Flow:** The data flow remains unidirectional and easy to follow: Coordinator -> ViewModel -> View.
*   **Low Risk:** This is an incremental refactoring, not a full rewrite. It preserves the well-functioning service layer and builds upon the existing architecture.
