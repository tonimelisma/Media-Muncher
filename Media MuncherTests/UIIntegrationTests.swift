import XCTest
import SwiftUI
@testable import Media_Muncher

/// Integration tests for SwiftUI components and their interactions with services
final class UIIntegrationTests: XCTestCase {
    
    private var appState: AppState!
    private var volumeManager: VolumeManager!
    private var settingsStore: SettingsStore!
    private var tempDir: URL!
    private let fm = FileManager.default
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory for test
        tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Initialize services
        volumeManager = VolumeManager()
        settingsStore = SettingsStore()
        settingsStore.setDestination(tempDir)
    }
    
    override func tearDownWithError() throws {
        try? fm.removeItem(at: tempDir)
        tempDir = nil
        appState = nil
        volumeManager = nil
        settingsStore = nil
        try super.tearDownWithError()
    }
    
    private func createAppState() async {
        let fileProcessor = FileProcessorService()
        let importService = ImportService()
        
        appState = await AppState(
            volumeManager: volumeManager,
            mediaScanner: fileProcessor,
            settingsStore: settingsStore,
            importService: importService
        )
    }
    
    /// Test that volume selection triggers file scanning
    func testVolumeSelectionTriggersScanning() async throws {
        // Arrange - create a test volume with files
        let testVolume = tempDir.appendingPathComponent("testvolume")
        try fm.createDirectory(at: testVolume, withIntermediateDirectories: true)
        
        // Create test files
        let testFile = testVolume.appendingPathComponent("test.jpg")
        fm.createFile(atPath: testFile.path, contents: Data([0xFF, 0xD8, 0xFF])) // JPEG header
        
        await createAppState()
        
        // Act - simulate volume selection
        await MainActor.run {
            appState.selectedVolume = testVolume.path
        }
        
        // Wait for scan to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Assert - files should be discovered
        await MainActor.run {
            XCTAssertEqual(appState.state, .idle)
            XCTAssertFalse(appState.files.isEmpty)
        }
    }
    
    /// Test error handling when scanning fails
    func testScanErrorHandling() async throws {
        // Arrange - try to scan a non-existent path
        let nonExistentPath = "/nonexistent/path/that/does/not/exist"
        
        await createAppState()
        
        // Act
        await MainActor.run {
            appState.selectedVolume = nonExistentPath
        }
        
        // Wait briefly
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Assert - should handle gracefully (return empty files list)
        await MainActor.run {
            XCTAssertEqual(appState.state, .idle)
            XCTAssertTrue(appState.files.isEmpty)
        }
    }
    
    /// Test settings changes affect file processing
    func testSettingsChangesAffectProcessing() async throws {
        // Arrange - create test volume with mixed file types
        let testVolume = tempDir.appendingPathComponent("mixedvolume")
        try fm.createDirectory(at: testVolume, withIntermediateDirectories: true)
        
        // Create different file types
        let jpegFile = testVolume.appendingPathComponent("test.jpg")
        let movFile = testVolume.appendingPathComponent("test.mov")
        fm.createFile(atPath: jpegFile.path, contents: Data([0xFF, 0xD8, 0xFF]))
        fm.createFile(atPath: movFile.path, contents: Data([0x00, 0x00, 0x00, 0x18]))
        
        await createAppState()
        
        // Act 1 - scan with images disabled
        await MainActor.run {
            settingsStore.filterImages = false
            settingsStore.filterVideos = true
            appState.selectedVolume = testVolume.path
        }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let filesWithoutImages = await MainActor.run { appState.files.count }
        
        // Act 2 - scan with images enabled
        await MainActor.run {
            settingsStore.filterImages = true
            settingsStore.filterVideos = true
            appState.selectedVolume = testVolume.path
        }
        
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let filesWithImages = await MainActor.run { appState.files.count }
        
        // Assert - should have more files when images are enabled
        XCTAssertGreaterThan(filesWithImages, filesWithoutImages)
    }
    
    /// Test import progress updates
    func testImportProgressUpdates() async throws {
        // Arrange - create test volume with a file
        let testVolume = tempDir.appendingPathComponent("progressvolume")
        try fm.createDirectory(at: testVolume, withIntermediateDirectories: true)
        
        let testFile = testVolume.appendingPathComponent("progress.jpg")
        let testData = Data(repeating: 0xFF, count: 1024) // 1KB file
        fm.createFile(atPath: testFile.path, contents: testData)
        
        await createAppState()
        
        await MainActor.run {
            appState.selectedVolume = testVolume.path
        }
        
        // Wait for scan
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Act - start import
        await MainActor.run {
            appState.importFiles()
        }
        
        // Wait for import to complete
        while await MainActor.run { appState.state == .importingFiles } {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Assert - import should complete successfully
        await MainActor.run {
            XCTAssertEqual(appState.state, .idle)
            XCTAssertEqual(appState.importedFileCount, 1)
            // Check the count of files eligible for import (not pre-existing)
            let filesToImport = appState.files.filter { $0.status != .pre_existing }
            XCTAssertEqual(filesToImport.count, 1)
        }
    }
    
    /// Test concurrent scan cancellation
    func testConcurrentScanCancellation() async throws {
        // Arrange - create volume with many files to make scan take time
        let testVolume = tempDir.appendingPathComponent("slowvolume")
        try fm.createDirectory(at: testVolume, withIntermediateDirectories: true)
        
        // Create many files
        for i in 0..<100 {
            let file = testVolume.appendingPathComponent("file\(i).jpg")
            fm.createFile(atPath: file.path, contents: Data([0xFF, 0xD8, 0xFF]))
        }
        
        await createAppState()
        
        // Act - start scan then quickly cancel
        await MainActor.run {
            appState.selectedVolume = testVolume.path
        }
        
        try await Task.sleep(nanoseconds: 50_000_000) // Let scan start
        
        await MainActor.run {
            appState.cancelScan()
        }
        
        try await Task.sleep(nanoseconds: 100_000_000) // Wait for cancellation
        
        // Assert - should be in idle state with empty files
        await MainActor.run {
            XCTAssertEqual(appState.state, .idle)
            XCTAssertTrue(appState.files.isEmpty)
        }
    }
} 