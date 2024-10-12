import SwiftUI

class AppState: ObservableObject {
    @Published var volumes: [Volume] = [] {
        didSet {
            print("AppState: Volumes updated. Count: \(volumes.count)")
        }
    }
    
    @Published var selectedVolumeID: String? {
        didSet {
            print("AppState: Selected volume ID changed to: \(selectedVolumeID ?? "nil")")
        }
    }
    
    @Published var defaultSavePath: String {
        didSet {
            print("AppState: Default save path updated to: \(defaultSavePath)")
            UserDefaults.standard.set(defaultSavePath, forKey: "defaultSavePath")
        }
    }

    @Published var isSelectedVolumeAccessible: Bool = false {
        didSet {
            print("AppState: Selected volume accessibility changed to: \(isSelectedVolumeAccessible)")
        }
    }

    @Published var mediaFiles: [MediaFile] = [] {
        didSet {
            print("AppState: Media files updated. Count: \(mediaFiles.count)")
        }
    }

    @Published var organizeDateFolders: Bool {
        didSet {
            print("AppState: Organize into Date Folders setting changed to: \(organizeDateFolders)")
            UserDefaults.standard.set(organizeDateFolders, forKey: "organizeDateFolders")
        }
    }

    @Published var renameDateTimeFiles: Bool {
        didSet {
            print("AppState: Rename Files with Date and Time setting changed to: \(renameDateTimeFiles)")
            UserDefaults.standard.set(renameDateTimeFiles, forKey: "renameDateTimeFiles")
        }
    }

    @Published var verifyImportIntegrity: Bool {
        didSet {
            print("AppState: Verify Import Integrity setting changed to: \(verifyImportIntegrity)")
            UserDefaults.standard.set(verifyImportIntegrity, forKey: "verifyImportIntegrity")
        }
    }

    @Published var importProgress: Double = 0
    @Published var importState: ImportState = .idle

    init() {
        print("AppState: Initializing")
        self.defaultSavePath = UserDefaults.standard.string(forKey: "defaultSavePath") ?? NSHomeDirectory()
        self.organizeDateFolders = UserDefaults.standard.bool(forKey: "organizeDateFolders")
        self.renameDateTimeFiles = UserDefaults.standard.bool(forKey: "renameDateTimeFiles")
        self.verifyImportIntegrity = UserDefaults.standard.bool(forKey: "verifyImportIntegrity")
        print("AppState: Default save path initialized to: \(defaultSavePath)")
        print("AppState: Organize into Date Folders initialized to: \(organizeDateFolders)")
        print("AppState: Rename Files with Date and Time initialized to: \(renameDateTimeFiles)")
        print("AppState: Verify Import Integrity initialized to: \(verifyImportIntegrity)")
    }
}

enum ImportState: Equatable {
    case idle
    case inProgress
    case completed
    case cancelled
    case failed(error: Error)
    
    static func == (lhs: ImportState, rhs: ImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.inProgress, .inProgress), (.completed, .completed), (.cancelled, .cancelled):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}
