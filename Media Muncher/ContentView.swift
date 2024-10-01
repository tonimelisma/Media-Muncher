import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @AppStorage("defaultSavePath") private var defaultSavePath = NSHomeDirectory()

    var body: some View {
        NavigationView {
            VolumeView(volumes: $viewModel.volumes, selectedVolumeID: $viewModel.selectedVolumeID)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            MediaView(volume: viewModel.volumes.first(where: { $0.id == viewModel.selectedVolumeID }),
                      volumes: viewModel.volumes,
                      defaultSavePath: $defaultSavePath)
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
                    viewModel.loadVolumes()
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
