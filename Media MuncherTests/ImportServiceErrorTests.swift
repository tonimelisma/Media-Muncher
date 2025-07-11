import XCTest
@testable import Media_Muncher

final class ImportServiceErrorTests: XCTestCase {
    var srcDir: URL!
    var destDir: URL!
    var fileManager: FileManager!
    var processor: FileProcessorService!
    var settings: SettingsStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        srcDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        processor = FileProcessorService()
        settings = SettingsStore()
        settings.renameByDate = false
        settings.organizeByDate = false
        settings.settingDeleteOriginals = false
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: srcDir)
        try? fileManager.removeItem(at: destDir)
        srcDir = nil
        destDir = nil
        settings = nil
        processor = nil
        fileManager = nil
        try super.tearDownWithError()
    }

    // Helper to collect stream results and ignore yielded values on error cases
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

    private func createSourceFile(named name: String, data: Data = Data([0x01,0x02])) -> URL {
        let url = srcDir.appendingPathComponent(name)
        fileManager.createFile(atPath: url.path, contents: data)
        return url
    }

    func testImport_destinationNotReachableThrows() async throws {
        // Arrange – create single file to import
        _ = createSourceFile(named: "file.heic")
        let files = await processor.processFiles(from: srcDir, destinationURL: destDir, settings: settings)
        let importSvc = ImportService(urlAccessWrapper: MockURLAccess(alwaysAllow: false))

        // Use an unwritable path (root-owned) to force isWritableFile == false
        let unreachableDest = URL(fileURLWithPath: "/root/\(UUID().uuidString)")

        // Act & Assert
        do {
            _ = try await collect(importSvc.importFiles(files: files, to: unreachableDest, settings: settings))
            XCTFail("Expected destinationNotReachable error")
        } catch let error as ImportService.ImportError {
            XCTAssertEqual(error, .destinationNotReachable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testImport_copyFailsWhenDestinationExists() async throws {
        // Arrange – create file in source
        _ = createSourceFile(named: "sample.jpg", data: Data(repeating: 0x10, count: 10))
        let files = await processor.processFiles(from: srcDir, destinationURL: destDir, settings: settings)
        guard let destPath = files.first?.destPath else {
            XCTFail("FileProcessorService did not set destPath")
            return
        }
        // Create conflicting file at destination path AFTER planning to force copy failure
        fileManager.createFile(atPath: destPath, contents: Data(repeating: 0x20, count: 20))

        let importSvc = ImportService(urlAccessWrapper: MockURLAccess(alwaysAllow: true))

        // Act
        let results = try await collect(importSvc.importFiles(files: files, to: destDir, settings: settings))
        guard let result = results.first else {
            XCTFail("No results returned")
            return
        }

        // Assert – operation should fail with copy error
        XCTAssertEqual(result.status, .failed)
        XCTAssertTrue(result.importError?.contains("Copy failed") ?? false)
    }
}

// MARK: - Helpers
private struct MockURLAccess: SecurityScopedURLAccessWrapperProtocol {
    let alwaysAllow: Bool
    func startAccessingSecurityScopedResource(for url: URL) -> Bool { alwaysAllow }
    func stopAccessingSecurityScopedResource(for url: URL) { /* no-op */ }
} 