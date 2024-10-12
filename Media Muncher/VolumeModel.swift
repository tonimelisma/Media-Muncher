import Foundation

/// `Volume` represents a storage volume in the system.
struct Volume: Identifiable, Equatable {
    /// The unique identifier of the volume.
    let id: String
    
    /// The name of the volume.
    let name: String
    
    /// The file system path to the volume.
    let devicePath: String
    
    /// The total size of the volume in bytes.
    let totalSize: Int64
    
    /// The available free space on the volume in bytes.
    let freeSize: Int64
    
    /// The UUID of the volume.
    let volumeUUID: String
    
    /// The used space on the volume in bytes.
    var usedSize: Int64 {
        return totalSize - freeSize
    }
    
    /// Compares two `Volume` instances for equality.
    /// - Parameters:
    ///   - lhs: The left-hand side `Volume` instance.
    ///   - rhs: The right-hand side `Volume` instance.
    /// - Returns: `true` if the volumes are equal, `false` otherwise.
    static func == (lhs: Volume, rhs: Volume) -> Bool {
        return lhs.id == rhs.id
    }
}
