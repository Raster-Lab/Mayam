// SPDX-License-Identifier: (see LICENSE)
// Mayam — FHIR R4 REST Handler

import Foundation
import MayamCore

// MARK: - FHIRPatientResource

/// A local FHIR R4 Patient resource model for REST responses.
///
/// This is Mayam's interim adapter model wrapping the essential Patient fields
/// for FHIR R4 REST responses. It will be retired once HL7kit's `FHIRkit`
/// module ships a native `Patient` resource.
public struct FHIRPatientResource: Sendable, Codable, Equatable {

    /// The FHIR resource type. Always `"Patient"`.
    public let resourceType: String

    /// The logical identifier of the resource.
    public let id: String

    /// Business identifiers for the patient.
    public var identifier: [FHIRIdentifier]?

    /// Whether this patient record is in active use.
    public var active: Bool?

    /// A name associated with the patient.
    public var name: [FHIRHumanName]?

    /// Administrative gender.
    public var gender: String?

    /// The date of birth as an ISO 8601 date string.
    public var birthDate: String?

    /// Creates a new FHIR R4 Patient resource.
    ///
    /// - Parameters:
    ///   - id: Logical resource identifier.
    ///   - identifier: Business identifiers.
    ///   - active: Whether the record is active.
    ///   - name: Patient names.
    ///   - gender: Administrative gender.
    ///   - birthDate: Date of birth string.
    public init(
        id: String,
        identifier: [FHIRIdentifier]? = nil,
        active: Bool? = nil,
        name: [FHIRHumanName]? = nil,
        gender: String? = nil,
        birthDate: String? = nil
    ) {
        self.resourceType = "Patient"
        self.id = id
        self.identifier = identifier
        self.active = active
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
    }
}

// MARK: - FHIRHumanName

/// A FHIR R4 HumanName data type.
///
/// Represents a human name with family and given components as defined by the
/// FHIR R4 specification.
public struct FHIRHumanName: Sendable, Codable, Equatable {

    /// The family (surname) component of the name.
    public var family: String?

    /// The given (first name / middle name) components of the name.
    public var given: [String]?

    /// Creates a new FHIR human name.
    ///
    /// - Parameters:
    ///   - family: Family name.
    ///   - given: Given names.
    public init(family: String? = nil, given: [String]? = nil) {
        self.family = family
        self.given = given
    }
}

// MARK: - FHIRDiagnosticReportResource

/// A local FHIR R4 DiagnosticReport resource model for REST responses.
///
/// This is Mayam's interim adapter model wrapping the essential
/// DiagnosticReport fields for FHIR R4 REST responses. It will be retired
/// once HL7kit's `FHIRkit` module ships a native `DiagnosticReport` resource.
public struct FHIRDiagnosticReportResource: Sendable, Codable, Equatable {

    /// The FHIR resource type. Always `"DiagnosticReport"`.
    public let resourceType: String

    /// The logical identifier of the resource.
    public let id: String

    /// The status of the diagnostic report (e.g. `"final"`, `"preliminary"`).
    public var status: String

    /// A code describing the type of report.
    public var code: FHIRCodeableConcept?

    /// A reference to the subject (typically a Patient) of the report.
    public var subject: FHIRReference?

    /// The date and time the report was issued as an ISO 8601 string.
    public var issued: String?

    /// References to related imaging studies.
    public var imagingStudy: [FHIRReference]?

    /// Clinical conclusion from the report.
    public var conclusion: String?

    /// Creates a new FHIR R4 DiagnosticReport resource.
    ///
    /// - Parameters:
    ///   - id: Logical resource identifier.
    ///   - status: Report status.
    ///   - code: Report type code.
    ///   - subject: Subject reference.
    ///   - issued: Issue date-time string.
    ///   - imagingStudy: Related imaging study references.
    ///   - conclusion: Clinical conclusion.
    public init(
        id: String,
        status: String,
        code: FHIRCodeableConcept? = nil,
        subject: FHIRReference? = nil,
        issued: String? = nil,
        imagingStudy: [FHIRReference]? = nil,
        conclusion: String? = nil
    ) {
        self.resourceType = "DiagnosticReport"
        self.id = id
        self.status = status
        self.code = code
        self.subject = subject
        self.issued = issued
        self.imagingStudy = imagingStudy
        self.conclusion = conclusion
    }
}

