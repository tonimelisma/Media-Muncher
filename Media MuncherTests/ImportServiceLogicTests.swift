import XCTest
@testable import Media_Muncher

final class ImportServiceLogicTests: XCTestCase {
    var srcDir: URL!
    var destDir: URL!
    var fileManager: FileManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        srcDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: srcDir)
        try? fileManager.removeItem(at: destDir)
        srcDir = nil
        destDir = nil
        try super.tearDownWithError()
    }
    
    private func copyFixture(named name: String) throws -> URL {
        guard let fixtureURL = Bundle(for: type(of: self)).url(forResource: name, withExtension: nil) else {
            XCTFail("Fixture \(name) missing from test bundle")
            throw NSError(domain: "missing_fixture", code: 0)
        }
        let dest = srcDir.appendingPathComponent(name)
        try fileManager.copyItem(at: fixtureURL, to: dest)
        return dest
    }
    
    private func collect(_ stream: AsyncThrowingStream<File, Error>) async throws -> [File] {
        var items: [File] = []
        for try await f in stream {
            if let idx = items.firstIndex(where: { $0.id == f.id }) {
                items[idx] = f
            } else {
                items.append(f)
            }
        }
        return items
    }
    
    // MARK: - Tests
    func testImport_copiesFileSuccessfully() async throws {
        // Arrange
        _ = try copyFixture(named: "no_exif_image.heic")
        let processor = FileProcessorService()
        var settings = SettingsStore()
        settings.renameByDate = false
        settings.organizeByDate = false
        settings.settingDeleteOriginals = false
        let files = await processor.processFiles(from: srcDir, destinationURL: destDir, settings: settings)
        let importSvc = ImportService(urlAccessWrapper: MockURLAccess(alwaysAllow: true))
        
        // Act
        let results = try await collect(importSvc.importFiles(files: files, to: destDir, settings: settings))
        guard let destPath = files.first?.destPath else {
            XCTFail("Destination path not set by FileProcessorService")
            return
        }
        // Assert
        XCTAssertTrue(results.contains { $0.status == .imported })
        XCTAssertTrue(fileManager.fileExists(atPath: destPath))
    }
    
    func testImport_withDeleteOriginals_removesSource() async throws {
        // Arrange
        let sourceFile = try copyFixture(named: "no_exif_image.heic")
        let processor = FileProcessorService()
        var settings = SettingsStore()
        settings.renameByDate = false
        settings.organizeByDate = false
        settings.settingDeleteOriginals = true
        let files = await processor.processFiles(from: srcDir, destinationURL: destDir, settings: settings)
        let importSvc = ImportService(urlAccessWrapper: MockURLAccess(alwaysAllow: true))
        
        // Act
        _ = try await collect(importSvc.importFiles(files: files, to: destDir, settings: settings))
        
        // Assert – original removed
        XCTAssertFalse(fileManager.fileExists(atPath: sourceFile.path))
    }
}

// MARK: - Helpers
private struct MockURLAccess: SecurityScopedURLAccessWrapperProtocol {
    let alwaysAllow: Bool
    func startAccessingSecurityScopedResource(for url: URL) -> Bool { alwaysAllow }
    func stopAccessingSecurityScopedResource(for url: URL) { /* no-op */ }
} 