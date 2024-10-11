import SwiftUI

/// `AppState` is a class that manages the global state of the application.
/// It conforms to `ObservableObject` to allow SwiftUI views to react to changes.
class AppState: ObservableObject {
    /// An array of `Volume` objects representing the available volumes.
    @Published var volumes: [Volume] = [] {
        didSet {
            print("AppState: Volumes updated. Count: \(volumes.count)")
        }
    }
    
    /// The ID of the currently selected volume.
    @Published var selectedVolumeID: String? {
        didSet {
            print("AppState: Selected volume ID changed to: \(selectedVolumeID ?? "nil")")
        }
    }
    
    /// The default save path for imported media.
    /// This property is persisted in `UserDefaults`.
    @Published var defaultSavePath: String {
        didSet {
            print("AppState: Default save path updated to: \(defaultSavePath)")
            UserDefaults.standard.set(defaultSavePath, forKey: "defaultSavePath")
        }
    }

    /// Indicates whether the selected volume is accessible.
    @Published var isSelectedVolumeAccessible: Bool = false {
        didSet {
            print("AppState: Selected volume accessibility changed to: \(isSelectedVolumeAccessible)")
        }
    }

    /// An array of `MediaFile` objects representing the media files in the selected volume.
    @Published var mediaFiles: [MediaFile] = [] {
        didSet {
            print("AppState: Media files updated. Count: \(mediaFiles.count)")
        }
    }

    /// Initializes the `AppState` with default values.
    init() {
        print("AppState: Initializing")
        // Load the default save path from UserDefaults, or use the home directory if not set
        self.defaultSavePath = UserDefaults.standard.string(forKey: "defaultSavePath") ?? NSHomeDirectory()
        print("AppState: Default save path initialized to: \(defaultSavePath)")
    }
}
