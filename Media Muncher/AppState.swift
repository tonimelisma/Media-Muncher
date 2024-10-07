import SwiftUI

class AppState: ObservableObject {
    @Published var volumes: [Volume] = []
    @Published var selectedVolumeID: String?
    @Published var defaultSavePath: String {
        didSet {
            UserDefaults.standard.set(defaultSavePath, forKey: "defaultSavePath")
        }
    }

    init() {
        print("AppState: Initializing")
        self.defaultSavePath = UserDefaults.standard.string(forKey: "defaultSavePath") ?? NSHomeDirectory()
    }
}
