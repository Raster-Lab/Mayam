// SPDX-License-Identifier: (see LICENSE)
// Mayam — Administrative Role

import Foundation

// MARK: - AdminRole

/// Administrative role assigned to an admin user.
public enum AdminRole: String, Codable, Sendable, CaseIterable {
    /// Full system administration access.
    case administrator
    /// Radiographer / radiologic technologist access.
    case technologist
    /// Clinician read-only access.
    case physician
    /// Audit-log read-only access.
    case auditor
}
