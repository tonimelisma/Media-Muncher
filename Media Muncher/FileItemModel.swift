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
    case jpeg
    case jpeg2000
    case jpegXL
    case png
    case gif
    case bmp
    case tiff
    case psd
    case eps
    case svg
    case ico
    case webp
    case heif
    
    // Raw Pictures
    case raw(format: RawFormat)
    
    // Videos
    case mp4
    case avi
    case mov
    case wmv
    case flv
    case mkv
    case webm
    case ogv
    case m4v
    case threegp
    case threeg2
    case asf
    case vob
    case mts
    
    // Raw Videos
    case rawVideo(format: RawVideoFormat)
    
    // Audio
    case mp3
    case wav
    case ogg
    case flac
    case aac
    case m4a
    case wma
    case amr
    case ac3
    case dts
    case alac
    case ape
    case shn
    case tta
    
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
    case arw
    case cr2
    case cr3
    case crw
    case dng
    case erf
    case kdc
    case mrw
    case nef
    case orf
    case pef
    case raf
    case raw
    case rw2
    case sr2
    case srf
    case x3f
}

enum RawVideoFormat: String {
    case braw
    case r3d
    case arriraw
}
