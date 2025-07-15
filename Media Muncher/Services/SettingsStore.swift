import Foundation
import SwiftUI

class SettingsStore: ObservableObject {
    private let userDefaults: UserDefaults
    
    @Published var settingDeleteOriginals: Bool {
        didSet {
            LogManager.debug("settingDeleteOriginals changed", category: "SettingsStore", metadata: ["value": "\(settingDeleteOriginals)"])
            userDefaults.set(settingDeleteOriginals, forKey: "settingDeleteOriginals")
        }
    }

    @Published var organizeByDate: Bool {
        didSet {
            LogManager.debug("organizeByDate changed", category: "SettingsStore", metadata: ["value": "\(organizeByDate)"])
            userDefaults.set(organizeByDate, forKey: "organizeByDate")
        }
    }
    
    @Published var renameByDate: Bool {
        didSet {
            LogManager.debug("renameByDate changed", category: "SettingsStore", metadata: ["value": "\(renameByDate)"])
            userDefaults.set(renameByDate, forKey: "renameByDate")
        }
    }

    @Published var filterImages: Bool {
        didSet {
            LogManager.debug("filterImages changed", category: "SettingsStore", metadata: ["value": "\(filterImages)"])
            userDefaults.set(filterImages, forKey: "filterImages")
        }
    }

    @Published var filterVideos: Bool {
        didSet {
            LogManager.debug("filterVideos changed", category: "SettingsStore", metadata: ["value": "\(filterVideos)"])
            userDefaults.set(filterVideos, forKey: "filterVideos")
        }
    }

    @Published var filterAudio: Bool {
        didSet {
            LogManager.debug("filterAudio changed", category: "SettingsStore", metadata: ["value": "\(filterAudio)"])
            userDefaults.set(filterAudio, forKey: "filterAudio")
        }
    }

    @Published var settingAutoEject: Bool {
        didSet {
            LogManager.debug("settingAutoEject changed", category: "SettingsStore", metadata: ["value": "\(settingAutoEject)"])
            userDefaults.set(settingAutoEject, forKey: "settingAutoEject")
        }
    }

    
    @Published private(set) var destinationURL: URL? {
        didSet {
            LogManager.debug("destinationURL changed", category: "SettingsStore", metadata: ["path": destinationURL?.path ?? "nil"])
        }
    }


    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        LogManager.debug("Initializing SettingsStore", category: "SettingsStore")
        
        self.settingDeleteOriginals = userDefaults.bool(forKey: "settingDeleteOriginals")
        self.organizeByDate = userDefaults.bool(forKey: "organizeByDate")
        self.renameByDate = userDefaults.bool(forKey: "renameByDate")
        self.settingAutoEject = userDefaults.bool(forKey: "settingAutoEject")
        
        // Automation feature removed – auto-launch toggle deprecated.

        // Default to true if no value is set
        self.filterImages = userDefaults.object(forKey: "filterImages") as? Bool ?? true
        self.filterVideos = userDefaults.object(forKey: "filterVideos") as? Bool ?? true
        self.filterAudio = userDefaults.object(forKey: "filterAudio") as? Bool ?? true

        // Remove obsolete automation keys (version <0.3) - only for standard UserDefaults
        if userDefaults == UserDefaults.standard {
            userDefaults.removeObject(forKey: "autoLaunchEnabled")
            userDefaults.removeObject(forKey: "volumeAutomationSettings")
            userDefaults.removeObject(forKey: "destinationBookmarkData")
            userDefaults.removeObject(forKey: "lastCustomBookmarkData")
        }

        self.destinationURL = nil
        LogManager.debug("Initial destinationURL set to nil", category: "SettingsStore")

        // If no bookmark is stored, default to the Pictures directory.
        if destinationURL == nil {
            setDefaults()
        }
    }

    private func setDefaults() {
        LogManager.debug("Setting default values", category: "SettingsStore")
        
        // Set default destination to user's Pictures folder (not sandboxed)
        let userPicturesURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        LogManager.debug("Default destination set to", category: "SettingsStore", metadata: ["path": userPicturesURL.path])
        
        if FileManager.default.fileExists(atPath: userPicturesURL.path) {
            LogManager.debug("User Pictures folder exists, setting as destination", category: "SettingsStore")
            setDestination(userPicturesURL)
        } else {
            LogManager.debug("User Pictures folder doesn't exist, trying Documents", category: "SettingsStore")
            let userDocumentsURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            if FileManager.default.fileExists(atPath: userDocumentsURL.path) {
                setDestination(userDocumentsURL)
            } else {
                LogManager.debug("Neither Pictures nor Documents exist, leaving destination as nil", category: "SettingsStore")
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
        LogManager.debug("trySetDestination called", category: "SettingsStore", metadata: ["path": url.path])

        // Validate the URL exists & is a directory.
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            LogManager.error("Invalid directory", category: "SettingsStore", metadata: ["path": url.path])
            return false
        }

        // Quick write-test to confirm sandbox/TCC access.
        let testFile = url.appendingPathComponent(".mm_write_test_\(UUID().uuidString)")
        do {
            try Data().write(to: testFile)
            try fm.removeItem(at: testFile)
        } catch {
            LogManager.error("Write-test failed", category: "SettingsStore", metadata: ["error": error.localizedDescription])
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