import AVFoundation
import SwiftUI
import Combine
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

enum errorState {
    case none
    case destinationFolderNotWritable
}

// MARK: - Scan Progress & Cancellation Support

/// Convenience alias for the async task that enumerates files. Storing this
/// allows us to cancel an ongoing scan when the user presses *Stop* or when
/// the selected volume changes.
private typealias ScanTask = Task<Void, Never>

class AppState: ObservableObject {
    // Services
    private let volumeManager: VolumeManager
    private let mediaScanner: MediaScanner
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
    
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?

    init(
        volumeManager: VolumeManager,
        mediaScanner: MediaScanner,
        settingsStore: SettingsStore,
        importService: ImportService
    ) {
        self.volumeManager = volumeManager
        self.mediaScanner = mediaScanner
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
            let streams = await mediaScanner.enumerateFiles(
                at: url,
                destinationURL: settingsStore.destinationURL,
                filterImages: settingsStore.filterImages,
                filterVideos: settingsStore.filterVideos,
                filterAudio: settingsStore.filterAudio,
                organizeByDate: settingsStore.organizeByDate,
                renameByDate: settingsStore.renameByDate
            )
            
            // Handle results
            Task {
                do {
                    for try await batch in streams.results {
                        await MainActor.run {
                            self.files.append(contentsOf: batch)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.error = .scanFailed(reason: error.localizedDescription)
                    }
                }
                await MainActor.run {
                    self.state = .idle
                }
            }
            
            // Handle progress
            Task {
                for try await count in streams.progress {
                    await MainActor.run {
                        self.filesScanned = count
                    }
                }
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

        self.state = .importingFiles

        importTask = Task {
            defer {
                Task { @MainActor in
                    self.state = .idle
                    self.totalFilesToImport = 0
                    self.importedFileCount = 0
                    self.totalBytesToImport = 0
                    self.importedBytes = 0
                }
            }
            
            guard let destinationURL = settingsStore.destinationURL else {
                await MainActor.run {
                    self.error = .destinationNotSet
                }
                return
            }
            
            guard let selectedVolumePath = selectedVolume,
                  let volumeToEject = volumes.first(where: { $0.devicePath == selectedVolumePath }) else {
                // This case is unlikely if files are present, but as a safeguard:
                await MainActor.run {
                    self.error = .importFailed(reason: "No volume selected or found.")
                }
                return
            }
            
            do {
                try await importService.importFiles(files: filesToImport, to: destinationURL, settings: self.settingsStore) { filesProcessed, bytesProcessed in
                    await MainActor.run {
                        self.importedFileCount = filesProcessed
                        self.importedBytes = bytesProcessed
                    }
                }
                
                if settingsStore.settingAutoEject {
                    volumeManager.ejectVolume(volumeToEject)
                }

            } catch is CancellationError {
                // User cancelled the import, do nothing, just let the state reset to idle.
            } catch let importError as ImportService.ImportError {
                await MainActor.run {
                    switch importError {
                    case .deleteFailed(_, let error):
                        self.error = .importSucceededWithDeletionErrors(reason: error.localizedDescription)
                    case .copyFailed(let src, _, let error):
                        self.error = .copyFailed(source: src.lastPathComponent, reason: error.localizedDescription)
                    case .directoryCreationError(let path, let error):
                        self.error = .directoryCreationFailed(path: path.path, reason: error.localizedDescription)
                    default:
                        self.error = .importFailed(reason: importError.localizedDescription)
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = .importFailed(reason: error.localizedDescription)
                }
            }
        }
    }
}
