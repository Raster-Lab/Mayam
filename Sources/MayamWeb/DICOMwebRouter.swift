// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOMweb HTTP Request Router

import Foundation
import MayamCore

// MARK: - HTTPMethod

/// A simple HTTP request method enumeration.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

// MARK: - DICOMwebRequest

/// A parsed DICOMweb HTTP request.
public struct DICOMwebRequest: Sendable {
    /// HTTP method.
    public let method: HTTPMethod
    /// Request path (without base path prefix).
    public let path: String
    /// Query parameters parsed from the URL.
    public let queryParams: [String: String]
    /// Request body.
    public let body: Data
    /// Request headers.
    public let headers: [String: String]

    public init(
        method: HTTPMethod,
        path: String,
        queryParams: [String: String] = [:],
        body: Data = Data(),
        headers: [String: String] = [:]
    ) {
        self.method = method
        self.path = path
        self.queryParams = queryParams
        self.body = body
        self.headers = headers
    }
}

// MARK: - DICOMwebResponse

/// A DICOMweb HTTP response.
public struct DICOMwebResponse: Sendable {
    /// HTTP status code.
    public let statusCode: UInt
    /// Response body.
    public let body: Data
    /// Response headers.
    public let headers: [String: String]

    public init(statusCode: UInt, body: Data = Data(), headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.body = body
        self.headers = headers
    }

    // MARK: - Convenience Factory Methods

    /// Creates a 200 OK response with a JSON body.
    public static func ok(json: Data) -> DICOMwebResponse {
        DICOMwebResponse(
            statusCode: 200,
            body: json,
            headers: ["Content-Type": "application/dicom+json"]
        )
    }

    /// Creates a 200 OK response with a multipart body.
    public static func ok(multipart: Data, boundary: String) -> DICOMwebResponse {
        DICOMwebResponse(
            statusCode: 200,
            body: multipart,
            headers: ["Content-Type": "multipart/related; type=\"application/dicom\"; boundary=\(boundary)"]
        )
    }

    /// Creates a 200 OK response with a custom Content-Type.
    public static func ok(body: Data, contentType: String) -> DICOMwebResponse {
        DICOMwebResponse(statusCode: 200, body: body, headers: ["Content-Type": contentType])
    }

    /// Creates a 201 Created response with a `Location` header.
    public static func created(location: String) -> DICOMwebResponse {
        DICOMwebResponse(statusCode: 201, headers: ["Location": location])
    }

    /// Creates a 204 No Content response.
    public static func noContent() -> DICOMwebResponse {
        DICOMwebResponse(statusCode: 204)
    }

    /// Creates an error response.
    public static func error(_ error: DICOMwebError) -> DICOMwebResponse {
        let body = error.description.data(using: .utf8) ?? Data()
        return DICOMwebResponse(
            statusCode: error.httpStatusCode,
            body: body,
            headers: ["Content-Type": "text/plain"]
        )
    }
}

// MARK: - DICOMwebRouter

/// Routes incoming HTTP requests to the appropriate DICOMweb handler.
///
/// The router implements the URL dispatch logic for all DICOMweb services:
/// WADO-RS, QIDO-RS, STOW-RS, UPS-RS, and WADO-URI.
///
/// URL path patterns follow the DICOMweb standard:
/// - WADO-RS: `{base}/studies/…`
/// - QIDO-RS: `{base}/studies`, `{base}/studies/{uid}/series`, etc.
/// - STOW-RS: `POST {base}/studies`
/// - UPS-RS: `{base}/workitems/…`
/// - WADO-URI: `{base}/wado?requestType=WADO&…`
///
/// Reference: DICOM PS3.18 — Web Services
public struct DICOMwebRouter: Sendable {

    // MARK: - Stored Properties

    private let qidoRS: QIDORSHandler
    private let wadoRS: WADORSHandler
    private let stowRS: STOWRSHandler
    private let upsRS: UPSRSHandler
    private let wadoURI: WADOURIHandler

    // MARK: - Initialiser

    /// Creates a new DICOMweb router.
    ///
    /// - Parameters:
    ///   - qidoRS: The QIDO-RS handler.
    ///   - wadoRS: The WADO-RS handler.
    ///   - stowRS: The STOW-RS handler.
    ///   - upsRS: The UPS-RS handler.
    ///   - wadoURI: The WADO-URI handler.
    public init(
        qidoRS: QIDORSHandler,
        wadoRS: WADORSHandler,
        stowRS: STOWRSHandler,
        upsRS: UPSRSHandler,
        wadoURI: WADOURIHandler
    ) {
        self.qidoRS = qidoRS
        self.wadoRS = wadoRS
        self.stowRS = stowRS
        self.upsRS = upsRS
        self.wadoURI = wadoURI
    }

    // MARK: - Route

    /// Dispatches an HTTP request to the appropriate handler and returns a response.
    ///
    /// - Parameter request: The incoming DICOMweb request.
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

