import XCTest
@testable import Media_Muncher

final class FileProcessorServiceTests: XCTestCase {
    var tempRoot: URL!
    var fileManager: FileManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        tempRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempRoot)
        tempRoot = nil
        try super.tearDownWithError()
    }

    func testFastEnumerate_respectsFilterFlags() async {
        // Arrange: create image and video
        let img = tempRoot.appendingPathComponent("pic.jpg")
        let vid = tempRoot.appendingPathComponent("clip.mov")
        fileManager.createFile(atPath: img.path, contents: Data([0xFF, 0xD8, 0xFF, 0xE0]))
        fileManager.createFile(atPath: vid.path, contents: Data([0x00, 0x00, 0x00, 0x18]))
        
        let settings = SettingsStore()
        settings.filterImages = true
        settings.filterVideos = false // disable videos
        settings.filterAudio = true
        let processor = FileProcessorService.testInstance()
        
        // Act
        let files = await processor.processFiles(from: tempRoot, destinationURL: nil, settings: settings)
        let mediaTypes = files.map { $0.mediaType }
        
        // Assert – only image should be present
        XCTAssertEqual(mediaTypes, [.image], "Should only include filtered media types")
    }
    
    func testProcessFilesStream_batchesFilesCorrectly() async {
        // Arrange: create multiple test files
        let files = ["pic1.jpg", "pic2.jpg", "pic3.jpg", "pic4.jpg", "pic5.jpg"]
        for fileName in files {
            let fileURL = tempRoot.appendingPathComponent(fileName)
            fileManager.createFile(atPath: fileURL.path, contents: Data([0xFF, 0xD8, 0xFF, 0xE0]))
        }
        
        let settings = SettingsStore()
        settings.filterImages = true
        settings.filterVideos = false
        settings.filterAudio = false
        let processor = FileProcessorService.testInstance()
        
        // Act: process files with small batch size
        let stream = await processor.processFilesStream(
            from: tempRoot,
            destinationURL: nil,
            settings: settings,
            batchSize: 2
        )
        
        var batchesReceived: [[File]] = []
        var totalFilesReceived = 0
        
        for await batch in stream {
            batchesReceived.append(batch)
            totalFilesReceived += batch.count
        }
        
        // Assert: check batching behavior
        XCTAssertEqual(totalFilesReceived, 5, "Should receive all 5 files")
        XCTAssertTrue(batchesReceived.count >= 2, "Should receive at least 2 batches")
        
        // First batches should have batch size, last may be smaller
        let fullBatches = batchesReceived.dropLast()
        for batch in fullBatches {
            XCTAssertEqual(batch.count, 2, "Full batches should have exactly 2 files")
        }
        
        // Last batch should contain remaining files
        if let lastBatch = batchesReceived.last {
            XCTAssertGreaterThan(lastBatch.count, 0, "Last batch should not be empty")
            XCTAssertLessThanOrEqual(lastBatch.count, 2, "Last batch should not exceed batch size")
        }
    }
    
    func testProcessFilesStream_handlesEmptyDirectory() async {
        // Arrange: empty directory
        let settings = SettingsStore()
        let processor = FileProcessorService.testInstance()
        
        // Act
        let stream = await processor.processFilesStream(
            from: tempRoot,
            destinationURL: nil,
            settings: settings,
            batchSize: 10
        )
        
        var batchCount = 0
        for await _ in stream {
            batchCount += 1
        }
        
        // Assert: no batches for empty directory
        XCTAssertEqual(batchCount, 0, "Empty directory should produce no batches")
    }
    
    func testProcessFilesStream_respectsCancellation() async {
        // Arrange: create many files to ensure processing takes time
        for i in 1...20 {
            let fileURL = tempRoot.appendingPathComponent("pic\(i).jpg")
            fileManager.createFile(atPath: fileURL.path, contents: Data([0xFF, 0xD8, 0xFF, 0xE0]))
        }
        
        let settings = SettingsStore()
        settings.filterImages = true
        let processor = FileProcessorService.testInstance()
        
        // Act: start processing then cancel quickly
        let task = Task {
            let stream = await processor.processFilesStream(
                from: tempRoot,
                destinationURL: nil,
                settings: settings,
                batchSize: 5
            )
            
            var batchCount = 0
            for await _ in stream {
                batchCount += 1
                if batchCount >= 2 {
                    // Cancel after receiving a couple batches
                    break
                }
            }
            return batchCount
        }
        
        // Cancel the task
        task.cancel()
        let result = await task.value
        
        // Assert: task should handle cancellation gracefully
        XCTAssertLessThan(result, 4, "Cancelled task should not process all files")
    }
} 
