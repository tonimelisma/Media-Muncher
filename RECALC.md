# RECALC.md - Destination Change Recalculation Flow

## Overview

This document explains the end-to-end production code flow for **automatic destination recalculation** - the feature that updates all loaded media files' destination paths when users change their import destination folder.

## High-Level Architecture

```
User Changes Destination
        ↓
   SettingsStore (publishes change)
        ↓
    AppState (reacts via Combine)
        ↓
FileProcessorService (recalculates paths)
        ↓
    UI Updates (shows new paths)
```

## Detailed Flow Breakdown

### Phase 1: User Changes Destination

**Entry Point**: User selects new folder in Settings UI

**Code Location**: `SettingsStore.swift:208-210`
```swift
func setDestination(_ url: URL) {
    _ = trySetDestination(url)
}
```

**What Happens**:
1. UI calls `settingsStore.setDestination(newURL)`
2. This triggers `trySetDestination()` which performs validation and bookmark creation

### Phase 2: SettingsStore Updates Internal State

**Code Location**: `SettingsStore.swift:155-206`

**Key Steps**:

1. **URL Validation** (lines 159-164):
   ```swift
   var isDir: ObjCBool = false
   guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
       return false
   }
   ```

2. **Write Permission Test** (lines 167-174):
   ```swift
   let testFile = url.appendingPathComponent(".mm_write_test_\(UUID().uuidString)")
   try Data().write(to: testFile)
   try fm.removeItem(at: testFile)
   ```

3. **Security-Scoped Bookmark Creation** (lines 177-188):
   ```swift
   bookmarkData = try url.bookmarkData(options: [.withSecurityScope], ...)
   ```

4. **State Updates** (lines 196-204):
   ```swift
   destinationBookmark = data    // Triggers @Published didSet
   destinationURL = url         // Direct assignment to @Published property
   ```

**Critical Detail**: The `destinationBookmark` setter triggers a `didSet` that calls `resolveBookmark()`:

**Code Location**: `SettingsStore.swift:54-61`
```swift
@Published private(set) var destinationBookmark: Data? {
    didSet {
        self.destinationURL = resolveBookmark()  // Line 59
    }
}
```

This creates a **double assignment** to `destinationURL`:
1. First from `didSet` → `resolveBookmark()`
2. Second from direct assignment in `trySetDestination()`

### Phase 3: Combine Publisher Notification

**Code Location**: `AppState.swift:98-104`

**Publisher Setup**:
```swift
settingsStore.$destinationURL
    .dropFirst() // Skip initial value during AppState initialization
    .receive(on: DispatchQueue.main)
    .sink { [weak self] newDestination in
        self?.handleDestinationChange(newDestination)
    }
    .store(in: &cancellables)
```

**Context**: This subscription is established during `AppState.init()` and remains active throughout the app lifecycle.

**The `.dropFirst()` Logic**:
- Prevents recalculation during app startup when `destinationURL` is first resolved from stored bookmarks
- Only responds to actual user-initiated destination changes
- **Critical for failing tests**: If publisher doesn't fire for subsequent changes, this entire flow breaks

### Phase 4: AppState Destination Change Handling

**Code Location**: `AppState.swift:251-287`

**Entry Point**: `handleDestinationChange(_ newDestination: URL?)`

**State Management**:
```swift
// Cancel any ongoing recalculation
recalculationTask?.cancel()

// Guard against empty file array
guard !files.isEmpty else { return }

// Set UI state to show recalculation in progress
isRecalculating = true
```

**Async Task Creation**:
```swift
recalculationTask = Task {
    do {
        let recalculatedFiles = await fileProcessorService.recalculateFileStatuses(
            for: files,
            destinationURL: newDestination,
            settings: settingsStore
        )
        
        // Check cancellation before UI update
        try Task.checkCancellation()
        
        await MainActor.run {
            self.files = recalculatedFiles
            self.isRecalculating = false
        }
    } catch is CancellationError {
        await MainActor.run {
            self.isRecalculating = false
        }
    } catch {
        await MainActor.run {
            self.isRecalculating = false
            // Could optionally set error state
        }
    }
}
```

**Concurrency Design**:
- Uses `Task` for proper async/await handling
- Supports cancellation if user changes destination again quickly
- Properly isolates UI updates to `MainActor`
- Graceful error handling for network/filesystem issues

### Phase 5: FileProcessorService Recalculation

**Entry Point**: `FileProcessorService.recalculateFileStatuses()`
**Code Location**: `FileProcessorService.swift:317-327`

