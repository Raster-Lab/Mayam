// SPDX-License-Identifier: (see LICENSE)
// Mayam — RIS Event Catalog Model

import Foundation

/// Represents a lifecycle event published via DICOM IAN and RESTful webhooks.
///
/// The RIS Event Catalog defines the full set of study lifecycle events that
/// Mayam publishes to downstream systems (including RIS). Each event carries
/// a type-specific payload with relevant study and patient metadata.
///
/// Reference: Mayam Milestone 10 — RIS Event Catalog
public struct RISEvent: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Nested Types

    /// The type of study lifecycle event.
    public enum EventType: String, Sendable, Codable, Equatable, CaseIterable {
        /// First instance of a new study stored.
        case studyReceived = "study.received"

        /// Additional instances arrive for an existing study.
        case studyUpdated = "study.updated"

        /// Study completeness criteria met.
        case studyComplete = "study.complete"

        /// Study available for retrieval (IAN equivalent).
        case studyAvailable = "study.available"

        /// Study forwarded to a destination.
        case studyRouted = "study.routed"

        /// Study migrated to near-line/offline tier.
        case studyArchived = "study.archived"

        /// Study recalled to online tier.
        case studyRehydrated = "study.rehydrated"

        /// Study permanently removed.
        case studyDeleted = "study.deleted"

        /// Processing error occurred.
        case studyError = "study.error"
    }

    // MARK: - Stored Properties

    /// Unique identifier for this event.
    public let id: UUID

    /// The event type from the RIS Event Catalog.
    public let eventType: EventType

    /// Study Instance UID (0020,000D).
    public let studyInstanceUID: String

    /// Accession Number (0008,0050).
    public var accessionNumber: String?

    /// Patient ID (0010,0020).
    public var patientID: String?

    /// Patient Name (0010,0010).
    public var patientName: String?

    /// Modality (0008,0060).
    public var modality: String?

    /// Study Date (0008,0020).
    public var studyDate: String?

    /// Study Description (0008,1030). Nullable — may be absent when the
    /// triggering event occurs before the attribute is available.
    public var studyDescription: String?

    /// AE Title of the receiving PACS server.
    public var receivingAE: String?

    /// AE Title of the source modality or system.
    public var sourceAE: String?

    /// Number of series in the study at the time of this event.
    public var seriesCount: Int?

    /// Number of instances in the study at the time of this event.
    public var instanceCount: Int?

    /// Latest Series Instance UID added.
    public var latestSeriesUID: String?

    /// Current study status.
    public var studyStatus: String?

    /// AE Title from which the study can be retrieved.
    public var retrieveAE: String?

    /// URL from which the study can be retrieved via DICOMweb.
    public var retrieveURL: String?

    /// Transfer syntaxes available for retrieval.
    public var availableTransferSyntaxes: [String]?

    /// Destination AE Title for routed studies.
    public var destinationAE: String?

    /// Destination URL for routed studies.
    public var destinationURL: String?

    /// Transfer syntax used for routing.
    public var transferSyntaxUsed: String?

    /// Route rule identifier that triggered the routing.
    public var routeRuleID: String?

    /// Storage tier (online, nearline, offline).
    public var storageTier: String?

    /// Archive format (ZIP, TAR+Zstd).
    public var archiveFormat: String?

    /// Path to the archived study.
    public var archivePath: String?

    /// Previous storage tier before rehydration.
    public var previousTier: String?

    /// Current storage tier after rehydration.
    public var currentTier: String?

    /// Duration of the recall operation in seconds.
    public var recallDuration: Double?

    /// Reason for deletion.
    public var deletionReason: String?

    /// User or system that initiated the deletion.
    public var deletedBy: String?

    /// Error code for error events.
    public var errorCode: String?

    /// Error message for error events.
    public var errorMessage: String?

    /// Processing stage where the error occurred.
    public var stage: String?

    /// Timestamp when this event was created.
    public let timestamp: Date

    // MARK: - Initialiser

    /// Creates a new RIS event.
    ///
    /// - Parameters:
    ///   - id: Unique event identifier (auto-generated if omitted).
    ///   - eventType: The lifecycle event type.
    ///   - studyInstanceUID: Study Instance UID.
    ///   - timestamp: Event timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        eventType: EventType,
        studyInstanceUID: String,
        accessionNumber: String? = nil,
        patientID: String? = nil,
        patientName: String? = nil,
        modality: String? = nil,
        studyDate: String? = nil,
        studyDescription: String? = nil,
        receivingAE: String? = nil,
        sourceAE: String? = nil,
        seriesCount: Int? = nil,
        instanceCount: Int? = nil,
        latestSeriesUID: String? = nil,
        studyStatus: String? = nil,
        retrieveAE: String? = nil,
        retrieveURL: String? = nil,
        availableTransferSyntaxes: [String]? = nil,
        destinationAE: String? = nil,
        destinationURL: String? = nil,
        transferSyntaxUsed: String? = nil,
        routeRuleID: String? = nil,
        storageTier: String? = nil,
        archiveFormat: String? = nil,
        archivePath: String? = nil,
        previousTier: String? = nil,
        currentTier: String? = nil,
        recallDuration: Double? = nil,
        deletionReason: String? = nil,
        deletedBy: String? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        stage: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.eventType = eventType
        self.studyInstanceUID = studyInstanceUID
        self.accessionNumber = accessionNumber
        self.patientID = patientID
        self.patientName = patientName
        self.modality = modality
        self.studyDate = studyDate
        self.studyDescription = studyDescription
        self.receivingAE = receivingAE
        self.sourceAE = sourceAE
        self.seriesCount = seriesCount
        self.instanceCount = instanceCount
        self.latestSeriesUID = latestSeriesUID
        self.studyStatus = studyStatus
        self.retrieveAE = retrieveAE
        self.retrieveURL = retrieveURL
        self.availableTransferSyntaxes = availableTransferSyntaxes
        self.destinationAE = destinationAE
        self.destinationURL = destinationURL
        self.transferSyntaxUsed = transferSyntaxUsed
        self.routeRuleID = routeRuleID
        self.storageTier = storageTier
        self.archiveFormat = archiveFormat
        self.archivePath = archivePath
        self.previousTier = previousTier
        self.currentTier = currentTier
        self.recallDuration = recallDuration
        self.deletionReason = deletionReason
        self.deletedBy = deletedBy
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.stage = stage
        self.timestamp = timestamp
    }
}
