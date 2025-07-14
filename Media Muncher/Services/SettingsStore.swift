import Foundation
import SwiftUI

class SettingsStore: ObservableObject {
    @Published var settingDeleteOriginals: Bool {
        didSet {
            print("[SettingsStore] DEBUG: settingDeleteOriginals changed to: \(settingDeleteOriginals)")
            UserDefaults.standard.set(settingDeleteOriginals, forKey: "settingDeleteOriginals")
        }
    }

    @Published var organizeByDate: Bool {
        didSet {
            print("[SettingsStore] DEBUG: organizeByDate changed to: \(organizeByDate)")
            UserDefaults.standard.set(organizeByDate, forKey: "organizeByDate")
        }
    }
    
    @Published var renameByDate: Bool {
        didSet {
            print("[SettingsStore] DEBUG: renameByDate changed to: \(renameByDate)")
            UserDefaults.standard.set(renameByDate, forKey: "renameByDate")
        }
    }

    @Published var filterImages: Bool {
        didSet {
            print("[SettingsStore] DEBUG: filterImages changed to: \(filterImages)")
            UserDefaults.standard.set(filterImages, forKey: "filterImages")
        }
    }

    @Published var filterVideos: Bool {
        didSet {
            print("[SettingsStore] DEBUG: filterVideos changed to: \(filterVideos)")
            UserDefaults.standard.set(filterVideos, forKey: "filterVideos")
        }
    }

    @Published var filterAudio: Bool {
        didSet {
            print("[SettingsStore] DEBUG: filterAudio changed to: \(filterAudio)")
            UserDefaults.standard.set(filterAudio, forKey: "filterAudio")
        }
    }

    @Published var settingAutoEject: Bool {
        didSet {
            print("[SettingsStore] DEBUG: settingAutoEject changed to: \(settingAutoEject)")
            UserDefaults.standard.set(settingAutoEject, forKey: "settingAutoEject")
        }
    }

    
    @Published private(set) var destinationURL: URL? {
        didSet {
            print("[SettingsStore] DEBUG: destinationURL changed to: \(destinationURL?.path ?? "nil")")
        }
    }


    init() {
        print("[SettingsStore] DEBUG: Initializing SettingsStore")
        
        self.settingDeleteOriginals = UserDefaults.standard.bool(forKey: "settingDeleteOriginals")
        self.organizeByDate = UserDefaults.standard.bool(forKey: "organizeByDate")
        self.renameByDate = UserDefaults.standard.bool(forKey: "renameByDate")
        self.settingAutoEject = UserDefaults.standard.bool(forKey: "settingAutoEject")
        
        // Automation feature removed – auto-launch toggle deprecated.

        // Default to true if no value is set
        self.filterImages = UserDefaults.standard.object(forKey: "filterImages") as? Bool ?? true
        self.filterVideos = UserDefaults.standard.object(forKey: "filterVideos") as? Bool ?? true
        self.filterAudio = UserDefaults.standard.object(forKey: "filterAudio") as? Bool ?? true

        // Remove obsolete automation keys (version <0.3)
        UserDefaults.standard.removeObject(forKey: "autoLaunchEnabled")
        UserDefaults.standard.removeObject(forKey: "volumeAutomationSettings")
        UserDefaults.standard.removeObject(forKey: "destinationBookmarkData")
        UserDefaults.standard.removeObject(forKey: "lastCustomBookmarkData")

        self.destinationURL = nil
        print("[SettingsStore] DEBUG: Initial destinationURL set to nil.")

        // If no bookmark is stored, default to the Pictures directory.
        if destinationURL == nil {
            setDefaults()
        }
    }

    private func setDefaults() {
        print("[SettingsStore] DEBUG: Setting default values")
        
        // Set default destination to user's Pictures folder (not sandboxed)
        let userPicturesURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        print("[SettingsStore] DEBUG: Default destination set to: \(userPicturesURL.path)")
        
        if FileManager.default.fileExists(atPath: userPicturesURL.path) {
            print("[SettingsStore] DEBUG: User Pictures folder exists, setting as destination")
            setDestination(userPicturesURL)
        } else {
            print("[SettingsStore] DEBUG: User Pictures folder doesn't exist, trying Documents")
            let userDocumentsURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            if FileManager.default.fileExists(atPath: userDocumentsURL.path) {
                setDestination(userDocumentsURL)
            } else {
                print("[SettingsStore] DEBUG: Neither Pictures nor Documents exist, leaving destination as nil")
            }
        }
    }

    // MARK: - Preset Folder Helpers
    private static let presetFolderNames: [String] = [
        "Pictures", "Movies", "Music", "Desktop", "Documents", "Downloads"
    ]

    private func isPresetFolder(_ url: URL) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return SettingsStore.presetFolderNames.contains {
            url.standardizedFileURL == home.appendingPathComponent($0).standardizedFileURL
        }
    }
 
    /// Attempts to set the given URL as the destination folder.
    /// - Returns: `true` if the app has confirmed write access *and* (for custom folders) managed to create a bookmark; `false` otherwise.
    @discardableResult
    func trySetDestination(_ url: URL) -> Bool {
        print("[SettingsStore] DEBUG: trySetDestination called with: \(url.path)")

        // Validate the URL exists & is a directory.
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            print("[SettingsStore] ERROR: Invalid directory: \(url.path)")
            return false
        }

        // Quick write-test to confirm sandbox/TCC access.
        let testFile = url.appendingPathComponent(".mm_write_test_\(UUID().uuidString)")
        do {
            try Data().write(to: testFile)
            try fm.removeItem(at: testFile)
        } catch {
            print("[SettingsStore] ERROR: Write-test failed: \(error)")
            return false
        }

        // All good – commit the new URL. This is the ONLY assignment to destinationURL now.
        destinationURL = url
        return true
    }

    func setDestination(_ url: URL) {
        _ = trySetDestination(url)
    }
    

    // Volume-specific automation logic removed.
} 