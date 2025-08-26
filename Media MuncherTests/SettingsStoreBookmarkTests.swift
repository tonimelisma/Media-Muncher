import XCTest
@testable import Media_Muncher

final class SettingsStoreBookmarkTests: XCTestCase {
    func testDestinationBookmarkPersistsAndResolves() throws {
        // Arrange isolated defaults and temp destination
        let defaults = UserDefaults(suiteName: "test.bookmarks.\(UUID().uuidString)")!
        let fm = FileManager.default
        let destDir = fm.temporaryDirectory.appendingPathComponent("bookmarkDest_\(UUID().uuidString)")
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Create store and set destination
        var store: SettingsStore? = SettingsStore(userDefaults: defaults)
        XCTAssertTrue(store!.trySetDestination(destDir))
        XCTAssertEqual(store!.destinationURL?.standardizedFileURL, destDir.standardizedFileURL)

        // Recreate store to simulate app relaunch
        store = nil
        let store2 = SettingsStore(userDefaults: defaults)

        // Assert bookmark resolves to the same destination
        XCTAssertEqual(store2.destinationURL?.standardizedFileURL, destDir.standardizedFileURL)
    }

    func testInvalidBookmarkIsClearedAndFallsBackToDefault() throws {
        // Arrange isolated defaults with invalid bookmark data
        let defaults = UserDefaults(suiteName: "test.bookmarks.invalid.\(UUID().uuidString)")!
        let invalid = Data([0x00, 0x01, 0x02, 0x03])
        defaults.set(invalid, forKey: "destinationBookmark")

        // Act: initialize store
        let store = SettingsStore(userDefaults: defaults)

        // Assert: destination is computed default and invalid bookmark removed
        XCTAssertNotNil(store.destinationURL)
        XCTAssertNil(defaults.object(forKey: "destinationBookmark"))
    }
}
