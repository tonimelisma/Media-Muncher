import XCTest
@testable import Media_Muncher

@MainActor
final class ImportProgressTests: XCTestCase {

    var importProgress: ImportProgress!

    override func setUp() {
        super.setUp()
        importProgress = ImportProgress()
    }

    override func tearDown() {
        importProgress = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(importProgress.totalBytesToImport, 0)
        XCTAssertEqual(importProgress.importedBytes, 0)
        XCTAssertEqual(importProgress.importedFileCount, 0)
        XCTAssertEqual(importProgress.totalFilesToImport, 0)
        XCTAssertNil(importProgress.importStartTime)
        XCTAssertNil(importProgress.elapsedSeconds)
        XCTAssertNil(importProgress.remainingSeconds)
    }

    func testStartWithFiles() {
        let files = [
            File(sourcePath: "/tmp/a.jpg", mediaType: .image, size: 100, status: .waiting),
            File(sourcePath: "/tmp/b.jpg", mediaType: .image, size: 200, status: .waiting)
        ]
        
        importProgress.start(with: files)
        
        XCTAssertEqual(importProgress.totalFilesToImport, 2)
        XCTAssertEqual(importProgress.totalBytesToImport, 300)
        XCTAssertEqual(importProgress.importedBytes, 0)
        XCTAssertEqual(importProgress.importedFileCount, 0)
        XCTAssertNotNil(importProgress.importStartTime)
    }

    func testUpdateWithImportedFile() {
        let file = File(sourcePath: "/tmp/a.jpg", mediaType: .image, size: 100, status: .imported)
        
        importProgress.update(with: file)
        
        XCTAssertEqual(importProgress.importedFileCount, 1)
        XCTAssertEqual(importProgress.importedBytes, 100)
    }

    func testUpdateWithNonImportedFile() {
        let file = File(sourcePath: "/tmp/a.jpg", mediaType: .image, size: 100, status: .waiting)
        
        importProgress.update(with: file)
        
        XCTAssertEqual(importProgress.importedFileCount, 0)
        XCTAssertEqual(importProgress.importedBytes, 0)
    }

    func testFinish() {
        importProgress.start(with: [])
        XCTAssertNotNil(importProgress.importStartTime)
        
        importProgress.finish()
        
        XCTAssertNil(importProgress.importStartTime)
    }

    func testComputedTimeProperties() async throws {
        let files = [File(sourcePath: "/tmp/a.jpg", mediaType: .image, size: 1000, status: .waiting)]
        importProgress.start(with: files)
        
        // Simulate progress
        try await Task.sleep(for: .seconds(1))
        
        let importedFile = File(sourcePath: "/tmp/a.jpg", mediaType: .image, size: 500, status: .imported)
        importProgress.update(with: importedFile)
        
        XCTAssertNotNil(importProgress.elapsedSeconds)
        XCTAssertNotNil(importProgress.remainingSeconds)
        
        XCTAssertGreaterThan(importProgress.elapsedSeconds ?? 0, 0.9)
        XCTAssertLessThan(importProgress.elapsedSeconds ?? 0, 1.1)
        
        XCTAssertGreaterThan(importProgress.remainingSeconds ?? 0, 0.9)
        XCTAssertLessThan(importProgress.remainingSeconds ?? 0, 1.1)
    }
} 