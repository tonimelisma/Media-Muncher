# Refactoring LogManager to use Dependency Injection

This document outlines the step-by-step plan to refactor the `LogManager` from a static singleton to a dependency-injected service. This change will improve testability, decouple our code, and make the application more maintainable.

**This plan is structured in two parts: First, we fix a critical concurrency bug in the current implementation. Second, we refactor the architecture to use Dependency Injection.**

## Phase 0: Fix the Concurrency Bug

Before we refactor the architecture, we must fix a race condition in the `LogManager`'s file-writing logic. The current implementation does not explicitly move to the end of the file before each write, which can cause log entries from different threads to get mixed up, resulting in corrupted JSON.

### Step 0.1: Fix the File-Writing Race Condition
Modify the `writeToFile` method to ensure it always seeks to the end of the file before writing new data. This operation, when performed on the serial `logQueue`, guarantees that each log entry is written atomically.

**File:** `Media Muncher/Services/LogManager.swift`
```swift
private func writeToFile(_ entry: LogEntry) {
    guard let handle = logFileHandle else { return }

    var data: Data
    do {
        data = try JSONEncoder().encode(entry)
    } catch {
        let errorMessage = "{\"error\": \"Failed to encode log entry: \(error.localizedDescription)\"}"
        data = errorMessage.data(using: .utf8)!
    }

    // This block is executed on a serial queue, ensuring atomicity.
    handle.seekToEndOfFile() // This is the crucial fix.

    // Add a newline if the file is not empty.
    if handle.offsetInFile > 0 {
        handle.write("\\n".data(using: .utf8)!)
    }

    handle.write(data)
}
```
**Verification:** The underlying bug is now fixed. However, the test suite will still fail due to the singleton state-leakage problem, which the subsequent phases will resolve.

### Step 0.2: Add a Concurrency Test to Verify the Fix
To prove the concurrency bug is squashed, we need a specific test that logs heavily from multiple threads and then verifies that every single line in the resulting log file is a valid, complete JSON object.

**File:** `Media MuncherTests/LogManagerTests.swift` (Add this new test method)
```swift
func testNoMalformedJSONAfterConcurrentWrites() {
    // Given
    let concurrentLogCount = 100
    let expectations = (0..<concurrentLogCount).map { i in
        XCTestExpectation(description: "Concurrent log \(i) completes")
    }

    // When - Log from multiple queues simultaneously
    for i in 0..<concurrentLogCount {
        DispatchQueue.global(qos: .userInitiated).async {
            let metadata = ["index": "\(i)", "thread": "\(Thread.current)"]
            LogManager.info("Concurrent message \(i)", category: "NoMalformedJSONTest", metadata: metadata) {
                expectations[i].fulfill()
            }
        }
    }

    wait(for: expectations, timeout: 15.0)

    // Then
    let logContent = LogManager.shared.getLogFileContents()
    XCTAssertNotNil(logContent)

    let lines = logContent?.components(separatedBy: "\\n").filter { !$0.isEmpty } ?? []
    XCTAssertEqual(lines.count, concurrentLogCount, "Should have the correct number of log entries")

    var decodedCount = 0
    for (i, line) in lines.enumerated() {
        guard let data = line.data(using: .utf8) else {
            XCTFail("Line \(i) is not valid UTF-8: \(line)")
            continue
        }

        do {
            _ = try JSONDecoder().decode(LogEntry.self, from: data)
            decodedCount += 1
        } catch {
            XCTFail("Failed to decode line \(i) as JSON: \(error) - Content: \(line)")
        }
    }

    XCTAssertEqual(decodedCount, concurrentLogCount, "All lines should be valid JSON LogEntry objects")
}
```
**Verification:** After the fix in Step 0.1, this specific test should pass reliably.

## Phase 1: Preparation - Introduce the Abstraction

The first phase of the DI refactor is to create a protocol for logging. This allows other parts of the app to depend on an abstraction, not a concrete implementation.

### Step 1.1: Create the `Logging` Protocol
Create a new protocol that defines the capabilities of our logger.

**File:** `Media Muncher/Protocols/Logging.swift` (Create this new file)
```swift
import Foundation

protocol Logging {
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]?, completion: (() -> Void)?)
}

extension Logging {
    func debug(_ message: String, category: String = "General", metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        write(level: .debug, category: category, message: message, metadata: metadata, completion: completion)
    }

    func info(_ message: String, category: String = "General", metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        write(level: .info, category: category, message: message, metadata: metadata, completion: completion)
    }

    func error(_ message: String, category: String = "General", metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        write(level: .error, category: category, message: message, metadata: metadata, completion: completion)
    }
}
```
**Verification:** The project should compile successfully.

### Step 1.2: Make `LogManager` Conform to `Logging`
Modify the `LogManager` class to adopt the new protocol.

**File:** `Media Muncher/Services/LogManager.swift`
```swift
// ...
class LogManager: ObservableObject, Logging {
// ...
    // The static convenience methods should be removed later, but for now, we leave them.
// ...
}
```
**Verification:** The project should compile successfully.

### Step 1.3: Create a `MockLogManager` for Testing
Create a "fake" logger that we can use in our tests. This mock will conform to the `Logging` protocol and store logs in an in-memory array instead of writing to a file.

**File:** `Media MuncherTests/Mocks/MockLogManager.swift` (Create this new file)
```swift
import Foundation
@testable import Media_Muncher

class MockLogManager: Logging {
    
    struct LogCall {
        let level: LogEntry.LogLevel
        let category: String
        let message: String
        let metadata: [String: String]?
    }
    
    var calls = [LogCall]()
    
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]?, completion: (() -> Void)?) {
        calls.append(LogCall(level: level, category: category, message: message, metadata: metadata))
        completion?()
    }
}
```
**Verification:** The project should compile successfully.

