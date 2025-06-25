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
    
    var shouldFailOnCopy = false
    var failCopyForPaths: [String] = []
    var mismatchedFileSizeForPaths: [String: Int] = [:]
    
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
        if shouldFailOnCopy || failCopyForPaths.contains(srcURL.path) {
            throw NSError(domain: "MockFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Forced copy failure for testing."])
        }
        
        guard let data = virtualFileSystem[srcURL.path] else {
            throw NSError(domain: "MockFileManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Source file not found."])
        }
        
        let finalData: Data
        if let mismatchedSize = mismatchedFileSizeForPaths[dstURL.path] {
            finalData = Data(count: mismatchedSize)
        } else {
            finalData = data
        }
        
        virtualFileSystem[dstURL.path] = finalData
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

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        guard let data = virtualFileSystem[path] else {
            throw NSError(domain: "MockFileManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found."])
        }
        return [.size: data.count as NSNumber]
    }
} 