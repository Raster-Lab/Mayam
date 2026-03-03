// SPDX-License-Identifier: (see LICENSE)
// Mayam — FHIR R4 Resource Models (ImagingStudy, Endpoint)

import Foundation

// MARK: - Supporting Types

/// A FHIR reference to another resource.
///
/// Represents a reference element as defined by the FHIR R4 specification.
/// Prefixed with `FHIR` to avoid conflicts with HL7kit's own reference type.
public struct FHIRReference: Sendable, Codable, Equatable {

    /// The literal reference string (e.g. `"Patient/123"`).
    public var reference: String?

    /// A human-readable display string for the referenced resource.
    public var display: String?

    /// The expected resource type of the reference (e.g. `"Patient"`).
    public var type: String?

    /// Creates a new FHIR reference.
    ///
    /// - Parameters:
    ///   - reference: Literal reference URI.
    ///   - display: Human-readable description.
    ///   - type: Expected resource type.
    public init(reference: String? = nil, display: String? = nil, type: String? = nil) {
        self.reference = reference
        self.display = display
        self.type = type
    }
}

// MARK: - FHIRIdentifier

/// A FHIR identifier element used to uniquely identify a resource.
///
/// Corresponds to the Identifier data type in the FHIR R4 specification.
public struct FHIRIdentifier: Sendable, Codable, Equatable {

    /// The namespace for the identifier value (e.g. `"urn:dicom:uid"`).
    public var system: String?

    /// The value of the identifier.
    public var value: String?

    /// Creates a new FHIR identifier.
    ///
    /// - Parameters:
    ///   - system: The identifier system URI.
    ///   - value: The identifier value.
    public init(system: String? = nil, value: String? = nil) {
        self.system = system
        self.value = value
    }
}

// MARK: - FHIRCoding

/// A FHIR coding element representing a code from a terminology system.
///
/// Corresponds to the Coding data type in the FHIR R4 specification.
public struct FHIRCoding: Sendable, Codable, Equatable {

    /// The terminology system URI (e.g. `"http://dicom.nema.org/resources/ontology/DCM"`).
    public var system: String?

    /// The code value within the system.
    public var code: String?

    /// A human-readable display string for the code.
    public var display: String?

    /// Creates a new FHIR coding.
    ///
    /// - Parameters:
    ///   - system: Terminology system URI.
    ///   - code: Code value.
    ///   - display: Human-readable description.
    public init(system: String? = nil, code: String? = nil, display: String? = nil) {
        self.system = system
        self.code = code
        self.display = display
    }
}

// MARK: - FHIRCodeableConcept

/// A FHIR codeable concept combining one or more codings with optional text.
///
/// Corresponds to the CodeableConcept data type in the FHIR R4 specification.
public struct FHIRCodeableConcept: Sendable, Codable, Equatable {

    /// One or more codings that define the concept.
    public var coding: [FHIRCoding]?

    /// A plain-text representation of the concept.
    public var text: String?

    /// Creates a new FHIR codeable concept.
    ///
    /// - Parameters:
    ///   - coding: Array of codings for the concept.
    ///   - text: Human-readable text.
    public init(coding: [FHIRCoding]? = nil, text: String? = nil) {
        self.coding = coding
        self.text = text
    }
}

// MARK: - FHIRAnnotation

/// A FHIR annotation element containing a text note.
///
/// Corresponds to the Annotation data type in the FHIR R4 specification.
public struct FHIRAnnotation: Sendable, Codable, Equatable {

    /// The annotation text content.
    public var text: String

    /// Creates a new FHIR annotation.
    ///
    /// - Parameter text: The annotation text.
    public init(text: String) {
        self.text = text
    }
}

// MARK: - FHIRContactPoint

/// A FHIR contact point element representing a communication channel.
///
/// Corresponds to the ContactPoint data type in the FHIR R4 specification.
public struct FHIRContactPoint: Sendable, Codable, Equatable {

    /// The type of contact system (e.g. `"phone"`, `"email"`).
    public var system: String?

    /// The contact detail value.
    public var value: String?

