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

// MARK: - ThumbnailCache
extension ThumbnailCache {
    convenience init(limit: Int) {
        self.init(limit: limit, logManager: MockLogManager())
    }
}

// MARK: - FileProcessorService
extension FileProcessorService {
    convenience init(logManager: Logging = MockLogManager()) {
        let cache = ThumbnailCache(limit: 16, logManager: logManager)
        self.init(logManager: logManager, thumbnailCache: cache)
    }
}

// MARK: - ImportService
extension ImportService {
    convenience init(urlAccessWrapper: SecurityScopedURLAccessWrapperProtocol) {
        self.init(logManager: MockLogManager(), urlAccessWrapper: urlAccessWrapper)
    }
    convenience init() {
        self.init(logManager: MockLogManager())
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
