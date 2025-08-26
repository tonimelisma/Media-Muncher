//
//  BookmarkStore.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Foundation

/// Utility responsible for creating and resolving (security-scoped) bookmarks.
/// This type is intentionally lightweight and synchronous.
struct BookmarkStore {
    func createBookmark(for url: URL, securityScoped: Bool = true) throws -> Data {
        let options: URL.BookmarkCreationOptions = securityScoped ? [.withSecurityScope] : []
        return try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Attempts to resolve a bookmark and reports staleness.
    /// - Returns: `(url, stale)` where `url` is non-nil only when resolution succeeds and is not stale.
    func resolveBookmark(_ data: Data) -> (url: URL?, stale: Bool) {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (isStale ? nil : url, isStale)
        } catch {
            return (nil, false)
        }
    }
}
