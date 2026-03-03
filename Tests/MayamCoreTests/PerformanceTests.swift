// SPDX-License-Identifier: (see LICENSE)
// Mayam — Performance Component Tests

import XCTest
import NIOCore
@testable import MayamCore

// MARK: - BufferPool Tests

final class BufferPoolTests: XCTestCase {

    // MARK: - Initialisation

    func test_bufferPool_initialState_hasEmptyStatistics() async {
        let pool = BufferPool(capacity: 8)
        let stats = await pool.statistics()
        XCTAssertEqual(stats.poolSize, 0)
        XCTAssertEqual(stats.capacity, 8)
        XCTAssertEqual(stats.acquireCount, 0)
        XCTAssertEqual(stats.releaseCount, 0)
        XCTAssertEqual(stats.missCount, 0)
        XCTAssertEqual(stats.hitRate, 0.0)
    }

    // MARK: - Acquire / Release

    func test_bufferPool_acquire_returnsBuffer() async {
        let pool = BufferPool(capacity: 4)
        let buffer = await pool.acquire(minimumCapacity: 1024)
        XCTAssertGreaterThanOrEqual(buffer.capacity, 1024)
        XCTAssertEqual(buffer.readableBytes, 0)
    }

    func test_bufferPool_acquire_incrementsMissOnEmpty() async {
        let pool = BufferPool(capacity: 4)
        _ = await pool.acquire()
        let stats = await pool.statistics()
        XCTAssertEqual(stats.acquireCount, 1)
        XCTAssertEqual(stats.missCount, 1)
    }

    func test_bufferPool_releaseAndAcquire_reusesBuffer() async {
        let pool = BufferPool(capacity: 4)
        var buffer = await pool.acquire(minimumCapacity: 2048)
        buffer.writeStaticString("test")
        await pool.release(&buffer)

        let reused = await pool.acquire(minimumCapacity: 512)
        XCTAssertEqual(reused.readableBytes, 0) // Cleared on acquire
        let stats = await pool.statistics()
        XCTAssertEqual(stats.acquireCount, 2)
        XCTAssertEqual(stats.missCount, 1) // Only first acquire was a miss
        XCTAssertEqual(stats.releaseCount, 1)
    }

    func test_bufferPool_hitRate_calculatedCorrectly() async {
        let pool = BufferPool(capacity: 4)
        // First acquire: miss
        var buf1 = await pool.acquire()
        await pool.release(&buf1)
        // Second acquire: hit (reused from pool)
        _ = await pool.acquire()
        let stats = await pool.statistics()
        XCTAssertEqual(stats.hitRate, 0.5, accuracy: 0.01)
    }

    func test_bufferPool_release_discardsWhenAtCapacity() async {
        let pool = BufferPool(capacity: 2)
        var buf1 = await pool.acquire()
        var buf2 = await pool.acquire()
        var buf3 = await pool.acquire()
        await pool.release(&buf1)
        await pool.release(&buf2)
        await pool.release(&buf3) // Should be discarded
        let stats = await pool.statistics()
        XCTAssertEqual(stats.poolSize, 2)
        XCTAssertEqual(stats.releaseCount, 3)
    }

    func test_bufferPool_drain_clearsAllBuffers() async {
        let pool = BufferPool(capacity: 8)
        var buf1 = await pool.acquire()
        var buf2 = await pool.acquire()
        await pool.release(&buf1)
        await pool.release(&buf2)
        await pool.drain()
        let stats = await pool.statistics()
        XCTAssertEqual(stats.poolSize, 0)
    }

    func test_bufferPool_acquire_expandsBufferIfTooSmall() async {
        let pool = BufferPool(capacity: 4)
        var small = await pool.acquire(minimumCapacity: 64)
        await pool.release(&small)
        let large = await pool.acquire(minimumCapacity: 16384)
        XCTAssertGreaterThanOrEqual(large.capacity, 16384)
    }
}

// MARK: - BufferPoolStatistics Tests

final class BufferPoolStatisticsTests: XCTestCase {

    func test_bufferPoolStatistics_equatable() {
        let a = BufferPoolStatistics(poolSize: 4, capacity: 8, acquireCount: 10, releaseCount: 8, missCount: 2, hitRate: 0.8)
        let b = BufferPoolStatistics(poolSize: 4, capacity: 8, acquireCount: 10, releaseCount: 8, missCount: 2, hitRate: 0.8)
        XCTAssertEqual(a, b)
    }

