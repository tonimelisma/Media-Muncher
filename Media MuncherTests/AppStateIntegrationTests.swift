import XCTest
import Combine
import Foundation
@testable import Media_Muncher

@MainActor
final class AppStateIntegrationTests: MediaMuncherTestCase {
    
    private var appState: AppState!
    private var fileStore: FileStore!

    override func setUp() async throws {
        try await super.setUp()
        
        let logManager = LogManager()
        let volumeManager = VolumeManager(logManager: logManager)
        let fileProcessorService = FileProcessorService(logManager: logManager)
        let settingsStore = SettingsStore(logManager: logManager)
        let importService = ImportService(logManager: logManager)
        let recalculationManager = RecalculationManager(logManager: logManager, fileProcessorService: fileProcessorService, settingsStore: settingsStore)
        fileStore = FileStore(logManager: logManager)
        
        appState = AppState(
            logManager: logManager,
            volumeManager: volumeManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore,
            importService: importService,
            recalculationManager: recalculationManager,
            fileStore: fileStore
        )
        
        // Clear any existing files
        fileStore.setFiles([])
    }

    override func tearDown() async throws {
        appState = nil
        fileStore = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func testVolumeInitialization() {
        // Test that volumes are initialized when AppState is created
        XCTAssertNotNil(appState.volumes)
    }

    // MARK: Recalculation after status change
    func testRecalculationAfterStatusChange() async throws {
        // Arrange: create real source volume with two files
        let srcDir = tempDirectory.appendingPathComponent("SRC")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: srcDir.appendingPathComponent("a.jpg").path, contents: Data([0xFF]))
        FileManager.default.createFile(atPath: srcDir.appendingPathComponent("b.jpg").path, contents: Data([0xFF,0xD8]))

        // Configure settings BEFORE scan so DestinationPathBuilder uses them
        appState.settingsStore.organizeByDate = false
        appState.settingsStore.renameByDate = false

        // Hook expectations
        var cancellables = Set<AnyCancellable>()
        let scanFinished = expectation(description: "Scan finished")
        appState.fileStore.$files
            .sink { files in
                if files.count == 2 && self.appState.state == .idle {
                    scanFinished.fulfill()
                }
            }
            .store(in: &cancellables)

        // Simulate volume mount & scan
        let vol = Volume(name: "TestVol", devicePath: srcDir.path, volumeUUID: UUID().uuidString)
        appState.volumes = [vol]
        appState.selectedVolumeID = vol.id

        await fulfillment(of: [scanFinished], timeout: 5)

        XCTAssertEqual(fileStore.files.count, 2)

        // Recalculation expectation
        let recalcFinished = expectation(description: "Recalc finished")
        appState.recalculationManager.didFinishPublisher
            .sink { _ in recalcFinished.fulfill() }
            .store(in: &cancellables)

        let newDest = tempDirectory.appendingPathComponent("NewDest")
        try FileManager.default.createDirectory(at: newDest, withIntermediateDirectories: true)
        appState.settingsStore.setDestination(newDest)

        await fulfillment(of: [recalcFinished], timeout: 5)

        // Assert destinations
        XCTAssertTrue(fileStore.files.allSatisfy { file in
            guard let dest = file.destPath else { return false }
            return dest.hasPrefix(newDest.path)
        })
        // Assert statuses waiting
        XCTAssertTrue(fileStore.files.allSatisfy { $0.status == .waiting })
    }
}
