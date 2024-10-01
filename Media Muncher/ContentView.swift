import AppKit
import SwiftUI

struct ContentView: View {
    @State private var selectedVolume: Volume?
    @StateObject private var volumeViewModel = VolumeViewModel()

    var body: some View {
        NavigationView {
            VolumeView(selectedVolume: $selectedVolume)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
                .environmentObject(volumeViewModel)

            ZStack {
                Color(NSColor.controlBackgroundColor)

                if let volume = selectedVolume {
                    MediaView(volume: volume)
                } else {
                    Text("Select a volume")
                }
            }
        }
        .navigationTitle("Media Muncher")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
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
                    volumeViewModel.loadVolumes()
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
        .frame(minWidth: 800, minHeight: 600)
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
