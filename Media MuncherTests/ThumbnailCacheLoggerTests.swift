import XCTest
@testable import Media_Muncher

final class ThumbnailCacheLoggerTests: XCTestCase {
    func testThumbnailCacheUsesInjectedLogger() async throws {
        let mock = MockLogManager()
        let cache = ThumbnailCache(limit: 4, logManager: mock)
        let fakeURL = URL(fileURLWithPath: "/path/does/not/exist_\(UUID().uuidString).jpg")

        // Act: request thumbnail for a non-existent file (should log debug messages and return nil)
        let data = await cache.thumbnailData(for: fakeURL)

        // Assert: no data for invalid path and logs captured via injected mock logger
        XCTAssertNil(data)
        let calls = await mock.getCalls()
        XCTAssertFalse(calls.isEmpty, "Expected ThumbnailCache to log via injected logger")
        // Sanity check: at least one of the calls should come from our TestDebugging category
        XCTAssertTrue(calls.contains(where: { $0.category == "TestDebugging" }))
    }
}

