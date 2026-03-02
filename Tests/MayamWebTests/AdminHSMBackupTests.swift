// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin HSM & Backup Tests

import XCTest
import Foundation
@testable import MayamWeb
import MayamCore

// MARK: - HSMStatus Tests

final class HSMStatusTests: XCTestCase {

    func test_hsmStatus_init_setsProperties() {
        let status = HSMStatus(
            enabled: true,
            tierCount: 3,
            migrationRuleCount: 2,
            migrationScanIntervalSeconds: 1800
        )
        XCTAssertTrue(status.enabled)
        XCTAssertEqual(status.tierCount, 3)
        XCTAssertEqual(status.migrationRuleCount, 2)
        XCTAssertEqual(status.migrationScanIntervalSeconds, 1800)
    }

    func test_hsmStatus_codable_roundTrips() throws {
        let status = HSMStatus(
            enabled: false,
            tierCount: 1,
            migrationRuleCount: 0,
            migrationScanIntervalSeconds: 3600
        )
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(HSMStatus.self, from: data)
        XCTAssertEqual(decoded.enabled, status.enabled)
        XCTAssertEqual(decoded.tierCount, status.tierCount)
    }
}

// MARK: - AdminBackupStatus Tests

final class AdminBackupStatusTests: XCTestCase {

    func test_adminBackupStatus_init_setsProperties() {
        let status = AdminBackupStatus(
            enabled: true,
            targetCount: 2,
            enabledTargetCount: 1,
            scheduleIntervalSeconds: 86400
        )
        XCTAssertTrue(status.enabled)
        XCTAssertEqual(status.targetCount, 2)
        XCTAssertEqual(status.enabledTargetCount, 1)
        XCTAssertEqual(status.scheduleIntervalSeconds, 86400)
    }

    func test_adminBackupStatus_codable_roundTrips() throws {
        let status = AdminBackupStatus(
            enabled: false,
            targetCount: 0,
            enabledTargetCount: 0,
            scheduleIntervalSeconds: 43200
        )
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(AdminBackupStatus.self, from: data)
        XCTAssertEqual(decoded.enabled, status.enabled)
        XCTAssertEqual(decoded.scheduleIntervalSeconds, status.scheduleIntervalSeconds)
    }
}

// MARK: - AdminStorageHandler HSM/Backup Tests

final class AdminStorageHandlerHSMBackupTests: XCTestCase {

    func test_getHSMStatus_returnsCorrectValues() async {
        let handler = AdminStorageHandler()
        let config = ServerConfiguration.HSM(
            enabled: true,
            tiers: [
                StorageTierConfiguration(tier: .online, path: "/fast"),
                StorageTierConfiguration(tier: .nearLine, path: "/slow")
            ],
            migrationRules: [
                MigrationRule(trigger: .ageDays(90), targetTier: .nearLine)
            ],
            migrationScanIntervalSeconds: 1800
        )

        let status = await handler.getHSMStatus(hsmConfig: config)
        XCTAssertTrue(status.enabled)
        XCTAssertEqual(status.tierCount, 2)
        XCTAssertEqual(status.migrationRuleCount, 1)
        XCTAssertEqual(status.migrationScanIntervalSeconds, 1800)
    }

    func test_getBackupStatus_returnsCorrectValues() async {
        let handler = AdminStorageHandler()
        let config = ServerConfiguration.Backup(
            enabled: true,
            targets: [
                BackupTarget(name: "A", targetType: .local, destinationPath: "/a", enabled: true),
                BackupTarget(name: "B", targetType: .network, destinationPath: "/b", enabled: false)
            ],
            schedule: BackupSchedule(intervalSeconds: 43200)
        )

        let status = await handler.getBackupStatus(backupConfig: config)
        XCTAssertTrue(status.enabled)
        XCTAssertEqual(status.targetCount, 2)
        XCTAssertEqual(status.enabledTargetCount, 1)
        XCTAssertEqual(status.scheduleIntervalSeconds, 43200)
    }

    func test_getHSMStatus_disabled_returnsDefaults() async {
        let handler = AdminStorageHandler()
        let config = ServerConfiguration.HSM()

        let status = await handler.getHSMStatus(hsmConfig: config)
        XCTAssertFalse(status.enabled)
        XCTAssertEqual(status.tierCount, 0)
    }

    func test_getBackupStatus_disabled_returnsDefaults() async {
        let handler = AdminStorageHandler()
        let config = ServerConfiguration.Backup()

        let status = await handler.getBackupStatus(backupConfig: config)
        XCTAssertFalse(status.enabled)
        XCTAssertEqual(status.targetCount, 0)
    }
}
