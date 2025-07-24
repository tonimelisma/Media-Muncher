# Media Muncher Async Test Infrastructure Fix

**Status**: Analysis Complete, Implementation Pending  
**Priority**: High - Blocking reliable CI/CD  
**Estimated Effort**: 2-3 days  

## Executive Summary

The Media Muncher test suite has systematic failures in async coordination, with 17 failing tests primarily in `AppStateRecalculationTests`, `LogManagerTests`, and `AppStateIntegrationTests`. The root cause is a mismatch between the production architecture's "Hybrid with Clear Boundaries" async model and the test infrastructure's polling-based coordination mechanism.

**Key Issues:**
- Tests timeout waiting for completion signals that never arrive
- `waitForCondition` polling violates architectural async patterns
- Missing proper coordination between MainActor UI services and background actors
- Test infrastructure doesn't leverage the existing Combine publisher system

## Failing Test Analysis

### 1. AppStateRecalculationTests - Primary Failure Category

**Tests Affected:**
- `testDestinationChangeTriggersRecalculation()` - Multiple failures, 10+ second timeouts
- `testRecalculationHandlesRapidDestinationChanges()` - Timeout failures  
- `testRecalculationWithComplexFileStatuses()` - Multiple failures

**Code Context:**
```swift
// Current problematic pattern from AppStateRecalculationTests.swift:232-238
settingsStore.setDestination(destB_URL)

// Wait for recalculation to complete
try await waitForCondition(timeout: 5.0, description: "Recalculation") {
    !self.appState.isRecalculating && 
    (self.fileStore.files.first?.destPath?.contains(self.destB_URL.lastPathComponent) ?? false)
}
```

**Log Evidence:**
From `media-muncher-2025-07-23_21-48-56-8511.log`:
```json
{"category":"RecalculationManager","level":"DEBUG","message":"startRecalculation called","metadata":{"newDestination":"\/var\/folders\/l2\/wj7kybc14wxbb7bv5l86glkh0000gn\/T\/test_destB_6D7BD712-B30E-47B3-8500-BB473AE2464A"},"timestamp":775025341.37661,"id":"3898DD2C-A5C8-49E9-AB83-F89A4325BE3F"}
{"id":"48E12DF0-3AED-429E-9FC2-71BCA9DA364A","level":"DEBUG","message":"No files to recalculate, resetting state","timestamp":775025341.376961,"category":"RecalculationManager"}
{"timestamp":775025341.377016,"id":"B1AB465D-21B6-4970-9963-2140A51BEBF7","level":"DEBUG","category":"FileStore","metadata":{"count":"0"},"message":"Setting files"}
```

**Problem Analysis:**
1. `RecalculationManager.startRecalculation()` is called correctly
2. Operation completes immediately with "No files to recalculate"  
3. `FileStore` is updated with count 0
4. Test's `waitForCondition` never detects completion because it's polling the wrong state

### 2. LogManagerTests - Simple Test Failure

**Test Affected:**
- `testLogWithNilMetadata()` - Single failure

**Code Context:**
```swift
// From LogManagerTests.swift:80-87
func testLogWithNilMetadata() async throws {
    let message = "Log with nil metadata"
    await logManager.info(message, category: "NilMetadataTest", metadata: nil)
    
    let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
    XCTAssertTrue(logContent.contains(message))
    XCTAssertFalse(logContent.contains("metadata"))  // This assertion likely fails
}
```

**Problem Analysis:**
This test expects that when `metadata: nil` is passed, the JSON output contains no "metadata" key. However, the JSON encoder might be including `"metadata":null` or similar, causing the string-based assertion to fail.

### 3. AppStateRecalculationUnitTests - Memory Management

**Test Affected:**
- `testFileStoreDeallocation()` - Memory leak detection

**Code Context:**
```swift
// From AppStateRecalculationUnitTests.swift:128-138
func testFileStoreDeallocation() async {
    weak var weakStore: FileStore?
    
    let container = TestAppContainer()
    
    autoreleasepool {
        weakStore = container.fileStore
    }
    
    XCTAssertNil(weakStore, "FileStore should deallocate when container goes out of scope")
}
```