    /// Creates a new FHIR contact point.
    ///
    /// - Parameters:
    ///   - system: Contact system type.
    ///   - value: Contact detail value.
    public init(system: String? = nil, value: String? = nil) {
        self.system = system
        self.value = value
    }
}

// MARK: - FHIRPeriod

/// A FHIR period element representing a time range with start and end boundaries.
///
/// Corresponds to the Period data type in the FHIR R4 specification.
public struct FHIRPeriod: Sendable, Codable, Equatable {

    /// The start of the period as an ISO 8601 date-time string.
    public var start: String?

    /// The end of the period as an ISO 8601 date-time string.
    public var end: String?

    /// Creates a new FHIR period.
    ///
    /// - Parameters:
    ///   - start: Start date-time string.
    ///   - end: End date-time string.
    public init(start: String? = nil, end: String? = nil) {
        self.start = start
        self.end = end
    }
}

// MARK: - FHIRImagingStudy

/// A FHIR R4 ImagingStudy resource model.
///
/// Represents a DICOM imaging study as defined by the FHIR R4 specification
/// (<http://hl7.org/fhir/R4/imagingstudy.html>). This local model bridges
/// Mayam's internal DICOM data to the FHIR representation until HL7kit's
/// FHIRkit module provides a native `ImagingStudy` resource.
///
/// - Note: This type will be retired once
///   [HL7kit](https://github.com/Raster-Lab/HL7kit) ships ImagingStudy support.
public struct FHIRImagingStudy: Sendable, Codable, Equatable {

    // MARK: - Status

    /// The status of the imaging study.
    public enum Status: String, Sendable, Codable, Equatable {
        /// The study has been registered but is not yet available.
        case registered
        /// The study is available for viewing.
        case available
        /// The study has been cancelled.
        case cancelled
        /// The study was entered in error.
        case enteredInError = "entered-in-error"
        /// The study status is unknown.
        case unknown
    }

    // MARK: - Series

    /// A single series within an imaging study.
    public struct Series: Sendable, Codable, Equatable {

        // MARK: - Instance

        /// A single SOP instance within a series.
        public struct Instance: Sendable, Codable, Equatable {

            /// The DICOM SOP Instance UID.
            public var uid: String

            /// The SOP Class coding (e.g. CT Image Storage).
            public var sopClass: FHIRCoding

            /// The instance number within the series.
            public var number: Int?

            /// A human-readable title for the instance.
            public var title: String?

            /// Creates a new imaging study instance.
            ///
            /// - Parameters:
            ///   - uid: DICOM SOP Instance UID.
            ///   - sopClass: SOP Class coding.
            ///   - number: Instance number.
            ///   - title: Human-readable title.
            public init(uid: String, sopClass: FHIRCoding, number: Int? = nil, title: String? = nil) {
                self.uid = uid
                self.sopClass = sopClass
                self.number = number
                self.title = title
            }
        }

        /// The DICOM Series Instance UID.
        public var uid: String

        /// The series number.
        public var number: Int?

        /// The imaging modality coding (e.g. CT, MR).
        public var modality: FHIRCoding

        /// A human-readable description of the series.
        public var description_: String?

        /// The number of SOP instances in the series.
        public var numberOfInstances: Int?

        /// References to DICOMweb endpoints for this series.
        public var endpoint: [FHIRReference]?

        /// The body site examined in this series.
        public var bodySite: FHIRCoding?

        /// The laterality of the body site (e.g. left, right).
        public var laterality: FHIRCoding?

        /// The date and time the series started as an ISO 8601 string.
        public var started: String?

        /// The SOP instances belonging to this series.
        public var instance: [Instance]?

        // MARK: - CodingKeys

        private enum CodingKeys: String, CodingKey {
            case uid, number, modality
            case description_ = "description"
            case numberOfInstances, endpoint, bodySite, laterality, started, instance
        }

