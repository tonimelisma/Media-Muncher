import XCTest
@testable import Media_Muncher

// MARK: - ImportServiceIntegrationTests

final class ImportServiceIntegrationTests: XCTestCase {

    var sourceURL: URL!
    var destinationURL: URL!
    var fileManager: FileManager!
    var settings: SettingsStore!
    var importService: ImportService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        settings = SettingsStore()
        importService = ImportService()

        // Create unique temporary source and destination directories for each test
        sourceURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destinationURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: sourceURL)
        try? fileManager.removeItem(at: destinationURL)
        sourceURL = nil
        destinationURL = nil
        fileManager = nil
        settings = nil
        importService = nil
        try super.tearDownWithError()
    }
    
    private func createTestVolume(withFiles fileNames: [String]) throws -> URL {
        let volumeURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: volumeURL, withIntermediateDirectories: true)

        for fileName in fileNames {
            guard let fixtureURL = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: nil) else {
                throw TestError.fixtureNotFound(name: fileName)
            }
            try fileManager.copyItem(at: fixtureURL, to: volumeURL.appendingPathComponent(fileName))
        }
        return volumeURL
    }

    private func collectStreamResults(for stream: AsyncThrowingStream<File, Error>) async throws -> [File] {
        var results: [File] = []
        for try await file in stream {
            if let index = results.firstIndex(where: { $0.id == file.id }) {
                results[index] = file
            } else {
                results.append(file)
            }
        }
        return results
    }

    // Helper to copy a fixture from the test bundle into the temporary source directory
    private func setupSourceFile(named fileName: String, in subfolder: String? = nil) throws -> URL {
        // Ensure the Fixtures directory exists in the test bundle.
        // This requires configuring the "Copy Bundle Resources" build phase for the test target.
        guard let fixtureURL = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: nil) else {
            throw TestError.fixtureNotFound(name: fileName)
        }

        var finalSourceURL = sourceURL!
        if let subfolder = subfolder {
            finalSourceURL = sourceURL.appendingPathComponent(subfolder)
            try fileManager.createDirectory(at: finalSourceURL, withIntermediateDirectories: true)
        }
        
        let destinationInSource = finalSourceURL.appendingPathComponent(fileName)
        try fileManager.copyItem(at: fixtureURL, to: destinationInSource)
        return destinationInSource
    }

    private func processFiles(from volume: URL) async -> [File] {
        let processor = FileProcessorService()
        let processedFiles = await processor.processFiles(
            from: volume,
            destinationURL: destinationURL,
            settings: settings
        )
        return processedFiles
    }

    func testImport_withRenameAndOrganize_createsCorrectPath() async throws {
        // Arrange
        settings.renameByDate = true
        settings.organizeByDate = true
        settings.settingDeleteOriginals = false

        let sourceURL = try createTestVolume(withFiles: ["exif_image.jpg"])
        let processedFiles = await processFiles(from: sourceURL)
        
        // Act
        let stream = await importService.importFiles(files: processedFiles, to: destinationURL, settings: settings)
        let results = try await collectStreamResults(for: stream)

        // Assert
        let finalPath = results.first?.destPath
        // The date extracted should be 2025:06:12 16:48:36 from the fixture's metadata.
        let expectedPath = destinationURL.appendingPathComponent("2025/06/20250612_164836.jpg").path
        XCTAssertEqual(finalPath, expectedPath)
    }

    func testImport_withDeleteOriginals_removesSourceFile() async throws {
        // Arrange
        settings.renameByDate = false
        settings.organizeByDate = false
        settings.settingDeleteOriginals = true

        let sourceURL = try createTestVolume(withFiles: ["no_exif_image.heic"])
        let originalSourcePath = sourceURL.appendingPathComponent("no_exif_image.heic").path
        let processedFiles = await processFiles(from: sourceURL)

        // Act
        let stream = await importService.importFiles(files: processedFiles, to: destinationURL, settings: settings)
        _ = try await collectStreamResults(for: stream)

        // Assert
        XCTAssertFalse(fileManager.fileExists(atPath: originalSourcePath), "Source file should have been deleted")
    }
}

enum TestError: Error, LocalizedError {
    case fixtureNotFound(name: String)
    var errorDescription: String? {
        switch self {
        case .fixtureNotFound(let name):
            return "Test fixture '\(name)' not found. Ensure it's added to the 'Media MuncherTests' target and its 'Copy Bundle Resources' build phase."
        }
    }
} 