**Problem Analysis:**
The `TestAppContainer` likely maintains strong references to services, preventing deallocation. This suggests the dependency injection pattern may have retain cycles.

### 4. AppStateIntegrationTests - Cross-Service Coordination

**Test Affected:**
- `testRecalculationAfterStatusChange()` - Integration test failure

**Code Context:**
```swift
// From AppStateIntegrationTests.swift:88-96
recalculationManager.didFinishPublisher
    .sink { _ in recalcFinished.fulfill() }
    .store(in: &cancellables)

let newDest = tempDirectory.appendingPathComponent("NewDest")
try FileManager.default.createDirectory(at: newDest, withIntermediateDirectories: true)
settingsStore.setDestination(newDest)

await fulfillment(of: [recalcFinished], timeout: 5)
```

**Problem Analysis:**
This test uses the correct publisher-based approach but still fails, suggesting the `didFinishPublisher` may not be firing correctly or the test setup has timing issues.

## Production Code Flow Analysis

### Current Architecture's Async Coordination

**From ARCHITECTURE.md Section 5:**
```
| Layer | Pattern | Purpose | Usage |
|-------|---------|---------|-------|
| UI Layer | MainActor + Combine | SwiftUI reactive binding | @MainActor classes with @Published properties |
| Service Layer | Actors + Async/Await | Thread-safe file operations | actor for I/O, pure async func interfaces |
| Cross-Layer | Async/Await + Task | Background coordination | Service calls via await, Task for lifecycle |
| State Management | Combine Publishers | Reactive UI updates | Settings and configuration changes |
```

### Recalculation Flow Breakdown

**Step-by-Step Analysis:**

1. **User Changes Destination** (UI Thread/MainActor)
   ```swift
   settingsStore.setDestination(newURL)  // Triggers @Published destinationURL
   ```

2. **AppState Observes Change** (MainActor)
   ```swift
   // From AppState setup - subscribes to settings changes
   settingsStore.$destinationURL
       .sink { [weak self] _ in
           self?.triggerRecalculation()  // Calls RecalculationManager
       }
   ```

3. **RecalculationManager Coordination** (MainActor)
   ```swift
   @MainActor func startRecalculation(newDestination: URL) async {
       // Updates UI state
       isRecalculating = true
       
       // Delegates to FileProcessorService (Actor)
       let recalculatedFiles = await fileProcessorService.recalculateDestinations(...)
       
       // Updates FileStore (MainActor)
       fileStore.setFiles(recalculatedFiles)
       
       // Publishes completion
       didFinishSubject.send(())
       isRecalculating = false
   }
   ```

4. **Cross-Actor Coordination Issues**
   - FileProcessorService runs on background actor
   - FileStore runs on MainActor  
   - Publisher events must coordinate between these contexts
   - Tests may miss timing-sensitive state transitions

## Solution Criteria

### Functional Requirements
1. **Deterministic Completion Detection**: Tests must reliably detect when async operations complete
2. **Architectural Alignment**: Test coordination must match production's async patterns
3. **No Polling**: Eliminate `waitForCondition` polling mechanism
4. **Publisher Integration**: Leverage existing Combine publisher infrastructure
5. **Actor Safety**: Proper coordination across MainActor and background actor boundaries

### Non-Functional Requirements  
1. **Performance**: Tests should complete quickly (<1 second for simple operations)
2. **Reliability**: >99% test pass rate, no flaky behavior
3. **Maintainability**: Test patterns should be easy to understand and extend
4. **Debugging**: Clear failure modes when async coordination breaks

### Compatibility Requirements
1. **Existing Test Structure**: Minimize changes to test logic and assertions
2. **CI/CD Integration**: Tests must be reliable in headless build environments
3. **Development Workflow**: Support fast local test iteration

## Alternative Solutions Evaluation

### 1. Publisher-Based Expectation System ⭐⭐⭐⭐⭐