**Two-Phase Design**:
```swift
func recalculateFileStatuses(
    for files: [File], 
    destinationURL: URL?, 
    settings: SettingsStore
) async -> [File] {
    // Step 1: Sync path calculation (no file I/O)
    let filesWithPaths = recalculatePathsOnly(for: files, destinationURL: destinationURL, settings: settings)
    
    // Step 2: Async file existence checks
    return await checkPreExistingStatus(for: filesWithPaths)
}
```

### Phase 5A: Synchronous Path Calculation

**Code Location**: `FileProcessorService.swift:331-369`

**Purpose**: Calculate new destination paths without any file I/O operations

**Key Logic**:
1. **Handle Missing Destination** (lines 336-346):
   ```swift
   guard let destRootURL = destinationURL else {
       // No destination - reset all files to waiting with no destPath
       return files.map { file in
           var newFile = file
           if newFile.status != .duplicate_in_source {
               newFile.destPath = nil
               newFile.status = .waiting
           }
           return newFile
       }
   }
   ```

2. **Preserve Duplicates** (lines 352-355):
   ```swift
   // Preserve duplicate_in_source files unchanged
   guard file.status != .duplicate_in_source else {
       processedFiles.append(file)
       continue
   }
   ```

3. **Calculate New Paths with Collision Resolution**:
   ```swift
   let fileWithPath = calculateDestinationPath(
       for: file,
       allFiles: processedFiles,
       destinationURL: destRootURL,
       settings: settings
   )
   ```

### Phase 5B: Collision Resolution Logic

**Code Location**: `FileProcessorService.swift:372-411`

**Path Building Process**:
```swift
var suffix = 0
var isUnique = false

while !isUnique {
    let candidatePath = DestinationPathBuilder.buildFinalDestinationUrl(
        for: newFile,
        in: destinationURL,
        settings: settings,
        suffix: suffix > 0 ? suffix : nil
    )

    // Check against other files in this session only
    let inSessionCollision = allFiles.contains { otherFile in
        guard otherFile.id != newFile.id else { return false }
        return otherFile.destPath == candidatePath.path
    }

    if inSessionCollision {
        suffix += 1
    } else {
        newFile.status = .waiting
        newFile.destPath = candidatePath.path
        isUnique = true
    }
}
```

**Collision Resolution Strategy**:
- Checks for conflicts only against files in current processing session
- Uses numerical suffixes: `photo.jpg`, `photo_2.jpg`, `photo_3.jpg`
- Ensures deterministic ordering by processing files in sorted path order

### Phase 5C: File Existence Checking

**Code Location**: `FileProcessorService.swift:414-440`

**Purpose**: Check if files already exist at new destination paths

**Logic**:
```swift
for file in files {
    if let destPath = file.destPath, file.status != .duplicate_in_source {
        if fileManager.fileExists(atPath: destPath) {
            let candidateURL = URL(fileURLWithPath: destPath)
            if await isSameFile(sourceFile: file, destinationURL: candidateURL) {
                updatedFile.status = .pre_existing
            } else {
                // Different file exists at destination, keep original status
            }
        } else {
            // File doesn't exist at destination, should be .waiting
            updatedFile.status = .waiting
        }
    }
}
```

**File Comparison Logic** (`isSameFile()` - lines 182-245):
1. **Size Check**: Early exit if byte sizes differ
2. **Filename Match**: Identical names = same file (handles overwrites)
3. **Timestamp Proximity**: ±60 seconds for FAT filesystem compatibility
4. **SHA-256 Fallback**: Expensive but definitive content comparison

### Phase 6: UI State Update

**Code Location**: `AppState.swift:270-273`

**MainActor Isolation**:
```swift
await MainActor.run {
    self.files = recalculatedFiles
    self.isRecalculating = false
}
```

**UI Bindings**: SwiftUI views observe `@Published var files` and automatically update when this assignment occurs

## State Transitions

### File Status States During Recalculation

1. **Before Recalculation**: Files have `destPath` pointing to old destination
2. **During Recalculation**: `appState.isRecalculating = true` (shows progress indicator)
3. **After Recalculation**: Files have new `destPath` and updated `status`

### Possible File Statuses

- **`.waiting`**: Ready to import, no conflicts
- **`.pre_existing`**: Same file already exists at destination  
- **`.duplicate_in_source`**: Duplicate within source volume (unchanged during recalc)

### AppState Properties

