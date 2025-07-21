import XCTest
@testable import Media_Muncher

final class DestinationPathBuilderExtensionTests: XCTestCase {

    private let referenceDate = Date(timeIntervalSince1970: 1735732800) // 2025-01-01 12:00:00 UTC
    private let rootURL = URL(fileURLWithPath: "/DestinationRoot")

    private func makeFile(name: String, mediaType: MediaType = .image) -> File {
        File(
            sourcePath: "/Volumes/SD/" + name,
            mediaType: mediaType,
            date: referenceDate,
            size: 1024,
            destPath: nil,
            status: .waiting,
            thumbnail: nil,
            importError: nil
        )
    }

    func testPreferredExtensionMapping() {
        let mappings: [(String,String)] = [
            ("jpeg", "jpg"),
            ("JPEG", "jpg"),
            ("HeIc", "heif"),
            ("tif", "tiff"),
            ("mp4", "mp4") // unchanged
        ]
        for (input, expected) in mappings {
            XCTAssertEqual(DestinationPathBuilder.preferredFileExtension(input), expected)
        }
    }

    func testRelativePath_OrganizeOnly() {
        let file = makeFile(name: "IMG_1234.JPEG")
        let rel = DestinationPathBuilder.relativePath(for: file, organizeByDate: true, renameByDate: false)
        XCTAssertEqual(rel, "2025/01/IMG_1234.jpg") // ext normalised + directory added
    }

    func testBuildFinalDestinationUrl_NoSuffix() {
        var settings = SettingsStore()
        settings.organizeByDate = true
        settings.renameByDate = true
        let file = makeFile(name: "clip.mp4", mediaType: .video)
        let url = DestinationPathBuilder.buildFinalDestinationUrl(for: file, in: rootURL, settings: settings)
        XCTAssertEqual(url.path, "/DestinationRoot/2025/01/20250101_120000.mp4")
    }

    func testBuildFinalDestinationUrl_MultipleSuffixes() {
        var settings = SettingsStore()
        settings.organizeByDate = true
        settings.renameByDate = true
        let file = makeFile(name: "sound.aac", mediaType: .audio)
        let first = DestinationPathBuilder.buildFinalDestinationUrl(for: file, in: rootURL, settings: settings, suffix: 1)
        let second = DestinationPathBuilder.buildFinalDestinationUrl(for: file, in: rootURL, settings: settings, suffix: 2)
        XCTAssertEqual(first.path, "/DestinationRoot/2025/01/20250101_120000_1.aac")
        XCTAssertEqual(second.path, "/DestinationRoot/2025/01/20250101_120000_2.aac")
    }
} 