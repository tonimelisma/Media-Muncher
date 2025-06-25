import XCTest
@testable import Media_Muncher

class FileProcessorServiceTests: XCTestCase {

    var service: FileProcessorService!
    var settings: SettingsStore!
    var mockFileManager: MockFileManager!
    let destinationURL = URL(fileURLWithPath: "/dest")
    let fixedDate = Date(timeIntervalSince1970: 1672531200) // 2023-01-01 00:00:00 UTC

    override func setUp() {
        super.setUp()
        service = FileProcessorService()
        settings = SettingsStore()
        mockFileManager = MockFileManager()
        settings.renameByDate = true // Use predictable names
        settings.organizeByDate = false
    }

    // MARK: - Test Cases

    func testSourceToSourceDuplicateIsCorrectlyMarked() async {
        // Arrange
        let file1 = File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: 1024, status: .waiting)
        let file2 = File(sourcePath: "/source/sub/file2.jpg", mediaType: .image, date: fixedDate, size: 1024, status: .waiting) // Same content
        let file3 = File(sourcePath: "/source/file3.jpg", mediaType: .image, date: fixedDate, size: 2048, status: .waiting) // Different
        
        var allFiles = [file1, file2, file3]

        // Act
        let processedFile1 = await service.processFile(file1, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)
        allFiles[0] = processedFile1
        
        let processedFile2 = await service.processFile(file2, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)
        allFiles[1] = processedFile2
        
        let processedFile3 = await service.processFile(file3, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)
        allFiles[2] = processedFile3

        // Assert
        XCTAssertEqual(allFiles[0].status, .waiting)
        XCTAssertEqual(allFiles[1].status, .duplicate_in_source, "File 2 should be marked as a source duplicate of File 1")
        XCTAssertEqual(allFiles[2].status, .waiting)
    }

    func testPreExistingFileIsCorrectlyMarked() async {
        // Arrange
        let fileOnDiskURL = destinationURL.appendingPathComponent("IMG_20230101_000000.jpg")
        try! mockFileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        mockFileManager.virtualFileSystem[fileOnDiskURL.path] = Data(count: 1024)
        try! mockFileManager.setAttributes([.modificationDate: fixedDate], ofItemAtPath: fileOnDiskURL.path)
        
        let sourceFile = File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: 1024, status: .waiting)
        let allFiles = [sourceFile]

        // Act
        let processedFile = await service.processFile(sourceFile, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)

        // Assert
        XCTAssertEqual(processedFile.status, .pre_existing)
    }

    func testCollisionWithDifferentFileOnDiskGetsSuffix() async {
        // Arrange
        let fileOnDiskURL = destinationURL.appendingPathComponent("IMG_20230101_000000.jpg")
        try! mockFileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        mockFileManager.virtualFileSystem[fileOnDiskURL.path] = Data(count: 9999) // Different size
        
        let sourceFile = File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: 1024, status: .waiting)
        let allFiles = [sourceFile]

        // Act
        let processedFile = await service.processFile(sourceFile, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)

        // Assert
        XCTAssertEqual(processedFile.status, .waiting)
        XCTAssertEqual(processedFile.destPath, "/dest/IMG_20230101_000000_1.jpg", "Should have suffix _1 due to collision with a different file on disk")
    }

    func testInSessionCollisionGetsSuffix() async {
        // Arrange
        let file1 = File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: 1024, status: .waiting)
        let file2 = File(sourcePath: "/source/file2.jpg", mediaType: .image, date: fixedDate, size: 2048, status: .waiting) // Different file, same ideal name
        var allFiles = [file1, file2]

        // Act
        let processedFile1 = await service.processFile(file1, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)
        allFiles[0] = processedFile1 // Update the array with the processed file to simulate the app's flow
        
        let processedFile2 = await service.processFile(file2, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)
        allFiles[1] = processedFile2

        // Assert
        XCTAssertEqual(processedFile1.destPath, "/dest/IMG_20230101_000000.jpg")
        XCTAssertEqual(processedFile2.destPath, "/dest/IMG_20230101_000000_1.jpg", "File 2 should have suffix _1 due to in-session collision with File 1")
    }
    
    func testThreeWayCollisionIsResolvedCorrectly() async {
        // Arrange
        // 1. A file already on disk
        let fileOnDiskURL = destinationURL.appendingPathComponent("IMG_20230101_000000.jpg")
        try! mockFileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        mockFileManager.virtualFileSystem[fileOnDiskURL.path] = Data(count: 9999)

        // 2. Two source files that will collide with the disk file and then each other
        let file1 = File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: 1024, status: .waiting)
        let file2 = File(sourcePath: "/source/file2.jpg", mediaType: .image, date: fixedDate, size: 2048, status: .waiting)
        var allFiles = [file1, file2]
        
        // Act
        let processedFile1 = await service.processFile(file1, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)
        allFiles[0] = processedFile1
        
        let processedFile2 = await service.processFile(file2, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)
        allFiles[1] = processedFile2
        
        // Assert
        XCTAssertEqual(processedFile1.destPath, "/dest/IMG_20230101_000000_1.jpg", "File 1 should get _1 suffix to avoid disk collision")
        XCTAssertEqual(processedFile2.destPath, "/dest/IMG_20230101_000000_2.jpg", "File 2 should get _2 suffix to avoid both disk and in-session collision")
    }
}

extension MockFileManager {
    func setAttributes(_ attributes: [FileAttributeKey : Any], ofItemAtPath path: String) throws {
        // This is a simplified mock. For testing, we just ensure the file exists.
        // A more complex mock could store attributes in a dictionary.
        guard virtualFileSystem[path] != nil else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: nil)
        }
    }
} 