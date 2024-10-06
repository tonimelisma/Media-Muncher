import SwiftUI

struct MediaView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if appState.volumes.isEmpty {
                    centeredContent {
                        Text("No Removable Volumes Found")
                            .font(.headline)
                        
                        Text("To import media, please connect a removable volume (such as an SD card or external drive) to your Mac. Once connected, click 'Refresh Volumes' in the toolbar.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            VolumeLogic.refreshVolumes(appState)
                        }) {
                            Text("Refresh Volumes")
                                .frame(minWidth: 100)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let _ = appState.volumes.first(where: { $0.id == appState.selectedVolumeID }) {
                    if appState.fileItems.isEmpty {
                        centeredContent {
                            Text("No Files Found")
                                .font(.headline)
                            
                            Text("There are no files on this volume that Media Muncher can import.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
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
                } else {
                    centeredContent {
                        Text("No Volume Selected")
                            .font(.headline)
                        
                        Text("Please select a volume from the sidebar to view its contents.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
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
                        do {
                            try MediaLogic.importMedia()
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                    .disabled(appState.selectedVolumeID == nil)
                }
                .padding()
            }
        }
        .alert(isPresented: $showingError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            print("MediaView: View appeared")
            print("MediaView: Volume - \(appState.volumes.first(where: { $0.id == appState.selectedVolumeID })?.name ?? "None")")
            print("MediaView: File items count - \(appState.fileItems.count)")
        }
    }
    
    private func centeredContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                content()
            }
            .padding()
            .frame(maxWidth: 400)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MediaView_Previews: PreviewProvider {
    static var previews: some View {
        MediaView().environmentObject(AppState())
    }
}
