import Foundation

enum AppError: Error, LocalizedError {
    case destinationNotWritable(path: String)
    case scanFailed(reason: String)
    case importFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .destinationNotWritable(let path):
            return "Destination folder is not writable at path: \(path)"
        case .scanFailed(let reason):
            return "Failed to scan for media: \(reason)"
        case .importFailed(let reason):
            return "Failed to import files: \(reason)"
        }
    }
} 