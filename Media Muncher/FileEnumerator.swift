import Foundation

class FileEnumerator {
    static func enumerateFiles(for volumePath: String, limit: Int = 10) -> [FileItem] {
        print("FileEnumerator: Enumerating files for path: \(volumePath)")
        var fileItems: [FileItem] = []
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: volumePath) else {
            print("FileEnumerator: Failed to create enumerator for path: \(volumePath)")
            return fileItems
        }
        
        print("FileEnumerator: Successfully created enumerator")
        
        var count = 0
        while let filePath = enumerator.nextObject() as? String {
            print("FileEnumerator: Found item: \(filePath)")
            
            if count >= limit { break }
            
            let fullPath = (volumePath as NSString).appendingPathComponent(filePath)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                print("FileEnumerator: Item exists, isDirectory: \(isDirectory.boolValue)")
                
                let itemType = isDirectory.boolValue ? "directory" : "file"
                print("FileEnumerator: Adding \(itemType): \(filePath)")
                let fileItem = FileItem(name: (filePath as NSString).lastPathComponent,
                                        path: fullPath,
                                        type: itemType)
                fileItems.append(fileItem)
                count += 1
            } else {
                print("FileEnumerator: Item doesn't exist: \(fullPath)")
            }
        }
        print("FileEnumerator: Enumerated \(count) items")
        
        return fileItems
    }
}
