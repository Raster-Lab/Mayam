// SPDX-License-Identifier: (see LICENSE)
// Mayam — Near-Line Storage & Backup Tests

import XCTest
import Foundation
import Crypto
@testable import MayamCore

// MARK: - StorageTier Tests

final class StorageTierTests: XCTestCase {

    func test_storageTier_allCases_hasThreeTiers() {
        XCTAssertEqual(StorageTier.allCases.count, 3)
        XCTAssertTrue(StorageTier.allCases.contains(.online))
        XCTAssertTrue(StorageTier.allCases.contains(.nearLine))
        XCTAssertTrue(StorageTier.allCases.contains(.archive))
    }

    func test_storageTier_rawValues_areCorrect() {
        XCTAssertEqual(StorageTier.online.rawValue, "online")
        XCTAssertEqual(StorageTier.nearLine.rawValue, "nearLine")
        XCTAssertEqual(StorageTier.archive.rawValue, "archive")
    }

    func test_storageTier_codable_roundTrips() throws {
        let tier = StorageTier.nearLine
        let data = try JSONEncoder().encode(tier)
        let decoded = try JSONDecoder().decode(StorageTier.self, from: data)
        XCTAssertEqual(decoded, tier)
    }

    func test_storageTierConfiguration_init_setsProperties() {
        let config = StorageTierConfiguration(
            tier: .nearLine,
            path: "/mnt/nearline",
            maxCapacityBytes: 1_000_000_000
        )
        XCTAssertEqual(config.tier, .nearLine)
        XCTAssertEqual(config.path, "/mnt/nearline")
        XCTAssertEqual(config.maxCapacityBytes, 1_000_000_000)
    }

    func test_storageTierConfiguration_defaultCapacity_isNil() {
        let config = StorageTierConfiguration(tier: .archive, path: "/archive")
        XCTAssertNil(config.maxCapacityBytes)
    }

