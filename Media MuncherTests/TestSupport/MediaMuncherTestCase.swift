import XCTest
import Foundation
import Combine
@testable import Media_Muncher

/// Base test case class for all Media Muncher tests providing common setup and utilities
@MainActor
class MediaMuncherTestCase: XCTestCase {
    
    // MARK: - Common Properties
    
    /// Temporary directory unique to this test instance
    var tempDirectory: URL!
    
    /// File manager instance for test file operations
    var fileManager: FileManager!
    
    /// Common cancellables set for publisher subscriptions
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables?.removeAll()
        cancellables = nil
        try? fileManager.removeItem(at: tempDirectory)
        tempDirectory = nil
        fileManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Async Test Coordination
    
    /// Creates a test app container for async testing with proper logging
    func createTestContainer() -> TestAppContainer {
        let container = TestAppContainer()
        Task { await logTestStep("Created test container with MockLogManager") }
        return container
    }
    
    /// Sets up a basic integration test environment
    @MainActor
    func setupIntegrationTest() async throws -> (TestAppContainer, AppState, URL, URL) {
        await logTestStep("Setting up integration test environment")
        
        let container = createTestContainer()
        
        let srcDir = tempDirectory.appendingPathComponent("SRC")
        let destDir = tempDirectory.appendingPathComponent("DEST")
        
        try fileManager.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        
        let appState = AppState(
            logManager: container.logManager,
            volumeManager: container.volumeManager,
            fileProcessorService: container.fileProcessorService,
            settingsStore: container.settingsStore,
            importService: container.importService,
            recalculationManager: container.recalculationManager,
            fileStore: container.fileStore
        )
        
        await logTestStep("✅ Integration test environment ready")
        return (container, appState, srcDir, destDir)
    }
    
    // MARK: - File System Utilities
    
    /// Creates a test file with specified content at the given path
    func createTestFile(at url: URL, content: Data) throws {
        try content.write(to: url)
    }
    
    /// Creates a simple test file with minimal content
    func createTestFile(named fileName: String, in directory: URL? = nil) throws -> URL {
        let targetDirectory = directory ?? tempDirectory!
        let fileURL = targetDirectory.appendingPathComponent(fileName)
        let content = Data("test content".utf8)
        try content.write(to: fileURL)
        return fileURL
    }
    
    /// Creates test files using the improved helper pattern
    override func createTestFileStructure(in directory: URL) throws -> [URL] {
        return try createTestFileStructureSync(in: directory)
    }
    
    /// Synchronous version for compatibility with existing code
    nonisolated func createTestFileStructureSync(in directory: URL) throws -> [URL] {
        return try createTestFiles(in: directory)
    }
    
    /// Creates a pre-existing file for collision testing
    override func createPreExistingFile(source: URL, destination: URL) throws {
        let sourceData = try Data(contentsOf: source)
        try sourceData.write(to: destination)
        
        // Set same modification time to ensure it's detected as pre-existing
        let sourceAttributes = try FileManager.default.attributesOfItem(atPath: source.path)
        if let modDate = sourceAttributes[.modificationDate] as? Date {
            try FileManager.default.setAttributes([.modificationDate: modDate], ofItemAtPath: destination.path)
        }
    }
    
    // MARK: - Async Test Coordination Helpers
    
    /// Safely coordinates a destination change with proper expectation setup
    /// This helper eliminates race conditions by setting up expectations BEFORE triggering the change
    @MainActor
    func performDestinationChange<T>(
        change: () throws -> T,
        expectingRecalculation recalculationManager: RecalculationManager,
        expectingFilesUpdate fileStore: FileStore,
        filesCondition: @escaping ([File]) -> Bool = { _ in true },
        timeout: TimeInterval = 10
    ) async throws -> T {
        
        await logTestStep("Setting up destination change coordination")
        
        // Set up expectations BEFORE triggering change
        let recalculationFinished = expectation(description: "Recalculation finished")
        let filesUpdated = expectation(description: "Files updated")
        
        // Set up recalculation completion expectation
        recalculationManager.didFinishPublisher.sink { _ in
            Task { await self.logTestStep("✅ Recalculation finished") }
            recalculationFinished.fulfill()
        }.store(in: &self.cancellables)
        
        // Set up files update expectation with condition check
        fileStore.$files.dropFirst().sink { files in
            Task { await self.logTestStep("Files updated - count: \(files.count)") }
            if filesCondition(files) {
                Task { await self.logTestStep("✅ Files condition met, fulfilling expectation") }
                filesUpdated.fulfill()
            } else {
                Task { await self.logTestStep("Files condition not met yet") }
            }
        }.store(in: &self.cancellables)
        
        await logTestStep("Triggering destination change")
        let result = try change()
        
        await logTestStep("Waiting for expectations to be fulfilled")
        await fulfillment(of: [recalculationFinished, filesUpdated], timeout: timeout)
        await logTestStep("✅ All expectations fulfilled")
        
        return result
    }
    
