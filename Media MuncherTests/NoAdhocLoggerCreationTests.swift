import XCTest

final class NoAdhocLoggerCreationTests: XCTestCase {
    func testNoAdhocLogManagerCreationInProductionCode() throws {
        // Enumerate all Swift files under the production source directory
        let fm = FileManager.default
        let repoRoot = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
        let srcDir = repoRoot.appendingPathComponent("Media Muncher")

        var offenders: [String] = []

        guard let enumerator = fm.enumerator(at: srcDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            XCTFail("Failed to enumerate source directory: \(srcDir.path)")
            return
        }

        // Regex patterns capturing different construction forms
        // - direct:   let x = LogManager()
        // - default:  logManager: Logging = LogManager()
        // - inferred: let x: LogManager = .init()
        let patterns: [String] = [
            #"\bLogManager\s*\("#,           // direct constructor call
            #"[:=]\s*LogManager\s*=\s*\.init\s*\("#, // type-inferred .init()
            #"[:=]\s*LogManager\s*\("#       // parameter default LogManager()
        ]

        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            // Allow AppContainer to construct the single shared logger
            if url.lastPathComponent == "AppContainer.swift" { continue }
            guard let contents = try? String(contentsOf: url) else { continue }
            for pattern in patterns {
                if contents.range(of: pattern, options: .regularExpression) != nil {
                    offenders.append(url.lastPathComponent)
                    break
                }
            }
        }

        XCTAssertTrue(offenders.isEmpty, "Unexpected LogManager construction in: \(offenders)")
    }
}
