import XCTest
@testable import Media_Muncher

class ImportServiceTests: XCTestCase {

    var importService: ImportService!
    var mockFileManager: MockFileManager!
    var mockURLAccessWrapper: MockSecurityScopedURLAccessWrapper!
    var sourceURL: URL!
    var destinationURL: URL!
    // Use a fixed date to make tests deterministic
    let fixedDate = Date(timeIntervalSince1970: 1672531200) // 2023-01-01 00:00:00 UTC

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockFileManager = MockFileManager()
        mockURLAccessWrapper = MockSecurityScopedURLAccessWrapper()
        importService = ImportService(fileManager: mockFileManager, urlAccessWrapper: mockURLAccessWrapper)
        // Inject the fixed date provider
        importService.nowProvider = { self.fixedDate }
        
        sourceURL = URL(fileURLWithPath: "/source")
        destinationURL = URL(fileURLWithPath: "/destination")
        
        mockFileManager.virtualFileSystem = [
            "/source/file1.jpg": Data(),
            "/source/file2.mov": Data(),
        ]
    }

    override func tearDownWithError() throws {
        importService = nil
        mockFileManager = nil
        mockURLAccessWrapper = nil
        sourceURL = nil
        destinationURL = nil
        try super.tearDownWithError()
    }
    
    private func createSettings(organize: Bool, rename: Bool) -> SettingsStore {
        let settings = SettingsStore()
        settings.organizeByDate = organize
        settings.renameByDate = rename
        return settings
    }

    func testImportFiles_NoOrganizeNoRename() async throws {
        let settings = createSettings(organize: false, rename: false)
        let fileModels = [
            File(sourcePath: "/source/file1.jpg", mediaType: .image, date: nil, size: nil, status: .waiting),
            File(sourcePath: "/source/file2.mov", mediaType: .video, date: nil, size: nil, status: .waiting)
        ]

        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings)

        XCTAssertEqual(mockFileManager.copiedFiles.count, 2)
        XCTAssertTrue(mockFileManager.fileExists(atPath: "/destination/file1.jpg"))
        XCTAssertTrue(mockFileManager.fileExists(atPath: "/destination/file2.mov"))
    }

    func testImportFiles_OrganizeByDateOnly() async throws {
        let settings = createSettings(organize: true, rename: false)
        let fileModels = [File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: nil, status: .waiting)]

        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings)

        let expectedPath = "/destination/2023/01/file1.jpg"
        XCTAssertTrue(mockFileManager.fileExists(atPath: expectedPath), "File should exist at \(expectedPath)")
        XCTAssertTrue(mockFileManager.createdDirectories.contains("/destination/2023/01"), "Directory /destination/2023/01 should have been created")
    }

    func testImportFiles_RenameByDateOnly() async throws {
        let settings = createSettings(organize: false, rename: true)
        let fileModels = [File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: nil, status: .waiting)]
        
        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings)

        let expectedPath = "/destination/IMG_20230101_000000.jpg"
        XCTAssertTrue(mockFileManager.fileExists(atPath: expectedPath), "File should exist at \(expectedPath)")
    }

    func testImportFiles_OrganizeAndRenameByDate() async throws {
        let settings = createSettings(organize: true, rename: true)
        let imageFile = File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: nil, status: .waiting)
        let videoFile = File(sourcePath: "/source/file2.mov", mediaType: .video, date: fixedDate, size: nil, status: .waiting)
        
        try await importService.importFiles(files: [imageFile, videoFile], to: destinationURL, settings: settings)

        let expectedImagePath = "/destination/2023/01/IMG_20230101_000000.jpg"
        let expectedVideoPath = "/destination/2023/01/VID_20230101_000000.mov"
        XCTAssertTrue(mockFileManager.fileExists(atPath: expectedImagePath))
        XCTAssertTrue(mockFileManager.fileExists(atPath: expectedVideoPath))
    }

    func testImportFiles_NoCreationDate() async throws {
        let settings = createSettings(organize: true, rename: true)
        // File has nil date, so import service should use the injected `fixedDate`
        let fileModels = [File(sourcePath: "/source/file1.jpg", mediaType: .image, date: nil, size: nil, status: .waiting)]

        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings)
        
        let expectedPath = "/destination/2023/01/IMG_20230101_000000.jpg"
        XCTAssertTrue(mockFileManager.fileExists(atPath: expectedPath), "File with no date should be organized and renamed using the provider date. Expected at \(expectedPath)")
    }

    func testImportFiles_FilenameConflictResolution() async throws {
        let settings = createSettings(organize: false, rename: true)
        let fileModels = [File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: nil, status: .waiting)]
        
        // Setup a pre-existing file
        mockFileManager.virtualFileSystem["/destination/IMG_20230101_000000.jpg"] = Data()
        
        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings)

        let expectedPath = "/destination/IMG_20230101_000000_1.jpg"
        XCTAssertTrue(mockFileManager.fileExists(atPath: expectedPath), "File should be renamed with a suffix to avoid conflict. Expected at \(expectedPath)")
    }
    
    func testImportFiles_FilenameConflictResolution_WithMultipleExistingFiles() async throws {
        let settings = createSettings(organize: false, rename: true)
        let fileModels = [File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: nil, status: .waiting)]
        
        // Setup multiple pre-existing files
        mockFileManager.virtualFileSystem["/destination/IMG_20230101_000000.jpg"] = Data()
        mockFileManager.virtualFileSystem["/destination/IMG_20230101_000000_1.jpg"] = Data()

        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings)

        let expectedPath = "/destination/IMG_20230101_000000_2.jpg"
        XCTAssertTrue(mockFileManager.fileExists(atPath: expectedPath), "File should be renamed with the next available suffix. Expected at \(expectedPath)")
    }
    
    // MARK: - Deletion Tests

    func testImportFiles_WhenDeleteOriginalsIsTrue_DeletesSourceFiles() async throws {
        let settings = createSettings(organize: false, rename: false)
        settings.settingDeleteOriginals = true
        let fileModels = [
            File(sourcePath: "/source/file1.jpg", mediaType: .image, date: nil, size: nil, status: .waiting),
            File(sourcePath: "/source/file2.mov", mediaType: .video, date: nil, size: nil, status: .waiting)
        ]

        // Setup a thumbnail for one of the files
        let thumbnailFilePath = "/source/file1.thm"
        mockFileManager.virtualFileSystem[thumbnailFilePath] = Data()

        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings)

        XCTAssertEqual(mockFileManager.removedItems.count, 3, "Should have removed the two source files and one thumbnail.")
        XCTAssertTrue(mockFileManager.removedItems.contains(URL(fileURLWithPath: "/source/file1.jpg")))
        XCTAssertTrue(mockFileManager.removedItems.contains(URL(fileURLWithPath: "/source/file2.mov")))
        XCTAssertTrue(mockFileManager.removedItems.contains(URL(fileURLWithPath: thumbnailFilePath)), "Thumbnail file should be deleted.")

        XCTAssertNil(mockFileManager.virtualFileSystem["/source/file1.jpg"])
        XCTAssertNil(mockFileManager.virtualFileSystem["/source/file2.mov"])
        XCTAssertNil(mockFileManager.virtualFileSystem[thumbnailFilePath])
    }

    func testImportFiles_WhenDeleteOriginalsIsFalse_DoesNotDeleteSourceFiles() async throws {
        let settings = createSettings(organize: false, rename: false)
        settings.settingDeleteOriginals = false
        let fileModels = [File(sourcePath: "/source/file1.jpg", mediaType: .image, date: nil, size: nil, status: .waiting)]

        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings)

        XCTAssertTrue(mockFileManager.removedItems.isEmpty)
        XCTAssertNotNil(mockFileManager.virtualFileSystem["/source/file1.jpg"])
    }

    func testImportFiles_WhenDeletionFails_ThrowsDeleteFailedError() async {
        let settings = createSettings(organize: false, rename: false)
        settings.settingDeleteOriginals = true
        let fileModels = [File(sourcePath: "/source/file1.jpg", mediaType: .image, date: nil, size: nil, status: .waiting)]
        mockFileManager.shouldThrowOnRemove = true

        do {
            try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings)
            XCTFail("Should have thrown an error")
        } catch let error as ImportService.ImportError {
            guard case .deleteFailed(let source, _) = error else {
                XCTFail("Incorrect error type. Expected .deleteFailed, got \(error)")
                return
            }
            XCTAssertEqual(source, URL(fileURLWithPath: "/source/file1.jpg"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
} 