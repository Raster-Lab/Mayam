// SPDX-License-Identifier: (see LICENSE)
// Mayam — Series Model

import Foundation

/// Represents a DICOM series within a study in the Mayam metadata database.
///
/// A series belongs to a ``Study`` and contains one or more SOP instances
/// (individual DICOM objects such as images, reports, or structured reports).
public struct Series: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Stored Properties

    /// Database-generated primary key.
    public let id: Int64?

    /// DICOM Series Instance UID (0020,000E).
    public let seriesInstanceUID: String

    /// Foreign key to the owning ``Study``.
    public let studyID: Int64

    /// DICOM Series Number (0020,0011).
    public var seriesNumber: Int?

    /// DICOM Modality (0008,0060).
    public var modality: String?

    /// DICOM Series Description (0008,103E).
    public var seriesDescription: String?

    /// Number of SOP instances currently recorded for this series.
    public var instanceCount: Int

    /// Row creation timestamp.
    public let createdAt: Date?

    /// Row last-update timestamp.
    public let updatedAt: Date?

    // MARK: - Initialiser

    /// Creates a new series record.
    ///
    /// - Parameters:
    ///   - id: Database primary key (`nil` for unsaved records).
    ///   - seriesInstanceUID: DICOM Series Instance UID (0020,000E).
    ///   - studyID: Foreign key to the owning study.
    ///   - seriesNumber: DICOM Series Number (0020,0011).
    ///   - modality: DICOM Modality (0008,0060).
    ///   - seriesDescription: DICOM Series Description (0008,103E).
    ///   - instanceCount: Number of instances in this series (default: `0`).
    ///   - createdAt: Row creation timestamp.
    ///   - updatedAt: Row last-update timestamp.
    public init(
        id: Int64? = nil,
        seriesInstanceUID: String,
        studyID: Int64,
        seriesNumber: Int? = nil,
        modality: String? = nil,
        seriesDescription: String? = nil,
        instanceCount: Int = 0,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.seriesInstanceUID = seriesInstanceUID
        self.studyID = studyID
        self.seriesNumber = seriesNumber
        self.modality = modality
        self.seriesDescription = seriesDescription
        self.instanceCount = instanceCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
