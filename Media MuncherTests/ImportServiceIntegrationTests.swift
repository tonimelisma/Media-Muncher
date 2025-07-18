import XCTest
@testable import Media_Muncher

// MARK: - ImportServiceIntegrationTests

final class ImportServiceIntegrationTests: IntegrationTestCase {

    var importService: ImportService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        importService = ImportService()
    }

    override func tearDownWithError() throws {
        importService = nil
        try super.tearDownWithError()
    }
    
    // Inherited methods now available:
    // - createTestVolume(withFiles:) 
    // - setupSourceFile(named:in:)
    // - collectStreamResults(for:)

    private func processFiles(from volume: URL) async -> [File] {
        let processor = FileProcessorService()
        let processedFiles = await processor.processFiles(
            from: volume,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        return processedFiles
    }

    func testImport_withRenameAndOrganize_createsCorrectPath() async throws {
        // Arrange
        settingsStore.renameByDate = true
        settingsStore.organizeByDate = true
        settingsStore.settingDeleteOriginals = false
        settingsStore.setDestination(destinationURL)

        let sourceURL = try createTestVolume(withFiles: ["exif_image.jpg"])
        let processedFiles = await processFiles(from: sourceURL)
        
        // Act
        let stream = await importService.importFiles(files: processedFiles, to: destinationURL, settings: settingsStore)
        let results: [File] = try await collectStreamResults(for: stream)

        // Assert
        let finalPath = results.first?.destPath
        // The date extracted should be 2025:06:12 16:48:36 from the fixture's metadata.
        let expectedPath = destinationURL.appendingPathComponent("2025/06/20250612_164836.jpg").path
        XCTAssertEqual(finalPath, expectedPath)
    }

    func testImport_withDeleteOriginals_removesSourceFile() async throws {
        // Arrange
        settingsStore.renameByDate = false
        settingsStore.organizeByDate = false
        settingsStore.settingDeleteOriginals = true
        settingsStore.setDestination(destinationURL)

        let sourceURL = try createTestVolume(withFiles: ["no_exif_image.heic"])
        let originalSourcePath = sourceURL.appendingPathComponent("no_exif_image.heic").path
        let processedFiles = await processFiles(from: sourceURL)

        // Act
        let stream = await importService.importFiles(files: processedFiles, to: destinationURL, settings: settingsStore)
        _ = try await collectStreamResults(for: stream) as [File]

        // Assert
        XCTAssertFalse(fileManager.fileExists(atPath: originalSourcePath), "Source file should have been deleted")
    }

    func testImport_readOnlySource_deletionFailsButImportSucceeds() async throws {
        // Arrange – make a read-only source directory with a single file
        settingsStore.renameByDate = false
        settingsStore.organizeByDate = false
        settingsStore.settingDeleteOriginals = true

        // CRITICAL FIX: Set the destination URL on the settings store!
        settingsStore.setDestination(destinationURL)

        let sourceURL = try createTestVolume(withFiles: ["no_exif_image.heic"])
        let originalSourcePath = sourceURL.appendingPathComponent("no_exif_image.heic").path

        let processedFiles = await processFiles(from: sourceURL)

        // Make directory and file read-only (0555) AFTER processing
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: Int16(0o555))], ofItemAtPath: sourceURL.path)
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: Int16(0o444))], ofItemAtPath: originalSourcePath)

        // Act
        let stream = await importService.importFiles(files: processedFiles, to: destinationURL, settings: settingsStore)
        let results: [File] = try await collectStreamResults(for: stream)

        // Assert – import succeeded (status .imported) but originals remain because deletion failed
        guard !results.isEmpty else {
            XCTFail("Should have at least one result")
            return
        }
        
        guard let lastResult = results.last(where: { $0.id == processedFiles.first?.id }) else {
            XCTFail("Last result should not be nil")
            return
        }
        
        XCTAssertEqual(lastResult.status, .imported, "Expected status to be .imported, got \(lastResult.status)")
        XCTAssertTrue(fileManager.fileExists(atPath: originalSourcePath), "Original should remain on read-only volume")
        XCTAssertNotNil(lastResult.importError, "Should have an import error due to deletion failure")
    }

    func testImport_withDeleteOriginals_removesPreExistingSourceFile() async throws {
        // Arrange
        settingsStore.renameByDate = false
        settingsStore.organizeByDate = false
        settingsStore.settingDeleteOriginals = true
        settingsStore.setDestination(destinationURL)

        let sourceURL = try createTestVolume(withFiles: ["duplicate_a.jpg"])
        let originalSourcePath = sourceURL.appendingPathComponent("duplicate_a.jpg").path

        // Manually place a copy in the destination to simulate a pre-existing file
        try fileManager.copyItem(at: URL(fileURLWithPath: originalSourcePath), to: destinationURL.appendingPathComponent("duplicate_a.jpg"))

        let processedFiles = await processFiles(from: sourceURL)

        // Act
        let stream = await importService.importFiles(files: processedFiles, to: destinationURL, settings: settingsStore)
        let results: [File] = try await collectStreamResults(for: stream)

        // Assert
        XCTAssertEqual(results.first?.status, .deleted_as_duplicate, "File should be marked as deleted duplicate")
        XCTAssertFalse(fileManager.fileExists(atPath: originalSourcePath), "Source file of pre-existing duplicate should have been deleted")
    }

    func testDiagnostic_BasicPipeline() async throws {
        // Arrange
        settingsStore.renameByDate = false
        settingsStore.organizeByDate = false
        settingsStore.settingDeleteOriginals = false
        settingsStore.setDestination(destinationURL)

        let sourceURL = try createTestVolume(withFiles: ["no_exif_image.heic"])
        
        // Diagnostic info
        let diagnostics = """
        === DIAGNOSTIC TEST ===
        1. Test destinationURL: \(destinationURL.path)
        2. SettingsStore destinationURL: \(settingsStore.destinationURL?.path ?? "nil")
        3. Source URL: \(sourceURL.path)
        4. Source files exist: \(fileManager.fileExists(atPath: sourceURL.appendingPathComponent("no_exif_image.heic").path))
        5. Destination dir exists: \(fileManager.fileExists(atPath: destinationURL.path))
        6. Destination writable: \(fileManager.isWritableFile(atPath: destinationURL.path))
        """
        
        // Write to temp file for inspection
        let diagnosticFile = tempDirectory.appendingPathComponent("diagnostic.txt")
        try diagnostics.data(using: .utf8)?.write(to: diagnosticFile)
        
        let processedFiles = await processFiles(from: sourceURL)
        
        let processInfo = """
        === PROCESSED FILES INFO ===
        7. Processed files count: \(processedFiles.count)
        8. First file sourcePath: \(processedFiles.first?.sourcePath ?? "nil")
        9. First file destPath: \(processedFiles.first?.destPath ?? "nil")
        10. First file status: \(processedFiles.first?.status.rawValue ?? "nil")
        11. First file mediaType: \(processedFiles.first?.mediaType.rawValue ?? "nil")
        """
        
        let combinedDiagnostics = diagnostics + "\n" + processInfo
        try combinedDiagnostics.data(using: .utf8)?.write(to: diagnosticFile)
        
        // Act
        let stream = await importService.importFiles(files: processedFiles, to: destinationURL, settings: settingsStore)
        let results: [File] = try await collectStreamResults(for: stream)

        let resultsInfo = """
        === IMPORT RESULTS INFO ===
        12. Results count: \(results.count)
        13. First result status: \(results.first?.status.rawValue ?? "nil")
        14. First result importError: \(results.first?.importError ?? "nil")
        """
        
        let finalDiagnostics = combinedDiagnostics + "\n" + resultsInfo
        try finalDiagnostics.data(using: .utf8)?.write(to: diagnosticFile)
        
        print("Diagnostic file written to: \(diagnosticFile.path)")
        
        // Basic assertions
        XCTAssertTrue(fileManager.fileExists(atPath: diagnosticFile.path), "Should have created diagnostic file")
        XCTAssertFalse(processedFiles.isEmpty, "Should have processed at least one file")
        XCTAssertFalse(results.isEmpty, "Should have at least one result")
    }

    func testMinimalReadOnlyScenario() async throws {
        // Arrange
        settingsStore.renameByDate = false
        settingsStore.organizeByDate = false
        settingsStore.settingDeleteOriginals = true
        settingsStore.setDestination(destinationURL)

        let sourceURL = try createTestVolume(withFiles: ["no_exif_image.heic"])
        let originalSourcePath = sourceURL.appendingPathComponent("no_exif_image.heic").path
        
        // Verify initial state
        XCTAssertTrue(fileManager.fileExists(atPath: originalSourcePath), "Source file should exist initially")
        
        let processedFiles = await processFiles(from: sourceURL)
        
        // Verify processed files
        XCTAssertFalse(processedFiles.isEmpty, "Should have processed files")
        XCTAssertEqual(processedFiles.count, 1, "Should have exactly one processed file")
        
        let processedFile = processedFiles[0]
        XCTAssertEqual(processedFile.status, .waiting, "Processed file should be waiting")
        XCTAssertNotNil(processedFile.destPath, "Processed file should have destination path")
        
        // Make read-only AFTER processing
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: Int16(0o555))], ofItemAtPath: sourceURL.path)
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: Int16(0o444))], ofItemAtPath: originalSourcePath)
        
        // Verify read-only state
        let attrs = try fileManager.attributesOfItem(atPath: originalSourcePath)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        XCTAssertEqual(perms, 0o444, "File should be read-only")
        
        // Act
        let stream = await importService.importFiles(files: processedFiles, to: destinationURL, settings: settingsStore)
        let results: [File] = try await collectStreamResults(for: stream)

        // Verify results
        XCTAssertFalse(results.isEmpty, "Should have results")
        XCTAssertEqual(results.count, 1, "Should have exactly one result")
        
        let result = results[0]
        XCTAssertEqual(result.status, .imported, "Should be imported, got: \(result.status)")
        XCTAssertNotNil(result.importError, "Should have import error about deletion failure")
        XCTAssertTrue(fileManager.fileExists(atPath: originalSourcePath), "Source should remain")
        
        // Verify destination file was created
        if let destPath = result.destPath {
            XCTAssertTrue(fileManager.fileExists(atPath: destPath), "Destination file should exist")
        }
    }
    
    private func canDeleteFile(at path: String) -> Bool {
        let testPath = path + ".deletetest"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try fileManager.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
    }
}

// TestError now defined in IntegrationTestCase 