- **`files: [File]`**: Main file array that drives UI
- **`isRecalculating: Bool`**: Controls progress indicators
- **`recalculationTask: Task?`**: Handles cancellation for rapid destination changes

## Preserved Data During Recalculation

**What Gets Preserved**:
- File metadata (size, date, EXIF data)
- Thumbnails (expensive to regenerate)
- Sidecar file associations (`.xmp`, `.thm` files)
- Duplicate relationships within source

**What Gets Recalculated**:
- `destPath` (destination file path)
- `status` (waiting vs pre-existing)
- Collision resolution suffixes

## Error Handling

### Cancellation Support
```swift
try Task.checkCancellation()
```
- Prevents UI updates if user changed destination again
- Gracefully handles rapid destination changes

### Error Recovery
```swift
catch {
    await MainActor.run {
        self.isRecalculating = false
        // Could optionally set error state
    }
}
```
- Always resets `isRecalculating` flag
- Prevents UI from staying in "loading" state indefinitely

## Integration Points

### DestinationPathBuilder
- Pure function for generating file paths
- Handles date-based organization (`YYYY/MM/`)
- Implements rename-by-date logic
- Consistent across initial scan and recalculation

### Settings Integration
- Respects all user preferences during recalculation
- `organizeByDate`: Creates date-based subfolders
- `renameByDate`: Uses capture date for filenames
- File type filters: Not relevant during recalc (files already filtered)

## Performance Characteristics

### Synchronous Phase
- **Fast**: No file I/O, pure path calculation
- **Deterministic**: Same inputs always produce same outputs
- **Memory Efficient**: Processes files sequentially

### Asynchronous Phase  
- **I/O Bound**: Limited by filesystem performance
- **Concurrent**: Could be parallelized but currently sequential
- **Cancellable**: Supports user interruption

## Test Environment Differences

### Production Environment
- Destination changes triggered by real user interaction
- Natural timing between destination changes
- Publisher chain works reliably
- Files loaded through normal volume scanning

### Test Environment
- Programmatic destination changes via `setDestination()`
- Rapid successive calls without delays
- Files loaded by direct assignment to `appState.files`
- Publisher chain may not fire reliably (root cause of failing tests)

## Critical Dependencies

### Combine Framework
- **Publisher Chain**: `settingsStore.$destinationURL.dropFirst()`
- **Threading**: `.receive(on: DispatchQueue.main)`
- **Memory Management**: Weak references prevent retain cycles

### Swift Concurrency
- **Actor Isolation**: FileProcessorService operations on background actor
- **MainActor**: UI updates properly isolated
- **Task Cancellation**: Supports user interruption

### Security Framework
- **Sandbox Access**: Security-scoped bookmarks for destination folders
- **Permission Validation**: Write tests before path calculation

This flow represents **core user functionality** - users expect destination changes to immediately update all loaded files without requiring a volume rescan.

---

## File Context Map for Recalculation Flow

### **Core Production Files**

| File | Role | Key Responsibility |
|------|------|-------------------|
| **`SettingsStore.swift`** | **Publisher Source** | Contains double assignment bug (lines 59&204). `setDestination()` triggers `@Published destinationURL` changes that feed the Combine chain |
| **`AppState.swift`** | **Flow Orchestrator** | Subscribes to `settingsStore.$destinationURL.dropFirst()` (line 98). `handleDestinationChange()` (line 251) coordinates entire recalc flow |
| **`FileProcessorService.swift`** | **Business Logic** | `recalculateFileStatuses()` (line 317) - two-phase: sync path calc + async file existence checks. Contains collision resolution and pre-existing detection |
| **`DestinationFolderPicker.swift`** | **UI Trigger** | NSViewRepresentable that calls `settingsStore.trySetDestination()` (lines 94,120) when user changes destination |
| **`SettingsView.swift`** | **UI Container** | SwiftUI view that embeds `DestinationFolderPicker` - the visual settings interface |

### **Test Files (Revealing Architectural Issues)**

| File | Test Focus | What It Reveals |
|------|------------|----------------|
| **`AppStateRecalculationTests.swift`** | **End-to-End Flow** | Lines 124-128: Async polling pattern `while appState.isRecalculating && attempts < 50` - indicates unreliable publisher chain |
| **`AppStateRecalculationSimpleTests.swift`** | **Basic AppState** | Lines 57-63: Multiple rapid `setDestination()` calls to test race conditions. Line 76: Direct `recalculatePathsOnly()` testing |
| **`FileProcessorRecalculationTests.swift`** | **Business Logic** | Lines 93-243: Comprehensive pipeline test covering pre-existing detection, collision resolution, status transitions through recalculation |

