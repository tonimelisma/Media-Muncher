import SwiftUI
import AppKit

/// `AppDelegate` handles application-level events.
class AppDelegate: NSObject, NSApplicationDelegate {
    /// Determines whether the application should terminate after the last window is closed.
    /// - Parameter sender: The application instance.
    /// - Returns: `true` to terminate the application, `false` otherwise.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    /// Called when the application has finished launching.
    /// - Parameter notification: The notification object.
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: Application did finish launching")
    }
}

/// The main structure of the Media Muncher application.
@main
struct Media_MuncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .environmentObject(appState)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            SidebarCommands()
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
    
    /// Initializes the Media_MuncherApp.
    init() {
        print("Media_MuncherApp: Initializing")
    }
}
