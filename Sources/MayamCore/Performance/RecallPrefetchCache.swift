// SPDX-License-Identifier: (see LICENSE)
// Mayam — HSM Recall Prefetch Cache

import Foundation

/// An LRU cache with prefetch hinting for optimising near-line recall
/// latency of HSM-migrated DICOM studies.
///
/// When a study on a near-line or archive tier is requested, recalling it
/// to online storage introduces latency. `RecallPrefetchCache` mitigates
/// this by:
///
/// 1. **Caching recently recalled studies** — keeping their online path
///    in memory so subsequent accesses are instantaneous.
/// 2. **Prefetch hinting** — when a study in a series is accessed, adjacent
///    studies (e.g. same patient or same accession) are prefetched
///    proactively into the cache.
/// 3. **LRU eviction** — the least-recently-used entries are evicted when
///    the cache reaches capacity.
///
/// ## Usage
///
/// ```swift
/// let cache = RecallPrefetchCache(maxEntries: 128, ttlSeconds: 3600)
/// if let cached = await cache.get(studyUID) {
///     return cached.onlinePath
/// }
/// // … perform actual recall …
/// await cache.put(studyUID, entry: RecallCacheEntry(…))
/// ```
///
/// Reference: Milestone 14 — Performance Optimisation & Benchmarking
public actor RecallPrefetchCache {

    // MARK: - Stored Properties

    /// Maximum number of entries in the cache.
    private let maxEntries: Int

    /// Time-to-live for cache entries, in seconds.
    private let ttlSeconds: TimeInterval

    /// The cache storage, keyed by Study Instance UID.
    private var entries: [String: RecallCacheEntry] = [:]

    /// Ordered list of keys for LRU eviction (most recent at the end).
    private var accessOrder: [String] = []

    /// Total cache hits since creation.
    private var hitCount: Int = 0

    /// Total cache misses since creation.
    private var missCount: Int = 0

    /// Prefetch hints: mapping from a study UID to related study UIDs
    /// that should be prefetched when the key study is accessed.
    private var prefetchHints: [String: Set<String>] = [:]

    /// Study UIDs that have been scheduled for prefetch.
    private var prefetchScheduled: Set<String> = []

    // MARK: - Initialiser

    /// Creates a new recall prefetch cache.
    ///
    /// - Parameters:
    ///   - maxEntries: Maximum number of cached entries (default: 128).
    ///   - ttlSeconds: Time-to-live for entries in seconds (default: 3600).
    public init(maxEntries: Int = 128, ttlSeconds: TimeInterval = 3600) {
        self.maxEntries = max(1, maxEntries)
        self.ttlSeconds = ttlSeconds
    }

    // MARK: - Public Methods

    /// Retrieves a cached recall entry for the given study.
    ///
    /// Returns `nil` if the entry does not exist or has expired.
    ///
    /// - Parameter studyInstanceUID: The Study Instance UID.
    /// - Returns: The cached entry, or `nil` if not found or expired.
    public func get(_ studyInstanceUID: String) -> RecallCacheEntry? {
        guard let entry = entries[studyInstanceUID] else {
            missCount += 1
            return nil
        }

        // Check TTL
        if Date().timeIntervalSince(entry.cachedAt) > ttlSeconds {
            evict(studyInstanceUID)
            missCount += 1
            return nil
        }

        hitCount += 1
        touchAccessOrder(studyInstanceUID)
        return entry
    }

    /// Stores a recall cache entry.
    ///
    /// If the cache is at capacity, the least-recently-used entry is evicted.
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID.
    ///   - entry: The recall cache entry to store.
    public func put(_ studyInstanceUID: String, entry: RecallCacheEntry) {
        // Evict LRU if at capacity
        if entries.count >= maxEntries && entries[studyInstanceUID] == nil {
            evictLRU()
        }

        entries[studyInstanceUID] = entry
        touchAccessOrder(studyInstanceUID)
    }

    /// Registers a prefetch hint: when `studyInstanceUID` is accessed,
    /// the `relatedUIDs` should be prefetched.
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The study that triggers prefetch.
    ///   - relatedUIDs: Study UIDs to prefetch.
    public func registerPrefetchHint(
        for studyInstanceUID: String,
        relatedUIDs: Set<String>
    ) {
        prefetchHints[studyInstanceUID] = relatedUIDs
    }

    /// Returns study UIDs that should be prefetched based on the given
    /// study access, and marks them as scheduled.
    ///
    /// - Parameter studyInstanceUID: The accessed study UID.
    /// - Returns: Set of study UIDs to prefetch (not already cached or scheduled).
    public func prefetchCandidates(for studyInstanceUID: String) -> Set<String> {
        guard let related = prefetchHints[studyInstanceUID] else {
            return []
        }

        let candidates = related.filter { uid in
            entries[uid] == nil && !prefetchScheduled.contains(uid)
        }

        for uid in candidates {
            prefetchScheduled.insert(uid)
        }

        return candidates
    }

    /// Marks a prefetch as completed for a study UID.
    ///
    /// - Parameter studyInstanceUID: The study UID that was prefetched.
    public func completePrefetch(_ studyInstanceUID: String) {
        prefetchScheduled.remove(studyInstanceUID)
    }

    /// Returns cache statistics.
    ///
    /// - Returns: A ``RecallCacheStatistics`` snapshot.
    public func statistics() -> RecallCacheStatistics {
        let total = hitCount + missCount
        return RecallCacheStatistics(
            entryCount: entries.count,
            maxEntries: maxEntries,
            hitCount: hitCount,
            missCount: missCount,
            hitRate: total > 0 ? Double(hitCount) / Double(total) : 0.0,
            prefetchScheduledCount: prefetchScheduled.count,
            prefetchHintCount: prefetchHints.count
        )
    }

    /// Evicts all expired entries from the cache.
    ///
    /// - Returns: The number of entries evicted.
    @discardableResult
    public func evictExpired() -> Int {
        let now = Date()
        var evictedCount = 0

        for (uid, entry) in entries {
            if now.timeIntervalSince(entry.cachedAt) > ttlSeconds {
                evict(uid)
                evictedCount += 1
            }
        }

        return evictedCount
    }

    /// Clears the entire cache.
    public func clear() {
        entries.removeAll()
        accessOrder.removeAll()
        prefetchScheduled.removeAll()
        hitCount = 0
        missCount = 0
    }

    // MARK: - Private Helpers

    /// Evicts the least-recently-used entry.
    private func evictLRU() {
        guard let oldest = accessOrder.first else { return }
        evict(oldest)
    }

    /// Evicts a specific entry.
    private func evict(_ studyInstanceUID: String) {
        entries.removeValue(forKey: studyInstanceUID)
        accessOrder.removeAll(where: { $0 == studyInstanceUID })
    }

    /// Moves a key to the end of the access order (most recently used).
    private func touchAccessOrder(_ studyInstanceUID: String) {
        accessOrder.removeAll(where: { $0 == studyInstanceUID })
        accessOrder.append(studyInstanceUID)
    }
}

