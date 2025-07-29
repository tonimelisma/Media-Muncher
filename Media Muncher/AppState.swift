//
//  AppState.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import QuickLookThumbnailing

enum ProgramState {
    case idle
    case enumeratingFiles
    case importingFiles
}

// MARK: - Scan Progress & Cancellation Support

/// Convenience alias for the async task that enumerates files. Storing this
/// allows us to cancel an ongoing scan when the user presses *Stop* or when
/// the selected volume changes.
private typealias ScanTask = Task<Void, Never>

@MainActor
class AppState: ObservableObject {
    @Published var selectedVolumeID: Volume.ID?
    @Published var volumes: [Volume] = []
    @Published var state: ProgramState = .idle
    @Published var error: AppError? = nil
    @Published var filesScanned: Int = 0
    @Published private(set) var importProgress = ImportProgress()
    @Published var isRecalculating: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?

    private let volumeManager: VolumeManager
    private let fileProcessorService: FileProcessorService
    private let settingsStore: SettingsStore
    private let importService: ImportService
    private let recalculationManager: RecalculationManager
    private let logManager: Logging
    private let fileStore: FileStore

    init(
        logManager: Logging,
        volumeManager: VolumeManager,
        fileProcessorService: FileProcessorService,
        settingsStore: SettingsStore,
        importService: ImportService,
        recalculationManager: RecalculationManager,
        fileStore: FileStore
    ) {
        self.logManager = logManager
        self.volumeManager = volumeManager
        self.fileProcessorService = fileProcessorService
        self.settingsStore = settingsStore
        self.importService = importService
        self.recalculationManager = recalculationManager
        self.fileStore = fileStore
        
        Task {
            await self.logManager.info("AppState.init() started", category: "AppState")
        }
        
        // Subscribe to volume changes
        Task {
            await self.logManager.debug("Subscribing to volumeManager.$volumes", category: "AppState")
        }
        volumeManager.$volumes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newVolumes in
                Task { [weak self] in
                    await self?.logManager.debug("Received volume changes from publisher", category: "AppState", metadata: ["count": "\(newVolumes.count)"])
                    self?.volumes = newVolumes
                    self?.ensureVolumeSelection()
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to selection changes
        Task {
            await self.logManager.debug("Subscribing to self.$selectedVolumeID", category: "AppState")
        }
        self.$selectedVolumeID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volumeID in
                Task { [weak self] in
                    await self?.logManager.debug("Received selectedVolumeID change from publisher", category: "AppState", metadata: ["volumeID": volumeID ?? "nil"])
                    self?.startScan(for: volumeID)
                }
            }
            .store(in: &cancellables)

        // Subscribe to destination changes and setup recalculation chain
        Task {
            await self.logManager.debug("Setting up destination change handling", category: "AppState")
        }
        setupDestinationChangeHandling()
        setupRecalculationManagerBindings()

        // Initial state
        Task {
            await self.logManager.debug("Setting initial volumes from volumeManager", category: "AppState")
        }
        self.volumes = volumeManager.volumes
        Task {
            await self.logManager.debug("Initial volumes set", category: "AppState", metadata: ["count": "\(self.volumes.count)"])
            await self.logManager.info("AppState initialized successfully", category: "AppState")
        }
        ensureVolumeSelection()
    }
    
    func ensureVolumeSelection() {
        Task {
            await logManager.debug("ensureVolumeSelection called", category: "AppState")
        }
        // Check if the currently selected ID corresponds to a connected volume.
        let currentSelectionIsValid = volumes.contains { $0.id == selectedVolumeID }

        if !currentSelectionIsValid {
            // If selection is invalid (or nil), select the first available volume.
            if let firstVolume = self.volumes.first {
                Task {
                    await logManager.debug("Selecting first volume", category: "AppState", metadata: ["name": firstVolume.name, "id": firstVolume.id])
                }
                self.selectedVolumeID = firstVolume.id
            } else {
                // If no volumes are available, clear the selection.
                Task {
                    await logManager.debug("No volumes available to select, clearing selection", category: "AppState")
                }
                self.selectedVolumeID = nil
            }
        } else if selectedVolumeID == nil, let firstVolume = volumes.first {
            // This handles the initial launch case where selection is nil but volumes are present.
            self.selectedVolumeID = firstVolume.id
        }
    }

