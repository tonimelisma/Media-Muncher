import Testing
@testable import Media_Muncher

struct HelperFunctionsTests {

    // MARK: - determineMediaType(for:)
    @Test func classifierDetectsCommonExtensions() throws {
        #expect(determineMediaType(for: "/tmp/file.jpg") == .image)
        #expect(determineMediaType(for: "/tmp/clip.MOV") == .video)
        #expect(determineMediaType(for: "/tmp/audio.Mp3") == .audio)
        #expect(determineMediaType(for: "/tmp/unknown.xyz") == .unknown)
    }

    // MARK: - preferredFileExtension(for:)
    @Test func preferredExtensionMapping() throws {
        #expect(preferredFileExtension(for: "jpeg") == "jpg")
        #expect(preferredFileExtension(for: "tif") == "tiff")
        #expect(preferredFileExtension(for: "png") == "png")
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