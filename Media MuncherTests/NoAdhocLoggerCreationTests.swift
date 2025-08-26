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

        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            // Allow AppContainer to construct the single shared logger
            if url.lastPathComponent == "AppContainer.swift" { continue }
            guard let contents = try? String(contentsOf: url) else { continue }
            if contents.contains("LogManager(") {
                offenders.append(url.lastPathComponent)
            }
        }

        XCTAssertTrue(offenders.isEmpty, "Unexpected LogManager() creation in: \(offenders)")
    }
}

