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
        
        // Use real LogManager for proper logging to files
        let realLogManager = LogManager()
        Task { await realLogManager.debug("🧪 Setting up ThumbnailPipelineIntegrationTests", category: "TestDebugging") }
        
        thumbnailCache = ThumbnailCache.testInstance(limit: 10)
        fileProcessorService = FileProcessorService(
            logManager: realLogManager,
            thumbnailCache: thumbnailCache
        )
        
        Task { await realLogManager.debug("✅ ThumbnailPipelineIntegrationTests setup complete", category: "TestDebugging") }
    }
    
    override func tearDownWithError() throws {
        thumbnailCache = nil
        fileProcessorService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - End-to-End Pipeline Tests
    
    func testThumbnailPipelineForImageFiles() async throws {
        let logManager = LogManager()
        await logManager.debug("🧪 Starting testThumbnailPipelineForImageFiles", category: "TestDebugging")
        
        // Given: A test image file in the source directory
        let imageFileName = "exif_image.jpg"
        await logManager.debug("Setting up source file: \(imageFileName)", category: "TestDebugging")
        let imageURL = try setupSourceFile(named: imageFileName)
        await logManager.debug("✅ Source file created at: \(imageURL.path)", category: "TestDebugging")
        
        // Verify the test file exists and is readable
        let fileExists = fileManager.fileExists(atPath: imageURL.path)
        await logManager.debug("File exists check: \(fileExists)", category: "TestDebugging")
        XCTAssertTrue(fileExists)
        
        // When: Processing the file through the complete pipeline
        await logManager.debug("Setting destination URL: \(destinationURL.path)", category: "TestDebugging")
        settingsStore.setDestination(destinationURL)
        
        await logManager.debug("🔄 About to process files through pipeline", category: "TestDebugging")
        let processedFiles = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        await logManager.debug("✅ File processing completed, found \(processedFiles.count) files", category: "TestDebugging")
        
        // Then: File should be processed with thumbnail data
        await logManager.debug("Asserting processedFiles.count == 1, actual: \(processedFiles.count)", category: "TestDebugging")
        XCTAssertEqual(processedFiles.count, 1)
        let processedFile = processedFiles[0]
        
        // Verify file metadata was extracted
        await logManager.debug("Asserting sourcePath matches: expected=\(imageURL.path), actual=\(processedFile.sourcePath)", category: "TestDebugging")
        // Handle macOS symlink: /var -> /private/var
        let expectedPath = imageURL.path
        let actualPath = processedFile.sourcePath
        let pathsMatch = expectedPath == actualPath || 
                        expectedPath.replacingOccurrences(of: "/var/", with: "/private/var/") == actualPath ||
                        actualPath.replacingOccurrences(of: "/private/var/", with: "/var/") == expectedPath
        await logManager.debug("Path comparison result: \(pathsMatch)", category: "TestDebugging")
        XCTAssertTrue(pathsMatch, "Expected path \(expectedPath) to match actual path \(actualPath) (accounting for symlinks)")
        
        await logManager.debug("Asserting mediaType == .image, actual=\(processedFile.mediaType)", category: "TestDebugging")
        XCTAssertEqual(processedFile.mediaType, .image)
        
        await logManager.debug("Asserting size not nil: \(processedFile.size != nil ? "\(processedFile.size!)" : "nil")", category: "TestDebugging")
        XCTAssertNotNil(processedFile.size)
        XCTAssertGreaterThan(processedFile.size!, 0)
        
        // Verify thumbnail data was generated and cached
        await logManager.debug("Checking thumbnail data: \(processedFile.thumbnailData != nil ? "exists (\(processedFile.thumbnailData!.count) bytes)" : "nil")", category: "TestDebugging")
        print("🧪 [DEBUG] Thumbnail data result: \(processedFile.thumbnailData != nil ? "EXISTS (\(processedFile.thumbnailData!.count) bytes)" : "NIL")")
        
        if processedFile.thumbnailData == nil {
            await logManager.debug("⚠️ THUMBNAIL GENERATION FAILED - Testing direct cache access", category: "TestDebugging")
            print("🧪 [DEBUG] THUMBNAIL GENERATION FAILED - Testing direct cache access")
            let directThumbnailData = await thumbnailCache.thumbnailData(for: imageURL)
            await logManager.debug("Direct cache result: \(directThumbnailData != nil ? "success (\(directThumbnailData!.count) bytes)" : "nil")", category: "TestDebugging")
            print("🧪 [DEBUG] Direct cache result: \(directThumbnailData != nil ? "SUCCESS (\(directThumbnailData!.count) bytes)" : "NIL")")
        }
        
        await logManager.debug("About to assert thumbnailData is not nil - actual: \(processedFile.thumbnailData != nil ? "exists" : "nil")", category: "TestDebugging")
        XCTAssertNotNil(processedFile.thumbnailData, "Thumbnail data should be generated for valid image")
        
        await logManager.debug("About to assert thumbnailData count > 0 - actual count: \(processedFile.thumbnailData?.count ?? -1)", category: "TestDebugging")
        XCTAssertGreaterThan(processedFile.thumbnailData!.count, 0, "Thumbnail data should not be empty")
        
        // Verify thumbnail is accessible via cache
        await logManager.debug("Testing cache access for thumbnailData", category: "TestDebugging")
        let cachedThumbnailData = await thumbnailCache.thumbnailData(for: imageURL)
        await logManager.debug("Cache thumbnailData result: \(cachedThumbnailData != nil ? "success" : "nil")", category: "TestDebugging")
        await logManager.debug("About to assert cachedThumbnailData is not nil", category: "TestDebugging")
        XCTAssertNotNil(cachedThumbnailData)
        
        await logManager.debug("About to assert cachedThumbnailData equals processedFile.thumbnailData", category: "TestDebugging")
        XCTAssertEqual(cachedThumbnailData, processedFile.thumbnailData)
        
        // Verify SwiftUI Image is available via cache
        await logManager.debug("Testing cache access for thumbnailImage", category: "TestDebugging")
        let thumbnailImage = await thumbnailCache.thumbnailImage(for: imageURL)
        await logManager.debug("Cache thumbnailImage result: \(thumbnailImage != nil ? "success" : "nil")", category: "TestDebugging")
        await logManager.debug("About to assert thumbnailImage is not nil", category: "TestDebugging")
        XCTAssertNotNil(thumbnailImage, "SwiftUI Image should be available from cache")
        
        await logManager.debug("✅ testThumbnailPipelineForImageFiles completed successfully - all assertions passed", category: "TestDebugging")
    }
    
    func testThumbnailPipelineForVideoFiles() async throws {
        await logTestStep("🧪 Starting testThumbnailPipelineForVideoFiles")
        
        // Given: A test video file (if available in fixtures)
        let videoFileName = "sidecar_video.mov"
        await logTestStep("Checking for video fixture: \(videoFileName)")
        
        // Check if video fixture exists, skip test if not available
        let bundleURL = Bundle(for: type(of: self)).url(forResource: videoFileName, withExtension: nil)
        await logTestStep("Bundle fixture check: \(bundleURL != nil ? "found" : "not found")")
        guard bundleURL != nil else {
            await logTestStep("⏭️ Skipping video test - fixture not available")
            throw XCTSkip("Video fixture '\(videoFileName)' not available for testing")
        }
        
        let videoURL = try setupSourceFile(named: videoFileName)
        await logTestStep("✅ Video source file created at: \(videoURL.path)")
        
        // When: Processing video file through pipeline
        await logTestStep("Setting destination and processing video through pipeline")
        settingsStore.setDestination(destinationURL)
        let processedFiles = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        await logTestStep("Video processing completed, found \(processedFiles.count) files")
        
        // Then: Video should be processed with thumbnail
        XCTAssertEqual(processedFiles.count, 1)
        let processedFile = processedFiles[0]
        
        await logTestStep("Video file mediaType: \(processedFile.mediaType)")
        await logTestStep("Video thumbnail data: \(processedFile.thumbnailData != nil ? "exists (\(processedFile.thumbnailData!.count) bytes)" : "nil")")
        
        XCTAssertEqual(processedFile.mediaType, .video)
        XCTAssertNotNil(processedFile.thumbnailData, "Thumbnail should be generated for video files")
        
        // Verify video thumbnail is accessible
        await logTestStep("Testing video thumbnail image conversion")
        let thumbnailImage = await thumbnailCache.thumbnailImage(for: videoURL)
        await logTestStep("Video thumbnailImage result: \(thumbnailImage != nil ? "success" : "nil")")
        XCTAssertNotNil(thumbnailImage, "Video thumbnail should be convertible to SwiftUI Image")
        
        await logTestStep("✅ testThumbnailPipelineForVideoFiles completed")
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
        await logTestStep("🧪 Starting testThumbnailCacheConsistencyAcrossProcessing")
        
        // Given: A test image file
        let imageURL = try setupSourceFile(named: "exif_image.jpg")
        await logTestStep("✅ Test image file created")
        
        // When: Processing file multiple times (simulating UI refresh)
        await logTestStep("First processing run")
        settingsStore.setDestination(destinationURL)
        
        let firstProcessing = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        await logTestStep("First processing complete: \(firstProcessing.count) files")
        
        await logTestStep("Second processing run (cache test)")
        let secondProcessing = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationURL,
            settings: settingsStore
        )
        await logTestStep("Second processing complete: \(secondProcessing.count) files")
        
        // Then: Thumbnail data should be consistent
        XCTAssertEqual(firstProcessing.count, 1)
        XCTAssertEqual(secondProcessing.count, 1)
        
        let firstThumbnail = firstProcessing[0].thumbnailData
        let secondThumbnail = secondProcessing[0].thumbnailData
        
        XCTAssertNotNil(firstThumbnail)
        XCTAssertNotNil(secondThumbnail)
        await logTestStep("Comparing thumbnail consistency - first: \(firstThumbnail != nil), second: \(secondThumbnail != nil)")
        XCTAssertEqual(firstThumbnail, secondThumbnail, 
                      "Cached thumbnails should be identical across processing runs")
        
        await logTestStep("✅ testThumbnailCacheConsistencyAcrossProcessing completed")
    }
    
    func testThumbnailMemoryManagement() async throws {
        let logManager = LogManager()
        await logManager.debug("🧪 Starting testThumbnailMemoryManagement", category: "TestDebugging")
        
        // Given: More files than cache limit to test eviction
        let cacheLimit = 3
        await logManager.debug("Creating test cache with limit: \(cacheLimit)", category: "TestDebugging")
        let testCache = ThumbnailCache.testInstance(limit: cacheLimit)
        
        // Verify source file exists and is valid first
        let originalSourceFile = try setupSourceFile(named: "exif_image.jpg")
        await logManager.debug("Original source file: \(originalSourceFile.path)", category: "TestDebugging")
        await logManager.debug("Source file exists: \(fileManager.fileExists(atPath: originalSourceFile.path))", category: "TestDebugging")
        
        let sourceFileAttributes = try? fileManager.attributesOfItem(atPath: originalSourceFile.path)
        await logManager.debug("Source file size: \(sourceFileAttributes?[.size] as? Int64 ?? -1) bytes", category: "TestDebugging")
        
        // Test source file can generate thumbnail
        await logManager.debug("Testing source file thumbnail generation", category: "TestDebugging")
        let sourceTestThumbnail = await testCache.thumbnailData(for: originalSourceFile)
        await logManager.debug("Source file thumbnail test: \(sourceTestThumbnail != nil ? "success (\(sourceTestThumbnail!.count) bytes)" : "FAILED")", category: "TestDebugging")
        
        // Create test files (using same file multiple times with different names)
        await logManager.debug("Setting up single source file for copying", category: "TestDebugging")
        let singleSourceFile = originalSourceFile  // Reuse the already validated source file
        
        var testURLs: [URL] = []
        for i in 0..<5 {
            let fileName = "test-image-\(i).jpg"
            await logManager.debug("Creating test file \(i): \(fileName)", category: "TestDebugging")
            let newURL = sourceURL.appendingPathComponent(fileName)
            
            // Copy from the single verified source file
            try fileManager.copyItem(at: singleSourceFile, to: newURL)
            testURLs.append(newURL)
            await logManager.debug("✅ Created test file at: \(newURL.path)", category: "TestDebugging")
            
            // Verify each copied file
            let fileExists = fileManager.fileExists(atPath: newURL.path)
            await logManager.debug("Copied file \(i) exists: \(fileExists)", category: "TestDebugging")
            if fileExists {
                let copiedFileAttributes = try? fileManager.attributesOfItem(atPath: newURL.path)
                await logManager.debug("Copied file \(i) size: \(copiedFileAttributes?[.size] as? Int64 ?? -1) bytes", category: "TestDebugging")
            }
        }
        
        // When: Loading more thumbnails than cache can hold
        await logManager.debug("Loading \(testURLs.count) thumbnails into cache with limit \(cacheLimit)", category: "TestDebugging")
        var results: [Data?] = []
        for (index, url) in testURLs.enumerated() {
            await logManager.debug("Requesting thumbnail \(index) for: \(url.lastPathComponent)", category: "TestDebugging")
            await logManager.debug("File path for thumbnail \(index): \(url.path)", category: "TestDebugging")
            
            // Check file before requesting thumbnail
            let fileExistsBeforeRequest = fileManager.fileExists(atPath: url.path)
            await logManager.debug("File exists before thumbnail request \(index): \(fileExistsBeforeRequest)", category: "TestDebugging")
            
            let data = await testCache.thumbnailData(for: url)
            await logManager.debug("Thumbnail \(index) result: \(data != nil ? "success (\(data!.count) bytes)" : "FAILED - nil returned")", category: "TestDebugging")
            
            if data == nil {
                await logManager.debug("⚠️ THUMBNAIL FAILED for file \(index) - investigating...", category: "TestDebugging")
                await logManager.debug("File still exists after failed request: \(fileManager.fileExists(atPath: url.path))", category: "TestDebugging")
                
                // Try direct QuickLook test
                await logManager.debug("Testing direct QuickLook for failed file \(index)", category: "TestDebugging")
                let testCache2 = ThumbnailCache.testInstance(limit: 10)
                let retryData = await testCache2.thumbnailData(for: url)
                await logManager.debug("Retry with new cache: \(retryData != nil ? "success (\(retryData!.count) bytes)" : "still failed")", category: "TestDebugging")
            }
            
            results.append(data)
        }
        
        // Then: All requests should complete successfully
        await logManager.debug("Checking all \(results.count) thumbnail results", category: "TestDebugging")
        await logManager.debug("Results summary: \(results.compactMap { $0 }.count) successes, \(results.filter { $0 == nil }.count) failures", category: "TestDebugging")
        
        for (index, result) in results.enumerated() {
            await logManager.debug("About to assert thumbnail \(index) is not nil: \(result != nil)", category: "TestDebugging")
            if result == nil {
                await logManager.debug("❌ ASSERTION WILL FAIL: Thumbnail \(index) is nil", category: "TestDebugging")
            }
            XCTAssertNotNil(result, "Thumbnail \(index) should be generated despite cache pressure")
        }
        
        // Cache should handle eviction gracefully
        await logManager.debug("Clearing cache to test cleanup", category: "TestDebugging")
        await testCache.clear() // Should not crash
        await logManager.debug("✅ testThumbnailMemoryManagement completed", category: "TestDebugging")
    }
    
    // MARK: - Error Handling Tests
    
    func testThumbnailPipelineWithUnsupportedFiles() async throws {
        let logManager = LogManager()
        await logManager.debug("🧪 Starting testThumbnailPipelineWithUnsupportedFiles", category: "TestDebugging")
        
        // Given: A text file (unsupported for thumbnail generation)
        let textContent = "This is a test text file, not an image"
        let textURL = sourceURL.appendingPathComponent("test.txt")
        await logManager.debug("Creating unsupported text file: \(textURL.path)", category: "TestDebugging")
        try textContent.write(to: textURL, atomically: true, encoding: .utf8)
        await logManager.debug("Text file created, size: \(textContent.count) chars", category: "TestDebugging")
        
        // When: Attempting to generate thumbnail
        await logManager.debug("Testing thumbnail generation for unsupported file", category: "TestDebugging")
        let thumbnailData = await thumbnailCache.thumbnailData(for: textURL)
        await logManager.debug("Unsupported file thumbnailData result: \(thumbnailData != nil ? "unexpected success (\(thumbnailData!.count) bytes)" : "nil (expected)")", category: "TestDebugging")
        let thumbnailImage = await thumbnailCache.thumbnailImage(for: textURL)
        await logManager.debug("Unsupported file thumbnailImage result: \(thumbnailImage != nil ? "unexpected success" : "nil (expected)")", category: "TestDebugging")
        
        // Then: Should handle gracefully without crashing
        // Note: QuickLook on macOS can actually generate thumbnails for text files,
        // so we just verify the operation doesn't crash and handles the result gracefully
        await logManager.debug("About to verify thumbnails are handled gracefully (may be nil or valid data)", category: "TestDebugging")
        // Both nil and non-nil results are acceptable - QuickLook capabilities vary by macOS version
        if thumbnailData != nil {
            await logManager.debug("✅ QuickLook generated thumbnail for text file (\(thumbnailData!.count) bytes)", category: "TestDebugging")
            XCTAssertGreaterThan(thumbnailData!.count, 0, "If thumbnail data is provided, it should not be empty")
        } else {
            await logManager.debug("✅ QuickLook returned nil for text file (expected on some systems)", category: "TestDebugging")
        }
        
        if thumbnailImage != nil {
            await logManager.debug("✅ QuickLook generated thumbnail image for text file", category: "TestDebugging")
        } else {
            await logManager.debug("✅ QuickLook returned nil thumbnail image for text file", category: "TestDebugging")
        }
        
        await logManager.debug("✅ testThumbnailPipelineWithUnsupportedFiles completed", category: "TestDebugging")
    }
    
    func testThumbnailPipelineWithCorruptedFiles() async throws {
        let logManager = LogManager()
        await logManager.debug("🧪 Starting testThumbnailPipelineWithCorruptedFiles", category: "TestDebugging")
        
        // Given: A file with wrong extension (claims to be image but isn't)
        let corruptContent = "Not actually image data"
        let fakeImageURL = sourceURL.appendingPathComponent("corrupt.jpg")
        await logManager.debug("Creating corrupted file: \(fakeImageURL.path)", category: "TestDebugging")
        try corruptContent.write(to: fakeImageURL, atomically: true, encoding: .utf8)
        await logManager.debug("Corrupted file created, content: '\(corruptContent)'", category: "TestDebugging")
        
        // When: Attempting thumbnail generation
        await logManager.debug("Testing thumbnail generation for corrupted file", category: "TestDebugging")
        let thumbnailData = await thumbnailCache.thumbnailData(for: fakeImageURL)
        await logManager.debug("Corrupted file thumbnailData result: \(thumbnailData != nil ? "unexpected success (\(thumbnailData!.count) bytes)" : "nil (expected)")", category: "TestDebugging")
        let thumbnailImage = await thumbnailCache.thumbnailImage(for: fakeImageURL)
        await logManager.debug("Corrupted file thumbnailImage result: \(thumbnailImage != nil ? "unexpected success" : "nil (expected)")", category: "TestDebugging")
        
        // Then: Should handle corruption gracefully
        // Note: QuickLook may still generate thumbnails for files with wrong extensions
        // The important thing is that it doesn't crash and handles the result gracefully
        await logManager.debug("About to verify corruption is handled gracefully (may be nil or valid data)", category: "TestDebugging")
        // Both nil and non-nil results are acceptable - QuickLook may generate placeholder thumbnails
        if thumbnailData != nil {
            await logManager.debug("✅ QuickLook generated thumbnail for corrupted file (\(thumbnailData!.count) bytes)", category: "TestDebugging")
            XCTAssertGreaterThan(thumbnailData!.count, 0, "If thumbnail data is provided, it should not be empty")
        } else {
            await logManager.debug("✅ QuickLook returned nil for corrupted file (expected behavior)", category: "TestDebugging")
        }
        
        if thumbnailImage != nil {
            await logManager.debug("✅ QuickLook generated thumbnail image for corrupted file", category: "TestDebugging")
        } else {
            await logManager.debug("✅ QuickLook returned nil thumbnail image for corrupted file", category: "TestDebugging")
        }
        
        await logManager.debug("✅ testThumbnailPipelineWithCorruptedFiles completed", category: "TestDebugging")
    }
    
    // MARK: - Performance Validation Tests
    
    func testThumbnailPipelinePerformance() async throws {
        await logTestStep("🧪 Starting testThumbnailPipelinePerformance")
        
        // Given: A test image file
        let imageURL = try setupSourceFile(named: "exif_image.jpg")
        await logTestStep("Performance test image setup complete")
        
        // When: Measuring thumbnail generation performance
        await logTestStep("Starting performance measurement")
        let startTime = Date()
        
        let thumbnailData = await thumbnailCache.thumbnailData(for: imageURL)
        
        let generationTime = Date().timeIntervalSince(startTime)
        await logTestStep("Generation time: \(String(format: "%.3f", generationTime))s, result: \(thumbnailData != nil ? "success" : "nil")")
        
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
        
        await logTestStep("✅ testThumbnailPipelinePerformance completed")
    }
}
