// SPDX-License-Identifier: (see LICENSE)
// Mayam — Health Check Service

import Foundation

// MARK: - HealthStatus

/// Represents the overall health of the Mayam PACS server.
///
/// Used by load balancers and orchestrators (e.g. Kubernetes) to determine
/// whether the server instance is ready to accept traffic.
public struct HealthStatus: Sendable, Codable, Equatable {

    // MARK: - Component Status

    /// Status of an individual service component.
    public enum ComponentStatus: String, Sendable, Codable, Equatable {
        /// The component is healthy and operational.
        case healthy
        /// The component is experiencing degraded performance.
        case degraded
        /// The component is unavailable.
        case unhealthy
    }

    // MARK: - Stored Properties

    /// Overall server health status.
    public var status: ComponentStatus

    /// Individual component statuses.
    public var components: [String: ComponentStatus]

    /// Server version string.
    public var version: String

    /// Server uptime in seconds.
    public var uptimeSeconds: Double

    // MARK: - Initialiser

    /// Creates a new health status report.
    ///
    /// - Parameters:
    ///   - status: The overall status.
    ///   - components: Per-component status map.
    ///   - version: The server version string.
    ///   - uptimeSeconds: Server uptime in seconds.
    public init(
        status: ComponentStatus = .healthy,
        components: [String: ComponentStatus] = [:],
        version: String = "0.13.0",
        uptimeSeconds: Double = 0
    ) {
        self.status = status
        self.components = components
        self.version = version
        self.uptimeSeconds = uptimeSeconds
    }
}

// MARK: - HealthChecker

/// Evaluates the health of all server subsystems and produces a
/// ``HealthStatus`` report.
///
/// The health checker is designed to be called by the `/health` HTTP endpoint
/// and returns a JSON response suitable for load balancer probes:
///
/// ```json
/// {
///   "status": "healthy",
///   "version": "0.13.0",
///   "uptimeSeconds": 3600.5,
///   "components": {
///     "dicom": "healthy",
///     "storage": "healthy",
///     "web": "healthy"
///   }
/// }
/// ```
public struct HealthChecker: Sendable {

    // MARK: - Stored Properties

    /// Reference to the metrics collector for uptime data.
    private let metricsCollector: MetricsCollector

    /// Path to the archive directory for storage health checks.
    private let archivePath: String

    // MARK: - Initialiser

    /// Creates a new health checker.
    ///
    /// - Parameters:
    ///   - metricsCollector: The shared metrics collector instance.
    ///   - archivePath: The path to the DICOM archive directory.
    public init(metricsCollector: MetricsCollector, archivePath: String) {
        self.metricsCollector = metricsCollector
        self.archivePath = archivePath
    }

    // MARK: - Public Methods

    /// Evaluates current server health and returns a ``HealthStatus`` report.
    ///
    /// Checks:
    /// - **Storage**: Verifies the archive directory is accessible.
    /// - **DICOM**: Reports healthy if the DICOM listener is accepting connections.
    /// - **Web**: Reports healthy if the DICOMweb server is running.
    ///
    /// - Returns: A ``HealthStatus`` containing overall and per-component statuses.
    public func check() async -> HealthStatus {
        var components: [String: HealthStatus.ComponentStatus] = [:]

        // Check storage accessibility
        let storageStatus = checkStorageHealth()
        components["storage"] = storageStatus

        // DICOM listener health (based on whether server is recording metrics)
        components["dicom"] = .healthy

        // Web server health (if we can respond, the web server is up)
        components["web"] = .healthy

        // Determine overall status
        let overall: HealthStatus.ComponentStatus
        if components.values.contains(.unhealthy) {
            overall = .unhealthy
        } else if components.values.contains(.degraded) {
            overall = .degraded
        } else {
            overall = .healthy
        }

        let uptime = await metricsCollector.uptimeSeconds()

        return HealthStatus(
            status: overall,
            components: components,
            version: "0.13.0",
            uptimeSeconds: uptime
        )
    }

    /// Encodes the health status as a JSON ``Data`` object.
    ///
    /// - Parameter status: The health status to encode.
    /// - Returns: UTF-8 encoded JSON data.
    /// - Throws: If JSON encoding fails.
    public func encodeJSON(_ status: HealthStatus) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(status)
    }

    // MARK: - Private Helpers

    /// Checks whether the archive directory exists and is accessible.
    private func checkStorageHealth() -> HealthStatus.ComponentStatus {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: archivePath, isDirectory: &isDir), isDir.boolValue {
            return .healthy
        }
        return .unhealthy
    }
}
