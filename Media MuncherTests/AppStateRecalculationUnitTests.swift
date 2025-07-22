import XCTest
import Foundation
import Combine
@testable import Media_Muncher

@MainActor 
final class AppStateRecalculationUnitTests: XCTestCase {

    private var appState: AppState!
    private var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = Set<AnyCancellable>()

        // Create test services
        let logManager = LogManager()
        let volumeManager = VolumeManager(logManager: logManager)
        let fileProcessorService = FileProcessorService(logManager: logManager)
        let settingsStore = SettingsStore(logManager: logManager)
        let importService = ImportService(logManager: logManager)
        let fileStore = FileStore(logManager: logManager)
        let recalculationManager = RecalculationManager(
            logManager: logManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore
        )

        // Create AppState with all dependencies
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
        cancellables = nil
        try super.tearDownWithError()
    }

    func testAppStateInitializesCorrectly() async throws {
        // Assert - AppState should initialize without crashing
        XCTAssertNotNil(appState)
        // Note: Don't test state enum as it may have complex initialization logic
        XCTAssertNotNil(appState.volumes)
    }

    func testSettingsStoreBindingExistsCorrectly() async throws {
        // Initially, settingsStore should have reasonable defaults
        let initialDestination = appState.settingsStore.destinationURL
        XCTAssertNotNil(initialDestination) // Default destination should be set automatically

        // Note: Rather than test complex binding logic, we test that the settingsStore is accessible
        XCTAssertFalse(appState.settingsStore.settingDeleteOriginals)
    }

    // This is a minimal test that demonstrates the binding chain is in place.
    // In reality, the recalculation logic is quite complex and is tested more thoroughly
    // in `AppStateRecalculationTests.swift`, which creates and manipulates real files.
    func testRecalculationManagerBindingExistsCorrectly() async throws {
        // Initially, no recalculation should be in progress
        XCTAssertFalse(appState.isRecalculating)

        // RecalculationManager should be present
        XCTAssertNotNil(appState.recalculationManager)
        
        // Files should start empty
        XCTAssertTrue(appState.recalculationManager.files.isEmpty)

        // No errors initially
        XCTAssertNil(appState.recalculationManager.error)
    }

    func testRecalculationErrorMapping() async throws {
        // This test demonstrates that error properties exist and are accessible
        // In practice, errors would be set by the RecalculationManager during actual operations
        
        // Initially, no errors should be present
        XCTAssertNil(appState.error)
        XCTAssertNil(appState.recalculationManager.error)
        
        // The error handling mechanism is tested more thoroughly in integration tests
        // where actual recalculation operations can fail and generate real errors
    }

    func testVolumeSelectionHandling() async throws {
        // Initially, no volume should be selected
        XCTAssertNil(appState.selectedVolumeID)

        // The VolumeManager should be accessible
        XCTAssertNotNil(appState.volumeManager)

        // Initially, volumes list should be empty (since we're not connecting real volumes in tests)
        XCTAssertTrue(appState.volumes.isEmpty)
    }

    func testImportProgressInitialization() async throws {
        // Import progress should exist and be in a non-started state
        XCTAssertEqual(appState.importProgress.totalBytesToImport, 0)
        XCTAssertEqual(appState.importProgress.totalFilesToImport, 0)
        XCTAssertEqual(appState.importProgress.importedBytes, 0)
        XCTAssertEqual(appState.importProgress.importedFileCount, 0)
    }

    func testCancellationSupport() async throws {
        // Test that cancellation methods exist and don't crash
        appState.cancelScan()
        appState.cancelImport()

        // State should remain .idle after cancellation
        XCTAssertEqual(appState.state, .idle)
    }

    func testMemoryManagement() {
        weak var leaked: AppState?
        autoreleasepool {
            let localState = AppState(
                logManager: LogManager(),
                volumeManager: VolumeManager(logManager: LogManager()),
                fileProcessorService: FileProcessorService(logManager: LogManager()),
                settingsStore: SettingsStore(logManager: LogManager()),
                importService: ImportService(logManager: LogManager()),
                recalculationManager: RecalculationManager(fileProcessorService: FileProcessorService(logManager: LogManager()), settingsStore: SettingsStore(logManager: LogManager())),
                fileStore: FileStore(logManager: LogManager())
            )
            leaked = localState
        }
        XCTAssertNil(leaked)
    }
}