//
//  FileModel.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/17/25.
//

import Foundation
import SwiftUI

enum MediaType: String {
    case audio, video, image, unknown
    
    static func from(filePath: String) -> MediaType {
        let validExtensions: [String: MediaType] = [
            // Audio
            "mp3": .audio, "wav": .audio, "aac": .audio,

            // Video
            "mp4": .video, "avi": .video, "mov": .video, "wmv": .video,
            "flv": .video,
            "mkv": .video, "webm": .video, "ogv": .video, "m4v": .video,
            "3gp": .video,
            "3g2": .video, "asf": .video, "vob": .video, "mts": .video,
            "m2ts": .video,
            "braw": .video, "r3d": .video, "ari": .video,

            // Images
            "jpg": .image, "jpeg": .image, "jpe": .image, "jif": .image,
            "jfif": .image,
            "jfi": .image, "jp2": .image, "j2k": .image, "jpf": .image,
            "jpm": .image,
            "jpg2": .image, "j2c": .image, "jpc": .image, "jpx": .image,
            "mj2": .image,
            "jxl": .image, "png": .image, "gif": .image, "bmp": .image,
            "tiff": .image,
            "tif": .image, "psd": .image, "eps": .image, "svg": .image,
            "ico": .image,
            "webp": .image, "heif": .image, "heifs": .image, "heic": .image,
            "heics": .image,
            "avci": .image, "avcs": .image, "hif": .image, "arw": .image,
            "cr2": .image,
            "cr3": .image, "crw": .image, "dng": .image, "erf": .image,
            "kdc": .image,
            "mrw": .image, "nef": .image, "orf": .image, "pef": .image,
            "raf": .image,
            "raw": .image, "rw2": .image, "sr2": .image, "srf": .image,
            "x3f": .image,
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
        case .unknown:
            return "questionmark.app"
        }
    }
}
