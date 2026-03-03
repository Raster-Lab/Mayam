// SPDX-License-Identifier: (see LICENSE)
// Mayam — Metrics HTTP Endpoint Handler

import Foundation
import MayamCore

// MARK: - MetricsHandler

/// Handles HTTP requests for the `/metrics` endpoint.
///
/// Returns Prometheus-compatible text exposition format containing all
/// tracked server metrics.  This endpoint is designed to be scraped by
/// Prometheus or any compatible metrics collection system.
///
/// ## Example Response
///
/// ```
/// # HELP mayam_active_associations Current number of active DICOM associations.
/// # TYPE mayam_active_associations gauge
/// mayam_active_associations 3
/// ```
///
/// Reference: Prometheus Exposition Format
public struct MetricsHandler: Sendable {

    // MARK: - Stored Properties

    /// The metrics collector providing current metric values.
    private let metricsCollector: MetricsCollector

    // MARK: - Initialiser

    /// Creates a new metrics handler.
    ///
    /// - Parameter metricsCollector: The shared metrics collector instance.
    public init(metricsCollector: MetricsCollector) {
        self.metricsCollector = metricsCollector
    }

    // MARK: - Public Methods

    /// Handles a metrics request and returns a Prometheus text response.
    ///
    /// - Returns: A ``DICOMwebResponse`` containing Prometheus metrics text.
    public func handleMetrics() async -> DICOMwebResponse {
        let output = await metricsCollector.prometheusOutput()
        let body = Data(output.utf8)
        return DICOMwebResponse(
            statusCode: 200,
            body: body,
            headers: [
                "Content-Type": "text/plain; version=0.0.4; charset=utf-8"
            ]
        )
    }
}