// MARK: - FHIRResourceStore Protocol

/// An asynchronous store for FHIR R4 resources.
///
/// `FHIRResourceStore` is the abstraction layer between the FHIR REST handler
/// and the underlying storage backend. All operations are `async` to support
/// database I/O without blocking.
public protocol FHIRResourceStore: Sendable {

    /// Searches for imaging studies matching the given parameters.
    ///
    /// - Parameter params: FHIR search query parameters.
    /// - Returns: An array of matching ``FHIRImagingStudy`` resources.
    func searchImagingStudies(params: [String: String]) async -> [FHIRImagingStudy]

    /// Retrieves an imaging study by its logical identifier.
    ///
    /// - Parameter id: The logical resource identifier.
    /// - Returns: The ``FHIRImagingStudy`` if found, otherwise `nil`.
    func getImagingStudy(id: String) async -> FHIRImagingStudy?

    /// Searches for patients matching the given parameters.
    ///
    /// - Parameter params: FHIR search query parameters.
    /// - Returns: An array of matching ``FHIRPatientResource`` resources.
    func searchPatients(params: [String: String]) async -> [FHIRPatientResource]

    /// Retrieves a patient by its logical identifier.
    ///
    /// - Parameter id: The logical resource identifier.
    /// - Returns: The ``FHIRPatientResource`` if found, otherwise `nil`.
    func getPatient(id: String) async -> FHIRPatientResource?

    /// Searches for diagnostic reports matching the given parameters.
    ///
    /// - Parameter params: FHIR search query parameters.
    /// - Returns: An array of matching ``FHIRDiagnosticReportResource`` resources.
    func searchDiagnosticReports(params: [String: String]) async -> [FHIRDiagnosticReportResource]

    /// Retrieves a diagnostic report by its logical identifier.
    ///
    /// - Parameter id: The logical resource identifier.
    /// - Returns: The ``FHIRDiagnosticReportResource`` if found, otherwise `nil`.
    func getDiagnosticReport(id: String) async -> FHIRDiagnosticReportResource?

    /// Searches for endpoints matching the given parameters.
    ///
    /// - Parameter params: FHIR search query parameters.
    /// - Returns: An array of matching ``FHIREndpoint`` resources.
    func searchEndpoints(params: [String: String]) async -> [FHIREndpoint]

    /// Retrieves an endpoint by its logical identifier.
    ///
    /// - Parameter id: The logical resource identifier.
    /// - Returns: The ``FHIREndpoint`` if found, otherwise `nil`.
    func getEndpoint(id: String) async -> FHIREndpoint?
}

// MARK: - InMemoryFHIRResourceStore

