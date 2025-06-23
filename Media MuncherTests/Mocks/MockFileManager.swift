import Foundation
@testable import Media_Muncher

class MockFileManager: FileManagerProtocol {
    var virtualFileSystem: [String: Data] = [:]
    var createdDirectories = Set<String>()
    var copiedFiles = [(source: URL, destination: URL)]()
    var removedItems = [URL]()
    
    var shouldThrowOnCreateDirectory = false
    var shouldThrowOnCopy = false
    var shouldThrowOnRemove = false
    
    func fileExists(atPath path: String) -> Bool {
        return virtualFileSystem[path] != nil || createdDirectories.contains(path)
    }
    
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws {
        if shouldThrowOnCreateDirectory {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create directory"])
        }
        
        if createIntermediates {
            var currentPath = ""
            for component in url.pathComponents {
                currentPath += component
                if currentPath == "/" { continue }
                if !currentPath.hasSuffix("/") {
                    currentPath += "/"
                }
                let a = String(currentPath.dropLast())
                
                if virtualFileSystem[a] == nil {
                     createdDirectories.insert(a)
                }
            }
        } else {
            createdDirectories.insert(url.path)
        }
    }
    
    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        if shouldThrowOnCopy {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to copy item"])
        }
        guard virtualFileSystem[srcURL.path] != nil else {
            let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSFilePathErrorKey: srcURL.path])
            throw error
        }
        virtualFileSystem[dstURL.path] = virtualFileSystem[srcURL.path]
        copiedFiles.append((source: srcURL, destination: dstURL))
    }

    func removeItem(at URL: URL) throws {
        if shouldThrowOnRemove {
            throw NSError(domain: "MockError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to remove item"])
        }
        if virtualFileSystem.removeValue(forKey: URL.path) != nil {
            removedItems.append(URL)
        } else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSFilePathErrorKey: URL.path])
        }
    }
} 