        /// Creates a new imaging study series.
        ///
        /// - Parameters:
        ///   - uid: DICOM Series Instance UID.
        ///   - number: Series number.
        ///   - modality: Imaging modality coding.
        ///   - description_: Human-readable description.
        ///   - numberOfInstances: Count of SOP instances.
        ///   - endpoint: DICOMweb endpoint references.
        ///   - bodySite: Body site coding.
        ///   - laterality: Laterality coding.
        ///   - started: Start date-time string.
        ///   - instance: Array of SOP instances.
        public init(
            uid: String,
            number: Int? = nil,
            modality: FHIRCoding,
            description_: String? = nil,
            numberOfInstances: Int? = nil,
            endpoint: [FHIRReference]? = nil,
            bodySite: FHIRCoding? = nil,
            laterality: FHIRCoding? = nil,
            started: String? = nil,
            instance: [Instance]? = nil
        ) {
            self.uid = uid
            self.number = number
            self.modality = modality
            self.description_ = description_
            self.numberOfInstances = numberOfInstances
            self.endpoint = endpoint
            self.bodySite = bodySite
            self.laterality = laterality
            self.started = started
            self.instance = instance
        }
    }

    // MARK: - Stored Properties

    /// The FHIR resource type. Always `"ImagingStudy"`.
    public let resourceType: String = "ImagingStudy"

    /// The logical identifier of the resource.
    public var id: String?

    /// The current status of the imaging study.
    public var status: Status

    /// A reference to the patient who is the subject of the study.
    public var subject: FHIRReference

    /// The date and time the study started as an ISO 8601 string.
    public var started: String?

    /// References to orders that prompted this imaging study.
    public var basedOn: [FHIRReference]?

    /// A reference to the requesting clinician.
    public var referrer: FHIRReference?

    /// References to DICOMweb endpoints where the study is accessible.
    public var endpoint: [FHIRReference]?

    /// The total number of series in the study.
    public var numberOfSeries: Int?

    /// The total number of SOP instances in the study.
    public var numberOfInstances: Int?

    /// A human-readable description of the imaging study.
    public var description_: String?

    /// The series belonging to this imaging study.
    public var series: [Series]?

    /// Business identifiers for the imaging study (e.g. DICOM Study Instance UID).
    public var identifier: [FHIRIdentifier]?

    /// The imaging modalities present in the study.
    public var modality: [FHIRCoding]?

    /// Coded reasons for performing the imaging study.
    public var reasonCode: [FHIRCodeableConcept]?

    /// Annotations and comments about the imaging study.
    public var note: [FHIRAnnotation]?

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case resourceType, id, status, subject, started, basedOn, referrer
        case endpoint, numberOfSeries, numberOfInstances
        case description_ = "description"
        case series, identifier, modality, reasonCode, note
    }

    // MARK: - Initialiser

    /// Creates a new FHIR R4 ImagingStudy resource.
    ///
    /// - Parameters:
    ///   - id: Logical resource identifier.
    ///   - status: Study status.
    ///   - subject: Patient reference.
    ///   - started: Study start date-time string.
    ///   - basedOn: Order references.
    ///   - referrer: Referring clinician reference.
    ///   - endpoint: DICOMweb endpoint references.
    ///   - numberOfSeries: Total number of series.
    ///   - numberOfInstances: Total number of SOP instances.
    ///   - description_: Human-readable description.
    ///   - series: Array of series within the study.
    ///   - identifier: Business identifiers.
    ///   - modality: Imaging modalities present.
    ///   - reasonCode: Coded reasons for the study.
    ///   - note: Annotations and comments.
    public init(
        id: String? = nil,
        status: Status,
        subject: FHIRReference,
        started: String? = nil,
        basedOn: [FHIRReference]? = nil,
        referrer: FHIRReference? = nil,
        endpoint: [FHIRReference]? = nil,
        numberOfSeries: Int? = nil,
        numberOfInstances: Int? = nil,
        description_: String? = nil,
        series: [Series]? = nil,
        identifier: [FHIRIdentifier]? = nil,
        modality: [FHIRCoding]? = nil,
        reasonCode: [FHIRCodeableConcept]? = nil,
        note: [FHIRAnnotation]? = nil
    ) {
        self.id = id
        self.status = status
        self.subject = subject
        self.started = started
        self.basedOn = basedOn
        self.referrer = referrer
        self.endpoint = endpoint
        self.numberOfSeries = numberOfSeries
        self.numberOfInstances = numberOfInstances
        self.description_ = description_
        self.series = series
        self.identifier = identifier
        self.modality = modality
        self.reasonCode = reasonCode
        self.note = note
    }
}

