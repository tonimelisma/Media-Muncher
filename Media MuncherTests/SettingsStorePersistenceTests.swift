import XCTest
@testable import Media_Muncher

// MARK: - SettingsStore Persistence & Defaults

final class SettingsStorePersistenceTests: XCTestCase {

    private let userDefaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        userDefaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        super.tearDown()
    }

    private func makeStore() -> SettingsStore {
        return SettingsStore()
    }

    func testDefaultValues() {
        let store = makeStore()
        XCTAssertTrue(store.filterImages)
        XCTAssertTrue(store.filterVideos)
        XCTAssertTrue(store.filterAudio)
        XCTAssertFalse(store.settingDeleteOriginals)
        XCTAssertFalse(store.organizeByDate)
        XCTAssertFalse(store.renameByDate)
        XCTAssertFalse(store.settingAutoEject)
    }
} 