/// An in-memory implementation of ``FHIRResourceStore``.
///
/// Used for development, testing, and lightweight deployments where the full
/// PostgreSQL database is not available.
///
/// > Important: This implementation does not persist resources across restarts.
///   Use the PostgreSQL-backed store in production deployments.
public actor InMemoryFHIRResourceStore: FHIRResourceStore {

    // MARK: - Stored Properties

    private var imagingStudies: [FHIRImagingStudy] = []
    private var patients: [FHIRPatientResource] = []
    private var diagnosticReports: [FHIRDiagnosticReportResource] = []
    private var endpoints: [FHIREndpoint] = []

    // MARK: - Initialiser

    /// Creates a new empty in-memory FHIR resource store.
    public init() {}

    // MARK: - Add Methods

    /// Adds an imaging study to the store.
    ///
    /// - Parameter study: The imaging study to add.
    public func addImagingStudy(_ study: FHIRImagingStudy) {
        imagingStudies.append(study)
    }

    /// Adds a patient to the store.
    ///
    /// - Parameter patient: The patient resource to add.
    public func addPatient(_ patient: FHIRPatientResource) {
        patients.append(patient)
    }

    /// Adds a diagnostic report to the store.
    ///
    /// - Parameter report: The diagnostic report resource to add.
    public func addDiagnosticReport(_ report: FHIRDiagnosticReportResource) {
        diagnosticReports.append(report)
    }

    /// Adds an endpoint to the store.
    ///
    /// - Parameter endpoint: The endpoint resource to add.
    public func addEndpoint(_ endpoint: FHIREndpoint) {
        endpoints.append(endpoint)
    }

    // MARK: - FHIRResourceStore Conformance

    public func searchImagingStudies(params: [String: String]) async -> [FHIRImagingStudy] {
        var results = imagingStudies
        if let patientRef = params["patient"] {
            results = results.filter { $0.subject.reference == patientRef }
        }
        if let status = params["status"] {
            results = results.filter { $0.status.rawValue == status }
        }
        return results
    }

    public func getImagingStudy(id: String) async -> FHIRImagingStudy? {
        imagingStudies.first { $0.id == id }
    }

    public func searchPatients(params: [String: String]) async -> [FHIRPatientResource] {
        var results = patients
        if let name = params["name"] {
            results = results.filter { patient in
                patient.name?.contains { humanName in
                    let familyMatch = humanName.family?.localizedCaseInsensitiveContains(name) ?? false
                    let givenMatch = humanName.given?.contains { $0.localizedCaseInsensitiveContains(name) } ?? false
                    return familyMatch || givenMatch
                } ?? false
            }
        }
        if let gender = params["gender"] {
            results = results.filter { $0.gender == gender }
        }
        return results
    }

    public func getPatient(id: String) async -> FHIRPatientResource? {
        patients.first { $0.id == id }
    }

    public func searchDiagnosticReports(params: [String: String]) async -> [FHIRDiagnosticReportResource] {
        var results = diagnosticReports
        if let status = params["status"] {
            results = results.filter { $0.status == status }
        }
        if let subject = params["subject"] {
            results = results.filter { $0.subject?.reference == subject }
        }
        return results
    }

    public func getDiagnosticReport(id: String) async -> FHIRDiagnosticReportResource? {
        diagnosticReports.first { $0.id == id }
    }

    public func searchEndpoints(params: [String: String]) async -> [FHIREndpoint] {
        var results = endpoints
        if let status = params["status"] {
            results = results.filter { $0.status.rawValue == status }
        }
        if let connectionType = params["connection-type"] {
            results = results.filter { $0.connectionType.code == connectionType }
        }
        return results
    }

    public func getEndpoint(id: String) async -> FHIREndpoint? {
        endpoints.first { $0.id == id }
    }
}

// MARK: - FHIRHandler

/// Handles FHIR R4 REST operations for Mayam.
///
/// `FHIRHandler` provides async methods for searching and retrieving FHIR R4
/// resources. Each method returns JSON-encoded `Data` suitable for inclusion
/// in an HTTP response body.
///
/// This handler delegates data access to a ``FHIRResourceStore`` implementation,
/// following the same dependency-injection pattern used by the DICOMweb handlers.
public struct FHIRHandler: Sendable {

    // MARK: - Stored Properties

    private let store: any FHIRResourceStore
    private let encoder: JSONEncoder

    // MARK: - Initialiser

    /// Creates a new FHIR handler.
    ///
    /// - Parameter store: The FHIR resource store for data access.
    public init(store: any FHIRResourceStore) {
        self.store = store
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        self.encoder = enc
    }

    // MARK: - ImagingStudy Operations

