import XCTest
@testable import Media_Muncher

// MARK: - DestinationPathBuilder Tests

final class DestinationPathBuilderTests: MediaMuncherTestCase {

    // Fixed date for deterministic results –  2025-01-01 12:00:00 UTC
    private let referenceDate = Date(timeIntervalSince1970: 1735732800) // 2025-01-01 12:00:00
    private let rootURL = URL(fileURLWithPath: "/Library/Destination")

    private func makeFile(name: String, mediaType: MediaType = .image) -> File {
        TestDataFactory.createTestFile(
            name: name,
            mediaType: mediaType,
            date: referenceDate,
            size: 1_024,
            sourcePath: "/Volumes/SD/" + name
        )
    }

    func testRelativePath_NoOrganize_NoRename() {
        // Given
        let file = makeFile(name: "IMG_0001.JPG")

        // When
        let rel = DestinationPathBuilder.relativePath(for: file, organizeByDate: false, renameByDate: false)

        // Then – keeps original base name but normalises extension case
        XCTAssertEqual(rel, "IMG_0001.jpg")
    }

    func testRelativePath_RenameByDate_PreservesDirectory() {
        // Given
        let file = makeFile(name: "some_random_name.heic")

        // When (rename only)
        let rel = DestinationPathBuilder.relativePath(for: file, organizeByDate: false, renameByDate: true)

        // Then – YYYYMMDD_HHMMSS.heif (preferred ext)
        XCTAssertEqual(rel, "20250101_120000.heif")
    }

    func testRelativePath_OrganizeAndRename() {
        // Given
        let file = makeFile(name: "CLIP.mov", mediaType: .video)

        // When (organize + rename)
        let rel = DestinationPathBuilder.relativePath(for: file, organizeByDate: true, renameByDate: true)

        // Then – directory + renamed base
        XCTAssertEqual(rel, "2025/01/20250101_120000.mov")
    }

    func testRelativePath_NilDate_FallsBackToOriginalName() {
        // Given – a file with no date at all (DestinationPathBuilder is pure; filesystem
        // fallback happens in FileProcessorService.getFileMetadata before this is called)
        let file = File(sourcePath: "/Volumes/SD/IMG_9999.JPG", mediaType: .image)
        XCTAssertNil(file.date)

        // When (organize + rename requested, but no date available)
        let rel = DestinationPathBuilder.relativePath(for: file, organizeByDate: true, renameByDate: true)

        // Then – keeps original name since there's no date to organize/rename by
        XCTAssertEqual(rel, "IMG_9999.jpg")
    }

    func testBuildFinalDestinationURL_AppendsSuffix() {
        // Given
        var settings = SettingsStore()
        settings.organizeByDate = true
        settings.renameByDate = true
        let file = makeFile(name: "music.aac", mediaType: .audio)

        // When – ask builder to append suffix 2
        let url = DestinationPathBuilder.buildFinalDestinationURL(for: file, in: rootURL, settings: settings, suffix: 2)

        // Then
        XCTAssertEqual(url.path, "/Library/Destination/2025/01/20250101_120000_2.aac")
    }
}
