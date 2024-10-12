import Foundation
import AVFoundation
import ImageIO

class MediaMetadataExtractor {
    static func extractCreationDateTime(from fileURL: URL, mediaType: MediaType, fallbackDate: Date) async -> Date {
        switch mediaType.category {
        case .audio, .video, .rawVideo:
            return await extractAudioVideoCreationDateTime(from: fileURL, fallbackDate: fallbackDate)
        case .processedPicture, .rawPicture:
            return await extractPictureCreationDateTime(from: fileURL, fallbackDate: fallbackDate)
        }
    }
    
    private static func extractAudioVideoCreationDateTime(from fileURL: URL, fallbackDate: Date) async -> Date {
        do {
            let asset = AVURLAsset(url: fileURL)
            let metadata = try await asset.load(.metadata)
            
            // Array of potential metadata keys for creation date (all as strings)
            let creationDateKeys = [
                AVMetadataKey.id3MetadataKeyDate.rawValue,
                AVMetadataKey.commonKeyCreationDate.rawValue,
                AVMetadataKey.isoUserDataKeyDate.rawValue,
                AVMetadataKey.commonKeyLastModifiedDate.rawValue,
                AVMetadataKey.id3MetadataKeyRecordingDates.rawValue,
                AVMetadataKey.iTunesMetadataKeyReleaseDate.rawValue,
                AVMetadataKey.quickTimeMetadataKeyCreationDate.rawValue,
                AVMetadataKey.quickTimeMetadataKeyLocationDate.rawValue,
                AVMetadataKey.quickTimeUserDataKeyCreationDate.rawValue,
                "com.apple.quicktime.creationdate",
                "creation_time"
            ]
            
            // Try to find a valid date using the keys
            for key in creationDateKeys {
                if let dateValue = try await getDateTime(from: metadata, for: key) {
                    print("MediaMetadataExtractor: Metadata key used for date: \(key)")
                    return dateValue
                }
            }
            
            print("MediaMetadataExtractor: No metadata date found, using fallback date")
            return fallbackDate
        } catch {
            print("MediaMetadataExtractor: Error extracting metadata: \(error)")
            return fallbackDate
        }
    }
    
    private static func extractPictureCreationDateTime(from fileURL: URL, fallbackDate: Date) async -> Date {
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            print("MediaMetadataExtractor: Unable to create image source for \(fileURL.lastPathComponent)")
            return fallbackDate
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            print("MediaMetadataExtractor: Unable to get image properties for \(fileURL.lastPathComponent)")
            return fallbackDate
        }
        
        let exifDictionary = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiffDictionary = imageProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        
        // Check EXIF date
        if let dateTimeOriginal = exifDictionary?[kCGImagePropertyExifDateTimeOriginal as String] as? String,
           let date = parseDateTime(dateTimeOriginal) {
            print("MediaMetadataExtractor: Using EXIF DateTimeOriginal for \(fileURL.lastPathComponent)")
            return date
        }
        
        // Check TIFF date
        if let dateTime = tiffDictionary?[kCGImagePropertyTIFFDateTime as String] as? String,
           let date = parseDateTime(dateTime) {
            print("MediaMetadataExtractor: Using TIFF DateTime for \(fileURL.lastPathComponent)")
            return date
        }
        
        // If no metadata date found, use fallback date
        print("MediaMetadataExtractor: No metadata date found for \(fileURL.lastPathComponent), using fallback date")
        return fallbackDate
    }
    
    // Helper function to extract date and time from metadata
    private static func getDateTime(from metadata: [AVMetadataItem], for key: String) async throws -> Date? {
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .init(rawValue: key))
        if let item = items.first {
            if let date = try await item.load(.dateValue) {
                return date
            } else if let stringValue = try await item.load(.stringValue) {
                return parseDateTime(stringValue)
            }
        }
        return nil
    }
    
    // Helper function to parse date and time strings
    private static func parseDateTime(_ dateTimeString: String) -> Date? {
        let dateFormatters = [
            "yyyy:MM:dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy:MM:dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "EEE MMM dd HH:mm:ss yyyy",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyyMMddHHmmss",
        ].map { format -> DateFormatter in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateTimeString) {
                return date
            }
        }
        
        print("MediaMetadataExtractor: Unable to parse date string: \(dateTimeString)")
        return nil
    }
}
