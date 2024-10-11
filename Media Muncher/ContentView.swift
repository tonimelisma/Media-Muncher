import SwiftUI

/// `ContentView` is the main view of the application.
/// It sets up the navigation structure and toolbar.
struct ContentView: View {
    @StateObject private var volumeViewModel: VolumeViewModel
    @StateObject private var mediaViewModel: MediaViewModel
    @ObservedObject var appState: AppState

    /// Initializes the `ContentView` with the given `AppState`.
    /// - Parameter appState: The global app state.
    init(appState: AppState) {
        self.appState = appState
        _volumeViewModel = StateObject(wrappedValue: VolumeViewModel(appState: appState))
        _mediaViewModel = StateObject(wrappedValue: MediaViewModel(appState: appState))
    }

    var body: some View {
        NavigationView {
            // Sidebar view for volume selection
            VolumeView(viewModel: volumeViewModel)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            // Main content view for media display
            MediaView(mediaViewModel: mediaViewModel, volumeViewModel: volumeViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 1)
        }
        .navigationTitle("Media Muncher")
        .toolbar {
            // Toolbar items
            ToolbarItem(placement: .navigation) {
                Button(action: UILogic.toggleSidebar) {
                    Image(systemName: "sidebar.leading")
                }
            }

            ToolbarItem(placement: .navigation) {
                Text("Media Muncher")
                    .font(.system(size: 15, weight: .semibold))
            }

            ToolbarItem(placement: .automatic) {
                Spacer()
            }

            ToolbarItem(placement: .automatic) {
                Button(action: {
                    print("ContentView: Refresh volumes button tapped")
                    volumeViewModel.refreshVolumes()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh volumes")
                            .font(.system(size: 13))
                    }
                }
            }

            ToolbarItem(placement: .automatic) {
                SettingsLink {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                        Text("Settings")
                            .font(.system(size: 13))
                    }
                }
            }
        }
        .toolbarBackground(.quinary)
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            print("ContentView: View appeared")
        }
        .environmentObject(appState)
    }
}

/// Preview provider for ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(appState: AppState())
    }
}
