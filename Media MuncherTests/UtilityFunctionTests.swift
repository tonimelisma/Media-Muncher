import XCTest
@testable import Media_Muncher

final class UtilityFunctionTests: XCTestCase {

    // MARK: determineMediaType(for:)
    func testClassifierDetectsCommonExtensions() {
        XCTAssertEqual(MediaType.from(filePath: "/tmp/file.jpg"), .image)
        XCTAssertEqual(MediaType.from(filePath: "/tmp/clip.MOV"), .video)
        XCTAssertEqual(MediaType.from(filePath: "/tmp/audio.Mp3"), .audio)
        XCTAssertEqual(MediaType.from(filePath: "/tmp/unknown.xyz"), .unknown)
    }

    // MARK: preferredFileExtension(for:)
    func testPreferredExtensionMapping() {
        XCTAssertEqual(DestinationPathBuilder.preferredFileExtension("jpeg"), "jpg")
        XCTAssertEqual(DestinationPathBuilder.preferredFileExtension("tif"), "tiff")
        XCTAssertEqual(DestinationPathBuilder.preferredFileExtension("png"), "png")
    }

    // MARK: Volume equality logic
    func testVolumeEqualityUsesDevicePath() {
        let volumeA = Volume(name: "SD Card", devicePath: "/Volumes/SD1", volumeUUID: "1234-ABCD")
        let volumeB = Volume(name: "Backup", devicePath: "/Volumes/SD1", volumeUUID: "ZZZZ-1111")
        let volumeC = Volume(name: "Other", devicePath: "/Volumes/OTHER", volumeUUID: "1234-ABCD")

        // Volume equality is based on devicePath, not volumeUUID
        XCTAssertEqual(volumeA, volumeB, "Same devicePath should be equal regardless of UUID")
        XCTAssertNotEqual(volumeA, volumeC, "Different devicePath should be unequal regardless of UUID")
        XCTAssertEqual(volumeA.id, volumeA.devicePath, "id should be devicePath")
    }
} 