    func test_bufferPoolStatistics_notEqual_differentValues() {
        let a = BufferPoolStatistics(poolSize: 4, capacity: 8, acquireCount: 10, releaseCount: 8, missCount: 2, hitRate: 0.8)
        let b = BufferPoolStatistics(poolSize: 5, capacity: 8, acquireCount: 10, releaseCount: 8, missCount: 2, hitRate: 0.8)
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - PerformanceProfiler Tests

final class PerformanceProfilerTests: XCTestCase {

    // MARK: - Measurement

    func test_performanceProfiler_measure_returnsPositiveDuration() {
        let result = PerformanceProfiler.measure("test-op") {
            _ = (0..<1000).reduce(0, +)
        }
        XCTAssertEqual(result.label, "test-op")
        XCTAssertEqual(result.iterations, 1)
        XCTAssertGreaterThan(result.totalDuration, 0)
    }

    func test_performanceProfiler_measure_multipleIterations() {
        let result = PerformanceProfiler.measure("multi", iterations: 5) {
            _ = (0..<100).reduce(0, +)
        }
        XCTAssertEqual(result.iterations, 5)
        XCTAssertEqual(result.durations.count, 5)
    }

    func test_performanceProfiler_measureAsync_returnsResult() async {
        let result = await PerformanceProfiler.measureAsync("async-op") {
            try? await Task.sleep(nanoseconds: 1_000)
        }
        XCTAssertEqual(result.label, "async-op")
        XCTAssertGreaterThan(result.totalDuration, 0)
    }

    // MARK: - Throughput

    func test_performanceProfiler_throughput_calculatesCorrectly() {
        let tp = PerformanceProfiler.throughput(bytes: 1_000_000, duration: 0.5)
        XCTAssertEqual(tp, 2_000_000, accuracy: 1.0)
    }

    func test_performanceProfiler_throughput_zeroDuration_returnsZero() {
        let tp = PerformanceProfiler.throughput(bytes: 1000, duration: 0)
        XCTAssertEqual(tp, 0)
    }

    // MARK: - Formatting

    func test_performanceProfiler_formatThroughput_gigabytes() {
        let result = PerformanceProfiler.formatThroughput(2_500_000_000)
        XCTAssertTrue(result.contains("GB/s"))
    }

    func test_performanceProfiler_formatThroughput_megabytes() {
        let result = PerformanceProfiler.formatThroughput(150_000_000)
        XCTAssertTrue(result.contains("MB/s"))
    }

    func test_performanceProfiler_formatThroughput_kilobytes() {
        let result = PerformanceProfiler.formatThroughput(50_000)
        XCTAssertTrue(result.contains("KB/s"))
    }

    func test_performanceProfiler_formatThroughput_bytes() {
        let result = PerformanceProfiler.formatThroughput(500)
        XCTAssertTrue(result.contains("B/s"))
    }

    func test_performanceProfiler_formatDuration_seconds() {
        let result = PerformanceProfiler.formatDuration(2.5)
        XCTAssertTrue(result.contains("s"))
    }

    func test_performanceProfiler_formatDuration_milliseconds() {
        let result = PerformanceProfiler.formatDuration(0.015)
        XCTAssertTrue(result.contains("ms"))
    }

    func test_performanceProfiler_formatDuration_microseconds() {
        let result = PerformanceProfiler.formatDuration(0.000_050)
        XCTAssertTrue(result.contains("µs"))
    }
}

// MARK: - ProfilingResult Tests

final class ProfilingResultTests: XCTestCase {

    func test_profilingResult_meanDuration() {
        let result = ProfilingResult(label: "test", durations: [1.0, 2.0, 3.0])
        XCTAssertEqual(result.meanDuration, 2.0, accuracy: 0.001)
    }

    func test_profilingResult_medianDuration_oddCount() {
        let result = ProfilingResult(label: "test", durations: [1.0, 3.0, 2.0])
        XCTAssertEqual(result.medianDuration, 2.0, accuracy: 0.001)
    }

    func test_profilingResult_medianDuration_evenCount() {
        let result = ProfilingResult(label: "test", durations: [1.0, 2.0, 3.0, 4.0])
        XCTAssertEqual(result.medianDuration, 2.5, accuracy: 0.001)
    }

    func test_profilingResult_minMax() {
        let result = ProfilingResult(label: "test", durations: [5.0, 1.0, 3.0])
        XCTAssertEqual(result.minDuration, 1.0)
        XCTAssertEqual(result.maxDuration, 5.0)
    }

    func test_profilingResult_standardDeviation() {
        let result = ProfilingResult(label: "test", durations: [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0])
        XCTAssertGreaterThan(result.standardDeviation, 0)
    }

    func test_profilingResult_emptyDurations() {
        let result = ProfilingResult(label: "empty", durations: [])
        XCTAssertEqual(result.meanDuration, 0)
        XCTAssertEqual(result.medianDuration, 0)
        XCTAssertEqual(result.minDuration, 0)
        XCTAssertEqual(result.maxDuration, 0)
        XCTAssertEqual(result.standardDeviation, 0)
    }

    func test_profilingResult_formattedSummary_containsLabel() {
        let result = ProfilingResult(label: "my-operation", durations: [0.1, 0.2])
        let summary = result.formattedSummary
        XCTAssertTrue(summary.contains("my-operation"))
        XCTAssertTrue(summary.contains("Mean:"))
        XCTAssertTrue(summary.contains("Median:"))
    }
}

// MARK: - ConcurrentStoreOptimiser Tests

final class ConcurrentStoreOptimiserTests: XCTestCase {

    func test_concurrentStoreOptimiser_initialState_canAcceptWrite() async {
        let logger = MayamLogger(label: "test.store")
        let optimiser = ConcurrentStoreOptimiser(maxInFlightBytes: 1024, logger: logger)
        let canWrite = await optimiser.canAcceptWrite()
        XCTAssertTrue(canWrite)
    }

    func test_concurrentStoreOptimiser_enqueueWrite_tracksInFlightBytes() async throws {
        let logger = MayamLogger(label: "test.store")
        let optimiser = ConcurrentStoreOptimiser(maxInFlightBytes: 1024, logger: logger)
        let data = Data(repeating: 0xAB, count: 256)
        try await optimiser.enqueueWrite(data: data, filePath: "/tmp/test.dcm")
        let inFlight = await optimiser.currentInFlightBytes()
        XCTAssertEqual(inFlight, 256)
    }

    func test_concurrentStoreOptimiser_enqueueWrite_backpressureWhenFull() async throws {
        let logger = MayamLogger(label: "test.store")
        let optimiser = ConcurrentStoreOptimiser(maxInFlightBytes: 100, logger: logger)
        // First write fills up the pipeline
        let data1 = Data(repeating: 0xAB, count: 100)
        try await optimiser.enqueueWrite(data: data1, filePath: "/tmp/test1.dcm")
        // Second write should trigger backpressure
        let data2 = Data(repeating: 0xCD, count: 50)
        do {
            try await optimiser.enqueueWrite(data: data2, filePath: "/tmp/test2.dcm")
            XCTFail("Expected backpressure error")
        } catch let error as ConcurrentStoreError {
            if case .backpressure = error {
                // Expected
            } else {
                XCTFail("Expected backpressure, got: \(error)")
            }
        }
    }

    func test_concurrentStoreOptimiser_flush_writesToDisk() async throws {
        let logger = MayamLogger(label: "test.store")
        let optimiser = ConcurrentStoreOptimiser(maxInFlightBytes: 1_000_000, logger: logger)
        let tmpDir = NSTemporaryDirectory() + "mayam_store_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        let data = Data(repeating: 0xCD, count: 512)
        let filePath = tmpDir + "/test_instance.dcm"
        try await optimiser.enqueueWrite(data: data, filePath: filePath)
        let flushed = try await optimiser.flush()
        XCTAssertEqual(flushed, 1)

        let stats = await optimiser.statistics()
        XCTAssertEqual(stats.totalWriteOps, 1)
        XCTAssertEqual(stats.totalBytesWritten, 512)
        XCTAssertEqual(stats.currentInFlightBytes, 0)

        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
        let written = try Data(contentsOf: URL(fileURLWithPath: filePath))
        XCTAssertEqual(written, data)
    }

    func test_concurrentStoreOptimiser_flush_emptyReturnsZero() async throws {
        let logger = MayamLogger(label: "test.store")
        let optimiser = ConcurrentStoreOptimiser(maxInFlightBytes: 1024, logger: logger)
        let flushed = try await optimiser.flush()
        XCTAssertEqual(flushed, 0)
    }

    func test_concurrentStoreOptimiser_reset_clearsState() async throws {
        let logger = MayamLogger(label: "test.store")
        let optimiser = ConcurrentStoreOptimiser(maxInFlightBytes: 1_000_000, logger: logger)
        let data = Data(repeating: 0xAB, count: 100)
        try await optimiser.enqueueWrite(data: data, filePath: "/tmp/test.dcm")
        await optimiser.reset()
        let stats = await optimiser.statistics()
        XCTAssertEqual(stats.currentInFlightBytes, 0)
        XCTAssertEqual(stats.totalBytesWritten, 0)
        XCTAssertEqual(stats.pendingCoalescedWrites, 0)
    }
}

// MARK: - WriteStatistics Tests

final class WriteStatisticsTests: XCTestCase {

    func test_writeStatistics_equatable() {
        let a = WriteStatistics(totalBytesWritten: 1000, totalWriteOps: 5, currentInFlightBytes: 100, maxInFlightBytes: 10000, pendingCoalescedWrites: 2)
        let b = WriteStatistics(totalBytesWritten: 1000, totalWriteOps: 5, currentInFlightBytes: 100, maxInFlightBytes: 10000, pendingCoalescedWrites: 2)
        XCTAssertEqual(a, b)
    }
}

// MARK: - ConcurrentStoreError Tests

final class ConcurrentStoreErrorTests: XCTestCase {

    func test_concurrentStoreError_backpressure_description() {
        let error = ConcurrentStoreError.backpressure(inFlightBytes: 500, maxInFlightBytes: 256)
        XCTAssertTrue(error.description.contains("saturated"))
    }

    func test_concurrentStoreError_writeFailed_description() {
        let error = ConcurrentStoreError.writeFailed(path: "/tmp/test.dcm", reason: "disk full")
        XCTAssertTrue(error.description.contains("disk full"))
        XCTAssertTrue(error.description.contains("/tmp/test.dcm"))
    }
}

// MARK: - QueryPlanOptimiser Tests

final class QueryPlanOptimiserTests: XCTestCase {

    // MARK: - Strategy Selection

    func test_queryPlanOptimiser_singleKey_usesIndexLookup() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .study,
            matchingKeys: ["StudyInstanceUID": "1.2.3.4"],
            returnKeys: []
        )
        XCTAssertEqual(plan.strategy, .indexLookup)
    }

