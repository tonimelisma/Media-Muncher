import Foundation

/// `FileEnumerator` is a utility class for enumerating files in a given directory.
class FileEnumerator {
    /// Enumerates files in the specified volume path.
    /// - Parameters:
    ///   - volumePath: The path of the volume to enumerate.
    ///   - limit: The maximum number of files to enumerate (default is 10).
    /// - Returns: An array of `FileItem` objects representing the enumerated files.
    static func enumerateFiles(for volumePath: String, limit: Int = 10) -> [FileItem] {
        print("FileEnumerator: Enumerating files for path: \(volumePath)")
        var fileItems: [FileItem] = []
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: volumePath),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { (url, error) -> Bool in
                print("FileEnumerator: Error enumerating \(url): \(error.localizedDescription)")
                return true // Continue enumeration
            }
        ) else {
            print("FileEnumerator: Failed to create enumerator for path: \(volumePath)")
            return fileItems
        }
        
        print("FileEnumerator: Successfully created enumerator")
        
        var count = 0
        for case let fileURL as URL in enumerator {
            guard count < limit else { break }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
                let isDirectory = resourceValues.isDirectory ?? false
                let name = resourceValues.name ?? fileURL.lastPathComponent
                
                let itemType = isDirectory ? "directory" : "file"
                print("FileEnumerator: Found \(itemType): \(name)")
                
                let fileItem = FileItem(name: name,
                                        path: fileURL.path,
                                        type: itemType)
                fileItems.append(fileItem)
                count += 1
            } catch {
                print("FileEnumerator: Error getting resource values for \(fileURL.path): \(error.localizedDescription)")
            }
        }
        
        print("FileEnumerator: Enumerated \(count) items")
        return fileItems
    }
}
