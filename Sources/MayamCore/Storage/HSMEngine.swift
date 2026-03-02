// SPDX-License-Identifier: (see LICENSE)
// Mayam — Hierarchical Storage Management Engine

import Foundation

// MARK: - HSMEngine

/// Manages hierarchical storage tiers, policy-driven migration, and
/// on-demand recall of DICOM studies.
///
/// The HSM engine maintains an index of study tier records that track
/// which storage tier each study resides on. It periodically evaluates
/// migration rules and moves studies between tiers according to policy.
///
/// When a study on a near-line or archive tier is queried, the engine
/// transparently recalls it to the online tier before serving.
///
/// Reference: Milestone 9 — Hierarchical Storage Management
public actor HSMEngine {

    // MARK: - Stored Properties

    /// HSM configuration.
    private let configuration: HSMConfiguration

    /// Logger for HSM events.
    private let logger: MayamLogger

    /// In-memory index of study tier records, keyed by Study Instance UID.
    private var tierRecords: [String: StudyTierRecord] = [:]

    /// History of migration operations for auditing.
    private var migrationHistory: [MigrationEvent] = []

    // MARK: - Initialiser

    /// Creates a new HSM engine.
    ///
    /// - Parameters:
    ///   - configuration: HSM configuration defining tiers and migration rules.
    ///   - logger: Logger instance for HSM events.
    public init(configuration: HSMConfiguration, logger: MayamLogger) {
        self.configuration = configuration
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Registers a study in the HSM index at the online tier.
    ///
    /// Called when a new study is ingested into the archive. The study is
    /// initially placed on the online tier.
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID (0020,000D).
    ///   - path: The file-system path of the study.
    ///   - studyDate: The DICOM study date (optional).
    ///   - modality: The primary modality (optional).
    public func registerStudy(
        studyInstanceUID: String,
        path: String,
        studyDate: Date? = nil,
        modality: String? = nil
    ) {
        let now = Date()
        let record = StudyTierRecord(
            studyInstanceUID: studyInstanceUID,
            currentTier: .online,
            currentPath: path,
            lastAccessedAt: now,
            migratedAt: now,
            studyDate: studyDate,
            modality: modality
        )
        tierRecords[studyInstanceUID] = record
        logger.info("HSM: Registered study '\(studyInstanceUID)' on online tier")
    }

    /// Returns the current tier record for a study.
    ///
    /// - Parameter studyInstanceUID: The Study Instance UID.
    /// - Returns: The tier record, or `nil` if the study is not tracked.
    public func getTierRecord(for studyInstanceUID: String) -> StudyTierRecord? {
        tierRecords[studyInstanceUID]
    }

    /// Returns all tier records currently tracked by the HSM engine.
    public func getAllTierRecords() -> [StudyTierRecord] {
        Array(tierRecords.values)
    }

    /// Returns the number of studies tracked by the HSM engine.
    public func trackedStudyCount() -> Int {
        tierRecords.count
    }

    /// Records an access to a study, updating its last-access timestamp.
    ///
    /// If the study is on a near-line or archive tier, this triggers a
    /// transparent recall to the online tier.
    ///
    /// - Parameter studyInstanceUID: The Study Instance UID.
    /// - Returns: The study's current path after any recall, or `nil` if
    ///   the study is not tracked.
    /// - Throws: ``HSMError`` if the recall fails.
    public func accessStudy(studyInstanceUID: String) throws -> String? {
        guard var record = tierRecords[studyInstanceUID] else {
            return nil
        }

        record.lastAccessedAt = Date()

        if record.currentTier != .online {
            logger.info("HSM: Recalling study '\(studyInstanceUID)' from \(record.currentTier.rawValue) to online tier")
            record = try recallToOnline(record: record)
        }

        tierRecords[studyInstanceUID] = record
        return record.currentPath
    }

    /// Evaluates all migration rules against the current tier records and
    /// returns a list of studies that should be migrated.
    ///
    /// This does not perform the migration — call ``migrateStudy(_:to:newPath:)``
    /// to execute each migration.
    ///
    /// - Returns: An array of tuples containing the study UID and target tier.
    public func evaluateMigrationCandidates() -> [(studyInstanceUID: String, targetTier: StorageTier)] {
        guard configuration.enabled else { return [] }

        var candidates: [(String, StorageTier)] = []
        let now = Date()

        for record in tierRecords.values {
            for rule in configuration.migrationRules {
                guard rule.targetTier != record.currentTier else { continue }

                if shouldMigrate(record: record, trigger: rule.trigger, now: now) {
                    candidates.append((record.studyInstanceUID, rule.targetTier))
                    break // First matching rule wins
                }
            }
        }

        return candidates
    }

    /// Migrates a study to a new storage tier.
    ///
    /// Updates the tier record with the new tier and path. The actual file
    /// movement is expected to be performed by the caller before invoking
    /// this method.
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID.
    ///   - targetTier: The destination tier.
    ///   - newPath: The new file-system path on the target tier.
    /// - Throws: ``HSMError/studyNotFound`` if the study is not tracked.
    public func migrateStudy(
        _ studyInstanceUID: String,
        to targetTier: StorageTier,
        newPath: String
    ) throws {
        guard var record = tierRecords[studyInstanceUID] else {
            throw HSMError.studyNotFound(studyInstanceUID: studyInstanceUID)
        }

        let sourceTier = record.currentTier
        let now = Date()

        record.currentTier = targetTier
        record.currentPath = newPath
        record.migratedAt = now
        tierRecords[studyInstanceUID] = record

        let event = MigrationEvent(
            studyInstanceUID: studyInstanceUID,
            sourceTier: sourceTier,
            targetTier: targetTier,
            migratedAt: now
        )
        migrationHistory.append(event)

        logger.info("HSM: Migrated study '\(studyInstanceUID)' from \(sourceTier.rawValue) to \(targetTier.rawValue)")
    }

    /// Returns the history of migration events.
    public func getMigrationHistory() -> [MigrationEvent] {
        migrationHistory
    }

    // MARK: - Private Helpers

    /// Evaluates whether a study matches a migration trigger.
    private func shouldMigrate(
        record: StudyTierRecord,
        trigger: MigrationTrigger,
        now: Date
    ) -> Bool {
        switch trigger {
        case .ageDays(let days):
            guard let studyDate = record.studyDate else { return false }
            let ageInDays = Calendar.current.dateComponents([.day], from: studyDate, to: now).day ?? 0
            return ageInDays >= days

        case .lastAccessDays(let days):
            let daysSinceAccess = Calendar.current.dateComponents(
                [.day], from: record.lastAccessedAt, to: now
            ).day ?? 0
            return daysSinceAccess >= days

        case .modality(let mod):
            return record.modality == mod

        case .studyStatus(let status):
            // Status-based migration requires external study status metadata;
            // for now, this is a placeholder that always returns false.
            _ = status
            return false
        }
    }

    /// Recalls a study from a non-online tier back to the online tier.
    ///
    /// In a production system, this would involve copying data from the
    /// near-line or archive storage back to fast online storage. This
    /// implementation updates the record's tier metadata; the actual file
    /// I/O is delegated to the storage layer.
    private func recallToOnline(record: StudyTierRecord) throws -> StudyTierRecord {
        guard let onlineTier = configuration.tiers.first(where: { $0.tier == .online }) else {
            throw HSMError.tierNotConfigured(tier: .online)
        }

        var updated = record
        let sourceTier = record.currentTier
        let now = Date()

        // Compute the online path: retain the study's relative path portion
        let studyUID = record.studyInstanceUID
        updated.currentTier = .online
        updated.currentPath = onlineTier.path + "/" + studyUID
        updated.migratedAt = now

        let event = MigrationEvent(
            studyInstanceUID: studyUID,
            sourceTier: sourceTier,
            targetTier: .online,
            migratedAt: now
        )
        migrationHistory.append(event)

        logger.info("HSM: Recalled study '\(studyUID)' from \(sourceTier.rawValue) to online tier")
        return updated
    }
}

// MARK: - MigrationEvent

/// Records a single tier migration event for auditing.
public struct MigrationEvent: Sendable, Codable, Equatable {

    /// The Study Instance UID that was migrated.
    public let studyInstanceUID: String

    /// The tier the study was migrated from.
    public let sourceTier: StorageTier

    /// The tier the study was migrated to.
    public let targetTier: StorageTier

    /// When the migration occurred.
    public let migratedAt: Date

    /// Creates a migration event record.
    public init(
        studyInstanceUID: String,
        sourceTier: StorageTier,
        targetTier: StorageTier,
        migratedAt: Date
    ) {
        self.studyInstanceUID = studyInstanceUID
        self.sourceTier = sourceTier
        self.targetTier = targetTier
        self.migratedAt = migratedAt
    }
}

// MARK: - HSMError

/// Errors that may occur during HSM operations.
public enum HSMError: Error, Sendable, CustomStringConvertible {

    /// The specified study was not found in the HSM index.
    case studyNotFound(studyInstanceUID: String)

    /// The specified storage tier is not configured.
    case tierNotConfigured(tier: StorageTier)

    /// A file operation failed during migration.
    case migrationFailed(studyInstanceUID: String, reason: String)

    /// A recall operation failed.
    case recallFailed(studyInstanceUID: String, reason: String)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .studyNotFound(let uid):
            return "Study '\(uid)' not found in HSM index"
        case .tierNotConfigured(let tier):
            return "Storage tier '\(tier.rawValue)' is not configured"
        case .migrationFailed(let uid, let reason):
            return "Migration failed for study '\(uid)': \(reason)"
        case .recallFailed(let uid, let reason):
            return "Recall failed for study '\(uid)': \(reason)"
        }
    }
}
