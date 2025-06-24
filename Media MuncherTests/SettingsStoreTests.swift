import XCTest
@testable import Media_Muncher

// MARK: - Settings Store Tests

class SettingsStoreTests: XCTestCase {

    var settingsStore: SettingsStore!
    let userDefaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        // Clear UserDefaults for a clean slate before each test
        userDefaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        settingsStore = SettingsStore()
    }

    override func tearDown() {
        settingsStore = nil
        userDefaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        super.tearDown()
    }
    
    // Automation-related tests removed (feature deferred)
} 