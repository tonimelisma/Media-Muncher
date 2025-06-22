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
    
    // Published UI State
    @Published private(set) var volumes: [Volume] = []
    @Published var selectedVolume: String? = nil
    @Published private(set) var files: [File] = []
    @Published private(set) var filesScanned: Int = 0
    @Published private(set) var state: ProgramState = .idle
    @Published private(set) var error: AppError? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private var scanTask: Task<Void, Never>?

    init(volumeManager: VolumeManager, mediaScanner: MediaScanner, settingsStore: SettingsStore) {
        self.volumeManager = volumeManager
        self.mediaScanner = mediaScanner
        self.settingsStore = settingsStore
        
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
        if let firstVolume = self.volumes.first {
            self.selectedVolume = firstVolume.devicePath
        } else {
            self.selectedVolume = nil
        }
    }

    private func startScan(for devicePath: String?) {
        scanTask?.cancel()
        
        self.files = []
        self.filesScanned = 0
        self.state = .idle
        self.error = nil

        guard let devicePath = devicePath, let url = URL(string: "file://\(devicePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)") else {
            return
        }
        
        self.state = .enumeratingFiles
        
        self.scanTask = Task {
            let streams = await mediaScanner.enumerateFiles(at: url)
            
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
                do {
                    for try await count in streams.progress {
                        await MainActor.run {
                            self.filesScanned = count
                        }
                    }
                } catch {
                    // Progress stream failed
                }
            }
        }
    }
    
    func cancelScan() {
        scanTask?.cancel()
        self.state = .idle
    }
    
    func importFiles() async {
        print("Importing files")
        let fileManager = FileManager.default
        let destination = settingsStore.settingDestinationFolder
        
        if !fileManager.isWritableFile(atPath: destination) {
            self.error = .destinationNotWritable(path: destination)
            return
        } else {
            self.error = nil
        }

        print("Total source files: \(files.count)")
        
        // ... import logic stub ...
        
        print("Import done")
    }
}
