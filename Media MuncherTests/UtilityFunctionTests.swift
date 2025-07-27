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
    func testVolumeEqualityUsesUUID() {
        let uuid = "1234-ABCD"
        let volumeA = Volume(name: "SD Card", devicePath: "/Volumes/SD1", volumeUUID: uuid)
        let volumeB = Volume(name: "Backup", devicePath: "/Volumes/SD_BACKUP", volumeUUID: uuid)
        let volumeC = Volume(name: "Other", devicePath: "/Volumes/OTHER", volumeUUID: "ZZZZ-1111")

        XCTAssertEqual(volumeA.volumeUUID, volumeB.volumeUUID)
        XCTAssertNotEqual(volumeA.volumeUUID, volumeC.volumeUUID)
    }
} 