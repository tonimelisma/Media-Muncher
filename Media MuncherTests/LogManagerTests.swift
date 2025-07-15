import XCTest
@testable import Media_Muncher

class LogManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear logs before each test
        LogManager.shared.clearLogs()
    }
    
    override func tearDown() {
        super.tearDown()
        // Clear logs after each test
        LogManager.shared.clearLogs()
    }
    
    func testBasicLogging() {
        // Test static convenience methods
        LogManager.debug("Debug message", category: "Test")
        LogManager.info("Info message", category: "Test")
        LogManager.error("Error message", category: "Test")
        
        // Wait a bit for async operations
        let expectation = XCTestExpectation(description: "Logging completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify entries were added
        XCTAssertEqual(LogManager.shared.entries.count, 3, "Should have 3 log entries")
        
        // Verify log file content
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent, "Log file should have content")
        XCTAssertTrue(logContent?.contains("Debug message") ?? false, "Log file should contain debug message")
        XCTAssertTrue(logContent?.contains("Info message") ?? false, "Log file should contain info message")
        XCTAssertTrue(logContent?.contains("Error message") ?? false, "Log file should contain error message")
    }
    
    func testLoggingWithMetadata() {
        LogManager.info("Test message with metadata", category: "Test", metadata: ["key1": "value1", "key2": "value2"])
        
        // Wait for async operations
        let expectation = XCTestExpectation(description: "Logging completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify metadata is included
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent, "Log file should have content")
        XCTAssertTrue(logContent?.contains("key1") ?? false, "Log file should contain metadata key1")
        XCTAssertTrue(logContent?.contains("value1") ?? false, "Log file should contain metadata value1")
    }
    
    func testLogClearing() {
        LogManager.debug("Test message", category: "Test")
        
        // Wait for logging
        let expectation1 = XCTestExpectation(description: "Logging completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)
        
        XCTAssertEqual(LogManager.shared.entries.count, 1, "Should have 1 log entry")
        
        // Clear logs
        LogManager.shared.clearLogs()
        
        // Wait for clearing
        let expectation2 = XCTestExpectation(description: "Clearing completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
        
        XCTAssertEqual(LogManager.shared.entries.count, 0, "Should have 0 log entries after clearing")
        
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertTrue(logContent?.isEmpty ?? true, "Log file should be empty after clearing")
    }
} 