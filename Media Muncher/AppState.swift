import SwiftUI

class AppState: ObservableObject {
    @Published var volumes: [Volume] = []
    @Published var selectedVolumeID: String?
    @Published var fileItems: [FileItem] = []
    @Published var errorMessage: String?
    @Published var showingPermissionAlert = false
    @Published var defaultSavePath: String {
        didSet {
            UserDefaults.standard.set(defaultSavePath, forKey: "defaultSavePath")
        }
    }
    @Published var volumePermissions: [String: Bool] = [:]

    init() {
        print("AppState: Initializing")
        self.defaultSavePath = UserDefaults.standard.string(forKey: "defaultSavePath") ?? NSHomeDirectory()
        VolumeLogic.loadVolumes(self)
    }
}
