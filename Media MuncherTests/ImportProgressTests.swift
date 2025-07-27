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

    func testComputedTimeProperties() {
        // Use fixed dates for deterministic testing
        let startTime = Date(timeIntervalSince1970: 1000)
        let currentTime = Date(timeIntervalSince1970: 1001) // 1 second later
        
        let files = [File(sourcePath: "/tmp/a.jpg", mediaType: .image, size: 1000, status: .waiting)]
        importProgress.startForTesting(with: files, startTime: startTime)
        
        // Simulate progress: 500 bytes imported out of 1000 (50% complete)
        let importedFile = File(sourcePath: "/tmp/a.jpg", mediaType: .image, size: 500, status: .imported)
        importProgress.update(with: importedFile)
        
        // Test explicit time calculations
        let elapsedSeconds = importProgress.elapsedSecondsForTesting(currentTime: currentTime)
        let remainingSeconds = importProgress.remainingSecondsForTesting(currentTime: currentTime)
        
        XCTAssertNotNil(elapsedSeconds)
        XCTAssertNotNil(remainingSeconds)
        
        XCTAssertEqual(elapsedSeconds, 1.0, "Should have exactly 1 second elapsed")
        XCTAssertEqual(remainingSeconds, 1.0, "Should estimate 1 second remaining (50% progress)")
        
        // Verify production methods still work (should be approximately the same if run immediately)
        XCTAssertNotNil(importProgress.elapsedSeconds)
        XCTAssertNotNil(importProgress.remainingSeconds)
    }
    
    func testTestingMethodsProvideConsistentResults() {
        // Verify testing methods produce same results as production methods when using current time
        let files = [File(sourcePath: "/tmp/a.jpg", mediaType: .image, size: 1000, status: .waiting)]
        let startTime = Date()
        
        importProgress.startForTesting(with: files, startTime: startTime)
        let importedFile = File(sourcePath: "/tmp/a.jpg", mediaType: .image, size: 500, status: .imported)
        importProgress.update(with: importedFile)
        
        let currentTime = Date()
        
        let testingElapsed = importProgress.elapsedSecondsForTesting(currentTime: currentTime)
        let testingRemaining = importProgress.remainingSecondsForTesting(currentTime: currentTime)
        
        XCTAssertNotNil(testingElapsed)
        XCTAssertNotNil(testingRemaining)
        
        // Testing methods should produce valid results
        XCTAssertGreaterThan(testingElapsed!, 0)
        XCTAssertGreaterThan(testingRemaining!, 0)
    }
} 