import Foundation
import SwiftUI

class SettingsStore: ObservableObject {
    @Published var settingDeleteOriginals: Bool {
        didSet {
            UserDefaults.standard.set(settingDeleteOriginals, forKey: "settingDeleteOriginals")
        }
    }

    @Published var organizeByDate: Bool {
        didSet {
            UserDefaults.standard.set(organizeByDate, forKey: "organizeByDate")
        }
    }
    
    @Published var renameByDate: Bool {
        didSet {
            UserDefaults.standard.set(renameByDate, forKey: "renameByDate")
        }
    }

    @Published var filterImages: Bool {
        didSet {
            UserDefaults.standard.set(filterImages, forKey: "filterImages")
        }
    }

    @Published var filterVideos: Bool {
        didSet {
            UserDefaults.standard.set(filterVideos, forKey: "filterVideos")
        }
    }

    @Published var filterAudio: Bool {
        didSet {
            UserDefaults.standard.set(filterAudio, forKey: "filterAudio")
        }
    }

    @Published var settingAutoEject: Bool {
        didSet {
            UserDefaults.standard.set(settingAutoEject, forKey: "settingAutoEject")
        }
    }

    @Published private(set) var destinationBookmark: Data? {
        didSet {
            UserDefaults.standard.set(destinationBookmark, forKey: "destinationBookmarkData")
            // When the bookmark changes, we need to resolve it to a URL again.
            self.destinationURL = resolveBookmark()
        }
    }
    
    @Published private(set) var destinationURL: URL?

    init() {
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
        self.destinationURL = resolveBookmark()

        // If no bookmark is stored, default to the Pictures directory.
        if destinationURL == nil, let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
            setDestination(url: picturesURL)
        }
    }

    func setDestination(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            self.destinationBookmark = bookmarkData
        } catch {
            print("Error creating bookmark: \(error)")
            // Optionally, handle the error, e.g., by showing an alert to the user.
            self.destinationBookmark = nil
        }
    }
    
    private func resolveBookmark() -> URL? {
        guard let bookmarkData = destinationBookmark else {
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("Bookmark is stale, attempting to refresh.")
                // If the bookmark is stale, we can try to create a new one to replace the old one.
                setDestination(url: url)
            }
            
            return url
        } catch {
            print("Error resolving bookmark: \(error)")
            // The bookmark is invalid, clear it.
            self.destinationBookmark = nil
            return nil
        }
    }

    // Volume-specific automation logic removed.
} 