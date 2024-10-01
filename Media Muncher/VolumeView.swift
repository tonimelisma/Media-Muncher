import SwiftUI

struct VolumeView: View {
    @EnvironmentObject var viewModel: VolumeViewModel
    @Binding var selectedVolume: Volume?

    var body: some View {
        List(selection: Binding(
            get: { selectedVolume?.id },
            set: { newValue in
                selectedVolume = viewModel.volumes.first(where: { $0.id == newValue })
            }
        )) {
            Section(header: Text("REMOVABLE VOLUMES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, 8)) {
                ForEach(viewModel.volumes) { volume in
                    HStack(spacing: 8) {
                        Image(systemName: "sdcard.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text(volume.name)
                            .font(.system(size: 13))
                        Spacer()
                        Button(action: {
                            viewModel.ejectVolume(volume)
                            if selectedVolume?.id == volume.id {
                                selectedVolume = nil
                            }
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
    }
}

struct VolumeView_Previews: PreviewProvider {
    static var previews: some View {
        VolumeView(selectedVolume: .constant(nil))
            .environmentObject(VolumeViewModel())
    }
}
