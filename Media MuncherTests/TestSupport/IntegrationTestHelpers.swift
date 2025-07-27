//
//  IntegrationTestHelpers.swift
//  Media MuncherTests
//
//  Integration test helper utilities for async coordination and file setup.
//

import XCTest
import Combine
import Foundation
@testable import Media_Muncher

extension XCTestCase {
    
    /// Helper for coordinating multiple publisher expectations with clear error reporting.
    /// This pattern follows ASYNC_TEST_PATTERNS.md for proper publisher-based coordination.
    func coordinatePublishers<T, U>(
        _ first: AnyPublisher<T, Never>,
        _ second: AnyPublisher<U, Never>,
        firstDescription: String,
        secondDescription: String,
        timeout: TimeInterval = 5.0,
        firstCondition: @escaping (T) -> Bool,
        secondCondition: @escaping (U) -> Bool
    ) async throws -> (T, U) {
        
        async let firstResult = try await waitForPublisher(
            first,
            timeout: timeout,
            description: firstDescription,
            satisfies: firstCondition
        )
        
        async let secondResult = try await waitForPublisher(
            second,
            timeout: timeout,
            description: secondDescription,
            satisfies: secondCondition
        )
        
        return try await (firstResult, secondResult)
    }
    
    /// Creates a realistic file structure for integration testing.
    /// Returns the URLs of created files for further test operations.
    func createTestFileStructure(in directory: URL) throws -> [URL] {
        var createdFiles: [URL] = []
        
        // Create main media files
        let imageFile = directory.appendingPathComponent("photo.jpg")
        let videoFile = directory.appendingPathComponent("video.mov")
        let audioFile = directory.appendingPathComponent("audio.mp3")
        
        // Create files with proper signatures for media type detection
        try TestDataFactory.jpegSignature.write(to: imageFile)
        try TestDataFactory.movSignature.write(to: videoFile)
        try TestDataFactory.mp3Signature.write(to: audioFile)
        
        createdFiles.append(contentsOf: [imageFile, videoFile, audioFile])
        
        // Create sidecar files for video
        let xmpFile = directory.appendingPathComponent("video.xmp")
        let thmFile = directory.appendingPathComponent("video.thm")
        try Data("XMP sidecar".utf8).write(to: xmpFile)
        try Data("THM thumbnail".utf8).write(to: thmFile)
        
        createdFiles.append(contentsOf: [xmpFile, thmFile])
        
        return createdFiles
    }
    
    /// Creates a pre-existing file in destination to test collision handling.
    func createPreExistingFile(source: URL, destination: URL) throws {
        let sourceData = try Data(contentsOf: source)
        try sourceData.write(to: destination)
        
        // Set same modification time to ensure it's detected as pre-existing
        let sourceAttributes = try FileManager.default.attributesOfItem(atPath: source.path)
        if let modDate = sourceAttributes[.modificationDate] as? Date {
            try FileManager.default.setAttributes([.modificationDate: modDate], ofItemAtPath: destination.path)
        }
    }
    
    /// Waits for a specific number of files to be processed and available in FileStore.
    /// This is a common pattern in integration tests for file discovery completion.
    func waitForFileProcessing(
        fileStore: FileStore,
        expectedCount: Int,
        timeout: TimeInterval = 10.0,
        description: String = "File processing completion"
    ) async throws {
        _ = try await waitForPublisher(
            fileStore.$files.eraseToAnyPublisher(),
            timeout: timeout,
            description: description
        ) { files in
            files.count >= expectedCount
        }
    }
    
    /// Verifies that all files have valid destination paths with expected directory.
    func assertValidDestinationPaths(
        files: [File],
        expectedDirectory: URL,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for mediaFile in files {
            XCTAssertNotNil(mediaFile.destPath, "File \(mediaFile.sourceName) should have destination path", file: file, line: line)
            XCTAssertTrue(
                mediaFile.destPath?.hasPrefix(expectedDirectory.path) ?? false,
                "File \(mediaFile.sourceName) destination should be in expected directory",
                file: file, line: line
            )
        }
    }
}