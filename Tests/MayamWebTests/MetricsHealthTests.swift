// SPDX-License-Identifier: (see LICENSE)
// Mayam — Metrics and Health Endpoint Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

// MARK: - MetricsHandler Tests

final class MetricsHandlerTests: XCTestCase {

    func test_metricsHandler_handleMetrics_returnsPrometheusFormat() async {
        let collector = MetricsCollector()
        await collector.recordActiveAssociations(5)
        await collector.recordRequest(durationSeconds: 0.05)

        let handler = MetricsHandler(metricsCollector: collector)
        let response = await handler.handleMetrics()

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["Content-Type"], "text/plain; version=0.0.4; charset=utf-8")

        let body = String(data: response.body, encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("mayam_active_associations 5"))
        XCTAssertTrue(body.contains("mayam_requests_total 1"))
    }

    func test_metricsHandler_handleMetrics_containsAllSections() async {
        let collector = MetricsCollector()
        let handler = MetricsHandler(metricsCollector: collector)
        let response = await handler.handleMetrics()

        let body = String(data: response.body, encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("# HELP mayam_uptime_seconds"))
        XCTAssertTrue(body.contains("# HELP mayam_active_associations"))
        XCTAssertTrue(body.contains("# HELP mayam_requests_total"))
        XCTAssertTrue(body.contains("# HELP mayam_request_duration_seconds"))
        XCTAssertTrue(body.contains("# HELP mayam_storage_bytes_total"))
        XCTAssertTrue(body.contains("# HELP mayam_compression_ratio"))
        XCTAssertTrue(body.contains("# HELP mayam_backup_last_run_timestamp"))
        XCTAssertTrue(body.contains("# HELP mayam_errors_total"))
        XCTAssertTrue(body.contains("# HELP mayam_queue_depth"))
    }
}

// MARK: - HealthHandler Tests

final class HealthHandlerTests: XCTestCase {

    func test_healthHandler_handleHealth_returns200WhenHealthy() async throws {
        let tempDir = NSTemporaryDirectory() + "mayam_health_handler_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let collector = MetricsCollector()
        let checker = HealthChecker(metricsCollector: collector, archivePath: tempDir)
        let handler = HealthHandler(healthChecker: checker)
        let response = await handler.handleHealth()

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["Content-Type"], "application/json")

        let json = try JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        XCTAssertEqual(json?["status"] as? String, "healthy")
    }

    func test_healthHandler_handleHealth_returns503WhenUnhealthy() async throws {
        let collector = MetricsCollector()
        let checker = HealthChecker(metricsCollector: collector, archivePath: "/nonexistent/path")
        let handler = HealthHandler(healthChecker: checker)
        let response = await handler.handleHealth()

        XCTAssertEqual(response.statusCode, 503)
        XCTAssertEqual(response.headers["Content-Type"], "application/json")

        let json = try JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        XCTAssertEqual(json?["status"] as? String, "unhealthy")
    }

    func test_healthHandler_handleHealth_includesComponents() async throws {
        let tempDir = NSTemporaryDirectory() + "mayam_health_handler_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let collector = MetricsCollector()
        let checker = HealthChecker(metricsCollector: collector, archivePath: tempDir)
        let handler = HealthHandler(healthChecker: checker)
        let response = await handler.handleHealth()

        let json = try JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        let components = json?["components"] as? [String: String]
        XCTAssertNotNil(components)
        XCTAssertEqual(components?["storage"], "healthy")
        XCTAssertEqual(components?["dicom"], "healthy")
        XCTAssertEqual(components?["web"], "healthy")
    }

    func test_healthHandler_handleHealth_includesVersion() async throws {
        let tempDir = NSTemporaryDirectory() + "mayam_health_handler_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let collector = MetricsCollector()
        let checker = HealthChecker(metricsCollector: collector, archivePath: tempDir)
        let handler = HealthHandler(healthChecker: checker)
        let response = await handler.handleHealth()

        let json = try JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        let version = json?["version"] as? String
        XCTAssertNotNil(version)
        XCTAssertFalse(version?.isEmpty ?? true)
    }
}
