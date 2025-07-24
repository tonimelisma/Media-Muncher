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

## 4. Architectural Context

The application uses a standard Dependency Injection (DI) pattern with an `AppContainer` to manage service lifecycles. To embrace Swift Concurrency, services that interact with the UI (like `FileStore` and `RecalculationManager`) are isolated to the `@MainActor`.

The deadlock is not a flaw in the DI pattern itself, but in the unsafe "blocking bridge" created to initialize the container from the synchronous `App.init()` entry point.

## 5. Proposed Solution

The `AppContainer.blocking()` function must be removed. The initialization of the container needs to be refactored to respect the asynchronous nature of its services without blocking the main thread.

A potential approach is to make the `AppContainer` a `@MainActor` itself. This would ensure its `init()` runs on the main thread, allowing it to safely create other `@MainActor`-isolated services. The services that perform heavy I/O (like `FileProcessorService`) are already actors and will correctly run on background threads, so this change should not introduce new performance problems.
