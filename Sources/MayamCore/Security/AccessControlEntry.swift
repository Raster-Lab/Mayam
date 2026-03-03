// SPDX-License-Identifier: (see LICENSE)
// Mayam — Access Control Entry Model

import Foundation

/// An access control entry (ACE) that grants or denies a specific user or role
/// access to a protected entity (patient or study).
///
/// Access control lists (ACLs) are evaluated when the Privacy Flag is set on an
/// entity.  When the Privacy Flag is active, only users or roles explicitly
/// listed in the ACL with `.allow` permission may access the entity's data
/// via C-FIND, C-MOVE, C-GET, or DICOMweb query/retrieve.
///
/// ## DICOM References
/// - DICOM PS3.15 — Security and System Management Profiles
public struct AccessControlEntry: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Nested Types

    /// The type of entity protected by this ACL entry.
    public enum EntityType: String, Sendable, Codable, Equatable, CaseIterable {
        /// A ``Patient`` entity.
        case patient
        /// A ``Study`` entity.
        case study
    }

    /// The type of principal (subject) this ACL entry applies to.
    public enum PrincipalType: String, Sendable, Codable, Equatable, CaseIterable {
        /// A specific user identified by username.
        case user
        /// A role (all users with this role).
        case role
    }

    /// The access permission granted or denied by this entry.
    public enum AccessPermission: String, Sendable, Codable, Equatable, CaseIterable {
        /// Access is explicitly granted.
        case allow
        /// Access is explicitly denied.
        case deny
    }

    // MARK: - Stored Properties

    /// Database-generated primary key.
    public let id: Int64?

    /// The type of entity this ACL entry protects.
    public let entityType: EntityType

    /// The primary key of the protected entity.
    public let entityID: Int64

    /// The type of principal this entry applies to.
    public let principalType: PrincipalType

    /// The principal identifier (username or role name).
    public let principalID: String

    /// The permission granted or denied.
    public let permission: AccessPermission

    /// The user who created this ACL entry.
    public let createdBy: String?

    /// Timestamp when the ACL entry was created.
    public let createdAt: Date?

    // MARK: - Initialiser

    /// Creates a new access control entry.
    ///
    /// - Parameters:
    ///   - id: Database primary key (`nil` for unsaved records).
    ///   - entityType: The type of entity being protected.
    ///   - entityID: The primary key of the protected entity.
    ///   - principalType: Whether this entry applies to a user or a role.
    ///   - principalID: The username or role name.
    ///   - permission: Whether access is allowed or denied.
    ///   - createdBy: The user who created this entry.
    ///   - createdAt: Timestamp of creation.
    public init(
        id: Int64? = nil,
        entityType: EntityType,
        entityID: Int64,
        principalType: PrincipalType,
        principalID: String,
        permission: AccessPermission,
        createdBy: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.entityID = entityID
        self.principalType = principalType
        self.principalID = principalID
        self.permission = permission
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}
