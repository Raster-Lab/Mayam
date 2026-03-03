// SPDX-License-Identifier: (see LICENSE)
// Mayam — IHE ATNA Audit Event Model

import Foundation

/// A structured audit event conforming to the IHE ATNA (Audit Trail and Node
/// Authentication) profile.
///
/// Audit messages follow the DICOM Audit Message XML format (RFC 3881) and the
/// IHE ITI TF-2a §3.20 specification.  Each event captures who did what to
/// which resource, from where, and when.
///
/// ## DICOM References
/// - DICOM PS3.15 Annex A — Security and System Management Profiles
/// - RFC 3881 — Security Audit and Access Accountability Message XML Data
///   Definitions for Healthcare Applications
public struct ATNAAuditEvent: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Nested Types

    /// Identifies the type of auditable event (RFC 3881 §4.1).
    public enum EventID: String, Sendable, Codable, Equatable, CaseIterable {
        /// DICOM Instances Accessed — a user or process accessed DICOM objects.
        case dicomInstancesAccessed = "110103"
        /// DICOM Instances Transferred — objects were moved between nodes.
        case dicomInstancesTransferred = "110104"
        /// DICOM Study Deleted — a study was permanently removed.
        case dicomStudyDeleted = "110105"
        /// Security Alert — a security-relevant condition was detected.
        case securityAlert = "110113"
        /// User Authentication — a login or logout event.
        case userAuthentication = "110114"
        /// Query — a query was executed against the archive.
        case query = "110112"
        /// Application Activity — the server started or stopped.
        case applicationActivity = "110100"
        /// Audit Log Used — the audit log itself was accessed.
        case auditLogUsed = "110101"
        /// Patient Record — a patient record was created, updated, or deleted.
        case patientRecord = "110110"
        /// Order Record — an order or accession record was modified.
        case orderRecord = "110109"
        /// Export — data was exported from the system.
        case export = "110106"
        /// Import — data was imported into the system.
        case import_ = "110107"
    }

    /// The outcome of the audited event (RFC 3881 §4.1).
    public enum EventOutcome: Int, Sendable, Codable, Equatable, CaseIterable {
        /// Nominal success (0).
        case success = 0
        /// Minor failure; action restarted (4).
        case minorFailure = 4
        /// Serious failure; action terminated (8).
        case seriousFailure = 8
        /// Major failure; action made unavailable (12).
        case majorFailure = 12
    }

    /// Identifies a participant in the audit event (RFC 3881 §4.2).
    public struct ActiveParticipant: Sendable, Codable, Equatable {
        /// User identifier (e.g. login username or AE Title).
        public let userID: String

        /// Human-readable name of the participant.
        public let userName: String?

        /// Whether this participant initiated the audited action.
        public let userIsRequestor: Bool

        /// Network access point identifier (IP address or hostname).
        public let networkAccessPointID: String?

        /// Network access point type (`1` = machine name, `2` = IP address).
        public let networkAccessPointTypeCode: Int?

        /// Creates an active participant.
        public init(
            userID: String,
            userName: String? = nil,
            userIsRequestor: Bool = true,
            networkAccessPointID: String? = nil,
            networkAccessPointTypeCode: Int? = nil
        ) {
            self.userID = userID
            self.userName = userName
            self.userIsRequestor = userIsRequestor
            self.networkAccessPointID = networkAccessPointID
            self.networkAccessPointTypeCode = networkAccessPointTypeCode
        }
    }

    /// Describes an object involved in the audited event (RFC 3881 §4.4).
    public struct ParticipantObject: Sendable, Codable, Equatable {
        /// Type of object (`1` = person, `2` = system object, `3` = organisation).
        public let participantObjectTypeCode: Int

        /// Role of the object (`1` = patient, `3` = report, `4` = resource,
        /// `6` = master file, `24` = query).
        public let participantObjectTypeCodeRole: Int

        /// Identifier for the object (e.g. Patient ID, Study Instance UID).
        public let participantObjectID: String

        /// Human-readable name of the object.
        public let participantObjectName: String?

        /// Creates a participant object.
        public init(
            participantObjectTypeCode: Int,
            participantObjectTypeCodeRole: Int,
            participantObjectID: String,
            participantObjectName: String? = nil
        ) {
            self.participantObjectTypeCode = participantObjectTypeCode
            self.participantObjectTypeCodeRole = participantObjectTypeCodeRole
            self.participantObjectID = participantObjectID
            self.participantObjectName = participantObjectName
        }
    }

    // MARK: - Stored Properties

    /// Unique identifier for this audit event.
    public let id: UUID

    /// The type of event being audited.
    public let eventID: EventID

    /// The outcome of the event.
    public let eventOutcome: EventOutcome

    /// Timestamp when the event occurred (UTC).
    public let eventDateTime: Date

    /// Free-text description of the event action.
    public let eventActionDescription: String?

    /// The active participants involved in the event.
    public let activeParticipants: [ActiveParticipant]

    /// The objects that were the target of the event.
    public let participantObjects: [ParticipantObject]

    /// The source audit node (the system generating this audit message).
    public let auditSourceID: String

    /// HMAC-SHA256 integrity hash for tamper detection, computed over all other
    /// fields when the event is persisted.
    public var integrityHash: String?

    // MARK: - Initialiser

    /// Creates a new ATNA audit event.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - eventID: The type of event being audited.
    ///   - eventOutcome: The outcome of the event.
    ///   - eventDateTime: When the event occurred (defaults to now).
    ///   - eventActionDescription: Optional free-text description.
    ///   - activeParticipants: The participants involved.
    ///   - participantObjects: The objects targeted by the event.
    ///   - auditSourceID: The audit source identifier.
    ///   - integrityHash: Optional HMAC integrity hash.
    public init(
        id: UUID = UUID(),
        eventID: EventID,
        eventOutcome: EventOutcome,
        eventDateTime: Date = Date(),
        eventActionDescription: String? = nil,
        activeParticipants: [ActiveParticipant] = [],
        participantObjects: [ParticipantObject] = [],
        auditSourceID: String = "MAYAM",
        integrityHash: String? = nil
    ) {
        self.id = id
        self.eventID = eventID
        self.eventOutcome = eventOutcome
        self.eventDateTime = eventDateTime
        self.eventActionDescription = eventActionDescription
        self.activeParticipants = activeParticipants
        self.participantObjects = participantObjects
        self.auditSourceID = auditSourceID
        self.integrityHash = integrityHash
    }

    // MARK: - XML Serialisation

    /// Serialises this audit event to DICOM Audit Message XML format.
    ///
    /// The output conforms to the RFC 3881 / DICOM PS3.15 Annex A schema.
    ///
    /// - Returns: A UTF-8 XML string representation.
    public func toAuditMessageXML() -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<AuditMessage>\n"
        xml += "  <EventIdentification "
        xml += "EventActionCode=\"E\" "
        xml += "EventDateTime=\"\(iso8601(eventDateTime))\" "
        xml += "EventOutcomeIndicator=\"\(eventOutcome.rawValue)\">\n"
        xml += "    <EventID code=\"\(eventID.rawValue)\" "
        xml += "codeSystemName=\"DCM\" displayName=\"\(eventID)\"/>\n"
        xml += "  </EventIdentification>\n"

        for participant in activeParticipants {
            xml += "  <ActiveParticipant "
            xml += "UserID=\"\(escapeXML(participant.userID))\" "
            xml += "UserIsRequestor=\"\(participant.userIsRequestor)\""
            if let name = participant.userName {
                xml += " UserName=\"\(escapeXML(name))\""
            }
            if let nap = participant.networkAccessPointID {
                xml += " NetworkAccessPointID=\"\(escapeXML(nap))\""
                xml += " NetworkAccessPointTypeCode=\"\(participant.networkAccessPointTypeCode ?? 2)\""
            }
            xml += "/>\n"
        }

        xml += "  <AuditSourceIdentification AuditSourceID=\"\(escapeXML(auditSourceID))\"/>\n"

        for obj in participantObjects {
            xml += "  <ParticipantObjectIdentification "
            xml += "ParticipantObjectTypeCode=\"\(obj.participantObjectTypeCode)\" "
            xml += "ParticipantObjectTypeCodeRole=\"\(obj.participantObjectTypeCodeRole)\" "
            xml += "ParticipantObjectID=\"\(escapeXML(obj.participantObjectID))\""
            if let name = obj.participantObjectName {
                xml += " ParticipantObjectName=\"\(escapeXML(name))\""
            }
            xml += "/>\n"
        }

        xml += "</AuditMessage>"
        return xml
    }

    // MARK: - Private Helpers

    /// Formats a date as ISO 8601 with millisecond precision.
    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Escapes XML special characters in a string.
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