**Approach:**
```swift
func testRecalculationWithPublishers() async throws {
    // Setup completion detection BEFORE triggering operation
    let recalculationComplete = expectation(description: "Recalculation complete")
    let filesUpdated = expectation(description: "Files updated")
    
    // Use existing publishers for coordination
    recalculationManager.didFinishPublisher
        .first()
        .sink { _ in recalculationComplete.fulfill() }
        .store(in: &cancellables)
    
    fileStore.$files
        .dropFirst()  // Skip initial empty state
        .first { files in 
            files.allSatisfy { $0.destPath?.contains(destB_URL.path) ?? false }
        }
        .sink { _ in filesUpdated.fulfill() }
        .store(in: &cancellables)
    
    // Trigger operation
    settingsStore.setDestination(destB_URL)
    
    // Wait for both completion signals
    await fulfillment(of: [recalculationComplete, filesUpdated], timeout: 2.0)
}
```

**Pros:**
- ✅ Aligns perfectly with architecture's Combine usage
- ✅ Deterministic - no polling, waits for actual completion signals
- ✅ Uses production publisher infrastructure  
- ✅ Fast execution - completes immediately when operation finishes
- ✅ Easy to debug - clear expectation failures

**Cons:**
- ⚠️ Requires ensuring all services expose necessary publishers
- ⚠️ Slightly more verbose than current approach

**Architecture Alignment Score: 10/10**

### 2. Async/Await with Continuation-Based Coordination ⭐⭐⭐⭐

**Approach:**
```swift
func testRecalculationWithContinuations() async throws {
    let recalculationTask = Task {
        await withCheckedContinuation { continuation in
            recalculationManager.didFinishPublisher
                .first()
                .sink { _ in continuation.resume() }
                .store(in: &cancellables)
        }
    }
    
    let filesTask = Task {
        await withCheckedContinuation { continuation in
            fileStore.$files
                .dropFirst()
                .first { files in 
                    files.allSatisfy { $0.destPath?.contains(destB_URL.path) ?? false }
                }
                .sink { _ in continuation.resume() }
                .store(in: &cancellables)
        }
    }
    
    settingsStore.setDestination(destB_URL)
    
    await recalculationTask.value
    await filesTask.value
}
```

**Pros:**
- ✅ Clean async/await interface
- ✅ Good performance
- ✅ Leverages existing publishers

**Cons:**
- ⚠️ More complex continuation safety concerns
- ⚠️ Harder to debug failed expectations
- ⚠️ Task cancellation complexity

**Architecture Alignment Score: 8/10**

### 3. AsyncStream-Based Test Coordination ⭐⭐⭐

**Approach:**
```swift
func testRecalculationWithStreams() async throws {
    let recalculationStream = recalculationManager.didFinishPublisher.values
    let filesStream = fileStore.$files.dropFirst().values
    
    settingsStore.setDestination(destB_URL)
    
    // Wait for recalculation completion
    for await _ in recalculationStream {
        break
    }
    
    // Wait for files to be updated with new destination
    for await files in filesStream {
        if files.allSatisfy({ $0.destPath?.contains(destB_URL.path) ?? false }) {
            break
        }
    }
}
```

**Pros:**
- ✅ Natural async iteration
- ✅ Good for complex state transitions

**Cons:**
- ⚠️ More verbose
- ⚠️ Stream lifecycle management complexity
- ⚠️ Harder to set timeouts

**Architecture Alignment Score: 7/10**

### 4. Enhanced Test Infrastructure with Service Hooks ⭐⭐

**Approach:**
```swift
// Add test-specific completion hooks to services
class TestableRecalculationManager: RecalculationManager {
    var testCompletionHandler: (() -> Void)?
    
    override func startRecalculation(newDestination: URL) async {
        await super.startRecalculation(newDestination: newDestination)
        testCompletionHandler?()
    }
}

func testRecalculationWithHooks() async throws {
    let completionExpectation = expectation(description: "Recalculation complete")
    testableRecalculationManager.testCompletionHandler = {
        completionExpectation.fulfill()
    }
    
    settingsStore.setDestination(destB_URL)
    await fulfillment(of: [completionExpectation], timeout: 2.0)
}
```

**Pros:**
- ✅ Simple and reliable
- ✅ Easy to debug

**Cons:**
- ❌ Requires test-specific service modifications
- ❌ Doesn't test real publisher coordination
- ❌ Maintenance overhead

**Architecture Alignment Score: 4/10**

### 5. Mock Service Injection with Synchronous Completion ⭐

