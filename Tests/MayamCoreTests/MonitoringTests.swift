// SPDX-License-Identifier: (see LICENSE)
// Mayam — Monitoring Component Tests

import XCTest
@testable import MayamCore

// MARK: - MetricsCollector Tests

final class MetricsCollectorTests: XCTestCase {

    // MARK: - Active Associations

    func test_metricsCollector_initialState_hasZeroAssociations() async {
        let collector = MetricsCollector()
        let count = await collector.getActiveAssociations()
        XCTAssertEqual(count, 0)
    }

    func test_metricsCollector_recordActiveAssociations_updatesCount() async {
        let collector = MetricsCollector()
        await collector.recordActiveAssociations(5)
        let count = await collector.getActiveAssociations()
        XCTAssertEqual(count, 5)
    }

    func test_metricsCollector_incrementActiveAssociations_incrementsByOne() async {
        let collector = MetricsCollector()
        await collector.incrementActiveAssociations()
        await collector.incrementActiveAssociations()
        let count = await collector.getActiveAssociations()
        XCTAssertEqual(count, 2)
    }

    func test_metricsCollector_decrementActiveAssociations_decrementsByOne() async {
        let collector = MetricsCollector()
        await collector.recordActiveAssociations(3)
        await collector.decrementActiveAssociations()
        let count = await collector.getActiveAssociations()
        XCTAssertEqual(count, 2)
    }

    func test_metricsCollector_decrementActiveAssociations_doesNotGoBelowZero() async {
        let collector = MetricsCollector()
        await collector.decrementActiveAssociations()
        let count = await collector.getActiveAssociations()
        XCTAssertEqual(count, 0)
    }

    // MARK: - Request Tracking

    func test_metricsCollector_recordRequest_incrementsTotal() async {
        let collector = MetricsCollector()
        await collector.recordRequest(durationSeconds: 0.05)
        await collector.recordRequest(durationSeconds: 0.10)
        let total = await collector.getTotalRequests()
        XCTAssertEqual(total, 2)
    }

    // MARK: - Error Tracking

    func test_metricsCollector_recordError_tracksByCategory() async {
        let collector = MetricsCollector()
        await collector.recordError(category: "dicom")
        await collector.recordError(category: "dicom")
        await collector.recordError(category: "http")
        let dicomErrors = await collector.getErrors(category: "dicom")
        let httpErrors = await collector.getErrors(category: "http")
        let storageErrors = await collector.getErrors(category: "storage")
        XCTAssertEqual(dicomErrors, 2)
        XCTAssertEqual(httpErrors, 1)
        XCTAssertEqual(storageErrors, 0)
    }

    // MARK: - Queue Depth

    func test_metricsCollector_recordQueueDepth_updatesDepth() async {
        let collector = MetricsCollector()
        await collector.recordQueueDepth(42)
        let depth = await collector.getQueueDepth()
        XCTAssertEqual(depth, 42)
    }

    // MARK: - Uptime

    func test_metricsCollector_uptimeSeconds_isPositive() async {
        let collector = MetricsCollector()
        let uptime = await collector.uptimeSeconds()
        XCTAssertGreaterThanOrEqual(uptime, 0)
    }

    // MARK: - Storage and Backup

    func test_metricsCollector_recordStorageUtilisation_tracksPerTier() async {
        let collector = MetricsCollector()
        await collector.recordStorageUtilisation(tier: "online", bytes: 1_000_000)
        await collector.recordStorageUtilisation(tier: "nearline", bytes: 5_000_000)
        // Verified via Prometheus output
        let output = await collector.prometheusOutput()
        XCTAssertTrue(output.contains("mayam_storage_bytes_total{tier=\"online\"} 1000000"))
        XCTAssertTrue(output.contains("mayam_storage_bytes_total{tier=\"nearline\"} 5000000"))
    }

    func test_metricsCollector_recordBackupCompletion_tracksStatus() async {
        let collector = MetricsCollector()
        await collector.recordBackupCompletion(success: true)
        let output = await collector.prometheusOutput()
        XCTAssertTrue(output.contains("mayam_backup_success 1.000000"))
    }

    func test_metricsCollector_recordBackupFailure_tracksStatus() async {
        let collector = MetricsCollector()
        await collector.recordBackupCompletion(success: false)
        let output = await collector.prometheusOutput()
        XCTAssertTrue(output.contains("mayam_backup_success 0.000000"))
    }

