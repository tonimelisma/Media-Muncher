import XCTest
@testable import Media_Muncher

// MARK: - Test helper extension

extension LogManager {
    /// Writes an entry and awaits its completion (used only in unit tests)
    func writeSync(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]? = nil) async {
        await self.write(level: level, category: category, message: message, metadata: metadata)
    }
}

// A mock implementation of the Logging protocol for testing purposes.
// This mock does not write to a file but stores log entries in memory.
final class TestLogManager: @unchecked Sendable, Logging {
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String : String]?) async {
        // For unit testing LogManager, we don't need a complex mock.
        // The real LogManager is tested against the file system.
    }
}

final class LogManagerTests: XCTestCase {
    
    var logManager: LogManager!
    var logFileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        logManager = LogManager()
        logFileURL = logManager.logFileURL
        // Ensure no previous log file exists
        try? FileManager.default.removeItem(at: logFileURL)
    }

    override func tearDownWithError() throws {
        // Clean up the created log file
        try? FileManager.default.removeItem(at: logFileURL)
        logManager = nil
        logFileURL = nil
        try super.tearDownWithError()
    }
    
    // Test that the LogManager creates a log file.
    func testLogManagerWritesToFile() async throws {
        let message = "Test message"
        await logManager.info(message, category: "Test")
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(logContent.contains(message))
    }
    
    // Test logging at all available levels.
    func testAllLogLevels() async throws {
        let debugMessage = "This is a debug message"
        let infoMessage = "This is an info message"
        let errorMessage = "This is an error message"
        
        await logManager.debug(debugMessage, category: "Test")
        await logManager.info(infoMessage, category: "Test")
        await logManager.error(errorMessage, category: "Test")
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(logContent.contains(debugMessage))
        XCTAssertTrue(logContent.contains(infoMessage))
        XCTAssertTrue(logContent.contains(errorMessage))
    }
    
    // Test logging with metadata.
    func testLogWithMetadata() async throws {
        let message = "Log with metadata"
        let metadata = ["key1": "value1", "key2": "value2"]
        await logManager.info(message, category: "MetadataTest", metadata: metadata)
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(logContent.contains("\"key1\":\"value1\""))
        XCTAssertTrue(logContent.contains("\"key2\":\"value2\""))
    }
    
    // Test logging with nil metadata.
    func testLogWithNilMetadata() async throws {
        let message = "Log with nil metadata"
        await logManager.info(message, category: "NilMetadataTest", metadata: nil)
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(logContent.contains(message))
        XCTAssertFalse(logContent.contains("metadata"))
    }
    
    // Test that the logged JSON is well-formed.
    func testJSONStructure() async throws {
        let message = "Valid JSON test"
        let metadata = ["path": "/dev/null"]
        await logManager.info(message, category: "JSONTest", metadata: metadata)
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        let data = Data(logContent.utf8)
        
        let decodedEntry = try JSONDecoder().decode(LogEntry.self, from: data)
        
        XCTAssertEqual(decodedEntry.message, message)
        XCTAssertEqual(decodedEntry.category, "JSONTest")
        XCTAssertEqual(decodedEntry.level, .info)
        XCTAssertEqual(decodedEntry.metadata?["path"], "/dev/null")
    }
    
    // Test concurrent logging from multiple threads.
    func testConcurrentLogging() async throws {
        let expectation = self.expectation(description: "Concurrent logging completes")
        expectation.expectedFulfillmentCount = 100
        
        for i in 1...100 {
            Task {
                await self.logManager.info("Concurrent message \(i)", category: "ConcurrentTest")
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5)
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = logContent.components(separatedBy: .newlines)
        // Check if all 100 messages were logged.
        XCTAssertEqual(lines.count, 100)
    }
    
    // Test that no malformed JSON is produced by concurrent writes.
    func testNoMalformedJSONAfterConcurrentWrites() async throws {
        try await testConcurrentLogging() // Reuse the concurrent logging
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = logContent.components(separatedBy: .newlines)
        
        for line in lines where !line.isEmpty {
            let data = Data(line.utf8)
            let decoder = JSONDecoder()
            XCTAssertNoThrow(try decoder.decode(LogEntry.self, from: data), "Line should be valid JSON: \(line)")
        }
    }

    // Test multiple log entries are appended correctly.
    func testMultipleLogEntries() async throws {
        for i in 1...5 {
            await logManager.info("Entry \(i)", category: "MultiTest")
        }
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = logContent.components(separatedBy: .newlines)
        XCTAssertEqual(lines.count, 5)
    }
    
    // Test logging with different categories.
    func testDifferentCategories() async throws {
        let categories = ["System", "Auth", "Network"]
        for category in categories {
            await logManager.info("Message for \(category)", category: category)
        }
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(logContent.contains("System"))
        XCTAssertTrue(logContent.contains("Auth"))
        XCTAssertTrue(logContent.contains("Network"))
    }
    
    // Test logging an empty message.
    func testEmptyMessage() async throws {
        await logManager.info("", category: "EmptyTest")
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(logContent.contains("\"message\":\"\""))
    }
    
    // Test logging a very long message.
    func testLongMessage() async throws {
        let longMessage = String(repeating: "A", count: 10_000)
        await logManager.info(longMessage, category: "LongTest")
        
        let logContent = try String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(logContent.contains(longMessage))
    }

    // Test that the log file name has the correct format.
    func testFilenameFormat() {
        let filename = logFileURL.lastPathComponent
        // Example format: media-muncher-YYYY-MM-DD_HH-mm-ss-pid.log
        let pattern = #"^media-muncher-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}-\d+\.log$"#
        XCTAssertNotNil(filename.range(of: pattern, options: .regularExpression))
    }
}
 