    func test_queryPlanOptimiser_dateAndModality_usesCompositeIndex() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .study,
            matchingKeys: ["StudyDate": "20250101-20250301", "Modality": "CT"],
            returnKeys: []
        )
        XCTAssertEqual(plan.strategy, .compositeIndexScan)
    }

    func test_queryPlanOptimiser_wildcardPattern_usesWildcardRangeScan() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .patient,
            matchingKeys: ["PatientName": "SMITH*"],
            returnKeys: []
        )
        XCTAssertEqual(plan.strategy, .wildcardRangeScan)
    }

    // MARK: - Index Hints

    func test_queryPlanOptimiser_studyLevel_dateModality_hintsCompositeIndex() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .study,
            matchingKeys: ["StudyDate": "20250101", "Modality": "MR"],
            returnKeys: []
        )
        XCTAssertEqual(plan.indexHint, "idx_studies_date_modality_accession")
    }

    func test_queryPlanOptimiser_patientLevel_patientName_hintsNameIndex() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .patient,
            matchingKeys: ["PatientName": "DOE^JOHN"],
            returnKeys: []
        )
        XCTAssertEqual(plan.indexHint, "idx_patients_patient_name")
    }

    func test_queryPlanOptimiser_studyLevel_accession_hintsAccessionIndex() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .study,
            matchingKeys: ["AccessionNumber": "ACC12345"],
            returnKeys: []
        )
        XCTAssertEqual(plan.indexHint, "idx_studies_accession_patient")
    }

    // MARK: - Wildcard Optimisation

    func test_queryPlanOptimiser_trailingWildcard_rewrittenToRange() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .patient,
            matchingKeys: ["PatientName": "SMI*"],
            returnKeys: []
        )
        XCTAssertEqual(plan.wildcardRewrites.count, 1)
        let rewrite = plan.wildcardRewrites[0]
        XCTAssertEqual(rewrite.column, "patient_name")
        XCTAssertEqual(rewrite.lowerBound, "SMI")
        XCTAssertEqual(rewrite.upperBound, "SMJ")
    }

    func test_queryPlanOptimiser_leadingWildcard_notRewritten() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .patient,
            matchingKeys: ["PatientName": "*SMITH"],
            returnKeys: []
        )
        XCTAssertEqual(plan.wildcardRewrites.count, 0)
    }

    // MARK: - Date Range Optimisation

    func test_queryPlanOptimiser_dateRange_parsedCorrectly() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .study,
            matchingKeys: ["StudyDate": "20250101-20250331"],
            returnKeys: []
        )
        XCTAssertEqual(plan.dateRangePartitions.count, 1)
        let partition = plan.dateRangePartitions[0]
        XCTAssertEqual(partition.column, "study_date")
        XCTAssertEqual(partition.startDate, "20250101")
        XCTAssertEqual(partition.endDate, "20250331")
    }

    // MARK: - SQL Generation

    func test_queryPlanOptimiser_generateSQL_withDateRange() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .study,
            matchingKeys: ["StudyDate": "20250101-20250301"],
            returnKeys: []
        )
        let (clause, params) = optimiser.generateSQL(for: plan)
        XCTAssertTrue(clause.contains("study_date >= $"))
        XCTAssertTrue(clause.contains("study_date <= $"))
        XCTAssertTrue(params.contains("20250101"))
        XCTAssertTrue(params.contains("20250301"))
    }

    // MARK: - Cost Estimation

    func test_queryPlanOptimiser_indexLookup_lowestCost() {
        let optimiser = QueryPlanOptimiser()
        let plan = optimiser.optimise(
            level: .study,
            matchingKeys: ["StudyInstanceUID": "1.2.3"],
            returnKeys: []
        )
        XCTAssertEqual(plan.estimatedCost, 1.0)
    }
}

