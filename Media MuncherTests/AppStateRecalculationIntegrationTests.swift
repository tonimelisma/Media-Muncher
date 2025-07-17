import XCTest
import Combine
@testable import Media_Muncher

@MainActor
final class AppStateRecalculationIntegrationTests: XCTestCase {
    
    func testAppStateRecalculationIsolation() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destA = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destB = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destA, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destB, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
            try? fileManager.removeItem(at: destA)
            try? fileManager.removeItem(at: destB)
        }
        
        // Create a single test file
        let testFile = tempDir.appendingPathComponent("test.jpg")
        fileManager.createFile(atPath: testFile.path, contents: Data([0x42]))
        
        // Verify directory is clean
        let contents = try fileManager.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertEqual(contents, ["test.jpg"])
        
        // Create fresh AppState
        let logManager = LogManager()
        let testDefaults = UserDefaults(suiteName: "AppStateRecalculationIntegrationTests")!
        let settingsStore = SettingsStore(logManager: logManager, userDefaults: testDefaults)
        let fileProcessorService = FileProcessorService(logManager: logManager)
        let importService = ImportService(logManager: logManager)
        let volumeManager = VolumeManager(logManager: logManager)
        
        let recalculationManager = RecalculationManager(
            logManager: logManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore
        )
        
        let appState = AppState(
            logManager: logManager,
            volumeManager: volumeManager,
            mediaScanner: fileProcessorService,
            settingsStore: settingsStore,
            importService: importService,
            recalculationManager: recalculationManager
        )
        
        settingsStore.setDestination(destA)
        
        // Scan initial files
        let scanExpectation = XCTestExpectation(description: "Initial scan")
        var cancellables: Set<AnyCancellable> = []
        
        appState.$files
            .dropFirst()
            .sink { files in
                if !files.isEmpty {
                    scanExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        appState.selectedVolume = tempDir.path
        await fulfillment(of: [scanExpectation], timeout: 5.0)
        
        // Verify initial state
        XCTAssertEqual(appState.files.count, 1, "Initial scan should find 1 file, found: \(appState.files.map { $0.sourceName })")
        XCTAssertEqual(appState.files.first?.sourceName, "test.jpg")
        
        let initialFile = appState.files.first!
        
        // Trigger recalculation by changing destination
        let recalcExpectation = XCTestExpectation(description: "Recalculation")
        
        appState.$files
            .dropFirst()
            .sink { files in
                recalcExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        settingsStore.setDestination(destB)
        await fulfillment(of: [recalcExpectation], timeout: 5.0)
        
        // Verify recalculation didn't change file list
        XCTAssertEqual(appState.files.count, 1, "Recalculation should still have 1 file, but got: \(appState.files.map { $0.sourceName }) with paths: \(appState.files.map { $0.sourcePath })")
        XCTAssertEqual(appState.files.first?.sourceName, "test.jpg")
        XCTAssertEqual(appState.files.first?.sourcePath, initialFile.sourcePath)
    }
}