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

    @Published private(set) var destinationBookmark: Data? {
        didSet {
            print("[SettingsStore] DEBUG: destinationBookmark changed - has data: \(destinationBookmark != nil)")
            UserDefaults.standard.set(destinationBookmark, forKey: "destinationBookmarkData")
            // When the bookmark changes, we need to resolve it to a URL again.
            self.destinationURL = resolveBookmark()
        }
    }
    
    @Published private(set) var destinationURL: URL? {
        didSet {
            print("[SettingsStore] DEBUG: destinationURL changed to: \(destinationURL?.path ?? "nil")")
        }
    }

    // MARK: - Last custom folder persistence
    /// Stores the bookmark data of the most recently chosen *custom* folder (i.e. not one of the six presets).
    /// This allows the Settings UI to present that folder in its own section even when the user subsequently
    /// selects one of the preset directories.
    @Published private(set) var lastCustomBookmark: Data? {
        didSet {
            print("[SettingsStore] DEBUG: lastCustomBookmark changed – has data: \(lastCustomBookmark != nil)")
            UserDefaults.standard.set(lastCustomBookmark, forKey: "lastCustomBookmarkData")
        }
    }

    /// Convenience accessor returning the resolved URL for `lastCustomBookmark`, if any.
    var lastCustomURL: URL? {
        resolveBookmark(lastCustomBookmark)
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

        self.destinationBookmark = UserDefaults.standard.data(forKey: "destinationBookmarkData")
        print("[SettingsStore] DEBUG: Loaded bookmark from UserDefaults: \(destinationBookmark != nil)")

        self.lastCustomBookmark = UserDefaults.standard.data(forKey: "lastCustomBookmarkData")
        print("[SettingsStore] DEBUG: Loaded lastCustomBookmark from UserDefaults: \(lastCustomBookmark != nil)")
        
        self.destinationURL = resolveBookmark()
        print("[SettingsStore] DEBUG: Resolved bookmark to URL: \(destinationURL?.path ?? "nil")")

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

        // Attempt to create a security-scoped bookmark for *all* folders so we hit the TCC gate.
        print("[SettingsStore] DEBUG: Attempting bookmark creation (this should trigger TCC if needed)…")
        var bookmarkData: Data?
        do {
            bookmarkData = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: [.isDirectoryKey], relativeTo: nil)
            print("[SettingsStore] DEBUG: Bookmark creation SUCCESS (size: \(bookmarkData!.count) bytes)")
        } catch {
            print("[SettingsStore] ERROR: Bookmark creation FAILED: \(error)")
            if let nserr = error as NSError? {
                print("[SettingsStore] ERROR: NSError domain=\(nserr.domain) code=\(nserr.code) userInfo=\(nserr.userInfo)")
            }
            return false // considered a permission denial
        }

        guard let data = bookmarkData else {
            print("[SettingsStore] ERROR: bookmarkData nil after supposed success – aborting")
            return false
        }

        // Persist bookmark for custom folders and for destination usage.
        destinationBookmark = data
        UserDefaults.standard.set(data, forKey: "destinationBookmark")

        if !isPresetFolder(url) {
            lastCustomBookmark = data
        }

        // All good – commit.
        destinationURL = url
        return true
    }

    func setDestination(_ url: URL) {
        _ = trySetDestination(url)
    }
    
    // MARK: - Bookmark helpers (overloads)
    /// Resolves an arbitrary security–scoped bookmark and returns its URL.
    /// If resolution fails, `nil` is returned and the caller may decide what to do.
    private func resolveBookmark(_ bookmarkData: Data?) -> URL? {
        guard let data = bookmarkData else { return nil }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                print("[SettingsStore] DEBUG: Stale bookmark encountered while resolving.")
            }
            return url
        } catch {
            print("[SettingsStore] ERROR: Failed to resolve bookmark: \(error)")
            return nil
        }
    }

    private func resolveBookmark() -> URL? {
        print("[SettingsStore] DEBUG: resolveBookmark called")
        guard let bookmarkData = destinationBookmark else {
            print("[SettingsStore] DEBUG: No bookmark data to resolve")
            return nil
        }
        
        print("[SettingsStore] DEBUG: Attempting to resolve bookmark with \(bookmarkData.count) bytes")
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            print("[SettingsStore] DEBUG: Successfully resolved bookmark to: \(url.path)")
            print("[SettingsStore] DEBUG: Bookmark is stale: \(isStale)")
            
            if isStale {
                print("[SettingsStore] DEBUG: Bookmark is stale, attempting to refresh...")
                // If the bookmark is stale, we can try to create a new one to replace the old one.
                setDestination(url)
            }
            
            return url
        } catch {
            print("[SettingsStore] ERROR: Failed to resolve bookmark: \(error)")
            print("[SettingsStore] DEBUG: Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("[SettingsStore] DEBUG: NSError domain: \(nsError.domain), code: \(nsError.code)")
                print("[SettingsStore] DEBUG: NSError userInfo: \(nsError.userInfo)")
            }
            // The bookmark is invalid, clear it.
            self.destinationBookmark = nil
            return nil
        }
    }

    // Volume-specific automation logic removed.
} 