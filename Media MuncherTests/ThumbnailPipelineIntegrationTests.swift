//
//  ThumbnailPipelineIntegrationTests.swift
//  Media MuncherTests
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import XCTest
import SwiftUI
@testable import Media_Muncher

/// End-to-end integration tests for the complete thumbnail pipeline.
/// These tests address FIX.md Issue 16 by validating the entire flow from
/// file discovery through thumbnail generation to UI display.
@MainActor  
final class ThumbnailPipelineIntegrationTests: IntegrationTestCase {
    
    var thumbnailCache: ThumbnailCache!
    var fileProcessorService: FileProcessorService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        thumbnailCache = ThumbnailCache(limit: 10)
        fileProcessorService = FileProcessorService(
            logManager: MockLogManager.shared,
            thumbnailCache: thumbnailCache
        )
    }
    
    override func tearDownWithError() throws {
        thumbnailCache = nil
        fileProcessorService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - End-to-End Pipeline Tests
    
    func testThumbnailPipelineForImageFiles() async throws {
        // Given: A test image file in the source directory
        let imageFileName = "exif_image.jpg"
        let imageURL = try setupSourceFile(named: imageFileName)
        
        // Verify the test file exists and is readable
        XCTAssertTrue(fileManager.fileExists(atPath: imageURL.path))
        
        // When: Processing the file through the complete pipeline
        settingsStore.setDestination(destinationURL)
        let processedFiles = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        
        // Then: File should be processed with thumbnail data
        XCTAssertEqual(processedFiles.count, 1)
        let processedFile = processedFiles[0]
        
        // Verify file metadata was extracted
        XCTAssertEqual(processedFile.sourcePath, imageURL.path)
        XCTAssertEqual(processedFile.mediaType, .image)
        XCTAssertNotNil(processedFile.size)
        XCTAssertGreaterThan(processedFile.size!, 0)
        
        // Verify thumbnail data was generated and cached
        XCTAssertNotNil(processedFile.thumbnailData, "Thumbnail data should be generated for valid image")
        XCTAssertGreaterThan(processedFile.thumbnailData!.count, 0, "Thumbnail data should not be empty")
        
        // Verify thumbnail is accessible via cache
        let cachedThumbnailData = await thumbnailCache.thumbnailData(for: imageURL)
        XCTAssertNotNil(cachedThumbnailData)
        XCTAssertEqual(cachedThumbnailData, processedFile.thumbnailData)
        
        // Verify SwiftUI Image is available via cache
        let thumbnailImage = await thumbnailCache.thumbnailImage(for: imageURL)
        XCTAssertNotNil(thumbnailImage, "SwiftUI Image should be available from cache")
    }
    
    func testThumbnailPipelineForVideoFiles() async throws {
        // Given: A test video file (if available in fixtures)
        let videoFileName = "sidecar_video.mov"
        
        // Check if video fixture exists, skip test if not available
        guard Bundle(for: type(of: self)).url(forResource: videoFileName, withExtension: nil) != nil else {
            throw XCTSkip("Video fixture '\(videoFileName)' not available for testing")
        }
        
        let videoURL = try setupSourceFile(named: videoFileName)
        
        // When: Processing video file through pipeline
        settingsStore.setDestination(destinationURL)
        let processedFiles = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        
        // Then: Video should be processed with thumbnail
        XCTAssertEqual(processedFiles.count, 1)
        let processedFile = processedFiles[0]
        
        XCTAssertEqual(processedFile.mediaType, .video)
        XCTAssertNotNil(processedFile.thumbnailData, "Thumbnail should be generated for video files")
        
        // Verify video thumbnail is accessible
        let thumbnailImage = await thumbnailCache.thumbnailImage(for: videoURL)
        XCTAssertNotNil(thumbnailImage, "Video thumbnail should be convertible to SwiftUI Image")
    }
    
    func testThumbnailPipelineWithMultipleFiles() async throws {
        // Given: Multiple test files with different types
        let fileNames = ["exif_image.jpg"] // Add more if fixtures available
        var setupURLs: [URL] = []
        
        for fileName in fileNames {
            if Bundle(for: type(of: self)).url(forResource: fileName, withExtension: nil) != nil {
                let url = try setupSourceFile(named: fileName)
                setupURLs.append(url)
            }
        }
        
        guard !setupURLs.isEmpty else {
            throw XCTSkip("No test fixtures available for multi-file pipeline test")
        }
        
        // When: Processing multiple files
        settingsStore.setDestination(destinationURL)
        let processedFiles = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        
        // Then: All files should have thumbnails
        XCTAssertEqual(processedFiles.count, setupURLs.count)
        
        for processedFile in processedFiles {
            XCTAssertNotNil(processedFile.thumbnailData, 
                           "File \(processedFile.sourceName) should have thumbnail data")
            
            // Verify each thumbnail is cached and accessible
            let fileURL = URL(fileURLWithPath: processedFile.sourcePath)
            let thumbnailImage = await thumbnailCache.thumbnailImage(for: fileURL)
            XCTAssertNotNil(thumbnailImage, 
                           "File \(processedFile.sourceName) should have cached SwiftUI Image")
        }
    }
    
    // MARK: - Cache Integration Tests
    
    func testThumbnailCacheConsistencyAcrossProcessing() async throws {
        // Given: A test image file
        let imageURL = try setupSourceFile(named: "exif_image.jpg")
        
        // When: Processing file multiple times (simulating UI refresh)
        settingsStore.setDestination(destinationURL)
        
        let firstProcessing = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        
        let secondProcessing = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        
        // Then: Thumbnail data should be consistent
        XCTAssertEqual(firstProcessing.count, 1)
        XCTAssertEqual(secondProcessing.count, 1)
        
        let firstThumbnail = firstProcessing[0].thumbnailData
        let secondThumbnail = secondProcessing[0].thumbnailData
        
        XCTAssertNotNil(firstThumbnail)
        XCTAssertNotNil(secondThumbnail)
        XCTAssertEqual(firstThumbnail, secondThumbnail, 
                      "Cached thumbnails should be identical across processing runs")
    }
    
    func testThumbnailMemoryManagement() async throws {
        // Given: More files than cache limit to test eviction
        let cacheLimit = 3
        let testCache = ThumbnailCache(limit: cacheLimit)
        
        // Create test files (using same file multiple times with different names)
        var testURLs: [URL] = []
        for i in 0..<5 {
            let fileName = "test-image-\(i).jpg"
            let sourceFile = try setupSourceFile(named: "exif_image.jpg")
            let newURL = sourceURL.appendingPathComponent(fileName)
            try fileManager.copyItem(at: sourceFile, to: newURL)
            testURLs.append(newURL)
        }
        
        // When: Loading more thumbnails than cache can hold
        var results: [Data?] = []
        for url in testURLs {
            let data = await testCache.thumbnailData(for: url)
            results.append(data)
        }
        
        // Then: All requests should complete successfully
        // (Memory management should prevent crashes)
        for (index, result) in results.enumerated() {
            XCTAssertNotNil(result, "Thumbnail \(index) should be generated despite cache pressure")
        }
        
        // Cache should handle eviction gracefully
        await testCache.clear() // Should not crash
    }
    
    // MARK: - Error Handling Tests
    
    func testThumbnailPipelineWithUnsupportedFiles() async throws {
        // Given: A text file (unsupported for thumbnail generation)
        let textContent = "This is a test text file, not an image"
        let textURL = sourceURL.appendingPathComponent("test.txt")
        try textContent.write(to: textURL, atomically: true, encoding: .utf8)
        
        // When: Attempting to generate thumbnail
        let thumbnailData = await thumbnailCache.thumbnailData(for: textURL)
        let thumbnailImage = await thumbnailCache.thumbnailImage(for: textURL)
        
        // Then: Should handle gracefully without crashing
        XCTAssertNil(thumbnailData, "Unsupported file should return nil thumbnail data")
        XCTAssertNil(thumbnailImage, "Unsupported file should return nil thumbnail image")
    }
    
    func testThumbnailPipelineWithCorruptedFiles() async throws {
        // Given: A file with wrong extension (claims to be image but isn't)
        let corruptContent = "Not actually image data"
        let fakeImageURL = sourceURL.appendingPathComponent("corrupt.jpg")
        try corruptContent.write(to: fakeImageURL, atomically: true, encoding: .utf8)
        
        // When: Attempting thumbnail generation
        let thumbnailData = await thumbnailCache.thumbnailData(for: fakeImageURL)
        let thumbnailImage = await thumbnailCache.thumbnailImage(for: fakeImageURL)
        
        // Then: Should handle corruption gracefully
        XCTAssertNil(thumbnailData, "Corrupted file should return nil thumbnail data")
        XCTAssertNil(thumbnailImage, "Corrupted file should return nil thumbnail image")
    }
    
    // MARK: - Performance Validation Tests
    
    func testThumbnailPipelinePerformance() async throws {
        // Given: A test image file
        let imageURL = try setupSourceFile(named: "exif_image.jpg")
        
        // When: Measuring thumbnail generation performance
        let startTime = Date()
        
        let thumbnailData = await thumbnailCache.thumbnailData(for: imageURL)
        
        let generationTime = Date().timeIntervalSince(startTime)
        
        // Then: Performance should be reasonable
        XCTAssertNotNil(thumbnailData)
        XCTAssertLessThan(generationTime, 5.0, "Thumbnail generation should complete within 5 seconds")
        
        // Second call should be much faster (cached)
        let cachedStartTime = Date()
        let cachedThumbnail = await thumbnailCache.thumbnailData(for: imageURL)
        let cachedTime = Date().timeIntervalSince(cachedStartTime)
        
        XCTAssertNotNil(cachedThumbnail)
        XCTAssertLessThan(cachedTime, 0.1, "Cached thumbnail should return within 100ms")
        XCTAssertEqual(cachedThumbnail, thumbnailData, "Cached thumbnail should match original")
    }
}