# Startup Deadlock Analysis

## 1. High-Level Summary

The application and its test suites are experiencing a deadlock on startup, causing them to hang indefinitely. The root cause is a circular wait condition between the main thread and a background task during the initialization of the `AppContainer` dependency injection container.

## 2. Symptoms

-   When launching the application, the UI never appears, and the process hangs.
-   When running `xcodebuild test`, the test runner hangs and eventually times out without executing any tests.
-   Debug logs show that the `AppContainer` initialization starts but never completes.

## 3. Root Cause Analysis

The deadlock occurs due to an unsafe pattern used to bridge synchronous and asynchronous code during the app's startup sequence.

Here is the step-by-step breakdown of the failure:

**File: `Media Muncher/Media_MuncherApp.swift`**

The application's `init()` method, which runs on the **main thread**, immediately calls a blocking function to create the service container.

```swift
// Runs on the MAIN THREAD
init() {
    // 1. The main thread calls blocking() and waits for it to return.
    let container = AppContainer.blocking()
    
    // ... subsequent initialization ...
}
```

**File: `Media Muncher/AppContainer.swift`**

The `blocking()` function is designed to run the `async` initializer of `AppContainer` from a synchronous context.

```swift
// Runs on the MAIN THREAD
static func blocking() -> AppContainer {
    // 2. A semaphore is created to block the main thread.
    let semaphore = DispatchSemaphore(value: 0)
    var container: AppContainer!
    
    // 3. A new background task is created to initialize the container.
    Task {
        container = await AppContainer()
        // 6. This signal will never be reached.
        semaphore.signal()
    }
    
    // 4. The main thread is parked here, waiting for the signal.
    semaphore.wait()
    return container
}
```

The `async init()` of `AppContainer` begins executing on a **background thread**. It successfully initializes several services until it reaches a service that is isolated to the Main Actor.

```swift
// Runs on a BACKGROUND THREAD
init() async {
    // ... other services are created ...

    // 5. The background task tries to initialize FileStore.
    // Because FileStore is a @MainActor, its initializer MUST run on the main thread.
    // The Swift Concurrency runtime queues this work for the main thread
    // and PAUSES the background task until it's complete.
    self.fileStore = await FileStore(logManager: logManager)
    
    // ...
}
```

**File: `Media Muncher/FileStore.swift`**

The `FileStore` class is explicitly marked as being isolated to the main actor.

```swift
@MainActor
final class FileStore: ObservableObject {
    // ...
}
```

### The Circular Wait

This creates a classic deadlock:

1.  The **Main Thread** is blocked by `semaphore.wait()`, waiting for the background `Task` to finish.
2.  The **Background Task** is blocked by `await FileStore(...)`, waiting for the **Main Thread** to become available to run the `FileStore` initializer.

Neither thread can proceed, and the application hangs.

## 4. Log-File Evidence

Analysis of the application logs confirms this sequence of events. The last message logged during a failed startup is from `AppContainer` right before it attempts to initialize the first `@MainActor`-isolated service.

**Log File: `media-muncher-2025-07-23_20-52-41-2642.log`**

```json
// ... previous services initialize successfully ...
{
  "message": "Creating ImportService...",
  "level": "DEBUG",
  "category": "AppContainer",
  "id": "79240C96-F5CC-4CDD-ADE1-4F7B93ABC910",
  "timestamp": 775021961.087722
}
{
  "message": "ImportService created",
  "level": "DEBUG",
  "category": "AppContainer",
  "id": "E383DE88-7CB3-4C29-BC39-41BBF5CA3D65",
  "timestamp": 775021961.087819
}
{
  "message": "Creating FileStore (MainActor)... About to await.",
  "level": "DEBUG",
  "category": "AppContainer",
  "id": "3DFB25C9-6194-4883-8B78-19E4427E6BB8",
  "timestamp": 775021961.087876
}
// --- THE LOG ENDS HERE ---
```

The log proves that the background task reaches the `await FileStore(...)` call and then stops. The corresponding "FileStore... created successfully" log message is never written, nor are any subsequent messages. This is the definitive signature of the deadlock.

## 5. Architectural Context

The application uses a standard Dependency Injection (DI) pattern with an `AppContainer` to manage service lifecycles. To embrace Swift Concurrency, services that interact with the UI (like `FileStore` and `RecalculationManager`) are isolated to the `@MainActor`.

The deadlock is not a flaw in the DI pattern itself, but in the unsafe "blocking bridge" created to initialize the container from the synchronous `App.init()` entry point.

## 6. Detailed Implementation Plan

The following step-by-step plan will be executed to resolve the deadlock.

### Part 1: Refactor `AppContainer.swift`

1.  **Isolate to Main Actor**: The `AppContainer` class will be marked with `@MainActor` to ensure its initializer and properties are accessed on the main thread. This allows it to safely create other `@MainActor`-isolated services like `FileStore`.

    ```swift
    // Before
    final class AppContainer { ... }

    // After
    @MainActor
    final class AppContainer { ... }
    ```

2.  **Make Initializer Synchronous**: Since the class is now on the main actor, its `init()` no longer needs to be `async`. The `await` keywords for creating `FileStore` and `RecalculationManager` can be removed.

    ```swift
    // Before
    init() async { ... }

    // After
    init() { ... }
    ```

3.  **Remove Unsafe `blocking()` Function**: The `static func blocking()` method, which is the root cause of the deadlock, will be deleted entirely.

### Part 2: Refactor `Media_MuncherApp.swift` for Asynchronous Startup

1.  **Introduce Loading State**: A new state variable, `@State private var appContainer: AppContainer?`, will be added to `Media_MuncherApp` to hold the fully initialized service container. It will be `nil` while services are being created.

2.  **Remove Old State Management**: The now-redundant `@StateObject` properties for `appState`, `fileStore`, etc., will be removed, as will the old synchronous `init()` method.

3.  **Implement Loading View**: The app's `body` will be updated to show a `ProgressView` while `appContainer` is `nil`. Once initialization is complete, it will switch to displaying the main `ContentView`.

    ```swift
    var body: some Scene {
        WindowGroup {
            if let container = appContainer {
                ContentView()
                    .environmentObject(container.appState) // Example
                    // ... inject other services
            } else {
                ProgressView()
                    .task {
                        // See next step
                    }
            }
        }
    }
    ```

4.  **Use `.task` for Initialization**: A `.task` modifier will be attached to the `ProgressView`. This task will run when the view first appears, create a new instance of `AppContainer` on the main thread, and assign it to the `appContainer` state variable, triggering the UI to update.

    ```swift
    ProgressView()
        .task {
            self.appContainer = AppContainer()
        }
    ```

### Part 3: Aligning with Test Setup

Analysis of `Media MuncherTests/TestSupport/TestAppContainer.swift` shows it is already a `@MainActor` class with an `async init`. The proposed changes will bring the production `AppContainer` in line with the established testing pattern, significantly reducing the risk of breaking the test suite. The test helpers will not need significant changes.