// MARK: - QueryStrategy Tests

final class QueryStrategyTests: XCTestCase {

    func test_queryStrategy_rawValues() {
        XCTAssertEqual(QueryStrategy.indexLookup.rawValue, "index_lookup")
        XCTAssertEqual(QueryStrategy.compositeIndexScan.rawValue, "composite_index_scan")
        XCTAssertEqual(QueryStrategy.wildcardRangeScan.rawValue, "wildcard_range_scan")
        XCTAssertEqual(QueryStrategy.fullTableScan.rawValue, "full_table_scan")
    }

    func test_queryStrategy_codable() throws {
        let strategy = QueryStrategy.compositeIndexScan
        let data = try JSONEncoder().encode(strategy)
        let decoded = try JSONDecoder().decode(QueryStrategy.self, from: data)
        XCTAssertEqual(decoded, strategy)
    }
}

// MARK: - RecallPrefetchCache Tests

final class RecallPrefetchCacheTests: XCTestCase {

    // MARK: - Basic Cache Operations

    func test_recallCache_get_returnsNilForUnknownStudy() async {
        let cache = RecallPrefetchCache(maxEntries: 8)
        let entry = await cache.get("unknown-uid")
        XCTAssertNil(entry)
    }

    func test_recallCache_putAndGet_returnsEntry() async {
        let cache = RecallPrefetchCache(maxEntries: 8)
        let entry = RecallCacheEntry(
            studyInstanceUID: "1.2.3",
            onlinePath: "/archive/1.2.3",
            recalledFrom: .nearLine
        )
        await cache.put("1.2.3", entry: entry)
        let retrieved = await cache.get("1.2.3")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.studyInstanceUID, "1.2.3")
        XCTAssertEqual(retrieved?.onlinePath, "/archive/1.2.3")
    }

    // MARK: - LRU Eviction

    func test_recallCache_evictsLRU_whenAtCapacity() async {
        let cache = RecallPrefetchCache(maxEntries: 2)
        let entry1 = RecallCacheEntry(studyInstanceUID: "uid1", onlinePath: "/1", recalledFrom: .nearLine)
        let entry2 = RecallCacheEntry(studyInstanceUID: "uid2", onlinePath: "/2", recalledFrom: .nearLine)
        let entry3 = RecallCacheEntry(studyInstanceUID: "uid3", onlinePath: "/3", recalledFrom: .nearLine)

        await cache.put("uid1", entry: entry1)
        await cache.put("uid2", entry: entry2)
        await cache.put("uid3", entry: entry3) // Should evict uid1

        let evicted = await cache.get("uid1")
        let kept2 = await cache.get("uid2")
        let kept3 = await cache.get("uid3")
        XCTAssertNil(evicted)
        XCTAssertNotNil(kept2)
        XCTAssertNotNil(kept3)
    }

    // MARK: - TTL Expiration

    func test_recallCache_expiredEntry_returnsNil() async {
        let cache = RecallPrefetchCache(maxEntries: 8, ttlSeconds: 0.01)
        let entry = RecallCacheEntry(
            studyInstanceUID: "1.2.3",
            onlinePath: "/archive/1.2.3",
            recalledFrom: .nearLine,
            cachedAt: Date().addingTimeInterval(-1.0) // Already 1 second old
        )
        await cache.put("1.2.3", entry: entry)
        let retrieved = await cache.get("1.2.3")
        XCTAssertNil(retrieved) // Expired
    }

    func test_recallCache_evictExpired_removesStaleEntries() async {
        let cache = RecallPrefetchCache(maxEntries: 8, ttlSeconds: 0.01)
        let oldEntry = RecallCacheEntry(
            studyInstanceUID: "old",
            onlinePath: "/old",
            recalledFrom: .nearLine,
            cachedAt: Date().addingTimeInterval(-1.0)
        )
        let freshEntry = RecallCacheEntry(
            studyInstanceUID: "fresh",
            onlinePath: "/fresh",
            recalledFrom: .nearLine
        )
        await cache.put("old", entry: oldEntry)
        await cache.put("fresh", entry: freshEntry)
        let evicted = await cache.evictExpired()
        XCTAssertEqual(evicted, 1)
    }

    // MARK: - Prefetch Hints

    func test_recallCache_prefetchCandidates_returnsRelatedUIDs() async {
        let cache = RecallPrefetchCache(maxEntries: 8)
        await cache.registerPrefetchHint(for: "study-A", relatedUIDs: ["study-B", "study-C"])
        let candidates = await cache.prefetchCandidates(for: "study-A")
        XCTAssertTrue(candidates.contains("study-B"))
        XCTAssertTrue(candidates.contains("study-C"))
    }

    func test_recallCache_prefetchCandidates_excludesCached() async {
        let cache = RecallPrefetchCache(maxEntries: 8)
        let entry = RecallCacheEntry(studyInstanceUID: "study-B", onlinePath: "/B", recalledFrom: .nearLine)
        await cache.put("study-B", entry: entry)
        await cache.registerPrefetchHint(for: "study-A", relatedUIDs: ["study-B", "study-C"])
        let candidates = await cache.prefetchCandidates(for: "study-A")
        XCTAssertFalse(candidates.contains("study-B"))
        XCTAssertTrue(candidates.contains("study-C"))
    }

    // MARK: - Statistics

    func test_recallCache_statistics_tracksHitsAndMisses() async {
        let cache = RecallPrefetchCache(maxEntries: 8)
        let entry = RecallCacheEntry(studyInstanceUID: "1.2.3", onlinePath: "/path", recalledFrom: .nearLine)
        await cache.put("1.2.3", entry: entry)
        _ = await cache.get("1.2.3") // hit
        _ = await cache.get("unknown") // miss
        let stats = await cache.statistics()
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.hitRate, 0.5, accuracy: 0.01)
    }

    // MARK: - Clear

    func test_recallCache_clear_resetsEverything() async {
        let cache = RecallPrefetchCache(maxEntries: 8)
        let entry = RecallCacheEntry(studyInstanceUID: "1.2.3", onlinePath: "/path", recalledFrom: .nearLine)
        await cache.put("1.2.3", entry: entry)
        await cache.clear()
        let stats = await cache.statistics()
        XCTAssertEqual(stats.entryCount, 0)
        XCTAssertEqual(stats.hitCount, 0)
        XCTAssertEqual(stats.missCount, 0)
    }
}

