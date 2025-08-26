import XCTest
@testable import Media_Muncher

final class FileProcessorCollisionTests: XCTestCase {
    var tempSrcDir: URL!
    var tempDestDir: URL!
    var fileManager: FileManager!
    var settings: SettingsStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        tempSrcDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        tempDestDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempSrcDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempDestDir, withIntermediateDirectories: true)
        settings = SettingsStore()
        // Disable rename/organize for deterministic simple filenames
        settings.renameByDate = false
        settings.organizeByDate = false
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempSrcDir)
        try? fileManager.removeItem(at: tempDestDir)
        tempSrcDir = nil
        tempDestDir = nil
        settings = nil
        fileManager = nil
        try super.tearDownWithError()
    }

    // MARK: - Helper
    private func createFile(named name: String, contents: Data = Data([0x00,0x01,0x02])) -> URL {
        let url = tempSrcDir.appendingPathComponent(name)
        fileManager.createFile(atPath: url.path, contents: contents)
        return url
    }

    // MARK: - Tests
    func testProcessFiles_detectsDuplicateInSource() async throws {
        // Arrange – create two identical image files
        let file1 = createFile(named: "a.jpg")
        let file2 = createFile(named: "b.jpg")
        // Ensure identical timestamps so duplicate detection is deterministic
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        try fileManager.setAttributes([.creationDate: referenceDate, .modificationDate: referenceDate], ofItemAtPath: file1.path)
        try fileManager.setAttributes([.creationDate: referenceDate, .modificationDate: referenceDate], ofItemAtPath: file2.path)

        let processor = FileProcessorService.testInstance()

        // Act
        let processed = await processor.processFiles(from: tempSrcDir, destinationURL: nil, settings: settings)

        // Assert – second file should be marked duplicate_in_source pointing to first
        XCTAssertEqual(processed.count, 2)
        // Sort to ensure predictable order (processFiles sorts by path already but be explicit)
        let sorted = processed.sorted { $0.sourcePath < $1.sourcePath }
        XCTAssertEqual(sorted[0].status, .waiting)
        XCTAssertEqual(sorted[1].status, .duplicate_in_source)
        XCTAssertEqual(sorted[1].duplicateOf, sorted[0].id)
    }

    func testProcessFiles_marksPreExistingDestination() async throws {
        // Arrange – create file in source
        let srcFile = createFile(named: "sample.jpg")
        // Copy identical file to destination to simulate pre-existing
        let destFile = tempDestDir.appendingPathComponent("sample.jpg")
        try fileManager.copyItem(at: srcFile, to: destFile)

        let processor = FileProcessorService.testInstance()

        // Act
        let processed = await processor.processFiles(from: tempSrcDir, destinationURL: tempDestDir, settings: settings)
        guard let result = processed.first else {
            XCTFail("No file processed")
            return
        }

        // Assert – should detect as pre_existing and keep same destPath
        XCTAssertEqual(result.status, .pre_existing)
        XCTAssertEqual(result.destPath, destFile.path)
    }

    func testProcessFiles_resolvesCollisionWithSuffix() async throws {
        // Arrange – create source file
        _ = createFile(named: "clip.jpg", contents: Data(repeating: 0xAA, count: 10))
        // Create DIFFERENT file with same name in destination to cause collision
        let existing = tempDestDir.appendingPathComponent("clip.jpg")
        fileManager.createFile(atPath: existing.path, contents: Data(repeating: 0xBB, count: 20))

        let processor = FileProcessorService.testInstance()

        // Act
        let processed = await processor.processFiles(from: tempSrcDir, destinationURL: tempDestDir, settings: settings)
        guard let result = processed.first else {
            XCTFail("No file processed")
            return
        }

        // Assert – should generate _1 suffix and remain .waiting
        XCTAssertEqual(result.status, .waiting)
        XCTAssertTrue(result.destPath?.hasSuffix("clip_1.jpg") ?? false, "Expected destPath with _1 suffix, got \(result.destPath ?? "nil")")
    }
} 