### **What's Happening in Each File**

#### **SettingsStore.swift - The Publisher Source**
```swift
// THE CRITICAL BUG (lines 54-61 & 196-204):
@Published private(set) var destinationBookmark: Data? {
    didSet { self.destinationURL = resolveBookmark() }  // Assignment #1
}
// Later in trySetDestination():
destinationBookmark = data     // Triggers didSet above
destinationURL = url          // Assignment #2 - RACE CONDITION
```

**What's Wrong**: The `destinationURL` property gets assigned twice during a single `setDestination()` call:
1. First from the `didSet` handler when `destinationBookmark` is set
2. Second from direct assignment in `trySetDestination()`

This creates race conditions where the Combine publisher may fire 0, 1, or 2 times unpredictably.

#### **AppState.swift - The Brittle Orchestrator**
```swift
// THE FRAGILE COMBINE CHAIN (lines 98-104):
settingsStore.$destinationURL
    .dropFirst() // Skip initial - BREAKS IN TESTS
    .receive(on: DispatchQueue.main)
    .sink { [weak self] newDestination in
        self?.handleDestinationChange(newDestination)
    }

// THE MANUAL TASK MANAGEMENT (lines 251-287):
private func handleDestinationChange(_ newDestination: URL?) {
    recalculationTask?.cancel()  // Manual cleanup
    guard !files.isEmpty else { return }
    isRecalculating = true
    recalculationTask = Task { /* async work */ }
}
```

**What's Wrong**: 
- `.dropFirst()` is a workaround for initialization timing issues that breaks in test environments
- Manual task management with `recalculationTask?.cancel()` is error-prone
- Mixed reactive (Combine) and imperative (Task) patterns

#### **FileProcessorService.swift - The Business Logic**
```swift
// TWO-PHASE DESIGN (lines 317-327):
func recalculateFileStatuses(
    for files: [File], 
    destinationURL: URL?, 
    settings: SettingsStore
) async -> [File] {
    // Step 1: Sync path calculation (no file I/O)
    let filesWithPaths = recalculatePathsOnly(for: files, destinationURL: destinationURL, settings: settings)
    
    // Step 2: Async file existence checks
    return await checkPreExistingStatus(for: filesWithPaths)
}
```

**What Works**: This is actually well-designed business logic with clear separation between:
- Synchronous path calculation (testable, deterministic)
- Asynchronous file I/O (handles pre-existing detection)

#### **DestinationFolderPicker.swift - The UI Trigger**
```swift
// USER INTERACTION HANDLERS (lines 90-107 & 110-129):
@objc func popupSelectionChanged(_ menuItem: NSMenuItem) {
    guard let url = menuItem.representedObject as? URL else { return }
    
    if parent.settingsStore.trySetDestination(url) {
        // Success: selection updated
    } else {
        // Failure: revert selection, show alert
    }
}

@objc private func showOpenPanel() {
    // NSOpenPanel for custom folder selection
    if self.parent.settingsStore.trySetDestination(url) {
        // Success: rebuild menu
    } else {
        // Failure: show permission alert
    }
}
```

**What It Does**: Provides the UI interface for destination changes. Calls `settingsStore.trySetDestination()` which triggers the entire recalculation flow.

#### **SettingsView.swift - The UI Container**
```swift
// SIMPLE SWIFTUI WRAPPER (lines 22-25):
VStack(alignment: .leading, spacing: 8) {
    DestinationFolderPicker()
        .environmentObject(settingsStore)
        .frame(maxWidth: 350)
    // Display current destination path
}
```

**What It Does**: Simple SwiftUI container that embeds the `DestinationFolderPicker` AppKit component.

### **Test Files - Exposing the Problems**

#### **AppStateRecalculationTests.swift - End-to-End Flow Testing**
```swift
// THE ASYNC POLLING PATTERN (lines 124-128):
var attempts = 0
while appState.isRecalculating && attempts < 50 {
    try await Task.sleep(nanoseconds: 10_000_000)
    attempts += 1
}
```

**What This Reveals**: The publisher chain is so unreliable that tests cannot wait for natural completion. They must poll the `isRecalculating` flag with arbitrary timeouts.

```swift
// MANUAL STATE INJECTION (lines 109-114):
let processedFiles = await fileProcessorService.processFiles(
    from: sourceURL,
    destinationURL: destA_URL,
    settings: settingsStore
)
appState.files = processedFiles  // BYPASSES NORMAL VOLUME SCAN
```

