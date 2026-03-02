// SPDX-License-Identifier: (see LICENSE)
// Mayam — Instance Model

import Foundation

/// Represents a DICOM SOP instance (individual DICOM object) in the Mayam
/// metadata database.
///
/// Each instance belongs to a ``Series`` and is associated with the on-disk
/// archive file. The stored ``transferSyntaxUID`` enables serve-as-stored
/// semantics: when a client accepts the stored transfer syntax the raw file
/// is served directly without transcoding.
public struct Instance: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Stored Properties

    /// Database-generated primary key.
    public let id: Int64?

    /// DICOM SOP Instance UID (0008,0018).
    public let sopInstanceUID: String

    /// DICOM SOP Class UID (0008,0016).
    public let sopClassUID: String

    /// Foreign key to the owning ``Series``.
    public let seriesID: Int64

    /// DICOM Instance Number (0020,0013).
    public var instanceNumber: Int?

    /// Transfer syntax UID in which the object is stored (store-as-received).
    ///
    /// Used to implement serve-as-stored semantics: the object is returned in
    /// this transfer syntax when the requesting client declares support for it.
    public let transferSyntaxUID: String

    /// SHA-256 integrity checksum of the stored file (hex-encoded).
    public var checksumSHA256: String?

    /// Size of the stored file in bytes.
    public let fileSizeBytes: Int64

    /// Path to the stored file relative to the archive root directory.
    public let filePath: String

    /// DICOM AE Title of the sending application entity (if known).
    public let callingAETitle: String?

    /// Row creation timestamp.
    public let createdAt: Date?

    /// Row last-update timestamp.
    public let updatedAt: Date?

    // MARK: - Initialiser

    /// Creates a new instance record.
    ///
    /// - Parameters:
    ///   - id: Database primary key (`nil` for unsaved records).
    ///   - sopInstanceUID: DICOM SOP Instance UID (0008,0018).
    ///   - sopClassUID: DICOM SOP Class UID (0008,0016).
    ///   - seriesID: Foreign key to the owning series.
    ///   - instanceNumber: DICOM Instance Number (0020,0013).
    ///   - transferSyntaxUID: The transfer syntax UID as stored.
    ///   - checksumSHA256: Hex-encoded SHA-256 checksum of the file.
    ///   - fileSizeBytes: Size of the stored file in bytes.
    ///   - filePath: Path relative to the archive root.
    ///   - callingAETitle: AE Title of the sending entity.
    ///   - createdAt: Row creation timestamp.
    ///   - updatedAt: Row last-update timestamp.
    public init(
        id: Int64? = nil,
        sopInstanceUID: String,
        sopClassUID: String,
        seriesID: Int64,
        instanceNumber: Int? = nil,
        transferSyntaxUID: String,
        checksumSHA256: String? = nil,
        fileSizeBytes: Int64,
        filePath: String,
        callingAETitle: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.seriesID = seriesID
        self.instanceNumber = instanceNumber
        self.transferSyntaxUID = transferSyntaxUID
        self.checksumSHA256 = checksumSHA256
        self.fileSizeBytes = fileSizeBytes
        self.filePath = filePath
        self.callingAETitle = callingAETitle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
