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
        if let rootDirectory = volume.rootDirectory {
            print("MediaViewModel: Root directory found, flattening directory structure")
            let allFiles = flattenDirectory(rootDirectory)
            print("MediaViewModel: Total files found: \(allFiles.count)")
            mediaFiles = allFiles.filter { isMediaFile($0) }
            print("MediaViewModel: Loaded \(mediaFiles.count) media files")
        } else {
            print("MediaViewModel: No root directory found for volume: \(volume.name)")
            // Instead of clearing files, we'll keep the existing ones
            print("MediaViewModel: Keeping existing files. Current count: \(mediaFiles.count)")
        }
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
    
    /// Flattens the directory structure into a list of media files.
    /// - Parameter directory: The root directory to flatten.
    /// - Returns: An array of MediaFile objects.
    private func flattenDirectory(_ directory: Directory) -> [MediaFile] {
        print("MediaViewModel: Flattening directory: \(directory.name)")
        var mediaFiles: [MediaFile] = []
        
        for item in directory.children {
            if let mediaFile = item as? MediaFile {
                mediaFiles.append(mediaFile)
            } else if let subdirectory = item as? Directory {
                mediaFiles.append(contentsOf: flattenDirectory(subdirectory))
            }
        }
        
        print("MediaViewModel: Found \(mediaFiles.count) files in \(directory.name)")
        return mediaFiles
    }
    
    /// Determines if a file is a media file based on its type.
    /// - Parameter file: The file to check.
    /// - Returns: `true` if the file is a media file, `false` otherwise.
    private func isMediaFile(_ file: MediaFile) -> Bool {
        let isMedia = switch file.mediaType {
        case .processedPicture, .rawPicture, .video, .audio:
            true
        }
        print("MediaViewModel: File \(file.name) is \(isMedia ? "a media file" : "not a media file") (Type: \(file.mediaType))")
        return isMedia
    }
}

/// Errors that can occur during media operations.
enum MediaError: Error {
    case importFailed(String)
}
