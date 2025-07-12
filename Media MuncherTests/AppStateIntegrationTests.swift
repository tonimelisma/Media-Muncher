import XCTest
import Combine
@testable import Media_Muncher

@MainActor
final class AppStateIntegrationTests: XCTestCase {

    var sourceURL: URL!
    var destinationA_URL: URL!
    var destinationB_URL: URL!
    var fileManager: FileManager!
    var settingsStore: SettingsStore!
    var fileProcessorService: FileProcessorService!
    var importService: ImportService!
    var volumeManager: VolumeManager!
    var appState: AppState!
    private var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        cancellables = []

        // Create unique temporary source and destination directories
        sourceURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destinationA_URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        destinationB_URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationA_URL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationB_URL, withIntermediateDirectories: true)

        // Initialize services
        settingsStore = SettingsStore()
        fileProcessorService = FileProcessorService()
        importService = ImportService()
        volumeManager = VolumeManager()

        // Initialize AppState
        appState = AppState(
            volumeManager: volumeManager,
            mediaScanner: fileProcessorService,
            settingsStore: settingsStore,
            importService: importService
        )
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: sourceURL)
        try? fileManager.removeItem(at: destinationA_URL)
        try? fileManager.removeItem(at: destinationB_URL)
        sourceURL = nil
        destinationA_URL = nil
        destinationB_URL = nil
        fileManager = nil
        settingsStore = nil
        fileProcessorService = nil
        importService = nil
        volumeManager = nil
        appState = nil
        cancellables = nil
        try super.tearDownWithError()
    }

    private func setupSourceFile(named fileName: String) throws -> URL {
        guard let fixtureURL = Bundle(for: type(of: self)).url(forResource: fileName, withExtension: nil) else {
            throw TestError.fixtureNotFound(name: fileName)
        }
        let destinationInSource = sourceURL.appendingPathComponent(fileName)
        try fileManager.copyItem(at: fixtureURL, to: destinationInSource)
        return destinationInSource
    }

    func testDestinationChangeRecalculatesFileStatuses() async throws {
        // 1. SETUP
        // Create source files
        let file1_sourceURL = try setupSourceFile(named: "exif_image.jpg")
        _ = try setupSourceFile(named: "no_exif_image.heic")

        // Create a pre-existing file in Destination A
        try fileManager.copyItem(at: file1_sourceURL, to: destinationA_URL.appendingPathComponent("exif_image.jpg"))

        // 2. INITIAL SCAN (Destination A)
        // Set initial destination
        settingsStore.setDestination(destinationA_URL)

        // Create an expectation for the initial scan to complete
        let initialScanExpectation = XCTestExpectation(description: "Initial scan completes")

        appState.$files
            .dropFirst()
            .sink { files in
                if !files.isEmpty {
                    initialScanExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Trigger the scan by setting the selected volume
        appState.selectedVolume = sourceURL.path

        await fulfillment(of: [initialScanExpectation], timeout: 5.0)

        // 3. ASSERT INITIAL STATE
        // Find the file that should be pre-existing
        guard let preExistingFile = appState.files.first(where: { $0.sourcePath == file1_sourceURL.path }) else {
            XCTFail("Could not find the specified file in appState.files")
            return
        }
        XCTAssertEqual(preExistingFile.status, .pre_existing, "File should initially be marked as pre-existing in Destination A")
        XCTAssertEqual(appState.files.filter({ $0.status == .waiting }).count, 1, "One file should be in waiting state")

        // 4. CHANGE DESTINATION & RECALCULATE
        // Create an expectation for the file statuses to be recalculated
        let recalculationExpectation = XCTestExpectation(description: "File statuses are recalculated after destination change")

        appState.$files
            .dropFirst()
            .sink { files in
                // The recalculation is complete when all files are back to .waiting status
                if files.allSatisfy({ $0.status == .waiting }) {
                    recalculationExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Change the destination, which should trigger the recalculation
        settingsStore.setDestination(destinationB_URL)

        // 5. ASSERT FINAL STATE
        await fulfillment(of: [recalculationExpectation], timeout: 5.0)

        XCTAssertEqual(appState.files.count, 2, "There should still be two files")
        XCTAssertTrue(appState.files.allSatisfy { $0.status == .waiting }, "All files should be marked as .waiting in Destination B")
    }
}