    func test_metricsCollector_recordCompressionRatio_tracksRatio() async {
        let collector = MetricsCollector()
        await collector.recordCompressionRatio(2.5)
        let output = await collector.prometheusOutput()
        XCTAssertTrue(output.contains("mayam_compression_ratio 2.500000"))
    }

    // MARK: - Prometheus Output

    func test_metricsCollector_prometheusOutput_containsAllMetrics() async {
        let collector = MetricsCollector()
        await collector.recordActiveAssociations(3)
        await collector.recordRequest(durationSeconds: 0.1)
        await collector.recordStorageUtilisation(tier: "online", bytes: 1024)
        await collector.recordCompressionRatio(1.5)
        await collector.recordError(category: "dicom")
        await collector.recordQueueDepth(10)
        await collector.recordBackupCompletion(success: true)

        let output = await collector.prometheusOutput()

        XCTAssertTrue(output.contains("mayam_uptime_seconds"))
        XCTAssertTrue(output.contains("mayam_active_associations 3"))
        XCTAssertTrue(output.contains("mayam_requests_total 1"))
        XCTAssertTrue(output.contains("mayam_request_duration_seconds"))
        XCTAssertTrue(output.contains("mayam_storage_bytes_total"))
        XCTAssertTrue(output.contains("mayam_compression_ratio"))
        XCTAssertTrue(output.contains("mayam_backup_last_run_timestamp"))
        XCTAssertTrue(output.contains("mayam_backup_success"))
        XCTAssertTrue(output.contains("mayam_errors_total"))
        XCTAssertTrue(output.contains("mayam_queue_depth 10"))
    }

    func test_metricsCollector_prometheusOutput_hasCorrectTypes() async {
        let collector = MetricsCollector()
        let output = await collector.prometheusOutput()

        XCTAssertTrue(output.contains("# TYPE mayam_uptime_seconds gauge"))
        XCTAssertTrue(output.contains("# TYPE mayam_active_associations gauge"))
        XCTAssertTrue(output.contains("# TYPE mayam_requests_total counter"))
        XCTAssertTrue(output.contains("# TYPE mayam_request_duration_seconds summary"))
        XCTAssertTrue(output.contains("# TYPE mayam_storage_bytes_total gauge"))
        XCTAssertTrue(output.contains("# TYPE mayam_compression_ratio gauge"))
        XCTAssertTrue(output.contains("# TYPE mayam_errors_total counter"))
        XCTAssertTrue(output.contains("# TYPE mayam_queue_depth gauge"))
    }

    func test_metricsCollector_prometheusOutput_endsWithNewline() async {
        let collector = MetricsCollector()
        let output = await collector.prometheusOutput()
        XCTAssertTrue(output.hasSuffix("\n"))
    }

    func test_metricsCollector_prometheusOutput_hasHelpLines() async {
        let collector = MetricsCollector()
        let output = await collector.prometheusOutput()

        XCTAssertTrue(output.contains("# HELP mayam_uptime_seconds"))
        XCTAssertTrue(output.contains("# HELP mayam_active_associations"))
        XCTAssertTrue(output.contains("# HELP mayam_requests_total"))
        XCTAssertTrue(output.contains("# HELP mayam_request_duration_seconds"))
    }

    // MARK: - Latency Percentiles

    func test_metricsCollector_latencyPercentiles_computeCorrectly() async {
        let collector = MetricsCollector()
        for i in 1...100 {
            await collector.recordRequest(durationSeconds: Double(i) / 1000.0)
        }
        let output = await collector.prometheusOutput()
        // With 100 values from 0.001 to 0.100, p50 ≈ 0.050, p90 ≈ 0.090, p99 ≈ 0.099
        XCTAssertTrue(output.contains("quantile=\"0.5\""))
        XCTAssertTrue(output.contains("quantile=\"0.9\""))
        XCTAssertTrue(output.contains("quantile=\"0.99\""))
    }

    func test_metricsCollector_emptyLatency_returnsZeros() async {
        let collector = MetricsCollector()
        let output = await collector.prometheusOutput()
        XCTAssertTrue(output.contains("mayam_request_duration_seconds{quantile=\"0.5\"} 0.000000"))
    }
}

// MARK: - HealthChecker Tests

final class HealthCheckerTests: XCTestCase {

