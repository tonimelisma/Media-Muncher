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
@MainActor
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
    init() {
        // Initialize core services first (no dependencies)
        self.logManager = LogManager()
        self.volumeManager = VolumeManager(logManager: logManager)
        self.thumbnailCache = ThumbnailCache()
        self.fileProcessorService = FileProcessorService(logManager: logManager, thumbnailCache: thumbnailCache)
        self.settingsStore = SettingsStore(logManager: logManager)
        self.importService = ImportService(logManager: logManager)
        self.fileStore = FileStore(logManager: logManager)
        
        // Initialize services with dependencies last
        self.recalculationManager = RecalculationManager(
            logManager: logManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore
        )
        
        logManager.info("AppContainer initialized", category: "AppContainer", metadata: [
            "services": "7 services instantiated"
        ])
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
}
#endif 