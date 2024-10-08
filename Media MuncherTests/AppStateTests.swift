import XCTest
@testable import Media_Muncher

class AppStateTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        appState = AppState()
    }
    
    override func tearDownWithError() throws {
        appState = nil
        try super.tearDownWithError()
    }
    
    func testInitialization() {
        XCTAssertNotNil(appState, "AppState should be initialized")
        XCTAssertTrue(appState.volumes.isEmpty, "Volumes should be empty on initialization")
        XCTAssertNil(appState.selectedVolumeID, "Selected volume ID should be nil on initialization")
        XCTAssertEqual(appState.defaultSavePath, NSHomeDirectory(), "Default save path should be the home directory on initialization")
    }
    
    func testSettingAndGettingVolumes() {
        let testVolumes = [
            Volume(id: "1", name: "Test Volume 1", devicePath: "/test/path1", totalSize: 1000, freeSize: 500, volumeUUID: "uuid1"),
            Volume(id: "2", name: "Test Volume 2", devicePath: "/test/path2", totalSize: 2000, freeSize: 1000, volumeUUID: "uuid2")
        ]
        
        appState.volumes = testVolumes
        
        XCTAssertEqual(appState.volumes.count, 2, "AppState should have 2 volumes")
        XCTAssertEqual(appState.volumes[0].id, "1", "First volume should have id '1'")
        XCTAssertEqual(appState.volumes[1].name, "Test Volume 2", "Second volume should have name 'Test Volume 2'")
    }
    
    func testSettingAndGettingSelectedVolumeID() {
        appState.selectedVolumeID = "test_id"
        XCTAssertEqual(appState.selectedVolumeID, "test_id", "Selected volume ID should be 'test_id'")
    }
    
    func testSettingAndGettingDefaultSavePath() {
        let testPath = "/Users/test/Documents"
        appState.defaultSavePath = testPath
        XCTAssertEqual(appState.defaultSavePath, testPath, "Default save path should be set to the test path")
    }
    
    func testPersistenceOfDefaultSavePath() {
        let testPath = "/Users/test/Downloads"
        appState.defaultSavePath = testPath
        
        // Simulate app restart by creating a new AppState instance
        let newAppState = AppState()
        
        XCTAssertEqual(newAppState.defaultSavePath, testPath, "Default save path should persist after app restart")
    }
}
