# Plan: Implement Count-Based Batching for UI Updates

This document provides a comprehensive guide for an intern to implement Architecture 4 (Batching by Count). The goal is to solve UI jank during file scanning by reducing the frequency of UI updates.

## 1. Executive Summary & Goal

**Problem:** When a volume is scanned, the UI freezes because it tries to update the file grid hundreds of times per second.

**Solution:** We will collect files in a temporary "buffer" and only update the UI when the buffer reaches a certain size. This drastically reduces the number of UI re-renders, keeping the app responsive.

**Target File:** `Media Muncher/AppState.swift`
**Target Method:** `startScan(for: Volume.ID?)`

## 2. Detailed Implementation Steps for the Intern

Here is exactly what you need to do.

1.  **Navigate to the Code:**
    *   Open the project and go to `Media Muncher/AppState.swift`.
    *   Find the function `private func startScan(for volumeID: Volume.ID?)`. The changes will be inside the `Task { ... }` block within this function.

2.  **Define the Batching Strategy:**
    *   Inside the `Task`, right at the top, add these two lines to define your buffer and batch size. We're starting with 50, which is a good balance.

    ```swift
    // Add these lines
    var buffer: [File] = []
    private let fileUpdateBatchSize = 50
    ```

3.  **Implement the Core Logic:**
    *   You will replace the existing `for await...in` loop. The new loop will add files to your `buffer` and then check if the buffer is full.

    *   **Replace this:**
        ```swift
        // This is the old code you will be replacing
        var processedFiles: [File] = []
        for await fileBatch in stream {
            processedFiles.append(contentsOf: fileBatch)
        }
        self.files = processedFiles
        ```

    *   **With this new logic:**
        ```swift
        // This is the new, improved logic
        for await fileBatch in stream {
            // Add the newly found files to our temporary buffer
            buffer.append(contentsOf: fileBatch)

            // Check if the buffer is full enough to trigger a UI update
            if buffer.count >= fileUpdateBatchSize {
                // IMPORTANT: This must be on the main thread!
                await MainActor.run {
                    self.files.append(contentsOf: buffer)
                    // Also update the progress text to stay in sync
                    self.importProgress = ImportProgress(processed: self.files.count, total: fileStore.files.count)
                }
                // Clear the buffer so we can start filling it again
                buffer.removeAll()
            }
        }
        ```

4.  **Handle the Leftovers:**
    *   What if there are 49 files left? The loop above won't add them. After the `for await` loop finishes, you need to add one final check to make sure the last few files are added to the UI.

    *   **Add this code immediately after the `for await` loop:**
        ```swift
        // After the loop, handle any remaining files
        if !buffer.isEmpty {
            await MainActor.run {
                self.files.append(contentsOf: buffer)
                // Keep the progress text in sync here too
                self.importProgress = ImportProgress(processed: self.files.count, total: fileStore.files.count)
            }
        }
        ```

5.  **Final State Reset:**
    *   The existing code already handles resetting the `isScanning` and `importProgress` state at the end of the `Task`. Ensure that logic remains.

## 3. De-Risking Analysis & Key Decisions

This section explains *why* we are doing it this way.

### Risk 1: Choosing the `batchSize` (Value: 50)

*   **Analysis:** I analyzed `MediaFileCellView.swift`. The cell view is moderately complex: it contains an `Image`, several `Text` views, a `ZStack`, and a `Rectangle` overlay. Rendering this is not free. If we update too often (e.g., `batchSize = 5`), the UI will still jank. If we update too slowly (e.g., `batchSize = 200`), the app will feel unresponsive.
*   **Decision:** A `batchSize` of **50** is a well-reasoned starting point. It's large enough to prevent UI stuttering on a reasonably fast machine but small enough to provide a feeling of "live" updates. We've defined it as a constant so you can easily tune it later if needed.

### Risk 2: Inconsistent UI (Progress Text vs. File Grid)

*   **Analysis:** I confirmed that `BottomBarView.swift` displays the progress using the `appState.importProgress` object. The `MediaFilesGridView` uses `appState.files`. If these are updated at different times, the UI will be confusing (e.g., text says "500 files" but the grid only shows 450).
*   **Decision:** The implementation plan **explicitly** solves this. By updating `self.importProgress` inside the *same* `MainActor.run` block where we update `self.files`, we guarantee they are updated in the exact same transaction. The UI will always be consistent.

### Risk 3: Thread Safety (`@MainActor`)

*   **Analysis:** I confirmed that `AppState.swift` is **not** marked with `@MainActor`. This is the most critical risk. Any update to its `@Published` properties from the background `Task` will crash the app.
*   **Decision:** The plan mandates using `await MainActor.run { ... }` for *every single write* to `self.files` and `self.importProgress`. This is non-negotiable and is the key to preventing crashes.

### Risk 4: The "Small Volume" Problem

*   **Analysis:** If a user inserts a volume with only 30 files, the `if buffer.count >= 50` condition will never be met inside the loop. The user will see nothing until the scan is completely finished, at which point the "handle the leftovers" code will run.
*   **Decision:** This is an **accepted trade-off** for this architecture's simplicity. For the vast majority of cases (volumes with hundreds or thousands of files), the user experience will be vastly improved. We are prioritizing fixing the main problem (UI jank on large volumes) and accepting this minor imperfection on small ones.

Good luck with the implementation! This change will make a huge difference to the app's performance and feel.