// MARK: - RecallCacheEntry Tests

final class RecallCacheEntryTests: XCTestCase {

    func test_recallCacheEntry_equatable() {
        let date = Date()
        let a = RecallCacheEntry(studyInstanceUID: "1.2.3", onlinePath: "/path", recalledFrom: .nearLine, cachedAt: date, recallDurationSeconds: 0.5)
        let b = RecallCacheEntry(studyInstanceUID: "1.2.3", onlinePath: "/path", recalledFrom: .nearLine, cachedAt: date, recallDurationSeconds: 0.5)
        XCTAssertEqual(a, b)
    }
}

// MARK: - RecallCacheStatistics Tests

final class RecallCacheStatisticsTests: XCTestCase {

    func test_recallCacheStatistics_equatable() {
        let a = RecallCacheStatistics(entryCount: 5, maxEntries: 128, hitCount: 10, missCount: 3, hitRate: 0.77, prefetchScheduledCount: 1, prefetchHintCount: 2)
        let b = RecallCacheStatistics(entryCount: 5, maxEntries: 128, hitCount: 10, missCount: 3, hitRate: 0.77, prefetchScheduledCount: 1, prefetchHintCount: 2)
        XCTAssertEqual(a, b)
    }
}

// MARK: - CodecBenchmark Tests

