import XCTest
@testable import Media_Muncher

final class FileProcessorServicePreExistingRenameTests: XCTestCase {
    var tempSrcDir: URL!
    var tempDestDir: URL!
    var fileManager: FileManager!
    var settings: SettingsStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default
        tempSrcDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        tempDestDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempSrcDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempDestDir, withIntermediateDirectories: true)

        settings = SettingsStore()
        settings.renameByDate = true   // Enable date-based renaming
        settings.organizeByDate = true // Enable YYYY/MM folder structure
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempSrcDir)
        try? fileManager.removeItem(at: tempDestDir)
        tempSrcDir = nil
        tempDestDir = nil
        settings = nil
        fileManager = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers
    private func createFile(at url: URL, contents: Data = Data([0xDE, 0xAD, 0xBE, 0xEF])) {
        fileManager.createFile(atPath: url.path, contents: contents)
    }

    // This replicates the logic found in DestinationPathBuilder when both organizeByDate & renameByDate are enabled.
    private func expectedRelativePath(for date: Date, ext: String) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let directory = String(format: "%04d/%02d/", comps.year!, comps.month!)
        let base = String(format: "%04d%02d%02d_%02d%02d%02d", comps.year!, comps.month!, comps.day!, comps.hour!, comps.minute!, comps.second!)
        return directory + base + "." + ext
    }

    func testDetectsPreExistingFileWhenRenamedByDate() async throws {
        // 1. Create source JPEG file
        let sourceURL = tempSrcDir.appendingPathComponent("holiday.jpg")
        createFile(at: sourceURL)

        // 2. Set creation & modification timestamps to a fixed date so DestinationPathBuilder is deterministic
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z for example
        try fileManager.setAttributes([.creationDate: fixedDate, .modificationDate: fixedDate], ofItemAtPath: sourceURL.path)

        // 3. Compute the expected destination path *as Media Muncher would*
        let relativePath = expectedRelativePath(for: fixedDate, ext: "jpg")
        let destFileURL = tempDestDir.appendingPathComponent(relativePath)

        // Ensure directory exists
        try fileManager.createDirectory(at: destFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // 4. Copy the *identical* file to destination to simulate a previous import
        try fileManager.copyItem(at: sourceURL, to: destFileURL)

        // 5. Process files – should mark as .pre_existing instead of allocating “_1” suffix
        let processor = FileProcessorService.testInstance()
        let processed = await processor.processFiles(from: tempSrcDir, destinationURL: tempDestDir, settings: settings)
        guard let result = processed.first else {
            XCTFail("No file processed")
            return
        }

        XCTAssertEqual(result.status, .pre_existing, "Expected file to be recognised as pre-existing but got \(result.status)")
        XCTAssertEqual(result.destPath, destFileURL.path, "Destination path mismatch (\(result.destPath ?? "nil"))")
    }
} 
