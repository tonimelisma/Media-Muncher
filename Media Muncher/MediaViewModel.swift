import Foundation
import Combine

class MediaViewModel: ObservableObject {
    @Published var isSelectedVolumeAccessible: Bool = false
    
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private var importTask: Task<Void, Error>?
    private let mediaImporter: MediaImporter

    init(appState: AppState) {
        print("MediaViewModel: Initializing")
        self.appState = appState
        self.mediaImporter = MediaImporter(appState: appState)
        setupObservers()
    }

    private func setupObservers() {
        print("MediaViewModel: Setting up observers")
        appState.$selectedVolumeID
            .sink { [weak self] selectedID in
                self?.onSelectedVolumeIDChanged(selectedID)
            }
            .store(in: &cancellables)
        
        appState.$isSelectedVolumeAccessible
            .sink { [weak self] isAccessible in
                self?.onVolumeAccessibilityChanged(isAccessible)
            }
            .store(in: &cancellables)

        appState.$mediaFiles
            .sink { [weak self] files in
                self?.onMediaFilesChanged(files)
            }
            .store(in: &cancellables)
    }

    func importMedia() {
        print("MediaViewModel: importMedia called")
        guard appState.appOperationState != .inProgress else {
            print("MediaViewModel: Import already in progress, skipping")
            return
        }
        appState.appOperationState = .inProgress
        appState.importProgress = 0
        
        print("MediaViewModel: Starting import task")
        importTask = Task {
            do {
                print("MediaViewModel: Calling mediaImporter.importMediaFiles()")
                try await mediaImporter.importMediaFiles()
                await MainActor.run {
                    print("MediaViewModel: Import completed successfully")
                    self.appState.appOperationState = .completed
                    self.appState.importProgress = 1.0
                }
            } catch {
                await MainActor.run {
                    print("MediaViewModel: Import failed with error: \(error)")
                    self.appState.appOperationState = .failed(error: error)
                }
            }
        }
    }
    
    func cancelImport() {
        print("MediaViewModel: Cancelling import")
        importTask?.cancel()
        appState.appOperationState = .cancelled
    }

    private func onSelectedVolumeIDChanged(_ selectedID: String?) {
        print("MediaViewModel: Selected volume ID changed to: \(selectedID ?? "nil")")
    }

    private func onVolumeAccessibilityChanged(_ isAccessible: Bool) {
        print("MediaViewModel: Volume accessibility changed to: \(isAccessible)")
        isSelectedVolumeAccessible = isAccessible
    }

    private func onMediaFilesChanged(_ files: [MediaFile]) {
        print("MediaViewModel: Received \(files.count) media files")
    }
}
