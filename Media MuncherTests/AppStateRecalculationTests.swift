import XCTest
import Combine
@testable import Media_Muncher

@MainActor
final class AppStateRecalculationTests: XCTestCase {
    var sourceURL: URL!
    var destA_URL: URL!
    var destB_URL: URL!
    var fileManager: FileManager!
    var settingsStore: SettingsStore!
    var fileProcessorService: FileProcessorService!
    var importService: ImportService!
    var volumeManager: VolumeManager!
    var fileStore: FileStore!
    var appState: AppState!
    var recalculationManager: RecalculationManager!
    private var cancellables: Set<AnyCancellable>!
    private var logManager: LogManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        cancellables = []

        let testRunID = UUID().uuidString
        sourceURL = fileManager.temporaryDirectory.appendingPathComponent("test_source_\(testRunID)")
        destA_URL = fileManager.temporaryDirectory.appendingPathComponent("test_destA_\(testRunID)")
        destB_URL = fileManager.temporaryDirectory.appendingPathComponent("test_destB_\(testRunID)")
        
        try? fileManager.removeItem(at: sourceURL)
        try? fileManager.removeItem(at: destA_URL)
        try? fileManager.removeItem(at: destB_URL)
        
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destA_URL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destB_URL, withIntermediateDirectories: true)

        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        logManager = LogManager()
        settingsStore = SettingsStore(logManager: logManager, userDefaults: testDefaults)
        fileProcessorService = FileProcessorService(logManager: logManager, thumbnailCache: ThumbnailCache.testInstance(limit: 16))
        importService = ImportService(logManager: logManager)
        volumeManager = VolumeManager(logManager: logManager)

        fileStore = FileStore(logManager: logManager)

        recalculationManager = RecalculationManager(
            logManager: logManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore,
            fileStore: fileStore
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
        try? fileManager.removeItem(at: sourceURL)
        try? fileManager.removeItem(at: destA_URL)
        try? fileManager.removeItem(at: destB_URL)
        super.tearDown()
    }

    private func createFile(at url: URL, content: Data = Data([0xAB])) {
        fileManager.createFile(atPath: url.path, contents: content)
    }

    private func triggerScanAndWaitForCompletion(fileCount: Int) async throws {
        await logManager.debug("🧪 HELPER: triggerScanAndWaitForCompletion called with expected count: \(fileCount)", category: "TestDebugging")
        let testVolume = Volume(name: "Test", devicePath: sourceURL.path, volumeUUID: UUID().uuidString)
        await logManager.debug("🧪 HELPER: Created test volume with path: \(sourceURL.path)", category: "TestDebugging")
        
        appState.volumes = [testVolume]
        await logManager.debug("🧪 HELPER: Set volumes array", category: "TestDebugging")
        appState.selectedVolumeID = testVolume.id
        await logManager.debug("🧪 HELPER: Set selectedVolumeID to: \(testVolume.id)", category: "TestDebugging")
        
        await logManager.debug("🧪 HELPER: About to wait for publisher with condition: files.count >= \(fileCount)", category: "TestDebugging")
        _ = try await waitForPublisher(
            fileStore.$files.eraseToAnyPublisher(),
            description: "Initial scan completion"
        ) { files in
            Task { await self.logManager.debug("🧪 HELPER: Publisher check - current file count: \(files.count), needed: \(fileCount)", category: "TestDebugging") }
            return files.count >= fileCount
        }
        await logManager.debug("🧪 HELPER: triggerScanAndWaitForCompletion completed successfully", category: "TestDebugging")
    }

    func testRecalculationIsProperlyGatedByFilePresence() {
        XCTAssertTrue(fileStore.files.isEmpty, "Should start with no files")

        var filesChangedCount = 0
        fileStore.$files
            .dropFirst()
            .sink { _ in filesChangedCount += 1 }
            .store(in: &cancellables)

        settingsStore.setDestination(destA_URL)
        settingsStore.setDestination(destB_URL)

        XCTAssertEqual(filesChangedCount, 0, "Files array should not change when no files are loaded")
    }

    func testDestinationChangeTriggersRecalculation() async throws {
        await logManager.debug("🧪 TEST: testDestinationChangeTriggersRecalculation - Starting test", category: "TestDebugging")
        
        createFile(at: sourceURL.appendingPathComponent("test.jpg"))
        await logManager.debug("🧪 TEST: Created test file", category: "TestDebugging")
        
        settingsStore.setDestination(destA_URL)
        await logManager.debug("🧪 TEST: Set destination A to \(destA_URL.path)", category: "TestDebugging")
        
        try await triggerScanAndWaitForCompletion(fileCount: 1)
        await logManager.debug("🧪 TEST: Scan completed, file count: \(fileStore.files.count)", category: "TestDebugging")

        XCTAssertEqual(fileStore.files.count, 1)
        XCTAssertTrue(fileStore.files.first?.destPath?.contains(destA_URL.lastPathComponent) ?? false)
        await logManager.debug("🧪 TEST: Initial file destPath: \(fileStore.files.first?.destPath ?? "nil")", category: "TestDebugging")
        
        let destB = destB_URL!
        await logManager.debug("🧪 TEST: About to change destination to B: \(destB.path)", category: "TestDebugging")
        
        await logManager.debug("🧪 TEST: Setting up expectations BEFORE destination change", category: "TestDebugging")
        let recalculationFinished = expectation(description: "Recalculation finished")
        recalculationManager.didFinishPublisher.sink { _ in 
            Task { await self.logManager.debug("🧪 TEST: RecalculationManager didFinish publisher fired!", category: "TestDebugging") }
            recalculationFinished.fulfill() 
        }.store(in: &cancellables)
        
        let filesUpdated = expectation(description: "Files updated")
        fileStore.$files.dropFirst().sink { files in
            Task { await self.logManager.debug("🧪 TEST: Files updated, checking destPath. File count: \(files.count)", category: "TestDebugging") }
            if let firstFile = files.first {
                Task { 
                    await self.logManager.debug("🧪 TEST: First file destPath: \(firstFile.destPath ?? "nil")", category: "TestDebugging")
                    await self.logManager.debug("🧪 TEST: Looking for destB component: \(destB.lastPathComponent)", category: "TestDebugging")
                }
                if firstFile.destPath?.contains(destB.lastPathComponent) ?? false {
                    Task { await self.logManager.debug("🧪 TEST: Files updated expectation fulfilled!", category: "TestDebugging") }
                    filesUpdated.fulfill()
                }
            }
        }.store(in: &cancellables)

        await logManager.debug("🧪 TEST: Expectations set up, now changing destination", category: "TestDebugging")
        await logManager.debug("🧪 TEST: Current isRecalculating before change: \(appState.isRecalculating)", category: "TestDebugging")
        
        settingsStore.setDestination(destB)
        await logManager.debug("🧪 TEST: Destination changed, waiting for fulfillment", category: "TestDebugging")
        await logManager.debug("🧪 TEST: Current isRecalculating after change: \(appState.isRecalculating)", category: "TestDebugging")

        await fulfillment(of: [recalculationFinished, filesUpdated], timeout: 15)
        await logManager.debug("🧪 TEST: Expectations fulfilled!", category: "TestDebugging")

        XCTAssertEqual(fileStore.files.count, 1)
        XCTAssertFalse(appState.isRecalculating)
        XCTAssertEqual(fileStore.files.first?.status, .waiting)
        XCTAssertTrue(fileStore.files.first?.destPath?.contains(destB.lastPathComponent) ?? false)
        await logManager.debug("🧪 TEST: Final assertions passed, test complete", category: "TestDebugging")
    }

    func testRecalculationWithComplexFileStatuses() async throws {
        await logManager.debug("🧪 TEST: testRecalculationWithComplexFileStatuses - Starting", category: "TestDebugging")
        
        await logManager.debug("🧪 TEST: Creating test files", category: "TestDebugging")
        createFile(at: sourceURL.appendingPathComponent("regular.jpg"))
        let preExistingFile = sourceURL.appendingPathComponent("existing.jpg")
        createFile(at: preExistingFile)
        createFile(at: sourceURL.appendingPathComponent("video.mov"))
        createFile(at: sourceURL.appendingPathComponent("video.xmp"))
        try fileManager.copyItem(at: preExistingFile, to: destA_URL.appendingPathComponent("existing.jpg"))
        await logManager.debug("🧪 TEST: Created 4 source files and 1 pre-existing destination file", category: "TestDebugging")

        await logManager.debug("🧪 TEST: Setting destination A and triggering scan", category: "TestDebugging")
        settingsStore.setDestination(destA_URL)
        await logManager.debug("🧪 TEST: About to trigger scan for 3 files", category: "TestDebugging")
        try await triggerScanAndWaitForCompletion(fileCount: 3)
        await logManager.debug("🧪 TEST: Scan completed, current file count: \(fileStore.files.count)", category: "TestDebugging")
        
        for (index, file) in fileStore.files.enumerated() {
            await logManager.debug("🧪 TEST: File \(index): \(file.sourceName) - status: \(file.status) - destPath: \(file.destPath ?? "nil")", category: "TestDebugging")
        }
        
        let destB = destB_URL!
        await logManager.debug("🧪 TEST: About to change destination to: \(destB.path)", category: "TestDebugging")
        
        await logManager.debug("🧪 TEST: Setting up publisher coordination BEFORE destination change", category: "TestDebugging")
        
        // Set up expectations BEFORE triggering the operation
        let recalculationFinished = expectation(description: "Recalculation finished")
        let filesUpdated = expectation(description: "Files updated")
        
        await logManager.debug("🧪 TEST: Setting up recalculationManager.didFinishPublisher subscription", category: "TestDebugging")
        recalculationManager.didFinishPublisher.sink { _ in 
            Task { await self.logManager.debug("🧪 TEST: ✅ RecalculationManager didFinish publisher fired!", category: "TestDebugging") }
            recalculationFinished.fulfill() 
        }.store(in: &cancellables)
        
        await logManager.debug("🧪 TEST: Setting up fileStore.$files subscription", category: "TestDebugging")
        fileStore.$files.dropFirst().sink { files in
            Task { await self.logManager.debug("🧪 TEST: Files updated, count: \(files.count)", category: "TestDebugging") }
            let allMatch = files.allSatisfy({ $0.destPath?.contains(destB.lastPathComponent) ?? false })
            Task { await self.logManager.debug("🧪 TEST: All files match destB: \(allMatch)", category: "TestDebugging") }
            if allMatch && files.count == 3 {
                Task { await self.logManager.debug("🧪 TEST: ✅ Files updated expectation fulfilled!", category: "TestDebugging") }
                filesUpdated.fulfill()
            } else {
                Task { await self.logManager.debug("🧪 TEST: ❌ Not fulfilling yet - allMatch: \(allMatch), count: \(files.count)", category: "TestDebugging") }
            }
        }.store(in: &cancellables)

        await logManager.debug("🧪 TEST: Current isRecalculating before destination change: \(appState.isRecalculating)", category: "TestDebugging")
        await logManager.debug("🧪 TEST: NOW triggering destination change to destB", category: "TestDebugging")
        settingsStore.setDestination(destB)
        await logManager.debug("🧪 TEST: Destination change triggered, isRecalculating now: \(appState.isRecalculating)", category: "TestDebugging")

        await logManager.debug("🧪 TEST: Waiting for expectations to be fulfilled (timeout: 10s)", category: "TestDebugging")
        await fulfillment(of: [recalculationFinished, filesUpdated], timeout: 15)
        await logManager.debug("🧪 TEST: ✅ Both expectations fulfilled!", category: "TestDebugging")

        await logManager.debug("🧪 TEST: Final verification - file count: \(fileStore.files.count)", category: "TestDebugging")
        XCTAssertEqual(fileStore.files.count, 3)
        XCTAssertFalse(appState.isRecalculating)
        XCTAssertTrue(fileStore.files.allSatisfy { $0.status == .waiting })
        XCTAssertFalse(fileStore.files.first { $0.sourceName == "video.mov" }!.sidecarPaths.isEmpty)
        
        await logManager.debug("🧪 TEST: testRecalculationWithComplexFileStatuses - Complete", category: "TestDebugging")
    }
    
    func testRecalculationWithPreExistingFiles() async throws {
        let regularFile = sourceURL.appendingPathComponent("regular.jpg")
        createFile(at: regularFile)
        
        // Create pre-existing file in destination A
        let existingFile = sourceURL.appendingPathComponent("existing.jpg")
        createFile(at: existingFile)
        try fileManager.copyItem(at: existingFile, to: destA_URL.appendingPathComponent("existing.jpg"))

        settingsStore.setDestination(destA_URL)
        try await triggerScanAndWaitForCompletion(fileCount: 2)
        
        // Verify one file is pre-existing, one is waiting
        XCTAssertEqual(fileStore.files.filter { $0.status == .pre_existing }.count, 1)
        XCTAssertEqual(fileStore.files.filter { $0.status == .waiting }.count, 1)

        let destB = destB_URL!
        let recalculationFinished = expectation(description: "Recalculation finished")
        recalculationManager.didFinishPublisher.sink { _ in recalculationFinished.fulfill() }.store(in: &cancellables)
        
        settingsStore.setDestination(destB)
        await fulfillment(of: [recalculationFinished], timeout: 15)

        // After recalculation to new destination, all files should be waiting
        XCTAssertTrue(fileStore.files.allSatisfy { $0.status == .waiting })
        XCTAssertTrue(fileStore.files.allSatisfy { $0.destPath?.contains(destB.lastPathComponent) ?? false })
    }
    
    func testRecalculationWithSidecarFiles() async throws {
        await logManager.debug("🧪 TEST: testRecalculationWithSidecarFiles - Starting", category: "TestDebugging")
        
        createFile(at: sourceURL.appendingPathComponent("video.mov"))
        createFile(at: sourceURL.appendingPathComponent("video.xmp"))
        createFile(at: sourceURL.appendingPathComponent("video.thm"))

        settingsStore.setDestination(destA_URL)
        try await triggerScanAndWaitForCompletion(fileCount: 1) // Only main file counted
        
        let videoFile = fileStore.files.first { $0.sourceName == "video.mov" }!
        XCTAssertEqual(videoFile.sidecarPaths.count, 2) // XMP and THM sidecars
        
        let destB = destB_URL!
        await logManager.debug("🧪 TEST: Setting up recalculation expectation", category: "TestDebugging")
        
        let recalculationFinished = expectation(description: "Recalculation finished")
        recalculationManager.didFinishPublisher.sink { _ in 
            Task { await self.logManager.debug("🧪 TEST: Recalculation finished", category: "TestDebugging") }
            recalculationFinished.fulfill() 
        }.store(in: &cancellables)
        
        await logManager.debug("🧪 TEST: Triggering destination change", category: "TestDebugging")
        settingsStore.setDestination(destB)
        await fulfillment(of: [recalculationFinished], timeout: 15)

        // Sidecar paths should be preserved after recalculation
        let recalculatedVideoFile = fileStore.files.first { $0.sourceName == "video.mov" }!
        XCTAssertEqual(recalculatedVideoFile.sidecarPaths.count, 2)
        XCTAssertTrue(recalculatedVideoFile.destPath?.contains(destB.lastPathComponent) ?? false)
        
        await logManager.debug("🧪 TEST: testRecalculationWithSidecarFiles - Complete", category: "TestDebugging")
    }
}