    /// Safely waits for file processing to complete with logging (enhanced version)
    func waitForFileProcessingWithLogging(
        fileStore: FileStore,
        expectedCount: Int,
        timeout: TimeInterval = 10,
        testName: String = "File processing"
    ) async throws {
        
        await logTestStep("\(testName) - Waiting for \(expectedCount) files")
        
        _ = try await waitForPublisher(
            fileStore.$files.eraseToAnyPublisher(),
            timeout: timeout,
            description: testName
        ) { files in
            Task { await self.logTestStep("\(testName) - Current count: \(files.count), target: \(expectedCount)") }
            return files.count >= expectedCount
        }
        
        await logTestStep("\(testName) - ✅ Target count reached")
    }
    
    /// Sets up volume and triggers scanning with proper coordination
    @MainActor
    func setupVolumeAndScan(
        appState: AppState,
        fileStore: FileStore,
        sourceURL: URL,
        expectedFileCount: Int,
        timeout: TimeInterval = 10
    ) async throws {
        
        await logTestStep("Setting up test volume with path: \(sourceURL.path)")
        
        let testVolume = Volume(
            name: "TestVolume", 
            devicePath: sourceURL.path, 
            volumeUUID: UUID().uuidString
        )
        
        appState.volumes = [testVolume]
        appState.selectedVolumeID = testVolume.id
        
        await logTestStep("Volume set up, waiting for \(expectedFileCount) files to be processed")
        
        try await waitForFileProcessingWithLogging(
            fileStore: fileStore,
            expectedCount: expectedFileCount,
            timeout: timeout,
            testName: "Volume scan"
        )
    }
    
    /// Creates test files with proper signatures and logging
    nonisolated func createTestFiles(
        in directory: URL,
        files: [String] = ["photo.jpg", "video.mov", "audio.mp3"]
    ) throws -> [URL] {
        
        var createdFiles: [URL] = []
        let fm = FileManager.default
        
        for fileName in files {
            let fileURL = try TestDataFactory.createMediaFile(
                named: fileName,
                in: directory,
                fileManager: fm
            )
            createdFiles.append(fileURL)
        }
        
        Task { await logTestStep("Created \(createdFiles.count) test files: \(files.joined(separator: ", "))") }
        
        return createdFiles
    }
    
    /// Asserts file destination paths are valid with logging (enhanced version)
    func assertValidDestinationPathsWithLogging(
        files: [File],
        expectedDirectory: URL,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        Task { await logTestStep("Validating destination paths for \(files.count) files") }
        
        for mediaFile in files {
            XCTAssertNotNil(
                mediaFile.destPath,
                "File \(mediaFile.sourceName) should have destination path",
                file: file,
                line: line
            )
            XCTAssertTrue(
                mediaFile.destPath?.hasPrefix(expectedDirectory.path) ?? false,
                "File \(mediaFile.sourceName) destination should be in expected directory",
                file: file,
                line: line
            )
        }
        
        Task { await logTestStep("✅ All destination paths validated") }
    }
    
    /// Creates an expectation for recalculation completion with logging
    @MainActor
    func expectRecalculationFinish(
        _ recalculationManager: RecalculationManager,
        description: String = "Recalculation finished"
    ) -> XCTestExpectation {
        
        let expectation = expectation(description: description)
        
        recalculationManager.didFinishPublisher.sink { _ in
            Task { await self.logTestStep("✅ \(description)") }
            expectation.fulfill()
        }.store(in: &self.cancellables)
        
        return expectation
    }
    
    /// Creates an expectation for files update with condition
    @MainActor
    func expectFilesUpdate(
        _ fileStore: FileStore,
        condition: @escaping ([File]) -> Bool,
        description: String = "Files updated"
    ) -> XCTestExpectation {
        
        let expectation = expectation(description: description)
        
        fileStore.$files.dropFirst().sink { files in
            Task { await self.logTestStep("Files update check - count: \(files.count)") }
            if condition(files) {
                Task { await self.logTestStep("✅ \(description)") }
                expectation.fulfill()
            }
        }.store(in: &self.cancellables)
        
        return expectation
    }
}