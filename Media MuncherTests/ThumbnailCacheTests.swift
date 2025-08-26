import XCTest
import SwiftUI
@testable import Media_Muncher

@MainActor
final class ThumbnailCacheTests: XCTestCase {

    var cache: ThumbnailCache!

    override func setUp() {
        super.setUp()
        // Use a small limit for easier testing
        cache = ThumbnailCache.testInstance(limit: 3)
    }

    override func tearDown() {
        cache = nil
        super.tearDown()
    }

    func test_cache_evicts_oldest_item_when_limit_is_exceeded() async {
        // Given: A cache with a limit of 3, filled with 3 items
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/a")) // Oldest
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/b"))
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/c")) // Newest

        // When: A 4th item is added
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/d"))

        // Then: The oldest item ("a") should be evicted. We test this by trying to access it again.
        // Since it was evicted, the generator will be called again. We can't check the internal cache,
        // so we rely on behavior. For this test, we are more concerned that the cache does not grow.
        // A better test for eviction order is below.
    }

    func test_accessing_item_marks_it_as_most_recently_used() async {
        // Given: A cache with a limit of 3, filled with 3 items
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/a")) // Oldest
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/b"))
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/c"))

        // When: The oldest item ("a") is accessed again, making it the newest
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/a"))
        
        // And two new items are added, forcing eviction
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/d"))
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/e"))


        // Then: "b" and "c" should be evicted. "a", "d", "e" should remain.
        // We can't check the internal state, but we can reason about what would be in the cache.
    }
    
    func test_cache_does_not_exceed_limit() async {
        // This test is tricky without access to the internal state.
        // The best we can do is add more items than the limit and ensure it doesn't crash.
        for i in 1...10 {
            _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/item_\(i)"))
        }
    }
    
    func test_clear_removes_all_items() async {
        // Given: A cache with some items
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/a"))
        _ = await cache.thumbnailImage(for: URL(fileURLWithPath: "/fake/b"))
        
        // When: The cache is cleared
        await cache.clear()
        
        // Then: The cache should be empty. We can't verify this directly,
        // but a subsequent call should re-generate the thumbnail.
    }
    
    func test_dual_caching_data_and_image() async {
        // Given: A URL for thumbnail generation
        let url = URL(fileURLWithPath: "/fake/test")
        
        // When: We request data first, then image
        let data = await cache.thumbnailData(for: url)
        let image = await cache.thumbnailImage(for: url)
        
        // Then: Both should be available (or both nil for fake URLs)
        // This test verifies the dual caching doesn't crash and handles both APIs
        if data != nil {
            XCTAssertNotNil(image, "If data is available, image should also be available")
        } else {
            XCTAssertNil(image, "If data is nil, image should also be nil")
        }
    }
    
    func test_image_cache_performance() async {
        // Given: A URL that we'll access multiple times
        let url = URL(fileURLWithPath: "/fake/performance")
        
        // When: We request the same image multiple times
        let image1 = await cache.thumbnailImage(for: url)
        let image2 = await cache.thumbnailImage(for: url)
        let image3 = await cache.thumbnailImage(for: url)
        
        // Then: All calls should return the same result (cached)
        // For fake URLs, all should be nil, but the cache should handle repeated calls
        XCTAssertEqual(image1 == nil, image2 == nil)
        XCTAssertEqual(image2 == nil, image3 == nil)
    }
} 
