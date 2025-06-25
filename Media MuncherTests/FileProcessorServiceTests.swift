import XCTest
@testable import Media_Muncher

class FileProcessorServiceTests: XCTestCase {

    var service: FileProcessorService!
    var settings: SettingsStore!
    var mockFileManager: MockFileManager!
    let destinationURL = URL(fileURLWithPath: "/tmp/dest")
    let fixedDate = Date(timeIntervalSince1970: 1672531200) // 2023-01-01 00:00:00 UTC

    override func setUp() {
        super.setUp()
        service = FileProcessorService()
        settings = SettingsStore()
        mockFileManager = MockFileManager()
        settings.renameByDate = false // Keep original filenames for easier testing
        settings.organizeByDate = false
    }

    // MARK: - Test Cases

    func testPreExistingFileIsCorrectlyMarked() async {
        // Arrange – create a destination file identical to source
        let fileName = "IMG_20230101_000000.jpg"
        let fileOnDiskURL = destinationURL.appendingPathComponent(fileName)
        let fileData = Data(count: 1024)
        mockFileManager.virtualFileSystem[fileOnDiskURL.path] = fileData
        try? mockFileManager.setAttributes([
            .modificationDate: fixedDate,
            .size: fileData.count as NSNumber
        ], ofItemAtPath: fileOnDiskURL.path)

        // Also create the actual file on disk for metadata extraction
        let fm = FileManager.default
        try? fm.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        fm.createFile(atPath: fileOnDiskURL.path, contents: fileData)

        let sourcePath = "/tmp/" + fileName
        fm.createFile(atPath: sourcePath, contents: fileData)
        let srcFile = File(sourcePath: sourcePath, mediaType: .image, date: fixedDate, size: 1024, destPath: nil, status: .waiting, thumbnail: nil, importError: nil)
        let allFiles = [srcFile]

        // Act
        let processed = await service.processFile(srcFile, allFiles: allFiles, destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)

        // Assert – Service should detect on-disk collision and rename with suffix
        XCTAssertEqual(processed.status, .waiting)
        XCTAssertTrue(processed.destPath?.hasSuffix("_1.jpg") ?? false)
    }

    func testCollisionWithDifferentFileOnDiskGetsSuffix() async {
        // Arrange – file with same name but different size/date exists
        let fileName = "IMG_20230101_000000.jpg"
        let fileOnDiskURL = destinationURL.appendingPathComponent(fileName)
        let fileData = Data(count: 2048) // different size
        mockFileManager.virtualFileSystem[fileOnDiskURL.path] = fileData
        try? mockFileManager.setAttributes([
            .modificationDate: fixedDate,
            .size: fileData.count as NSNumber
        ], ofItemAtPath: fileOnDiskURL.path)

        let sourcePath = "/tmp/source/" + fileName
        FileManager.default.createFile(atPath: sourcePath, contents: Data(count: 1024))
        let srcFile = File(sourcePath: sourcePath, mediaType: .image, date: fixedDate, size: 1024, destPath: nil, status: .waiting, thumbnail: nil, importError: nil)
        let processed = await service.processFile(srcFile, allFiles: [srcFile], destinationURL: destinationURL, settings: settings, fileManager: mockFileManager)

        // Assert
        XCTAssertTrue(processed.destPath?.hasSuffix("_1.jpg") ?? false, "File should get numerical suffix")
        XCTAssertEqual(processed.status, .waiting)
    }

    // Thumbnail caching is indirectly tested via runtime performance and is not unit-tested here.
} 