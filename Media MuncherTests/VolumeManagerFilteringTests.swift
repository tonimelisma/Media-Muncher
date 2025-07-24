import XCTest
@testable import Media_Muncher

// MARK: - VolumeManager filtering tests

final class VolumeManagerFilteringTests: XCTestCase {

    func testLoadVolumes_ReturnsOnlyRemovable() async {
        let vm = VolumeManager()
        let volumes = await vm.loadVolumes()
        for v in volumes {
            let url = URL(fileURLWithPath: v.devicePath)
            if let isRemovable = try? url.resourceValues(forKeys: [.volumeIsRemovableKey]).volumeIsRemovable {
                XCTAssertEqual(isRemovable, true, "Volume \(v.name) is not marked removable")
            } else {
                XCTFail("Could not read resource values for volume at \(url.path)")
            }
        }
    }
} 