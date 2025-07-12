import XCTest
@testable import Media_Muncher

final class RecalculationIsolationTest: XCTestCase {
    
    func testRecalculationDoesNotChangeFileList() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destA = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destB = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destA, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destB, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
            try? fileManager.removeItem(at: destA)
            try? fileManager.removeItem(at: destB)
        }
        
        // Create a single test file
        let testFile = tempDir.appendingPathComponent("test.jpg")
        fileManager.createFile(atPath: testFile.path, contents: Data([0x42]))
        
        let processor = FileProcessorService()
        let settings = SettingsStore()
        
        // Initial scan
        let initialFiles = await processor.processFiles(
            from: tempDir,
            destinationURL: destA,
            settings: settings
        )
        
        XCTAssertEqual(initialFiles.count, 1, "Initial scan should find 1 file")
        XCTAssertEqual(initialFiles.first?.sourceName, "test.jpg")
        
        // Recalculate for different destination
        let recalculatedFiles = await processor.recalculateFileStatuses(
            for: initialFiles,
            destinationURL: destB,
            settings: settings
        )
        
        // The recalculation should return the same files, just with updated statuses
        XCTAssertEqual(recalculatedFiles.count, 1, "Recalculation should return exactly 1 file, but got: \(recalculatedFiles.map { $0.sourceName })")
        XCTAssertEqual(recalculatedFiles.first?.sourceName, "test.jpg")
        XCTAssertEqual(recalculatedFiles.first?.sourcePath, initialFiles.first?.sourcePath)
    }
}