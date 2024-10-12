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

    init() {
        print("AppState: Initializing")
        self.defaultSavePath = UserDefaults.standard.string(forKey: "defaultSavePath") ?? NSHomeDirectory()
        self.organizeDateFolders = UserDefaults.standard.bool(forKey: "organizeDateFolders")
        self.renameDateTimeFiles = UserDefaults.standard.bool(forKey: "renameDateTimeFiles")
        print("AppState: Default save path initialized to: \(defaultSavePath)")
        print("AppState: Organize into Date Folders initialized to: \(organizeDateFolders)")
        print("AppState: Rename Files with Date and Time initialized to: \(renameDateTimeFiles)")
    }
}