final class CodecBenchmarkTests: XCTestCase {

    func test_codecBenchmark_generateSyntheticPixelData_correctSize() {
        let benchmark = CodecBenchmark(warmupIterations: 0, timedIterations: 1)
        let data = benchmark.generateSyntheticPixelData(imageSize: .ct512)
        XCTAssertEqual(data.count, 512 * 512 * 2) // 16-bit pixels
    }

    func test_codecBenchmark_generateSyntheticPixelData_8bit() {
        let benchmark = CodecBenchmark(warmupIterations: 0, timedIterations: 1)
        let size = BenchmarkImageSize(width: 128, height: 128, bitsAllocated: 8, bitsStored: 8)
        let data = benchmark.generateSyntheticPixelData(imageSize: size)
        XCTAssertEqual(data.count, 128 * 128)
    }

    func test_codecBenchmark_runSingleCodec_returnsResult() {
        let benchmark = CodecBenchmark(warmupIterations: 0, timedIterations: 2)
        let size = BenchmarkImageSize(width: 64, height: 64, bitsAllocated: 16, bitsStored: 12)
        let result = benchmark.run(codec: .jpeg2000Lossless, imageSize: size)
        XCTAssertEqual(result.codec, .jpeg2000Lossless)
        XCTAssertEqual(result.inputSizeBytes, 64 * 64 * 2)
        XCTAssertEqual(result.encodeProfile.durations.count, 2)
        XCTAssertEqual(result.decodeProfile.durations.count, 2)
    }

