import Foundation

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let type: String // e.g., "image", "video", "document"
    // Add more properties as needed (size, date, etc.)
}
