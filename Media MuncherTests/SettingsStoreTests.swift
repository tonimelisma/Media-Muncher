import XCTest
@testable import Media_Muncher

// MARK: - Settings Store Tests

class SettingsStoreTests: XCTestCase {

    var settingsStore: SettingsStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        settingsStore = SettingsStore(userDefaults: testDefaults)
    }

    override func tearDownWithError() throws {
        settingsStore = nil
        try super.tearDownWithError()
    }
    
    // Automation-related tests removed (feature deferred)
} 