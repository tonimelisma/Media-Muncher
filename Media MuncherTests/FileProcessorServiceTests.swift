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
        let processor = FileProcessorService()
        
        // Act
        let files = await processor.processFiles(from: tempRoot, destinationURL: nil, settings: settings)
        let mediaTypes = files.map { $0.mediaType }
        
        // Assert – only image should be present
        XCTAssertEqual(mediaTypes, [.image], "Should only include filtered media types")
    }
} 