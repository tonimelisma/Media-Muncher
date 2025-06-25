import AVFoundation
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

class AppState: ObservableObject {
    // Services
    private let volumeManager: VolumeManager
    private let fileProcessorService: FileProcessorService
    private let settingsStore: SettingsStore
    private let importService: ImportService
    
    // Published UI State
    @Published private(set) var volumes: [Volume] = []
    @Published var selectedVolume: String? = nil
    @Published private(set) var files: [File] = []
    @Published private(set) var filesScanned: Int = 0
    @Published private(set) var state: ProgramState = .idle
    @Published private(set) var error: AppError? = nil
    
    // Import Progress
    @Published var totalFilesToImport: Int = 0
    @Published var importedFileCount: Int = 0
    @Published var totalBytesToImport: Int64 = 0
    @Published var importedBytes: Int64 = 0
    
    // Timing
    @Published private(set) var importStartTime: Date? = nil
    
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

    init(
        volumeManager: VolumeManager,
        mediaScanner: FileProcessorService,
        settingsStore: SettingsStore,
        importService: ImportService
    ) {
        self.volumeManager = volumeManager
        self.fileProcessorService = mediaScanner
        self.settingsStore = settingsStore
        self.importService = importService
        
        // Subscribe to volume changes
        volumeManager.$volumes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newVolumes in
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
                self?.startScan(for: devicePath)
            }
            .store(in: &cancellables)

        // Initial state
        self.volumes = volumeManager.volumes
        ensureVolumeSelection()
    }
    
    func ensureVolumeSelection() {
        if selectedVolume == nil {
            // Standard behavior: select the first volume if none is selected
            if let firstVolume = self.volumes.first {
                self.selectedVolume = firstVolume.devicePath
            } else {
                self.selectedVolume = nil
            }
        }
    }

    private func startScan(for devicePath: String?) {
        scanTask?.cancel()
        
        self.files = []
        self.filesScanned = 0
        self.state = .idle
        self.error = nil

        guard let devicePath = devicePath else { return }
        let url = URL(fileURLWithPath: devicePath, isDirectory: true)
        
        self.state = .enumeratingFiles
        
        self.scanTask = Task {
            let initialFiles = await fileProcessorService.fastEnumerate(
                at: url,
                filterImages: settingsStore.filterImages,
                filterVideos: settingsStore.filterVideos,
                filterAudio: settingsStore.filterAudio
            )

            await MainActor.run {
                self.files = initialFiles
                self.filesScanned = initialFiles.count
            }

            // Now, process each file for enrichment and collision resolution
            for i in 0..<initialFiles.count {
                if Task.isCancelled { break }
                
                let processedFile = await fileProcessorService.processFile(
                    initialFiles[i],
                    allFiles: self.files,
                    destinationURL: settingsStore.destinationURL,
                    settings: settingsStore
                )
                
                await MainActor.run {
                    // It's crucial to update the single source of truth
                    if let index = self.files.firstIndex(where: { $0.id == processedFile.id }) {
                        self.files[index] = processedFile
                    }
                }
            }
            
            await MainActor.run {
                self.state = .idle
            }
        }
    }
    
    func cancelScan() {
        scanTask?.cancel()
        self.state = .idle
    }
    
    func cancelImport() {
        importTask?.cancel()
    }
    
    func importFiles() {
        self.error = nil
        
        let filesToImport = self.files.filter { $0.status != .pre_existing }
        
        guard !filesToImport.isEmpty else { return }
        
        // Reset progress and set totals
        self.importedFileCount = 0
        self.importedBytes = 0
        self.totalFilesToImport = filesToImport.count
        self.totalBytesToImport = filesToImport.reduce(0) { $0 + ($1.size ?? 0) }

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
                let stream = await importService.importFiles(files: filesToImport, to: destinationURL, settings: self.settingsStore)
                for try await updatedFile in stream {
                    await MainActor.run {
                        if let index = self.files.firstIndex(where: { $0.id == updatedFile.id }) {
                            self.files[index] = updatedFile
                            
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

                await MainActor.run {
                    self.importStartTime = nil // clear when done
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
