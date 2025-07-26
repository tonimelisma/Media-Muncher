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
    // inherits cancellables from MediaMuncherTestCase

    override func setUp() async throws {
        try await super.setUp()
        // cancellables initialized in parent class
        
        let container = TestAppContainer()
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
        
        fileStore.setFiles([])
    }

    override func tearDown() async throws {
        appState = nil
        fileStore = nil
        settingsStore = nil
        recalculationManager = nil
        // cancellables cleaned up in parent class
        try await super.tearDown()
    }

    func testVolumeInitialization() {
        XCTAssertNotNil(appState.volumes)
    }

    func testRecalculationAfterStatusChange() async throws {
        let container = TestAppContainer()
        await container.logManager.debug("🧪 INTEGRATION: testRecalculationAfterStatusChange - Starting", category: "TestDebugging")
        
        let srcDir = tempDirectory.appendingPathComponent("SRC")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        await container.logManager.debug("🧪 INTEGRATION: Created source directory: \(srcDir.path)", category: "TestDebugging")
        
        // Create test files using helper - more files to test batching behavior
        let testFiles = ["photo1.jpg", "photo2.jpg", "photo3.jpg", "video1.mov", "video2.mov", "audio1.mp3"]
        let createdFiles = try createTestFiles(in: srcDir, files: testFiles)
        await container.logManager.debug("🧪 INTEGRATION: Created \(createdFiles.count) test files", category: "TestDebugging")

        settingsStore.organizeByDate = false
        settingsStore.renameByDate = false

        let vol = Volume(name: "TestVol", devicePath: srcDir.path, volumeUUID: UUID().uuidString)
        await container.logManager.debug("🧪 INTEGRATION: Setting up test volume with path: \(srcDir.path)", category: "TestDebugging")
        
        // Set up volume and trigger scan
        appState.volumes = [vol]
        appState.selectedVolumeID = vol.id
        await container.logManager.debug("🧪 INTEGRATION: Set up test volume and selected it", category: "TestDebugging")

        // Wait for initial file processing
        await container.logManager.debug("🧪 INTEGRATION: About to wait for file processing (expecting 6 files)", category: "TestDebugging")
        try await waitForFileProcessingWithLogging(fileStore: fileStore, expectedCount: 6, timeout: 30) // 6 test files - longer timeout due to batching
        await container.logManager.debug("🧪 INTEGRATION: File processing completed, found \(fileStore.files.count) files", category: "TestDebugging")

        XCTAssertEqual(fileStore.files.count, 6)
        for file in fileStore.files {
            XCTAssertNotNil(file.destPath, "File should have destination path")
            await container.logManager.debug("🧪 INTEGRATION: File \(file.sourceName) has destPath: \(file.destPath ?? "nil")", category: "TestDebugging")
        }

        let newDest = tempDirectory.appendingPathComponent("NewDest")
        try FileManager.default.createDirectory(at: newDest, withIntermediateDirectories: true)
        await container.logManager.debug("🧪 INTEGRATION: Created new destination: \(newDest.path)", category: "TestDebugging")

        // Set up expectations BEFORE triggering destination change  
        await container.logManager.debug("🧪 INTEGRATION: Setting up expectations BEFORE destination change", category: "TestDebugging")
        let recalculationFinished = expectation(description: "Recalculation finished")
        let filesUpdated = expectation(description: "Files updated")
        
        recalculationManager.didFinishPublisher.sink { _ in
            Task { await container.logManager.debug("🧪 INTEGRATION: ✅ Recalculation finished!", category: "TestDebugging") }
            recalculationFinished.fulfill()
        }.store(in: &cancellables)
        
        fileStore.$files.dropFirst().sink { files in
            let allMatch = files.allSatisfy { $0.destPath?.hasPrefix(newDest.path) ?? false }
            Task { await container.logManager.debug("🧪 INTEGRATION: Files updated - count: \(files.count), allMatch: \(allMatch)", category: "TestDebugging") }
            if allMatch && files.count == 6 {
                Task { await container.logManager.debug("🧪 INTEGRATION: ✅ Files updated expectation fulfilled!", category: "TestDebugging") }
                filesUpdated.fulfill()
            }
        }.store(in: &cancellables)

        await container.logManager.debug("🧪 INTEGRATION: NOW triggering destination change", category: "TestDebugging")
        settingsStore.setDestination(newDest)
        
        await container.logManager.debug("🧪 INTEGRATION: Waiting for expectations", category: "TestDebugging")
        await fulfillment(of: [recalculationFinished, filesUpdated], timeout: 30)
        await container.logManager.debug("🧪 INTEGRATION: Both expectations fulfilled!", category: "TestDebugging")

        // Verify all files have valid destination paths
        assertValidDestinationPaths(files: fileStore.files, expectedDirectory: newDest)
        XCTAssertTrue(fileStore.files.allSatisfy { $0.status == .waiting })
        await container.logManager.debug("🧪 INTEGRATION: testRecalculationAfterStatusChange - Complete", category: "TestDebugging")
    }
    
    func testRecalculationWithPreExistingFiles() async throws {
        let container = TestAppContainer()
        await container.logManager.debug("🧪 PREEXISTING: testRecalculationWithPreExistingFiles - Starting", category: "TestDebugging")
        
        let srcDir = tempDirectory.appendingPathComponent("SRC")
        let destDir = tempDirectory.appendingPathComponent("DEST")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        await container.logManager.debug("🧪 PREEXISTING: Created directories", category: "TestDebugging", metadata: ["srcDir": srcDir.path, "destDir": destDir.path])
        
        let createdFiles = try createTestFileStructure(in: srcDir)
        let imageFile = createdFiles.first { $0.lastPathComponent == "photo.jpg" }!
        await container.logManager.debug("🧪 PREEXISTING: Created test files", category: "TestDebugging", metadata: ["count": "\(createdFiles.count)", "imageFile": imageFile.path])
        
        // Create pre-existing file in destination
        let destImageFile = destDir.appendingPathComponent("photo.jpg")
        try createPreExistingFile(source: imageFile, destination: destImageFile)
        await container.logManager.debug("🧪 PREEXISTING: Created pre-existing file", category: "TestDebugging", metadata: ["destFile": destImageFile.path])
        
        settingsStore.setDestination(destDir)
        settingsStore.organizeByDate = false
        settingsStore.renameByDate = false
        await container.logManager.debug("🧪 PREEXISTING: Set destination and settings", category: "TestDebugging", metadata: ["destDir": destDir.path])

        let vol = Volume(name: "TestVol", devicePath: srcDir.path, volumeUUID: UUID().uuidString)
        appState.volumes = [vol]
        appState.selectedVolumeID = vol.id
        await container.logManager.debug("🧪 PREEXISTING: Set volume", category: "TestDebugging", metadata: ["volumeID": vol.id])

        await container.logManager.debug("🧪 PREEXISTING: About to wait for file processing", category: "TestDebugging")
        try await waitForFileProcessingWithLogging(fileStore: fileStore, expectedCount: 3, timeout: 30)
        await container.logManager.debug("🧪 PREEXISTING: File processing completed", category: "TestDebugging", metadata: ["fileCount": "\(fileStore.files.count)"])

        // Verify one file is detected as pre-existing
        let preExistingFiles = fileStore.files.filter { $0.status == .pre_existing }
        await container.logManager.debug("🧪 PREEXISTING: Pre-existing files check", category: "TestDebugging", metadata: ["preExistingCount": "\(preExistingFiles.count)", "allFiles": fileStore.files.map { "\($0.sourceName):\($0.status)" }.joined(separator: ", ")])
        XCTAssertEqual(preExistingFiles.count, 1)
        XCTAssertEqual(preExistingFiles.first?.sourceName, "photo.jpg")

        // Test recalculation to new destination
        let newDest = tempDirectory.appendingPathComponent("NewDest")
        try FileManager.default.createDirectory(at: newDest, withIntermediateDirectories: true)
        await container.logManager.debug("🧪 PREEXISTING: Created new destination", category: "TestDebugging", metadata: ["newDest": newDest.path])

        // Set up expectation BEFORE triggering destination change
        await container.logManager.debug("🧪 PREEXISTING: Setting up recalculation expectation", category: "TestDebugging")
        let recalculationFinished = expectation(description: "Recalculation finished")
        recalculationManager.didFinishPublisher.sink { _ in 
            Task { await container.logManager.debug("🧪 PREEXISTING: ✅ Recalculation finished signal received!", category: "TestDebugging") }
            recalculationFinished.fulfill() 
        }.store(in: &cancellables)

        await container.logManager.debug("🧪 PREEXISTING: NOW triggering destination change", category: "TestDebugging")
        settingsStore.setDestination(newDest)
        
        await container.logManager.debug("🧪 PREEXISTING: Waiting for recalculation to finish", category: "TestDebugging")
        await fulfillment(of: [recalculationFinished], timeout: 30)
        await container.logManager.debug("🧪 PREEXISTING: Recalculation expectation fulfilled!", category: "TestDebugging")

        // After recalculation, all files should be waiting since no pre-existing files in new destination
        await container.logManager.debug("🧪 PREEXISTING: Final verification", category: "TestDebugging", metadata: ["allFiles": fileStore.files.map { "\($0.sourceName):\($0.status)" }.joined(separator: ", ")])
        XCTAssertTrue(fileStore.files.allSatisfy { $0.status == .waiting })
        assertValidDestinationPaths(files: fileStore.files, expectedDirectory: newDest)
        await container.logManager.debug("🧪 PREEXISTING: testRecalculationWithPreExistingFiles - Complete", category: "TestDebugging")
    }
}