**Approach:**
```swift
class MockRecalculationManager: RecalculationManager {
    override func startRecalculation(newDestination: URL) async {
        // Synchronous recalculation for testing
        recalculatePathsOnly(newDestination: newDestination)
        didFinishSubject.send(())
    }
}
```

**Pros:**
- ✅ Fast and deterministic
- ✅ Simple debugging

**Cons:**
- ❌ Doesn't test real async coordination
- ❌ Extensive mocking required
- ❌ Poor production fidelity

**Architecture Alignment Score: 2/10**

## Recommended Solution: Publisher-Based Expectation System

**Choice Rationale:**
1. **Perfect Architectural Alignment**: Uses the same Combine publishers that drive the production UI
2. **Deterministic**: No polling or arbitrary timeouts
3. **High Fidelity**: Tests the actual async coordination mechanisms
4. **Maintainable**: Builds on existing infrastructure
5. **Performance**: Fast test execution

## Detailed Implementation Plan

### Phase 1: Infrastructure Updates (Day 1)

#### 1.1 Audit and Enhance Service Publishers

**Task**: Ensure all services expose necessary completion publishers

**Files to Modify:**
- `Services/RecalculationManager.swift`
- `Services/FileProcessorService.swift`  
- `Services/ImportService.swift`

**Example Enhancement:**
```swift
// In RecalculationManager.swift
@MainActor
class RecalculationManager: ObservableObject {
    // Existing code...
    
    // Enhanced publisher for test coordination
    private let didFinishSubject = PassthroughSubject<Void, Never>()
    var didFinishPublisher: AnyPublisher<Void, Never> {
        didFinishSubject.eraseToAnyPublisher()
    }
    
    // Enhanced publisher for error coordination  
    private let didErrorSubject = PassthroughSubject<AppError, Never>()
    var didErrorPublisher: AnyPublisher<AppError, Never> {
        didErrorSubject.eraseToAnyPublisher()
    }
    
    func startRecalculation(newDestination: URL) async {
        // Existing implementation...
        
        // Ensure completion signal is sent
        didFinishSubject.send(())
    }
}
```

#### 1.2 Create Publisher-Based Test Utilities

**New File**: `Media MuncherTests/TestSupport/AsyncTestUtilities.swift`

```swift
import XCTest
import Combine
@testable import Media_Muncher

extension XCTestCase {
    
    /// Wait for a publisher to emit its first value
    func waitForPublisher<T, E: Error>(
        _ publisher: AnyPublisher<T, E>,
        timeout: TimeInterval = 2.0,
        description: String
    ) async throws -> T {
        let expectation = XCTestExpectation(description: description)
        var result: T?
        var error: E?
        
        let subscription = publisher
            .first()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let publisherError) = completion {
                        error = publisherError
                    }
                    expectation.fulfill()
                },
                receiveValue: { value in
                    result = value
                }
            )
        
        await fulfillment(of: [expectation], timeout: timeout)
        subscription.cancel()
        
        if let error = error {
            throw error
        }
        
        guard let result = result else {
            throw XCTestError(.failureWhileWaiting)
        }
        
        return result
    }
    
    /// Wait for multiple publishers to complete
    func waitForPublishers(
        timeout: TimeInterval = 2.0,
        description: String,
        @PublisherExpectationBuilder _ expectations: () -> [PublisherExpectation]
    ) async throws {
        let publisherExpectations = expectations()
        let xctExpectations = publisherExpectations.map { $0.expectation }
        
        // Start all subscriptions
        publisherExpectations.forEach { $0.startSubscription() }
        
        await fulfillment(of: xctExpectations, timeout: timeout)
        
        // Clean up subscriptions
        publisherExpectations.forEach { $0.cleanup() }
    }
}

// Builder pattern for multiple publisher expectations
@resultBuilder
struct PublisherExpectationBuilder {
    static func buildBlock(_ expectations: PublisherExpectation...) -> [PublisherExpectation] {
        return expectations
    }
}

// Wrapper for publisher expectations
class PublisherExpectation {
    let expectation: XCTestExpectation
    private var subscription: AnyCancellable?
    private let startSubscriptionBlock: () -> AnyCancellable
    
    init<T, E: Error>(description: String, publisher: AnyPublisher<T, E>) {
        self.expectation = XCTestExpectation(description: description)
        self.startSubscriptionBlock = {
            publisher
                .first()
                .sink(
                    receiveCompletion: { _ in self.expectation.fulfill() },
                    receiveValue: { _ in }
                )
        }
    }
    
    func startSubscription() {
        subscription = startSubscriptionBlock()
    }
    
    func cleanup() {
        subscription?.cancel()
    }
}
```

