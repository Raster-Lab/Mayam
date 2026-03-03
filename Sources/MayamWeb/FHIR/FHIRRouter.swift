// SPDX-License-Identifier: (see LICENSE)
// Mayam — FHIR R4 REST Router

import Foundation
import MayamCore

// MARK: - FHIRRouter

/// Routes incoming HTTP requests to the appropriate FHIR R4 handler method.
///
/// The router implements URL dispatch logic for the FHIR R4 REST API,
/// supporting `Patient`, `ImagingStudy`, `DiagnosticReport`, and `Endpoint`
/// resource types as well as the server `metadata` (CapabilityStatement)
/// endpoint.
///
/// URL path patterns follow the FHIR R4 RESTful API specification:
/// - `GET /{ResourceType}` — search resources
/// - `GET /{ResourceType}/{id}` — read a single resource
/// - `GET /metadata` — server capability statement
///
/// Reference: HL7 FHIR R4 — RESTful API (<http://hl7.org/fhir/R4/http.html>)
public struct FHIRRouter: Sendable {

    // MARK: - Stored Properties

    private let handler: FHIRHandler

    // MARK: - Initialiser

    /// Creates a new FHIR router.
    ///
    /// - Parameter handler: The FHIR handler that implements resource operations.
    public init(handler: FHIRHandler) {
        self.handler = handler
    }

    // MARK: - Route

    /// Dispatches an HTTP request to the appropriate FHIR handler method and returns a response.
    ///
    /// - Parameter request: The incoming HTTP request.
    /// - Returns: The HTTP response.
    public func route(_ request: DICOMwebRequest) async -> DICOMwebResponse {
        do {
            return try await dispatch(request)
        } catch let error as DICOMwebError {
            return DICOMwebResponse.error(error)
        } catch {
            return DICOMwebResponse.error(DICOMwebError.internalError(underlying: error))
        }
    }

    // MARK: - Dispatch

    private func dispatch(_ request: DICOMwebRequest) async throws -> DICOMwebResponse {
        let path = request.path
        let method = request.method
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        // GET /metadata — CapabilityStatement
        if (path == "/metadata" || path == "metadata") && components.last == "metadata" {
            guard method == .get else {
                throw DICOMwebError.methodNotAllowed(method: method.rawValue)
            }
            return try buildCapabilityStatement()
        }

        guard !components.isEmpty else {
            throw DICOMwebError.notFound(resource: path)
        }

        let resourceType = components[0]
        let resourceId: String? = components.count >= 2 ? components[1] : nil

        switch resourceType {
        case "Patient":
            guard method == .get else {
                throw DICOMwebError.methodNotAllowed(method: method.rawValue)
            }
            if let id = resourceId {
                let data = try await handler.getPatient(id: id)
                return fhirOk(json: data)
            } else {
                let data = try await handler.searchPatients(params: request.queryParams)
                return fhirOk(json: data)
            }

        case "ImagingStudy":
            guard method == .get else {
                throw DICOMwebError.methodNotAllowed(method: method.rawValue)
            }
            if let id = resourceId {
                let data = try await handler.getImagingStudy(id: id)
                return fhirOk(json: data)
            } else {
                let data = try await handler.searchImagingStudies(params: request.queryParams)
                return fhirOk(json: data)
            }

        case "DiagnosticReport":
            guard method == .get else {
                throw DICOMwebError.methodNotAllowed(method: method.rawValue)
            }
            if let id = resourceId {
                let data = try await handler.getDiagnosticReport(id: id)
                return fhirOk(json: data)
            } else {
                let data = try await handler.searchDiagnosticReports(params: request.queryParams)
                return fhirOk(json: data)
            }

        case "Endpoint":
            guard method == .get else {
                throw DICOMwebError.methodNotAllowed(method: method.rawValue)
            }
            if let id = resourceId {
                let data = try await handler.getEndpoint(id: id)
                return fhirOk(json: data)
            } else {
                let data = try await handler.searchEndpoints(params: request.queryParams)
                return fhirOk(json: data)
            }

        default:
            throw DICOMwebError.notFound(resource: path)
        }
    }

    // MARK: - Helpers

    /// Creates a 200 OK response with the `application/fhir+json` content type.
    private func fhirOk(json: Data) -> DICOMwebResponse {
        DICOMwebResponse(
            statusCode: 200,
            body: json,
            headers: ["Content-Type": "application/fhir+json"]
        )
    }

    /// Builds a minimal FHIR R4 CapabilityStatement describing the server's supported resources.
    private func buildCapabilityStatement() throws -> DICOMwebResponse {
        let statement: [String: Any] = [
            "resourceType": "CapabilityStatement",
            "status": "active",
            "fhirVersion": "4.0.1",
            "format": ["application/fhir+json"],
            "rest": [
                [
                    "mode": "server",
                    "resource": [
                        ["type": "Patient", "interaction": [["code": "read"], ["code": "search-type"]]],
                        ["type": "ImagingStudy", "interaction": [["code": "read"], ["code": "search-type"]]],
                        ["type": "DiagnosticReport", "interaction": [["code": "read"], ["code": "search-type"]]],
                        ["type": "Endpoint", "interaction": [["code": "read"], ["code": "search-type"]]]
                    ]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: statement, options: [.sortedKeys])
        return fhirOk(json: data)
    }
}