**What This Reveals**: Tests cannot rely on the normal volume scanning flow, so they manually inject file state.

#### **AppStateRecalculationSimpleTests.swift - Basic State Testing**
```swift
// RAPID DESTINATION CHANGES (lines 57-63):
settingsStore.setDestination(tempDir1)
settingsStore.setDestination(tempDir2)
settingsStore.setDestination(tempDir1)
// Should not crash and final destination should be correct
XCTAssertEqual(settingsStore.destinationURL, tempDir1)
```

**What This Tests**: Race condition handling when users rapidly change destinations.

```swift
// DIRECT METHOD TESTING (lines 75-86):
let result = await fileProcessorService.recalculatePathsOnly(
    for: mockFiles,
    destinationURL: tempDir,
    settings: settingsStore
)
```

**What This Reveals**: Tests bypass the unreliable Combine chain by testing business logic methods directly.

#### **FileProcessorRecalculationTests.swift - Business Logic Validation**
```swift
// COMPREHENSIVE PIPELINE TEST (lines 93-243):
// === Test isSameFile heuristics ===
// Scenario 1: Identical files should be detected as pre-existing
XCTAssertEqual(identicalFile!.status, .pre_existing, 
              "Identical file should be detected as pre-existing via size + filename match")

// Scenario 2: Different content files should be waiting with collision suffix
XCTAssertEqual(differentFile!.status, .waiting, 
              "Different file should be waiting due to content difference")

// === PHASE 2: Recalculation (Test status transitions) ===
let recalculatedFiles = await processor.recalculateFileStatuses(
    for: initialFiles,
    destinationURL: destinationB,
    settings: settings
)
```

**What This Tests**: The business logic works correctly - file comparison heuristics, collision resolution, status transitions during recalculation.

### **The Flow Summary**

1. **UI Trigger**: User clicks folder in `DestinationFolderPicker` 
2. **Double Assignment**: `SettingsStore.trySetDestination()` assigns `destinationURL` twice
3. **Brittle Chain**: Combine publisher with `.dropFirst()` *sometimes* fires
4. **Manual Orchestration**: `AppState.handleDestinationChange()` manually manages tasks
5. **Business Logic**: `FileProcessorService` does the actual recalculation work
6. **Test Fragility**: Tests require async polling because publisher chain is unreliable

### **Root Issue Analysis**

**The Problem**: The architecture mixes reactive (Combine) and imperative (manual task management) patterns, creating race conditions and test brittleness. The double assignment in SettingsStore breaks publisher reliability, forcing tests to use polling instead of deterministic state observation.

**Evidence in Tests**:
- Async polling pattern appears in multiple test files
- Manual state injection bypasses normal flows
- Direct method calls avoid the Combine publisher chain
- Race condition testing with rapid `setDestination()` calls

**The Business Logic Works**: `FileProcessorService` contains solid, well-tested business logic for path calculation, collision resolution, and pre-existing detection. The problem is entirely in the orchestration and state management layers.

---

## Architectural Analysis & Alternative Designs

### Current Architecture Issues

**Critical Problems Identified**:

1. **Double Publisher Assignment** (SettingsStore.swift:59 & 204):
   - `destinationBookmark` didSet triggers `resolveBookmark()` → `destinationURL` assignment
   - Followed by direct `destinationURL = url` assignment
   - Creates race conditions and publisher firing inconsistencies

2. **Test Fragility Pattern**:
   ```swift
   // Tests consistently use async polling
   while appState.isRecalculating && attempts < 50 {
       try await Task.sleep(nanoseconds: 10_000_000)
       attempts += 1
   }
   ```

3. **Manual State Injection** in tests:
   ```swift
   appState.files = processedFiles  // Bypasses normal volume scan flow
   ```

4. **Combine Chain Brittleness**:
   ```swift
   settingsStore.$destinationURL
       .dropFirst() // Skip initial value - source of test failures
   ```

### Evaluation Criteria

**Testability**:
- Synchronous Testability: Can tests verify behavior without async polling/timeouts?
- Publisher Reliability: Do Combine chains fire consistently in test environment?
- State Isolation: Can test setup avoid manual state injection?
- Deterministic Timing: No race conditions or timing dependencies

**Robustness**:
- No Double Assignment: Single source of truth for state changes
- Cancellation Safety: Clean interruption without leaked state
- Error Recovery: Graceful handling of I/O failures
- Thread Safety: Proper actor isolation

