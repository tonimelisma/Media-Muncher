import Foundation
import Combine

/// `MediaViewModel` manages the media items for the selected volume.
class MediaViewModel: ObservableObject {
    /// Indicates whether the selected volume is accessible.
    @Published var isSelectedVolumeAccessible: Bool = false
    
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

    /// Sets up observers for changes in the selected volume and media files.
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
