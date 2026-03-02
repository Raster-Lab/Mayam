// SPDX-License-Identifier: (see LICENSE)
// Mayam — Storage Tier Model

import Foundation

// MARK: - StorageTier

/// Defines the hierarchical storage tiers available in the PACS archive.
///
/// Each tier represents a different class of storage medium, balancing
/// access speed against cost and capacity.
///
/// Reference: Milestone 9 — Hierarchical Storage Management (HSM)
public enum StorageTier: String, Sendable, Codable, Equatable, CaseIterable {

    /// Online tier — fast local storage (SSD/NVMe) for active studies.
    case online

    /// Near-line tier — networked or external storage (NAS/external drive)
    /// for studies accessed infrequently.
    case nearLine

    /// Archive tier — cold storage (object storage / tape) for long-term
    /// retention.
    case archive
}

// MARK: - MigrationRule

/// A policy rule that governs when studies should be migrated between
/// storage tiers.
///
/// Each rule defines a trigger condition and a target tier. When the
/// condition is met for a study, the HSM engine queues it for migration
/// to the specified tier.
public struct MigrationRule: Sendable, Codable, Equatable {

    /// The criterion that triggers migration.
    public var trigger: MigrationTrigger

    /// The destination tier for studies matching this rule.
    public var targetTier: StorageTier

    /// Creates a migration rule.
    ///
    /// - Parameters:
    ///   - trigger: The condition that triggers migration.
    ///   - targetTier: The destination storage tier.
    public init(trigger: MigrationTrigger, targetTier: StorageTier) {
        self.trigger = trigger
        self.targetTier = targetTier
    }
}

// MARK: - MigrationTrigger

/// Defines when a study should be migrated to a different storage tier.
public enum MigrationTrigger: Sendable, Codable, Equatable {

    /// Migrate after the study exceeds the given age in days since its
    /// study date.
    case ageDays(Int)

    /// Migrate after the study has not been accessed for the given number
    /// of days.
    case lastAccessDays(Int)

    /// Migrate studies of a specific modality (e.g. `"CR"`, `"MR"`).
    case modality(String)

    /// Migrate studies with a specific status string.
    case studyStatus(String)
}

// MARK: - StorageTierConfiguration

/// Configuration for a single storage tier, defining its path and capacity
/// limits.
public struct StorageTierConfiguration: Sendable, Codable, Equatable {

    /// The storage tier this configuration applies to.
    public var tier: StorageTier

    /// The root directory path for this tier.
    public var path: String

    /// Maximum capacity in bytes. A value of `nil` means unlimited.
    public var maxCapacityBytes: Int64?

    /// Creates a storage tier configuration.
    ///
    /// - Parameters:
    ///   - tier: The storage tier.
    ///   - path: Root directory path for the tier.
    ///   - maxCapacityBytes: Maximum capacity in bytes (default: `nil` = unlimited).
    public init(tier: StorageTier, path: String, maxCapacityBytes: Int64? = nil) {
        self.tier = tier
        self.path = path
        self.maxCapacityBytes = maxCapacityBytes
    }
}

// MARK: - HSMConfiguration

/// Configuration for the Hierarchical Storage Management engine.
public struct HSMConfiguration: Sendable, Codable, Equatable {

    /// Whether HSM is enabled.
    public var enabled: Bool

    /// Configured storage tiers (at least the online tier must be present).
    public var tiers: [StorageTierConfiguration]

    /// Migration rules evaluated in order; the first matching rule wins.
    public var migrationRules: [MigrationRule]

    /// Interval in seconds between automatic migration scans.
    public var migrationScanIntervalSeconds: Int

    /// The default HSM configuration (disabled, online tier only).
    public static let `default` = HSMConfiguration(
        enabled: false,
        tiers: [],
        migrationRules: [],
        migrationScanIntervalSeconds: 3600
    )

    /// Creates an HSM configuration.
    ///
    /// - Parameters:
    ///   - enabled: Whether HSM is enabled (default: `false`).
    ///   - tiers: Configured storage tiers (default: empty).
    ///   - migrationRules: Migration rules (default: empty).
    ///   - migrationScanIntervalSeconds: Scan interval in seconds (default: 3600).
    public init(
        enabled: Bool = false,
        tiers: [StorageTierConfiguration] = [],
        migrationRules: [MigrationRule] = [],
        migrationScanIntervalSeconds: Int = 3600
    ) {
        self.enabled = enabled
        self.tiers = tiers
        self.migrationRules = migrationRules
        self.migrationScanIntervalSeconds = migrationScanIntervalSeconds
    }
}

// MARK: - StudyTierRecord

/// Tracks the current storage tier and location of a study in the HSM system.
public struct StudyTierRecord: Sendable, Codable, Equatable {

    /// The Study Instance UID (0020,000D).
    public let studyInstanceUID: String

    /// The current storage tier.
    public var currentTier: StorageTier

    /// The file-system path where the study is currently stored.
    public var currentPath: String

    /// Timestamp of the last access to the study.
    public var lastAccessedAt: Date

    /// Timestamp when the study was migrated to its current tier.
    public var migratedAt: Date

    /// The original study date from the DICOM header, if available.
    public var studyDate: Date?

    /// The primary modality of the study (e.g. `"CT"`, `"MR"`).
    public var modality: String?

    /// Creates a study tier record.
    ///
    /// - Parameters:
    ///   - studyInstanceUID: The Study Instance UID.
    ///   - currentTier: The current storage tier.
    ///   - currentPath: The file-system path of the study.
    ///   - lastAccessedAt: Timestamp of last access.
    ///   - migratedAt: Timestamp of last migration.
    ///   - studyDate: The original study date (optional).
    ///   - modality: The primary modality (optional).
    public init(
        studyInstanceUID: String,
        currentTier: StorageTier,
        currentPath: String,
        lastAccessedAt: Date,
        migratedAt: Date,
        studyDate: Date? = nil,
        modality: String? = nil
    ) {
        self.studyInstanceUID = studyInstanceUID
        self.currentTier = currentTier
        self.currentPath = currentPath
        self.lastAccessedAt = lastAccessedAt
        self.migratedAt = migratedAt
        self.studyDate = studyDate
        self.modality = modality
    }
}