**Maintainability**:
- Clear Responsibilities: Single purpose per class/method
- Minimal Coupling: Services don't depend on each other's internals
- Observable State: Easy to debug/trace execution
- No Hidden Side Effects: Explicit state transitions

**Performance**:
- Non-blocking UI: All heavy work off main thread
- Efficient Updates: Only recalculate what changed
- Memory Bounded: No unbounded resource growth
- Cancellable: User can interrupt operations

---

## Alternative Architecture Designs

### Architecture 1: Command Pattern with Explicit State Machine

**Core Concept**: Replace reactive Combine chain with explicit command execution and state transitions.

```swift
protocol RecalculationCommand {
    func execute(files: [File], destination: URL?, settings: SettingsStore) async -> [File]
}

class RecalculationStateMachine {
    enum State {
        case idle
        case recalculating(task: Task<[File], Error>)
    }
    
    @Published private(set) var state: State = .idle
    @Published private(set) var files: [File] = []
    
    func requestRecalculation(destination: URL?, settings: SettingsStore) {
        // Cancel existing, start new - no race conditions
        switch state {
        case .recalculating(let task):
            task.cancel()
        case .idle:
            break
        }
        
        let newTask = Task {
            let command = DestinationChangeCommand()
            return await command.execute(files: files, destination: destination, settings: settings)
        }
        
        state = .recalculating(task: newTask)
        
        Task {
            do {
                let result = try await newTask.value
                await MainActor.run {
                    self.files = result
                    self.state = .idle
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.state = .idle
                }
            }
        }
    }
}

struct DestinationChangeCommand: RecalculationCommand {
    func execute(files: [File], destination: URL?, settings: SettingsStore) async -> [File] {
        // Pure business logic - easily testable
        let fileProcessor = FileProcessorService()
        return await fileProcessor.recalculateFileStatuses(
            for: files,
            destinationURL: destination,
            settings: settings
        )
    }
}
```

**Benefits**:
- No publisher chain brittleness
- Explicit state transitions
- Easy to test synchronously via direct command execution
- Clear cancellation semantics
- Single responsibility per command

### Architecture 2: Event Sourcing with Replay

**Core Concept**: Store sequence of destination changes, replay to compute current state.

```swift
struct DestinationChangeEvent {
    let timestamp: Date
    let destination: URL?
    let id: UUID
}

class RecalculationEventStore {
    private var events: [DestinationChangeEvent] = []
    @Published private(set) var currentState: RecalculationState = .idle
    
    func recordDestinationChange(_ destination: URL?) -> UUID {
        let event = DestinationChangeEvent(
            timestamp: Date(), 
            destination: destination, 
            id: UUID()
        )
        events.append(event)
        
        // Trigger replay
        Task {
            await replayEvents()
        }
        
        return event.id
    }
    
    private func replayEvents() async {
        guard let latestEvent = events.last else { return }
        
        currentState = .recalculating(eventID: latestEvent.id)
        
        let result = await fileProcessor.recalculateFileStatuses(
            for: currentFiles,
            destinationURL: latestEvent.destination,
            settings: settings
        )
        
        await MainActor.run {
            self.currentState = .completed(files: result, eventID: latestEvent.id)
        }
    }
}

enum RecalculationState {
    case idle
    case recalculating(eventID: UUID)
    case completed(files: [File], eventID: UUID)
}
```

**Benefits**:
- Natural handling of rapid changes (only latest event matters)
- Audit trail of all destination changes
- Can replay/debug any state
- No lost events during rapid changes
- Time-travel debugging capabilities

### Architecture 3: Actor-Based Pipeline

**Core Concept**: Dedicated actor for recalculation with message passing.

```swift
actor RecalculationActor {
    private var currentFiles: [File] = []
    private var currentTask: Task<Void, Never>?
    private var completionHandler: ((Result<[File], Error>) -> Void)?
    
    func updateFiles(_ files: [File]) {
        currentFiles = files
    }
    
    func requestRecalculation(
        destination: URL?, 
        settings: SettingsStore,
        completion: @escaping (Result<[File], Error>) -> Void
    ) {
        currentTask?.cancel() // Clean cancellation
        completionHandler = completion
        
        currentTask = Task {
            do {
                let fileProcessor = FileProcessorService()
                let result = await fileProcessor.recalculateFileStatuses(
                    for: currentFiles,
                    destinationURL: destination, 
                    settings: settings
                )
                
                try Task.checkCancellation()
                currentFiles = result
                completion(.success(result))
            } catch is CancellationError {
                // Task was cancelled, don't call completion
            } catch {
                completion(.failure(error))
            }
        }
    }
}

class RecalculationCoordinator: ObservableObject {
    @Published var files: [File] = []
    @Published var isRecalculating = false
    
    private let actor = RecalculationActor()
    
    func handleDestinationChange(_ destination: URL?, settings: SettingsStore) {
        isRecalculating = true
        
        Task {
            await actor.updateFiles(files)
            await actor.requestRecalculation(destination: destination, settings: settings) { result in
                Task { @MainActor in
                    self.isRecalculating = false
                    switch result {
                    case .success(let newFiles):
                        self.files = newFiles
                    case .failure(let error):
                        // Handle error
                        break
                    }
                }
            }
        }
    }
}
```

