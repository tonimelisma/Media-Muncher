import Foundation
import Combine

class MediaViewModel: ObservableObject {
    @Published var fileItems: [FileItem] = []
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        setupObservers()
    }

    private func setupObservers() {
        appState.$selectedVolumeID
            .sink { [weak self] selectedID in
                if let id = selectedID {
                    self?.loadFilesForVolume(withID: id)
                } else {
                    self?.clearFiles()
                }
            }
            .store(in: &cancellables)
    }

    func loadFilesForVolume(withID id: String) {
        guard let volume = appState.volumes.first(where: { $0.id == id }) else {
            print("MediaViewModel: No volume found with ID: \(id) for loading files")
            clearFiles()
            return
        }
        
        print("MediaViewModel: Loading files for volume: \(volume.name)")
        fileItems = FileEnumerator.enumerateFiles(for: volume.devicePath)
        print("MediaViewModel: Loaded \(fileItems.count) files")
    }

    func clearFiles() {
        print("MediaViewModel: Clearing files")
        fileItems = []
    }

    func importMedia() throws {
        print("MediaViewModel: Import media")
        // Simulating an error for demonstration
        throw MediaError.importFailed("Failed to import media")
    }
}

enum MediaError: Error {
    case importFailed(String)
}
