// SPDX-License-Identifier: (see LICENSE)
// Mayam — Patient Model

import Foundation

/// Represents a DICOM patient record in the Mayam metadata database.
///
/// Each patient may have one or more ``Accession`` records and, transitively,
/// one or more ``Study`` records.  The ``deleteProtect`` and ``privacyFlag``
/// flags provide entity-level protection controls that cascade to child records.
public struct Patient: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Stored Properties

    /// Database-generated primary key.
    public let id: Int64?

    /// DICOM Patient ID (0010,0020).
    public let patientID: String

    /// DICOM Patient Name (0010,0010).
    public var patientName: String?

    /// When `true` the patient and all child accessions / studies are protected
    /// from deletion until the flag is explicitly removed.
    public var deleteProtect: Bool

    /// When `true` routing and query access to this patient's data is restricted
    /// to explicitly authorised users or roles.
    public var privacyFlag: Bool

    /// Row creation timestamp.
    public let createdAt: Date?

    /// Row last-update timestamp.
    public let updatedAt: Date?

    // MARK: - Initialiser

    public init(
        id: Int64? = nil,
        patientID: String,
        patientName: String? = nil,
        deleteProtect: Bool = false,
        privacyFlag: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.patientID = patientID
        self.patientName = patientName
        self.deleteProtect = deleteProtect
        self.privacyFlag = privacyFlag
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
