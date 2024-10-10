import Foundation
import Combine

/// `MediaViewModel` manages the media items for the selected volume.
class MediaViewModel: ObservableObject {
    /// The list of media files in the selected volume.
    @Published var mediaFiles: [MediaFile] = []
    
    /// The global app state.
    private var appState: AppState
    
    /// Set of cancellables for managing subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Initializes the MediaViewModel with the given AppState.
    /// - Parameter appState: The global app state.
    init(appState: AppState) {
        self.appState = appState
        setupObservers()
        print("MediaViewModel: Initialized")
    }

    /// Sets up observers for changes in the selected volume.
    private func setupObservers() {
        appState.$selectedVolumeID
            .sink { [weak self] selectedID in
                print("MediaViewModel: Selected volume ID changed to: \(selectedID ?? "nil")")
                if let id = selectedID {
                    self?.loadFilesForVolume(withID: id)
                } else {
                    self?.clearFiles()
                }
            }
            .store(in: &cancellables)
        print("MediaViewModel: Observers set up")
    }

    /// Loads files for the volume with the given ID.
    /// - Parameter id: The ID of the volume to load files for.
    func loadFilesForVolume(withID id: String) {
        print("MediaViewModel: Loading files for volume with ID: \(id)")
        guard let volume = appState.volumes.first(where: { $0.id == id }) else {
            print("MediaViewModel: No volume found with ID: \(id) for loading files")
            return
        }
        
        print("MediaViewModel: Loading files for volume: \(volume.name)")
        mediaFiles = volume.mediaFiles
        print("MediaViewModel: Loaded \(mediaFiles.count) media files")
    }

    /// Clears the list of media files.
    func clearFiles() {
        print("MediaViewModel: Clearing files")
        mediaFiles = []
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
