import XCTest
@testable import Media_Muncher

final class AppStateWorkflowTests: XCTestCase {
    private var fm: FileManager { FileManager.default }

    /// Mock that records ejection attempts rather than calling NSWorkspace.
    private final class MockVolumeManager: VolumeManager {
        private(set) var ejectedVolumes: [Volume] = []
        override func ejectVolume(_ volume: Volume) {
            ejectedVolumes.append(volume)
        }
        /// Allow initialisation without real observers.
        override init() {
            super.init()
            // Remove observers installed by super to avoid system notifications in tests.
            // (Accessing the private property via KVC isn't ideal, but doable in tests.)
        }
    }

    func testImport_autoEjectEjectsVolume() async throws {
        // Arrange – create one tiny file in a fake removable volume
        let tempSrc = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tempDst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempSrc, withIntermediateDirectories: true)
        let srcFile = tempSrc.appendingPathComponent("tiny.jpg")
        fm.createFile(atPath: srcFile.path, contents: Data([0xFF]))
        try fm.createDirectory(at: tempDst, withIntermediateDirectories: true)

        let settings = SettingsStore()
        settings.setDestination(tempDst)
        settings.settingDeleteOriginals = false
        settings.settingAutoEject = true
        settings.renameByDate = false
        settings.organizeByDate = false

        let mockVM = MockVolumeManager()
        mockVM.volumes = [Volume(name: "TestVol", devicePath: tempSrc.path, volumeUUID: "uuid")]

        let fps = FileProcessorService()
        let importer = ImportService()

        let appState = AppState(volumeManager: mockVM, mediaScanner: fps, settingsStore: settings, importService: importer)

        // Precondition: selected volume is nil -> set it to trigger scan
        appState.selectedVolume = tempSrc.path
        // Wait briefly to allow scan to finish
        try await Task.sleep(nanoseconds: 200_000_000)

        // Act
        await MainActor.run { appState.importFiles() }
        // Wait until import completes
        while appState.state == .importingFiles {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // Assert
        XCTAssertEqual(mockVM.ejectedVolumes.count, 1, "Import should auto-eject when toggle enabled")
    }

    func testScanCancellation_resetsStateAndClearsFiles() async throws {
        // Arrange
        let tempSrc = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempSrc, withIntermediateDirectories: true)
        // create a bunch of files to slow scan somewhat
        for i in 0..<50 {
            fm.createFile(atPath: tempSrc.appendingPathComponent("f\(i).jpg").path, contents: Data(repeating: 0xAA, count: 128))
        }

        let mockVM = MockVolumeManager()
        mockVM.volumes = [Volume(name: "Vol", devicePath: tempSrc.path, volumeUUID: "uuid")]

        let settings = SettingsStore()
        let fps = FileProcessorService()
        let importer = ImportService()

        let appState = AppState(volumeManager: mockVM, mediaScanner: fps, settingsStore: settings, importService: importer)

        // Act – start scan
        appState.selectedVolume = tempSrc.path
        try await Task.sleep(nanoseconds: 50_000_000) // let scan start
        await MainActor.run { appState.cancelScan() }

        // Wait briefly for cancellation propagate
        try await Task.sleep(nanoseconds: 50_000_000)

        // Assert – state back to idle and files list cleared
        await MainActor.run {
            XCTAssertEqual(appState.state, .idle)
            XCTAssertTrue(appState.files.isEmpty)
        }
    }
} 