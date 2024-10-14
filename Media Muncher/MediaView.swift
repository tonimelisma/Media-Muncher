import SwiftUI

struct MediaView: View {
    @ObservedObject var mediaViewModel: MediaViewModel
    @ObservedObject var volumeViewModel: VolumeViewModel
    @StateObject private var mediaFilesViewModel: MediaFilesViewModel
    @EnvironmentObject var appState: AppState
    @State private var showingError = false
    @State private var errorMessage = ""

    init(mediaViewModel: MediaViewModel, volumeViewModel: VolumeViewModel) {
        self.mediaViewModel = mediaViewModel
        self.volumeViewModel = volumeViewModel
        self._mediaFilesViewModel = StateObject(wrappedValue: MediaFilesViewModel())
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                content
                Spacer()
                bottomBar
            }
        }
        .alert(isPresented: $showingError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear(perform: onAppear)
        .onChange(of: appState.selectedVolumeID) { oldValue, newValue in
            onSelectedVolumeIDChange(oldValue, newValue)
        }
        .onChange(of: appState.mediaFiles) { oldValue, newValue in
            onMediaFilesChange(oldValue, newValue)
        }
    }
    
    @ViewBuilder
    var content: some View {
        if appState.volumes.isEmpty {
            noVolumesView
        } else if appState.selectedVolumeID == nil {
            noVolumeSelectedView
        } else if !appState.isSelectedVolumeAccessible {
            volumeAccessRequiredView
        } else if appState.appOperationState == .enumerating || !mediaFilesViewModel.displayedMediaFiles.isEmpty {
            MediaFilesGridView(mediaFiles: mediaFilesViewModel.displayedMediaFiles)
        } else {
            noMediaFilesView
        }
    }
    
    var noVolumesView: some View {
        centeredContent {
            Text("No Removable Volumes Found")
                .font(.headline)
            
            Text("To import media, please connect a removable volume (such as an SD card or external drive) to your Mac. Once connected, click 'Refresh Volumes' in the toolbar.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: refreshVolumes) {
                Text("Refresh Volumes")
                    .frame(minWidth: 100)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    var noVolumeSelectedView: some View {
        centeredContent {
            Text("No Volume Selected")
                .font(.headline)
            
            Text("Please select a volume from the sidebar to view its contents.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    var volumeAccessRequiredView: some View {
        centeredContent {
            Text("Volume Access Required")
                .font(.headline)
            
            Text("Permission is needed to access this volume. Please grant access when prompted.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: requestAccess) {
                Text("Request Access")
                    .frame(minWidth: 100)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    var noMediaFilesView: some View {
        centeredContent {
            Text("No Media Files Found")
                .font(.headline)
            
            Text("There are no media files on this volume that Media Muncher can import.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    var bottomBar: some View {
        HStack {
            Text("Import To:")
                .font(.system(size: 13, weight: .semibold))

            FolderSelector(
                defaultSavePath: $appState.defaultSavePath,
                showAdvancedSettings: true)
            .onChange(of: appState.defaultSavePath) { oldValue, newValue in
                print("MediaView: Default save path changed from \(oldValue) to \(newValue)")
            }

            Spacer()

            Button("Import", action: importMedia)
                .disabled(appState.selectedVolumeID == nil || !appState.isSelectedVolumeAccessible || appState.appOperationState == .enumerating)
        }
        .padding()
        .background(Color(nsColor: .quinaryLabel))
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
    
    private func refreshVolumes() {
        volumeViewModel.refreshVolumes()
    }
    
    private func requestAccess() {
        if let selectedID = appState.selectedVolumeID {
            volumeViewModel.selectVolume(withID: selectedID)
        }
    }
    
    private func importMedia() {
        print("MediaView: Import button clicked")
        mediaViewModel.importMedia()
    }
    
    private func onAppear() {
        print("MediaView: View appeared")
        mediaFilesViewModel.setAppState(appState)
    }
    
    private func onSelectedVolumeIDChange(_ oldValue: String?, _ newValue: String?) {
        print("MediaView: Selected volume ID changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
    }
    
    private func onMediaFilesChange(_ oldValue: [MediaFile], _ newValue: [MediaFile]) {
        print("MediaView: Media files changed. Old count: \(oldValue.count), New count: \(newValue.count)")
    }
}

struct MediaView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        let volumeViewModel = VolumeViewModel(appState: appState)
        let mediaViewModel = MediaViewModel(appState: appState)
        return MediaView(mediaViewModel: mediaViewModel, volumeViewModel: volumeViewModel).environmentObject(appState)
    }
}