    func test_codecBenchmark_runAll_coversAllCodecPaths() {
        let benchmark = CodecBenchmark(warmupIterations: 0, timedIterations: 1)
        let size = BenchmarkImageSize(width: 32, height: 32, bitsAllocated: 16, bitsStored: 12)
        let results = benchmark.runAll(imageSize: size)
        XCTAssertEqual(results.count, CodecPath.allCases.count)
    }

    func test_codecBenchmark_formatReport_containsCodecNames() {
        let benchmark = CodecBenchmark(warmupIterations: 0, timedIterations: 1)
        let size = BenchmarkImageSize(width: 32, height: 32)
        let results = benchmark.runAll(imageSize: size)
        let report = benchmark.formatReport(results)
        XCTAssertTrue(report.contains("JPEG 2000 Lossless"))
        XCTAssertTrue(report.contains("HTJ2K"))
        XCTAssertTrue(report.contains("JPEG-LS"))
    }
}

// MARK: - BenchmarkImageSize Tests

final class BenchmarkImageSizeTests: XCTestCase {

    func test_benchmarkImageSize_description() {
        let size = BenchmarkImageSize(width: 512, height: 512, bitsAllocated: 16, bitsStored: 12)
        XCTAssertTrue(size.description.contains("512×512"))
        XCTAssertTrue(size.description.contains("12-bit"))
    }

    func test_benchmarkImageSize_presets() {
        XCTAssertEqual(BenchmarkImageSize.ct512.width, 512)
        XCTAssertEqual(BenchmarkImageSize.dx2k.width, 2048)
        XCTAssertEqual(BenchmarkImageSize.mg4k.width, 4096)
        XCTAssertEqual(BenchmarkImageSize.mr256.width, 256)
    }

    func test_benchmarkImageSize_equatable() {
        let a = BenchmarkImageSize(width: 512, height: 512)
        let b = BenchmarkImageSize(width: 512, height: 512)
        XCTAssertEqual(a, b)
    }
}

// MARK: - CodecPath Tests

final class CodecPathTests: XCTestCase {

    func test_codecPath_allCases() {
        XCTAssertEqual(CodecPath.allCases.count, 9)
    }

    func test_codecPath_rawValues() {
        XCTAssertEqual(CodecPath.jpeg2000Lossless.rawValue, "JPEG 2000 Lossless")
        XCTAssertEqual(CodecPath.htj2kLossless.rawValue, "HTJ2K Lossless")
        XCTAssertEqual(CodecPath.jpegLSLossless.rawValue, "JPEG-LS Lossless")
        XCTAssertEqual(CodecPath.jpegXLLossless.rawValue, "JPEG XL Lossless")
        XCTAssertEqual(CodecPath.rleLossless.rawValue, "RLE Lossless")
    }
}

// MARK: - CodecTimingProfile Tests

final class CodecTimingProfileTests: XCTestCase {

    func test_codecTimingProfile_meanDuration() {
        let profile = CodecTimingProfile(durations: [0.01, 0.02, 0.03], totalBytes: 1024, totalPixels: 512)
        XCTAssertEqual(profile.meanDuration, 0.02, accuracy: 0.001)
    }

    func test_codecTimingProfile_bytesPerSecond() {
        let profile = CodecTimingProfile(durations: [1.0], totalBytes: 1_000_000, totalPixels: 250_000)
        XCTAssertEqual(profile.bytesPerSecond, 1_000_000, accuracy: 1.0)
    }

    func test_codecTimingProfile_megapixelsPerSecond() {
        let profile = CodecTimingProfile(durations: [1.0], totalBytes: 500_000, totalPixels: 1_000_000)
        XCTAssertEqual(profile.megapixelsPerSecond, 1.0, accuracy: 0.01)
    }

    func test_codecTimingProfile_formattedSummary_containsUnits() {
        let profile = CodecTimingProfile(durations: [0.001], totalBytes: 1024, totalPixels: 512)
        let summary = profile.formattedSummary
        XCTAssertTrue(summary.contains("ms"))
        XCTAssertTrue(summary.contains("Mpx/s"))
    }
}

// MARK: - StressTester Tests

final class StressTesterTests: XCTestCase {

    func test_stressTester_generateSyntheticDataset_correctCount() {
        let config = StressTestConfiguration(
            patientCount: 2,
            studiesPerPatient: 2,
            seriesPerStudy: 1,
            instancesPerSeries: 3
        )
        let tester = StressTester(configuration: config)
        let instances = tester.generateSyntheticDataset()
        XCTAssertEqual(instances.count, 2 * 2 * 1 * 3) // 12 instances
    }

