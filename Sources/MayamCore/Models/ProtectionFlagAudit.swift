// SPDX-License-Identifier: (see LICENSE)
// Mayam — Protection Flag Audit Model

import Foundation

/// Records a single change to a Delete Protect or Privacy Flag on a patient,
/// accession, or study entity.
///
/// All changes to protection flags are persisted in the
/// `protection_flag_audit` table as mandated by security and audit requirements
/// (DICOM PS3.15).
public struct ProtectionFlagAudit: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Nested Types

    /// Entity types that support protection flags.
    public enum EntityType: String, Sendable, Codable, Equatable, CaseIterable {
        /// A ``Patient`` entity.
        case patient
        /// An ``Accession`` entity.
        case accession
        /// A ``Study`` entity.
        case study
    }

    /// The name of the protection flag that was changed.
    public enum FlagName: String, Sendable, Codable, Equatable, CaseIterable {
        /// The delete-protection flag.
        case deleteProtect = "delete_protect"
        /// The privacy flag.
        case privacyFlag = "privacy_flag"
    }

    // MARK: - Stored Properties

    /// Database-generated primary key.
    public let id: Int64?

    /// The type of entity whose flag was changed.
    public let entityType: EntityType

    /// The primary key of the entity whose flag was changed.
    public let entityID: Int64

    /// The flag that was changed.
    public let flagName: FlagName

    /// The previous value of the flag before the change.
    public let oldValue: Bool

    /// The new value of the flag after the change.
    public let newValue: Bool

    /// The username or AE Title of the actor who made the change (if available).
    public let changedBy: String?

    /// An optional human-readable reason for the change.
    public let reason: String?

    /// Timestamp when the change was recorded.
    public let changedAt: Date?

    // MARK: - Initialiser

    /// Creates a new protection flag audit record.
    ///
    /// - Parameters:
    ///   - id: Database primary key (`nil` for unsaved records).
    ///   - entityType: The type of entity whose flag changed.
    ///   - entityID: The primary key of the entity.
    ///   - flagName: The flag that was changed.
    ///   - oldValue: The previous value of the flag.
    ///   - newValue: The new value of the flag.
    ///   - changedBy: The actor who made the change.
    ///   - reason: An optional reason for the change.
    ///   - changedAt: Timestamp of the change.
    public init(
        id: Int64? = nil,
        entityType: EntityType,
        entityID: Int64,
        flagName: FlagName,
        oldValue: Bool,
        newValue: Bool,
        changedBy: String? = nil,
        reason: String? = nil,
        changedAt: Date? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityID = entityID
        self.flagName = flagName
        self.oldValue = oldValue
        self.newValue = newValue
        self.changedBy = changedBy
        self.reason = reason
        self.changedAt = changedAt
    }
}
