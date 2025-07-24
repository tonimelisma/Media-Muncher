//
//  Media_MuncherApp.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/13/25.
//

import SwiftUI

@main
struct Media_MuncherApp: App {
    // This state variable holds the fully initialized container.
    // It starts as nil, and the UI will show a loading view until it is populated.
    @State private var container: AppContainer?
    
    var body: some Scene {
        WindowGroup {
            // Check if the container has been initialized.
            if let container = container {
                // Once the container is ready, show the main ContentView.
                ContentView()
                    // Inject all the necessary services into the environment.
                    .environmentObject(container.appState)
                    .environmentObject(container.volumeManager)
                    .environmentObject(container.settingsStore)
                    .environmentObject(container.fileStore)
                    .environment(\.thumbnailCache, container.thumbnailCache)
            } else {
                // While the container is nil, show a loading spinner.
                ProgressView()
                    .task {
                        // This task runs when the ProgressView appears.
                        // It creates the AppContainer on the main thread.
                        self.container = AppContainer()
                    }
            }
        }
        .commands {
            // This adds a "Settings" menu item to the app menu
        }

        Settings {
            // The Settings view also needs the services. We must ensure it also
            // has a loading state or gets the services once they are ready.
            // For now, we can conditionally show the view.
            if let container = container {
                SettingsView()
                    .environmentObject(container.settingsStore)
                    .environmentObject(container.volumeManager)
            }
        }
    }
}
