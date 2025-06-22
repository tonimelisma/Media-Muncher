import XCTest
@testable import Media_Muncher

class MediaScannerTests: XCTestCase {
    var tempDirectoryURL: URL!
    let fileManager = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Create a unique temporary directory for each test
        tempDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    override func tearDownWithError() throws {
        try fileManager.removeItem(at: tempDirectoryURL)
        tempDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testEnumerateFilesFindsMedia() async throws {
        // Arrange
        let testFiles = ["test.jpg", "test.mov", "document.txt", "test.png"]
        for fileName in testFiles {
            let fileURL = tempDirectoryURL.appendingPathComponent(fileName)
            fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        
        let mediaScanner = MediaScanner()
        
        // Act
        let streams = await mediaScanner.enumerateFiles(at: tempDirectoryURL)
        var foundFiles: [File] = []
        for try await batch in streams.results {
            foundFiles.append(contentsOf: batch)
        }

        // Assert
        XCTAssertEqual(foundFiles.count, 3, "Should have found 3 media files, ignoring the .txt file.")
        
        let foundNames = foundFiles.map { $0.sourceName }.sorted()
        XCTAssertEqual(foundNames, ["test.jpg", "test.mov", "test.png"])
        
        let imageFiles = foundFiles.filter { $0.mediaType == .image }
        XCTAssertEqual(imageFiles.count, 2)
        
        let videoFiles = foundFiles.filter { $0.mediaType == .video }
        XCTAssertEqual(videoFiles.count, 1)
    }
} 