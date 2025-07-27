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
    
    func testSynchronousInitialization() {
        // Verify that SettingsStore initialization is completely synchronous
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        
        let startTime = Date()
        let settingsStore = SettingsStore(userDefaults: testDefaults)
        let initTime = Date().timeIntervalSince(startTime)
        
        // Should complete very quickly (< 100ms) since it's synchronous
        XCTAssertLessThan(initTime, 0.1, "SettingsStore initialization should be synchronous and fast")
        
        // Should have destination immediately available
        XCTAssertNotNil(settingsStore.destinationURL, "Destination should be available immediately after init")
        
        // Verify it's a reasonable default directory
        let destination = settingsStore.destinationURL!
        let homeDir = NSHomeDirectory()
        let expectedPaths = [
            URL(fileURLWithPath: homeDir).appendingPathComponent("Pictures").path,
            URL(fileURLWithPath: homeDir).appendingPathComponent("Documents").path
        ]
        XCTAssertTrue(expectedPaths.contains(destination.path), 
                     "Default destination should be Pictures or Documents, got: \(destination.path)")
    }
    
    func testImmediateDestinationAvailability() {
        // Test the specific issue that was causing test failures
        let testDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let settingsStore = SettingsStore(userDefaults: testDefaults)
        
        // The race condition bug was that destinationURL might be nil immediately after init
        // This should now pass consistently
        XCTAssertNotNil(settingsStore.destinationURL, "Race condition fix: destinationURL should be immediately available")
    }
    
    // Automation-related tests removed (feature deferred)
} 