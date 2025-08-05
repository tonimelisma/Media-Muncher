//
//  AppContainerTests.swift
//  Media MuncherTests
//
//  Tests for AppContainer initialization and dependency injection
//

import XCTest
@testable import Media_Muncher

@MainActor
final class AppContainerTests: XCTestCase {
    
    func testAppContainerInitialization() async throws {
        // Given: No existing container
        
        // When: Creating a new AppContainer
        let container = AppContainer()
        
        // Then: All services should be properly initialized
        XCTAssertNotNil(container.logManager)
        XCTAssertNotNil(container.volumeManager)
        XCTAssertNotNil(container.thumbnailCache)
        XCTAssertNotNil(container.fileProcessorService)
        XCTAssertNotNil(container.settingsStore)
        XCTAssertNotNil(container.importService)
        XCTAssertNotNil(container.fileStore)
        XCTAssertNotNil(container.recalculationManager)
        XCTAssertNotNil(container.appState)
    }
    
    func testLogManagerLogsInitialization() async throws {
        // Given: A new AppContainer
        let container = AppContainer()

        // When: Initialization completes
        // Give a moment for the async logging to complete
        try await Task.sleep(for: .milliseconds(100))
        await container.logManager.info("Test log entry", category: "Test")

        // Then: the log file should contain our test message. If it doesn't,
        // logging is broken and the log manager isn't writing to disk.
        guard let logManager = container.logManager as? LogManager else {
            return XCTFail("AppContainer should provide a concrete LogManager for log inspection")
        }
        let logContents = logManager.getLogFileContents()

        XCTAssertTrue(
            logContents?.contains("Test log entry") == true,
            "Expected 'Test log entry' to be written to the log file, but it was missing"
        )
    }
}
