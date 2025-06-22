import Foundation
import SwiftUI

class SettingsStore: ObservableObject {
    @Published var settingDeleteOriginals: Bool {
        didSet {
            UserDefaults.standard.set(settingDeleteOriginals, forKey: "settingDeleteOriginals")
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
} 