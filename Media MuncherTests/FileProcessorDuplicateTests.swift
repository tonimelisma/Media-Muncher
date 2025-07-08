import XCTest
@testable import Media_Muncher

final class FileProcessorDuplicateTests: XCTestCase {
    private var src: URL!; private var dst: URL!
    private var fm: FileManager { FileManager.default }

    override func setUpWithError() throws {
        try super.setUpWithError()
        src = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        dst = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: src, withIntermediateDirectories: true)
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? fm.removeItem(at: src)
        try? fm.removeItem(at: dst)
        try super.tearDownWithError()
    }

    private func createFile(_ url: URL, size: Int = 1, timestamp: Date = Date()) {
        fm.createFile(atPath: url.path, contents: Data(repeating: 0xCC, count: size))
        try? fm.setAttributes([.modificationDate: timestamp, .creationDate: timestamp], ofItemAtPath: url.path)
    }

    func testDuplicateInSource_markedDuplicate() async throws {
        // Two identical photos with different filenames
        let ts = Date(timeIntervalSince1970: 1_700_000_000)
        let f1 = src.appendingPathComponent("a.jpg")
        let f2 = src.appendingPathComponent("b.jpg")
        createFile(f1, size: 10, timestamp: ts)
        createFile(f2, size: 10, timestamp: ts)

        let settings = SettingsStore()
        let fps = FileProcessorService()
        let files = await fps.processFiles(from: src, destinationURL: nil, settings: settings)
        XCTAssertEqual(files.count, 2)
        let dup = files.first { $0.status == .duplicate_in_source }
        XCTAssertNotNil(dup, "One of the files should be tagged duplicate_in_source")
    }

    func testCollision_suffix2Generated() async throws {
        // Destination already has file + _1 so incoming gets _2
        let existing = dst.appendingPathComponent("clip.mov")
        createFile(existing, size: 5)
        let existing2 = dst.appendingPathComponent("clip_1.mov")
        createFile(existing2, size: 6) // different size ensures collision, not duplicate

        // Source supplies third distinct version with same base name
        let f = src.appendingPathComponent("clip.mov")
        createFile(f, size: 7)

        let settings = SettingsStore()
        settings.renameByDate = false
        settings.organizeByDate = false
        let fps = FileProcessorService()
        let processed = await fps.processFiles(from: src, destinationURL: dst, settings: settings)
        guard let file = processed.first else { XCTFail(); return }
        XCTAssertTrue(file.destPath?.hasSuffix("clip_2.mov") == true, "Should generate _2 suffix")
    }

    func testDifferentFileSameName_GetsSuffixNotPreExisting() async throws {
        // Destination has clip.mov size 5, source has different size
        let existing = dst.appendingPathComponent("clip.mov")
        createFile(existing, size: 5)

        let srcFile = src.appendingPathComponent("clip.mov")
        createFile(srcFile, size: 9)

        let settings = SettingsStore()
        settings.renameByDate = false
        settings.organizeByDate = false

        let fps = FileProcessorService()
        let processed = await fps.processFiles(from: src, destinationURL: dst, settings: settings)
        guard let file = processed.first else { XCTFail(); return }

        XCTAssertEqual(file.status, .waiting)
        XCTAssertTrue(file.destPath?.hasSuffix("clip_1.mov") == true)
    }
} 