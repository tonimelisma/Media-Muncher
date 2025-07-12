import XCTest
@testable import Media_Muncher

final class FileProcessorRecalculationTests: XCTestCase {
    var sourceDir: URL!
    var destinationA: URL!
    var destinationB: URL!
    var fileManager: FileManager!
    var settings: SettingsStore!
    var processor: FileProcessorService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        sourceDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destinationA = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destinationB = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationA, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationB, withIntermediateDirectories: true)
        
        settings = SettingsStore()
        processor = FileProcessorService()
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: sourceDir)
        try? fileManager.removeItem(at: destinationA)
        try? fileManager.removeItem(at: destinationB)
        try super.tearDownWithError()
    }

    private func createFile(at url: URL, content: Data = Data([0x42])) {
        fileManager.createFile(atPath: url.path, contents: content)
    }

    func testRecalculateFileStatuses_preservesSidecarPaths() async throws {
        // Arrange
        let videoFile = sourceDir.appendingPathComponent("test.mov")
        let sidecarFile = sourceDir.appendingPathComponent("test.xmp")
        createFile(at: videoFile)
        createFile(at: sidecarFile)
        
        // Get initial files with sidecars attached
        let initialFiles = await processor.processFiles(from: sourceDir, destinationURL: destinationA, settings: settings)
        guard let fileWithSidecar = initialFiles.first else {
            XCTFail("No files processed")
            return
        }
        
        XCTAssertFalse(fileWithSidecar.sidecarPaths.isEmpty, "File should have sidecar paths attached")
        let originalSidecarPaths = fileWithSidecar.sidecarPaths
        
        // Act - recalculate for new destination
        let recalculatedFiles = try await processor.recalculateFileStatuses(
            for: initialFiles,
            destinationURL: destinationB,
            settings: settings
        )
        
        // Assert
        guard let recalculatedFile = recalculatedFiles.first else {
            XCTFail("No files returned from recalculation")
            return
        }
        
        XCTAssertEqual(recalculatedFile.sidecarPaths, originalSidecarPaths, "Sidecar paths should be preserved")
        XCTAssertEqual(recalculatedFile.status, .waiting, "Status should be recalculated to waiting")
    }

    func testRecalculateFileStatuses_changesPreExistingToWaiting() async throws {
        // Arrange
        let sourceFile = sourceDir.appendingPathComponent("image.jpg")
        let sampleContent = Data(repeating: 0x42, count: 1000) // Use specific content
        fileManager.createFile(atPath: sourceFile.path, contents: sampleContent)
        
        // Create identical pre-existing file in destination A
        try fileManager.copyItem(at: sourceFile, to: destinationA.appendingPathComponent("image.jpg"))
        
        // Get initial files (should be marked pre-existing)
        let initialFiles = await processor.processFiles(from: sourceDir, destinationURL: destinationA, settings: settings)
        guard let preExistingFile = initialFiles.first else {
            XCTFail("No files processed")
            return
        }
        XCTAssertEqual(preExistingFile.status, .pre_existing)
        
        // Act - recalculate for destination B (where file doesn't exist)
        let recalculatedFiles = try await processor.recalculateFileStatuses(
            for: initialFiles,
            destinationURL: destinationB,
            settings: settings
        )
        
        // Assert
        guard let recalculatedFile = recalculatedFiles.first else {
            XCTFail("No files returned from recalculation")
            return
        }
        XCTAssertEqual(recalculatedFile.status, .waiting, "Pre-existing file should become waiting in new destination")
    }

    func testRecalculateFileStatuses_preservesDuplicateInSourceStatus() async throws {
        // Arrange - create files with pre-set duplicate status to test preservation logic
        var file1 = File(sourcePath: sourceDir.appendingPathComponent("file1.jpg").path, mediaType: .image, status: .waiting)
        var file2 = File(sourcePath: sourceDir.appendingPathComponent("file2.jpg").path, mediaType: .image, status: .duplicate_in_source)
        let initialFiles = [file1, file2]
        
        // Act - recalculate for new destination
        let recalculatedFiles = try await processor.recalculateFileStatuses(
            for: initialFiles,
            destinationURL: destinationB,
            settings: settings
        )
        
        // Assert - duplicate status should be preserved
        XCTAssertEqual(recalculatedFiles.count, 2)
        let waitingFile = recalculatedFiles.first { $0.sourcePath == file1.sourcePath }
        let duplicateFile = recalculatedFiles.first { $0.sourcePath == file2.sourcePath }
        
        XCTAssertEqual(waitingFile?.status, .waiting, "Non-duplicate files should become waiting")
        XCTAssertEqual(duplicateFile?.status, .duplicate_in_source, "Duplicate status should be preserved")
    }

    func testRecalculateFileStatuses_handlesMultipleFilesWithoutCrashing() async throws {
        // Arrange - create multiple files to test recalculation handles complex scenarios
        var multipleFiles: [File] = []
        for i in 0..<10 {
            let file = File(
                sourcePath: sourceDir.appendingPathComponent("file_\(i).jpg").path,
                mediaType: .image,
                status: i % 2 == 0 ? .waiting : .pre_existing
            )
            multipleFiles.append(file)
        }
        
        // Act - recalculate shouldn't crash with multiple files
        let recalculatedFiles = try await processor.recalculateFileStatuses(
            for: multipleFiles,
            destinationURL: destinationB,
            settings: settings
        )
        
        // Assert - should handle all files without crashing
        XCTAssertEqual(recalculatedFiles.count, multipleFiles.count)
        // All non-duplicate files should become waiting after recalculation
        let nonDuplicateFiles = recalculatedFiles.filter { $0.status != .duplicate_in_source }
        XCTAssertTrue(nonDuplicateFiles.allSatisfy { $0.status == .waiting }, "Non-duplicate files should be waiting")
    }

    func testRecalculateFileStatuses_emptyInputReturnsEmpty() async throws {
        // Act
        let result = try await processor.recalculateFileStatuses(
            for: [],
            destinationURL: destinationA,
            settings: settings
        )
        
        // Assert
        XCTAssertTrue(result.isEmpty, "Empty input should return empty array")
    }

    func testRecalculateFileStatuses_nilDestinationHandledGracefully() async throws {
        // Arrange
        let sourceFile = sourceDir.appendingPathComponent("test.jpg")
        createFile(at: sourceFile)
        
        let initialFiles = await processor.processFiles(from: sourceDir, destinationURL: destinationA, settings: settings)
        
        // Act
        let recalculatedFiles = try await processor.recalculateFileStatuses(
            for: initialFiles,
            destinationURL: nil,
            settings: settings
        )
        
        // Assert
        XCTAssertEqual(recalculatedFiles.count, initialFiles.count)
        // With nil destination, files should maintain basic info but possibly no destination path
        for file in recalculatedFiles {
            XCTAssertEqual(file.sourcePath, initialFiles.first?.sourcePath)
        }
    }
}