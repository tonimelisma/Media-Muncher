import XCTest
import Combine
@testable import Media_Muncher

@MainActor
final class AppStateIntegrationTests: XCTestCase {

    var sourceURL: URL!
    var destinationA_URL: URL!
    var destinationB_URL: URL!
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

        // Create unique temporary source and destination directories
        sourceURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destinationA_URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destinationB_URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationA_URL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationB_URL, withIntermediateDirectories: true)

        // Initialize services with isolated UserDefaults for testing
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        settingsStore = SettingsStore(userDefaults: testDefaults)
        fileProcessorService = FileProcessorService()
        importService = ImportService()
        volumeManager = VolumeManager()

        // Initialize RecalculationManager first
        let recalculationManager = RecalculationManager(
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore
        )

        // Initialize AppState
        appState = AppState(
            volumeManager: volumeManager,
            mediaScanner: fileProcessorService,
            settingsStore: settingsStore,
            importService: importService,
            recalculationManager: recalculationManager
        )
    }

    override func tearDownWithError() throws {
        // Cancel any ongoing operations
        appState?.cancelScan()
        appState?.cancelImport()
        
        // Clear state
        if let appState = appState {
            appState.files = []
            appState.state = .idle
            appState.error = nil
        }
        
        // Remove test directories
        try? fileManager.removeItem(at: sourceURL)
        try? fileManager.removeItem(at: destinationA_URL)
        try? fileManager.removeItem(at: destinationB_URL)
        
        // Clear references
        sourceURL = nil
        destinationA_URL = nil
        destinationB_URL = nil
        fileManager = nil
        settingsStore = nil
        fileProcessorService = nil
        importService = nil
        volumeManager = nil
        appState = nil
        cancellables = nil
        
        try super.tearDownWithError()
    }

    private func setupSourceFile(named fileName: String) throws -> URL {
        guard let fixtureURL = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: nil) else {
            throw TestError.fixtureNotFound(name: fileName)
        }
        let destinationInSource = sourceURL.appendingPathComponent(fileName)
        try fileManager.copyItem(at: fixtureURL, to: destinationInSource)
        return destinationInSource
    }

    func testDestinationChangeRecalculatesFileStatuses() async throws {
        // 1. SETUP - Create source files
        let file1_sourceURL = try setupSourceFile(named: "exif_image.jpg")
        _ = try setupSourceFile(named: "no_exif_image.heic")

        // Create a pre-existing file in Destination A
        try fileManager.copyItem(at: file1_sourceURL, to: destinationA_URL.appendingPathComponent("exif_image.jpg"))

        // 2. INITIAL SCAN - Set destination and scan source
        settingsStore.setDestination(destinationA_URL)

        // Perform initial scan directly (bypassing volume selection which doesn't work in tests)
        let processedFiles = await fileProcessorService.processFiles(
            from: sourceURL,
            destinationURL: destinationA_URL,
            settings: settingsStore
        )
        appState.files = processedFiles

        // 3. VALIDATE INITIAL STATE
        XCTAssertEqual(appState.files.count, 2, "Should have 2 files after initial scan")
        
        let preExistingFile = appState.files.first { $0.sourceName == "exif_image.jpg" }
        let waitingFile = appState.files.first { $0.sourceName == "no_exif_image.heic" }
        
        XCTAssertNotNil(preExistingFile, "Should find exif_image.jpg")
        XCTAssertNotNil(waitingFile, "Should find no_exif_image.heic")
        XCTAssertEqual(preExistingFile?.status, .pre_existing, "exif_image.jpg should be pre-existing")
        XCTAssertEqual(waitingFile?.status, .waiting, "no_exif_image.heic should be waiting")

        // 4. DESTINATION CHANGE & RECALCULATION
        // Trigger destination change (this automatically triggers handleDestinationChange)
        settingsStore.setDestination(destinationB_URL)

        // Wait for recalculation to complete using proper expectation
        let recalcExpectation = XCTestExpectation(description: "Recalculation complete")
        appState.$isRecalculating
            .dropFirst()
            .sink { isRecalculating in
                if !isRecalculating {
                    recalcExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [recalcExpectation], timeout: 5.0)

        // 5. FINAL ASSERTIONS
        XCTAssertEqual(appState.files.count, 2, "Should still have 2 files")
        XCTAssertFalse(appState.isRecalculating, "Should not be recalculating")
        
        // All files should now be .waiting (no pre-existing files in empty destination B)
        XCTAssertTrue(appState.files.allSatisfy { $0.status == .waiting }, 
                     "All files should be .waiting in empty destination B")
        
        // All destination paths should point to destination B
        XCTAssertTrue(appState.files.allSatisfy { 
            guard let destPath = $0.destPath else { return false }
            return destPath.hasPrefix(destinationB_URL.path)
        }, "All files should have destination paths pointing to destination B")
        
        // Previously pre-existing file should now be waiting
        let updatedPreExistingFile = appState.files.first { $0.sourceName == "exif_image.jpg" }
        XCTAssertEqual(updatedPreExistingFile?.status, .waiting, 
                      "Previously pre-existing file should now be waiting")
    }
}
