import XCTest
@testable import Media_Muncher

class ImportServiceTests: XCTestCase {

    var importService: ImportService!
    var mockFileManager: MockFileManager!
    var mockURLAccessWrapper: MockSecurityScopedURLAccessWrapper!
    var settings: SettingsStore!
    let destinationURL = URL(fileURLWithPath: "/dest")

    override func setUp() {
        super.setUp()
        mockFileManager = MockFileManager()
        mockURLAccessWrapper = MockSecurityScopedURLAccessWrapper()
        importService = ImportService(fileManager: mockFileManager, urlAccessWrapper: mockURLAccessWrapper)
        settings = SettingsStore()
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

    func testSuccessfulImport() async throws {
        // Arrange
        let sourcePath = "/source/photo.jpg"
        let destPath = "/dest/photo.jpg"
        mockFileManager.virtualFileSystem[sourcePath] = Data(count: 1234)
        let files = [File(sourcePath: sourcePath, mediaType: .image, size: 1234, destPath: destPath, status: .waiting)]

        // Act
        let stream = importService.importFiles(files: files, to: destinationURL, settings: settings)
        let results = try await collectStreamResults(for: stream)

        // Assert
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.status, .imported)
        XCTAssertEqual(mockFileManager.copiedFiles.count, 1)
        XCTAssertEqual(mockFileManager.copiedFiles.first?.destination, URL(fileURLWithPath: destPath))
        XCTAssertTrue(mockFileManager.fileExists(atPath: destPath))
        XCTAssertNil(results.first?.importError)
    }
    
    func testSuccessfulImportWithDeletion() async throws {
        // Arrange
        let sourcePath = "/source/photo.jpg"
        let destPath = "/dest/photo.jpg"
        mockFileManager.virtualFileSystem[sourcePath] = Data(count: 1234)
        let files = [File(sourcePath: sourcePath, mediaType: .image, size: 1234, destPath: destPath, status: .waiting)]
        settings.settingDeleteOriginals = true

        // Act
        let stream = importService.importFiles(files: files, to: destinationURL, settings: settings)
        _ = try await collectStreamResults(for: stream)

        // Assert
        XCTAssertFalse(mockFileManager.fileExists(atPath: sourcePath), "Source file should have been deleted")
    }

    func testCopyFailure() async throws {
        // Arrange
        let sourcePath = "/source/photo.jpg"
        let destPath = "/dest/photo.jpg"
        mockFileManager.virtualFileSystem[sourcePath] = Data(count: 1234)
        mockFileManager.failCopyForPaths = [sourcePath]
        let files = [File(sourcePath: sourcePath, mediaType: .image, size: 1234, destPath: destPath, status: .waiting)]

        // Act
        let stream = importService.importFiles(files: files, to: destinationURL, settings: settings)
        let results = try await collectStreamResults(for: stream)

        // Assert
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.status, .failed)
        XCTAssertNotNil(results.first?.importError)
        XCTAssert(results.first?.importError?.contains("Copy failed") ?? false)
        XCTAssertFalse(mockFileManager.fileExists(atPath: destPath))
    }
    
    func testVerificationFailure() async throws {
        // Arrange
        let sourcePath = "/source/photo.jpg"
        let destPath = "/dest/photo.jpg"
        mockFileManager.virtualFileSystem[sourcePath] = Data(count: 1234)
        mockFileManager.mismatchedFileSizeForPaths = [destPath: 999]
        let files = [File(sourcePath: sourcePath, mediaType: .image, size: 1234, destPath: destPath, status: .waiting)]
        
        // Act
        let stream = importService.importFiles(files: files, to: destinationURL, settings: settings)
        let results = try await collectStreamResults(for: stream)

        // Assert
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.status, .failed)
        XCTAssertNotNil(results.first?.importError)
        XCTAssert(results.first?.importError?.contains("Verification failed") ?? false)
    }
    
    func testFullBatchWithMixedResults() async throws {
        // Arrange
        let file1 = File(sourcePath: "/source/success.jpg", mediaType: .image, size: 100, destPath: "/dest/success.jpg", status: .waiting)
        let file2 = File(sourcePath: "/source/copy_fail.jpg", mediaType: .image, size: 200, destPath: "/dest/copy_fail.jpg", status: .waiting)
        let file3 = File(sourcePath: "/source/verify_fail.jpg", mediaType: .image, size: 300, destPath: "/dest/verify_fail.jpg", status: .waiting)
        mockFileManager.virtualFileSystem = [
            file1.sourcePath: Data(count: 100),
            file2.sourcePath: Data(count: 200),
            file3.sourcePath: Data(count: 300),
        ]
        
        mockFileManager.failCopyForPaths = [file2.sourcePath]
        mockFileManager.mismatchedFileSizeForPaths = [file3.destPath!: 999]

        let files = [file1, file2, file3]
        
        // Act
        let stream = importService.importFiles(files: files, to: destinationURL, settings: settings)
        let results = try await collectStreamResults(for: stream)

        // Assert
        XCTAssertEqual(results.count, 3)
        
        let successFile = results.first { $0.id == file1.id }
        XCTAssertEqual(successFile?.status, .imported)
        XCTAssert(mockFileManager.fileExists(atPath: successFile!.destPath!))

        let copyFailFile = results.first { $0.id == file2.id }
        XCTAssertEqual(copyFailFile?.status, .failed)
        XCTAssert(copyFailFile?.importError?.contains("Copy failed") ?? false)
        XCTAssertFalse(mockFileManager.fileExists(atPath: copyFailFile!.destPath!))
        
        let verifyFailFile = results.first { $0.id == file3.id }
        XCTAssertEqual(verifyFailFile?.status, .failed)
        XCTAssert(verifyFailFile?.importError?.contains("Verification failed") ?? false)
        XCTAssert(mockFileManager.fileExists(atPath: verifyFailFile!.destPath!))
    }
} 