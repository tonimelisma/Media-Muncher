import Foundation
import zlib

struct MediaFile: Identifiable, Equatable {
    let id = UUID()
    let sourcePath: String
    let sourceName: String
    let size: Int64
    let mediaType: MediaType
    let timeTaken: Date
    var destinationPath: String?
    var destinationName: String?
    var sourceCRC32: UInt32?
    var destinationCRC32: UInt32?
    var isImported: Bool = false

    static func == (lhs: MediaFile, rhs: MediaFile) -> Bool {
        return lhs.id == rhs.id
    }

    func calculateCRC32(forPath path: String) -> UInt32? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return data.withUnsafeBytes { bufferPointer in
            let unsafeBufferPointer = bufferPointer.bindMemory(to: UInt8.self)
            return UInt32(zlib.crc32(0, unsafeBufferPointer.baseAddress, UInt32(unsafeBufferPointer.count)))
        }
    }
}

enum MediaType: Equatable {
    // Processed Pictures
    case jpeg, jpeg2000, jpegXL, png, gif, bmp, tiff, psd, eps, svg, ico, webp, heif
    
    // Raw Pictures
    case raw(format: RawFormat)
    
    // Videos
    case mp4, avi, mov, wmv, flv, mkv, webm, ogv, m4v, threegp, threeg2, asf, vob, mts
    
    // Raw Videos
    case rawVideo(format: RawVideoFormat)
    
    // Audio
    case mp3, wav, ogg, flac, aac, m4a, wma, amr, ac3, dts, alac, ape, shn, tta
    
    var category: MediaCategory {
        switch self {
        case .jpeg, .jpeg2000, .jpegXL, .png, .gif, .bmp, .tiff, .psd, .eps, .svg, .ico, .webp, .heif:
            return .processedPicture
        case .raw:
            return .rawPicture
        case .mp4, .avi, .mov, .wmv, .flv, .mkv, .webm, .ogv, .m4v, .threegp, .threeg2, .asf, .vob, .mts:
            return .video
        case .rawVideo:
            return .rawVideo
        case .mp3, .wav, .ogg, .flac, .aac, .m4a, .wma, .amr, .ac3, .dts, .alac, .ape, .shn, .tta:
            return .audio
        }
    }
}

enum MediaCategory {
    case processedPicture
    case rawPicture
    case video
    case rawVideo
    case audio
}

enum RawFormat: String {
    case arw, cr2, cr3, crw, dng, erf, kdc, mrw, nef, orf, pef, raf, raw, rw2, sr2, srf, x3f
}

enum RawVideoFormat: String {
    case braw, r3d, arriraw
}

enum ImportError: Error {
    case integrityCheckFailed(fileName: String)
    case partialFailure(errors: [Error])
}

enum ImportState: Equatable {
    case idle
    case inProgress
    case completed
    case cancelled
    case failed(error: Error)
    
    static func == (lhs: ImportState, rhs: ImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.inProgress, .inProgress), (.completed, .completed), (.cancelled, .cancelled):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}
