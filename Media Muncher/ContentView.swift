import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            VolumeView()
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            MediaView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Media Muncher")
        .toolbar {
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
                    VolumeLogic.refreshVolumes(appState)
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(AppState())
    }
}
