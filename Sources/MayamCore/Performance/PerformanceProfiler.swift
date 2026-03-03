// SPDX-License-Identifier: (see LICENSE)
// Mayam — Performance Profiler

import Foundation

/// Lightweight performance profiling utilities for measuring timing,
/// throughput, and memory usage across Mayam subsystems.
///
/// `PerformanceProfiler` provides static helpers that can be embedded
/// in production code paths with negligible overhead when profiling
/// is disabled, and detailed wall-clock, CPU-time, and throughput
/// measurements when enabled.
///
/// ## Usage
///
/// ```swift
/// let result = PerformanceProfiler.measure("c-store-write") {
///     try storageActor.store(…)
/// }
/// print(result.formattedSummary)
/// ```
///
/// Reference: Milestone 14 — Performance Optimisation & Benchmarking
public enum PerformanceProfiler {

    // MARK: - Measurement

    /// Measures the wall-clock duration of a synchronous closure.
    ///
    /// - Parameters:
    ///   - label: A human-readable label for the operation being profiled.
    ///   - iterations: Number of times to execute the closure (default: 1).
    ///   - operation: The closure to measure.
    /// - Returns: A ``ProfilingResult`` summarising the measurement.
    @discardableResult
    public static func measure(
        _ label: String,
        iterations: Int = 1,
        operation: () throws -> Void
    ) rethrows -> ProfilingResult {
        let iterCount = max(1, iterations)
        var durations: [TimeInterval] = []
        durations.reserveCapacity(iterCount)

        for _ in 0..<iterCount {
            let start = DispatchTime.now()
            try operation()
            let end = DispatchTime.now()
            let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
            durations.append(Double(nanos) / 1_000_000_000.0)
        }

        return ProfilingResult(label: label, durations: durations)
    }

    /// Measures the wall-clock duration of an asynchronous closure.
    ///
    /// - Parameters:
    ///   - label: A human-readable label for the operation being profiled.
    ///   - iterations: Number of times to execute the closure (default: 1).
    ///   - operation: The async closure to measure.
    /// - Returns: A ``ProfilingResult`` summarising the measurement.
    @discardableResult
    public static func measureAsync(
        _ label: String,
        iterations: Int = 1,
        operation: () async throws -> Void
    ) async rethrows -> ProfilingResult {
        let iterCount = max(1, iterations)
        var durations: [TimeInterval] = []
        durations.reserveCapacity(iterCount)

        for _ in 0..<iterCount {
            let start = DispatchTime.now()
            try await operation()
            let end = DispatchTime.now()
            let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
            durations.append(Double(nanos) / 1_000_000_000.0)
        }

        return ProfilingResult(label: label, durations: durations)
    }

    // MARK: - Throughput

    /// Computes throughput in bytes per second.
    ///
    /// - Parameters:
    ///   - bytes: Total bytes processed.
    ///   - duration: Time taken in seconds.
    /// - Returns: Throughput in bytes per second, or 0 if duration is zero.
    public static func throughput(bytes: Int, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        return Double(bytes) / duration
    }

    /// Formats a byte count into a human-readable string (e.g. "1.23 GB/s").
    ///
    /// - Parameter bytesPerSecond: The throughput in bytes per second.
    /// - Returns: A formatted string.
    public static func formatThroughput(_ bytesPerSecond: Double) -> String {
        switch bytesPerSecond {
        case _ where bytesPerSecond >= 1_000_000_000:
            return String(format: "%.2f GB/s", bytesPerSecond / 1_000_000_000)
        case _ where bytesPerSecond >= 1_000_000:
            return String(format: "%.2f MB/s", bytesPerSecond / 1_000_000)
        case _ where bytesPerSecond >= 1_000:
            return String(format: "%.2f KB/s", bytesPerSecond / 1_000)
        default:
            return String(format: "%.0f B/s", bytesPerSecond)
        }
    }

    /// Formats a duration in seconds into a human-readable string.
    ///
    /// - Parameter seconds: The duration in seconds.
    /// - Returns: A formatted string (e.g. "1.23 ms", "456.78 µs").
    public static func formatDuration(_ seconds: TimeInterval) -> String {
        switch seconds {
        case _ where seconds >= 1.0:
            return String(format: "%.3f s", seconds)
        case _ where seconds >= 0.001:
            return String(format: "%.3f ms", seconds * 1_000)
        case _ where seconds >= 0.000_001:
            return String(format: "%.3f µs", seconds * 1_000_000)
        default:
            return String(format: "%.0f ns", seconds * 1_000_000_000)
        }
    }
}

// MARK: - ProfilingResult

/// Captures the result of a profiling measurement.
public struct ProfilingResult: Sendable {

    /// Human-readable label identifying the measured operation.
    public let label: String

    /// Individual iteration durations in seconds.
    public let durations: [TimeInterval]

    /// Number of iterations performed.
    public var iterations: Int { durations.count }

    /// Total time across all iterations, in seconds.
    public var totalDuration: TimeInterval { durations.reduce(0, +) }

    /// Mean duration per iteration, in seconds.
    public var meanDuration: TimeInterval {
        guard !durations.isEmpty else { return 0 }
        return totalDuration / Double(durations.count)
    }

    /// Minimum iteration duration, in seconds.
    public var minDuration: TimeInterval { durations.min() ?? 0 }

    /// Maximum iteration duration, in seconds.
    public var maxDuration: TimeInterval { durations.max() ?? 0 }

    /// Median iteration duration, in seconds.
    public var medianDuration: TimeInterval {
        guard !durations.isEmpty else { return 0 }
        let sorted = durations.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        }
        return sorted[mid]
    }

    /// Standard deviation of iteration durations.
    public var standardDeviation: TimeInterval {
        guard durations.count > 1 else { return 0 }
        let mean = meanDuration
        let variance = durations.reduce(0.0) { sum, d in sum + (d - mean) * (d - mean) }
            / Double(durations.count - 1)
        return variance.squareRoot()
    }

    /// A formatted multi-line summary of the profiling result.
    public var formattedSummary: String {
        var lines: [String] = []
        lines.append("[\(label)] \(iterations) iteration(s)")
        lines.append("  Total:   \(PerformanceProfiler.formatDuration(totalDuration))")
        lines.append("  Mean:    \(PerformanceProfiler.formatDuration(meanDuration))")
        lines.append("  Median:  \(PerformanceProfiler.formatDuration(medianDuration))")
        lines.append("  Min:     \(PerformanceProfiler.formatDuration(minDuration))")
        lines.append("  Max:     \(PerformanceProfiler.formatDuration(maxDuration))")
        if iterations > 1 {
            lines.append("  StdDev:  \(PerformanceProfiler.formatDuration(standardDeviation))")
        }
        return lines.joined(separator: "\n")
    }

    /// Creates a profiling result.
    ///
    /// - Parameters:
    ///   - label: Human-readable label for the operation.
    ///   - durations: Individual iteration durations in seconds.
    public init(label: String, durations: [TimeInterval]) {
        self.label = label
        self.durations = durations
    }
}
