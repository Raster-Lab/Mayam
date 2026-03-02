// SPDX-License-Identifier: (see LICENSE)
// Mayam — Scheduled Procedure Step Model

import Foundation

/// Represents a Scheduled Procedure Step (SPS) entry for the Modality Worklist.
///
/// An SPS describes a procedure that is scheduled to be performed on a modality.
/// The Modality Worklist SCP serves these records in response to C-FIND queries
/// from modalities, allowing them to populate patient demographics and procedure
/// details automatically.
///
/// Reference: DICOM PS3.4 Annex K — Modality Worklist Information Model
public struct ScheduledProcedureStep: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Nested Types

    /// The status of a scheduled procedure step.
    public enum Status: String, Sendable, Codable, Equatable, CaseIterable {
        /// Procedure is scheduled and awaiting performance.
        case scheduled = "SCHEDULED"

        /// Procedure has arrived at the modality.
        case arrived = "ARRIVED"

        /// Procedure is ready to be performed.
        case ready = "READY"

        /// Procedure has started.
        case started = "STARTED"

        /// Procedure has been completed.
        case completed = "COMPLETED"

        /// Procedure has been discontinued.
        case discontinued = "DISCONTINUED"
    }

    // MARK: - Stored Properties

    /// Unique identifier for this scheduled procedure step.
    public let scheduledProcedureStepID: String

    /// Study Instance UID (0020,000D) for the study this step belongs to.
    public var studyInstanceUID: String

    /// Accession Number (0008,0050).
    public var accessionNumber: String

    /// Patient ID (0010,0020).
    public var patientID: String

    /// Patient Name (0010,0010).
    public var patientName: String

    /// Patient Birth Date (0010,0030).
    public var patientBirthDate: String?

    /// Patient Sex (0010,0040).
    public var patientSex: String?

    /// Referring Physician Name (0008,0090).
    public var referringPhysicianName: String?

    /// Requested Procedure ID (0040,1001).
    public var requestedProcedureID: String?

    /// Requested Procedure Description (0032,1060).
    public var requestedProcedureDescription: String?

    /// Scheduled Procedure Step Start Date (0040,0002).
    public var scheduledStartDate: String

    /// Scheduled Procedure Step Start Time (0040,0003).
    public var scheduledStartTime: String?

    /// Modality (0008,0060) — the type of modality for this step (e.g. CT, MR, CR).
    public var modality: String

    /// Scheduled Performing Physician Name (0040,0006).
    public var scheduledPerformingPhysicianName: String?

    /// Scheduled Procedure Step Description (0040,0007).
    public var scheduledProcedureStepDescription: String?

    /// Scheduled Station AE Title (0040,0001) — the AE title of the modality.
    public var scheduledStationAETitle: String?

    /// Scheduled Station Name (0040,0010).
    public var scheduledStationName: String?

    /// Scheduled Procedure Step Location (0040,0011).
    public var scheduledProcedureStepLocation: String?

    /// Current status of this scheduled procedure step.
    public var status: Status

    /// Row creation timestamp.
    public let createdAt: Date

    /// Row last-update timestamp.
    public var updatedAt: Date

    // MARK: - Identifiable

    public var id: String { scheduledProcedureStepID }

    // MARK: - Initialiser

    /// Creates a new Scheduled Procedure Step record.
    ///
    /// - Parameters:
    ///   - scheduledProcedureStepID: Unique step identifier.
    ///   - studyInstanceUID: Study Instance UID.
    ///   - accessionNumber: Accession Number.
    ///   - patientID: Patient ID.
    ///   - patientName: Patient Name.
    ///   - patientBirthDate: Patient Birth Date.
    ///   - patientSex: Patient Sex.
    ///   - referringPhysicianName: Referring Physician Name.
    ///   - requestedProcedureID: Requested Procedure ID.
    ///   - requestedProcedureDescription: Requested Procedure Description.
    ///   - scheduledStartDate: Scheduled Start Date (DA format).
    ///   - scheduledStartTime: Scheduled Start Time (TM format).
    ///   - modality: Modality type.
    ///   - scheduledPerformingPhysicianName: Scheduled Performing Physician.
    ///   - scheduledProcedureStepDescription: Step description.
    ///   - scheduledStationAETitle: Target modality AE Title.
    ///   - scheduledStationName: Target station name.
    ///   - scheduledProcedureStepLocation: Step location.
    ///   - status: Current status.
    ///   - createdAt: Creation timestamp.
    ///   - updatedAt: Last-update timestamp.
    public init(
        scheduledProcedureStepID: String,
        studyInstanceUID: String,
        accessionNumber: String,
        patientID: String,
        patientName: String,
        patientBirthDate: String? = nil,
        patientSex: String? = nil,
        referringPhysicianName: String? = nil,
        requestedProcedureID: String? = nil,
        requestedProcedureDescription: String? = nil,
        scheduledStartDate: String,
        scheduledStartTime: String? = nil,
        modality: String,
        scheduledPerformingPhysicianName: String? = nil,
        scheduledProcedureStepDescription: String? = nil,
        scheduledStationAETitle: String? = nil,
        scheduledStationName: String? = nil,
        scheduledProcedureStepLocation: String? = nil,
        status: Status = .scheduled,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.scheduledProcedureStepID = scheduledProcedureStepID
        self.studyInstanceUID = studyInstanceUID
        self.accessionNumber = accessionNumber
        self.patientID = patientID
        self.patientName = patientName
        self.patientBirthDate = patientBirthDate
        self.patientSex = patientSex
        self.referringPhysicianName = referringPhysicianName
        self.requestedProcedureID = requestedProcedureID
        self.requestedProcedureDescription = requestedProcedureDescription
        self.scheduledStartDate = scheduledStartDate
        self.scheduledStartTime = scheduledStartTime
        self.modality = modality
        self.scheduledPerformingPhysicianName = scheduledPerformingPhysicianName
        self.scheduledProcedureStepDescription = scheduledProcedureStepDescription
        self.scheduledStationAETitle = scheduledStationAETitle
        self.scheduledStationName = scheduledStationName
        self.scheduledProcedureStepLocation = scheduledProcedureStepLocation
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
