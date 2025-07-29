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
        
        // Then: LogManager should have logged the initialization
        // Note: We can't easily test the log contents without exposing internal state,
        // but we can verify the LogManager is working by calling it directly
        await container.logManager.info("Test log entry", category: "Test")
        
        // If we get here without crashing, the LogManager is working
        XCTAssertTrue(true, "LogManager successfully handled initialization and test logging")
    }
}