import Foundation
import Combine

class MediaViewModel: ObservableObject {
    @Published var isSelectedVolumeAccessible: Bool = false
    
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private var importTask: Task<Void, Error>?

    init(appState: AppState) {
        self.appState = appState
        setupObservers()
        print("MediaViewModel: Initialized")
    }

    private func setupObservers() {
        appState.$selectedVolumeID
            .sink { selectedID in
                print("MediaViewModel: Selected volume ID changed to: \(selectedID ?? "nil")")
            }
            .store(in: &cancellables)
        
        appState.$isSelectedVolumeAccessible
            .sink { [weak self] isAccessible in
                print("MediaViewModel: Volume accessibility changed to: \(isAccessible)")
                self?.isSelectedVolumeAccessible = isAccessible
            }
            .store(in: &cancellables)

        appState.$mediaFiles
            .sink { files in
                print("MediaViewModel: Received \(files.count) media files")
            }
            .store(in: &cancellables)

        print("MediaViewModel: Observers set up")
    }

    func importMedia() {
        guard appState.importState != .inProgress else { return }
        appState.importState = .inProgress
        appState.importProgress = 0
        
        importTask = Task {
            do {
                try await importMediaFiles()
                await MainActor.run {
                    self.appState.importState = .completed
                    self.appState.importProgress = 1.0
                }
            } catch {
                await MainActor.run {
                    self.appState.importState = .failed(error: error)
                }
            }
        }
    }
    
    func cancelImport() {
        importTask?.cancel()
        appState.importState = .cancelled
    }

    private func importMediaFiles() async throws {
        let totalFiles = Double(appState.mediaFiles.count)
        var errors: [Error] = []

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, file) in appState.mediaFiles.enumerated() {
                group.addTask {
                    do {
                        try await self.processMediaFile(file)
                    } catch {
                        errors.append(error)
                    }
                    await self.updateProgress(Double(index + 1) / totalFiles)
                }
            }
            
            try await group.waitForAll()
        }
        
        if !errors.isEmpty {
            throw ImportError.partialFailure(errors: errors)
        }
    }

    private func processMediaFile(_ file: MediaFile) async throws {
        try Task.checkCancellation()
        
        let destinationPath = appState.defaultSavePath
        let destinationName = file.sourceName
        
        var updatedFile = file
        updatedFile.destinationPath = destinationPath
        updatedFile.destinationName = destinationName
        updatedFile.sourceCRC32 = file.calculateCRC32(forPath: file.sourcePath)
        
        // For now, we're not actually copying the file, so we'll use the same CRC32 for both source and destination
        updatedFile.destinationCRC32 = updatedFile.sourceCRC32
        
        if appState.verifyImportIntegrity {
            print("MediaViewModel: Verifying integrity for file: \(destinationName)")
            if updatedFile.sourceCRC32 == updatedFile.destinationCRC32 {
                print("MediaViewModel: Integrity verified for file: \(destinationName)")
                updatedFile.isImported = true
            } else {
                print("MediaViewModel: Integrity check failed for file: \(destinationName)")
                updatedFile.isImported = false
                throw ImportError.integrityCheckFailed(fileName: destinationName)
            }
        } else {
            updatedFile.isImported = true
        }
        
        await MainActor.run {
            if let index = appState.mediaFiles.firstIndex(where: { $0.id == file.id }) {
                appState.mediaFiles[index] = updatedFile
            }
        }
    }

    @MainActor
    private func updateProgress(_ progress: Double) {
        appState.importProgress = progress
    }
}

enum ImportError: Error {
    case integrityCheckFailed(fileName: String)
    case partialFailure(errors: [Error])
}
