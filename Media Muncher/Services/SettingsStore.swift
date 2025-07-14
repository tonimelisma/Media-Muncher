import Foundation
import SwiftUI
import os

class SettingsStore: ObservableObject {
    @Published var settingDeleteOriginals: Bool {
        didSet {
            Logger.settings.debug("settingDeleteOriginals changed to: \(self.settingDeleteOriginals, privacy: .public)")
            UserDefaults.standard.set(settingDeleteOriginals, forKey: "settingDeleteOriginals")
        }
    }

    @Published var organizeByDate: Bool {
        didSet {
            Logger.settings.debug("organizeByDate changed to: \(self.organizeByDate, privacy: .public)")
            UserDefaults.standard.set(organizeByDate, forKey: "organizeByDate")
        }
    }
    
    @Published var renameByDate: Bool {
        didSet {
            Logger.settings.debug("renameByDate changed to: \(self.renameByDate, privacy: .public)")
            UserDefaults.standard.set(renameByDate, forKey: "renameByDate")
        }
    }

    @Published var filterImages: Bool {
        didSet {
            Logger.settings.debug("filterImages changed to: \(self.filterImages, privacy: .public)")
            UserDefaults.standard.set(filterImages, forKey: "filterImages")
        }
    }

    @Published var filterVideos: Bool {
        didSet {
            Logger.settings.debug("filterVideos changed to: \(self.filterVideos, privacy: .public)")
            UserDefaults.standard.set(filterVideos, forKey: "filterVideos")
        }
    }

    @Published var filterAudio: Bool {
        didSet {
            Logger.settings.debug("filterAudio changed to: \(self.filterAudio, privacy: .public)")
            UserDefaults.standard.set(filterAudio, forKey: "filterAudio")
        }
    }

    @Published var settingAutoEject: Bool {
        didSet {
            Logger.settings.debug("settingAutoEject changed to: \(self.settingAutoEject, privacy: .public)")
            UserDefaults.standard.set(settingAutoEject, forKey: "settingAutoEject")
        }
    }

    
    @Published private(set) var destinationURL: URL? {
        didSet {
            Logger.settings.debug("destinationURL changed to: \(self.destinationURL?.path ?? "nil", privacy: .public)")
        }
    }


    init() {
        Logger.settings.debug("Initializing SettingsStore")
        
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
        Logger.settings.debug("Initial destinationURL set to nil.")

        // If no bookmark is stored, default to the Pictures directory.
        if destinationURL == nil {
            setDefaults()
        }
    }

    private func setDefaults() {
        Logger.settings.debug("Setting default values")
        
        // Set default destination to user's Pictures folder (not sandboxed)
        let userPicturesURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        Logger.settings.debug("Default destination set to: \(userPicturesURL.path, privacy: .public)")
        
        if FileManager.default.fileExists(atPath: userPicturesURL.path) {
            Logger.settings.debug("User Pictures folder exists, setting as destination")
            setDestination(userPicturesURL)
        } else {
            Logger.settings.debug("User Pictures folder doesn't exist, trying Documents")
            let userDocumentsURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            if FileManager.default.fileExists(atPath: userDocumentsURL.path) {
                setDestination(userDocumentsURL)
            } else {
                Logger.settings.debug("Neither Pictures nor Documents exist, leaving destination as nil")
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
        Logger.settings.debug("trySetDestination called with: \(url.path, privacy: .public)")

        // Validate the URL exists & is a directory.
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            Logger.settings.error("Invalid directory: \(url.path, privacy: .public)")
            return false
        }

        // Quick write-test to confirm sandbox/TCC access.
        let testFile = url.appendingPathComponent(".mm_write_test_\(UUID().uuidString)")
        do {
            try Data().write(to: testFile)
            try fm.removeItem(at: testFile)
        } catch {
            Logger.settings.error("Write-test failed: \(error.localizedDescription, privacy: .public)")
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