### Phase 2: Fix AppStateRecalculationTests (Day 1-2)

#### 2.1 Replace Polling with Publisher Coordination

**File**: `Media MuncherTests/AppStateRecalculationTests.swift`

**Before (Lines 231-238):**
```swift
// Act: Change destination (should trigger recalculation)
settingsStore.setDestination(destB_URL)

// Wait for recalculation to complete
try await waitForCondition(timeout: 5.0, description: "Recalculation") {
    !self.appState.isRecalculating && 
    (self.fileStore.files.first?.destPath?.contains(self.destB_URL.lastPathComponent) ?? false)
}
```

**After:**
```swift
// Setup completion detection BEFORE triggering operation
try await waitForPublishers(timeout: 2.0, description: "Recalculation and file update") {
    PublisherExpectation(
        description: "Recalculation completed", 
        publisher: recalculationManager.didFinishPublisher
    )
    PublisherExpectation(
        description: "Files updated with new destination",
        publisher: fileStore.$files
            .dropFirst()
            .first { files in
                files.allSatisfy { $0.destPath?.contains(self.destB_URL.lastPathComponent) ?? false }
            }
            .eraseToAnyPublisher()
    )
}

// Trigger operation AFTER setting up expectations
settingsStore.setDestination(destB_URL)
```

#### 2.2 Fix Complex File Status Test

**Function**: `testRecalculationWithComplexFileStatuses()`

**Enhanced Implementation:**
```swift
func testRecalculationWithComplexFileStatuses() async throws {
    // Arrange: Create complex file scenario
    let regularFile = sourceURL.appendingPathComponent("regular.jpg")
    let preExistingFile = sourceURL.appendingPathComponent("existing.jpg")
    let videoWithSidecar = sourceURL.appendingPathComponent("video.mov")
    let sidecar = sourceURL.appendingPathComponent("video.xmp")
    
    createFile(at: regularFile)
    createFile(at: preExistingFile)
    createFile(at: videoWithSidecar)
    createFile(at: sidecar)
    
    // Create a pre-existing file in destA
    try fileManager.copyItem(at: preExistingFile, to: destA_URL.appendingPathComponent("existing.jpg"))
    
    // Set initial destination and trigger scan
    settingsStore.setDestination(destA_URL)
    let testVolume = Volume(name: "Test", devicePath: sourceURL.path, volumeUUID: UUID().uuidString)
    appState.volumes = [testVolume]
    appState.selectedVolumeID = testVolume.id
    
    // Wait for initial scan to complete using publishers
    _ = try await waitForPublisher(
        fileStore.$files
            .dropFirst()
            .first { $0.count >= 3 }  // Wait for 3 files to be discovered
            .eraseToAnyPublisher(),
        timeout: 5.0,
        description: "Initial scan completion"
    )
    
    // Setup recalculation expectations
    try await waitForPublishers(timeout: 3.0, description: "Recalculation with complex statuses") {
        PublisherExpectation(
            description: "Recalculation completed",
            publisher: recalculationManager.didFinishPublisher
        )
        PublisherExpectation(
            description: "All files updated with destB paths",
            publisher: fileStore.$files
                .dropFirst()
                .first { files in
                    files.count >= 3 && 
                    files.allSatisfy { $0.destPath?.contains(self.destB_URL.lastPathComponent) ?? false }
                }
                .eraseToAnyPublisher()
        )
    }
    
    // Act: Change destination (should trigger recalculation) 
    settingsStore.setDestination(destB_URL)
    
    // Assert: Verify files after automatic recalculation
    XCTAssertEqual(fileStore.files.count, 3, "File count should remain stable after recalculation")
    XCTAssertFalse(appState.isRecalculating, "Should not be recalculating after completion")
    XCTAssertTrue(fileStore.files.allSatisfy { $0.status == .waiting }, "All files should be .waiting after destination change")
    XCTAssertFalse(fileStore.files.first { $0.sourceName == "video.mov" }!.sidecarPaths.isEmpty, "Sidecar paths should be preserved after recalculation")
}
```

