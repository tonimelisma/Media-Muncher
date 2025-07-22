//
//  ThumbnailCache.swift
//  Media Muncher
//
//  Actor responsible for generating and caching QuickLook thumbnails off the main thread.
//

import Foundation
import SwiftUI
import QuickLookThumbnailing

/// Actor-based thumbnail cache with LRU eviction.
/// All heavy QuickLook work happens inside the actor, keeping the UI thread smooth.
actor ThumbnailCache {
    private var cache: [String: Image] = [:]
    private var order: [String] = []   // Least-recently-used order
    private let limit: Int

    init(limit: Int = Constants.thumbnailCacheLimit) {
        self.limit = limit
    }

    /// Returns a cached thumbnail for the url or generates one on demand.
    /// - Parameters:
    ///   - url: File url to create thumbnail for.
    ///   - size: Pixel size (defaults 256×256).
    /// - Returns: SwiftUI Image or nil if generation failed.
    func thumbnail(for url: URL, size: CGSize = CGSize(width: 256, height: 256)) async -> Image? {
        let key = url.path
        if let cached = cache[key] {
            // Move key to most-recent position.
            order.removeAll { $0 == key }
            order.append(key)
            return cached
        }

        let request = QLThumbnailGenerator.Request(fileAt: url,
                                                   size: size,
                                                   scale: NSScreen.main?.backingScaleFactor ?? 1.0,
                                                   representationTypes: .all)
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        let img = Image(nsImage: rep.nsImage)
        cache[key] = img
        order.append(key)
        // Evict if necessary
        if order.count > limit, let oldest = order.first {
            order.removeFirst()
            cache.removeValue(forKey: oldest)
        }
        return img
    }

    /// Purges the entire cache (testing / memory-pressure).
    func clear() {
        cache.removeAll()
        order.removeAll()
    }
} 