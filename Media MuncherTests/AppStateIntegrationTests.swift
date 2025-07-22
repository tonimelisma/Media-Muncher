import XCTest
import Combine
import Foundation
@testable import Media_Muncher

@MainActor
final class AppStateIntegrationTests: MediaMuncherTestCase {
    
    private var appState: AppState!
    private var fileStore: FileStore!
    private var settingsStore: SettingsStore!
    private var recalculationManager: RecalculationManager!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        cancellables = []
        
        let container = await TestAppContainer()
        fileStore = container.fileStore
        settingsStore = container.settingsStore
        recalculationManager = container.recalculationManager
        
        appState = AppState(
            logManager: container.logManager,
            volumeManager: container.volumeManager,
            fileProcessorService: container.fileProcessorService,
            settingsStore: container.settingsStore,
            importService: container.importService,
            recalculationManager: container.recalculationManager,
            fileStore: container.fileStore
        )
        
        // Clear any existing files
        fileStore.setFiles([])
    }

    override func tearDown() async throws {
        appState = nil
        fileStore = nil
        settingsStore = nil
        recalculationManager = nil
        cancellables = nil
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
        settingsStore.organizeByDate = false
        settingsStore.renameByDate = false

        // Hook expectations
        let scanFinished = expectation(description: "Scan finished")
        fileStore.$files
            .dropFirst() // Ignore initial empty value
            .sink { files in
                if files.count == 2 {
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
        recalculationManager.didFinishPublisher
            .sink { _ in recalcFinished.fulfill() }
            .store(in: &cancellables)

        let newDest = tempDirectory.appendingPathComponent("NewDest")
        try FileManager.default.createDirectory(at: newDest, withIntermediateDirectories: true)
        settingsStore.setDestination(newDest)

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
