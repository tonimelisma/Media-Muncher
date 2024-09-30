import SwiftUI

class Settings: ObservableObject {
    @Published var mediaDownloadLocation: URL {
        didSet {
            UserDefaults.standard.set(mediaDownloadLocation.path, forKey: "mediaDownloadLocation")
        }
    }
    
    init() {
        if let savedPath = UserDefaults.standard.string(forKey: "mediaDownloadLocation") {
            self.mediaDownloadLocation = URL(fileURLWithPath: savedPath)
        } else {
            self.mediaDownloadLocation = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
    }
}