**Benefits**:
- Thread safety guaranteed by actor
- Natural cancellation semantics
- No shared mutable state
- Clear async boundaries
- Actor provides natural serialization

### Architecture 4: Functional Pipeline with Immutable State

**Core Concept**: Pure functions with immutable state transformations.

```swift
struct RecalculationState {
    let files: [File]
    let destination: URL?
    let isRecalculating: Bool
    let error: Error?
    
    static func initial() -> RecalculationState {
        RecalculationState(files: [], destination: nil, isRecalculating: false, error: nil)
    }
}

enum RecalculationAction {
    case destinationChanged(URL?)
    case recalculationStarted
    case recalculationCompleted([File])
    case recalculationFailed(Error)
    case recalculationCancelled
}

struct RecalculationReducer {
    static func reduce(
        state: RecalculationState, 
        action: RecalculationAction
    ) -> RecalculationState {
        switch action {
        case .destinationChanged(let url):
            return RecalculationState(
                files: state.files,
                destination: url,
                isRecalculating: true,
                error: nil
            )
        case .recalculationCompleted(let files):
            return RecalculationState(
                files: files,
                destination: state.destination,
                isRecalculating: false,
                error: nil
            )
        case .recalculationFailed(let error):
            return RecalculationState(
                files: state.files,
                destination: state.destination,
                isRecalculating: false,
                error: error
            )
        case .recalculationCancelled:
            return RecalculationState(
                files: state.files,
                destination: state.destination,
                isRecalculating: false,
                error: nil
            )
        case .recalculationStarted:
            return RecalculationState(
                files: state.files,
                destination: state.destination,
                isRecalculating: true,
                error: nil
            )
        }
    }
}

class RecalculationStore: ObservableObject {
    @Published private(set) var state = RecalculationState.initial()
    private var currentTask: Task<Void, Never>?
    
    func dispatch(_ action: RecalculationAction) {
        state = RecalculationReducer.reduce(state: state, action: action)
        
        // Side effects
        if case .destinationChanged(let url) = action {
            performRecalculation(destination: url)
        }
    }
    
    private func performRecalculation(destination: URL?) {
        currentTask?.cancel()
        
        currentTask = Task {
            do {
                let fileProcessor = FileProcessorService()
                let result = await fileProcessor.recalculateFileStatuses(
                    for: state.files,
                    destinationURL: destination,
                    settings: settingsStore
                )
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.dispatch(.recalculationCompleted(result))
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.dispatch(.recalculationCancelled)
                }
            } catch {
                await MainActor.run {
                    self.dispatch(.recalculationFailed(error))
                }
            }
        }
    }
}
```

**Benefits**:
- No side effects in core logic
- Easy to test (pure functions)
- Predictable state transitions
- Composable operations
- Time-travel debugging
- Clear action/state separation

---

## Architecture Evaluation Matrix

