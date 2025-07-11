import XCTest
@testable import Media_Muncher

/// Focused additional tests that complement the existing comprehensive test suite
final class FocusedAdditionalTests: XCTestCase {
    
    private var tempDir: URL!
    private let fm = FileManager.default
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? fm.removeItem(at: tempDir)
        tempDir = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Media Type Detection Edge Cases
    
    /// Test media type detection with unusual file extensions
    func testMediaTypeDetectionEdgeCases() throws {
        // Test uppercase extensions
        XCTAssertEqual(MediaType.from(filePath: "test.JPG"), .image)
        XCTAssertEqual(MediaType.from(filePath: "test.MP4"), .video)
        XCTAssertEqual(MediaType.from(filePath: "test.MP3"), .audio)
        
        // Test mixed case
        XCTAssertEqual(MediaType.from(filePath: "test.JpG"), .image)
        XCTAssertEqual(MediaType.from(filePath: "test.Mp4"), .video)
        
        // Test files without extensions
        XCTAssertEqual(MediaType.from(filePath: "test"), .unknown)
        XCTAssertEqual(MediaType.from(filePath: ""), .unknown)
        
        // Test files with multiple dots
        XCTAssertEqual(MediaType.from(filePath: "test.backup.jpg"), .image)
        XCTAssertEqual(MediaType.from(filePath: "my.file.name.mp4"), .video)
        
        // Test unknown extensions
        XCTAssertEqual(MediaType.from(filePath: "test.xyz"), .unknown)
        XCTAssertEqual(MediaType.from(filePath: "test.txt"), .unknown)
    }
    
    /// Test all media type SF Symbol mappings
    func testMediaTypeSFSymbolMappings() throws {
        XCTAssertEqual(MediaType.image.sfSymbolName, "photo.fill.on.rectangle.fill")
        XCTAssertEqual(MediaType.video.sfSymbolName, "video.fill")
        XCTAssertEqual(MediaType.audio.sfSymbolName, "music.note")
        XCTAssertEqual(MediaType.unknown.sfSymbolName, "questionmark.app")
    }
    
    // MARK: - File Model Edge Cases
    
    /// Test File model computed properties
    func testFileModelComputedProperties() throws {
        let file = File(
            sourcePath: "/path/to/MyPhoto.JPEG",
            mediaType: .image,
            date: Date(),
            size: 1024,
            destPath: "/dest/MyPhoto.JPEG",
            status: .waiting,
            thumbnail: nil,
            importError: nil
        )
        
        XCTAssertEqual(file.sourceName, "MyPhoto.JPEG")
        XCTAssertEqual(file.filenameWithoutExtension, "MyPhoto")
        XCTAssertEqual(file.fileExtension, "JPEG")
        XCTAssertEqual(file.id, "/path/to/MyPhoto.JPEG") // id is sourcePath
    }
    
    /// Test File model with complex paths
    func testFileModelWithComplexPaths() throws {
        let complexPath = "/Users/test/My Documents/Photos/Vacation 2024/IMG_001.jpg"
        let file = File(
            sourcePath: complexPath,
            mediaType: .image,
            date: Date(),
            size: 2048,
            destPath: nil,
            status: .waiting,
            thumbnail: nil,
            importError: nil
        )
        
        XCTAssertEqual(file.sourceName, "IMG_001.jpg")
        XCTAssertEqual(file.filenameWithoutExtension, "IMG_001")
        XCTAssertEqual(file.fileExtension, "jpg")
        XCTAssertEqual(file.id, complexPath)
    }
    
    // MARK: - FileStatus Enum Validation
    
    /// Test all FileStatus enum values
    func testFileStatusEnumValues() throws {
        let allStatuses: [FileStatus] = [
            .waiting, .pre_existing, .copying, .verifying, .imported, .failed, .duplicate_in_source
        ]
        
        // Ensure all status values have string representations
        for status in allStatuses {
            XCTAssertFalse(status.rawValue.isEmpty, "Status \(status) should have non-empty raw value")
        }
        
        // Test specific status values
        XCTAssertEqual(FileStatus.waiting.rawValue, "waiting")
        XCTAssertEqual(FileStatus.imported.rawValue, "imported")
        XCTAssertEqual(FileStatus.failed.rawValue, "failed")
    }
    
    // MARK: - Real File System Operations
    
    /// Test creating files with various extensions in temp directory
    func testRealFileSystemOperations() throws {
        let testFiles = [
            ("photo.jpg", Data([0xFF, 0xD8, 0xFF, 0xE0])), // JPEG header
            ("video.mp4", Data([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70])), // MP4 header
            ("audio.mp3", Data([0x49, 0x44, 0x33])), // MP3 ID3 header
            ("document.txt", Data("Hello World".utf8))
        ]
        
        var createdFiles: [URL] = []
        
        for (filename, data) in testFiles {
            let fileURL = tempDir.appendingPathComponent(filename)
            XCTAssertTrue(fm.createFile(atPath: fileURL.path, contents: data))
            XCTAssertTrue(fm.fileExists(atPath: fileURL.path))
            createdFiles.append(fileURL)
            
            // Verify file size
            let attributes = try fm.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            XCTAssertEqual(fileSize, Int64(data.count))
        }
        
        // Test that we can enumerate the created files
        let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(contents.count, testFiles.count)
    }
    
    /// Test handling of file system edge cases
    func testFileSystemEdgeCases() throws {
        // Test with files that have special characters
        let specialNames = [
            "file with spaces.jpg",
            "file-with-dashes.jpg",
            "file_with_underscores.jpg",
            "file.with.dots.jpg"
        ]
        
        for filename in specialNames {
            let fileURL = tempDir.appendingPathComponent(filename)
            let testData = Data("test".utf8)
            
            XCTAssertTrue(fm.createFile(atPath: fileURL.path, contents: testData))
            XCTAssertTrue(fm.fileExists(atPath: fileURL.path))
            
            // Test that MediaType detection works with special characters
            let mediaType = MediaType.from(filePath: fileURL.path)
            XCTAssertEqual(mediaType, .image)
        }
    }
    
    // MARK: - Performance Validation
    
    /// Test that media type detection is fast
    func testMediaTypeDetectionPerformance() throws {
        let testPaths = (0..<1000).map { "file\($0).jpg" }
        
        measure {
            for path in testPaths {
                _ = MediaType.from(filePath: path)
            }
        }
    }
    
    /// Test File model creation performance
    func testFileModelCreationPerformance() throws {
        let basePath = tempDir.path
        
        measure {
            let files = (0..<1000).map { i in
                File(
                    sourcePath: "\(basePath)/file\(i).jpg",
                    mediaType: .image,
                    date: Date(),
                    size: Int64(i * 1024),
                    destPath: nil,
                    status: .waiting,
                    thumbnail: nil,
                    importError: nil
                )
            }
            XCTAssertEqual(files.count, 1000)
        }
    }
} 