        // WADO-URI: GET /wado?requestType=WADO&...
        if path == "/wado" || path.hasPrefix("/wado?") {
            guard method == .get else {
                throw DICOMwebError.methodNotAllowed(method: method.rawValue)
            }
            return try await handleWADOURI(request)
        }

        // UPS-RS: /workitems/...
        if path.hasPrefix("/workitems") {
            return try await handleUPSRS(request)
        }

        // All other DICOMweb paths start with /studies
        if path.hasPrefix("/studies") {
            return try await handleStudiesPath(request)
        }

        throw DICOMwebError.notFound(resource: path)
    }

    // MARK: - Studies Path Dispatch

    /// Dispatches requests to paths beginning with `/studies`.
    private func handleStudiesPath(_ request: DICOMwebRequest) async throws -> DICOMwebResponse {
        let path = request.path
        let method = request.method
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        // POST /studies or POST /studies/{studyUID} — STOW-RS
        if method == .post {
            let contentType = request.headers["Content-Type"] ?? request.headers["content-type"] ?? ""
            guard contentType.contains("multipart/related") else {
                throw DICOMwebError.unsupportedMediaType(mediaType: contentType)
            }
            let expectedStudyUID = components.count >= 2 ? components[1] : nil
            let result = try await stowRS.storeInstances(
                body: request.body,
                contentType: contentType,
                expectedStudyUID: expectedStudyUID
            )
            let body = try result.encode()
            return DICOMwebResponse(
                statusCode: result.httpStatusCode,
                body: body,
                headers: ["Content-Type": "application/dicom+json"]
            )
        }

        // GET /studies — QIDO-RS: search studies
        if components.count == 1 && components[0] == "studies" && method == .get {
            let data = try await qidoRS.searchStudies(queryParams: request.queryParams)
            return DICOMwebResponse.ok(json: data)
        }

        guard components.count >= 2, components[0] == "studies" else {
            throw DICOMwebError.notFound(resource: path)
        }

        let studyUID = components[1]

        // GET /studies/{studyUID}/metadata — WADO-RS study metadata
        if components.count == 3 && components[2] == "metadata" && method == .get {
            let response = try await wadoRS.retrieveStudyMetadata(studyUID: studyUID)
            return DICOMwebResponse.ok(body: response.body, contentType: response.contentType)
        }

        // GET /studies/{studyUID} — WADO-RS: retrieve study
        if components.count == 2 && method == .get {
            let response = try await wadoRS.retrieveStudy(studyUID: studyUID)
            return DICOMwebResponse.ok(body: response.body, contentType: response.contentType)
        }

        // GET /studies/{studyUID}/series — QIDO-RS: search series in study
        if components.count == 3 && components[2] == "series" && method == .get {
            let data = try await qidoRS.searchSeries(
                studyUID: studyUID,
                queryParams: request.queryParams
            )
            return DICOMwebResponse.ok(json: data)
        }

        guard components.count >= 4, components[2] == "series" else {
            throw DICOMwebError.notFound(resource: path)
        }

        let seriesUID = components[3]

        // GET /studies/{uid}/series/{uid}/metadata — WADO-RS series metadata
        if components.count == 5 && components[4] == "metadata" && method == .get {
            let response = try await wadoRS.retrieveSeriesMetadata(studyUID: studyUID, seriesUID: seriesUID)
            return DICOMwebResponse.ok(body: response.body, contentType: response.contentType)
        }

        // GET /studies/{uid}/series/{uid} — WADO-RS: retrieve series
        if components.count == 4 && method == .get {
            let response = try await wadoRS.retrieveSeries(studyUID: studyUID, seriesUID: seriesUID)
            return DICOMwebResponse.ok(body: response.body, contentType: response.contentType)
        }

        // GET /studies/{uid}/series/{uid}/instances — QIDO-RS: search instances
        if components.count == 5 && components[4] == "instances" && method == .get {
            let data = try await qidoRS.searchInstances(
                studyUID: studyUID,
                seriesUID: seriesUID,
                queryParams: request.queryParams
            )
            return DICOMwebResponse.ok(json: data)
        }

        guard components.count >= 6, components[4] == "instances" else {
            throw DICOMwebError.notFound(resource: path)
        }

        let instanceUID = components[5]

        // GET /studies/{uid}/series/{uid}/instances/{uid}/metadata
        if components.count == 7 && components[6] == "metadata" && method == .get {
            let response = try await wadoRS.retrieveInstanceMetadata(
                studyUID: studyUID,
                seriesUID: seriesUID,
                instanceUID: instanceUID
            )
            return DICOMwebResponse.ok(body: response.body, contentType: response.contentType)
        }

        // GET /studies/{uid}/series/{uid}/instances/{uid}/frames/{numbers}
        if components.count == 8 && components[6] == "frames" && method == .get {
            let frameNumbers = components[7].split(separator: ",").compactMap { Int($0) }
            let response = try await wadoRS.retrieveFrames(
                studyUID: studyUID,
                seriesUID: seriesUID,
                instanceUID: instanceUID,
                frameNumbers: frameNumbers
            )
            return DICOMwebResponse.ok(body: response.body, contentType: response.contentType)
        }

        // GET /studies/{uid}/series/{uid}/instances/{uid}
        if components.count == 6 && method == .get {
            let response = try await wadoRS.retrieveInstance(
                studyUID: studyUID,
                seriesUID: seriesUID,
                instanceUID: instanceUID
            )
            return DICOMwebResponse.ok(body: response.body, contentType: response.contentType)
        }

        throw DICOMwebError.notFound(resource: path)
    }

    // MARK: - UPS-RS Dispatch

    private func handleUPSRS(_ request: DICOMwebRequest) async throws -> DICOMwebResponse {
        let path = request.path
        let method = request.method
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        // POST /workitems — create workitem
        if components.count == 1 && method == .post {
            let preferredUID = request.queryParams["workitem"]
            let record = try await upsRS.createWorkitem(preferredUID: preferredUID)
            return DICOMwebResponse.created(location: "/workitems/\(record.workitemUID)")
        }

        // GET /workitems — query workitems
        if components.count == 1 && method == .get {
            let records = await upsRS.queryWorkitems(queryParams: request.queryParams)
            let dicts = records.map { r -> [String: String] in
                var d: [String: String] = ["00080018": r.workitemUID, "00741000": r.state.rawValue]
                if let label = r.procedureStepLabel { d["00741204"] = label }
                return d
            }
            let body = try JSONSerialization.data(withJSONObject: dicts)
            return DICOMwebResponse.ok(body: body, contentType: "application/dicom+json")
        }

        guard components.count >= 2, components[0] == "workitems" else {
            throw DICOMwebError.notFound(resource: path)
        }

        let uid = components[1]

        // GET /workitems/{uid}
        if components.count == 2 && method == .get {
            let record = try await upsRS.retrieveWorkitem(uid: uid)
            let dict: [String: String] = ["00080018": record.workitemUID, "00741000": record.state.rawValue]
            let body = try JSONSerialization.data(withJSONObject: dict)
            return DICOMwebResponse.ok(body: body, contentType: "application/dicom+json")
        }

        // PUT /workitems/{uid} — update workitem dataset
        if components.count == 2 && method == .put {
            var dataSet: [String: DICOMJSONValue] = [:]
            if !request.body.isEmpty {
                if let parsed = try? JSONDecoder().decode([String: DICOMJSONValue].self, from: request.body) {
                    dataSet = parsed
                }
            }
            let record = try await upsRS.updateWorkitem(uid: uid, dataSet: dataSet)
            let dict: [String: String] = ["00080018": record.workitemUID, "00741000": record.state.rawValue]
            let body = try JSONSerialization.data(withJSONObject: dict)
            return DICOMwebResponse.ok(body: body, contentType: "application/dicom+json")
        }

        // PUT /workitems/{uid}/state
        if components.count == 3 && components[2] == "state" && method == .put {
            guard let stateStr = request.queryParams["state"] ?? parseStateFromBody(request.body),
                  let newState = UPSRecord.State(rawValue: stateStr) else {
                throw DICOMwebError.badRequest(reason: "Invalid or missing state value")
            }
            let performerAE = request.queryParams["performerAETitle"]
            let record = try await upsRS.changeWorkitemState(
                uid: uid,
                newState: newState,
                performerAETitle: performerAE
            )
            let dict: [String: String] = ["00080018": record.workitemUID, "00741000": record.state.rawValue]
            let body = try JSONSerialization.data(withJSONObject: dict)
            return DICOMwebResponse.ok(body: body, contentType: "application/dicom+json")
        }

        // POST /workitems/{uid}/subscribers/{aeTitle}
        if components.count == 4 && components[2] == "subscribers" && method == .post {
            let aeTitle = components[3]
            try await upsRS.subscribe(aeTitle: aeTitle, to: uid)
            return DICOMwebResponse.created(location: "/workitems/\(uid)/subscribers/\(aeTitle)")
        }

        // DELETE /workitems/{uid}/subscribers/{aeTitle}
        if components.count == 4 && components[2] == "subscribers" && method == .delete {
            let aeTitle = components[3]
            await upsRS.unsubscribe(aeTitle: aeTitle, from: uid)
            return DICOMwebResponse.noContent()
        }

        throw DICOMwebError.notFound(resource: path)
    }

    // MARK: - WADO-URI Dispatch

    private func handleWADOURI(_ request: DICOMwebRequest) async throws -> DICOMwebResponse {
        let wadoRequest = try WADOURIRequest.parse(queryParams: request.queryParams)
        let (body, contentType) = try await wadoURI.retrieve(request: wadoRequest)
        return DICOMwebResponse.ok(body: body, contentType: contentType)
    }

    // MARK: - Helpers

    /// Attempts to parse a state value from a JSON request body.
    private func parseStateFromBody(_ body: Data) -> String? {
        guard !body.isEmpty,
              let obj = try? JSONSerialization.jsonObject(with: body) as? [String: String] else {
            return nil
        }
        return obj["00741000"] ?? obj["state"]
    }
}
