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

        // When: We write a test log entry
        // The LogManager actor ensures synchronizeFile() completes before await returns
        try await Task.sleep(for: .milliseconds(100))
        await container.logManager.info("Test log entry", category: "AppContainerTest")

        // Then: The log file should contain our test message
        guard let logManager = container.logManager as? LogManager else {
            return XCTFail("AppContainer should provide a concrete LogManager for log inspection")
        }
        
        let logContents = logManager.getLogFileContents()
        XCTAssertNotNil(logContents, "Log file should exist and be readable")
        
        guard let contents = logContents else {
            return XCTFail("Failed to read log file contents")
        }
        
        XCTAssertTrue(
            contents.contains("Test log entry"),
            "Expected 'Test log entry' to be written to log file. Log contents: \(contents.prefix(500))"
        )
        
        XCTAssertTrue(
            contents.contains("AppContainerTest"),
            "Expected category 'AppContainerTest' to be in log file. Log contents: \(contents.prefix(500))"
        )
    }
}
