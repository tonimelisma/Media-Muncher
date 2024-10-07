import Foundation

/// `FileItem` represents a file or directory in the file system.
struct FileItem: Identifiable {
    /// Unique identifier for the file item.
    let id = UUID()
    
    /// The name of the file or directory.
    let name: String
    
    /// The full path of the file or directory.
    let path: String
    
    /// The type of the item (e.g., "file", "directory").
    let type: String
    
    // TODO: Add more properties as needed (size, date, etc.)
}