// MARK: - RecallCacheEntry

/// A cached entry for a recalled study.
public struct RecallCacheEntry: Sendable, Equatable {

    /// The Study Instance UID.
    public let studyInstanceUID: String

    /// The online-tier file system path after recall.
    public let onlinePath: String

    /// The tier the study was recalled from.
    public let recalledFrom: StorageTier

    /// When the entry was cached.
    public let cachedAt: Date

    /// Recall duration in seconds (how long the recall took).
    public let recallDurationSeconds: TimeInterval

    /// Creates a recall cache entry.
    public init(
        studyInstanceUID: String,
        onlinePath: String,
        recalledFrom: StorageTier,
        cachedAt: Date = Date(),
        recallDurationSeconds: TimeInterval = 0
    ) {
        self.studyInstanceUID = studyInstanceUID
        self.onlinePath = onlinePath
        self.recalledFrom = recalledFrom
        self.cachedAt = cachedAt
        self.recallDurationSeconds = recallDurationSeconds
    }
}

// MARK: - RecallCacheStatistics

/// A snapshot of recall cache usage counters.
public struct RecallCacheStatistics: Sendable, Equatable {

    /// Current number of entries in the cache.
    public let entryCount: Int

    /// Maximum cache capacity.
    public let maxEntries: Int

    /// Total cache hits.
    public let hitCount: Int

    /// Total cache misses.
    public let missCount: Int

    /// Hit rate (0.0–1.0).
    public let hitRate: Double

    /// Number of studies currently scheduled for prefetch.
    public let prefetchScheduledCount: Int

    /// Number of registered prefetch hint mappings.
    public let prefetchHintCount: Int

    /// Creates a recall cache statistics snapshot.
    public init(
        entryCount: Int,
        maxEntries: Int,
        hitCount: Int,
        missCount: Int,
        hitRate: Double,
        prefetchScheduledCount: Int,
        prefetchHintCount: Int
    ) {
        self.entryCount = entryCount
        self.maxEntries = maxEntries
        self.hitCount = hitCount
        self.missCount = missCount
        self.hitRate = hitRate
        self.prefetchScheduledCount = prefetchScheduledCount
        self.prefetchHintCount = prefetchHintCount
    }
}