### Phase 3: Fix LogManagerTests (Day 2)

#### 3.1 Investigate JSON Encoding Issue

**Problem**: `testLogWithNilMetadata()` expects no "metadata" string when metadata is nil

**Investigation Steps:**
1. Check actual JSON output when metadata is nil
2. Verify JSON encoder behavior
3. Update test assertion to match actual behavior

**File**: `Media MuncherTests/LogManagerTests.swift`

**Enhanced Test:**
```swift
func testLogWithNilMetadata() async throws {
    let message = "Log with nil metadata"
    await logManager.info(message, category: "NilMetadataTest", metadata: nil)
    
    let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
    let data = Data(logContent.utf8)
    
    // Parse actual JSON to verify structure
    let decodedEntry = try JSONDecoder().decode(LogEntry.self, from: data)
    
    XCTAssertEqual(decodedEntry.message, message)
    XCTAssertEqual(decodedEntry.category, "NilMetadataTest")
    XCTAssertNil(decodedEntry.metadata, "Metadata should be nil when not provided")
    
    // Verify JSON doesn't contain metadata key (not just the string "metadata")
    let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    XCTAssertFalse(jsonObject?.keys.contains("metadata") ?? true, "JSON should not contain metadata key when nil")
}
```

### Phase 4: Fix Memory Management Tests (Day 2)

#### 4.1 Investigate TestAppContainer Retain Cycles

**File**: `Media MuncherTests/TestSupport/TestAppContainer.swift`

**Analysis**: Check for retain cycles in service initialization

**Enhanced Container with Weak References:**
```swift
@MainActor
final class TestAppContainer {
    let logManager: Logging
    let volumeManager: VolumeManager
    let fileProcessorService: FileProcessorService
    let settingsStore: SettingsStore
    let importService: ImportService
    let fileStore: FileStore
    let recalculationManager: RecalculationManager
    let thumbnailCache: ThumbnailCache

    init(userDefaults: UserDefaults = .init(suiteName: "TestDefaults-\(UUID().uuidString)")!) {
        let mockLog = MockLogManager()
        self.logManager = mockLog
        self.volumeManager = VolumeManager(logManager: mockLog)
        self.thumbnailCache = ThumbnailCache(limit: 128)
        self.fileProcessorService = FileProcessorService(logManager: mockLog, thumbnailCache: thumbnailCache)
        self.settingsStore = SettingsStore(logManager: mockLog, userDefaults: userDefaults)
        self.importService = ImportService(logManager: mockLog)
        
        // These services are @MainActor and initialize synchronously
        self.fileStore = FileStore(logManager: mockLog)
        
        // Careful: RecalculationManager might hold strong references
        self.recalculationManager = RecalculationManager(
            logManager: mockLog, 
            fileProcessorService: fileProcessorService, 
            settingsStore: settingsStore
        )
        
        // Break potential retain cycles
        // Check if RecalculationManager holds strong references to other services
    }
    
    deinit {
        // Ensure proper cleanup
        // Add logging to verify deallocation
    }
}
```

#### 4.2 Enhanced Deallocation Test

**File**: `Media MuncherTests/AppStateRecalculationUnitTests.swift`

