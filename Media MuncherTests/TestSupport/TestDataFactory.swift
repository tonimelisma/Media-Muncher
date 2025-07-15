import Foundation
import XCTest
@testable import Media_Muncher

/// Factory methods for creating test data and common test objects
struct TestDataFactory {
    
    // MARK: - File Creation
    
    /// Creates a test File object with specified parameters
    static func createTestFile(
        name: String,
        mediaType: MediaType = .image,
        date: Date = Date(),
        size: Int64 = 1024,
        sourcePath: String? = nil
    ) -> File {
        let path = sourcePath ?? "/Volumes/TestVolume/\(name)"
        return File(
            sourcePath: path,
            mediaType: mediaType,
            date: date,
            size: size,
            destPath: nil,
            status: .waiting,
            thumbnail: nil,
            importError: nil
        )
    }
    
    /// Creates a test Volume object
    static func createTestVolume(
        name: String = "TestVolume",
        devicePath: String = "/Volumes/TestVolume",
        volumeUUID: String = "test-uuid-\(UUID().uuidString)"
    ) -> Volume {
        return Volume(
            name: name,
            devicePath: devicePath,
            volumeUUID: volumeUUID
        )
    }
    
    // MARK: - Media File Signatures
    
    /// JPEG file signature for creating valid image files
    static let jpegSignature = Data([0xFF, 0xD8, 0xFF, 0xE0])
    
    /// HEIC file signature
    static let heicSignature = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63])
    
    /// MOV file signature
    static let movSignature = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x71, 0x74, 0x20, 0x20])
    
    /// MP3 file signature
    static let mp3Signature = Data([0xFF, 0xFB, 0x90, 0x00])
    
    // MARK: - File System Helpers
    
    /// Creates a media file with proper signature based on extension
    static func createMediaFile(named fileName: String, in directory: URL, fileManager: FileManager = .default) throws -> URL {
        let fileURL = directory.appendingPathComponent(fileName)
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        
        let signature: Data
        switch ext {
        case "jpg", "jpeg":
            signature = jpegSignature
        case "heic":
            signature = heicSignature
        case "mov":
            signature = movSignature
        case "mp3":
            signature = mp3Signature
        default:
            signature = Data("test content".utf8)
        }
        
        try signature.write(to: fileURL)
        return fileURL
    }
    
    /// Creates multiple test files with different types
    static func createTestFileSet(in directory: URL, fileManager: FileManager = .default) throws -> [URL] {
        let files = [
            "test_image.jpg",
            "test_video.mov", 
            "test_audio.mp3",
            "test_heic.heic"
        ]
        
        return try files.map { fileName in
            try createMediaFile(named: fileName, in: directory, fileManager: fileManager)
        }
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {
    
    /// Waits for a condition to become true with a timeout
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        description: String,
        condition: @escaping () -> Bool
    ) async throws {
        let expectation = XCTestExpectation(description: description)
        
        Task {
            while !condition() {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                try Task.checkCancellation()
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: timeout)
    }
    
    /// Compares two files for equality
    func assertFilesEqual(
        _ file1: URL,
        _ file2: URL,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            let data1 = try Data(contentsOf: file1)
            let data2 = try Data(contentsOf: file2)
            XCTAssertEqual(data1, data2, "Files should be equal", file: file, line: line)
        } catch {
            XCTFail("Failed to compare files: \(error)", file: file, line: line)
        }
    }
    
    /// Asserts that a file exists at the given path
    func assertFileExists(
        at url: URL,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "File should exist at \(url.path)",
            file: file,
            line: line
        )
    }
    
    /// Asserts that a file does not exist at the given path  
    func assertFileDoesNotExist(
        at url: URL,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: url.path),
            "File should not exist at \(url.path)",
            file: file,
            line: line
        )
    }
}