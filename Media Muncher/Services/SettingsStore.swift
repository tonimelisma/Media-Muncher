import Foundation
import SwiftUI

class SettingsStore: ObservableObject {
    @Published var settingDeleteOriginals: Bool {
        didSet {
            UserDefaults.standard.set(settingDeleteOriginals, forKey: "settingDeleteOriginals")
        }
    }
    
    @Published var settingDestinationFolder: String {
        didSet {
            UserDefaults.standard.set(settingDestinationFolder, forKey: "settingDestinationFolder")
        }
    }

    init() {
        self.settingDeleteOriginals = UserDefaults.standard.bool(forKey: "settingDeleteOriginals")
        self.settingDestinationFolder =
            UserDefaults.standard.string(forKey: "settingDestinationFolder") ?? FileManager.default.urls(
                for: .picturesDirectory, in: .userDomainMask
            ).first?.path ?? ""
    }

    func setSettingDestinationFolder(_ folder: String) {
        settingDestinationFolder = folder
    }
} 