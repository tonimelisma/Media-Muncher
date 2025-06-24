import Testing
@testable import Media_Muncher

struct HelperFunctionsTests {

    // MARK: - determineMediaType(for:)
    @Test func classifierDetectsCommonExtensions() throws {
        #expect(MediaType.from(filePath: "/tmp/file.jpg") == .image)
        #expect(MediaType.from(filePath: "/tmp/clip.MOV") == .video)
        #expect(MediaType.from(filePath: "/tmp/audio.Mp3") == .audio)
        #expect(MediaType.from(filePath: "/tmp/unknown.xyz") == .unknown)
    }

    // MARK: - preferredFileExtension(for:)
    @Test func preferredExtensionMapping() throws {
        #expect(DestinationPathBuilder.preferredFileExtension("jpeg") == "jpg")
        #expect(DestinationPathBuilder.preferredFileExtension("tif") == "tiff")
        #expect(DestinationPathBuilder.preferredFileExtension("png") == "png")
    }

    // MARK: - Volume equality logic
    @Test func volumeEqualityUsesUUID() throws {
        let uuid = "1234-ABCD"
        let volumeA = Volume(name: "SD Card", devicePath: "/Volumes/SD1", volumeUUID: uuid)
        let volumeB = Volume(name: "Backup", devicePath: "/Volumes/SD_BACKUP", volumeUUID: uuid)
        let volumeC = Volume(name: "Other", devicePath: "/Volumes/OTHER", volumeUUID: "ZZZZ-1111")

        #expect(volumeA == volumeB)
        #expect(volumeA != volumeC)
    }
} 