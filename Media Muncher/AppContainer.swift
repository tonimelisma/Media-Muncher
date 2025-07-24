//
//  AppContainer.swift
//  Media Muncher
//
//  Dependency injection container for centralized service management
//

import Foundation

/// Centralized dependency injection container that instantiates and manages all shared services.
/// This class serves as the single source of truth for service instances and their dependencies.
///
/// ## Usage Pattern:
/// ```swift
/// // In Media_MuncherApp.swift
/// let container = AppContainer()
/// let appState = AppState(
///     logManager: container.logManager,
///     volumeManager: container.volumeManager,
///     // ... other services
/// )
/// ```
///
/// ## Benefits:
/// - Centralized service configuration
/// - Simplified dependency management
/// - Enhanced testability through mock injection
/// - Clear service dependency graph
final class AppContainer {
    
    // MARK: - Core Services
    
    /// Primary logging service used by all other services
    let logManager: Logging
    
    /// Volume discovery and management service
    let volumeManager: VolumeManager
    
    /// Thumbnail cache shared between file processor and UI
    let thumbnailCache: ThumbnailCache

    /// File scanning and metadata processing service  
    let fileProcessorService: FileProcessorService
    
    /// User preferences and settings management
    let settingsStore: SettingsStore
    
    /// File copying and import operations
    let importService: ImportService
    
    /// Centralized file state management for UI binding
    let fileStore: FileStore
    
    /// Destination change recalculation state machine
    let recalculationManager: RecalculationManager
    
    // MARK: - Initialization
    
    /// Creates a new container with all services properly initialized and wired together.
    /// Services are created in dependency order to ensure proper initialization.
    init() async {
        // Can't log before LogManager is created, so we use print here.
        print("DEBUG: AppContainer.init() starting - thread: \(Thread.current) - is main thread: \(Thread.isMainThread)")
        
        self.logManager = LogManager()
        await logManager.debug("AppContainer.init() started", category: "AppContainer")

        await logManager.debug("Creating VolumeManager...", category: "AppContainer")
        self.volumeManager = VolumeManager(logManager: logManager)
        await logManager.debug("VolumeManager created", category: "AppContainer")

        await logManager.debug("Creating ThumbnailCache...", category: "AppContainer")
        self.thumbnailCache = ThumbnailCache()
        await logManager.debug("ThumbnailCache created", category: "AppContainer")

        await logManager.debug("Creating FileProcessorService...", category: "AppContainer")
        self.fileProcessorService = FileProcessorService(logManager: logManager, thumbnailCache: thumbnailCache)
        await logManager.debug("FileProcessorService created", category: "AppContainer")

        await logManager.debug("Creating SettingsStore...", category: "AppContainer")
        self.settingsStore = SettingsStore(logManager: logManager)
        await logManager.debug("SettingsStore created", category: "AppContainer")

        await logManager.debug("Creating ImportService...", category: "AppContainer")
        self.importService = ImportService(logManager: logManager)
        await logManager.debug("ImportService created", category: "AppContainer")
        
        // These services are @MainActor, so their initialization must be awaited
        // from a non-MainActor context.
        await logManager.debug("Creating FileStore (MainActor)... About to await.", category: "AppContainer")
        self.fileStore = await FileStore(logManager: logManager)
        await logManager.debug("FileStore (MainActor) created successfully. Await finished.", category: "AppContainer")
        
        // Initialize services with dependencies last
        await logManager.debug("Creating RecalculationManager (MainActor)... About to await.", category: "AppContainer")
        self.recalculationManager = await RecalculationManager(
            logManager: logManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore
        )
        await logManager.debug("RecalculationManager (MainActor) created successfully. Await finished.", category: "AppContainer")
        
        await logManager.info("AppContainer initialized successfully", category: "AppContainer")
        print("DEBUG: AppContainer.init() completed")
    }
}

// MARK: - Testing Support

#if DEBUG
extension AppContainer {
    /// Creates a container with mock services for testing.
    /// This allows for isolated unit testing of individual components.
    static func mock(
        logManager: Logging? = nil,
        volumeManager: VolumeManager? = nil,
        fileProcessorService: FileProcessorService? = nil,
        settingsStore: SettingsStore? = nil,
        importService: ImportService? = nil,
        fileStore: FileStore? = nil
    ) -> AppContainer {
        // This would be implemented when we add proper mock services
        fatalError("Mock container not yet implemented - create mock services first")
    }

    /// A temporary synchronous wrapper for the async initializer.
    /// To be removed when SwiftUI's App protocol supports async initialization.
    static func blocking() -> AppContainer {
        // Can't use LogManager here as it hasn't been created yet.
        print("DEBUG: AppContainer.blocking() called - thread: \(Thread.current) - is main thread: \(Thread.isMainThread)")
        let semaphore = DispatchSemaphore(value: 0)
        var container: AppContainer!
        
        print("DEBUG: AppContainer.blocking() creating Task...")
        Task {
            print("DEBUG: AppContainer.blocking() Task started - thread: \(Thread.current) - is main thread: \(Thread.isMainThread)")
            container = await AppContainer()
            print("DEBUG: AppContainer.blocking() Task finished, container created. Signaling semaphore.")
            semaphore.signal()
        }
        
        print("DEBUG: AppContainer.blocking() waiting for semaphore...")
        semaphore.wait()
        print("DEBUG: AppContainer.blocking() semaphore signaled. Returning container.")
        return container
    }
}
#endif 