    func test_storageTierConfiguration_codable_roundTrips() throws {
        let config = StorageTierConfiguration(
            tier: .online,
            path: "/fast-ssd",
            maxCapacityBytes: 500_000_000
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(StorageTierConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
    }
}

// MARK: - MigrationRule Tests

final class MigrationRuleTests: XCTestCase {

    func test_migrationRule_ageDaysTrigger_setsProperties() {
        let rule = MigrationRule(trigger: .ageDays(90), targetTier: .nearLine)
        XCTAssertEqual(rule.targetTier, .nearLine)
        if case .ageDays(let days) = rule.trigger {
            XCTAssertEqual(days, 90)
        } else {
            XCTFail("Expected ageDays trigger")
        }
    }

    func test_migrationRule_lastAccessDaysTrigger_setsProperties() {
        let rule = MigrationRule(trigger: .lastAccessDays(30), targetTier: .archive)
        XCTAssertEqual(rule.targetTier, .archive)
        if case .lastAccessDays(let days) = rule.trigger {
            XCTAssertEqual(days, 30)
        } else {
            XCTFail("Expected lastAccessDays trigger")
        }
    }

    func test_migrationRule_modalityTrigger_setsProperties() {
        let rule = MigrationRule(trigger: .modality("CR"), targetTier: .nearLine)
        if case .modality(let mod) = rule.trigger {
            XCTAssertEqual(mod, "CR")
        } else {
            XCTFail("Expected modality trigger")
        }
    }

    func test_migrationRule_studyStatusTrigger_setsProperties() {
        let rule = MigrationRule(trigger: .studyStatus("completed"), targetTier: .archive)
        if case .studyStatus(let status) = rule.trigger {
            XCTAssertEqual(status, "completed")
        } else {
            XCTFail("Expected studyStatus trigger")
        }
    }

    func test_migrationRule_codable_roundTrips() throws {
        let rule = MigrationRule(trigger: .ageDays(60), targetTier: .nearLine)
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(MigrationRule.self, from: data)
        XCTAssertEqual(decoded, rule)
    }
}

// MARK: - HSMConfiguration Tests

final class HSMConfigurationTests: XCTestCase {

    func test_hsmConfiguration_default_isDisabled() {
        let config = HSMConfiguration.default
        XCTAssertFalse(config.enabled)
        XCTAssertTrue(config.tiers.isEmpty)
        XCTAssertTrue(config.migrationRules.isEmpty)
        XCTAssertEqual(config.migrationScanIntervalSeconds, 3600)
    }

    func test_hsmConfiguration_customInit_setsProperties() {
        let tiers = [
            StorageTierConfiguration(tier: .online, path: "/fast"),
            StorageTierConfiguration(tier: .nearLine, path: "/slow")
        ]
        let rules = [MigrationRule(trigger: .ageDays(90), targetTier: .nearLine)]
        let config = HSMConfiguration(
            enabled: true,
            tiers: tiers,
            migrationRules: rules,
            migrationScanIntervalSeconds: 7200
        )
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.tiers.count, 2)
        XCTAssertEqual(config.migrationRules.count, 1)
        XCTAssertEqual(config.migrationScanIntervalSeconds, 7200)
    }

    func test_hsmConfiguration_codable_roundTrips() throws {
        let config = HSMConfiguration(
            enabled: true,
            tiers: [StorageTierConfiguration(tier: .online, path: "/fast")],
            migrationRules: [MigrationRule(trigger: .lastAccessDays(30), targetTier: .archive)],
            migrationScanIntervalSeconds: 1800
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(HSMConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
    }
}

// MARK: - StudyTierRecord Tests

final class StudyTierRecordTests: XCTestCase {

    func test_studyTierRecord_init_setsProperties() {
        let now = Date()
        let record = StudyTierRecord(
            studyInstanceUID: "1.2.3.4",
            currentTier: .online,
            currentPath: "/archive/1.2.3.4",
            lastAccessedAt: now,
            migratedAt: now,
            studyDate: now,
            modality: "CT"
        )
        XCTAssertEqual(record.studyInstanceUID, "1.2.3.4")
        XCTAssertEqual(record.currentTier, .online)
        XCTAssertEqual(record.currentPath, "/archive/1.2.3.4")
        XCTAssertEqual(record.lastAccessedAt, now)
        XCTAssertEqual(record.migratedAt, now)
        XCTAssertEqual(record.studyDate, now)
        XCTAssertEqual(record.modality, "CT")
    }

    func test_studyTierRecord_optionalFields_defaultToNil() {
        let record = StudyTierRecord(
            studyInstanceUID: "1.2.3",
            currentTier: .nearLine,
            currentPath: "/nearline/1.2.3",
            lastAccessedAt: Date(),
            migratedAt: Date()
        )
        XCTAssertNil(record.studyDate)
        XCTAssertNil(record.modality)
    }

    func test_studyTierRecord_codable_roundTrips() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let record = StudyTierRecord(
            studyInstanceUID: "1.2.3",
            currentTier: .archive,
            currentPath: "/archive/1.2.3",
            lastAccessedAt: Date(),
            migratedAt: Date(),
            modality: "MR"
        )
        let data = try encoder.encode(record)
        let decoded = try decoder.decode(StudyTierRecord.self, from: data)
        XCTAssertEqual(decoded.studyInstanceUID, record.studyInstanceUID)
        XCTAssertEqual(decoded.currentTier, record.currentTier)
    }
}

// MARK: - HSMEngine Tests

final class HSMEngineTests: XCTestCase {

    private func makeEngine(
        enabled: Bool = true,
        tiers: [StorageTierConfiguration] = [
            StorageTierConfiguration(tier: .online, path: "/online"),
            StorageTierConfiguration(tier: .nearLine, path: "/nearline")
        ],
        migrationRules: [MigrationRule] = []
    ) -> HSMEngine {
        let config = HSMConfiguration(
            enabled: enabled,
            tiers: tiers,
            migrationRules: migrationRules
        )
        return HSMEngine(
            configuration: config,
            logger: MayamLogger(label: "test.hsm")
        )
    }

    func test_hsmEngine_registerStudy_tracksStudy() async {
        let engine = makeEngine()
        await engine.registerStudy(studyInstanceUID: "1.2.3", path: "/online/1.2.3")

        let count = await engine.trackedStudyCount()
        XCTAssertEqual(count, 1)

        let record = await engine.getTierRecord(for: "1.2.3")
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.currentTier, .online)
        XCTAssertEqual(record?.currentPath, "/online/1.2.3")
    }

    func test_hsmEngine_registerStudy_withMetadata_setsFields() async {
        let engine = makeEngine()
        let studyDate = Date()
        await engine.registerStudy(
            studyInstanceUID: "1.2.3",
            path: "/online/1.2.3",
            studyDate: studyDate,
            modality: "CT"
        )

        let record = await engine.getTierRecord(for: "1.2.3")
        XCTAssertNotNil(record?.studyDate)
        XCTAssertEqual(record?.modality, "CT")
    }

    func test_hsmEngine_getTierRecord_returnsNilForUnknownStudy() async {
        let engine = makeEngine()
        let record = await engine.getTierRecord(for: "unknown")
        XCTAssertNil(record)
    }

    func test_hsmEngine_getAllTierRecords_returnsAll() async {
        let engine = makeEngine()
        await engine.registerStudy(studyInstanceUID: "1.2.3", path: "/online/1.2.3")
        await engine.registerStudy(studyInstanceUID: "4.5.6", path: "/online/4.5.6")

        let records = await engine.getAllTierRecords()
        XCTAssertEqual(records.count, 2)
    }

    func test_hsmEngine_accessStudy_updatesLastAccess() async throws {
        let engine = makeEngine()
        await engine.registerStudy(studyInstanceUID: "1.2.3", path: "/online/1.2.3")

        let before = await engine.getTierRecord(for: "1.2.3")
        // Small delay to ensure time difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let path = try await engine.accessStudy(studyInstanceUID: "1.2.3")
        let after = await engine.getTierRecord(for: "1.2.3")

        XCTAssertNotNil(path)
        XCTAssertNotNil(before)
        XCTAssertNotNil(after)
        XCTAssertTrue(after!.lastAccessedAt >= before!.lastAccessedAt)
    }

    func test_hsmEngine_accessStudy_unknownReturnsNil() async throws {
        let engine = makeEngine()
        let path = try await engine.accessStudy(studyInstanceUID: "unknown")
        XCTAssertNil(path)
    }

    func test_hsmEngine_migrateStudy_updatesTier() async throws {
        let engine = makeEngine()
        await engine.registerStudy(studyInstanceUID: "1.2.3", path: "/online/1.2.3")

        try await engine.migrateStudy("1.2.3", to: .nearLine, newPath: "/nearline/1.2.3")

        let record = await engine.getTierRecord(for: "1.2.3")
        XCTAssertEqual(record?.currentTier, .nearLine)
        XCTAssertEqual(record?.currentPath, "/nearline/1.2.3")
    }

    func test_hsmEngine_migrateStudy_unknownThrows() async {
        let engine = makeEngine()
        do {
            try await engine.migrateStudy("unknown", to: .nearLine, newPath: "/nearline/unknown")
            XCTFail("Expected HSMError.studyNotFound")
        } catch let error as HSMError {
            if case .studyNotFound(let uid) = error {
                XCTAssertEqual(uid, "unknown")
            } else {
                XCTFail("Expected studyNotFound error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_hsmEngine_migrateStudy_recordsMigrationHistory() async throws {
        let engine = makeEngine()
        await engine.registerStudy(studyInstanceUID: "1.2.3", path: "/online/1.2.3")
        try await engine.migrateStudy("1.2.3", to: .nearLine, newPath: "/nearline/1.2.3")

        let history = await engine.getMigrationHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].studyInstanceUID, "1.2.3")
        XCTAssertEqual(history[0].sourceTier, .online)
        XCTAssertEqual(history[0].targetTier, .nearLine)
    }

    func test_hsmEngine_evaluateMigrationCandidates_disabled_returnsEmpty() async {
        let engine = makeEngine(enabled: false)
        await engine.registerStudy(studyInstanceUID: "1.2.3", path: "/online/1.2.3")

        let candidates = await engine.evaluateMigrationCandidates()
        XCTAssertTrue(candidates.isEmpty)
    }

    func test_hsmEngine_evaluateMigrationCandidates_ageDays_findsExpired() async {
        let rules = [MigrationRule(trigger: .ageDays(0), targetTier: .nearLine)]
        let engine = makeEngine(migrationRules: rules)
        await engine.registerStudy(
            studyInstanceUID: "1.2.3",
            path: "/online/1.2.3",
            studyDate: Date().addingTimeInterval(-86400) // 1 day ago
        )

        let candidates = await engine.evaluateMigrationCandidates()
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].studyInstanceUID, "1.2.3")
        XCTAssertEqual(candidates[0].targetTier, .nearLine)
    }

