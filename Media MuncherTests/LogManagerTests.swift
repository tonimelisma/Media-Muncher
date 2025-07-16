import XCTest
@testable import Media_Muncher

class LogManagerTests: XCTestCase {
    
    private var originalLogFileURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Store the original log file URL for cleanup
        originalLogFileURL = LogManager.shared.logFileURL
    }
    
    override func tearDownWithError() throws {
        // Clean up any test log files
        try? FileManager.default.removeItem(at: originalLogFileURL)
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Functionality Tests
    
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
    
    // MARK: - Log Level Tests
    
    func testAllLogLevels() {
        // Given
        let expectations = [
            XCTestExpectation(description: "Debug log completes"),
            XCTestExpectation(description: "Info log completes"),
            XCTestExpectation(description: "Error log completes")
        ]
        
        let debugMessage = "Debug message \(UUID())"
        let infoMessage = "Info message \(UUID())"
        let errorMessage = "Error message \(UUID())"
        
        // When
        LogManager.debug(debugMessage, category: "Test") {
            expectations[0].fulfill()
        }
        
        LogManager.info(infoMessage, category: "Test") {
            expectations[1].fulfill()
        }
        
        LogManager.error(errorMessage, category: "Test") {
            expectations[2].fulfill()
        }
        
        wait(for: expectations, timeout: 3.0)
        
        // Then
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent)
        XCTAssertTrue(logContent?.contains(debugMessage) ?? false)
        XCTAssertTrue(logContent?.contains(infoMessage) ?? false)
        XCTAssertTrue(logContent?.contains(errorMessage) ?? false)
    }
    
    // MARK: - Metadata Tests
    
    func testMetadataHandling() {
        // Given
        let expectation = XCTestExpectation(description: "Metadata log completes")
        let uniqueMarker = "METADATA_TEST_\(UUID().uuidString)"
        let message = "Test with metadata - \(uniqueMarker)"
        let metadata = [
            "key1": "value1",
            "key2": "value2", 
            "special": "special/chars:and spaces",
            "uniqueMarker": uniqueMarker
        ]
        
        // When
        LogManager.info(message, category: "MetadataTest", metadata: metadata) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent, "Log file should not be empty")
        
        // Use unique marker to find our specific log entry
        guard logContent?.contains(uniqueMarker) == true else {
            XCTFail("Could not find test entry with unique marker: \(uniqueMarker)")
            return
        }
        
        // Verify the entry contains our metadata
        XCTAssertTrue(logContent?.contains("key1") ?? false, "Should contain key1")
        XCTAssertTrue(logContent?.contains("value1") ?? false, "Should contain value1")
        XCTAssertTrue(logContent?.contains("key2") ?? false, "Should contain key2")
        XCTAssertTrue(logContent?.contains("value2") ?? false, "Should contain value2")
        XCTAssertTrue(logContent?.contains("special/chars:and spaces") ?? false, "Should contain special characters")
        
        // Verify JSON structure by parsing the specific line
        let lines = logContent?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        let ourLine = lines.first { $0.contains(uniqueMarker) }
        XCTAssertNotNil(ourLine, "Should find our specific log line")
        
        if let line = ourLine {
            do {
                let jsonData = line.data(using: .utf8)!
                let logEntry = try JSONDecoder().decode(LogEntry.self, from: jsonData)
                XCTAssertEqual(logEntry.category, "MetadataTest")
                XCTAssertTrue(logEntry.message.contains(uniqueMarker))
                XCTAssertNotNil(logEntry.metadata)
                XCTAssertEqual(logEntry.metadata?["uniqueMarker"], uniqueMarker)
                XCTAssertEqual(logEntry.metadata?["key1"], "value1")
                XCTAssertEqual(logEntry.metadata?["key2"], "value2")
                XCTAssertEqual(logEntry.metadata?["special"], "special/chars:and spaces")
            } catch {
                XCTFail("Failed to decode our log entry as JSON: \(error)")
            }
        }
    }
    
    func testNilMetadata() {
        // Given
        let expectation = XCTestExpectation(description: "Nil metadata log completes")
        let message = "Test with nil metadata"
        
        // When
        LogManager.info(message, category: "NilMetadataTest", metadata: nil) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent)
        XCTAssertTrue(logContent?.contains(message) ?? false)
    }
    
    // MARK: - JSON Format Tests
    
    func testJSONFormatValidation() {
        // Given
        let expectation = XCTestExpectation(description: "JSON format log completes")
        let message = "JSON format test"
        let metadata = ["testKey": "testValue"]
        
        // When
        LogManager.info(message, category: "JSONTest", metadata: metadata) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent)
        
        // Validate JSON structure
        let lines = logContent?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        XCTAssertGreaterThan(lines.count, 0, "Should have at least one log entry")
        
        for line in lines {
            let jsonData = line.data(using: .utf8)!
            do {
                let logEntry = try JSONDecoder().decode(LogEntry.self, from: jsonData)
                XCTAssertNotNil(logEntry.id)
                XCTAssertNotNil(logEntry.timestamp)
                XCTAssertFalse(logEntry.category.isEmpty)
                XCTAssertFalse(logEntry.message.isEmpty)
            } catch {
                XCTFail("Failed to decode JSON log entry: \(error)")
            }
        }
    }
    
    // MARK: - Filename Format Tests
    
    func testFilenameFormat() {
        // Given
        let logManager = LogManager.shared
        let filename = logManager.logFileURL.lastPathComponent
        
        // Then
        XCTAssertTrue(filename.hasPrefix("media-muncher-"), "Filename should start with 'media-muncher-'")
        XCTAssertTrue(filename.hasSuffix(".log"), "Filename should end with '.log'")
        
        // Extract timestamp part (remove prefix and suffix)
        let timestampPart = String(filename.dropFirst("media-muncher-".count).dropLast(".log".count))
        
        // Validate format: YYYY-MM-DD_HH-mm-ss
        let pattern = "^\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2}$"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.numberOfMatches(in: timestampPart, range: NSRange(timestampPart.startIndex..., in: timestampPart))
        
        XCTAssertEqual(matches, 1, "Timestamp should match format YYYY-MM-DD_HH-mm-ss, got: \(timestampPart)")
        
        // Ensure no problematic characters
        let problematicChars = CharacterSet(charactersIn: "/: ,")
        XCTAssertTrue(timestampPart.rangeOfCharacter(from: problematicChars) == nil, 
                     "Timestamp should not contain problematic filesystem characters")
    }
    
    // MARK: - Concurrent Logging Tests
    
    func testConcurrentLogging() {
        // Given
        let concurrentLogCount = 50
        let expectations = (0..<concurrentLogCount).map { i in
            XCTestExpectation(description: "Concurrent log \(i) completes")
        }
        
        // When - Log from multiple queues simultaneously
        for i in 0..<concurrentLogCount {
            DispatchQueue.global(qos: .background).async {
                LogManager.info("Concurrent message \(i)", category: "ConcurrentTest") {
                    expectations[i].fulfill()
                }
            }
        }
        
        wait(for: expectations, timeout: 10.0)
        
        // Then
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent)
        
        let lines = logContent?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        let concurrentMessages = lines.filter { $0.contains("Concurrent message") }
        
        XCTAssertEqual(concurrentMessages.count, concurrentLogCount, 
                      "Should have logged all concurrent messages")
        
        // Verify all messages are present
        for i in 0..<concurrentLogCount {
            XCTAssertTrue(logContent?.contains("Concurrent message \(i)") ?? false,
                         "Should contain message \(i)")
        }
    }
    
    // MARK: - Multiple Entry Tests
    
    func testMultipleLogEntries() {
        // Given
        let entryCount = 10
        let expectations = (0..<entryCount).map { i in
            XCTestExpectation(description: "Entry \(i) completes")
        }
        
        // When
        for i in 0..<entryCount {
            LogManager.info("Entry \(i)", category: "MultiTest") {
                expectations[i].fulfill()
            }
        }
        
        wait(for: expectations, timeout: 5.0)
        
        // Then
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent)
        
        let lines = logContent?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        let entryLines = lines.filter { $0.contains("Entry") && $0.contains("MultiTest") }
        
        XCTAssertEqual(entryLines.count, entryCount, "Should have \(entryCount) entries")
    }
    
    // MARK: - Category Tests
    
    func testDifferentCategories() {
        // Given
        let categories = ["Category1", "Category2", "Special-Category_123"]
        let expectations = categories.map { category in
            XCTestExpectation(description: "Category \(category) completes")
        }
        
        // When
        for (index, category) in categories.enumerated() {
            LogManager.info("Message for \(category)", category: category) {
                expectations[index].fulfill()
            }
        }
        
        wait(for: expectations, timeout: 3.0)
        
        // Then
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent)
        
        for category in categories {
            XCTAssertTrue(logContent?.contains(category) ?? false,
                         "Should contain category: \(category)")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyMessage() {
        // Given
        let expectation = XCTestExpectation(description: "Empty message log completes")
        
        // When
        LogManager.info("", category: "EmptyTest") {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent)
        XCTAssertTrue(logContent?.contains("EmptyTest") ?? false)
    }
    
    func testLongMessage() {
        // Given
        let expectation = XCTestExpectation(description: "Long message log completes")
        let longMessage = String(repeating: "A", count: 1000)
        
        // When
        LogManager.info(longMessage, category: "LongTest") {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = LogManager.shared.getLogFileContents()
        XCTAssertNotNil(logContent)
        XCTAssertTrue(logContent?.contains(longMessage) ?? false)
    }
}
 