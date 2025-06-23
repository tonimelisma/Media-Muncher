import AppKit
import Foundation

class VolumeObserver: NSObject {
    override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(volumeMounted),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        print("Volume observer initialized.")
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc func volumeMounted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey] as? URL
        else {
            print("Could not get volume URL from notification.")
            return
        }
        
        print("Volume mounted at path: \(volumeURL.path)")

        do {
            let resourceValues = try volumeURL.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeUUIDStringKey])
            guard resourceValues.volumeIsRemovable == true, let uuid = resourceValues.volumeUUIDString else {
                print("Volume is not removable or has no UUID, ignoring.")
                return
            }
            
            print("Removable volume detected. UUID: \(uuid). Launching main application.")
            launchMainApp(with: uuid)
            
        } catch {
            print("Failed to get resource values for volume: \(error)")
        }
    }

    private func launchMainApp(with uuid: String) {
        // Path to the main app from the helper's perspective.
        // The helper is in Contents/Library/LoginItems, so we go up three levels.
        let mainAppURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--volume-uuid", uuid]
        
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, error in
            if let error = error {
                print("Failed to launch main application: \(error)")
            } else {
                print("Main application launched successfully.")
            }
        }
    }
}

// Keep the observer alive
let observer = VolumeObserver()

// Run the loop to keep the helper alive
RunLoop.main.run() 