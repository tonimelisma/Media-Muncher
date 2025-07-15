import XCTest
@testable import Media_Muncher

// MARK: - SettingsStore Persistence & Defaults

final class SettingsStorePersistenceTests: XCTestCase {

    private var testDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    override func tearDownWithError() throws {
        testDefaults = nil
        try super.tearDownWithError()
    }

    private func makeStore() -> SettingsStore {
        return SettingsStore(userDefaults: testDefaults)
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