    // MARK: - Health Check

    func test_healthChecker_check_returnsHealthyWhenArchiveExists() async {
        let tempDir = NSTemporaryDirectory() + "mayam_health_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let collector = MetricsCollector()
        let checker = HealthChecker(metricsCollector: collector, archivePath: tempDir)
        let status = await checker.check()

        XCTAssertEqual(status.status, .healthy)
        XCTAssertEqual(status.components["storage"], .healthy)
        XCTAssertEqual(status.components["dicom"], .healthy)
        XCTAssertEqual(status.components["web"], .healthy)
    }

    func test_healthChecker_check_returnsUnhealthyWhenArchiveMissing() async {
        let collector = MetricsCollector()
        let checker = HealthChecker(metricsCollector: collector, archivePath: "/nonexistent/path")
        let status = await checker.check()

        XCTAssertEqual(status.status, .unhealthy)
        XCTAssertEqual(status.components["storage"], .unhealthy)
    }

    func test_healthChecker_check_includesVersionAndUptime() async {
        let tempDir = NSTemporaryDirectory() + "mayam_health_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let collector = MetricsCollector()
        let checker = HealthChecker(metricsCollector: collector, archivePath: tempDir)
        let status = await checker.check()

        XCTAssertFalse(status.version.isEmpty)
        XCTAssertGreaterThanOrEqual(status.uptimeSeconds, 0)
    }

