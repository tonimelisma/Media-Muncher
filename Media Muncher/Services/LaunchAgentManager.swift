import Foundation
import ServiceManagement

class LaunchAgentManager {
    static let shared = LaunchAgentManager()
    
    private let service = SMAppService.loginItem(identifier: "com.tonimelisma.MediaMuncherHelper")

    private init() {}

    func enable() {
        do {
            try service.register()
            print("Successfully registered and enabled the login item.")
        } catch {
            print("Failed to enable login item: \(error.localizedDescription)")
        }
    }

    func disable() {
        do {
            try service.unregister()
            print("Successfully unregistered and disabled the login item.")
        } catch {
            print("Failed to disable login item: \(error.localizedDescription)")
        }
    }
    
    var isEnabled: Bool {
        return service.status == .enabled
    }
} 