## Phase 2: The Refactoring - Injecting the Dependency

Now we will perform the core refactoring, starting from the application's entry point and passing the `LogManager` instance down.

### Step 2.1: Instantiate `LogManager` in the App Root
The `App` struct will now create and own the `LogManager` instance.

**File:** `Media Muncher/Media_MuncherApp.swift`
```swift
import SwiftUI

@main
struct Media_MuncherApp: App {
    @StateObject private var appState: AppState
    private let logManager: Logging = LogManager() // Create the instance

    init() {
        // Now, we must initialize AppState with its dependencies
        let newAppState = AppState(logManager: logManager)
        _appState = StateObject(wrappedValue: newAppState)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
```
**Verification:** The project will **not** compile. The compiler will now show errors everywhere `AppState()` was called without a `logManager`. This is expected and guides us to the next step.

### Step 2.2: Update `AppState` to Accept the Logger
Modify `AppState` to take a `Logging` instance in its initializer.

**File:** `Media Muncher/AppState.swift`
```swift
// ...
class AppState: ObservableObject {
    // ... (other properties)
    private let logManager: Logging

    // Keep the parameterless init for previews, but provide a real one
    init(logManager: Logging = MockLogManager()) { // Default to mock for previews
        self.logManager = logManager
        // ... (rest of the init)
        
        // Example of using the injected logger
        self.logManager.info("AppState initialized")
    }
    // ...
}
```
**Verification:** Go back to `Media_MuncherApp.swift`. The error there should be gone. The project should now compile again.

### Step 2.3: Identify and Refactor All Other Call-sites
We need to find every file that uses `LogManager.shared` and refactor it to use an injected instance. We will do this one service at a time. The compiler will be our guide. Let's start with `ImportService`.

**File:** `Media Muncher/Services/ImportService.swift`
1. Add a `logManager` property.
2. Update the initializer to accept a `Logging` instance.
3. Replace all calls to `LogManager.shared` with `logManager`.

```swift
class ImportService {
    private let logManager: Logging
    private let fileManager: FileManager

    init(logManager: Logging, fileManager: FileManager = .default) {
        self.logManager = logManager
        self.fileManager = fileManager
    }

    // ... inside other methods ...
    // Replace this:
    // LogManager.shared.error("Some error")
    // With this:
    // logManager.error("Some error")
}
```
**Verification:** The project will **not** compile. Find where `ImportService` is created (likely in `AppState`) and pass the `logManager` instance to it. Continue this chain until the project compiles.

## Phase 3: The Switch-Over and Cleanup

Once the dependency is plumbed through the app, we can remove the old singleton code.

### Step 3.1: Remove Static Methods and Shared Instance
The compiler is now your best friend. Delete the `shared` instance and the static convenience methods from `LogManager`.

**File:** `Media Muncher/Services/LogManager.swift`
```swift
class LogManager: ObservableObject, Logging {
    // DELETE THIS LINE
    // static var shared = LogManager()

    // ...

    // DELETE ALL OF THESE STATIC METHODS
    // static func debug(...) { ... }
    // static func info(...) { ... }
    // static func error(...) { ... }
    
    // ...
}
```
**Verification:** Try to compile. If you missed any call sites, the compiler will now fail with an error like "`LogManager` has no member `shared`." Hunt down and fix every single one until the project compiles.

### Step 3.2: Remove Test-Only Reset Helper
The `resetSharedInstanceForTesting` method is now obsolete and can be removed.

**File:** `Media Muncher/Services/LogManager.swift`
```swift
#if DEBUG
// DELETE THIS ENTIRE FUNCTION
static func resetSharedInstanceForTesting() {
    // ...
}
#endif
```
**Verification:** The project should compile.

## Phase 4: Updating Tests

Finally, update the tests to use the new DI-friendly architecture.

### Step 4.1: Update `LogManagerTests`
These tests should now create their own `LogManager` instance for each test.

**File:** `Media MuncherTests/LogManagerTests.swift`
```swift
class LogManagerTests: XCTestCase {
    
    var logManager: LogManager!
    var logFileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create a new instance for each test
        logManager = LogManager() 
        logFileURL = logManager.logFileURL
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: logFileURL)
        try super.tearDownWithError()
    }
    
    func testLogManagerWritesToFile() {
        // ...
        // Use the instance variable:
        logManager.info(message, category: "Test") { ... }
        // ...
    }
}
```
**Verification:** All tests in `LogManagerTests.swift` should pass.

### Step 4.2: Update Other Integration Tests
Any other tests that were relying on `LogManager.shared` must now be updated to inject a `MockLogManager`.

**File:** `Media MuncherTests/ImportServiceIntegrationTests.swift`
```swift
class ImportServiceIntegrationTests: XCTestCase {
    
    var importService: ImportService!
    var mockLogger: MockLogManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockLogger = MockLogManager()
        importService = ImportService(logManager: mockLogger)
    }

    func testSomething() {
        // ... do the test ...
        
        // Assert that the logger was called
        XCTAssertEqual(mockLogger.calls.count, 1)
        XCTAssertEqual(mockLogger.calls.first?.level, .info)
    }
}
```
**Verification:** All tests in the project should pass. The refactoring is complete. 

---

## 2025-07-16 – Follow-up: Actor-based Logger
The original Phase 0 fixed the race by seeking to EOF on a serial queue.  We have now **replaced that queue with a Swift `actor`**:

* Guarantees write atomicity under Swift Concurrency.
* Each process writes to `media-muncher-TIMESTAMP-PID.log`.
* `LogManager` prunes log files older than 30 days on startup.
* All services receive a `Logging` dependency via default parameter; singleton removed.

No further test failures remain; concurrency test now awaits the actor and asserts on delta line-count. 