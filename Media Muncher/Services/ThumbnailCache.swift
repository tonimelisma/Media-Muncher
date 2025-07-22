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
    private var cache: [String: Data] = [:]
    private var order: [String] = []   // Least-recently-used order
    private let limit: Int

    init(limit: Int = Constants.thumbnailCacheLimit) {
        self.limit = limit
    }

    /// Returns cached thumbnail data for the url or generates it on demand.
    /// - Parameters:
    ///   - url: File url to create thumbnail for.
    ///   - size: Pixel size (defaults 256×256).
    /// - Returns: PNG image data or nil if generation failed.
    func thumbnailData(for url: URL, size: CGSize = CGSize(width: 256, height: 256)) async -> Data? {
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
        
        // Convert NSImage to PNG data for thread-safe storage
        guard let tiffData = rep.nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        cache[key] = pngData
        order.append(key)
        // Evict if necessary
        if order.count > limit, let oldest = order.first {
            order.removeFirst()
            cache.removeValue(forKey: oldest)
        }
        return pngData
    }

    /// Legacy method for backwards compatibility - converts data to Image
    func thumbnail(for url: URL, size: CGSize = CGSize(width: 256, height: 256)) async -> Image? {
        guard let data = await thumbnailData(for: url, size: size) else {
            return nil
        }
        return NSImage(data: data).map(Image.init)
    }

    /// Purges the entire cache (testing / memory-pressure).
    func clear() {
        cache.removeAll()
        order.removeAll()
    }
} 