    private func startScan(for volumeID: Volume.ID?) {
        Task {
            await logManager.debug("startScan called", category: "AppState", metadata: ["volumeID": volumeID ?? "nil"])
        }
        
        scanTask?.cancel()
        
        self.state = .idle
        self.error = nil

        // Find the volume by its ID to get the path for the URL.
        guard let volumeID = volumeID,
              let volume = volumes.first(where: { $0.id == volumeID }) else {
            Task {
                await logManager.debug("No volume ID provided or volume not found, skipping scan", category: "AppState")
            }
            return
        }
        
        let url = URL(fileURLWithPath: volume.devicePath, isDirectory: true)
        Task {
            await logManager.debug("Starting scan for URL", category: "AppState", metadata: ["path": url.path])
        }
        
        self.state = .enumeratingFiles
        
        self.scanTask = Task {
            await self.logManager.debug("Scan task started", category: "AppState")
            
            fileStore.clearFiles()
            self.filesScanned = 0
            
            let stream = await fileProcessorService.processFilesStream(
                from: url,
                destinationURL: settingsStore.destinationURL,
                settings: settingsStore,
                batchSize: 50
            )
            
            // Define batching strategy
            var buffer: [File] = []
            let fileUpdateBatchSize = 50
            
            // Implement the core logic with batching
            for await fileBatch in stream {
                // Add the newly found files to our temporary buffer
                buffer.append(contentsOf: fileBatch)
                
                // Check if the buffer is full enough to trigger a UI update
                if buffer.count >= fileUpdateBatchSize {
                    // IMPORTANT: This must be on the main thread!
                    await MainActor.run {
                        self.fileStore.appendFiles(buffer)
                        self.filesScanned = self.fileStore.files.count
                    }
                    // Clear the buffer so we can start filling it again
                    buffer.removeAll()
                }
            }
            
            // Handle the leftovers - after the loop, handle any remaining files
            if !buffer.isEmpty {
                await MainActor.run {
                    self.fileStore.appendFiles(buffer)
                    self.filesScanned = self.fileStore.files.count
                }
            }
            
            await self.logManager.debug("Scan task completed", category: "AppState", metadata: ["totalCount": "\(self.fileStore.files.count)"])

            await MainActor.run {
                self.state = .idle
                Task {
                    await self.logManager.debug("Updated UI to idle state", category: "AppState", metadata: ["finalCount": "\(self.fileStore.files.count)"])
                }
            }
        }
    }
    
    func cancelScan() {
        Task {
            await self.logManager.debug("cancelScan called", category: "AppState")
        }
        scanTask?.cancel()
        self.state = .idle
    }
    
    func cancelImport() {
        Task {
            await self.logManager.debug("cancelImport called", category: "AppState")
        }
        importTask?.cancel()
    }
    
    func importFiles() {
        self.error = nil

        let filesToImport = fileStore.filesToImport
        guard !filesToImport.isEmpty else { return }

        // Reset and start progress tracking
        self.importProgress.start(with: filesToImport)
        self.state = .importingFiles

        importTask = Task {
            // This defer block will run regardless of how the task exits (success, error, cancellation).
            // It ensures the program state always returns to idle and progress tracking is reset.
            defer {
                Task { @MainActor in
                    self.state = .idle
                    self.importProgress.finish()
                }
            }

            guard let destinationURL = settingsStore.destinationURL else {
                await MainActor.run {
                    self.error = .destinationNotSet
                }
                return
            }

            do {
                let stream = await importService.importFiles(files: fileStore.files, to: destinationURL, settings: self.settingsStore)
                for try await updatedFile in stream {
                    await MainActor.run {
                        self.fileStore.updateFile(updatedFile)
                        // Delegate progress update
                        self.importProgress.update(with: updatedFile)
                    }
                }

                // After the import process is finished...
                if settingsStore.settingAutoEject,
                   let selectedVolumeID = selectedVolumeID,
                   let volumeToEject = volumes.first(where: { $0.id == selectedVolumeID }) {
                    volumeManager.ejectVolume(volumeToEject)
                }

                // Detect any deletion failures recorded in File.importError
                let deletionFailures = fileStore.files.contains { $0.importError?.contains("Failed to delete original") == true }

                await MainActor.run {
                    if deletionFailures {
                        self.error = .importSucceededWithDeletionErrors(reason: "One or more originals could not be deleted (read-only drive)")
                    }
                }

            } catch is CancellationError {
                // User cancelled the import, do nothing, just let the state reset to idle.
            } catch {
                await MainActor.run {
                    self.error = .importFailed(reason: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Publisher Chain Setup
    
    /// Configures subscription to destination URL changes to trigger recalculation.
    private func setupDestinationChangeHandling() {
        settingsStore.$destinationURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newDestination in
                guard let self = self else { return }
                self.recalculationManager.startRecalculation(
                    for: self.fileStore.files,
                    newDestinationURL: newDestination,
                    settings: self.settingsStore
                )
            }
            .store(in: &cancellables)
    }
    
    /// Configures reactive bindings between RecalculationManager and AppState UI properties.
    private func setupRecalculationManagerBindings() {
        // Sync files from RecalculationManager to FileStore
        recalculationManager.$files
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedFiles in
                self?.fileStore.setFiles(updatedFiles)
            }
            .store(in: &cancellables)
        
        // Sync recalculation status
        recalculationManager.$isRecalculating
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRecalculating, on: self)
            .store(in: &cancellables)
        
        // Map recalculation errors to AppState error handling
        recalculationManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recalculationError in
                self?.handleRecalculationError(recalculationError)
            }
            .store(in: &cancellables)
    }
    
    /// Handles recalculation errors with proper domain error mapping.
    private func handleRecalculationError(_ recalculationError: AppError?) {
        if let error = recalculationError {
            self.error = .recalculationFailed(reason: error.localizedDescription)
        } else if self.error?.isRecalculationError == true {
            self.error = nil // Clear only recalculation errors
        }
    }

}
