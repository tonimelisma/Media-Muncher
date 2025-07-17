import XCTest
@testable import Media_Muncher

// MARK: - Test helper extension

extension LogManager {
    /// Writes an entry and awaits its completion (used only in unit tests)
    func writeSync(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]? = nil) async {
        await withCheckedContinuation { cont in
            self.write(level: level, category: category, message: message, metadata: metadata) {
                cont.resume()
            }
        }
    }
}

class LogManagerTests: XCTestCase {
    
    var logManager: LogManager!
    var logFileURL: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create a new instance for each test
        logManager = LogManager()
        logFileURL = logManager.logFileURL
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: logFileURL)
        try super.tearDownWithError()
    }
    
    func testNoMalformedJSONAfterConcurrentWrites() async {
        // Given
        let concurrentLogCount = 100

        // Capture baseline line count before new writes
        let baselineCount = logManager.getLogFileContents()?
            .split(separator: "\n")
            .filter { !$0.isEmpty }
            .count ?? 0

        // When – launch concurrent tasks that await write completion
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentLogCount {
                group.addTask {
                    let metadata = ["index": "\(i)"]
                    await self.logManager.writeSync(level: .info, category: "NoMalformedJSONTest", message: "Concurrent message \(i)", metadata: metadata)
                }
            }
        }

        // All writes finished – safe to read file

        // Then
        let logContent = logManager.getLogFileContents()
        XCTAssertNotNil(logContent)

        let lines = logContent?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        XCTAssertEqual(lines.count - baselineCount, concurrentLogCount, "Exactly the new entries should have been added")

        var decodedCount = 0
        for (i, line) in lines.enumerated() {
            guard let data = line.data(using: .utf8) else {
                XCTFail("Line \(i) is not valid UTF-8: \(line)")
                continue
            }

            do {
                _ = try JSONDecoder().decode(LogEntry.self, from: data)
                decodedCount += 1
            } catch {
                XCTFail("Failed to decode line \(i) as JSON: \(error) - Content: \(line)")
            }
        }

        XCTAssertEqual(decodedCount, concurrentLogCount, "All lines should be valid JSON LogEntry objects")
    }
    
    // MARK: - Basic Functionality Tests
    
    func testLogManagerWritesToFile() {
        // Given
        let expectation = XCTestExpectation(description: "Log write completes")
        let message = "Test message \(UUID())"
        
        // When
        logManager.info(message, category: "Test") {
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
        
        let debugMessage = "Debug message"
        let infoMessage = "Info message"
        let errorMessage = "Error message"
        
        // When
        logManager.debug(debugMessage, category: "Test") {
            expectations[0].fulfill()
        }
        logManager.info(infoMessage, category: "Test") {
            expectations[1].fulfill()
        }
        logManager.error(errorMessage, category: "Test") {
            expectations[2].fulfill()
        }
        
        wait(for: expectations, timeout: 2.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
        XCTAssertNotNil(logContent)

        let lines = logContent?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        XCTAssertEqual(lines.count, 3, "Should have three log entries")

        XCTAssertTrue(logContent?.contains(debugMessage) ?? false)
        XCTAssertTrue(logContent?.contains(infoMessage) ?? false)
        XCTAssertTrue(logContent?.contains(errorMessage) ?? false)
    }
    
    // MARK: - Metadata Tests
    
    func testLogWithMetadata() {
        // Given
        let expectation = XCTestExpectation(description: "Log with metadata completes")
        let message = "Test with metadata"
        let metadata = ["key1": "value1", "key2": "value2"]
        
        // When
        logManager.info(message, category: "MetadataTest", metadata: metadata) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
        XCTAssertNotNil(logContent)
        XCTAssertTrue(logContent?.contains("value1") ?? false)
        XCTAssertTrue(logContent?.contains("value2") ?? false)
    }

    // MARK: - Additional tests continue as before but using instance instead of static methods
    
    func testLogWithNilMetadata() {
        // Given
        let expectation = XCTestExpectation(description: "Log with nil metadata completes")
        let message = "Test with nil metadata"
        
        // When
        logManager.info(message, category: "NilMetadataTest", metadata: nil) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
        XCTAssertNotNil(logContent)
        XCTAssertTrue(logContent?.contains(message) ?? false)
    }

    func testJSONStructure() {
        // Given
        let expectation = XCTestExpectation(description: "JSON log completes")
        let message = "JSON structure test"
        let metadata = ["testKey": "testValue"]
        
        // When
        logManager.info(message, category: "JSONTest", metadata: metadata) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
        XCTAssertNotNil(logContent)
        
        guard let data = logContent?.data(using: .utf8) else {
            XCTFail("Could not convert log content to data")
            return
        }
        
        do {
            let logEntry = try JSONDecoder().decode(LogEntry.self, from: data)
            XCTAssertEqual(logEntry.message, message)
            XCTAssertEqual(logEntry.category, "JSONTest")
            XCTAssertEqual(logEntry.level, .info)
            XCTAssertEqual(logEntry.metadata?["testKey"], "testValue")
        } catch {
            XCTFail("Failed to decode JSON: \(error)")
        }
    }

    // MARK: - Filename Format Tests
    
    func testFilenameFormat() {
        // Given
        let filename = logManager.logFileURL.lastPathComponent
        
        // Then
        XCTAssertTrue(filename.hasPrefix("media-muncher-"), "Filename should start with 'media-muncher-'")
        XCTAssertTrue(filename.hasSuffix(".log"), "Filename should end with '.log'")
        
        // Extract timestamp part (remove prefix and suffix)
        let timestampPart = String(filename.dropFirst("media-muncher-".count).dropLast(".log".count))
        
        // Validate format: YYYY-MM-DD_HH-mm-ss-<pid>
        let pattern = "^\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2}-\\d+$"
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
                self.logManager.info("Concurrent message \(i)", category: "ConcurrentTest") {
                    expectations[i].fulfill()
                }
            }
        }
        
        wait(for: expectations, timeout: 10.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
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
            logManager.info("Entry \(i)", category: "MultiTest") {
                expectations[i].fulfill()
            }
        }
        
        wait(for: expectations, timeout: 5.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
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
            logManager.info("Message for \(category)", category: category) {
                expectations[index].fulfill()
            }
        }
        
        wait(for: expectations, timeout: 3.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
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
        logManager.info("", category: "EmptyTest") {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
        XCTAssertNotNil(logContent)
        XCTAssertTrue(logContent?.contains("EmptyTest") ?? false)
    }
    
    func testLongMessage() {
        // Given
        let expectation = XCTestExpectation(description: "Long message log completes")
        let longMessage = String(repeating: "A", count: 1000)
        
        // When
        logManager.info(longMessage, category: "LongTest") {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        let logContent = logManager.getLogFileContents()
        XCTAssertNotNil(logContent)
        XCTAssertTrue(logContent?.contains(longMessage) ?? false)
    }
}
 