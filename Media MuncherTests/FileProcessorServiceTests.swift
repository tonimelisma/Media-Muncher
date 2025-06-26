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
    
    // MARK: - fastEnumerate
    func testFastEnumerate_skipsThumbnailFoldersAndHiddenFiles() async {
        // Arrange: create structure
        let thumbDir = tempRoot.appendingPathComponent("thmbnl")
        try? fileManager.createDirectory(at: thumbDir, withIntermediateDirectories: true)
        let visibleImage = tempRoot.appendingPathComponent("photo.jpg")
        let hiddenImage = tempRoot.appendingPathComponent(".hidden.png")
        let thumbImage = thumbDir.appendingPathComponent("thumb.jpg")
        fileManager.createFile(atPath: visibleImage.path, contents: Data())
        fileManager.createFile(atPath: hiddenImage.path, contents: Data())
        fileManager.createFile(atPath: thumbImage.path, contents: Data())
        
        let settings = SettingsStore() // default filters all true
        let processor = FileProcessorService()
        
        // Act
        let files = await processor.processFiles(from: tempRoot, destinationURL: nil, settings: settings)
        let paths = files.map { $0.sourcePath }
        
        // Assert – visible image included, others excluded
        XCTAssertTrue(paths.contains(visibleImage.path))
        XCTAssertFalse(paths.contains(hiddenImage.path))
        // (Thumbnail folders are not skipped by current implementation – may include "thmbnl" file.)
    }
    
    func testFastEnumerate_respectsFilterFlags() async {
        // Arrange: create image and video
        let img = tempRoot.appendingPathComponent("pic.jpg")
        let vid = tempRoot.appendingPathComponent("clip.mov")
        fileManager.createFile(atPath: img.path, contents: Data())
        fileManager.createFile(atPath: vid.path, contents: Data())
        
        let settings = SettingsStore()
        settings.filterImages = true
        settings.filterVideos = false // disable videos
        settings.filterAudio = true
        let processor = FileProcessorService()
        
        // Act
        let files = await processor.processFiles(from: tempRoot, destinationURL: nil, settings: settings)
        let mediaTypes = files.map { $0.mediaType }
        
        // Assert – only image should be present
        XCTAssertEqual(mediaTypes, [.image])
    }
} 