    /// Searches for imaging studies matching the given parameters.
    ///
    /// - Parameter params: FHIR search query parameters.
    /// - Returns: JSON-encoded array of ``FHIRImagingStudy`` resources.
    /// - Throws: An error if JSON encoding fails.
    public func searchImagingStudies(params: [String: String]) async throws -> Data {
        let results = await store.searchImagingStudies(params: params)
        return try encoder.encode(results)
    }

    /// Retrieves a single imaging study by its logical identifier.
    ///
    /// - Parameter id: The logical resource identifier.
    /// - Returns: JSON-encoded ``FHIRImagingStudy`` resource.
    /// - Throws: ``DICOMwebError/notFound(resource:)`` if the resource does not exist.
    public func getImagingStudy(id: String) async throws -> Data {
        guard let study = await store.getImagingStudy(id: id) else {
            throw DICOMwebError.notFound(resource: "ImagingStudy/\(id)")
        }
        return try encoder.encode(study)
    }

    // MARK: - Patient Operations

    /// Searches for patients matching the given parameters.
    ///
    /// - Parameter params: FHIR search query parameters.
    /// - Returns: JSON-encoded array of ``FHIRPatientResource`` resources.
    /// - Throws: An error if JSON encoding fails.
    public func searchPatients(params: [String: String]) async throws -> Data {
        let results = await store.searchPatients(params: params)
        return try encoder.encode(results)
    }

    /// Retrieves a single patient by its logical identifier.
    ///
    /// - Parameter id: The logical resource identifier.
    /// - Returns: JSON-encoded ``FHIRPatientResource`` resource.
    /// - Throws: ``DICOMwebError/notFound(resource:)`` if the resource does not exist.
    public func getPatient(id: String) async throws -> Data {
        guard let patient = await store.getPatient(id: id) else {
            throw DICOMwebError.notFound(resource: "Patient/\(id)")
        }
        return try encoder.encode(patient)
    }

    // MARK: - DiagnosticReport Operations

    /// Searches for diagnostic reports matching the given parameters.
    ///
    /// - Parameter params: FHIR search query parameters.
    /// - Returns: JSON-encoded array of ``FHIRDiagnosticReportResource`` resources.
    /// - Throws: An error if JSON encoding fails.
    public func searchDiagnosticReports(params: [String: String]) async throws -> Data {
        let results = await store.searchDiagnosticReports(params: params)
        return try encoder.encode(results)
    }

    /// Retrieves a single diagnostic report by its logical identifier.
    ///
    /// - Parameter id: The logical resource identifier.
    /// - Returns: JSON-encoded ``FHIRDiagnosticReportResource`` resource.
    /// - Throws: ``DICOMwebError/notFound(resource:)`` if the resource does not exist.
    public func getDiagnosticReport(id: String) async throws -> Data {
        guard let report = await store.getDiagnosticReport(id: id) else {
            throw DICOMwebError.notFound(resource: "DiagnosticReport/\(id)")
        }
        return try encoder.encode(report)
    }

    // MARK: - Endpoint Operations

    /// Searches for endpoints matching the given parameters.
    ///
    /// - Parameter params: FHIR search query parameters.
    /// - Returns: JSON-encoded array of ``FHIREndpoint`` resources.
    /// - Throws: An error if JSON encoding fails.
    public func searchEndpoints(params: [String: String]) async throws -> Data {
        let results = await store.searchEndpoints(params: params)
        return try encoder.encode(results)
    }

    /// Retrieves a single endpoint by its logical identifier.
    ///
    /// - Parameter id: The logical resource identifier.
    /// - Returns: JSON-encoded ``FHIREndpoint`` resource.
    /// - Throws: ``DICOMwebError/notFound(resource:)`` if the resource does not exist.
    public func getEndpoint(id: String) async throws -> Data {
        guard let endpoint = await store.getEndpoint(id: id) else {
            throw DICOMwebError.notFound(resource: "Endpoint/\(id)")
        }
        return try encoder.encode(endpoint)
    }
}
