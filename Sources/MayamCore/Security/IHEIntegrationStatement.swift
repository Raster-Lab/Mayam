// SPDX-License-Identifier: (see LICENSE)
// Mayam — IHE Integration Statement Model

import Foundation

/// An IHE Integration Statement declares the IHE profiles, actors, and options
/// that Mayam implements.
///
/// Integration Statements are required by IHE for systems participating in
/// Connectathon testing and production IHE-based deployments.  Each statement
/// identifies the profile, the actor(s) played by Mayam within that profile,
/// and any options that are supported.
///
/// ## IHE References
/// - IHE ITI Technical Framework — Integration Statements
/// - IHE Radiology Technical Framework — Integration Profiles
public struct IHEIntegrationStatement: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Nested Types

    /// IHE profile identifiers relevant to radiology PACS.
    public enum Profile: String, Sendable, Codable, Equatable, CaseIterable {
        /// **SWF** — Scheduled Workflow — end-to-end radiology workflow from
        /// order placement through image availability.
        case scheduledWorkflow = "SWF"

        /// **PIR** — Patient Information Reconciliation — reconcile patient
        /// demographics between modality and RIS/HIS.
        case patientInformationReconciliation = "PIR"

        /// **CPI** — Consistent Presentation of Images — ensure images are
        /// displayed consistently across workstations.
        case consistentPresentationOfImages = "CPI"

        /// **KIN** — Key Image Note — flag clinically significant images.
        case keyImageNote = "KIN"

        /// **XDS-I.b** — Cross-Enterprise Document Sharing for Imaging —
        /// share imaging studies across enterprise boundaries.
        case xdsImaging = "XDS-I.b"

        /// **ATNA** — Audit Trail and Node Authentication — secure audit
        /// logging and TLS node authentication.
        case auditTrailNodeAuthentication = "ATNA"
    }

    /// IHE actor roles that Mayam plays within a profile.
    public enum Actor: String, Sendable, Codable, Equatable, CaseIterable {
        /// Image Archive — stores and serves DICOM objects.
        case imageArchive = "Image Archive"
        /// Image Manager — manages studies, routing, and lifecycle.
        case imageManager = "Image Manager"
        /// Order Filler — receives and fulfils imaging orders.
        case orderFiller = "Order Filler"
        /// Evidence Creator — creates key image notes and reports.
        case evidenceCreator = "Evidence Creator"
        /// Imaging Document Source — publishes imaging documents to XDS.
        case imagingDocumentSource = "Imaging Document Source"
        /// Secure Node — implements TLS and audit logging.
        case secureNode = "Secure Node"
        /// Audit Record Repository — stores and manages audit records.
        case auditRecordRepository = "Audit Record Repository"
    }

    /// IHE profile options supported by Mayam.
    public enum ProfileOption: String, Sendable, Codable, Equatable, CaseIterable {
        /// Supports DICOM C-STORE, C-FIND, C-MOVE, C-GET.
        case dicomStorageAndRetrieval = "DICOM Storage and Retrieval"
        /// Supports DICOMweb (WADO-RS, QIDO-RS, STOW-RS).
        case dicomWebAccess = "DICOMweb Access"
        /// Supports MPPS and MWL.
        case modalityPerformedProcedureStep = "MPPS"
        /// Supports patient demographics synchronisation.
        case patientDemographicsQuery = "Patient Demographics Query"
        /// Supports audit message generation and export.
        case auditTrail = "Audit Trail"
        /// Supports TLS 1.3 for all network communication.
        case tlsNodeAuthentication = "TLS Node Authentication"
    }

    // MARK: - Stored Properties

    /// Unique identifier for this integration statement.
    public let id: UUID

    /// The IHE profile this statement covers.
    public let profile: Profile

    /// The actors Mayam plays within this profile.
    public let actors: [Actor]

    /// The profile options supported by Mayam.
    public let options: [ProfileOption]

    /// The version of the IHE Technical Framework referenced.
    public let frameworkVersion: String

    /// The date of this integration statement.
    public let statementDate: Date

    /// Additional notes about conformance or limitations.
    public let notes: String?

    // MARK: - Initialiser

    /// Creates a new IHE Integration Statement.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - profile: The IHE profile.
    ///   - actors: The actors played by Mayam.
    ///   - options: The supported profile options.
    ///   - frameworkVersion: The IHE TF version (defaults to current).
    ///   - statementDate: The statement date (defaults to now).
    ///   - notes: Optional notes.
    public init(
        id: UUID = UUID(),
        profile: Profile,
        actors: [Actor],
        options: [ProfileOption] = [],
        frameworkVersion: String = "IHE ITI/RAD TF Rev. 21.0",
        statementDate: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.profile = profile
        self.actors = actors
        self.options = options
        self.frameworkVersion = frameworkVersion
        self.statementDate = statementDate
        self.notes = notes
    }

    // MARK: - Factory Methods

    /// Returns the complete set of IHE Integration Statements for Mayam.
    ///
    /// These statements declare Mayam's conformance to the targeted IHE
    /// profiles: SWF, PIR, CPI, KIN, XDS-I.b, and ATNA.
    public static func allStatements() -> [IHEIntegrationStatement] {
        [
            IHEIntegrationStatement(
                profile: .scheduledWorkflow,
                actors: [.imageArchive, .imageManager, .orderFiller],
                options: [.dicomStorageAndRetrieval, .modalityPerformedProcedureStep],
                notes: "Supports MWL SCP, MPPS SCP, C-STORE SCP/SCU, C-FIND SCP, C-MOVE SCP, C-GET SCP."
            ),
            IHEIntegrationStatement(
                profile: .patientInformationReconciliation,
                actors: [.imageManager],
                options: [.patientDemographicsQuery],
                notes: "Supports patient demographics update via HL7 ADT and FHIR R4 Patient resource."
            ),
            IHEIntegrationStatement(
                profile: .consistentPresentationOfImages,
                actors: [.imageArchive],
                options: [.dicomStorageAndRetrieval],
                notes: "Stores and serves Grayscale Softcopy Presentation State objects."
            ),
            IHEIntegrationStatement(
                profile: .keyImageNote,
                actors: [.imageArchive],
                options: [.dicomStorageAndRetrieval],
                notes: "Stores and serves Key Object Selection Documents."
            ),
            IHEIntegrationStatement(
                profile: .xdsImaging,
                actors: [.imagingDocumentSource],
                options: [.dicomWebAccess],
                notes: "Publishes imaging studies via DICOMweb (WADO-RS, QIDO-RS, STOW-RS)."
            ),
            IHEIntegrationStatement(
                profile: .auditTrailNodeAuthentication,
                actors: [.secureNode, .auditRecordRepository],
                options: [.auditTrail, .tlsNodeAuthentication],
                notes: "Generates structured audit messages (RFC 3881); supports TLS 1.3 for all connections; tamper-evident local audit storage; syslog export."
            )
        ]
    }
}