    func test_hsmEngine_evaluateMigrationCandidates_modality_matchesCorrectly() async {
        let rules = [MigrationRule(trigger: .modality("CR"), targetTier: .archive)]
        let engine = makeEngine(migrationRules: rules)
        await engine.registerStudy(
            studyInstanceUID: "1.2.3",
            path: "/online/1.2.3",
            modality: "CR"
        )
        await engine.registerStudy(
            studyInstanceUID: "4.5.6",
            path: "/online/4.5.6",
            modality: "CT"
        )

        let candidates = await engine.evaluateMigrationCandidates()
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].studyInstanceUID, "1.2.3")
    }

    func test_hsmEngine_evaluateMigrationCandidates_skipsSameTier() async {
        let rules = [MigrationRule(trigger: .modality("CR"), targetTier: .online)]
        let engine = makeEngine(migrationRules: rules)
        await engine.registerStudy(
            studyInstanceUID: "1.2.3",
            path: "/online/1.2.3",
            modality: "CR"
        )

        let candidates = await engine.evaluateMigrationCandidates()
        XCTAssertTrue(candidates.isEmpty)
    }

    func test_hsmEngine_accessStudy_recallsFromNearLine() async throws {
        let engine = makeEngine()
        await engine.registerStudy(studyInstanceUID: "1.2.3", path: "/online/1.2.3")
        try await engine.migrateStudy("1.2.3", to: .nearLine, newPath: "/nearline/1.2.3")

        let path = try await engine.accessStudy(studyInstanceUID: "1.2.3")
        let record = await engine.getTierRecord(for: "1.2.3")

        XCTAssertNotNil(path)
        XCTAssertEqual(record?.currentTier, .online)
    }
}

// MARK: - HSMError Tests

final class HSMErrorTests: XCTestCase {

    func test_hsmError_studyNotFound_description() {
        let error = HSMError.studyNotFound(studyInstanceUID: "1.2.3")
        XCTAssertTrue(error.description.contains("1.2.3"))
    }

    func test_hsmError_tierNotConfigured_description() {
        let error = HSMError.tierNotConfigured(tier: .nearLine)
        XCTAssertTrue(error.description.contains("nearLine"))
    }

    func test_hsmError_migrationFailed_description() {
        let error = HSMError.migrationFailed(studyInstanceUID: "1.2.3", reason: "disk full")
        XCTAssertTrue(error.description.contains("1.2.3"))
        XCTAssertTrue(error.description.contains("disk full"))
    }

    func test_hsmError_recallFailed_description() {
        let error = HSMError.recallFailed(studyInstanceUID: "1.2.3", reason: "timeout")
        XCTAssertTrue(error.description.contains("1.2.3"))
        XCTAssertTrue(error.description.contains("timeout"))
    }
}

// MARK: - BackupConfiguration Tests

final class BackupConfigurationTests: XCTestCase {

    func test_backupTargetType_allCases_hasThreeTypes() {
        XCTAssertEqual(BackupTargetType.allCases.count, 3)
        XCTAssertTrue(BackupTargetType.allCases.contains(.local))
        XCTAssertTrue(BackupTargetType.allCases.contains(.network))
        XCTAssertTrue(BackupTargetType.allCases.contains(.s3))
    }

    func test_backupTarget_init_setsProperties() {
        let target = BackupTarget(
            name: "Local Backup",
            targetType: .local,
            destinationPath: "/backups"
        )
        XCTAssertEqual(target.name, "Local Backup")
        XCTAssertEqual(target.targetType, .local)
        XCTAssertEqual(target.destinationPath, "/backups")
        XCTAssertTrue(target.enabled)
    }

    func test_backupTarget_codable_roundTrips() throws {
        let target = BackupTarget(
            name: "NAS",
            targetType: .network,
            destinationPath: "//server/share",
            enabled: false
        )
        let data = try JSONEncoder().encode(target)
        let decoded = try JSONDecoder().decode(BackupTarget.self, from: data)
        XCTAssertEqual(decoded.name, target.name)
        XCTAssertEqual(decoded.targetType, target.targetType)
        XCTAssertEqual(decoded.destinationPath, target.destinationPath)
        XCTAssertEqual(decoded.enabled, target.enabled)
    }

    func test_backupSchedule_defaults_are24Hours() {
        let schedule = BackupSchedule()
        XCTAssertEqual(schedule.intervalSeconds, 86_400)
        XCTAssertTrue(schedule.includeDatabase)
        XCTAssertTrue(schedule.includeDICOMObjects)
    }

    func test_backupConfiguration_default_isDisabled() {
        let config = BackupConfiguration.default
        XCTAssertFalse(config.enabled)
        XCTAssertTrue(config.targets.isEmpty)
    }

