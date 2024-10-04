import Foundation

struct Volume: Identifiable, Equatable {
    let id: String
    let name: String
    let devicePath: String
    let totalSize: Int64
    let freeSize: Int64
    let volumeUUID: String
    
    var usedSize: Int64 {
        return totalSize - freeSize
    }
    
    static func == (lhs: Volume, rhs: Volume) -> Bool {
        return lhs.id == rhs.id
    }
}
