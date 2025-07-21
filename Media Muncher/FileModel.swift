//
//  FileModel.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/17/25.
//

import Foundation
import SwiftUI

enum MediaType: String {
    case audio, video, image, raw, unknown
    
    static func from(filePath: String) -> MediaType {
        let validExtensions: [String: MediaType] = [
            // Audio (from PRD)
            "mp3": .audio, "wav": .audio, "aac": .audio,

            // Video (from PRD)
            "mp4": .video, "avi": .video, "mov": .video, "wmv": .video,
            "flv": .video, "mkv": .video, "webm": .video, "ogv": .video, 
            "m4v": .video, "3gp": .video, "3g2": .video, "asf": .video, 
            "vob": .video, "mts": .video, "m2ts": .video, "braw": .video, 
            "r3d": .video, "ari": .video,

            // Images (from PRD)
            "jpg": .image, "jpeg": .image, "jpe": .image, "jif": .image,
            "jfif": .image, "jfi": .image, "jp2": .image, "j2k": .image, 
            "jpf": .image, "jpm": .image, "jpg2": .image, "j2c": .image, 
            "jpc": .image, "jpx": .image, "mj2": .image, "jxl": .image, 
            "png": .image, "gif": .image, "bmp": .image, "tiff": .image,
            "tif": .image, "psd": .image, "eps": .image, "svg": .image,
            "ico": .image, "webp": .image, "heif": .image, "heifs": .image, 
            "heic": .image, "heics": .image, "avci": .image, "avcs": .image, 
            "hif": .image,

            // RAW (from PRD) 
            "arw": .raw, "cr2": .raw, "cr3": .raw, "crw": .raw, "dng": .raw, 
            "erf": .raw, "kdc": .raw, "mrw": .raw, "nef": .raw, "orf": .raw, 
            "pef": .raw, "raf": .raw, "raw": .raw, "rw2": .raw, "sr2": .raw, 
            "srf": .raw, "x3f": .raw,
        ]
        let ext = (filePath as NSString).pathExtension.lowercased()
        return validExtensions[ext] ?? .unknown
    }
}

enum FileStatus: String {
    case waiting, pre_existing, copying, verifying, imported, failed, duplicate_in_source, deleted_as_duplicate, imported_with_deletion_error
}

struct File: Identifiable, Sendable {
    var id: String {
        sourcePath
    }
    let sourcePath: String
    var sourceName: String {
        (sourcePath as NSString).lastPathComponent
    }
    var filenameWithoutExtension: String {
        (sourceName as NSString).deletingPathExtension
    }
    var fileExtension: String {
        (sourceName as NSString).pathExtension
    }
    var mediaType: MediaType
    var date: Date?
    var size: Int64?
    var destPath: String?
    var status: FileStatus
    nonisolated(unsafe) var thumbnail: Image?
    var importError: String?
    var duplicateOf: String? // ID of the file this one is a duplicate of
    var sidecarPaths: [String] = []
}

extension MediaType {
    /// Returns an appropriate SF Symbol name for the given media type so the UI can render a context-specific icon.
    var sfSymbolName: String {
        switch self {
        case .image:
            return "photo.fill.on.rectangle.fill"
        case .video:
            return "video.fill"
        case .audio:
            return "music.note"
        case .raw:
            return "camera.fill"
        case .unknown:
            return "questionmark.app"
        }
    }
}
