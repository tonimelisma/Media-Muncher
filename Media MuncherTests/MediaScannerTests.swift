import XCTest
@testable import Media_Muncher

final class MediaScannerTests: XCTestCase {
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
        let streams = await mediaScanner.enumerateFiles(at: tempDirectoryURL, destinationURL: nil, filterImages: true, filterVideos: true, filterAudio: true)
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

    func testEnumerateFilesDetectsPreExistingFiles() async throws {
        // Arrange
        let sourceURL = tempDirectoryURL.appendingPathComponent("source")
        let destinationURL = tempDirectoryURL.appendingPathComponent("destination")
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // 1. File that exists in both source and destination (should be marked pre_existing)
        let file1URL = sourceURL.appendingPathComponent("image1.jpg")
        let destFile1URL = destinationURL.appendingPathComponent("image1.jpg")
        let file1Content = "samedata".data(using: .utf8)
        fileManager.createFile(atPath: file1URL.path, contents: file1Content)
        fileManager.createFile(atPath: destFile1URL.path, contents: file1Content)
        // Ensure modification dates are close
        try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: file1URL.path)
        try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: destFile1URL.path)


        // 2. File that only exists in source (should be marked waiting)
        let file2URL = sourceURL.appendingPathComponent("image2.jpg")
        fileManager.createFile(atPath: file2URL.path, contents: "newdata".data(using: .utf8))

        // 3. File with same name but different content/size (should be marked waiting)
        let file3URL = sourceURL.appendingPathComponent("image3.jpg")
        let destFile3URL = destinationURL.appendingPathComponent("image3.jpg")
        fileManager.createFile(atPath: file3URL.path, contents: "source_data_for_3".data(using: .utf8))
        fileManager.createFile(atPath: destFile3URL.path, contents: "destination_data_for_3_is_different".data(using: .utf8))
        
        let mediaScanner = MediaScanner()
        
        // Act
        let streams = await mediaScanner.enumerateFiles(at: sourceURL, destinationURL: destinationURL, filterImages: true, filterVideos: true, filterAudio: true)
        var foundFiles: [File] = []
        for try await batch in streams.results {
            foundFiles.append(contentsOf: batch)
        }

        // Assert
        XCTAssertEqual(foundFiles.count, 3)
        
        let file1 = foundFiles.first { $0.sourceName == "image1.jpg" }
        XCTAssertNotNil(file1)
        XCTAssertEqual(file1?.status, .pre_existing, "image1.jpg should be marked as pre_existing")

        let file2 = foundFiles.first { $0.sourceName == "image2.jpg" }
        XCTAssertNotNil(file2)
        XCTAssertEqual(file2?.status, .waiting, "image2.jpg should be marked as waiting")

        let file3 = foundFiles.first { $0.sourceName == "image3.jpg" }
        XCTAssertNotNil(file3)
        XCTAssertEqual(file3?.status, .waiting, "image3.jpg should be marked as waiting because its size is different")
    }

    func testEnumerateFilesWithFilters() async throws {
        // Arrange
        let testFiles = ["image.jpg", "video.mov", "audio.mp3", "document.txt"]
        for fileName in testFiles {
            let fileURL = tempDirectoryURL.appendingPathComponent(fileName)
            fileManager.createFile(atPath: fileURL.path, contents: Data("test".utf8), attributes: nil)
        }
        
        let mediaScanner = MediaScanner()
        
        // Act & Assert
        
        // 1. Test filtering for only images
        var streams = await mediaScanner.enumerateFiles(at: tempDirectoryURL, destinationURL: nil, filterImages: true, filterVideos: false, filterAudio: false)
        var foundFiles: [File] = []
        for try await batch in streams.results {
            foundFiles.append(contentsOf: batch)
        }
        XCTAssertEqual(foundFiles.count, 1)
        XCTAssertEqual(foundFiles.first?.sourceName, "image.jpg")

        // 2. Test filtering for only videos
        streams = await mediaScanner.enumerateFiles(at: tempDirectoryURL, destinationURL: nil, filterImages: false, filterVideos: true, filterAudio: false)
        foundFiles = []
        for try await batch in streams.results {
            foundFiles.append(contentsOf: batch)
        }
        XCTAssertEqual(foundFiles.count, 1)
        XCTAssertEqual(foundFiles.first?.sourceName, "video.mov")
        
        // 3. Test filtering for only audio
        streams = await mediaScanner.enumerateFiles(at: tempDirectoryURL, destinationURL: nil, filterImages: false, filterVideos: false, filterAudio: true)
        foundFiles = []
        for try await batch in streams.results {
            foundFiles.append(contentsOf: batch)
        }
        XCTAssertEqual(foundFiles.count, 1)
        XCTAssertEqual(foundFiles.first?.sourceName, "audio.mp3")

        // 4. Test filtering for images and videos
        streams = await mediaScanner.enumerateFiles(at: tempDirectoryURL, destinationURL: nil, filterImages: true, filterVideos: true, filterAudio: false)
        foundFiles = []
        for try await batch in streams.results {
            foundFiles.append(contentsOf: batch)
        }
        XCTAssertEqual(foundFiles.count, 2)
        XCTAssertTrue(foundFiles.contains { $0.sourceName == "image.jpg" })
        XCTAssertTrue(foundFiles.contains { $0.sourceName == "video.mov" })
        
        // 5. Test filtering for all media types
        streams = await mediaScanner.enumerateFiles(at: tempDirectoryURL, destinationURL: nil, filterImages: true, filterVideos: true, filterAudio: true)
        foundFiles = []
        for try await batch in streams.results {
            foundFiles.append(contentsOf: batch)
        }
        XCTAssertEqual(foundFiles.count, 3)
        XCTAssertTrue(foundFiles.contains { $0.sourceName == "image.jpg" })
        XCTAssertTrue(foundFiles.contains { $0.sourceName == "video.mov" })
        XCTAssertTrue(foundFiles.contains { $0.sourceName == "audio.mp3" })
    }

    func testEnumerateFilesSkipsThumbnailFolders() async throws {
        // Arrange
        let thumbnailFolder1 = tempDirectoryURL.appendingPathComponent("THMBNL")
        let thumbnailFolder2 = tempDirectoryURL.appendingPathComponent(".thumbnails")
        let regularFolder = tempDirectoryURL.appendingPathComponent("regular")
        
        try fileManager.createDirectory(at: thumbnailFolder1, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailFolder2, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: regularFolder, withIntermediateDirectories: true)

        // Files that should be skipped
        fileManager.createFile(atPath: thumbnailFolder1.appendingPathComponent("thumb1.jpg").path, contents: nil)
        fileManager.createFile(atPath: thumbnailFolder2.appendingPathComponent("thumb2.mov").path, contents: nil)

        // File that should be found
        let expectedFile = regularFolder.appendingPathComponent("media.mp3")
        fileManager.createFile(atPath: expectedFile.path, contents: nil)

        let mediaScanner = MediaScanner()

        // Act
        let streams = await mediaScanner.enumerateFiles(at: tempDirectoryURL, destinationURL: nil, filterImages: true, filterVideos: true, filterAudio: true)
        var foundFiles: [File] = []
        for try await batch in streams.results {
            foundFiles.append(contentsOf: batch)
        }

        // Assert
        XCTAssertEqual(foundFiles.count, 1, "Should only find one file, ignoring files in thumbnail directories.")
        XCTAssertEqual(foundFiles.first?.sourcePath, expectedFile.path)
    }
} 