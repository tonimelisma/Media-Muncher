# Async Test Patterns for Media Muncher

## The Race Condition Problem

When testing async operations with Combine publishers, there's a critical race condition:

```swift
// ❌ BROKEN - Race condition
settingsStore.setDestination(newDest)  // Triggers publisher immediately
let expectation = expectation(description: "...") // Too late! Publisher already fired
```

## The Solution: Setup-Then-Trigger Pattern

Always set up expectations BEFORE triggering the operation:

```swift
// ✅ CORRECT - Setup first, then trigger
let expectation = expectation(description: "Recalculation finished")

// 1. Set up publisher subscription FIRST
recalculationManager.didFinishPublisher.sink { _ in
    expectation.fulfill()
}.store(in: &cancellables)

// 2. THEN trigger the operation
settingsStore.setDestination(newDest)

// 3. Wait for completion
await fulfillment(of: [expectation], timeout: 5)
```

## Working Example

See `AppStateRecalculationTests.swift` for a complete working example:

```swift
func testDestinationChangeTriggersRecalculation() async throws {
    // Setup test data
    createFile(at: sourceURL.appendingPathComponent("test.jpg"))
    settingsStore.setDestination(destA_URL)
    try await triggerScanAndWaitForCompletion(fileCount: 1)
    
    // Setup expectations BEFORE triggering change
    let recalculationFinished = expectation(description: "Recalculation finished")
    let filesUpdated = expectation(description: "Files updated")
    
    recalculationManager.didFinishPublisher.sink { _ in 
        recalculationFinished.fulfill() 
    }.store(in: &cancellables)
    
    fileStore.$files.dropFirst().sink { files in
        if files.first?.destPath?.contains(destB.lastPathComponent) ?? false {
            filesUpdated.fulfill()
        }
    }.store(in: &cancellables)

    // NOW trigger the change
    settingsStore.setDestination(destB)
    
    // Wait for completion
    await fulfillment(of: [recalculationFinished, filesUpdated], timeout: 5)
    
    // Verify results
    XCTAssertFalse(appState.isRecalculating)
    XCTAssertEqual(fileStore.files.first?.status, .waiting)
}
```

## Key Principles

1. **Setup-Then-Trigger**: Always set up expectations before triggering operations
2. **Use Detailed Logging**: The `await logManager.debug()` calls are invaluable for debugging
3. **Keep It Simple**: Don't over-engineer complex helper infrastructure
4. **Test One Thing**: Each test should verify one specific behavior

## When to Use This Pattern

- Testing destination changes that trigger recalculation
- Testing file processing that updates publishers
- Any test where you need to coordinate multiple async operations

## Anti-Patterns to Avoid

- Setting up expectations after triggering operations
- Complex helper methods that hide the coordination logic
- Trying to make async tests synchronous with blocking waits