    func test_backupStatus_allCases() {
        XCTAssertEqual(BackupStatus.allCases.count, 4)
        XCTAssertEqual(BackupStatus.running.rawValue, "running")
        XCTAssertEqual(BackupStatus.completed.rawValue, "completed")
        XCTAssertEqual(BackupStatus.failed.rawValue, "failed")
        XCTAssertEqual(BackupStatus.cancelled.rawValue, "cancelled")
    }

    func test_backupRecord_init_setsDefaults() {
        let record = BackupRecord(targetID: UUID(), startedAt: Date())
        XCTAssertEqual(record.status, .running)
        XCTAssertEqual(record.objectCount, 0)
        XCTAssertEqual(record.sizeBytes, 0)
        XCTAssertNil(record.completedAt)
        XCTAssertNil(record.errorMessage)
    }
}

// MARK: - BackupManager Tests

final class BackupManagerTests: XCTestCase {

    private func makeTmpDir() throws -> String {
        let tmp = NSTemporaryDirectory() + "mayam_backup_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        return tmp
    }

    func test_backupManager_runBackup_local_copiesFiles() async throws {
        let archivePath = try makeTmpDir()
        let backupPath = try makeTmpDir()
        defer {
            try? FileManager.default.removeItem(atPath: archivePath)
            try? FileManager.default.removeItem(atPath: backupPath)
        }

        // Create a test .dcm file
        let subDir = archivePath + "/PAT001/1.2.3/1.2.3.4"
        try FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true)
        try Data("test-dicom-data".utf8).write(to: URL(fileURLWithPath: subDir + "/1.2.3.4.5.dcm"))

        let target = BackupTarget(name: "Test", targetType: .local, destinationPath: backupPath)
        let config = BackupConfiguration(enabled: true, targets: [target])
        let manager = BackupManager(
            configuration: config,
            archivePath: archivePath,
            logger: MayamLogger(label: "test.backup")
        )

        let record = try await manager.runBackup(to: target)
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.objectCount, 1)
        XCTAssertTrue(record.sizeBytes > 0)
        XCTAssertNotNil(record.completedAt)
    }

    func test_backupManager_runBackup_emptyArchive_succeeds() async throws {
        let archivePath = try makeTmpDir()
        let backupPath = try makeTmpDir()
        defer {
            try? FileManager.default.removeItem(atPath: archivePath)
            try? FileManager.default.removeItem(atPath: backupPath)
        }

        let target = BackupTarget(name: "Empty", targetType: .local, destinationPath: backupPath)
        let config = BackupConfiguration(enabled: true, targets: [target])
        let manager = BackupManager(
            configuration: config,
            archivePath: archivePath,
            logger: MayamLogger(label: "test.backup")
        )

        let record = try await manager.runBackup(to: target)
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.objectCount, 0)
    }

    func test_backupManager_getBackupHistory_returnsRecords() async throws {
        let archivePath = try makeTmpDir()
        let backupPath = try makeTmpDir()
        defer {
            try? FileManager.default.removeItem(atPath: archivePath)
            try? FileManager.default.removeItem(atPath: backupPath)
        }

        let target = BackupTarget(name: "Test", targetType: .local, destinationPath: backupPath)
        let config = BackupConfiguration(enabled: true, targets: [target])
        let manager = BackupManager(
            configuration: config,
            archivePath: archivePath,
            logger: MayamLogger(label: "test.backup")
        )

        _ = try await manager.runBackup(to: target)
        let history = await manager.getBackupHistory()
        XCTAssertEqual(history.count, 1)
    }

    func test_backupManager_completedBackupCount_countsCompleted() async throws {
        let archivePath = try makeTmpDir()
        let backupPath = try makeTmpDir()
        defer {
            try? FileManager.default.removeItem(atPath: archivePath)
            try? FileManager.default.removeItem(atPath: backupPath)
        }

        let target = BackupTarget(name: "Test", targetType: .local, destinationPath: backupPath)
        let config = BackupConfiguration(enabled: true, targets: [target])
        let manager = BackupManager(
            configuration: config,
            archivePath: archivePath,
            logger: MayamLogger(label: "test.backup")
        )

        _ = try await manager.runBackup(to: target)
        let count = await manager.completedBackupCount()
        XCTAssertEqual(count, 1)
    }

    func test_backupManager_runScheduledBackups_runsEnabledTargets() async throws {
        let archivePath = try makeTmpDir()
        let backupPath = try makeTmpDir()
        defer {
            try? FileManager.default.removeItem(atPath: archivePath)
            try? FileManager.default.removeItem(atPath: backupPath)
        }

        let enabledTarget = BackupTarget(name: "Enabled", targetType: .local, destinationPath: backupPath, enabled: true)
        let disabledTarget = BackupTarget(name: "Disabled", targetType: .local, destinationPath: backupPath, enabled: false)
        let config = BackupConfiguration(enabled: true, targets: [enabledTarget, disabledTarget])
        let manager = BackupManager(
            configuration: config,
            archivePath: archivePath,
            logger: MayamLogger(label: "test.backup")
        )

        let records = await manager.runScheduledBackups()
        XCTAssertEqual(records.count, 1)
    }

    func test_backupManager_networkBackup_delegatesToLocal() async throws {
        let archivePath = try makeTmpDir()
        let backupPath = try makeTmpDir()
        defer {
            try? FileManager.default.removeItem(atPath: archivePath)
            try? FileManager.default.removeItem(atPath: backupPath)
        }

        let target = BackupTarget(name: "Network", targetType: .network, destinationPath: backupPath)
        let config = BackupConfiguration(enabled: true, targets: [target])
        let manager = BackupManager(
            configuration: config,
            archivePath: archivePath,
            logger: MayamLogger(label: "test.backup")
        )

        let record = try await manager.runBackup(to: target)
        XCTAssertEqual(record.status, .completed)
    }
}