// MARK: - FHIREndpoint

/// A FHIR R4 Endpoint resource model.
///
/// Represents a technical endpoint for connecting to a service, as defined by
/// the FHIR R4 specification (<http://hl7.org/fhir/R4/endpoint.html>). In Mayam
/// this is primarily used to describe DICOMweb endpoints (e.g. WADO-RS, STOW-RS).
///
/// - Note: This type will be retired once
///   [HL7kit](https://github.com/Raster-Lab/HL7kit) ships Endpoint support.
public struct FHIREndpoint: Sendable, Codable, Equatable {

    // MARK: - Status

    /// The status of the endpoint.
    public enum Status: String, Sendable, Codable, Equatable {
        /// The endpoint is expected to be active and can be used.
        case active
        /// The endpoint has been temporarily suspended.
        case suspended
        /// The endpoint is experiencing an error condition.
        case error
        /// The endpoint is no longer active.
        case off
        /// The endpoint was entered in error.
        case enteredInError = "entered-in-error"
    }

    // MARK: - Stored Properties

    /// The FHIR resource type. Always `"Endpoint"`.
    public let resourceType: String = "Endpoint"

    /// The logical identifier of the resource.
    public var id: String?

    /// The current status of the endpoint.
    public var status: Status

    /// The type of connection (e.g. `dicom-wado-rs`, `dicom-stow-rs`).
    public var connectionType: FHIRCoding

    /// A human-readable name for the endpoint.
    public var name: String?

    /// A reference to the organisation that manages the endpoint.
    public var managingOrganization: FHIRReference?

    /// Contact details for the endpoint.
    public var contact: [FHIRContactPoint]?

    /// The time period during which the endpoint is expected to be active.
    public var period: FHIRPeriod?

    /// The payload types supported by the endpoint.
    public var payloadType: [FHIRCodeableConcept]

    /// The MIME types supported by the endpoint (e.g. `"application/dicom"`).
    public var payloadMimeType: [String]?

    /// The technical base address (URL) of the endpoint.
    public var address: String

    /// Additional headers to include when connecting to the endpoint.
    public var header: [String]?

    /// Business identifiers for the endpoint.
    public var identifier: [FHIRIdentifier]?

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case resourceType, id, status, connectionType, name, managingOrganization
        case contact, period, payloadType, payloadMimeType, address, header, identifier
    }

    // MARK: - Initialiser

    /// Creates a new FHIR R4 Endpoint resource.
    ///
    /// - Parameters:
    ///   - id: Logical resource identifier.
    ///   - status: Endpoint status.
    ///   - connectionType: Connection type coding.
    ///   - name: Human-readable name.
    ///   - managingOrganization: Managing organisation reference.
    ///   - contact: Contact details.
    ///   - period: Active period.
    ///   - payloadType: Supported payload types.
    ///   - payloadMimeType: Supported MIME types.
    ///   - address: Technical base URL.
    ///   - header: Additional HTTP headers.
    ///   - identifier: Business identifiers.
    public init(
        id: String? = nil,
        status: Status,
        connectionType: FHIRCoding,
        name: String? = nil,
        managingOrganization: FHIRReference? = nil,
        contact: [FHIRContactPoint]? = nil,
        period: FHIRPeriod? = nil,
        payloadType: [FHIRCodeableConcept],
        payloadMimeType: [String]? = nil,
        address: String,
        header: [String]? = nil,
        identifier: [FHIRIdentifier]? = nil
    ) {
        self.id = id
        self.status = status
        self.connectionType = connectionType
        self.name = name
        self.managingOrganization = managingOrganization
        self.contact = contact
        self.period = period
        self.payloadType = payloadType
        self.payloadMimeType = payloadMimeType
        self.address = address
        self.header = header
        self.identifier = identifier
    }
}
