import XCTest
import Combine
@testable import Media_Muncher

@MainActor
final class AppStateRecalculationTests: XCTestCase {
    var sourceURL: URL!
    var destA_URL: URL!
    var destB_URL: URL!
    var fileManager: FileManager!
    var settingsStore: SettingsStore!
    var fileProcessorService: FileProcessorService!
    var importService: ImportService!
    var volumeManager: VolumeManager!
    var appState: AppState!
    private var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        cancellables = []

        let testRunID = UUID().uuidString
        sourceURL = fileManager.temporaryDirectory.appendingPathComponent("test_source_\(testRunID)")
        destA_URL = fileManager.temporaryDirectory.appendingPathComponent("test_destA_\(testRunID)")
        destB_URL = fileManager.temporaryDirectory.appendingPathComponent("test_destB_\(testRunID)")
        
        try? fileManager.removeItem(at: sourceURL)
        try? fileManager.removeItem(at: destA_URL)
        try? fileManager.removeItem(at: destB_URL)
        
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destA_URL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destB_URL, withIntermediateDirectories: true)

        settingsStore = SettingsStore()
        fileProcessorService = FileProcessorService()
        importService = ImportService()
        volumeManager = VolumeManager()

        appState = AppState(
            volumeManager: volumeManager,
            mediaScanner: fileProcessorService,
            settingsStore: settingsStore,
            importService: importService
        )
    }

    override func tearDownWithError() throws {
        // Cancel any ongoing operations
        appState.cancelScan()
        appState.cancelImport()
        
        // Clear state
        appState.files = []
        appState.state = .idle
        appState.error = nil
        
        // Remove test directories
        try? fileManager.removeItem(at: sourceURL)
        try? fileManager.removeItem(at: destA_URL)
        try? fileManager.removeItem(at: destB_URL)
        
        // Clear references
        cancellables = nil
        sourceURL = nil
        destA_URL = nil
        destB_URL = nil
        settingsStore = nil
        fileProcessorService = nil
        importService = nil
        volumeManager = nil
        appState = nil
        
        try super.tearDownWithError()
    }

    private func createFile(at url: URL, content: Data = Data([0xAB])) {
        fileManager.createFile(atPath: url.path, contents: content)
    }
    
    // Manually trigger a scan and wait for it to complete.
    

    func testRecalculationIsProperlyGatedByFilePresence() {
        XCTAssertTrue(appState.files.isEmpty, "Should start with no files")

        var filesChangedCount = 0
        appState.$files
            .dropFirst()
            .sink { _ in filesChangedCount += 1 }
            .store(in: &cancellables)

        settingsStore.setDestination(destA_URL)
        settingsStore.setDestination(destB_URL)
        settingsStore.setDestination(destA_URL)

        XCTAssertEqual(filesChangedCount, 0, "Files array should not change when no files are loaded")
        XCTAssertTrue(appState.files.isEmpty, "Files should remain empty")
    }

    func testRecalculationHandlesRapidDestinationChanges() async throws {
        // Arrange
        let testFile = sourceURL.appendingPathComponent("test.jpg")
        createFile(at: testFile)
        settingsStore.setDestination(destA_URL)

        // Act: Perform initial scan directly (bypassing volume selection which doesn't work in tests)
        let processedFiles = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destA_URL,
            settings: settingsStore
        )
        appState.files = processedFiles

        // Assert initial scan results
        XCTAssertEqual(appState.files.count, 1, "Should have loaded one file after initial scan")
        XCTAssertEqual(appState.files.first?.destPath, destA_URL.appendingPathComponent("test.jpg").path, "Initial destination path should be correct")

        // Act: Test rapid destination changes through the real AppState flow
        settingsStore.setDestination(destB_URL)
        
        // Wait for recalculation to complete
        var attempts = 0
        while appState.isRecalculating && attempts < 50 {
            try await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }

        // Assert: AppState should have updated files automatically via handleDestinationChange
        XCTAssertEqual(appState.files.count, 1, "File count should remain stable after recalculation")
        XCTAssertFalse(appState.isRecalculating, "Should not be recalculating after completion")
        XCTAssertEqual(appState.files.first?.destPath, destB_URL.appendingPathComponent("test.jpg").path, "Final destination path should reflect the last setting")
        XCTAssertEqual(settingsStore.destinationURL, destB_URL, "SettingsStore destination should be correct")
    }

    func testRecalculationWithComplexFileStatuses() async throws {
        // Arrange
        let regularFile = sourceURL.appendingPathComponent("regular.jpg")
        let preExistingFile = sourceURL.appendingPathComponent("existing.jpg")
        let videoWithSidecar = sourceURL.appendingPathComponent("video.mov")
        let sidecar = sourceURL.appendingPathComponent("video.xmp")
        
        createFile(at: regularFile)
        createFile(at: preExistingFile)
        createFile(at: videoWithSidecar)
        createFile(at: sidecar)
        
        // Create a pre-existing file in destA
        try fileManager.copyItem(at: preExistingFile, to: destA_URL.appendingPathComponent("existing.jpg"))
        
        settingsStore.setDestination(destA_URL)

        // Act: Perform initial scan directly (bypassing volume selection which doesn't work in tests)
        let processedFiles = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destA_URL,
            settings: settingsStore
        )
        appState.files = processedFiles
        
        // Assert initial scan results
        XCTAssertEqual(appState.files.count, 3, "Should load 3 primary files (regular, existing, video)")
        XCTAssertEqual(appState.files.first { $0.sourceName == "existing.jpg" }?.status, .pre_existing, "Pre-existing file should be marked as such")
        XCTAssertFalse(appState.files.first { $0.sourceName == "video.mov" }!.sidecarPaths.isEmpty, "Video should have associated sidecar paths")

        // Act: Change destination through real AppState flow
        settingsStore.setDestination(destB_URL)
        
        // Wait for recalculation to complete
        var attempts = 0
        while appState.isRecalculating && attempts < 50 {
            try await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }
        
        // Assert: Verify files after automatic recalculation
        XCTAssertEqual(appState.files.count, 3, "File count should remain stable after recalculation")
        XCTAssertFalse(appState.isRecalculating, "Should not be recalculating after completion")
        XCTAssertTrue(appState.files.allSatisfy { $0.status == .waiting }, "All files should be .waiting after destination change (unless duplicate_in_source)")
        XCTAssertFalse(appState.files.first { $0.sourceName == "video.mov" }!.sidecarPaths.isEmpty, "Sidecar paths should be preserved after recalculation")
        XCTAssertEqual(appState.files.first { $0.sourceName == "regular.jpg" }?.destPath, destB_URL.appendingPathComponent("regular.jpg").path)
        XCTAssertEqual(appState.files.first { $0.sourceName == "existing.jpg" }?.destPath, destB_URL.appendingPathComponent("existing.jpg").path)
        XCTAssertEqual(appState.files.first { $0.sourceName == "video.mov" }?.destPath, destB_URL.appendingPathComponent("video.mov").path)
    }

    func testDestinationChangeTriggersRecalculation() async throws {
        // Arrange
        let testFile = sourceURL.appendingPathComponent("test.jpg")
        createFile(at: testFile)
        settingsStore.setDestination(destA_URL)

        // Act: Perform initial scan directly (bypassing volume selection which doesn't work in tests)
        let processedFiles = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destA_URL,
            settings: settingsStore
        )
        appState.files = processedFiles

        // Assert initial state
        XCTAssertEqual(appState.files.count, 1)
        XCTAssertEqual(appState.files.first?.status, .waiting)
        XCTAssertEqual(appState.files.first?.destPath, destA_URL.appendingPathComponent("test.jpg").path)

        // Act: Change destination through real AppState flow (this triggers handleDestinationChange)
        settingsStore.setDestination(destB_URL)
        
        // Wait for recalculation to complete
        var attempts = 0
        while appState.isRecalculating && attempts < 50 {
            try await Task.sleep(nanoseconds: 10_000_000)
            attempts += 1
        }

        // Assert: Verify automatic recalculation
        XCTAssertEqual(appState.files.count, 1)
        XCTAssertFalse(appState.isRecalculating, "Should not be recalculating after completion")
        XCTAssertEqual(appState.files.first?.status, .waiting) // Should still be waiting
        XCTAssertEqual(appState.files.first?.destPath, destB_URL.appendingPathComponent("test.jpg").path)
    }
}
