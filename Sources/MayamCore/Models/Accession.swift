// SPDX-License-Identifier: (see LICENSE)
// Mayam — Accession Model

import Foundation

/// Represents an accession (order/procedure grouping) in the Mayam metadata
/// database.
///
/// An accession belongs to a ``Patient`` and may be associated with one or more
/// ``Study`` records.  The ``deleteProtect`` and ``privacyFlag`` flags provide
/// entity-level protection controls that cascade to child studies.
public struct Accession: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Stored Properties

    /// Database-generated primary key.
    public let id: Int64?

    /// DICOM Accession Number (0008,0050).
    public let accessionNumber: String

    /// Foreign key to the owning ``Patient``.
    public let patientID: Int64

    /// When `true` the accession and all child studies are protected from
    /// deletion until the flag is explicitly removed.
    public var deleteProtect: Bool

    /// When `true` routing and query access to this accession's data is
    /// restricted to explicitly authorised users or roles.
    public var privacyFlag: Bool

    /// Row creation timestamp.
    public let createdAt: Date?

    /// Row last-update timestamp.
    public let updatedAt: Date?

    // MARK: - Initialiser

    public init(
        id: Int64? = nil,
        accessionNumber: String,
        patientID: Int64,
        deleteProtect: Bool = false,
        privacyFlag: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.accessionNumber = accessionNumber
        self.patientID = patientID
        self.deleteProtect = deleteProtect
        self.privacyFlag = privacyFlag
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
