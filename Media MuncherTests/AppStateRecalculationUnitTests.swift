import XCTest
import Foundation
import Combine
@testable import Media_Muncher

@MainActor 
final class AppStateRecalculationUnitTests: XCTestCase {

    private var appState: AppState!
    private var cancellables: Set<AnyCancellable>!
    private var settingsStore: SettingsStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = Set<AnyCancellable>()
    }
    
    // Asynchronous setup helper
    private func setupAppState() async {
        // Create test services
        let logManager = LogManager()
        let volumeManager = VolumeManager(logManager: logManager)
        let fileProcessorService = FileProcessorService(logManager: logManager)
        self.settingsStore = SettingsStore(logManager: logManager)
        let importService = ImportService(logManager: logManager)
        
        // Await the MainActor-isolated services
        let fileStore = await FileStore(logManager: logManager)
        let recalculationManager = await RecalculationManager(
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
        settingsStore = nil
        try super.tearDownWithError()
    }

    func testAppStateInitializesCorrectly() async throws {
        await setupAppState()
        // Assert - AppState should initialize without crashing
        XCTAssertNotNil(appState)
        // Note: Don't test state enum as it may have complex initialization logic
        XCTAssertNotNil(appState.volumes)
    }

    func testSettingsStoreBindingExistsCorrectly() async throws {
        await setupAppState()
        let expectation = XCTestExpectation(description: "Wait for default destination to be set")
        
        // Subscribe to the publisher BEFORE any potential changes
        settingsStore.$destinationURL
            .sink { url in
                if url != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Wait for the expectation to be fulfilled
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Assert that the destination URL is now non-nil
        XCTAssertNotNil(settingsStore.destinationURL)
        XCTAssertFalse(settingsStore.settingDeleteOriginals)
    }

    // This is a minimal test that demonstrates the binding chain is in place.
    // In reality, the recalculation logic is quite complex and is tested more thoroughly
    // in `AppStateRecalculationTests.swift`, which creates and manipulates real files.
    func testRecalculationManagerBindingExistsCorrectly() async throws {
        await setupAppState()
        // Initially, no recalculation should be in progress
        XCTAssertFalse(appState.isRecalculating)
    }

    func testRecalculationErrorMapping() async throws {
        await setupAppState()
        // This test demonstrates that error properties exist and are accessible
        // In practice, errors would be set by the RecalculationManager during actual operations
        
        // Initially, no errors should be present
        XCTAssertNil(appState.error)
    }

    func testVolumeSelectionHandling() async throws {
        await setupAppState()
        // Initially, no volume should be selected
        XCTAssertNil(appState.selectedVolumeID)

        // Initially, volumes list should be empty (since we're not connecting real volumes in tests)
        XCTAssertTrue(appState.volumes.isEmpty)
    }

    func testImportProgressInitialization() async throws {
        await setupAppState()
        // Import progress should exist and be in a non-started state
        XCTAssertEqual(appState.importProgress.totalBytesToImport, 0)
        XCTAssertEqual(appState.importProgress.totalFilesToImport, 0)
        XCTAssertEqual(appState.importProgress.importedBytes, 0)
        XCTAssertEqual(appState.importProgress.importedFileCount, 0)
    }

    func testCancellationSupport() async throws {
        await setupAppState()
        // Test that cancellation methods exist and don't crash
        appState.cancelScan()
        appState.cancelImport()

        // State should remain .idle after cancellation
        XCTAssertEqual(appState.state, .idle)
    }

    func testFileStoreDeallocation() async {
        weak var weakStore: FileStore?
        
        let container = await TestAppContainer()
        
        autoreleasepool {
            weakStore = container.fileStore
        }
        
        XCTAssertNil(weakStore, "FileStore should deallocate when container goes out of scope")
    }
}