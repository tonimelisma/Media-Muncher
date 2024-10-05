import SwiftUI

struct MediaView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            if appState.volumes.isEmpty {
                Text("No removable volumes found")
            } else if let volume = appState.volumes.first(where: { $0.id == appState.selectedVolumeID }) {
                VStack {
                    Text("Volume: \(volume.name)")
                        .font(.headline)
                        .padding(.bottom)
                    
                    if let errorMessage = appState.errorMessage {
                        Button(action: {
                            appState.showingPermissionAlert = true
                        }) {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        }
                        .alert(isPresented: $appState.showingPermissionAlert) {
                            Alert(
                                title: Text("Permission Required"),
                                message: Text("To access this volume, you may need to grant permission in System Preferences or select the volume again."),
                                primaryButton: .default(Text("Open System Preferences")) {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                        NSWorkspace.shared.open(url)
                                    }
                                },
                                secondaryButton: .default(Text("Select Volume")) {
                                    VolumeLogic.requestVolumeAccess(appState)
                                }
                            )
                        }
                    } else if appState.fileItems.isEmpty {
                        Text("No files found on this volume")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150))], spacing: 10) {
                                ForEach(appState.fileItems) { item in
                                    VStack {
                                        Image(systemName: item.type == "directory" ? "folder" : "doc")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50, height: 50)
                                            .foregroundColor(item.type == "directory" ? .blue : .gray)
                                        Text(item.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Select a volume")
            }

            Spacer()

            HStack {
                Text("Import To:")
                    .font(.system(size: 13, weight: .semibold))

                FolderSelector(
                    defaultSavePath: $appState.defaultSavePath,
                    showAdvancedSettings: true)

                Spacer()

                Button("Import") {
                    print("MediaView: Import button tapped")
                    MediaLogic.importMedia(appState: appState)
                }
                .disabled(appState.selectedVolumeID == nil)
            }
            .padding()
        }
        .onAppear {
            print("MediaView: View appeared")
            print("MediaView: Volume - \(appState.volumes.first(where: { $0.id == appState.selectedVolumeID })?.name ?? "None")")
            print("MediaView: File items count - \(appState.fileItems.count)")
        }
    }
}

struct MediaView_Previews: PreviewProvider {
    static var previews: some View {
        MediaView().environmentObject(AppState())
    }
}
