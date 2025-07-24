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

    // MARK: - Top-Level State Management

    /// The main application state orchestrator.
    let appState: AppState
    
    // MARK: - Initialization
    
    /// Creates a new container with all services properly initialized and wired together.
    /// Services are created in dependency order to ensure proper initialization.
    init() {
        // This initializer now runs on the Main Actor.
        print("DEBUG: AppContainer.init() starting - thread: \(Thread.current) - is main thread: \(Thread.isMainThread)")
        
        // Core Services (no dependencies)
        self.logManager = LogManager()
        self.thumbnailCache = ThumbnailCache()
        self.settingsStore = SettingsStore(logManager: logManager)
        self.importService = ImportService(logManager: logManager)
        self.volumeManager = VolumeManager(logManager: logManager)
        self.fileStore = FileStore(logManager: logManager)

        // Services with dependencies
        self.fileProcessorService = FileProcessorService(logManager: logManager, thumbnailCache: thumbnailCache)
        self.recalculationManager = RecalculationManager(
            logManager: logManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore
        )

        // Top-level state orchestrator
        self.appState = AppState(
            logManager: logManager,
            volumeManager: volumeManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore,
            importService: importService,
            recalculationManager: recalculationManager,
            fileStore: fileStore
        )
        
        Task.detached { await self.logManager.info("AppContainer initialized successfully", category: "AppContainer") }
        print("DEBUG: AppContainer.init() completed")
    }
} 