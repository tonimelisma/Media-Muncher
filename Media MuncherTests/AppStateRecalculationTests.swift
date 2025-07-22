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
    private var logManager: LogManager!

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

        // Use isolated UserDefaults for test
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        logManager = LogManager()
        settingsStore = SettingsStore(logManager: logManager, userDefaults: testDefaults)
        fileProcessorService = FileProcessorService(logManager: logManager)
        importService = ImportService(logManager: logManager)
        volumeManager = VolumeManager(logManager: logManager)

        // Instantiate RecalculationManager first
        let recalculationManager = RecalculationManager(
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore
        )

        let fileStore = FileStore(logManager: logManager)
        
        appState = AppState(
            logManager: logManager,
            volumeManager: volumeManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore,
            importService: importService,
            recalculationManager: recalculationManager,
            fileStore: fileStore
        )
    }

    override func tearDownWithError() throws {
        // Cancel any ongoing operations
        appState.cancelScan()
        appState.cancelImport()
        
        // Clear state
        appState.fileStore.clearFiles()
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
        XCTAssertTrue(appState.fileStore.files.isEmpty, "Should start with no files")

        var filesChangedCount = 0
        appState.fileStore.$files
            .dropFirst()
            .sink { _ in filesChangedCount += 1 }
            .store(in: &cancellables)

        settingsStore.setDestination(destA_URL)
        settingsStore.setDestination(destB_URL)
        settingsStore.setDestination(destA_URL)

        XCTAssertEqual(filesChangedCount, 0, "Files array should not change when no files are loaded")
        XCTAssertTrue(appState.fileStore.files.isEmpty, "Files should remain empty")
    }

    func testRecalculationHandlesRapidDestinationChanges() async throws {
        // This test validates the complete integration flow:
        // 1. Real file system setup
        // 2. Full AppState scanning (not manual file creation)
        // 3. Destination change triggering RecalculationManager
        // 4. Proper async coordination between all services
        
        // Arrange: Create real test file
        let testFile = sourceURL.appendingPathComponent("test.jpg")
        createFile(at: testFile)
        
        // Set initial destination and trigger full scan
        settingsStore.setDestination(destA_URL)
        let testVolume = Volume(name: "Test", devicePath: sourceURL.path, volumeUUID: UUID().uuidString)
        appState.volumes = [testVolume]
        appState.selectedVolumeID = testVolume.id
        
        // Wait for initial scan to complete (this is the real integration test)
        try await waitForCondition(timeout: 5.0, description: "Initial scan") {
            self.appState.fileStore.files.count >= 1 && self.appState.state == .idle
        }
        
        // Verify initial scan worked correctly
        XCTAssertEqual(appState.fileStore.files.count, 1, "Should have scanned one test file")
        XCTAssertEqual(appState.fileStore.files.first?.status, .waiting, "File should be in waiting status")
        XCTAssertTrue(appState.fileStore.files.first?.destPath?.contains(destA_URL.lastPathComponent) ?? false, "File should have destA path")
        
        // Act: Change destination (this should trigger RecalculationManager)
        settingsStore.setDestination(destB_URL)
        
        // Wait for recalculation to complete
        try await waitForCondition(timeout: 5.0, description: "Recalculation") {
            !self.appState.isRecalculating && 
            (self.appState.fileStore.files.first?.destPath?.contains(self.destB_URL.lastPathComponent) ?? false)
        }
        
        // Assert: Verify the complete integration worked
        XCTAssertEqual(appState.fileStore.files.count, 1, "File count should remain stable")
        XCTAssertFalse(appState.isRecalculating, "Should not be recalculating after completion")
        XCTAssertEqual(appState.fileStore.files.first?.status, .waiting, "File should still be waiting")
        XCTAssertTrue(appState.fileStore.files.first?.destPath?.contains(destB_URL.lastPathComponent) ?? false, "File should have destB path")
        XCTAssertEqual(settingsStore.destinationURL, destB_URL, "SettingsStore should reflect new destination")
    }
    

    func testRecalculationWithComplexFileStatuses() async throws {
        // Arrange: Create complex file scenario
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
        
        logManager.debug("--- Starting testRecalculationWithComplexFileStatuses ---", category: "AppStateRecalculationTests")
        
        // Set initial destination and trigger scan
        settingsStore.setDestination(destA_URL)
        let testVolume = Volume(name: "Test", devicePath: sourceURL.path, volumeUUID: UUID().uuidString)
        appState.volumes = [testVolume]
        appState.selectedVolumeID = testVolume.id
        
        // Wait for initial scan to complete
        try await waitForCondition(timeout: 5.0, description: "Initial scan") {
            self.appState.fileStore.files.count >= 3 && self.appState.state == .idle
        }
        
        logManager.debug("Initial files", category: "AppStateRecalculationTests", metadata: ["files": self.appState.fileStore.files.map { $0.sourceName }.joined(separator: ", ")])
        
        // Act: Change destination (should trigger recalculation)
        settingsStore.setDestination(destB_URL)
        
        // Wait for recalculation to complete
        try await waitForCondition(timeout: 5.0, description: "Recalculation") {
            !self.appState.isRecalculating && 
            self.appState.fileStore.files.allSatisfy { $0.destPath?.contains(self.destB_URL.lastPathComponent) ?? false }
        }
        
        logManager.debug("Recalculated files", category: "AppStateRecalculationTests", metadata: ["files": self.appState.fileStore.files.map { $0.sourceName }.joined(separator: ", ")])
        logManager.debug("--- Ending testRecalculationWithComplexFileStatuses ---", category: "AppStateRecalculationTests")
        
        // Assert: Verify files after automatic recalculation
        XCTAssertEqual(appState.fileStore.files.count, 3, "File count should remain stable after recalculation")
        XCTAssertFalse(appState.isRecalculating, "Should not be recalculating after completion")
        XCTAssertTrue(appState.fileStore.files.allSatisfy { $0.status == .waiting }, "All files should be .waiting after destination change (unless duplicate_in_source)")
        XCTAssertFalse(appState.fileStore.files.first { $0.sourceName == "video.mov" }!.sidecarPaths.isEmpty, "Sidecar paths should be preserved after recalculation")
    }

    func testDestinationChangeTriggersRecalculation() async throws {
        // Arrange
        let testFile = sourceURL.appendingPathComponent("test.jpg")
        createFile(at: testFile)
        settingsStore.setDestination(destA_URL)
        let testVolume = Volume(name: "Test", devicePath: sourceURL.path, volumeUUID: UUID().uuidString)
        appState.volumes = [testVolume]
        appState.selectedVolumeID = testVolume.id

        // Wait for initial scan to complete
        try await waitForCondition(timeout: 5.0, description: "Initial scan") {
            self.appState.fileStore.files.count >= 1 && self.appState.state == .idle
        }
        
        // Verify initial state
        XCTAssertEqual(appState.fileStore.files.count, 1)
        XCTAssertEqual(appState.fileStore.files.first?.status, .waiting)
        XCTAssertTrue(appState.fileStore.files.first?.destPath?.contains(destA_URL.lastPathComponent) ?? false)

        // Act: Change destination (should trigger recalculation)
        settingsStore.setDestination(destB_URL)
        
        // Wait for recalculation to complete
        try await waitForCondition(timeout: 5.0, description: "Recalculation") {
            !self.appState.isRecalculating && 
            (self.appState.fileStore.files.first?.destPath?.contains(self.destB_URL.lastPathComponent) ?? false)
        }

        // Assert: Verify automatic recalculation
        XCTAssertEqual(appState.fileStore.files.count, 1)
        XCTAssertFalse(appState.isRecalculating, "Should not be recalculating after completion")
        XCTAssertEqual(appState.fileStore.files.first?.status, .waiting) // Should still be waiting
        XCTAssertTrue(appState.fileStore.files.first?.destPath?.contains(destB_URL.lastPathComponent) ?? false)
    }
}
