import Foundation

struct DestinationPathBuilder {
    /// Normalises extension (e.g. jpeg → jpg)
    static func preferredFileExtension(_ ext: String) -> String {
        let e = ext.lowercased()
        let extensionMapping: [String: String] = [
            "jpeg": "jpg", "jpe": "jpg", "jif": "jpg", "jfif": "jpg", "jfi": "jpg",
            "jp2": "jp2", "j2k": "jp2", "jpf": "jp2", "jpm": "jp2", "jpg2": "jp2",
            "j2c": "jp2", "jpc": "jp2", "jpx": "jp2", "mj2": "jp2", "tif": "tiff",
            "heifs": "heif", "heic": "heif", "heics": "heif", "avci": "heif",
            "avcs": "heif",
            "hif": "heif",
        ]
        return extensionMapping[e] ?? e
    }

    /// Returns the *relative* path (inside destination root) a file *should* have, **without** collision-resolution suffixes.
    /// This is deterministic and used by both MediaScanner (duplicate detection) and ImportService (first attempt).
    static func relativePath(for file: File, organizeByDate: Bool, renameByDate: Bool) -> String {
        // Decide directory component
        var directory = ""
        if organizeByDate, let date = file.date ?? Date(timeIntervalSince1970: 0) as Date? {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            let comps = cal.dateComponents([.year, .month], from: date)
            if let y = comps.year, let m = comps.month {
                directory = String(format: "%04d/%02d/", y, m)
            }
        }

        // Decide base filename
        let base: String
        if renameByDate, let date = file.date ?? Date(timeIntervalSince1970: 0) as Date? {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            let c = cal.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
            let y = c.year ?? 0, mo = c.month ?? 0, d = c.day ?? 0, h = c.hour ?? 0, mi = c.minute ?? 0, s = c.second ?? 0
            base = String(format: "%04d%02d%02d_%02d%02d%02d", y, mo, d, h, mi, s)
        } else {
            base = file.filenameWithoutExtension
        }

        let ext = preferredFileExtension(file.fileExtension)
        return directory + base + "." + ext
    }

    static func buildFinalDestinationUrl(
        for file: File,
        in rootURL: URL,
        settings: SettingsStore,
        suffix: Int? = nil
    ) -> URL {
        let relativePath = Self.relativePath(for: file, organizeByDate: settings.organizeByDate, renameByDate: settings.renameByDate)
        
        var idealURL = rootURL.appendingPathComponent(relativePath)
        
        if let suffix = suffix {
            let baseFilename = (idealURL.lastPathComponent as NSString).deletingPathExtension
            let fileExtension = idealURL.pathExtension
            let newFilename = "\(baseFilename)_\(suffix).\(fileExtension)"
            idealURL = idealURL.deletingLastPathComponent().appendingPathComponent(newFilename)
        }
        
        return idealURL
    }
} 