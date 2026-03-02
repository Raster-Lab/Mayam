// SPDX-License-Identifier: (see LICENSE)
// Mayam — MayamAdmin Module

import Foundation

/// The MayamAdmin module bundles static web assets for the administration
/// console.
///
/// ## Planned Features
/// - Dashboard — server status, storage utilisation, metrics.
/// - DICOM Node Manager — add, edit, verify remote AE Titles.
/// - Storage Manager — view pools, utilisation, integrity checks.
/// - Log Viewer — filterable audit and application logs.
/// - System Settings — AE Title, ports, TLS, LDAP, backup.
/// - Setup Wizard — guided first-run configuration.
///
/// > Note: Full implementation is part of Milestone 7.
public enum MayamAdmin {
    /// The current version of the MayamAdmin module.
    public static let version = "0.1.0"
}
