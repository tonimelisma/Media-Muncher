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
    
    private func setupAppState() {
        let logManager = LogManager()
        let volumeManager = VolumeManager(logManager: logManager)
        let fileProcessorService = FileProcessorService(logManager: logManager)
        self.settingsStore = SettingsStore(logManager: logManager)
        let importService = ImportService(logManager: logManager)
        
        let fileStore = FileStore(logManager: logManager)
        let recalculationManager = RecalculationManager(
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore
        )

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

    func testAppStateInitializesCorrectly() {
        setupAppState()
        XCTAssertNotNil(appState)
        XCTAssertNotNil(appState.volumes)
    }

    func testSettingsStoreBindingExistsCorrectly() {
        setupAppState()
        
        // With synchronous initialization, destinationURL should be immediately available
        XCTAssertNotNil(settingsStore.destinationURL, "SettingsStore destinationURL should be set immediately after initialization")
        XCTAssertFalse(settingsStore.settingDeleteOriginals)
        
        // Verify the destination is a reasonable default (Pictures or Documents)
        let destination = settingsStore.destinationURL!
        let homeDir = NSHomeDirectory()
        let expectedPaths = [
            URL(fileURLWithPath: homeDir).appendingPathComponent("Pictures").path,
            URL(fileURLWithPath: homeDir).appendingPathComponent("Documents").path
        ]
        XCTAssertTrue(expectedPaths.contains(destination.path), 
                     "Destination should be Pictures or Documents folder, got: \(destination.path)")
    }

    func testRecalculationManagerBindingExistsCorrectly() {
        setupAppState()
        XCTAssertFalse(appState.isRecalculating)
    }

    func testRecalculationErrorMapping() {
        setupAppState()
        XCTAssertNil(appState.error)
    }

    func testVolumeSelectionHandling() {
        setupAppState()
        XCTAssertNil(appState.selectedVolumeID)
        XCTAssertTrue(appState.volumes.isEmpty)
    }

    func testImportProgressInitialization() {
        setupAppState()
        XCTAssertEqual(appState.importProgress.totalBytesToImport, 0)
        XCTAssertEqual(appState.importProgress.totalFilesToImport, 0)
        XCTAssertEqual(appState.importProgress.importedBytes, 0)
        XCTAssertEqual(appState.importProgress.importedFileCount, 0)
    }

    func testCancellationSupport() {
        setupAppState()
        appState.cancelScan()
        appState.cancelImport()
        XCTAssertEqual(appState.state, .idle)
    }

    func testFileStoreDeallocation() {
        weak var weakStore: FileStore?
        weak var weakContainer: TestAppContainer?
        weak var weakLogManager: MockLogManager?
        
        autoreleasepool {
            let container = TestAppContainer()
            weakContainer = container
            weakStore = container.fileStore
            weakLogManager = container.logManager as? MockLogManager
            
            XCTAssertNotNil(weakStore, "FileStore should be alive while container exists")
            XCTAssertNotNil(weakContainer, "Container should be alive in autoreleasepool")
            XCTAssertNotNil(weakLogManager, "MockLogManager should be alive while container exists")
        }
        
        // Force any pending async log tasks to complete
        let expectation = XCTestExpectation(description: "Async cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 15.0)
        
        XCTAssertNil(weakContainer, "TestAppContainer should deallocate after autoreleasepool")
        XCTAssertNil(weakStore, "FileStore should deallocate when container is deallocated")
        XCTAssertNil(weakLogManager, "MockLogManager should deallocate when container is deallocated")
    }

    func testFullServiceDeallocation() {
        weak var weakRecalculationManager: RecalculationManager?
        weak var weakFileProcessor: FileProcessorService?
        weak var weakSettingsStore: SettingsStore?
        weak var weakThumbnailCache: ThumbnailCache?
        weak var weakVolumeManager: VolumeManager?
        
        autoreleasepool {
            let container = TestAppContainer()
            weakRecalculationManager = container.recalculationManager
            weakFileProcessor = container.fileProcessorService
            weakSettingsStore = container.settingsStore
            weakThumbnailCache = container.thumbnailCache
            weakVolumeManager = container.volumeManager
        }
        
        // Force any pending async tasks to complete
        let expectation = XCTestExpectation(description: "Service cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 15.0)
        
        XCTAssertNil(weakRecalculationManager, "RecalculationManager should deallocate")
        XCTAssertNil(weakFileProcessor, "FileProcessorService should deallocate") 
        XCTAssertNil(weakSettingsStore, "SettingsStore should deallocate")
        XCTAssertNil(weakThumbnailCache, "ThumbnailCache should deallocate")
        XCTAssertNil(weakVolumeManager, "VolumeManager should deallocate")
    }
    
    func testContainerWithMultipleInstances() {
        // Test that multiple container instances don't interfere with each other
        weak var weakContainer1: TestAppContainer?
        weak var weakContainer2: TestAppContainer?
        weak var weakStore1: FileStore?
        weak var weakStore2: FileStore?
        
        autoreleasepool {
            let container1 = TestAppContainer()
            let container2 = TestAppContainer()
            
            weakContainer1 = container1
            weakContainer2 = container2
            weakStore1 = container1.fileStore
            weakStore2 = container2.fileStore
            
            // Verify they're different instances
            XCTAssertTrue(container1.fileStore !== container2.fileStore, "Different containers should have different FileStore instances")
        }
        
        // Allow async cleanup
        let expectation = XCTestExpectation(description: "Multiple container cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 15.0)
        
        XCTAssertNil(weakContainer1, "First container should deallocate")
        XCTAssertNil(weakContainer2, "Second container should deallocate")
        XCTAssertNil(weakStore1, "First FileStore should deallocate")
        XCTAssertNil(weakStore2, "Second FileStore should deallocate")
    }
}