**Enhanced Test:**
```swift
func testFileStoreDeallocation() async {
    weak var weakStore: FileStore?
    weak var weakContainer: TestAppContainer?
    
    autoreleasepool {
        let container = TestAppContainer()
        weakContainer = container
        weakStore = container.fileStore
        
        // Verify strong references are working
        XCTAssertNotNil(weakStore, "FileStore should be alive while container exists")
        XCTAssertNotNil(weakContainer, "Container should be alive in autoreleasepool")
    }
    
    // Force garbage collection
    await Task.yield()
    
    XCTAssertNil(weakContainer, "TestAppContainer should deallocate after autoreleasepool")
    XCTAssertNil(weakStore, "FileStore should deallocate when container is deallocated")
}

func testFullServiceDeallocation() async {
    weak var weakRecalculationManager: RecalculationManager?
    weak var weakFileProcessor: FileProcessorService?
    weak var weakSettingsStore: SettingsStore?
    
    autoreleasepool {
        let container = TestAppContainer()
        weakRecalculationManager = container.recalculationManager
        weakFileProcessor = container.fileProcessorService
        weakSettingsStore = container.settingsStore
    }
    
    await Task.yield()
    
    XCTAssertNil(weakRecalculationManager, "RecalculationManager should deallocate")
    XCTAssertNil(weakFileProcessor, "FileProcessorService should deallocate") 
    XCTAssertNil(weakSettingsStore, "SettingsStore should deallocate")
}
```

### Phase 5: Integration Test Fixes (Day 2-3)

#### 5.1 Fix AppStateIntegrationTests

**File**: `Media MuncherTests/AppStateIntegrationTests.swift`

**Issue Analysis**: The test uses `didFinishPublisher` correctly but may have setup timing issues.

**Enhanced Test:**
```swift
func testRecalculationAfterStatusChange() async throws {
    // Arrange: create real source volume with two files
    let srcDir = tempDirectory.appendingPathComponent("SRC")
    try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: srcDir.appendingPathComponent("a.jpg").path, contents: Data([0xFF]))
    FileManager.default.createFile(atPath: srcDir.appendingPathComponent("b.jpg").path, contents: Data([0xFF,0xD8]))

    // Configure settings BEFORE scan so DestinationPathBuilder uses them
    settingsStore.organizeByDate = false
    settingsStore.renameByDate = false

    // Simulate volume mount & scan using publisher coordination
    let vol = Volume(name: "TestVol", devicePath: srcDir.path, volumeUUID: UUID().uuidString)
    appState.volumes = [vol]
    appState.selectedVolumeID = vol.id

    // Wait for scan completion using publishers
    _ = try await waitForPublisher(
        fileStore.$files
            .dropFirst()
            .first { $0.count == 2 }
            .eraseToAnyPublisher(),
        timeout: 5.0,
        description: "Initial scan completion"
    )

    XCTAssertEqual(fileStore.files.count, 2)

    // Setup recalculation expectations
    let newDest = tempDirectory.appendingPathComponent("NewDest")
    try FileManager.default.createDirectory(at: newDest, withIntermediateDirectories: true)
    
    try await waitForPublishers(timeout: 5.0, description: "Recalculation after destination change") {
        PublisherExpectation(
            description: "Recalculation completed",
            publisher: recalculationManager.didFinishPublisher
        )
        PublisherExpectation(
            description: "Files updated with new destination",
            publisher: fileStore.$files
                .dropFirst()
                .first { files in
                    files.allSatisfy { file in
                        guard let dest = file.destPath else { return false }
                        return dest.hasPrefix(newDest.path)
                    }
                }
                .eraseToAnyPublisher()
        )
    }
    
    // Trigger recalculation
    settingsStore.setDestination(newDest)

    // Assert destinations and statuses
    XCTAssertTrue(fileStore.files.allSatisfy { file in
        guard let dest = file.destPath else { return false }
        return dest.hasPrefix(newDest.path)
    })
    XCTAssertTrue(fileStore.files.allSatisfy { $0.status == .waiting })
}
```

### Phase 6: Validation and Documentation (Day 3)

#### 6.1 Comprehensive Test Run

**Commands:**
```bash
# Run all tests to verify fixes
xcodebuild -scheme "Media Muncher" test

# Run specific failing test categories
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/AppStateRecalculationTests"
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/LogManagerTests" 
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/AppStateRecalculationUnitTests"
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/AppStateIntegrationTests"

# Verify logs show proper coordination
tail -f logs/media-muncher-*.log
```

#### 6.2 Performance Validation

**Criteria:**
- Individual tests complete in <1 second
- Full test suite completes in <30 seconds  
- No test timeouts or flaky behavior
- Clean log output with proper async coordination

#### 6.3 Update Documentation

**Files to Update:**

1. **CLAUDE.md** - Add new async test patterns to development guide
2. **ARCHITECTURE.md** - Document test infrastructure alignment with production patterns
3. **README.md** - Update testing section if present

