import XCTest
@testable import Media_Muncher

class LogManagerTests: XCTestCase {
    
    func testLogManagerWritesToFile() {
        // Given
        let logManager = LogManager.shared
        let expectation = XCTestExpectation(description: "Log write completes")
        let message = "Test message \(UUID())"
        
        // When
        LogManager.info(message, category: "Test") {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
        XCTAssertNotNil(logContent, "Log file should not be empty")
        XCTAssertTrue(logContent?.contains(message) ?? false, "Log file should contain the test message")
    }
}
 