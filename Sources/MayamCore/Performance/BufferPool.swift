// SPDX-License-Identifier: (see LICENSE)
// Mayam — Reusable ByteBuffer Pool

import NIOCore

/// A pool of reusable `ByteBuffer` instances that reduces allocation overhead
/// in high-throughput DICOM association pipelines.
///
/// `BufferPool` maintains an internal free-list of pre-allocated byte buffers.
/// Callers acquire a buffer, write into it, and return it when finished. This
/// avoids the cost of repeatedly allocating and deallocating memory during
/// sustained C-STORE or C-FIND traffic.
///
/// ## Usage
///
/// ```swift
/// let pool = BufferPool(allocator: channel.allocator, capacity: 64)
/// var buffer = pool.acquire(minimumCapacity: 16_384)
/// buffer.writeBytes(data)
/// // … send buffer …
/// pool.release(&buffer)
/// ```
///
/// > Concurrency: `BufferPool` is implemented as an actor to ensure thread-safe
/// > access from multiple NIO event loops.
///
/// Reference: Milestone 14 — Performance Optimisation & Benchmarking
public actor BufferPool {

    // MARK: - Stored Properties

    /// The NIO allocator used to create new buffers when the pool is empty.
    private let allocator: ByteBufferAllocator

    /// Maximum number of buffers retained in the pool.
    private let capacity: Int

    /// Free-list of reusable buffers.
    private var freeList: [ByteBuffer] = []

    /// Total number of buffers acquired since the pool was created.
    private var acquireCount: Int = 0

    /// Total number of buffers returned to the pool.
    private var releaseCount: Int = 0

    /// Number of times a new buffer had to be allocated (pool miss).
    private var missCount: Int = 0

    // MARK: - Initialiser

    /// Creates a new buffer pool.
    ///
    /// - Parameters:
    ///   - allocator: The NIO byte buffer allocator.
    ///   - capacity: Maximum number of buffers to keep in the pool (default: 64).
    public init(allocator: ByteBufferAllocator = ByteBufferAllocator(), capacity: Int = 64) {
        self.allocator = allocator
        self.capacity = max(1, capacity)
    }

    // MARK: - Public Methods

    /// Acquires a buffer from the pool, or allocates a new one if the pool
    /// is empty.
    ///
    /// The returned buffer's reader and writer indices are reset to zero.
    ///
    /// - Parameter minimumCapacity: The minimum writable capacity required.
    /// - Returns: A `ByteBuffer` ready for writing.
    public func acquire(minimumCapacity: Int = 4096) -> ByteBuffer {
        acquireCount += 1

        if var buffer = freeList.popLast() {
            buffer.clear()
            if buffer.capacity < minimumCapacity {
                buffer.reserveCapacity(minimumCapacity)
            }
            return buffer
        }

        missCount += 1
        return allocator.buffer(capacity: minimumCapacity)
    }

    /// Returns a buffer to the pool for reuse.
    ///
    /// If the pool is at capacity, the buffer is discarded.
    ///
    /// - Parameter buffer: The buffer to return. Its contents are cleared.
    public func release(_ buffer: inout ByteBuffer) {
        releaseCount += 1
        buffer.clear()

        if freeList.count < capacity {
            freeList.append(buffer)
        }
    }

    /// Returns statistics about pool usage.
    ///
    /// - Returns: A ``BufferPoolStatistics`` snapshot.
    public func statistics() -> BufferPoolStatistics {
        BufferPoolStatistics(
            poolSize: freeList.count,
            capacity: capacity,
            acquireCount: acquireCount,
            releaseCount: releaseCount,
            missCount: missCount,
            hitRate: acquireCount > 0
                ? Double(acquireCount - missCount) / Double(acquireCount)
                : 0.0
        )
    }

    /// Drains all buffers from the pool, releasing their memory.
    public func drain() {
        freeList.removeAll()
    }
}

// MARK: - BufferPoolStatistics

/// A snapshot of buffer pool usage counters.
public struct BufferPoolStatistics: Sendable, Equatable {

    /// Current number of buffers in the pool.
    public let poolSize: Int

    /// Maximum pool capacity.
    public let capacity: Int

    /// Total number of `acquire()` calls.
    public let acquireCount: Int

    /// Total number of `release()` calls.
    public let releaseCount: Int

    /// Number of times a new allocation was required (pool miss).
    public let missCount: Int

    /// Fraction of acquires served from the pool (0.0–1.0).
    public let hitRate: Double

    /// Creates a new statistics snapshot.
    public init(
        poolSize: Int,
        capacity: Int,
        acquireCount: Int,
        releaseCount: Int,
        missCount: Int,
        hitRate: Double
    ) {
        self.poolSize = poolSize
        self.capacity = capacity
        self.acquireCount = acquireCount
        self.releaseCount = releaseCount
        self.missCount = missCount
        self.hitRate = hitRate
    }
}
