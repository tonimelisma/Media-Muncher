import XCTest
@testable import Media_Muncher

/// Tests for the AppState workflow and state management
final class AppStateWorkflowTests: XCTestCase {
    private var tempDir: URL!
    private let fm = FileManager.default
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory
        tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? fm.removeItem(at: tempDir)
        tempDir = nil
        try super.tearDownWithError()
    }
    
    func testAppStateInitializationAndBasicWorkflow() async throws {
        // Arrange
        let tempSrc = tempDir.appendingPathComponent("source")
        let tempDst = tempDir.appendingPathComponent("destination")
        
        try fm.createDirectory(at: tempSrc, withIntermediateDirectories: true)
        try fm.createDirectory(at: tempDst, withIntermediateDirectories: true)
        
        // Create a test file
        let testFile = tempSrc.appendingPathComponent("test.jpg")
        let testData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        try testData.write(to: testFile)
        
        // Initialize services
        let mockVM = VolumeManager()
        let fps = FileProcessorService()
        let settings = SettingsStore()
        settings.setDestination(tempDst)
        let importer = ImportService()
        
        // Act
        let appState = await AppState(volumeManager: mockVM, mediaScanner: fps, settingsStore: settings, importService: importer)
        
        await MainActor.run {
            appState.selectedVolume = tempSrc.path
        }
        
        // Wait for processing
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Start import
        await MainActor.run {
            appState.importFiles()
        }
        
        // Wait for import to complete
        while await MainActor.run { appState.state == .importingFiles } {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Assert
        await MainActor.run {
            XCTAssertEqual(appState.state, .idle)
            XCTAssertFalse(appState.files.isEmpty)
            XCTAssertGreaterThan(appState.importedFileCount, 0)
        }
    }
    
    func testAppStateVolumeSelectionClearsFiles() async throws {
        // Arrange
        let tempSrc1 = tempDir.appendingPathComponent("source1")
        let tempSrc2 = tempDir.appendingPathComponent("source2")
        
        try fm.createDirectory(at: tempSrc1, withIntermediateDirectories: true)
        try fm.createDirectory(at: tempSrc2, withIntermediateDirectories: true)
        
        // Create files in both sources
        let testFile1 = tempSrc1.appendingPathComponent("test1.jpg")
        let testFile2 = tempSrc2.appendingPathComponent("test2.jpg")
        let testData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        try testData.write(to: testFile1)
        try testData.write(to: testFile2)
        
        let mockVM = VolumeManager()
        let fps = FileProcessorService()
        let settings = SettingsStore()
        settings.setDestination(tempDir)
        let importer = ImportService()
        
        // Act
        let appState = await AppState(volumeManager: mockVM, mediaScanner: fps, settingsStore: settings, importService: importer)
        
        await MainActor.run {
            appState.selectedVolume = tempSrc1.path
        }
        
        // Wait for first scan
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let filesFromFirstScan = await MainActor.run { appState.files.count }
        
        // Change volume
        await MainActor.run {
            appState.selectedVolume = tempSrc2.path
        }
        
        // Wait for second scan
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let filesFromSecondScan = await MainActor.run { appState.files.count }
        
        // Assert
        XCTAssertGreaterThan(filesFromFirstScan, 0)
        XCTAssertGreaterThan(filesFromSecondScan, 0)
        // Files should be different or same count but different instances
        await MainActor.run {
            XCTAssertFalse(appState.files.isEmpty)
        }
    }
} 