import SwiftUI

struct BottomBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            if appState.state == .enumeratingFiles {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text("\(appState.filesScanned) files")
                    .font(.caption)
                    .padding(.leading, 4)
                Button("Stop") {
                    appState.cancelScan()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
            } else if appState.state == .importingFiles {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(appState.importedBytes), total: Double(appState.totalBytesToImport > 0 ? appState.totalBytesToImport : 1))
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text("\(appState.importedFileCount) / \(appState.totalFilesToImport) files")
                        Spacer()
                        Text(byteCountFormatter.string(fromByteCount: appState.importedBytes) + " / " + byteCountFormatter.string(fromByteCount: appState.totalBytesToImport))
                    }
                    .font(.caption)
                }
                Button("Cancel") {
                    appState.cancelImport()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
            }
            ErrorView()
            Spacer()
            if appState.state != .importingFiles {
                Button("Import") {
                    appState.importFiles()
                }
                .disabled(appState.state != .idle || appState.files.isEmpty)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .quinaryLabel))
    }
}

private let byteCountFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter
}() 