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
    @Published var selectedVolume: String?
    @Published var volumes: [Volume] = []
    @Published var files: [File] = []
    @Published var state: ProgramState = .idle
    @Published var error: AppError? = nil
    @Published var filesScanned: Int = 0
    @Published var totalBytesToImport: Int64 = 0
    @Published var importedBytes: Int64 = 0
    @Published var importedFileCount: Int = 0
    @Published var importStartTime: Date? = nil
    @Published var isRecalculating: Bool = false
    
    /// Returns seconds elapsed since the current import started. Nil when no import is running.
    var elapsedSeconds: TimeInterval? {
        guard let start = importStartTime, state == .importingFiles else { return nil }
        return Date().timeIntervalSince(start)
    }
    
    /// Estimated seconds remaining based on current throughput (bytes/sec). Nil if not computable yet.
    var remainingSeconds: TimeInterval? {
        guard let elapsed = elapsedSeconds, elapsed > 0, importedBytes > 0 else { return nil }
        let throughput = Double(importedBytes) / elapsed
        guard throughput > 0 else { return nil }
        let remainingBytes = Double(max(0, totalBytesToImport - importedBytes))
        return remainingBytes / throughput
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?

    private let volumeManager: VolumeManager
    private let fileProcessorService: FileProcessorService
    private let settingsStore: SettingsStore
    private let importService: ImportService
    private let recalculationManager: RecalculationManager

    init(
        volumeManager: VolumeManager,
        mediaScanner: FileProcessorService,
        settingsStore: SettingsStore,
        importService: ImportService,
        recalculationManager: RecalculationManager
    ) {
        
        self.volumeManager = volumeManager
        self.fileProcessorService = mediaScanner
        self.settingsStore = settingsStore
        self.importService = importService
        self.recalculationManager = recalculationManager
        
        // Subscribe to volume changes
        volumeManager.$volumes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newVolumes in
                LogManager.debug("Volume changes received", category: "AppState", metadata: ["volumes": "\(newVolumes.map { $0.name })"])
                self?.volumes = newVolumes
                if self?.selectedVolume == nil || !newVolumes.contains(where: { $0.devicePath == self?.selectedVolume }) {
                    self?.ensureVolumeSelection()
                }
            }
            .store(in: &cancellables)
            
        // Subscribe to selection changes
        self.$selectedVolume
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devicePath in
                LogManager.debug("selectedVolume changed", category: "AppState", metadata: ["devicePath": devicePath ?? "nil"])
                self?.startScan(for: devicePath)
            }
            .store(in: &cancellables)

        // Subscribe to destination changes
        settingsStore.$destinationURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newDestination in
                guard let self = self else { return }
                // Now, we tell the RecalculationManager to start the process.
                self.recalculationManager.startRecalculation(
                    for: self.files, // Pass AppState's current files
                    newDestinationURL: newDestination,
                    settings: self.settingsStore // Pass settings
                )
            }
            .store(in: &cancellables)

        // Subscribe to RecalculationManager's files updates
        recalculationManager.$files
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedFiles in
                self?.files = updatedFiles // AppState's files reflect RecalculationManager's files
            }
            .store(in: &cancellables)

        // Subscribe to RecalculationManager's recalculating status
        recalculationManager.$isRecalculating
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRecalculating, on: self)
            .store(in: &cancellables)

        // Subscribe to RecalculationManager's errors
        recalculationManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recalculationError in
                // Explicitly map the recalculation error to our domain-specific error type.
                // This ensures consistency in how recalculation errors are presented to the UI.
                if let error = recalculationError {
                    self?.error = .recalculationFailed(reason: error.localizedDescription)
                } else if self?.error?.isRecalculationError == true { // Clear if it was a recalculation error
                    self?.error = nil
                }
            }
            .store(in: &cancellables)

        // Initial state
        self.volumes = volumeManager.volumes
        LogManager.debug("Initial volumes", category: "AppState", metadata: ["volumes": "\(self.volumes.map { $0.name })"])
        ensureVolumeSelection()
    }
    
    func ensureVolumeSelection() {
        LogManager.debug("ensureVolumeSelection called", category: "AppState")
        let currentSelectionIsValid = volumes.contains { $0.devicePath == selectedVolume }
        
        if !currentSelectionIsValid {
            if let firstVolume = self.volumes.first {
                LogManager.debug("Selecting first volume", category: "AppState", metadata: ["name": firstVolume.name, "devicePath": firstVolume.devicePath])
                self.selectedVolume = firstVolume.devicePath
            } else {
                LogManager.debug("No volumes available to select, clearing selection", category: "AppState")
                self.selectedVolume = nil
            }
        } else if selectedVolume == nil, let firstVolume = volumes.first {
            // This handles the initial launch case where selection is nil but volumes are present.
            self.selectedVolume = firstVolume.devicePath
        }
    }

    private func startScan(for devicePath: String?) {
        LogManager.debug("startScan called", category: "AppState", metadata: ["devicePath": devicePath ?? "nil"])
        
        scanTask?.cancel()
        
        self.files = []
        self.filesScanned = 0
        self.state = .idle
        self.error = nil

        guard let devicePath = devicePath else { 
            LogManager.debug("No device path provided, skipping scan", category: "AppState")
            return 
        }
        
        let url = URL(fileURLWithPath: devicePath, isDirectory: true)
        LogManager.debug("Starting scan for URL", category: "AppState", metadata: ["path": url.path])
        
        self.state = .enumeratingFiles
        
        self.scanTask = Task {
            LogManager.debug("Scan task started", category: "AppState")
            let processedFiles = await fileProcessorService.processFiles(
                from: url,
                destinationURL: settingsStore.destinationURL,
                settings: settingsStore
            )
            LogManager.debug("Scan task completed", category: "AppState", metadata: ["count": "\(processedFiles.count)"])

            await MainActor.run {
                self.files = processedFiles
                self.filesScanned = processedFiles.count
                self.state = .idle
                LogManager.debug("Updated UI", category: "AppState", metadata: ["count": "\(processedFiles.count)"])
            }
        }
    }
    
    func cancelScan() {
        LogManager.debug("cancelScan called", category: "AppState")
        scanTask?.cancel()
        self.state = .idle
    }
    
    func cancelImport() {
        LogManager.debug("cancelImport called", category: "AppState")
        importTask?.cancel()
    }
    
    func importFiles() {
        self.error = nil

        let filesToImport = self.files.filter { $0.status == .waiting }
        guard !filesToImport.isEmpty else { return }

        // Progress should only be calculated based on files that will actually be copied.
        self.totalBytesToImport = filesToImport.reduce(0) { $0 + ($1.size ?? 0) }
        self.importedFileCount = 0
        self.importedBytes = 0

        self.importStartTime = Date()

        self.state = .importingFiles

        importTask = Task {
            defer {
                Task { @MainActor in
                    self.state = .idle
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

                            // Only increment progress for files that were actually copied.
                            if updatedFile.status == .imported {
                                self.importedFileCount += 1
                                self.importedBytes += updatedFile.size ?? 0
                            }
                        }
                    }
                }

                // After the import process is finished...
                if settingsStore.settingAutoEject,
                   let selectedVolumePath = selectedVolume,
                   let volumeToEject = volumes.first(where: { $0.devicePath == selectedVolumePath }) {
                    volumeManager.ejectVolume(volumeToEject)
                }

                // Detect any deletion failures recorded in File.importError
                let deletionFailures = self.files.contains { $0.importError?.contains("Failed to delete original") == true }

                await MainActor.run {
                    self.importStartTime = nil // clear when done
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
    

}
