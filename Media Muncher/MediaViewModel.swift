import Foundation
import Combine

/// `MediaViewModel` manages the media items for the selected volume.
class MediaViewModel: ObservableObject {
    /// The list of file items in the selected volume.
    @Published var fileItems: [FileItem] = []
    
    /// The global app state.
    private var appState: AppState
    
    /// Set of cancellables for managing subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Initializes the MediaViewModel with the given AppState.
    /// - Parameter appState: The global app state.
    init(appState: AppState) {
        self.appState = appState
        setupObservers()
    }

    /// Sets up observers for changes in the selected volume.
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

    /// Loads files for the volume with the given ID.
    /// - Parameter id: The ID of the volume to load files for.
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

    /// Clears the list of file items.
    func clearFiles() {
        print("MediaViewModel: Clearing files")
        fileItems = []
    }

    /// Imports media from the selected volume.
    /// - Throws: `MediaError.importFailed` if the import fails.
    func importMedia() throws {
        print("MediaViewModel: Import media")
        // TODO: Implement actual media import logic
        // This is a placeholder that simulates an error
        throw MediaError.importFailed("Failed to import media")
    }
}

/// Errors that can occur during media operations.
enum MediaError: Error {
    case importFailed(String)
}
