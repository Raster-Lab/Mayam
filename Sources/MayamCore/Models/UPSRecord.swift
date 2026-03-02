// SPDX-License-Identifier: (see LICENSE)
// Mayam — Unified Procedure Step (UPS) Record Model

import Foundation

/// Represents a DICOM Unified Procedure Step (UPS) workitem.
///
/// A UPS workitem describes a unit of work to be performed (e.g. a study to
/// be read, a procedure to be performed, or a QC task). The UPS-RS service
/// allows clients to create, query, retrieve, update, and monitor workitems
/// via RESTful HTTP.
///
/// Reference: DICOM PS3.4 Annex CC — Unified Procedure Step Service and SOP Classes
public struct UPSRecord: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Nested Types

    /// The state of a UPS workitem.
    ///
    /// Reference: DICOM PS3.4 Table CC.1.1-2 — UPS State Descriptions
    public enum State: String, Sendable, Codable, Equatable, CaseIterable {
        /// Workitem is available to be claimed.
        case scheduled = "SCHEDULED"

        /// Workitem has been claimed by a performer.
        case inProgress = "IN PROGRESS"

        /// Workitem has been completed successfully.
        case completed = "COMPLETED"

        /// Workitem has been cancelled.
        case cancelled = "CANCELLED"
    }

    // MARK: - Stored Properties

    /// Unique identifier for this workitem (used as the ``id``).
    public let workitemUID: String

    /// Current state of the workitem.
    public var state: State

    /// DICOM Scheduled Procedure Step Start DateTime (0040,4005).
    public var scheduledStartDateTime: Date?

    /// DICOM Procedure Step Label (0074,1204) — human-readable description.
    public var procedureStepLabel: String?

    /// DICOM Worklist Label (0074,1202) — name of the worklist this workitem belongs to.
    public var worklistLabel: String?

    /// DICOM Scheduled Station Name Code Sequence value (0040,4025) — station identifier.
    public var scheduledStationName: String?

    /// DICOM Input Readiness State (0040,4041).
    public var inputReadinessState: String?

    /// DICOM Scheduled Procedure Step Priority (0074,1200).
    public var priority: String?

    /// AE Title of the performer that has claimed this workitem, if in progress.
    public var performerAETitle: String?

    /// The raw DICOM dataset for this workitem (encoded as DICOM JSON).
    public var dataSet: [String: DICOMJSONValue]

    /// Row creation timestamp.
    public let createdAt: Date

    /// Row last-update timestamp.
    public var updatedAt: Date

    // MARK: - Identifiable

    public var id: String { workitemUID }

    // MARK: - Initialiser

    /// Creates a new UPS workitem record.
    ///
    /// - Parameters:
    ///   - workitemUID: The unique UID for this workitem.
    ///   - state: Initial state (default: `.scheduled`).
    ///   - scheduledStartDateTime: Scheduled start time.
    ///   - procedureStepLabel: Human-readable label.
    ///   - worklistLabel: Worklist name.
    ///   - scheduledStationName: Station name.
    ///   - inputReadinessState: Input readiness state.
    ///   - priority: Scheduling priority.
    ///   - performerAETitle: AE Title of the current performer.
    ///   - dataSet: Raw DICOM JSON dataset.
    ///   - createdAt: Creation timestamp.
    ///   - updatedAt: Last-update timestamp.
    public init(
        workitemUID: String,
        state: State = .scheduled,
        scheduledStartDateTime: Date? = nil,
        procedureStepLabel: String? = nil,
        worklistLabel: String? = nil,
        scheduledStationName: String? = nil,
        inputReadinessState: String? = nil,
        priority: String? = nil,
        performerAETitle: String? = nil,
        dataSet: [String: DICOMJSONValue] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.workitemUID = workitemUID
        self.state = state
        self.scheduledStartDateTime = scheduledStartDateTime
        self.procedureStepLabel = procedureStepLabel
        self.worklistLabel = worklistLabel
        self.scheduledStationName = scheduledStationName
        self.inputReadinessState = inputReadinessState
        self.priority = priority
        self.performerAETitle = performerAETitle
        self.dataSet = dataSet
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - DICOMJSONValue

/// A JSON-encodable DICOM attribute value for use in UPS and DICOMweb responses.
///
/// Represents a single attribute entry in the DICOM JSON encoding defined by
/// DICOM PS3.18 Section F — DICOM JSON Model.
public enum DICOMJSONValue: Sendable, Codable, Equatable {

    /// A string value (covers VRs: AE, AS, CS, DA, DS, DT, IS, LO, LT, SH, ST, TM, UC, UI, UR, UT).
    case string([String?])

    /// A number value (covers VRs: DS, IS, FL, FD, SL, SS, UL, US).
    case number([Double?])

    /// A boolean value.
    case bool(Bool)

    /// A sequence of nested datasets (VR: SQ).
    case sequence([[String: DICOMJSONValue]])

    /// Bulk data URI reference.
    case bulkDataURI(String)

    /// An empty / zero-length value.
    case empty

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case vr, Value, BulkDataURI
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.decodeIfPresent(String.self, forKey: .vr)

        if let bulkURI = try container.decodeIfPresent(String.self, forKey: .BulkDataURI) {
            self = .bulkDataURI(bulkURI)
            return
        }

        // Try sequence first
        if let seq = try? container.decodeIfPresent([[String: DICOMJSONValue]].self, forKey: .Value) {
            self = .sequence(seq)
            return
        }

        // Try string array
        if let strings = try? container.decodeIfPresent([String?].self, forKey: .Value) {
            self = .string(strings)
            return
        }

        // Try number array
        if let numbers = try? container.decodeIfPresent([Double?].self, forKey: .Value) {
            self = .number(numbers)
            return
        }

        self = .empty
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let values):
            try container.encode(values, forKey: .Value)
        case .number(let values):
            try container.encode(values, forKey: .Value)
        case .bool(let value):
            try container.encode([value ? "true" : "false"], forKey: .Value)
        case .sequence(let seq):
            try container.encode(seq, forKey: .Value)
        case .bulkDataURI(let uri):
            try container.encode(uri, forKey: .BulkDataURI)
        case .empty:
            break
        }
    }
}
