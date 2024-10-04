import SwiftUI

struct MediaView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var defaultSavePath: String

    var body: some View {
        VStack {
            if viewModel.volumes.isEmpty {
                Text("No removable volumes found")
            } else if let volume = viewModel.volumes.first(where: { $0.id == viewModel.selectedVolumeID }) {
                VStack {
                    Text("Volume: \(volume.name)")
                        .font(.headline)
                        .padding(.bottom)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Button(action: {
                            viewModel.showingPermissionAlert = true
                        }) {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        }
                        .alert(isPresented: $viewModel.showingPermissionAlert) {
                            Alert(
                                title: Text("Permission Required"),
                                message: Text("To access this volume, you may need to grant permission in System Preferences or select the volume again."),
                                primaryButton: .default(Text("Open System Preferences")) {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                        NSWorkspace.shared.open(url)
                                    }
                                },
                                secondaryButton: .default(Text("Select Volume")) {
                                    viewModel.requestVolumeAccess()
                                }
                            )
                        }
                    } else if viewModel.fileItems.isEmpty {
                        Text("No files found on this volume")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150))], spacing: 10) {
                                ForEach(viewModel.fileItems) { item in
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
                    defaultSavePath: $defaultSavePath,
                    showAdvancedSettings: true)

                Spacer()

                Button("Import") {
                    print("MediaView: Import button tapped")
                    // Import action here
                }
                .disabled(viewModel.selectedVolumeID == nil)
            }
            .padding()
        }
        .onAppear {
            print("MediaView: View appeared")
            print("MediaView: Volume - \(viewModel.volumes.first(where: { $0.id == viewModel.selectedVolumeID })?.name ?? "None")")
            print("MediaView: File items count - \(viewModel.fileItems.count)")
        }
    }
}