// MARK: - BackupError Tests

final class BackupErrorTests: XCTestCase {

    func test_backupError_alreadyRunning_description() {
        let error = BackupError.backupAlreadyRunning
        XCTAssertTrue(error.description.contains("already in progress"))
    }

    func test_backupError_sourceNotAccessible_description() {
        let error = BackupError.sourceNotAccessible(path: "/archive")
        XCTAssertTrue(error.description.contains("/archive"))
    }

    func test_backupError_targetNotAccessible_description() {
        let error = BackupError.targetNotAccessible(path: "/backup")
        XCTAssertTrue(error.description.contains("/backup"))
    }

    func test_backupError_copyFailed_description() {
        let error = BackupError.copyFailed(source: "/a", destination: "/b", reason: "disk full")
        XCTAssertTrue(error.description.contains("disk full"))
    }
}

// MARK: - StorageCommitmentSCP Tests

final class StorageCommitmentSCPTests: XCTestCase {

    func test_storageCommitmentSCP_sopClassUID_isCorrect() {
        XCTAssertEqual(StorageCommitmentSCP.sopClassUID, "1.2.840.10008.1.20.1")
    }

    func test_storageCommitmentSCP_processCommitment_allExist_allSuccess() async {
        let scp = StorageCommitmentSCP(
            instanceExistsCheck: { _ in true },
            logger: MayamLogger(label: "test.commitment")
        )

        let result = await scp.processCommitmentRequest(
            transactionUID: "1.2.3.999",
            referencedInstances: [
                (sopClassUID: "1.2.840.10008.5.1.4.1.1.2", sopInstanceUID: "1.2.3.4.5"),
                (sopClassUID: "1.2.840.10008.5.1.4.1.1.2", sopInstanceUID: "1.2.3.4.6")
            ]
        )

        XCTAssertEqual(result.transactionUID, "1.2.3.999")
        XCTAssertEqual(result.successInstances.count, 2)
        XCTAssertEqual(result.failedInstances.count, 0)
    }

    func test_storageCommitmentSCP_processCommitment_someMissing_partialFailure() async {
        let scp = StorageCommitmentSCP(
            instanceExistsCheck: { uid in uid == "1.2.3.4.5" },
            logger: MayamLogger(label: "test.commitment")
        )

        let result = await scp.processCommitmentRequest(
            transactionUID: "1.2.3.888",
            referencedInstances: [
                (sopClassUID: "1.2.840.10008.5.1.4.1.1.2", sopInstanceUID: "1.2.3.4.5"),
                (sopClassUID: "1.2.840.10008.5.1.4.1.1.2", sopInstanceUID: "missing.uid")
            ]
        )

        XCTAssertEqual(result.successInstances.count, 1)
        XCTAssertEqual(result.failedInstances.count, 1)
        XCTAssertEqual(result.failedInstances[0].sopInstanceUID, "missing.uid")
        XCTAssertEqual(result.failedInstances[0].failureReason, StorageCommitmentSCP.failureReasonNoSuchInstance)
    }

    func test_storageCommitmentSCP_processCommitment_noneMissing_allFail() async {
        let scp = StorageCommitmentSCP(
            instanceExistsCheck: { _ in false },
            logger: MayamLogger(label: "test.commitment")
        )

        let result = await scp.processCommitmentRequest(
            transactionUID: "1.2.3.777",
            referencedInstances: [
                (sopClassUID: "1.2.840.10008.5.1.4.1.1.2", sopInstanceUID: "1.2.3.4.5")
            ]
        )

        XCTAssertEqual(result.successInstances.count, 0)
        XCTAssertEqual(result.failedInstances.count, 1)
    }

    func test_storageCommitmentSCP_emptyRequest_succeeds() async {
        let scp = StorageCommitmentSCP(
            instanceExistsCheck: { _ in true },
            logger: MayamLogger(label: "test.commitment")
        )

        let result = await scp.processCommitmentRequest(
            transactionUID: "1.2.3.666",
            referencedInstances: []
        )

        XCTAssertEqual(result.successInstances.count, 0)
        XCTAssertEqual(result.failedInstances.count, 0)
    }

