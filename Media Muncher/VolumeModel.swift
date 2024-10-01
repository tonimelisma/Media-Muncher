import Foundation

struct Volume: Identifiable {
    let id: String
    let name: String
    let devicePath: String
    let totalSize: Int64
    let freeSize: Int64
    let volumeUUID: String
    
    var usedSize: Int64 {
        return totalSize - freeSize
    }
}
