import Foundation

struct DestinationPathBuilder {
    /// Normalises extension (e.g. jpeg → jpg)
    static func preferredFileExtension(_ ext: String) -> String {
        let e = ext.lowercased()
        switch e {
        case "jpeg":
            return "jpg"
        default:
            return e
        }
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
            let prefix: String
            switch file.mediaType {
            case .video: prefix = "VID"
            case .audio: prefix = "AUD"
            default: prefix = "IMG"
            }
            base = String(format: "%@_%04d%02d%02d_%02d%02d%02d", prefix, y, mo, d, h, mi, s)
        } else {
            base = file.filenameWithoutExtension
        }

        let ext = preferredFileExtension(file.fileExtension)
        return directory + base + "." + ext
    }
} 