    func test_storageCommitmentSCP_getCompletedTransactions_tracksHistory() async {
        let scp = StorageCommitmentSCP(
            instanceExistsCheck: { _ in true },
            logger: MayamLogger(label: "test.commitment")
        )

        _ = await scp.processCommitmentRequest(
            transactionUID: "tx1",
            referencedInstances: [(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")]
        )
        _ = await scp.processCommitmentRequest(
            transactionUID: "tx2",
            referencedInstances: [(sopClassUID: "1.2.3", sopInstanceUID: "7.8.9")]
        )

        let count = await scp.completedTransactionCount()
        XCTAssertEqual(count, 2)

        let transactions = await scp.getCompletedTransactions()
        XCTAssertEqual(transactions.count, 2)
    }
}

// MARK: - StorageCommitmentError Tests

final class StorageCommitmentErrorTests: XCTestCase {

    func test_storageCommitmentError_transactionNotFound_description() {
        let error = StorageCommitmentError.transactionNotFound(transactionUID: "1.2.3")
        XCTAssertTrue(error.description.contains("1.2.3"))
    }

    func test_storageCommitmentError_invalidRequest_description() {
        let error = StorageCommitmentError.invalidRequest(reason: "missing UID")
        XCTAssertTrue(error.description.contains("missing UID"))
    }
}

// MARK: - PointInTimeRecovery Tests

final class PointInTimeRecoveryTests: XCTestCase {

    private func makeTmpDir() throws -> String {
        let tmp = NSTemporaryDirectory() + "mayam_pitr_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        return tmp
    }

    func test_pitr_createSnapshot_createsFile() async throws {
        let dir = try makeTmpDir()
        let dbPath = dir + "/test.db"
        let snapshotDir = dir + "/snapshots"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        // Create a test database file
        try Data("test-database-content".utf8).write(to: URL(fileURLWithPath: dbPath))

        let pitr = PointInTimeRecovery(
            snapshotDirectory: snapshotDir,
            databasePath: dbPath,
            logger: MayamLogger(label: "test.pitr")
        )

        let snapshot = try await pitr.createSnapshot(label: "test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshot.filePath))
        XCTAssertEqual(snapshot.label, "test")
        XCTAssertTrue(snapshot.sizeBytes > 0)
    }

    func test_pitr_listSnapshots_returnsNewestFirst() async throws {
        let dir = try makeTmpDir()
        let dbPath = dir + "/test.db"
        let snapshotDir = dir + "/snapshots"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try Data("db-content".utf8).write(to: URL(fileURLWithPath: dbPath))

        let pitr = PointInTimeRecovery(
            snapshotDirectory: snapshotDir,
            databasePath: dbPath,
            logger: MayamLogger(label: "test.pitr")
        )

        let s1 = try await pitr.createSnapshot(label: "first")
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let s2 = try await pitr.createSnapshot(label: "second")

        let list = await pitr.listSnapshots()
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].label, "second")
        XCTAssertEqual(list[1].label, "first")
        _ = (s1, s2)
    }

    func test_pitr_snapshotCount_returnsCorrectCount() async throws {
        let dir = try makeTmpDir()
        let dbPath = dir + "/test.db"
        let snapshotDir = dir + "/snapshots"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try Data("db-content".utf8).write(to: URL(fileURLWithPath: dbPath))

        let pitr = PointInTimeRecovery(
            snapshotDirectory: snapshotDir,
            databasePath: dbPath,
            logger: MayamLogger(label: "test.pitr")
        )

        _ = try await pitr.createSnapshot()
        let count = await pitr.snapshotCount()
        XCTAssertEqual(count, 1)
    }

    func test_pitr_createSnapshot_databaseNotFound_throws() async {
        let dir = NSTemporaryDirectory() + "mayam_pitr_noexist_\(UUID().uuidString)"
        let pitr = PointInTimeRecovery(
            snapshotDirectory: dir + "/snapshots",
            databasePath: dir + "/nonexistent.db",
            logger: MayamLogger(label: "test.pitr")
        )

        do {
            _ = try await pitr.createSnapshot()
            XCTFail("Expected RecoveryError.databaseNotFound")
        } catch let error as RecoveryError {
            if case .databaseNotFound = error {
                // expected
            } else {
                XCTFail("Expected databaseNotFound, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_pitr_restore_restoresDatabase() async throws {
        let dir = try makeTmpDir()
        let dbPath = dir + "/test.db"
        let snapshotDir = dir + "/snapshots"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        // Create original database
        try Data("original-content".utf8).write(to: URL(fileURLWithPath: dbPath))

        let pitr = PointInTimeRecovery(
            snapshotDirectory: snapshotDir,
            databasePath: dbPath,
            logger: MayamLogger(label: "test.pitr")
        )

        let snapshot = try await pitr.createSnapshot(label: "before-change")

        // Modify the database
        try Data("modified-content".utf8).write(to: URL(fileURLWithPath: dbPath))

        // Restore from snapshot
        try await pitr.restore(from: snapshot.id)

        // Verify the original content is restored
        let restoredData = try Data(contentsOf: URL(fileURLWithPath: dbPath))
        XCTAssertEqual(String(data: restoredData, encoding: .utf8), "original-content")
    }

    func test_pitr_restore_unknownSnapshot_throws() async throws {
        let dir = try makeTmpDir()
        let dbPath = dir + "/test.db"
        let snapshotDir = dir + "/snapshots"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try Data("content".utf8).write(to: URL(fileURLWithPath: dbPath))

        let pitr = PointInTimeRecovery(
            snapshotDirectory: snapshotDir,
            databasePath: dbPath,
            logger: MayamLogger(label: "test.pitr")
        )

        do {
            try await pitr.restore(from: UUID())
            XCTFail("Expected RecoveryError.snapshotNotFound")
        } catch let error as RecoveryError {
            if case .snapshotNotFound = error {
                // expected
            } else {
                XCTFail("Expected snapshotNotFound, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_pitr_pruning_limitsSnapshots() async throws {
        let dir = try makeTmpDir()
        let dbPath = dir + "/test.db"
        let snapshotDir = dir + "/snapshots"
        defer { try? FileManager.default.removeItem(atPath: dir) }

        try Data("content".utf8).write(to: URL(fileURLWithPath: dbPath))

        let pitr = PointInTimeRecovery(
            snapshotDirectory: snapshotDir,
            databasePath: dbPath,
            maxSnapshots: 2,
            logger: MayamLogger(label: "test.pitr")
        )

        _ = try await pitr.createSnapshot(label: "s1")
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await pitr.createSnapshot(label: "s2")
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await pitr.createSnapshot(label: "s3")

        let count = await pitr.snapshotCount()
        XCTAssertEqual(count, 2)
    }
}

// MARK: - RecoveryError Tests

final class RecoveryErrorTests: XCTestCase {

    func test_recoveryError_databaseNotFound_description() {
        let error = RecoveryError.databaseNotFound(path: "/db")
        XCTAssertTrue(error.description.contains("/db"))
    }

    func test_recoveryError_snapshotFailed_description() {
        let error = RecoveryError.snapshotFailed(reason: "disk full")
        XCTAssertTrue(error.description.contains("disk full"))
    }

    func test_recoveryError_snapshotNotFound_description() {
        let id = UUID()
        let error = RecoveryError.snapshotNotFound(id: id)
        XCTAssertTrue(error.description.contains(id.uuidString))
    }

    func test_recoveryError_snapshotFileNotFound_description() {
        let error = RecoveryError.snapshotFileNotFound(path: "/snap")
        XCTAssertTrue(error.description.contains("/snap"))
    }

    func test_recoveryError_restoreFailed_description() {
        let error = RecoveryError.restoreFailed(reason: "permission denied")
        XCTAssertTrue(error.description.contains("permission denied"))
    }
}

// MARK: - IntegrityScanner Tests

final class IntegrityScannerTests: XCTestCase {

    private func makeTmpDir() throws -> String {
        let tmp = NSTemporaryDirectory() + "mayam_integrity_test_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        return tmp
    }

    func test_integrityScanner_emptyArchive_passes() async throws {
        let archivePath = try makeTmpDir()
        defer { try? FileManager.default.removeItem(atPath: archivePath) }

        let scanner = IntegrityScanner(
            archivePath: archivePath,
            checksumLookup: { _ in nil },
            logger: MayamLogger(label: "test.integrity")
        )

        let result = try await scanner.runScan()
        XCTAssertEqual(result.scannedCount, 0)
        XCTAssertEqual(result.validCount, 0)
        XCTAssertEqual(result.mismatchCount, 0)
        XCTAssertEqual(result.errorCount, 0)
        XCTAssertEqual(result.status, "passed")
    }

    func test_integrityScanner_validChecksums_passes() async throws {
        let archivePath = try makeTmpDir()
        defer { try? FileManager.default.removeItem(atPath: archivePath) }

        let testData = Data("test-dicom-data".utf8)

        // Compute expected checksum
        var hasher = Crypto.SHA256()
        hasher.update(data: testData)
        let digest = hasher.finalize()
        let expectedChecksum = digest.map { String(format: "%02x", $0) }.joined()

        // Write test file
        try testData.write(to: URL(fileURLWithPath: archivePath + "/test.dcm"))

        let scanner = IntegrityScanner(
            archivePath: archivePath,
            checksumLookup: { _ in expectedChecksum },
            logger: MayamLogger(label: "test.integrity")
        )

        let result = try await scanner.runScan()
        XCTAssertEqual(result.scannedCount, 1)
        XCTAssertEqual(result.validCount, 1)
        XCTAssertEqual(result.mismatchCount, 0)
        XCTAssertEqual(result.status, "passed")
    }

    func test_integrityScanner_mismatchedChecksum_reportsViolation() async throws {
        let archivePath = try makeTmpDir()
        defer { try? FileManager.default.removeItem(atPath: archivePath) }

        try Data("test-data".utf8).write(to: URL(fileURLWithPath: archivePath + "/test.dcm"))

        let scanner = IntegrityScanner(
            archivePath: archivePath,
            checksumLookup: { _ in "0000000000000000000000000000000000000000000000000000000000000000" },
            logger: MayamLogger(label: "test.integrity")
        )

        let result = try await scanner.runScan()
        XCTAssertEqual(result.scannedCount, 1)
        XCTAssertEqual(result.mismatchCount, 1)
        XCTAssertEqual(result.status, "violations_found")
        XCTAssertEqual(result.violations.count, 1)
        XCTAssertEqual(result.violations[0].violationType, .checksumMismatch)
    }

    func test_integrityScanner_noStoredChecksum_skipsVerification() async throws {
        let archivePath = try makeTmpDir()
        defer { try? FileManager.default.removeItem(atPath: archivePath) }

        try Data("data".utf8).write(to: URL(fileURLWithPath: archivePath + "/test.dcm"))

        let scanner = IntegrityScanner(
            archivePath: archivePath,
            checksumLookup: { _ in nil },
            logger: MayamLogger(label: "test.integrity")
        )

        let result = try await scanner.runScan()
        XCTAssertEqual(result.scannedCount, 1)
        XCTAssertEqual(result.validCount, 1)
        XCTAssertEqual(result.mismatchCount, 0)
    }

    func test_integrityScanner_getScanHistory_tracksResults() async throws {
        let archivePath = try makeTmpDir()
        defer { try? FileManager.default.removeItem(atPath: archivePath) }

        let scanner = IntegrityScanner(
            archivePath: archivePath,
            checksumLookup: { _ in nil },
            logger: MayamLogger(label: "test.integrity")
        )

        _ = try await scanner.runScan()
        let history = await scanner.getScanHistory()
        XCTAssertEqual(history.count, 1)
    }

    func test_integrityScanner_lastScanResult_returnsLatest() async throws {
        let archivePath = try makeTmpDir()
        defer { try? FileManager.default.removeItem(atPath: archivePath) }

        let scanner = IntegrityScanner(
            archivePath: archivePath,
            checksumLookup: { _ in nil },
            logger: MayamLogger(label: "test.integrity")
        )

        let result = try await scanner.runScan()
        let last = await scanner.lastScanResult()
        XCTAssertNotNil(last)
        XCTAssertEqual(last?.id, result.id)
    }
}

// MARK: - IntegrityScanError Tests

final class IntegrityScanErrorTests: XCTestCase {

    func test_scanAlreadyRunning_description() {
        let error = IntegrityScanError.scanAlreadyRunning
        XCTAssertTrue(error.description.contains("already in progress"))
    }

    func test_archiveNotAccessible_description() {
        let error = IntegrityScanError.archiveNotAccessible(path: "/archive")
        XCTAssertTrue(error.description.contains("/archive"))
    }
}

// MARK: - MigrationEvent Tests

final class MigrationEventTests: XCTestCase {

    func test_migrationEvent_init_setsProperties() {
        let now = Date()
        let event = MigrationEvent(
            studyInstanceUID: "1.2.3",
            sourceTier: .online,
            targetTier: .nearLine,
            migratedAt: now
        )
        XCTAssertEqual(event.studyInstanceUID, "1.2.3")
        XCTAssertEqual(event.sourceTier, .online)
        XCTAssertEqual(event.targetTier, .nearLine)
        XCTAssertEqual(event.migratedAt, now)
    }

    func test_migrationEvent_codable_roundTrips() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = MigrationEvent(
            studyInstanceUID: "1.2.3",
            sourceTier: .online,
            targetTier: .archive,
            migratedAt: Date()
        )
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(MigrationEvent.self, from: data)
        XCTAssertEqual(decoded.studyInstanceUID, event.studyInstanceUID)
        XCTAssertEqual(decoded.sourceTier, event.sourceTier)
        XCTAssertEqual(decoded.targetTier, event.targetTier)
    }
}

// MARK: - SCPDispatcher Storage Commitment Integration Tests

final class SCPDispatcherStorageCommitmentTests: XCTestCase {

    func test_scpDispatcher_handleStorageCommitment_withSCP_delegates() async {
        let commitmentSCP = StorageCommitmentSCP(
            instanceExistsCheck: { _ in true },
            logger: MayamLogger(label: "test.commitment")
        )
        let dispatcher = SCPDispatcher(storageCommitmentSCP: commitmentSCP)

        let result = await dispatcher.handleStorageCommitment(
            transactionUID: "1.2.3.999",
            referencedInstances: [(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")]
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.successInstances.count, 1)
    }

    func test_scpDispatcher_handleStorageCommitment_withoutSCP_returnsNil() async {
        let dispatcher = SCPDispatcher()

        let result = await dispatcher.handleStorageCommitment(
            transactionUID: "1.2.3.999",
            referencedInstances: [(sopClassUID: "1.2.3", sopInstanceUID: "4.5.6")]
        )

        XCTAssertNil(result)
    }
}

// MARK: - ServerConfiguration HSM & Backup Tests

final class ServerConfigurationHSMBackupTests: XCTestCase {

    func test_serverConfiguration_default_hsmDisabled() {
        let config = ServerConfiguration()
        XCTAssertFalse(config.hsm.enabled)
        XCTAssertTrue(config.hsm.tiers.isEmpty)
        XCTAssertTrue(config.hsm.migrationRules.isEmpty)
    }

    func test_serverConfiguration_default_backupDisabled() {
        let config = ServerConfiguration()
        XCTAssertFalse(config.backup.enabled)
        XCTAssertTrue(config.backup.targets.isEmpty)
    }

    func test_serverConfiguration_hsm_codable_roundTrips() throws {
        var config = ServerConfiguration()
        config.hsm = ServerConfiguration.HSM(
            enabled: true,
            tiers: [StorageTierConfiguration(tier: .online, path: "/fast")],
            migrationRules: [MigrationRule(trigger: .ageDays(90), targetTier: .nearLine)],
            migrationScanIntervalSeconds: 1800
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ServerConfiguration.self, from: data)
        XCTAssertTrue(decoded.hsm.enabled)
        XCTAssertEqual(decoded.hsm.tiers.count, 1)
        XCTAssertEqual(decoded.hsm.migrationRules.count, 1)
        XCTAssertEqual(decoded.hsm.migrationScanIntervalSeconds, 1800)
    }

    func test_serverConfiguration_backup_codable_roundTrips() throws {
        var config = ServerConfiguration()
        config.backup = ServerConfiguration.Backup(
            enabled: true,
            targets: [BackupTarget(name: "Local", targetType: .local, destinationPath: "/backup")],
            schedule: BackupSchedule(intervalSeconds: 43200)
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ServerConfiguration.self, from: data)
        XCTAssertTrue(decoded.backup.enabled)
        XCTAssertEqual(decoded.backup.targets.count, 1)
        XCTAssertEqual(decoded.backup.schedule.intervalSeconds, 43200)
    }

    func test_serverConfiguration_hsmDefaults_decodeMissing() throws {
        let json = """
        { "dicom": { "aeTitle": "TEST" } }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(ServerConfiguration.self, from: json)
        XCTAssertFalse(config.hsm.enabled)
        XCTAssertFalse(config.backup.enabled)
    }
}

// MARK: - IntegrityViolation Tests

final class IntegrityViolationTests: XCTestCase {

    func test_violationType_rawValues() {
        XCTAssertEqual(IntegrityScanner.ViolationType.checksumMismatch.rawValue, "checksumMismatch")
        XCTAssertEqual(IntegrityScanner.ViolationType.fileUnreadable.rawValue, "fileUnreadable")
        XCTAssertEqual(IntegrityScanner.ViolationType.fileNotFound.rawValue, "fileNotFound")
    }

    func test_integrityViolation_init_setsProperties() {
        let violation = IntegrityScanner.IntegrityViolation(
            filePath: "PAT001/1.2.3/test.dcm",
            expectedChecksum: "abc123",
            computedChecksum: "def456",
            violationType: .checksumMismatch
        )
        XCTAssertEqual(violation.filePath, "PAT001/1.2.3/test.dcm")
        XCTAssertEqual(violation.expectedChecksum, "abc123")
        XCTAssertEqual(violation.computedChecksum, "def456")
        XCTAssertEqual(violation.violationType, .checksumMismatch)
    }

    func test_integrityViolation_fileUnreadable_hasNilChecksum() {
        let violation = IntegrityScanner.IntegrityViolation(
            filePath: "test.dcm",
            expectedChecksum: "abc",
            computedChecksum: nil,
            violationType: .fileUnreadable
        )
        XCTAssertNil(violation.computedChecksum)
    }
}

// MARK: - ScanResult Tests

final class ScanResultTests: XCTestCase {

    func test_scanResult_defaults() {
        let result = IntegrityScanner.ScanResult(startedAt: Date())
        XCTAssertEqual(result.scannedCount, 0)
        XCTAssertEqual(result.validCount, 0)
        XCTAssertEqual(result.mismatchCount, 0)
        XCTAssertEqual(result.errorCount, 0)
        XCTAssertEqual(result.status, "running")
        XCTAssertNil(result.completedAt)
        XCTAssertTrue(result.violations.isEmpty)
    }
}
