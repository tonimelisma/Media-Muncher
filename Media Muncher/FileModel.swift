//
//  FileModel.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/17/25.
//

import Foundation

enum MediaType: String {
    case audio, video, image, unknown
}

enum FileStatus: String {
    case waiting, pre_existing, failed, copied
}

struct File: Identifiable {
    var id: String {
        sourcePath
    }
    let sourcePath: String
    var sourceName: String {
        (sourcePath as NSString).lastPathComponent
    }
    var mediaType: MediaType
    var date: Date?
    var size: Int64?
    var destDirectory: String?
    var destFilename: String?
    var destPath: String? {
        guard let destDirectory = destDirectory, let destFilename = destFilename
        else {
            return nil
        }
        return destDirectory + "/" + destFilename
    }
    var status: FileStatus
}

func determineMediaType(for filePath: String) -> MediaType {
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

func preferredFileExtension(for ext: String) -> String {
    let extensionMapping: [String: String] = [
        "jpeg": "jpg", "jpe": "jpg", "jif": "jpg", "jfif": "jpg", "jfi": "jpg",
        "jp2": "jp2", "j2k": "jp2", "jpf": "jp2", "jpm": "jp2", "jpg2": "jp2",
        "j2c": "jp2", "jpc": "jp2", "jpx": "jp2", "mj2": "jp2", "tif": "tiff",
        "heifs": "heif", "heic": "heif", "heics": "heif", "avci": "heif",
        "avcs": "heif",
        "hif": "heif",
    ]
    return extensionMapping[ext.lowercased()] ?? ext.lowercased()
}
