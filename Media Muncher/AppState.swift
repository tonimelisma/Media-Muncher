import Foundation
import SwiftUI
import Combine
import QuickLookThumbnailing
//
//  AppState.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/15/25.
//

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
    @Published var files: [File] = []
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

    init(
        logManager: Logging,
        volumeManager: VolumeManager,
        fileProcessorService: FileProcessorService,
        settingsStore: SettingsStore,
        importService: ImportService,
        recalculationManager: RecalculationManager
    ) {
        
        self.logManager = logManager
        self.volumeManager = volumeManager
        self.fileProcessorService = fileProcessorService
        self.settingsStore = settingsStore
        self.importService = importService
        self.recalculationManager = recalculationManager
        
        // Example of using the injected logger
        self.logManager.info("AppState initialized")
        
        // Subscribe to volume changes
        volumeManager.$volumes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newVolumes in
                self?.logManager.debug("Volume changes received", category: "AppState", metadata: ["volumes": "\(newVolumes.map { $0.name })"])
                self?.volumes = newVolumes
                self?.ensureVolumeSelection()
            }
            .store(in: &cancellables)
            
        // Subscribe to selection changes
        self.$selectedVolumeID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] volumeID in
                self?.logManager.debug("selectedVolumeID changed", category: "AppState", metadata: ["volumeID": volumeID ?? "nil"])
                self?.startScan(for: volumeID)
            }
            .store(in: &cancellables)

        // Subscribe to destination changes and setup recalculation chain
        setupDestinationChangeHandling()
        setupRecalculationManagerBindings()

        // Initial state
        self.volumes = volumeManager.volumes
        self.logManager.debug("Initial volumes", category: "AppState", metadata: ["volumes": "\(self.volumes.map { $0.name })"])
        ensureVolumeSelection()
    }
    
    func ensureVolumeSelection() {
        logManager.debug("ensureVolumeSelection called", category: "AppState")
        // Check if the currently selected ID corresponds to a connected volume.
        let currentSelectionIsValid = volumes.contains { $0.id == selectedVolumeID }

        if !currentSelectionIsValid {
            // If selection is invalid (or nil), select the first available volume.
            if let firstVolume = self.volumes.first {
                logManager.debug("Selecting first volume", category: "AppState", metadata: ["name": firstVolume.name, "id": firstVolume.id])
                self.selectedVolumeID = firstVolume.id
            } else {
                // If no volumes are available, clear the selection.
                logManager.debug("No volumes available to select, clearing selection", category: "AppState")
                self.selectedVolumeID = nil
            }
        } else if selectedVolumeID == nil, let firstVolume = volumes.first {
            // This handles the initial launch case where selection is nil but volumes are present.
            self.selectedVolumeID = firstVolume.id
        }
    }

    private func startScan(for volumeID: Volume.ID?) {
        logManager.debug("startScan called", category: "AppState", metadata: ["volumeID": volumeID ?? "nil"])
        
        scanTask?.cancel()
        
        self.files = []
        self.filesScanned = 0
        self.state = .idle
        self.error = nil

        // Find the volume by its ID to get the path for the URL.
        guard let volumeID = volumeID,
              let volume = volumes.first(where: { $0.id == volumeID }) else {
            logManager.debug("No volume ID provided or volume not found, skipping scan", category: "AppState")
            return
        }
        
        let url = URL(fileURLWithPath: volume.devicePath, isDirectory: true)
        logManager.debug("Starting scan for URL", category: "AppState", metadata: ["path": url.path])
        
        self.state = .enumeratingFiles
        
        self.scanTask = Task {
            self.logManager.debug("Scan task started", category: "AppState")
            let processedFiles = await fileProcessorService.processFiles(
                from: url,
                destinationURL: settingsStore.destinationURL,
                settings: settingsStore
            )
            self.logManager.debug("Scan task completed", category: "AppState", metadata: ["count": "\(processedFiles.count)"])

            await MainActor.run {
                self.files = processedFiles
                self.filesScanned = processedFiles.count
                self.state = .idle
                self.logManager.debug("Updated UI", category: "AppState", metadata: ["count": "\(processedFiles.count)"])
            }
        }
    }
    
    func cancelScan() {
        self.logManager.debug("cancelScan called", category: "AppState")
        scanTask?.cancel()
        self.state = .idle
    }
    
    func cancelImport() {
        self.logManager.debug("cancelImport called", category: "AppState")
        importTask?.cancel()
    }
    
    func importFiles() {
        self.error = nil

        let filesToImport = self.files.filter { $0.status == .waiting }
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
                let stream = await importService.importFiles(files: self.files, to: destinationURL, settings: self.settingsStore)
                for try await updatedFile in stream {
                    await MainActor.run {
                        if let index = self.files.firstIndex(where: { $0.id == updatedFile.id }) {
                            self.files[index] = updatedFile
                            // Delegate progress update
                            self.importProgress.update(with: updatedFile)
                        }
                    }
                }

                // After the import process is finished...
                if settingsStore.settingAutoEject,
                   let selectedVolumeID = selectedVolumeID,
                   let volumeToEject = volumes.first(where: { $0.id == selectedVolumeID }) {
                    volumeManager.ejectVolume(volumeToEject)
                }

                // Detect any deletion failures recorded in File.importError
                let deletionFailures = self.files.contains { $0.importError?.contains("Failed to delete original") == true }

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
                    for: self.files,
                    newDestinationURL: newDestination,
                    settings: self.settingsStore
                )
            }
            .store(in: &cancellables)
    }
    
    /// Configures reactive bindings between RecalculationManager and AppState UI properties.
    private func setupRecalculationManagerBindings() {
        // Sync files from RecalculationManager
        recalculationManager.$files
            .receive(on: DispatchQueue.main)
            .assign(to: \.files, on: self)
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