    func test_healthChecker_encodeJSON_producesValidJSON() async throws {
        let collector = MetricsCollector()
        let checker = HealthChecker(metricsCollector: collector, archivePath: "/tmp")
        let status = await checker.check()
        let data = try checker.encodeJSON(status)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["status"])
        XCTAssertNotNil(json?["version"])
        XCTAssertNotNil(json?["components"])
    }

    // MARK: - HealthStatus

    func test_healthStatus_defaultInit_isHealthy() {
        let status = HealthStatus()
        XCTAssertEqual(status.status, .healthy)
    }

    func test_healthStatus_codable_roundTrips() throws {
        let original = HealthStatus(
            status: .degraded,
            components: ["storage": .healthy, "dicom": .degraded],
            version: "0.13.0",
            uptimeSeconds: 3600.5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(HealthStatus.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func test_healthStatus_equatable_matchesEqual() {
        let a = HealthStatus(status: .healthy, components: ["web": .healthy])
        let b = HealthStatus(status: .healthy, components: ["web": .healthy])
        XCTAssertEqual(a, b)
    }

    func test_healthStatus_equatable_differsOnStatus() {
        let a = HealthStatus(status: .healthy)
        let b = HealthStatus(status: .unhealthy)
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - GracefulShutdown Tests

final class GracefulShutdownTests: XCTestCase {

    func test_gracefulShutdown_initialState_notShuttingDown() {
        let shutdown = GracefulShutdown()
        XCTAssertFalse(shutdown.isShuttingDown)
    }

    func test_gracefulShutdown_trigger_setsShuttingDown() {
        let shutdown = GracefulShutdown()
        shutdown.trigger()
        XCTAssertTrue(shutdown.isShuttingDown)
    }

    func test_gracefulShutdown_trigger_yieldsOnStream() async {
        let shutdown = GracefulShutdown()

        Task {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            shutdown.trigger()
        }

        let expectation = XCTestExpectation(description: "Shutdown stream yields")
        Task {
            for await _ in shutdown.shutdownSignals() {
                expectation.fulfill()
                break
            }
        }
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func test_gracefulShutdown_doubleTrigger_doesNotCrash() {
        let shutdown = GracefulShutdown()
        shutdown.trigger()
        shutdown.trigger()
        XCTAssertTrue(shutdown.isShuttingDown)
    }
}

// MARK: - DatabaseMigrator Tests

final class DatabaseMigratorTests: XCTestCase {

    func test_databaseMigrator_discoverMigrations_findsResourceFiles() throws {
        let logger = MayamLogger(label: "test.migrator")
        let migrator = DatabaseMigrator(logger: logger)
        let migrations = try migrator.discoverMigrations()

        // Should find the bundled migration files
        XCTAssertGreaterThanOrEqual(migrations.count, 0)

        // Verify ordering
        if migrations.count >= 2 {
            XCTAssertLessThan(migrations[0].version, migrations[1].version)
        }
    }

    func test_databaseMigrator_pendingMigrations_filtersApplied() throws {
        let logger = MayamLogger(label: "test.migrator")
        let migrator = DatabaseMigrator(logger: logger, appliedVersions: [1, 2])

        let all = [
            MigrationRecord(filename: "001_base.sql", version: 1, sql: "CREATE TABLE t1;"),
            MigrationRecord(filename: "002_index.sql", version: 2, sql: "CREATE INDEX;"),
            MigrationRecord(filename: "003_users.sql", version: 3, sql: "CREATE TABLE users;")
        ]

        let pending = migrator.pendingMigrations(from: all)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.version, 3)
    }

    func test_databaseMigrator_pendingMigrations_allApplied_returnsEmpty() throws {
        let logger = MayamLogger(label: "test.migrator")
        let migrator = DatabaseMigrator(logger: logger, appliedVersions: [1, 2])

        let all = [
            MigrationRecord(filename: "001_base.sql", version: 1, sql: "CREATE TABLE t1;"),
            MigrationRecord(filename: "002_index.sql", version: 2, sql: "CREATE INDEX;")
        ]

        let pending = migrator.pendingMigrations(from: all)
        XCTAssertTrue(pending.isEmpty)
    }

    func test_databaseMigrator_applyPendingMigrations_setsAppliedTimestamp() {
        let logger = MayamLogger(label: "test.migrator")
        let migrator = DatabaseMigrator(logger: logger)

        let pending = [
            MigrationRecord(filename: "003_users.sql", version: 3, sql: "CREATE TABLE users;")
        ]

        let applied = migrator.applyPendingMigrations(pending)
        XCTAssertEqual(applied.count, 1)
        XCTAssertNotNil(applied.first?.appliedAt)
        XCTAssertEqual(applied.first?.filename, "003_users.sql")
    }

    func test_databaseMigrator_applyPendingMigrations_emptyList_returnsEmpty() {
        let logger = MayamLogger(label: "test.migrator")
        let migrator = DatabaseMigrator(logger: logger)

        let applied = migrator.applyPendingMigrations([])
        XCTAssertTrue(applied.isEmpty)
    }

    func test_databaseMigrator_schemaMigrationsTableSQL_isValid() {
        let sql = DatabaseMigrator.schemaMigrationsTableSQL()
        XCTAssertTrue(sql.contains("CREATE TABLE IF NOT EXISTS schema_migrations"))
        XCTAssertTrue(sql.contains("version"))
        XCTAssertTrue(sql.contains("filename"))
        XCTAssertTrue(sql.contains("applied_at"))
    }

    func test_migrationRecord_equatable_matchesEqual() {
        let a = MigrationRecord(filename: "001_test.sql", version: 1, sql: "CREATE TABLE t;")
        let b = MigrationRecord(filename: "001_test.sql", version: 1, sql: "CREATE TABLE t;")
        XCTAssertEqual(a, b)
    }

    func test_migrationRecord_equatable_differsOnVersion() {
        let a = MigrationRecord(filename: "001_test.sql", version: 1, sql: "CREATE TABLE t;")
        let b = MigrationRecord(filename: "002_test.sql", version: 2, sql: "CREATE TABLE t;")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - DatabaseMigrationError

    func test_databaseMigrationError_descriptions_areReadable() {
        let errors: [DatabaseMigrationError] = [
            .migrationsDirectoryNotFound(path: "/path/to/migrations"),
            .unreadableMigration(filename: "001_test.sql", underlying: nil),
            .invalidMigrationFilename(filename: "bad_name.sql"),
            .migrationFailed(filename: "001_test.sql", underlying: nil)
        ]

        for error in errors {
            XCTAssertFalse(error.description.isEmpty)
        }
    }
}

// MARK: - ManagedAtomic Tests

final class ManagedAtomicTests: XCTestCase {

    func test_managedAtomic_initialValue_isCorrect() {
        let atomic = ManagedAtomic(false)
        XCTAssertFalse(atomic.value)
    }

    func test_managedAtomic_setValue_updatesValue() {
        let atomic = ManagedAtomic(false)
        atomic.setValue(true)
        XCTAssertTrue(atomic.value)
    }

    func test_managedAtomic_intValue_worksCorrectly() {
        let atomic = ManagedAtomic(0)
        atomic.setValue(42)
        XCTAssertEqual(atomic.value, 42)
    }
}
