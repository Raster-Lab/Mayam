// SPDX-License-Identifier: (see LICENSE)
// Mayam — Health Check HTTP Endpoint Handler

import Foundation
import MayamCore

// MARK: - HealthHandler

/// Handles HTTP requests for the `/health` endpoint.
///
/// Returns a JSON health status report suitable for load balancer and
/// orchestrator probes (Kubernetes liveness/readiness).
///
/// ## Example Response
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
///
/// Returns HTTP 200 when healthy, HTTP 503 when unhealthy.
public struct HealthHandler: Sendable {

    // MARK: - Stored Properties

    /// The health checker that evaluates server subsystems.
    private let healthChecker: HealthChecker

    // MARK: - Initialiser

    /// Creates a new health handler.
    ///
    /// - Parameter healthChecker: The health checker instance.
    public init(healthChecker: HealthChecker) {
        self.healthChecker = healthChecker
    }

    // MARK: - Public Methods

    /// Handles a health check request and returns a JSON response.
    ///
    /// - Returns: A ``DICOMwebResponse`` containing the health status JSON.
    ///   Returns HTTP 200 for healthy/degraded, HTTP 503 for unhealthy.
    public func handleHealth() async -> DICOMwebResponse {
        let status = await healthChecker.check()

        let statusCode: UInt = status.status == .unhealthy ? 503 : 200

        do {
            let body = try healthChecker.encodeJSON(status)
            return DICOMwebResponse(
                statusCode: statusCode,
                body: body,
                headers: ["Content-Type": "application/json"]
            )
        } catch {
            let errorBody = Data("{\"status\":\"unhealthy\",\"error\":\"encoding failure\"}".utf8)
            return DICOMwebResponse(
                statusCode: 503,
                body: errorBody,
                headers: ["Content-Type": "application/json"]
            )
        }
    }
}