    func test_stressTester_syntheticInstances_haveValidUIDs() {
        let config = StressTestConfiguration(
            patientCount: 1,
            studiesPerPatient: 1,
            seriesPerStudy: 1,
            instancesPerSeries: 2
        )
        let tester = StressTester(configuration: config)
        let instances = tester.generateSyntheticDataset()
        for instance in instances {
            XCTAssertFalse(instance.sopInstanceUID.isEmpty)
            XCTAssertFalse(instance.studyInstanceUID.isEmpty)
            XCTAssertFalse(instance.seriesInstanceUID.isEmpty)
            XCTAssertFalse(instance.patientID.isEmpty)
            XCTAssertTrue(instance.sopClassUID.contains("1.2.840.10008"))
        }
    }

    func test_stressTester_syntheticInstances_haveCorrectModalities() {
        let config = StressTestConfiguration(
            patientCount: 1,
            studiesPerPatient: 1,
            seriesPerStudy: 4,
            instancesPerSeries: 1,
            modalities: ["CT", "MR", "CR", "DX"]
        )
        let tester = StressTester(configuration: config)
        let instances = tester.generateSyntheticDataset()
        let modalities = Set(instances.map { $0.modality })
        XCTAssertTrue(modalities.contains("CT"))
        XCTAssertTrue(modalities.contains("MR"))
        XCTAssertTrue(modalities.contains("CR"))
        XCTAssertTrue(modalities.contains("DX"))
    }

    func test_stressTester_generateInstanceData_correctSize() {
        let config = StressTestConfiguration(imageSize: .ct512)
        let tester = StressTester(configuration: config)
        let data = tester.generateInstanceData()
        XCTAssertEqual(data.count, 512 * 512 * 2)
    }

    func test_stressTester_datasetSummary_calculatesCorrectly() {
        let config = StressTestConfiguration(
            patientCount: 10,
            studiesPerPatient: 2,
            seriesPerStudy: 3,
            instancesPerSeries: 50,
            concurrentAssociations: 4,
            imageSize: .ct512
        )
        let tester = StressTester(configuration: config)
        let summary = tester.datasetSummary()
        XCTAssertEqual(summary.patientCount, 10)
        XCTAssertEqual(summary.totalStudies, 20)
        XCTAssertEqual(summary.totalSeries, 60)
        XCTAssertEqual(summary.totalInstances, 3000)
        XCTAssertEqual(summary.bytesPerInstance, 512 * 512 * 2)
        XCTAssertEqual(summary.concurrentAssociations, 4)
    }

    func test_stressTester_datasetSummary_formattedSummary_containsInfo() {
        let config = StressTestConfiguration(patientCount: 5)
        let tester = StressTester(configuration: config)
        let summary = tester.datasetSummary()
        let formatted = summary.formattedSummary
        XCTAssertTrue(formatted.contains("Patients:"))
        XCTAssertTrue(formatted.contains("Studies:"))
        XCTAssertTrue(formatted.contains("Instances:"))
        XCTAssertTrue(formatted.contains("GB"))
    }
}

// MARK: - DatasetSummary Tests

final class DatasetSummaryTests: XCTestCase {

    func test_datasetSummary_equatable() {
        let a = DatasetSummary(patientCount: 10, totalStudies: 20, totalSeries: 60, totalInstances: 3000, bytesPerInstance: 524288, totalBytes: 1572864000, concurrentAssociations: 8)
        let b = DatasetSummary(patientCount: 10, totalStudies: 20, totalSeries: 60, totalInstances: 3000, bytesPerInstance: 524288, totalBytes: 1572864000, concurrentAssociations: 8)
        XCTAssertEqual(a, b)
    }
}

// MARK: - WildcardRewrite Tests

final class WildcardRewriteTests: XCTestCase {

    func test_wildcardRewrite_equatable() {
        let a = WildcardRewrite(column: "patient_name", originalPattern: "SMI*", lowerBound: "SMI", upperBound: "SMJ")
        let b = WildcardRewrite(column: "patient_name", originalPattern: "SMI*", lowerBound: "SMI", upperBound: "SMJ")
        XCTAssertEqual(a, b)
    }
}

// MARK: - DateRangePartition Tests

final class DateRangePartitionTests: XCTestCase {

    func test_dateRangePartition_equatable() {
        let a = DateRangePartition(column: "study_date", startDate: "20250101", endDate: "20250331")
        let b = DateRangePartition(column: "study_date", startDate: "20250101", endDate: "20250331")
        XCTAssertEqual(a, b)
    }
}
