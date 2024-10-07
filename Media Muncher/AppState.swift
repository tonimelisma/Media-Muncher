import SwiftUI

/// `AppState` is a class that manages the global state of the application.
/// It conforms to `ObservableObject` to allow SwiftUI views to react to changes.
class AppState: ObservableObject {
    /// An array of `Volume` objects representing the available volumes.
    @Published var volumes: [Volume] = []
    
    /// The ID of the currently selected volume.
    @Published var selectedVolumeID: String?
    
    /// The default save path for imported media.
    /// This property is persisted in `UserDefaults`.
    @Published var defaultSavePath: String {
        didSet {
            UserDefaults.standard.set(defaultSavePath, forKey: "defaultSavePath")
        }
    }

    /// Initializes the `AppState` with default values.
    init() {
        print("AppState: Initializing")
        // Load the default save path from UserDefaults, or use the home directory if not set
        self.defaultSavePath = UserDefaults.standard.string(forKey: "defaultSavePath") ?? NSHomeDirectory()
    }
}
