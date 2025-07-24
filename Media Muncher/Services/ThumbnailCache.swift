//
//  ThumbnailCache.swift
//  Media Muncher
//
//  Actor responsible for generating and caching QuickLook thumbnails off the main thread.
//

import Foundation
import SwiftUI
import QuickLookThumbnailing

// MARK: - Environment Key

private struct ThumbnailCacheKey: EnvironmentKey {
    static let defaultValue: ThumbnailCache = ThumbnailCache()
}

extension EnvironmentValues {
    var thumbnailCache: ThumbnailCache {
        get { self[ThumbnailCacheKey.self] }
        set { self[ThumbnailCacheKey.self] = newValue }
    }
}

/// Actor-based thumbnail cache with dual storage (Data + Image) and unified LRU eviction.
/// All heavy QuickLook work happens inside the actor, keeping the UI thread smooth.
/// Provides both JPEG data for File model compatibility and SwiftUI Images for direct UI use.
actor ThumbnailCache {
    private var dataCache: [String: Data] = [:]
    private var imageCache: [String: Image] = [:]
    private var accessOrder: [String] = []   // Unified LRU order for both caches
    private let limit: Int

    init(limit: Int = Constants.thumbnailCacheLimit) {
        self.limit = limit
    }

    /// Returns cached thumbnail data for the url or generates it on demand.
    /// - Parameters:
    ///   - url: File url to create thumbnail for.
    ///   - size: Pixel size (defaults 256×256).
    /// - Returns: JPEG image data (80% quality) or nil if generation failed.
    func thumbnailData(for url: URL, size: CGSize = CGSize(width: 256, height: 256)) async -> Data? {
        let key = url.path
        
        if let cached = dataCache[key] {
            updateAccessOrder(key: key)
            return cached
        }

        // Generate new thumbnail data
        guard let data = await generateThumbnailData(url: url, size: size) else {
            return nil
        }
        
        storeThumbnail(key: key, data: data)
        return data
    }

    /// Returns cached thumbnail image for the url or generates it on demand.
    /// This method eliminates Data→Image conversion in the UI layer.
    /// - Parameters:
    ///   - url: File url to create thumbnail for.
    ///   - size: Pixel size (defaults 256×256).
    /// - Returns: SwiftUI Image or nil if generation failed.
    func thumbnailImage(for url: URL, size: CGSize = CGSize(width: 256, height: 256)) async -> Image? {
        let key = url.path
        
        // Check image cache first for optimal performance
        if let cached = imageCache[key] {
            updateAccessOrder(key: key)
            return cached
        }
        
        // Get data (from cache or generate)
        guard let data = await thumbnailData(for: url, size: size) else {
            return nil
        }
        
        // Convert to Image and cache
        guard let nsImage = NSImage(data: data) else {
            return nil
        }
        
        let image = Image(nsImage: nsImage)
        imageCache[key] = image
        updateAccessOrder(key: key)
        
        return image
    }

    /// Purges the entire cache (testing / memory-pressure).
    func clear() {
        dataCache.removeAll()
        imageCache.removeAll()
        accessOrder.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Generates thumbnail data using QuickLook framework
    private func generateThumbnailData(url: URL, size: CGSize) async -> Data? {
        let request = QLThumbnailGenerator.Request(fileAt: url,
                                                   size: size,
                                                   scale: NSScreen.main?.backingScaleFactor ?? 1.0,
                                                   representationTypes: .all)
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        
        // Convert NSImage to JPEG data for thread-safe storage with efficient compression
        guard let tiffData = rep.nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        
        return jpegData
    }
    
    /// Stores thumbnail data and updates access order
    private func storeThumbnail(key: String, data: Data) {
        dataCache[key] = data
        updateAccessOrder(key: key)
        enforceLimit()
    }
    
    /// Updates the LRU access order for a key
    private func updateAccessOrder(key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    /// Enforces cache size limit by evicting oldest entries from both caches
    private func enforceLimit() {
        while accessOrder.count > limit {
            if let oldest = accessOrder.first {
                accessOrder.removeFirst()
                dataCache.removeValue(forKey: oldest)
                imageCache.removeValue(forKey: oldest)
            }
        }
    }
} 