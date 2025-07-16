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

        let sourceURL = try createTestVolume(withFiles: ["no_exif_image.heic"])
        let originalSourcePath = sourceURL.appendingPathComponent("no_exif_image.heic").path

        // Make directory and file read-only (0555)
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: Int16(0o555))], ofItemAtPath: sourceURL.path)
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: Int16(0o444))], ofItemAtPath: originalSourcePath)

        let processedFiles = await processFiles(from: sourceURL)

        // Act
        let stream = await importService.importFiles(files: processedFiles, to: destinationURL, settings: settingsStore)
        let results: [File] = try await collectStreamResults(for: stream)

        // Assert – import succeeded (status .imported) but originals remain because deletion failed
        XCTAssertTrue(fileManager.fileExists(atPath: originalSourcePath), "Original should remain on read-only volume")
        XCTAssertNotNil(results.first?.importError)
    }

    func testImport_withDeleteOriginals_removesPreExistingSourceFile() async throws {
        // Arrange
        settingsStore.renameByDate = false
        settingsStore.organizeByDate = false
        settingsStore.settingDeleteOriginals = true

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
}

// TestError now defined in IntegrationTestCase 