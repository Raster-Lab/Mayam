// SPDX-License-Identifier: (see LICENSE)
// Mayam — Performed Procedure Step Model

import Foundation

/// Represents a Modality Performed Procedure Step (MPPS) record.
///
/// An MPPS tracks the real-time status of a procedure being performed on a
/// modality. Modalities create an MPPS via N-CREATE when a procedure begins
/// and update it via N-SET when the procedure completes or is discontinued.
///
/// Reference: DICOM PS3.4 Annex F — Modality Performed Procedure Step SOP Class
public struct PerformedProcedureStep: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Nested Types

    /// The status of a performed procedure step.
    ///
    /// Reference: DICOM PS3.3 C.4.14 — Performed Procedure Step Status (0040,0252)
    public enum Status: String, Sendable, Codable, Equatable, CaseIterable {
        /// Procedure is currently in progress.
        case inProgress = "IN PROGRESS"

        /// Procedure has been completed successfully.
        case completed = "COMPLETED"

        /// Procedure was discontinued before completion.
        case discontinued = "DISCONTINUED"
    }

    // MARK: - Stored Properties

    /// The SOP Instance UID uniquely identifying this MPPS instance (0008,0018).
    public let sopInstanceUID: String

    /// Current status of the performed procedure step (0040,0252).
    public var status: Status

    /// Study Instance UID (0020,000D) of the study this step belongs to.
    public var studyInstanceUID: String?

    /// Accession Number (0008,0050).
    public var accessionNumber: String?

    /// Patient ID (0010,0020).
    public var patientID: String?

    /// Patient Name (0010,0010).
    public var patientName: String?

    /// Modality (0008,0060).
    public var modality: String?

    /// Performed Station AE Title (0040,0241).
    public var performedStationAETitle: String?

    /// Performed Station Name (0040,0242).
    public var performedStationName: String?

    /// Performed Procedure Step Start Date (0040,0244).
    public var performedStartDate: String?

    /// Performed Procedure Step Start Time (0040,0245).
    public var performedStartTime: String?

    /// Performed Procedure Step End Date (0040,0250).
    public var performedEndDate: String?

    /// Performed Procedure Step End Time (0040,0251).
    public var performedEndTime: String?

    /// Performed Procedure Step Description (0040,0254).
    public var performedProcedureStepDescription: String?

    /// Performed Procedure Step ID (0040,0253).
    public var performedProcedureStepID: String?

    /// Scheduled Procedure Step ID linking to the worklist (0040,0009).
    public var scheduledProcedureStepID: String?

    /// Series Instance UIDs created during this step.
    public var performedSeriesInstanceUIDs: [String]

    /// Number of instances stored during this step.
    public var numberOfInstances: Int

    /// Row creation timestamp.
    public let createdAt: Date

    /// Row last-update timestamp.
    public var updatedAt: Date

    // MARK: - Identifiable

    public var id: String { sopInstanceUID }

    // MARK: - Initialiser

    /// Creates a new Performed Procedure Step record.
    ///
    /// - Parameters:
    ///   - sopInstanceUID: The SOP Instance UID for this MPPS.
    ///   - status: Initial status (default: `.inProgress`).
    ///   - studyInstanceUID: Study Instance UID.
    ///   - accessionNumber: Accession Number.
    ///   - patientID: Patient ID.
    ///   - patientName: Patient Name.
    ///   - modality: Modality type.
    ///   - performedStationAETitle: Performing station AE Title.
    ///   - performedStationName: Performing station name.
    ///   - performedStartDate: Start date.
    ///   - performedStartTime: Start time.
    ///   - performedEndDate: End date.
    ///   - performedEndTime: End time.
    ///   - performedProcedureStepDescription: Description.
    ///   - performedProcedureStepID: Step identifier.
    ///   - scheduledProcedureStepID: Linked scheduled step ID.
    ///   - performedSeriesInstanceUIDs: Series UIDs created.
    ///   - numberOfInstances: Number of instances stored.
    ///   - createdAt: Creation timestamp.
    ///   - updatedAt: Last-update timestamp.
    public init(
        sopInstanceUID: String,
        status: Status = .inProgress,
        studyInstanceUID: String? = nil,
        accessionNumber: String? = nil,
        patientID: String? = nil,
        patientName: String? = nil,
        modality: String? = nil,
        performedStationAETitle: String? = nil,
        performedStationName: String? = nil,
        performedStartDate: String? = nil,
        performedStartTime: String? = nil,
        performedEndDate: String? = nil,
        performedEndTime: String? = nil,
        performedProcedureStepDescription: String? = nil,
        performedProcedureStepID: String? = nil,
        scheduledProcedureStepID: String? = nil,
        performedSeriesInstanceUIDs: [String] = [],
        numberOfInstances: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.status = status
        self.studyInstanceUID = studyInstanceUID
        self.accessionNumber = accessionNumber
        self.patientID = patientID
        self.patientName = patientName
        self.modality = modality
        self.performedStationAETitle = performedStationAETitle
        self.performedStationName = performedStationName
        self.performedStartDate = performedStartDate
        self.performedStartTime = performedStartTime
        self.performedEndDate = performedEndDate
        self.performedEndTime = performedEndTime
        self.performedProcedureStepDescription = performedProcedureStepDescription
        self.performedProcedureStepID = performedProcedureStepID
        self.scheduledProcedureStepID = scheduledProcedureStepID
        self.performedSeriesInstanceUIDs = performedSeriesInstanceUIDs
        self.numberOfInstances = numberOfInstances
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - MPPSError

/// Errors that may occur during MPPS operations.
public enum MPPSError: Error, Sendable, CustomStringConvertible {

    /// The MPPS instance was not found.
    case instanceNotFound(sopInstanceUID: String)

    /// The MPPS instance already exists (duplicate N-CREATE).
    case duplicateInstance(sopInstanceUID: String)

    /// An invalid state transition was attempted.
    case invalidStateTransition(from: PerformedProcedureStep.Status, to: PerformedProcedureStep.Status)

    /// The MPPS instance cannot be modified because it is in a final state.
    case instanceFinalised(sopInstanceUID: String)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .instanceNotFound(let uid):
            return "MPPS instance '\(uid)' not found"
        case .duplicateInstance(let uid):
            return "MPPS instance '\(uid)' already exists"
        case .invalidStateTransition(let from, let to):
            return "Invalid MPPS state transition from '\(from.rawValue)' to '\(to.rawValue)'"
        case .instanceFinalised(let uid):
            return "MPPS instance '\(uid)' is in a final state and cannot be modified"
        }
    }
}
