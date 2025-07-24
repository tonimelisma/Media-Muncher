//  TestAppContainer.swift
//  Media MuncherTests
//
//  Lightweight container used only by the test target. Keeps production code free of test helpers.
//

import Foundation
@testable import Media_Muncher

/// A minimal dependency container for tests. Uses MockLogManager and in-memory defaults.
@MainActor
final class TestAppContainer {
    let logManager: Logging
    let volumeManager: VolumeManager
    let fileProcessorService: FileProcessorService
    let settingsStore: SettingsStore
    let importService: ImportService
    let fileStore: FileStore
    let recalculationManager: RecalculationManager
    let thumbnailCache: ThumbnailCache

    init(userDefaults: UserDefaults = .init(suiteName: "TestDefaults-")!) {
        let mockLog = MockLogManager()
        self.logManager = mockLog
        self.volumeManager = VolumeManager(logManager: mockLog)
        self.thumbnailCache = ThumbnailCache(limit: 128)
        self.fileProcessorService = FileProcessorService(logManager: mockLog, thumbnailCache: thumbnailCache)
        self.settingsStore = SettingsStore(logManager: mockLog, userDefaults: userDefaults)
        self.importService = ImportService(logManager: mockLog)
        
        // These services are @MainActor and initialize synchronously
        self.fileStore = FileStore(logManager: mockLog)
        self.recalculationManager = RecalculationManager(logManager: mockLog, fileProcessorService: fileProcessorService, settingsStore: settingsStore)
    }
} 