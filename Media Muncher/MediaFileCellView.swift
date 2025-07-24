import SwiftUI

struct MediaFileCellView: View {
    let file: File
    @State private var showingErrorAlert = false
    @State private var displayThumbnail: Image?
    @Environment(\.thumbnailCache) private var thumbnailCache

    var body: some View {
        VStack {
            ZStack {
                if let thumbnail = displayThumbnail {
                    thumbnail
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                } else {
                    Image(systemName: file.mediaType.sfSymbolName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .padding(.vertical, 25)
                }
                
                if file.status == .pre_existing || file.status == .imported {
                    Color.black.opacity(0.4)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.largeTitle)
                }
                
                if file.status == .deleted_as_duplicate {
                    Color.black.opacity(0.4)
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.white)
                        .font(.largeTitle)
                }
                
                if file.status == .duplicate_in_source {
                    Color.black.opacity(0.4)
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundColor(.white)
                        .font(.largeTitle)
                }
                
                if file.status == .copying || file.status == .verifying {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
                
                if file.status == .failed {
                    Color.black.opacity(0.4)
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.largeTitle)
                        .onTapGesture {
                            self.showingErrorAlert = true
                        }
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(file.sourceName)
                .lineLimit(1)
                .font(.caption)
                .frame(width: 100)
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: file.id) { _ in
            loadThumbnail()
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("Import Failed"),
                message: Text(file.importError ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadThumbnail() {
        Task {
            let url = URL(fileURLWithPath: file.sourcePath)
            displayThumbnail = await thumbnailCache.thumbnailImage(for: url)
        }
    }
} 