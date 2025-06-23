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
    
    // MARK: - Automation Settings Tests
    
    func test_automationSetting_defaultsToAsk() {
        // Given
        let uuid = UUID().uuidString
        
        // When
        let setting = settingsStore.automationSetting(for: uuid)
        
        // Then
        XCTAssertEqual(setting, .ask, "The default automation setting for an unknown UUID should be .ask")
    }
    
    func test_setAutomationSetting_persistsSetting() {
        // Given
        let uuid = UUID().uuidString
        let expectedSetting = AutomationSetting.autoImport
        
        // When
        settingsStore.setAutomationSetting(for: uuid, setting: expectedSetting)
        
        // Then
        let newSettingsStore = SettingsStore() // Create a new instance to force reload from UserDefaults
        let actualSetting = newSettingsStore.automationSetting(for: uuid)
        XCTAssertEqual(actualSetting, expectedSetting, "The setting should be persisted and reloaded correctly.")
    }

    func test_setAutomationSetting_doesNotAffectOtherUUIDs() {
        // Given
        let uuid1 = UUID().uuidString
        let uuid2 = UUID().uuidString
        let setting1 = AutomationSetting.autoImport
        let setting2_default = settingsStore.automationSetting(for: uuid2)

        // When
        settingsStore.setAutomationSetting(for: uuid1, setting: setting1)
        
        // Then
        let newSettingsStore = SettingsStore()
        let actualSetting1 = newSettingsStore.automationSetting(for: uuid1)
        let actualSetting2 = newSettingsStore.automationSetting(for: uuid2)

        XCTAssertEqual(actualSetting1, setting1, "The setting for the first UUID should be correctly set.")
        XCTAssertEqual(actualSetting2, .ask, "The setting for the second UUID should remain the default.")
        XCTAssertEqual(actualSetting2, setting2_default, "The setting for the second UUID should not have changed.")
    }
    
    func test_volumeAutomationSettings_encodesAndDecodesSuccessfully() {
        // Given
        let uuid1 = UUID().uuidString
        let uuid2 = UUID().uuidString
        
        settingsStore.setAutomationSetting(for: uuid1, setting: .ignore)
        settingsStore.setAutomationSetting(for: uuid2, setting: .autoImport)
        
        // When
        // The saving is done automatically via didSet. We create a new store to trigger loading.
        let newSettingsStore = SettingsStore()
        
        // Then
        let settings = newSettingsStore.volumeAutomationSettings
        XCTAssertEqual(settings.count, 2)
        XCTAssertEqual(settings[uuid1], .ignore)
        XCTAssertEqual(settings[uuid2], .autoImport)
    }
}

// MARK: - Import Logic Tests (Driven by Settings)

class ImportServiceWithSettingsTests: XCTestCase {

    var importService: ImportService!
    var mockFileManager: MockFileManager!
    var mockURLAccessWrapper: MockSecurityScopedURLAccessWrapper!
    var sourceURL: URL!
    var destinationURL: URL!
    // Use a fixed date to make tests deterministic
    let fixedDate = Date(timeIntervalSince1970: 1672531200) // 2023-01-01 00:00:00 UTC

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockFileManager = MockFileManager()
        mockURLAccessWrapper = MockSecurityScopedURLAccessWrapper()
        importService = ImportService(fileManager: mockFileManager, urlAccessWrapper: mockURLAccessWrapper)
        // Inject the fixed date provider
        importService.nowProvider = { self.fixedDate }
        
        sourceURL = URL(fileURLWithPath: "/source")
        destinationURL = URL(fileURLWithPath: "/destination")
        
        mockFileManager.virtualFileSystem = [
            "/source/file1.jpg": Data(count: 100),
            "/source/file2.mov": Data(count: 200),
        ]
    }

    override func tearDownWithError() throws {
        importService = nil
        mockFileManager = nil
        mockURLAccessWrapper = nil
        sourceURL = nil
        destinationURL = nil
        try super.tearDownWithError()
    }
    
    private func createSettings(organize: Bool, rename: Bool, deleteOriginals: Bool = false) -> SettingsStore {
        let settings = SettingsStore()
        settings.organizeByDate = organize
        settings.renameByDate = rename
        settings.settingDeleteOriginals = deleteOriginals
        return settings
    }

    func testImportFiles_NoOrganizeNoRename() async throws {
        let settings = createSettings(organize: false, rename: false)
        let fileModels = [
            File(sourcePath: "/source/file1.jpg", mediaType: .image, date: nil, size: 100, status: .waiting),
            File(sourcePath: "/source/file2.mov", mediaType: .video, date: nil, size: 200, status: .waiting)
        ]

        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings, progressHandler: nil)

        XCTAssertEqual(mockFileManager.copiedFiles.count, 2)
        XCTAssertTrue(mockFileManager.fileExists(atPath: "/destination/file1.jpg"))
        XCTAssertTrue(mockFileManager.fileExists(atPath: "/destination/file2.mov"))
    }

    func testImportFiles_OrganizeByDateOnly() async throws {
        let settings = createSettings(organize: true, rename: false)
        let fileModels = [File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: 100, status: .waiting)]

        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings, progressHandler: nil)

        let expectedPath = "/destination/2023/01/file1.jpg"
        XCTAssertTrue(mockFileManager.fileExists(atPath: expectedPath))
    }

    func testImportFiles_RenameByDateOnly() async throws {
        let settings = createSettings(organize: false, rename: true)
        let fileModels = [File(sourcePath: "/source/file1.jpg", mediaType: .image, date: fixedDate, size: 100, status: .waiting)]
        
        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings, progressHandler: nil)

        let expectedPath = "/destination/IMG_20230101_000000.jpg"
        XCTAssertTrue(mockFileManager.fileExists(atPath: expectedPath))
    }

    func testImportFiles_WhenDeleteOriginalsIsTrue_DeletesSourceFiles() async throws {
        let settings = createSettings(organize: false, rename: false, deleteOriginals: true)
        let fileModels = [
            File(sourcePath: "/source/file1.jpg", mediaType: .image, date: nil, size: 100, status: .waiting),
        ]

        try await importService.importFiles(files: fileModels, to: destinationURL, settings: settings, progressHandler: nil)

        XCTAssertEqual(mockFileManager.removedItems.count, 1)
        XCTAssertTrue(mockFileManager.removedItems.contains(URL(fileURLWithPath: "/source/file1.jpg")))
        XCTAssertNil(mockFileManager.virtualFileSystem["/source/file1.jpg"])
    }
} 