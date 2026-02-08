//  TestAppContainer.swift
//  Media MuncherTests
//
//  Lightweight container used only by the test target. Keeps production code free of test helpers.
//

import Foundation
@testable import Media_Muncher

/// A minimal dependency container for tests. Uses MockLogManager and in-memory defaults.
/// Fixed to prevent retain cycles that block proper service deallocation.
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

    init(userDefaults: UserDefaults = .init(suiteName: "TestDefaults-\(UUID().uuidString)")!) {
        let mockLog = MockLogManager()
        self.logManager = mockLog
        
        // Create thumbnail cache with smaller limit for tests
        self.thumbnailCache = ThumbnailCache.testInstance(limit: 32)
        
        // Create services in dependency order to avoid retain cycles
        self.volumeManager = VolumeManager(logManager: mockLog)
        self.fileProcessorService = FileProcessorService(logManager: mockLog, thumbnailCache: thumbnailCache)
        self.settingsStore = SettingsStore(logManager: mockLog, userDefaults: userDefaults)
        self.importService = ImportService(logManager: mockLog)
        self.fileStore = FileStore(logManager: mockLog)
        
        // RecalculationManager depends on fileProcessorService, settingsStore, and fileStore
        // but doesn't create circular references as it only calls methods on them
        self.recalculationManager = RecalculationManager(
            logManager: mockLog,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore,
            fileStore: fileStore
        )
    }
} 
