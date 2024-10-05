import SwiftUI

struct VolumeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(selection: Binding(
            get: { self.appState.selectedVolumeID },
            set: { VolumeLogic.selectVolume(withID: $0 ?? "", appState: self.appState) }
        )) {
            Section(header: Text("REMOVABLE VOLUMES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, 8)) {
                ForEach(appState.volumes) { volume in
                    HStack(spacing: 8) {
                        Image(systemName: "sdcard.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text(volume.name)
                            .font(.system(size: 13))
                        Spacer()
                        Button(action: {
                            print("VolumeView: Eject button tapped for volume: \(volume.name)")
                            VolumeLogic.ejectVolume(volume, appState: appState)
                        }) {
                            Image(systemName: "eject.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 2)
                    .tag(volume.id)
                }
            }
        }
        .listStyle(SidebarListStyle())
        .onAppear {
            print("VolumeView: View appeared")
            print("VolumeView: Volumes count - \(appState.volumes.count)")
            print("VolumeView: Selected volume ID - \(appState.selectedVolumeID ?? "None")")
        }
    }
}

struct VolumeView_Previews: PreviewProvider {
    static var previews: some View {
        VolumeView().environmentObject(AppState())
    }
}
