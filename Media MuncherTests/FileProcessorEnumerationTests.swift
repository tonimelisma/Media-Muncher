import XCTest
@testable import Media_Muncher

final class FileProcessorEnumerationTests: XCTestCase {
    private var src: URL!; private var fm: FileManager { FileManager.default }

    override func setUpWithError() throws {
        try super.setUpWithError()
        src = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: src, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? fm.removeItem(at: src)
        try super.tearDownWithError()
    }

    func testThumbnailFoldersAreSkipped() async throws {
        let thumbDir = src.appendingPathComponent(".thumbnails")
        try fm.createDirectory(at: thumbDir, withIntermediateDirectories: true)
        let img = thumbDir.appendingPathComponent("ignored.jpg")
        fm.createFile(atPath: img.path, contents: Data([0xAA]))

        let normal = src.appendingPathComponent("photo.jpg")
        fm.createFile(atPath: normal.path, contents: Data([0xBB]))

        let settings = SettingsStore()
        let fps = FileProcessorService()
        let files = await fps.processFiles(from: src, destinationURL: nil, settings: settings)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first?.sourcePath, normal.path)
    }

    func testMetadataFallbackToMtime() async throws {
        // Create image with no EXIF; Ensure date equal to mtime
        let ts = Date(timeIntervalSince1970: 1_700_001_111)
        let img = src.appendingPathComponent("bare.heic")
        fm.createFile(atPath: img.path, contents: Data([0x00]))
        try fm.setAttributes([.modificationDate: ts, .creationDate: ts], ofItemAtPath: img.path)

        let settings = SettingsStore()
        settings.renameByDate = true
        settings.organizeByDate = false
        let fps = FileProcessorService()
        let files = await fps.processFiles(from: src, destinationURL: nil, settings: settings)
        guard let file = files.first else { XCTFail(); return }
        XCTAssertNotNil(file.date)
        XCTAssertEqual(file.date!.timeIntervalSince1970, ts.timeIntervalSince1970, accuracy: 1, "Date should fallback to modification time")
    }
} 