import SwiftUI

enum AppOperationState: Equatable {
    case idle
    case enumerating
    case inProgress
    case completed
    case cancelled
    case failed(error: Error)
    
    static func == (lhs: AppOperationState, rhs: AppOperationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.enumerating, .enumerating), (.inProgress, .inProgress), (.completed, .completed), (.cancelled, .cancelled):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

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

    @Published var autoChooseUniqueName: Bool {
        didSet {
            UserDefaults.standard.set(autoChooseUniqueName, forKey: "autoChooseUniqueName")
        }
    }

    @Published var importProgress: Double = 0
    @Published var appOperationState: AppOperationState = .idle

    init() {
        self.defaultSavePath = UserDefaults.standard.string(forKey: "defaultSavePath") ?? NSHomeDirectory()
        self.organizeDateFolders = UserDefaults.standard.bool(forKey: "organizeDateFolders")
        self.renameDateTimeFiles = UserDefaults.standard.bool(forKey: "renameDateTimeFiles")
        self.verifyImportIntegrity = UserDefaults.standard.bool(forKey: "verifyImportIntegrity")
        self.autoChooseUniqueName = UserDefaults.standard.bool(forKey: "autoChooseUniqueName")
        
        // Set default value for autoChooseUniqueName if it hasn't been set before
        if !UserDefaults.standard.contains(key: "autoChooseUniqueName") {
            self.autoChooseUniqueName = true
            UserDefaults.standard.set(true, forKey: "autoChooseUniqueName")
        }
    }
}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
