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
        
        // Use isolated UserDefaults for test
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        settings = SettingsStore(userDefaults: testDefaults)
        processor = FileProcessorService.testInstance()
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
        
        let initialFiles = await processor.processFiles(from: sourceDir, destinationURL: destinationA, settings: settings)
        
        // Act
        let recalculatedFiles = await processor.recalculateFileStatuses(
            for: initialFiles,
            destinationURL: destinationB,
            settings: settings
        )
        
        // Assert
        XCTAssertEqual(recalculatedFiles.first?.sidecarPaths, initialFiles.first?.sidecarPaths)
    }

    func testRecalculateFileStatuses_changesPreExistingToWaiting() async throws {
        // Create a File object with .pre_existing status (like the other tests do)
        let file = File(sourcePath: sourceDir.appendingPathComponent("image.jpg").path, mediaType: .image, status: .pre_existing)
        
        // Act - recalculate for destination B
        let recalculatedFiles = await processor.recalculateFileStatuses(
            for: [file],
            destinationURL: destinationB,
            settings: settings
        )
        
        // Assert
        guard let recalculatedFile = recalculatedFiles.first else {
            XCTFail("No files returned from recalculation")
            return
        }
        
        // Pre-existing file should become waiting when recalculated for new destination
        XCTAssertEqual(recalculatedFile.status, .waiting, "Pre-existing file should become waiting")
    }
    
    func testCompleteFileProcessingPipeline_PreExistingDetectionAndRecalculation() async throws {
        // This comprehensive test validates the entire file processing pipeline:
        // 1. Initial file processing with pre-existing detection using isSameFile heuristics
        // 2. Recalculation when destination changes
        // 3. Multiple file scenarios and edge cases
        
        // Configure settings for predictable behavior (no date organization/renaming)
        settings.organizeByDate = false
        settings.renameByDate = false
        
        // === Scenario 1: Identical file (should be detected as pre-existing) ===
        let identicalContent = Data(repeating: 0x42, count: 1500)
        let sourceFile1 = sourceDir.appendingPathComponent("identical.jpg")
        fileManager.createFile(atPath: sourceFile1.path, contents: identicalContent)
        
        // Create identical file in destination A
        let destFile1 = destinationA.appendingPathComponent("identical.jpg")
        try fileManager.copyItem(at: sourceFile1, to: destFile1)
        
        // === Scenario 2: Different content, same name (should be waiting with collision resolution) ===
        let differentContent = Data(repeating: 0x7F, count: 2000)
        let sourceFile2 = sourceDir.appendingPathComponent("different.jpg")
        fileManager.createFile(atPath: sourceFile2.path, contents: differentContent)
        
        // Create different file with same name in destination A
        let destFile2 = destinationA.appendingPathComponent("different.jpg")
        let originalContent = Data(repeating: 0x11, count: 1000)
        fileManager.createFile(atPath: destFile2.path, contents: originalContent)
        
        // === Scenario 3: Same content, different timestamps (should trigger SHA-256 comparison) ===
        let sameContentFile = sourceDir.appendingPathComponent("timestamp_test.jpg")
        fileManager.createFile(atPath: sameContentFile.path, contents: identicalContent)
        
        // Create file with same content but modify timestamp
        let destFile3 = destinationA.appendingPathComponent("timestamp_test.jpg")
        try fileManager.copyItem(at: sameContentFile, to: destFile3)
        
        // Modify the destination file's timestamp to be significantly different
        let futureDate = Date().addingTimeInterval(3600) // 1 hour in the future
        try fileManager.setAttributes([.modificationDate: futureDate], ofItemAtPath: destFile3.path)
        
        // === Scenario 4: File that will have filename collision ===
        let collisionFile = sourceDir.appendingPathComponent("collision.jpg")
        fileManager.createFile(atPath: collisionFile.path, contents: Data(repeating: 0x99, count: 800))
        
        // Create different file with same name in destination A
        let destCollisionFile = destinationA.appendingPathComponent("collision.jpg")
        fileManager.createFile(atPath: destCollisionFile.path, contents: Data(repeating: 0xAA, count: 900))
        
        // === PHASE 1: Initial Processing (Test pre-existing detection) ===
        let initialFiles = await processor.processFiles(from: sourceDir, destinationURL: destinationA, settings: settings)
        
        // Verify we processed all source files
        XCTAssertEqual(initialFiles.count, 4, "Should process all 4 source files")
        
        // Find each file by source name
        let identicalFile = initialFiles.first { $0.sourceName == "identical.jpg" }
        let differentFile = initialFiles.first { $0.sourceName == "different.jpg" }
        let timestampFile = initialFiles.first { $0.sourceName == "timestamp_test.jpg" }
        let collisionFileResult = initialFiles.first { $0.sourceName == "collision.jpg" }
        
        XCTAssertNotNil(identicalFile, "Should find identical.jpg in results")
        XCTAssertNotNil(differentFile, "Should find different.jpg in results")
        XCTAssertNotNil(timestampFile, "Should find timestamp_test.jpg in results")
        XCTAssertNotNil(collisionFileResult, "Should find collision.jpg in results")
        
        // === Test isSameFile heuristics ===
        
        // Scenario 1: Identical files should be detected as pre-existing
        XCTAssertEqual(identicalFile!.status, .pre_existing, 
                      "Identical file should be detected as pre-existing via size + filename match")
        XCTAssertEqual(identicalFile!.destPath, destFile1.path, 
                      "Pre-existing file should have correct destination path")
        
        // Scenario 2: Different content files should be waiting with collision suffix
        XCTAssertEqual(differentFile!.status, .waiting, 
                      "Different file should be waiting due to content difference")
        XCTAssertTrue(differentFile!.destPath!.contains("different_1.jpg") || 
                     differentFile!.destPath!.contains("different") && differentFile!.destPath! != destFile2.path,
                     "Different file should have collision suffix or different path")
        
        // Scenario 3: Same content with different timestamp should be pre-existing (SHA-256 match)
        XCTAssertEqual(timestampFile!.status, .pre_existing, 
                      "File with same content but different timestamp should be pre-existing via SHA-256 comparison")
        
        // Scenario 4: Collision file should be waiting with suffix
        XCTAssertEqual(collisionFileResult!.status, .waiting, 
                      "Collision file should be waiting with collision resolution")
        XCTAssertTrue(collisionFileResult!.destPath!.contains("collision_1.jpg") || 
                     collisionFileResult!.destPath!.contains("collision") && collisionFileResult!.destPath! != destCollisionFile.path,
                     "Collision file should have suffix to avoid overwriting different file")
        
        // === PHASE 2: Recalculation (Test status transitions) ===
        let recalculatedFiles = await processor.recalculateFileStatuses(
            for: initialFiles,
            destinationURL: destinationB, // destinationB has no pre-existing files
            settings: settings
        )
        
        XCTAssertEqual(recalculatedFiles.count, 4, "Should recalculate all files")
        
        // Find recalculated files
        let recalcIdentical = recalculatedFiles.first { $0.sourceName == "identical.jpg" }
        let recalcDifferent = recalculatedFiles.first { $0.sourceName == "different.jpg" }
        let recalcTimestamp = recalculatedFiles.first { $0.sourceName == "timestamp_test.jpg" }
        let recalcCollision = recalculatedFiles.first { $0.sourceName == "collision.jpg" }
        
        // All files should now be .waiting since destinationB has no pre-existing files
        XCTAssertEqual(recalcIdentical!.status, .waiting, 
                      "Previously pre-existing file should become waiting in new destination")
        XCTAssertEqual(recalcDifferent!.status, .waiting, 
                      "Different file should remain waiting")
        XCTAssertEqual(recalcTimestamp!.status, .waiting, 
                      "Previously pre-existing timestamp file should become waiting")
        XCTAssertEqual(recalcCollision!.status, .waiting, 
                      "Collision file should remain waiting")
        
        // All files should have destination paths pointing to destinationB
        XCTAssertTrue(recalcIdentical!.destPath!.hasPrefix(destinationB.path), 
                     "Recalculated file should have destinationB path")
        XCTAssertTrue(recalcDifferent!.destPath!.hasPrefix(destinationB.path), 
                     "Recalculated file should have destinationB path")
        XCTAssertTrue(recalcTimestamp!.destPath!.hasPrefix(destinationB.path), 
                     "Recalculated file should have destinationB path")
        XCTAssertTrue(recalcCollision!.destPath!.hasPrefix(destinationB.path), 
                     "Recalculated file should have destinationB path")
        
        // === PHASE 3: Test recalculation back to original destination ===
        let revertedFiles = await processor.recalculateFileStatuses(
            for: recalculatedFiles,
            destinationURL: destinationA, // Back to original destination
            settings: settings
        )
        
        // Find reverted files
        let revertIdentical = revertedFiles.first { $0.sourceName == "identical.jpg" }
        let revertTimestamp = revertedFiles.first { $0.sourceName == "timestamp_test.jpg" }
        
        // Files that were originally pre-existing should be detected as pre-existing again
        XCTAssertEqual(revertIdentical!.status, .pre_existing, 
                      "File should be detected as pre-existing again when recalculated back to original destination")
        XCTAssertEqual(revertTimestamp!.status, .pre_existing, 
                      "Timestamp test file should be pre-existing again via SHA-256")
        
        // === Verify metadata preservation throughout pipeline ===
        for file in recalculatedFiles {
            XCTAssertNotNil(file.date, "File date should be preserved through recalculation")
            XCTAssertNotNil(file.size, "File size should be preserved through recalculation")
            XCTAssertEqual(file.mediaType, .image, "Media type should be preserved")
        }
    }

    func testRecalculateFileStatuses_preservesDuplicateInSourceStatus() async throws {
        // Arrange - create files with pre-set duplicate status to test preservation logic
        var file1 = File(sourcePath: sourceDir.appendingPathComponent("file1.jpg").path, mediaType: .image, status: .waiting)
        var file2 = File(sourcePath: sourceDir.appendingPathComponent("file2.jpg").path, mediaType: .image, status: .duplicate_in_source)
        let initialFiles = [file1, file2]
        
        // Act - recalculate for new destination
        let recalculatedFiles = await processor.recalculateFileStatuses(
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
        let recalculatedFiles = await processor.recalculateFileStatuses(
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
        let result = await processor.recalculateFileStatuses(
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
        let recalculatedFiles = await processor.recalculateFileStatuses(
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
