import XCTest
@testable import Media_Muncher

final class ImportServiceSidecarTests: XCTestCase {
    var srcDir: URL!
    var destDir: URL!
    var fileManager: FileManager!
    var settings: SettingsStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        srcDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        // Use isolated UserDefaults for test
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        settings = SettingsStore(userDefaults: testDefaults)
        settings.renameByDate = false
        settings.organizeByDate = false
        settings.settingDeleteOriginals = true
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: srcDir)
        try? fileManager.removeItem(at: destDir)
        srcDir = nil
        destDir = nil
        settings = nil
        fileManager = nil
        try super.tearDownWithError()
    }

    private func createFile(at url: URL) {
        fileManager.createFile(atPath: url.path, contents: Data([0xAB]))
    }

    private func collect(_ stream: AsyncThrowingStream<File, Error>) async throws {
        for try await _ in stream { /* drain */ }
    }

    func testImport_deletesSidecarFiles() async throws {
        // Arrange
        let video = srcDir.appendingPathComponent("movie.mov")
        let sidecar = srcDir.appendingPathComponent("movie.xmp")
        createFile(at: video)
        createFile(at: sidecar)

        let processor = FileProcessorService()
        let files = await processor.processFiles(from: srcDir, destinationURL: destDir, settings: settings)
        
        let importSvc = ImportService(urlAccessWrapper: MockURLAccess(alwaysAllow: true))

        // Act
        try await collect(importSvc.importFiles(files: files, to: destDir, settings: settings))

        // Assert
        XCTAssertFalse(fileManager.fileExists(atPath: sidecar.path))
    }
}

// MARK: - Helpers
private struct MockURLAccess: SecurityScopedURLAccessWrapperProtocol {
    let alwaysAllow: Bool
    func startAccessingSecurityScopedResource(for url: URL) -> Bool { alwaysAllow }
    func stopAccessingSecurityScopedResource(for url: URL) { /* no-op */ }
} 