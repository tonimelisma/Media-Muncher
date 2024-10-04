import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: Application did finish launching")
    }
}

@main
struct Media_MuncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var volumeManager = VolumeManager()
        
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(volumeManager)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            SidebarCommands()
        }
        
        Settings {
            SettingsView()
        }
    }
    
    init() {
        print("Media_MuncherApp: Initializing")
    }
}
