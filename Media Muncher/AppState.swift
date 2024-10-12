import SwiftUI

class AppState: ObservableObject {
    @Published var volumes: [Volume] = []
    
    @Published var selectedVolumeID: String?
    
    @Published var defaultSavePath: String {
        didSet {
            UserDefaults.standard.set(defaultSavePath, forKey: "defaultSavePath")
        }
    }

    @Published var isSelectedVolumeAccessible: Bool = false

    @Published var mediaFiles: [MediaFile] = []

    @Published var organizeDateFolders: Bool {
        didSet {
            UserDefaults.standard.set(organizeDateFolders, forKey: "organizeDateFolders")
        }
    }

    @Published var renameDateTimeFiles: Bool {
        didSet {
            UserDefaults.standard.set(renameDateTimeFiles, forKey: "renameDateTimeFiles")
        }
    }

    @Published var verifyImportIntegrity: Bool {
        didSet {
            UserDefaults.standard.set(verifyImportIntegrity, forKey: "verifyImportIntegrity")
        }
    }

    @Published var importProgress: Double = 0
    @Published var importState: ImportState = .idle

    init() {
        self.defaultSavePath = UserDefaults.standard.string(forKey: "defaultSavePath") ?? NSHomeDirectory()
        self.organizeDateFolders = UserDefaults.standard.bool(forKey: "organizeDateFolders")
        self.renameDateTimeFiles = UserDefaults.standard.bool(forKey: "renameDateTimeFiles")
        self.verifyImportIntegrity = UserDefaults.standard.bool(forKey: "verifyImportIntegrity")
    }
}