| Criteria | Current | Command Pattern | Event Sourcing | Actor Pipeline | Functional |
|----------|---------|----------------|----------------|----------------|------------|
| **Testability** |
| Synchronous Testing | ❌ (async polling) | ✅ (explicit commands) | ✅ (replay events) | ⚠️ (actor boundaries) | ✅ (pure functions) |
| Publisher Reliability | ❌ (dropFirst issues) | ✅ (no publishers) | ✅ (event-driven) | ✅ (direct calls) | ✅ (no publishers) |
| State Isolation | ❌ (manual injection) | ✅ (dependency injection) | ✅ (event replay) | ✅ (actor encapsulation) | ✅ (immutable state) |
| Deterministic Timing | ❌ (race conditions) | ✅ (sequential execution) | ✅ (ordered events) | ✅ (actor serialization) | ✅ (pure functions) |
| **Robustness** |
| No Double Assignment | ❌ (bookmark + URL) | ✅ (single command path) | ✅ (single event stream) | ✅ (actor state) | ✅ (immutable updates) |
| Cancellation Safety | ⚠️ (manual task mgmt) | ✅ (command cancellation) | ✅ (event invalidation) | ✅ (actor task mgmt) | ⚠️ (external cancellation) |
| Error Recovery | ⚠️ (try/catch blocks) | ✅ (command error handling) | ✅ (event retry) | ✅ (actor isolation) | ✅ (functional error types) |
| Thread Safety | ⚠️ (MainActor + async) | ✅ (explicit isolation) | ✅ (immutable events) | ✅ (actor guarantee) | ✅ (no shared state) |
| **Maintainability** |
| Clear Responsibilities | ❌ (mixed concerns) | ✅ (command per action) | ✅ (event per change) | ✅ (actor per domain) | ✅ (function per transform) |
| Minimal Coupling | ❌ (6-layer dependency) | ✅ (command interface) | ✅ (event bus) | ✅ (message passing) | ✅ (function composition) |
| Observable State | ⚠️ (scattered @Published) | ✅ (state machine) | ✅ (event log) | ⚠️ (actor internals) | ✅ (explicit state) |
| No Hidden Side Effects | ❌ (didSet triggers) | ✅ (explicit execution) | ✅ (event recording) | ✅ (actor boundaries) | ✅ (pure functions) |
| **Performance** |
| Non-blocking UI | ✅ (async/await) | ✅ (async commands) | ✅ (async replay) | ✅ (actor background) | ✅ (async transforms) |
| Efficient Updates | ⚠️ (full recalc always) | ✅ (incremental commands) | ⚠️ (replay overhead) | ✅ (delta updates) | ✅ (immutable sharing) |
| Memory Bounded | ✅ (no accumulation) | ✅ (command cleanup) | ⚠️ (event history grows) | ✅ (actor cleanup) | ✅ (structural sharing) |
| Cancellable | ⚠️ (manual task mgmt) | ✅ (command cancellation) | ✅ (event cancellation) | ✅ (actor task cancel) | ⚠️ (external control) |

---

## Recommendations

### **Winner: Command Pattern with State Machine**

**Rationale**:
- **Addresses core testing issues**: Eliminates async polling, publisher brittleness
- **Fixes robustness problems**: No double assignment, clean cancellation
- **Improves maintainability**: Clear responsibilities, explicit state transitions
- **Maintains performance**: All current performance characteristics preserved
- **Minimal disruption**: Can be implemented incrementally

**Key Implementation Points**:

1. **Replace Combine publisher chain** with explicit `DestinationChangeCommand`
2. **Centralize state in RecalculationStateMachine** instead of scattered `@Published` properties
3. **Make recalculation synchronous** for testing with async wrapper for production
4. **Use dependency injection** for FileProcessorService instead of direct coupling

**Migration Strategy**:
```swift
// Phase 1: Add command infrastructure alongside existing code
// Phase 2: Replace handleDestinationChange with command execution
// Phase 3: Remove old Combine chain
// Phase 4: Update tests to use synchronous command execution
```

### **Runner-up: Actor Pipeline**

**Strengths**:
- Excellent for robustness and thread safety
- Natural fit with Swift concurrency model
- Good choice if concurrent recalculations become requirement

**Limitations**:
- Slightly more complex testing due to actor boundaries
- Less familiar pattern for team

### **Not Recommended**:

**Event Sourcing**: 
- Overkill for this use case
- Memory overhead from event history
- Added complexity without clear benefits

**Functional Pipeline**: 
- Excellent for pure logic but requires significant refactoring
- Would need major changes to existing SwiftUI integration
- Steeper learning curve for team

---

## Conclusion

The current recalculation architecture suffers from fundamental design issues that manifest as test fragility and robustness problems. The **Command Pattern with State Machine** approach offers the best balance of testability, robustness, and maintainability while requiring minimal disruption to existing code.

**Critical Issues Solved**:
- Eliminates double publisher assignment causing race conditions
- Removes brittle Combine chains with `.dropFirst()` workarounds  
- Eliminates manual async polling in tests
- Provides clear separation of concerns across services

**Implementation Priority**:
1. **High**: Command Pattern with State Machine (addresses all critical issues)
2. **Medium**: Actor Pipeline (excellent robustness, slightly more complex)
3. **Low**: Event Sourcing (overkill) and Functional Pipeline (major refactor)