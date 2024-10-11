import SwiftUI

/// `MediaView` displays the content of the selected volume.
struct MediaView: View {
    @ObservedObject var mediaViewModel: MediaViewModel
    @ObservedObject var volumeViewModel: VolumeViewModel
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
                            print("MediaView: Refresh Volumes button tapped")
                            volumeViewModel.refreshVolumes()
                        }) {
                            Text("Refresh Volumes")
                                .frame(minWidth: 100)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if appState.selectedVolumeID == nil {
                    centeredContent {
                        Text("No Volume Selected")
                            .font(.headline)
                        
                        Text("Please select a volume from the sidebar to view its contents.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else if !appState.isSelectedVolumeAccessible {
                    centeredContent {
                        Text("Volume Access Required")
                            .font(.headline)
                        
                        Text("Permission is needed to access this volume. Please grant access when prompted.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            print("MediaView: Request Access button tapped")
                            if let selectedID = appState.selectedVolumeID {
                                volumeViewModel.selectVolume(withID: selectedID)
                            }
                        }) {
                            Text("Request Access")
                                .frame(minWidth: 100)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if appState.mediaFiles.isEmpty {
                    centeredContent {
                        Text("No Media Files Found")
                            .font(.headline)
                        
                        Text("There are no media files on this volume that Media Muncher can import.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150))], spacing: 10) {
                            ForEach(appState.mediaFiles) { mediaFile in
                                VStack {
                                    Image(systemName: iconForMediaFile(mediaFile))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(colorForMediaFile(mediaFile))
                                    Text(mediaFile.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .onTapGesture {
                                    print("MediaView: Media file tapped - \(mediaFile.name)")
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: appState.mediaFiles) { _, newValue in
                        print("MediaView: Media files updated, new count: \(newValue.count)")
                    }
                }

                Spacer()

                HStack {
                    Text("Import To:")
                        .font(.system(size: 13, weight: .semibold))

                    FolderSelector(
                        defaultSavePath: $appState.defaultSavePath,
                        showAdvancedSettings: true)
                    .onChange(of: appState.defaultSavePath) { _, newValue in
                        print("MediaView: Default save path changed to \(newValue)")
                    }

                    Spacer()

                    Button("Import") {
                        print("MediaView: Import button tapped")
                        do {
                            try mediaViewModel.importMedia()
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                    .disabled(appState.selectedVolumeID == nil || !appState.isSelectedVolumeAccessible)
                    .onChange(of: appState.selectedVolumeID) { _, newValue in
                        print("MediaView: Import button \(newValue == nil ? "disabled" : "enabled")")
                    }
                }
                .padding()
            }
        }
        .alert(isPresented: $showingError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            print("MediaView: View appeared")
            print("MediaView: Selected Volume - \(appState.volumes.first(where: { $0.id == appState.selectedVolumeID })?.name ?? "None")")
            print("MediaView: Media files count - \(appState.mediaFiles.count)")
        }
        .onChange(of: appState.selectedVolumeID) { oldValue, newValue in
            print("MediaView: Selected volume ID changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
        }
        .onChange(of: appState.mediaFiles) { oldValue, newValue in
            print("MediaView: Media files changed. Old count: \(oldValue.count), New count: \(newValue.count)")
            print("MediaView: Media files breakdown - Photos: \(newValue.filter { $0.mediaType.category == .processedPicture || $0.mediaType.category == .rawPicture }.count), Videos: \(newValue.filter { $0.mediaType.category == .video || $0.mediaType.category == .rawVideo }.count), Audio: \(newValue.filter { $0.mediaType.category == .audio }.count)")
        }
    }
    
    /// Creates a centered content view.
    /// - Parameter content: The content to be centered.
    /// - Returns: A view with the content centered both vertically and horizontally.
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
    
    /// Determines the appropriate icon for a media file.
    /// - Parameter mediaFile: The media file to get an icon for.
    /// - Returns: The name of the system icon to use.
    private func iconForMediaFile(_ mediaFile: MediaFile) -> String {
        switch mediaFile.mediaType.category {
        case .processedPicture, .rawPicture:
            return "photo"
        case .video, .rawVideo:
            return "video"
        case .audio:
            return "music.note"
        }
    }
    
    /// Determines the appropriate color for a media file icon.
    /// - Parameter mediaFile: The media file to get a color for.
    /// - Returns: The color to use for the icon.
    private func colorForMediaFile(_ mediaFile: MediaFile) -> Color {
        switch mediaFile.mediaType.category {
        case .processedPicture, .rawPicture:
            return .blue
        case .video, .rawVideo:
            return .red
        case .audio:
            return .green
        }
    }
}

/// Preview provider for MediaView
struct MediaView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        let volumeViewModel = VolumeViewModel(appState: appState)
        let mediaViewModel = MediaViewModel(appState: appState)
        return MediaView(mediaViewModel: mediaViewModel, volumeViewModel: volumeViewModel).environmentObject(appState)
    }
}
