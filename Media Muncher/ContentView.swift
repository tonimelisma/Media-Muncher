import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @AppStorage("defaultSavePath") private var defaultSavePath = NSHomeDirectory()

    var body: some View {
        NavigationView {
            VolumeView(viewModel: viewModel)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            MediaView(volume: viewModel.volumes.first(where: { $0.id == viewModel.selectedVolumeID }),
                      volumes: viewModel.volumes,
                      fileItems: viewModel.fileItems,
                      defaultSavePath: $defaultSavePath)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    print("ContentView: Refresh volumes button tapped")
                    viewModel.refreshVolumes()
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
    }

    private func toggleSidebar() {
        print("ContentView: Toggle sidebar called")
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
