import XCTest
@testable import Media_Muncher

final class DirectFileProcessorTest: XCTestCase {
    
    func testDirectFileProcessorScan() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Create a single test file
        let testFile = tempDir.appendingPathComponent("test.jpg")
        fileManager.createFile(atPath: testFile.path, contents: Data([0x42]))
        
        // Verify directory contents
        let contents = try fileManager.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertEqual(contents, ["test.jpg"], "Directory should only contain test.jpg")
        
        // Directly call FileProcessorService
        let processor = FileProcessorService.testInstance()
        let settings = SettingsStore()
        
        let files = await processor.processFiles(
            from: tempDir,
            destinationURL: nil,
            settings: settings
        )
        
        // This should find exactly 1 file
        XCTAssertEqual(files.count, 1, "Should find exactly 1 file, but found: \(files.map { $0.sourceName })")
        XCTAssertEqual(files.first?.sourceName, "test.jpg", "Should find test.jpg")
    }
}
