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
                        Text("\(appState.importedFileCount) / \(appState.files.filter { $0.status != .pre_existing }.count) files")
                        Spacer()
                        Text(byteCountFormatter.string(fromByteCount: appState.importedBytes) + " / " + byteCountFormatter.string(fromByteCount: appState.totalBytesToImport))
                    }
                    .font(.caption)

                    // Timing row
                    if let elapsed = appState.elapsedSeconds {
                        HStack(spacing: 8) {
                            Text("Elapsed " + formatTime(elapsed))
                            if let remaining = appState.remainingSeconds {
                                Text("· ETA " + formatTime(remaining))
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
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

private func formatTime(_ seconds: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: seconds) ?? ""
} 