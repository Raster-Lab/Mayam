// SPDX-License-Identifier: (see LICENSE)
// Mayam — Access Control Service

import Foundation

/// Evaluates and manages per-entity access control lists (ACLs) for patients
/// and studies with the Privacy Flag set.
///
/// When the Privacy Flag is active on a patient or study, the
/// ``AccessControlService`` determines whether a given user (identified by
/// username and role) is authorised to access that entity.  Access is denied by
/// default unless an explicit ``AccessControlEntry`` with `.allow` permission
/// exists for the user or their role.
///
/// ## Evaluation Rules
/// 1. Explicit **deny** entries always take precedence over allow entries.
/// 2. If no deny entry exists, an explicit **allow** entry for the user or any
///    of the user's roles grants access.
/// 3. If no matching entry exists, access is **denied** (default-deny).
/// 4. Administrators always have access regardless of ACL entries.
///
/// ## DICOM References
/// - DICOM PS3.15 — Security and System Management Profiles
public actor AccessControlService {

    // MARK: - Stored Properties

    /// In-memory ACL store (to be replaced by database in production).
    private var entries: [AccessControlEntry] = []

    /// Logger for access control operations.
    private let logger: MayamLogger

    // MARK: - Initialiser

    /// Creates a new access control service.
    public init() {
        self.logger = MayamLogger(label: "com.raster-lab.mayam.acl")
    }

    // MARK: - ACL Management

    /// Adds an access control entry.
    ///
    /// - Parameter entry: The ACL entry to add.
    /// - Returns: The added entry.
    @discardableResult
    public func addEntry(_ entry: AccessControlEntry) -> AccessControlEntry {
        entries.append(entry)
        logger.info("ACL entry added: \(entry.principalType.rawValue)/\(entry.principalID) -> \(entry.entityType.rawValue)/\(entry.entityID) = \(entry.permission.rawValue)")
        return entry
    }

    /// Removes an access control entry by its ID.
    ///
    /// - Parameter id: The ID of the entry to remove.
    /// - Returns: `true` if the entry was found and removed.
    @discardableResult
    public func removeEntry(id: Int64) -> Bool {
        let before = entries.count
        entries.removeAll { $0.id == id }
        let removed = entries.count < before
        if removed {
            logger.info("ACL entry removed: id=\(id)")
        }
        return removed
    }

    /// Returns all ACL entries for a specific entity.
    ///
    /// - Parameters:
    ///   - entityType: The entity type to query.
    ///   - entityID: The entity primary key.
    /// - Returns: An array of matching ACL entries.
    public func entries(
        for entityType: AccessControlEntry.EntityType,
        entityID: Int64
    ) -> [AccessControlEntry] {
        entries.filter { $0.entityType == entityType && $0.entityID == entityID }
    }

    /// Returns all stored ACL entries.
    public func allEntries() -> [AccessControlEntry] {
        entries
    }

    // MARK: - Access Evaluation

    /// Evaluates whether a user is authorised to access a protected entity.
    ///
    /// - Parameters:
    ///   - username: The authenticated user's username.
    ///   - role: The user's administrative role.
    ///   - entityType: The type of entity being accessed.
    ///   - entityID: The primary key of the entity.
    /// - Returns: `true` if access is granted; `false` if denied.
    public func isAuthorised(
        username: String,
        role: AdminRole,
        entityType: AccessControlEntry.EntityType,
        entityID: Int64
    ) -> Bool {
        // Administrators always have access.
        if role == .administrator {
            return true
        }

        let relevantEntries = entries.filter {
            $0.entityType == entityType && $0.entityID == entityID
        }

        // If no ACL entries exist, default-deny.
        guard !relevantEntries.isEmpty else { return false }

        // Check for explicit deny — deny always wins.
        let hasDeny = relevantEntries.contains { entry in
            entry.permission == .deny && (
                (entry.principalType == .user && entry.principalID == username) ||
                (entry.principalType == .role && entry.principalID == role.rawValue)
            )
        }
        if hasDeny { return false }

        // Check for explicit allow.
        let hasAllow = relevantEntries.contains { entry in
            entry.permission == .allow && (
                (entry.principalType == .user && entry.principalID == username) ||
                (entry.principalType == .role && entry.principalID == role.rawValue)
            )
        }

        return hasAllow
    }
}
