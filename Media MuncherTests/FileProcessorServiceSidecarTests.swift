import XCTest
@testable import Media_Muncher

final class FileProcessorServiceSidecarTests: XCTestCase {
    var rootDir: URL!
    var fileManager: FileManager!
    var settings: SettingsStore!
    private var logManager: LogManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        rootDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: rootDir, withIntermediateDirectories: true)
        logManager = LogManager()
        settings = SettingsStore(logManager: logManager)
        settings.filterImages = true
        settings.filterVideos = true
        settings.filterAudio = true
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: rootDir)
        rootDir = nil
        settings = nil
        fileManager = nil
        try super.tearDownWithError()
    }

    private func createFile(at url: URL) {
        fileManager.createFile(atPath: url.path, contents: Data([0x00]))
    }

    func testFastEnumerate_attachesSidecarPaths() async throws {
        // Arrange – video with THM sidecar
        let video = rootDir.appendingPathComponent("clip.mov")
        let sidecar = rootDir.appendingPathComponent("clip.thm")
        createFile(at: video)
        createFile(at: sidecar)

        let processor = FileProcessorService(logManager: logManager)

        // Act
        let files = await processor.processFiles(from: rootDir, destinationURL: nil, settings: settings)
        if let f = files.first {
            logManager.debug("sidecarPaths", category: "FileProcessorServiceSidecarTests", metadata: ["paths": f.sidecarPaths.joined(separator: ", ")])
        } else {
            logManager.debug("files empty", category: "FileProcessorServiceSidecarTests")
        }

        // Assert – only main video returned and sidecar attached
        XCTAssertEqual(files.count, 1)
        guard let file = files.first else { return }
        XCTAssertEqual(file.mediaType, .video)
        XCTAssertTrue(file.sidecarPaths.contains { $0.lowercased().hasSuffix(".thm") }, "Expected .thm sidecar to be attached, got \(file.sidecarPaths)")
    }
} 