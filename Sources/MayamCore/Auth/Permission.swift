// SPDX-License-Identifier: (see LICENSE)
// Mayam — RBAC Permissions

import Foundation

// MARK: - Permission

/// A fine-grained permission that governs access to a specific area of the
/// admin API.
public enum Permission: String, Sendable, CaseIterable {
    /// View the admin dashboard and statistics.
    case viewDashboard
    /// Create, update, and delete DICOM AE nodes.
    case manageNodes
    /// Manage storage pools and run integrity checks.
    case manageStorage
    /// Read server log entries.
    case viewLogs
    /// Read and write server settings.
    case manageSettings
    /// Create, update, and delete local user accounts.
    case manageUsers
    /// Read and write LDAP integration configuration.
    case manageLDAP
    /// Submit C-FIND, C-MOVE, C-GET query-retrieve operations.
    case queryRetrieve
    /// Browse patient, study, and series records.
    case viewPatients
}

// MARK: - AdminRole + Permissions

public extension AdminRole {

    /// The set of permissions granted to this role.
    var permissions: Set<Permission> {
        switch self {
        case .administrator:
            return Set(Permission.allCases)

        case .technologist:
            return [
                .viewDashboard,
                .manageNodes,
                .manageStorage,
                .viewLogs,
                .queryRetrieve,
                .viewPatients
            ]

        case .physician:
            return [
                .viewDashboard,
                .queryRetrieve,
                .viewPatients,
                .viewLogs
            ]

        case .auditor:
            return [
                .viewDashboard,
                .viewLogs
            ]
        }
    }

    /// Returns `true` if this role has been granted the specified permission.
    ///
    /// - Parameter permission: The permission to check.
    /// - Returns: `true` if the permission is included in this role's set.
    func hasPermission(_ permission: Permission) -> Bool {
        permissions.contains(permission)
    }
}
