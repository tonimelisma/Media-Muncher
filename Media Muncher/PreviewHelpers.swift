//
//  PreviewHelpers.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

#if DEBUG
import SwiftUI

/// Lightweight factories for creating preview-ready environment objects
/// without the full AppContainer. Only compiled in DEBUG builds.
enum PreviewHelpers {

    // MARK: - Noop Logger

    private struct NoopLogger: Logging, @unchecked Sendable {
        func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]?) async {}
    }

    // MARK: - Factories

    static func settingsStore() -> SettingsStore {
        SettingsStore(logManager: NoopLogger(), userDefaults: .init(suiteName: "PreviewHelpers")!, bookmarkStore: BookmarkStore())
    }

    @MainActor static func fileStore(files: [File] = []) -> FileStore {
        let store = FileStore(logManager: NoopLogger())
        store.setFiles(files)
        return store
    }

    static func volumeManager() -> VolumeManager {
        VolumeManager(logManager: NoopLogger())
    }

    @MainActor static func appState() -> AppState {
        let logger = NoopLogger()
        let settings = settingsStore()
        let vm = volumeManager()
        let thumbnailCache = ThumbnailCache(limit: 10, logManager: logger)
        let fs = fileStore()
        let fps = FileProcessorService(logManager: logger, thumbnailCache: thumbnailCache)
        let rm = RecalculationManager(logManager: logger, fileProcessorService: fps, settingsStore: settings, fileStore: fs)
        return AppState(
            logManager: logger,
            volumeManager: vm,
            fileProcessorService: fps,
            settingsStore: settings,
            importService: ImportService(logManager: logger),
            recalculationManager: rm,
            fileStore: fs
        )
    }

    // MARK: - Sample Data

    static func sampleFiles() -> [File] {
        [
            File(sourcePath: "/Volumes/SD/DCIM/IMG_0001.jpg", mediaType: .image, size: 3_500_000, status: .waiting),
            File(sourcePath: "/Volumes/SD/DCIM/IMG_0002.cr3", mediaType: .raw, size: 25_000_000, status: .pre_existing),
            File(sourcePath: "/Volumes/SD/DCIM/MOV_0003.mov", mediaType: .video, size: 150_000_000, status: .imported),
            File(sourcePath: "/Volumes/SD/DCIM/IMG_0004.jpg", mediaType: .image, size: 4_200_000, status: .copying),
            File(sourcePath: "/Volumes/SD/DCIM/IMG_0005.heic", mediaType: .image, size: 2_800_000, status: .failed),
            File(sourcePath: "/Volumes/SD/DCIM/IMG_0006.dng", mediaType: .raw, size: 20_000_000, status: .duplicate_in_source),
            File(sourcePath: "/Volumes/SD/DCIM/IMG_0007.jpg", mediaType: .image, size: 3_100_000, status: .deleted_as_duplicate),
        ]
    }
}
#endif
