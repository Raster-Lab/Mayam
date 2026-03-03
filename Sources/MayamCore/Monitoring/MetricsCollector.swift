// SPDX-License-Identifier: (see LICENSE)
// Mayam — Prometheus Metrics Collector

import Foundation

// MARK: - MetricsCollector

/// Collects and exposes operational metrics in Prometheus text exposition format.
///
/// `MetricsCollector` is a singleton actor that tracks server-wide counters,
/// gauges, and histograms.  All subsystems (DICOM, storage, HTTP, backup)
/// record observations via `record*` methods, and the ``prometheusOutput()``
/// method serialises the current state in the Prometheus text format.
///
/// ## Tracked Metrics
///
/// | Metric | Type | Description |
/// |---|---|---|
/// | `mayam_active_associations` | Gauge | Current DICOM association count |
/// | `mayam_requests_total` | Counter | Total HTTP requests served |
/// | `mayam_request_duration_seconds` | Histogram | Request latency distribution |
/// | `mayam_storage_bytes_total` | Gauge | Storage utilisation per tier |
/// | `mayam_compression_ratio` | Gauge | Archive compression ratio |
/// | `mayam_backup_last_run_timestamp` | Gauge | Last backup completion (Unix) |
/// | `mayam_backup_success` | Gauge | 1 if last backup succeeded, 0 otherwise |
/// | `mayam_errors_total` | Counter | Total error count by category |
/// | `mayam_queue_depth` | Gauge | Pending work queue depth |
///
/// Reference: Prometheus Exposition Format — https://prometheus.io/docs/instrumenting/exposition_formats/
public actor MetricsCollector {

    // MARK: - Singleton

    /// Shared metrics collector instance.
    public static let shared = MetricsCollector()

    // MARK: - Stored Properties

    /// Current number of active DICOM associations.
    private var activeAssociations: Int = 0

    /// Total number of HTTP requests served since startup.
    private var totalRequests: UInt64 = 0

    /// Request latency observations in seconds, bucketed for percentile
    /// computation (p50, p90, p99).
    private var latencyObservations: [Double] = []

    /// Storage utilisation in bytes, keyed by tier name.
    private var storageBytesByTier: [String: UInt64] = [:]

    /// Current archive compression ratio (original / compressed).
    private var compressionRatio: Double = 1.0

    /// Unix timestamp of the last successful backup run.
    private var backupLastRunTimestamp: Double = 0.0

    /// Whether the last backup succeeded (1.0) or failed (0.0).
    private var backupSuccess: Double = 0.0

    /// Total error count keyed by category.
    private var errorsByCategory: [String: UInt64] = [:]

    /// Current pending work queue depth.
    private var queueDepth: Int = 0

    /// Server start time for uptime calculation.
    private let startTime: Date

    // MARK: - Initialiser

    /// Creates a new metrics collector.
    public init() {
        self.startTime = Date()
    }

    // MARK: - Recording Methods

    /// Records a change in the active DICOM association count.
    ///
    /// - Parameter count: The new active association count.
    public func recordActiveAssociations(_ count: Int) {
        activeAssociations = count
    }

    /// Increments the active association count by one.
    public func incrementActiveAssociations() {
        activeAssociations += 1
    }

    /// Decrements the active association count by one.
    public func decrementActiveAssociations() {
        activeAssociations = max(0, activeAssociations - 1)
    }

    /// Records an HTTP request and its latency.
    ///
    /// - Parameter durationSeconds: The request duration in seconds.
    public func recordRequest(durationSeconds: Double) {
        totalRequests += 1
        latencyObservations.append(durationSeconds)

        // Keep at most 10 000 observations to bound memory usage.
        if latencyObservations.count > 10_000 {
            latencyObservations.removeFirst(latencyObservations.count - 10_000)
        }
    }

    /// Records storage utilisation for a given tier.
    ///
    /// - Parameters:
    ///   - tier: The storage tier name (e.g. `"online"`, `"nearline"`).
    ///   - bytes: Total bytes used.
    public func recordStorageUtilisation(tier: String, bytes: UInt64) {
        storageBytesByTier[tier] = bytes
    }

    /// Records the current archive compression ratio.
    ///
    /// - Parameter ratio: The compression ratio (original size / compressed size).
    public func recordCompressionRatio(_ ratio: Double) {
        compressionRatio = ratio
    }

    /// Records a backup completion event.
    ///
    /// - Parameter success: Whether the backup completed successfully.
    public func recordBackupCompletion(success: Bool) {
        backupLastRunTimestamp = Date().timeIntervalSince1970
        backupSuccess = success ? 1.0 : 0.0
    }

    /// Records an error in the given category.
    ///
    /// - Parameter category: The error category (e.g. `"dicom"`, `"http"`, `"storage"`).
    public func recordError(category: String) {
        errorsByCategory[category, default: 0] += 1
    }

    /// Records the current work queue depth.
    ///
    /// - Parameter depth: The number of pending items in the queue.
    public func recordQueueDepth(_ depth: Int) {
        queueDepth = depth
    }

    // MARK: - Accessors

    /// Returns the current active association count.
    public func getActiveAssociations() -> Int {
        activeAssociations
    }

    /// Returns the total number of requests served.
    public func getTotalRequests() -> UInt64 {
        totalRequests
    }

    /// Returns the current queue depth.
    public func getQueueDepth() -> Int {
        queueDepth
    }

    /// Returns the total errors for a given category.
    ///
    /// - Parameter category: The error category.
    /// - Returns: The cumulative error count.
    public func getErrors(category: String) -> UInt64 {
        errorsByCategory[category] ?? 0
    }

    /// Returns the server uptime in seconds.
    public func uptimeSeconds() -> Double {
        Date().timeIntervalSince(startTime)
    }

    // MARK: - Prometheus Output

    /// Generates a Prometheus-compatible text exposition of all tracked metrics.
    ///
    /// - Returns: A UTF-8 string in Prometheus text format.
    public func prometheusOutput() -> String {
        var lines: [String] = []

        // Uptime
        lines.append("# HELP mayam_uptime_seconds Server uptime in seconds.")
        lines.append("# TYPE mayam_uptime_seconds gauge")
        lines.append("mayam_uptime_seconds \(formatDouble(uptimeSeconds()))")

        // Active associations
        lines.append("# HELP mayam_active_associations Current number of active DICOM associations.")
        lines.append("# TYPE mayam_active_associations gauge")
        lines.append("mayam_active_associations \(activeAssociations)")

        // Total requests
        lines.append("# HELP mayam_requests_total Total HTTP requests served.")
        lines.append("# TYPE mayam_requests_total counter")
        lines.append("mayam_requests_total \(totalRequests)")

        // Request latency percentiles
        let percentiles = computePercentiles()
        lines.append("# HELP mayam_request_duration_seconds Request latency percentiles.")
        lines.append("# TYPE mayam_request_duration_seconds summary")
        lines.append("mayam_request_duration_seconds{quantile=\"0.5\"} \(formatDouble(percentiles.p50))")
        lines.append("mayam_request_duration_seconds{quantile=\"0.9\"} \(formatDouble(percentiles.p90))")
        lines.append("mayam_request_duration_seconds{quantile=\"0.99\"} \(formatDouble(percentiles.p99))")
        lines.append("mayam_request_duration_seconds_count \(totalRequests)")

        // Storage utilisation per tier
        lines.append("# HELP mayam_storage_bytes_total Storage utilisation in bytes per tier.")
        lines.append("# TYPE mayam_storage_bytes_total gauge")
        for (tier, bytes) in storageBytesByTier.sorted(by: { $0.key < $1.key }) {
            lines.append("mayam_storage_bytes_total{tier=\"\(tier)\"} \(bytes)")
        }

        // Compression ratio
        lines.append("# HELP mayam_compression_ratio Archive compression ratio.")
        lines.append("# TYPE mayam_compression_ratio gauge")
        lines.append("mayam_compression_ratio \(formatDouble(compressionRatio))")

        // Backup status
        lines.append("# HELP mayam_backup_last_run_timestamp Unix timestamp of the last backup run.")
        lines.append("# TYPE mayam_backup_last_run_timestamp gauge")
        lines.append("mayam_backup_last_run_timestamp \(formatDouble(backupLastRunTimestamp))")

        lines.append("# HELP mayam_backup_success Whether the last backup succeeded (1) or failed (0).")
        lines.append("# TYPE mayam_backup_success gauge")
        lines.append("mayam_backup_success \(formatDouble(backupSuccess))")

        // Error rates
        lines.append("# HELP mayam_errors_total Total errors by category.")
        lines.append("# TYPE mayam_errors_total counter")
        for (category, count) in errorsByCategory.sorted(by: { $0.key < $1.key }) {
            lines.append("mayam_errors_total{category=\"\(category)\"} \(count)")
        }

        // Queue depth
        lines.append("# HELP mayam_queue_depth Pending work queue depth.")
        lines.append("# TYPE mayam_queue_depth gauge")
        lines.append("mayam_queue_depth \(queueDepth)")

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private Helpers

    /// Computes p50, p90, and p99 percentiles from latency observations.
    private func computePercentiles() -> (p50: Double, p90: Double, p99: Double) {
        guard !latencyObservations.isEmpty else {
            return (0, 0, 0)
        }
        let sorted = latencyObservations.sorted()
        let count = sorted.count

        let p50 = sorted[min(count - 1, Int(Double(count) * 0.50))]
        let p90 = sorted[min(count - 1, Int(Double(count) * 0.90))]
        let p99 = sorted[min(count - 1, Int(Double(count) * 0.99))]

        return (p50, p90, p99)
    }

    /// Formats a `Double` for Prometheus output (avoids scientific notation).
    private func formatDouble(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}
