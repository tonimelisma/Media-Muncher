import Foundation
@testable import Media_Muncher

// Test-only convenience initializers to adapt to new explicit DI without
// touching every test call site.

// MARK: - SettingsStore
extension SettingsStore {
    convenience init(logManager: Logging, userDefaults: UserDefaults) {
        self.init(logManager: logManager, userDefaults: userDefaults, bookmarkStore: BookmarkStore())
    }
    convenience init(userDefaults: UserDefaults) {
        self.init(logManager: MockLogManager(), userDefaults: userDefaults, bookmarkStore: BookmarkStore())
    }
    convenience init(logManager: Logging) {
        self.init(logManager: logManager, userDefaults: .standard, bookmarkStore: BookmarkStore())
    }
    convenience init() {
        self.init(logManager: MockLogManager(), userDefaults: .standard, bookmarkStore: BookmarkStore())
    }
}

// MARK: - ThumbnailCache (Test Factory)
extension ThumbnailCache {
    static func testInstance(limit: Int) -> ThumbnailCache {
        ThumbnailCache(limit: limit, logManager: MockLogManager())
    }
}

// MARK: - FileProcessorService (Test Factory)
extension FileProcessorService {
    static func testInstance(logManager: Logging = MockLogManager()) -> FileProcessorService {
        let cache = ThumbnailCache(limit: 16, logManager: logManager)
        return FileProcessorService(logManager: logManager, thumbnailCache: cache)
    }
}

// MARK: - ImportService (Test Factory)
extension ImportService {
    static func testInstance(urlAccessWrapper: SecurityScopedURLAccessWrapperProtocol) -> ImportService {
        ImportService(logManager: MockLogManager(), urlAccessWrapper: urlAccessWrapper)
    }
    static func testInstance() -> ImportService {
        ImportService(logManager: MockLogManager())
    }
}

// MARK: - VolumeManager
extension VolumeManager {
    convenience init() {
        self.init(logManager: MockLogManager())
    }
}

// MARK: - RecalculationManager
extension RecalculationManager {
    convenience init(fileProcessorService: FileProcessorService, settingsStore: SettingsStore) {
        self.init(logManager: MockLogManager(), fileProcessorService: fileProcessorService, settingsStore: settingsStore)
    }
}