#### 6.4 Create Test Pattern Guidelines

**New File**: `Media MuncherTests/TestSupport/ASYNC_TEST_PATTERNS.md`

```markdown
# Async Test Patterns for Media Muncher

## Publisher-Based Coordination

### Single Operation Completion
```swift
// Wait for a service operation to complete
_ = try await waitForPublisher(
    serviceManager.didFinishPublisher,
    timeout: 2.0,
    description: "Service operation completion"
)
```

### Multiple Coordinated Operations  
```swift
// Wait for multiple related operations
try await waitForPublishers(timeout: 3.0, description: "Complex operation") {
    PublisherExpectation(description: "Service A", publisher: serviceA.didFinishPublisher)
    PublisherExpectation(description: "Service B", publisher: serviceB.didFinishPublisher)
}
```

### State-Based Completion
```swift
// Wait for specific state conditions
_ = try await waitForPublisher(
    fileStore.$files
        .dropFirst()
        .first { files in files.count >= expectedCount }
        .eraseToAnyPublisher(),
    timeout: 5.0,  
    description: "Files reach expected count"
)
```

## Anti-Patterns to Avoid

❌ **Polling with Task.sleep:**
```swift
// DON'T DO THIS
while !condition {
    try await Task.sleep(nanoseconds: 10_000_000)
}
```

❌ **Arbitrary timeouts:**
```swift  
// DON'T DO THIS
try await Task.sleep(nanoseconds: 1_000_000_000)  // Just wait 1 second
```

❌ **Ignoring cancellation:**
```swift
// DON'T DO THIS - always check cancellation in loops
while someCondition {
    // Missing: try Task.checkCancellation()
}
```

## Best Practices

✅ **Use existing publishers for coordination**
✅ **Set up expectations BEFORE triggering operations**  
✅ **Use appropriate timeouts (1-5 seconds for most operations)**
✅ **Clean up subscriptions and cancellables**
✅ **Test both success and failure paths**
```

## Success Metrics

### Quantitative Goals
- **Test Pass Rate**: >99% (from current ~50%)
- **Test Execution Time**: <30 seconds total (from current 60+ seconds with timeouts)
- **Individual Test Performance**: <1 second for simple operations
- **CI/CD Reliability**: Zero flaky test failures

### Qualitative Goals  
- **Developer Experience**: Clear test failure messages, easy debugging
- **Maintainability**: Test patterns match production architecture  
- **Confidence**: Tests validate real async coordination, not just final state

## Risk Assessment

### Technical Risks
- **Publisher Implementation Gaps**: Some services may not expose required publishers
  - *Mitigation*: Audit all services in Phase 1, add missing publishers
- **Timing Edge Cases**: Complex async flows may still have subtle timing issues
  - *Mitigation*: Comprehensive testing across different hardware/load conditions
- **Memory Leaks**: Subscription management could introduce retain cycles
  - *Mitigation*: Explicit subscription cleanup, memory leak testing

### Schedule Risks
- **Scope Creep**: Investigation may reveal additional async coordination issues
  - *Mitigation*: Focus on identified failing tests first, defer edge cases
- **Integration Complexity**: Cross-service coordination fixes may be complex
  - *Mitigation*: Incremental testing, fallback to simpler approaches if needed

### Quality Risks
- **Regression Risk**: Changes to test infrastructure could break working tests
  - *Mitigation*: Incremental rollout, preserve existing test logic where possible

## Conclusion

This plan addresses the systematic async coordination failures in the Media muncher test suite by aligning test infrastructure with the production architecture's publisher-based coordination model. The publisher-based expectation system provides deterministic, fast, and maintainable async testing that matches the application's "Hybrid with Clear Boundaries" async architecture.

**Key Benefits:**
1. **Eliminates Flaky Tests**: Deterministic completion detection
2. **Improves Performance**: Tests complete when operations finish, not after arbitrary delays
3. **Enhances Maintainability**: Test patterns match production code
4. **Increases Confidence**: Tests validate real async coordination mechanisms

**Implementation Priority**: High - blocking reliable CI/CD and development workflow

**Timeline**: 2-3 days for complete implementation and validation