// SPDX-License-Identifier: (see LICENSE)
// Mayam — Storage Policy Model

import Foundation

// MARK: - DuplicatePolicy

/// Defines the behaviour when a duplicate SOP instance is received during ingest.
///
/// Reference: Milestone 3 — Storage Policy Matrix (Ingest stage)
public enum DuplicatePolicy: String, Sendable, Codable, Equatable, CaseIterable {

    /// Reject the duplicate; return a C-STORE failure status (0xA700 — Duplicate SOP Instance).
    case reject

    /// Overwrite the existing instance with the newly received one.
    case overwrite

    /// Store both the existing and new instances; append a unique counter suffix to the
    /// incoming file name to avoid collision.
    case keepBoth
}

// MARK: - StoragePolicy

/// A complete storage policy that governs ingest, online serving, near-line
/// migration, offline archival, and rehydration behaviour of the DICOM archive.
///
/// The policy is configurable per-server and can be overridden on a per-modality
/// basis in future releases.
///
/// Reference: DICOM PS3.4 Annex B — Storage Service Class
public struct StoragePolicy: Sendable, Codable, Equatable {

    // MARK: - Ingest Policies

    /// Behaviour when a SOP Instance with a duplicate UID is received.
    public var duplicatePolicy: DuplicatePolicy

    /// Whether to compute and persist SHA-256 integrity checksums on ingest.
    public var checksumEnabled: Bool

    // MARK: - Near-Line / Offline Policies

    /// Maximum age (in days) of online studies before near-line migration is
    /// triggered. A value of `nil` disables age-based migration.
    public var nearLineMigrationAgeDays: Int?

    /// Whether to produce a ZIP archive of a study before near-line migration.
    public var zipOnArchive: Bool

    // MARK: - Default Policy

    /// The default storage policy applied when no explicit configuration is present.
    ///
    /// - Duplicate policy: reject.
    /// - Checksum enabled.
    /// - No age-based near-line migration.
    /// - ZIP-on-archive disabled.
    public static let `default` = StoragePolicy(
        duplicatePolicy: .reject,
        checksumEnabled: true,
        nearLineMigrationAgeDays: nil,
        zipOnArchive: false
    )

    // MARK: - Initialiser

    /// Creates a storage policy.
    ///
    /// - Parameters:
    ///   - duplicatePolicy: Behaviour on duplicate SOP Instance receipt (default: `.reject`).
    ///   - checksumEnabled: Whether to compute SHA-256 checksums on ingest (default: `true`).
    ///   - nearLineMigrationAgeDays: Age in days that triggers near-line migration (default: `nil`).
    ///   - zipOnArchive: Whether to package studies as ZIP archives before migration (default: `false`).
    public init(
        duplicatePolicy: DuplicatePolicy = .reject,
        checksumEnabled: Bool = true,
        nearLineMigrationAgeDays: Int? = nil,
        zipOnArchive: Bool = false
    ) {
        self.duplicatePolicy = duplicatePolicy
        self.checksumEnabled = checksumEnabled
        self.nearLineMigrationAgeDays = nearLineMigrationAgeDays
        self.zipOnArchive = zipOnArchive
    }
}
