// SPDX-License-Identifier: (see LICENSE)
// Mayam — Study Model

import Foundation

/// Represents a DICOM study record in the Mayam metadata database.
///
/// Each study belongs to a ``Patient`` and may optionally be linked to an
/// ``Accession``.  The ``deleteProtect`` and ``privacyFlag`` flags provide
/// entity-level protection controls.
public struct Study: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Stored Properties

    /// Database-generated primary key.
    public let id: Int64?

    /// DICOM Study Instance UID (0020,000D).
    public let studyInstanceUID: String

    /// Foreign key to the associated ``Accession`` (nullable).
    public let accessionID: Int64?

    /// Foreign key to the owning ``Patient``.
    public let patientID: Int64

    /// DICOM Study Date (0008,0020).
    public var studyDate: Date?

    /// DICOM Study Description (0008,1030).
    public var studyDescription: String?

    /// Primary modality of the study.
    public var modality: String?

    /// When `true` the study is protected from deletion until the flag is
    /// explicitly removed.
    public var deleteProtect: Bool

    /// When `true` routing and query access to this study is restricted to
    /// explicitly authorised users or roles.
    public var privacyFlag: Bool

    /// SHA-256 integrity checksum of the archived study data.
    public var checksumSHA256: String?

    /// Row creation timestamp.
    public let createdAt: Date?

    /// Row last-update timestamp.
    public let updatedAt: Date?

    // MARK: - Initialiser

    public init(
        id: Int64? = nil,
        studyInstanceUID: String,
        accessionID: Int64? = nil,
        patientID: Int64,
        studyDate: Date? = nil,
        studyDescription: String? = nil,
        modality: String? = nil,
        deleteProtect: Bool = false,
        privacyFlag: Bool = false,
        checksumSHA256: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.studyInstanceUID = studyInstanceUID
        self.accessionID = accessionID
        self.patientID = patientID
        self.studyDate = studyDate
        self.studyDescription = studyDescription
        self.modality = modality
        self.deleteProtect = deleteProtect
        self.privacyFlag = privacyFlag
        self.checksumSHA256 = checksumSHA256
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
