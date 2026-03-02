// SPDX-License-Identifier: (see LICENSE)
// Mayam — WADO-RS Handler

import Foundation
import MayamCore

// MARK: - WADORSResponse

/// The result of a WADO-RS retrieval operation.
public struct WADORSResponse: Sendable {
    /// The `Content-Type` header value for the response.
    public let contentType: String

    /// The response body data.
    public let body: Data

    public init(contentType: String, body: Data) {
        self.contentType = contentType
        self.body = body
    }
}

// MARK: - WADORSHandler

/// Implements the WADO-RS (Web Access to DICOM Objects by RESTful Services) service.
///
/// WADO-RS provides RESTful HTTP access to DICOM objects stored in the archive.
/// Responses use `multipart/related` encoding for bulk retrieval and
/// `application/dicom+json` for metadata responses.
///
/// ## Supported Endpoints
///
/// - `GET {base}/studies/{studyUID}` — retrieve all instances in a study.
/// - `GET {base}/studies/{studyUID}/series/{seriesUID}` — retrieve all instances in a series.
/// - `GET {base}/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}` — retrieve one instance.
/// - `GET {base}/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/frames/{frameNumbers}` — retrieve frames.
/// - `GET {base}/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/metadata` — JSON metadata.
/// - `GET {base}/studies/{studyUID}/metadata` — JSON metadata for all instances in a study.
/// - `GET {base}/studies/{studyUID}/series/{seriesUID}/metadata` — JSON metadata for a series.
///
/// Reference: DICOM PS3.18 Section 10.4 — WADO-RS
public struct WADORSHandler: Sendable {

    // MARK: - Stored Properties

    /// Archive root path for reading stored DICOM objects.
    private let archivePath: String

    /// The metadata store for resolving UIDs to file paths.
    private let metadataStore: DICOMMetadataStore

    // MARK: - Initialiser

    /// Creates a new WADO-RS handler.
    ///
    /// - Parameters:
    ///   - archivePath: The root path of the DICOM archive.
    ///   - metadataStore: The metadata store for UID resolution.
    public init(archivePath: String, metadataStore: DICOMMetadataStore) {
        self.archivePath = archivePath
        self.metadataStore = metadataStore
    }

    // MARK: - Study Retrieval

    /// Retrieves all instances in a study as a `multipart/related` response.
    ///
    /// Each part contains the raw DICOM dataset for one instance, served
    /// in the stored transfer syntax (serve-as-stored).
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID.
    ///   - acceptedTransferSyntaxes: Transfer syntaxes accepted by the client.
    /// - Returns: A ``WADORSResponse`` with `multipart/related` content.
    /// - Throws: ``DICOMwebError/notFound`` if the study does not exist.
    public func retrieveStudy(
        studyUID: String,
        acceptedTransferSyntaxes: [String] = []
    ) async throws -> WADORSResponse {
        let instanceResults = await metadataStore.allInstances(inStudy: studyUID)
        guard !instanceResults.isEmpty else {
            throw DICOMwebError.notFound(resource: "Study \(studyUID)")
        }
        return try buildMultipartResponse(from: instanceResults)
    }

    // MARK: - Series Retrieval

    /// Retrieves all instances in a series as a `multipart/related` response.
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID.
    ///   - seriesUID: The Series Instance UID.
    ///   - acceptedTransferSyntaxes: Transfer syntaxes accepted by the client.
    /// - Returns: A ``WADORSResponse`` with `multipart/related` content.
    /// - Throws: ``DICOMwebError/notFound`` if the series does not exist.
    public func retrieveSeries(
        studyUID: String,
        seriesUID: String,
        acceptedTransferSyntaxes: [String] = []
    ) async throws -> WADORSResponse {
        let instanceResults = await metadataStore.allInstances(inSeries: seriesUID, study: studyUID)
        guard !instanceResults.isEmpty else {
            throw DICOMwebError.notFound(resource: "Series \(seriesUID) in study \(studyUID)")
        }
        return try buildMultipartResponse(from: instanceResults)
    }

    // MARK: - Instance Retrieval

    /// Retrieves a single DICOM instance as a `multipart/related` response.
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID.
    ///   - seriesUID: The Series Instance UID.
    ///   - instanceUID: The SOP Instance UID.
    ///   - acceptedTransferSyntaxes: Transfer syntaxes accepted by the client.
    /// - Returns: A ``WADORSResponse`` with `multipart/related` content.
    /// - Throws: ``DICOMwebError/notFound`` if the instance does not exist.
    public func retrieveInstance(
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        acceptedTransferSyntaxes: [String] = []
    ) async throws -> WADORSResponse {
        guard let result = await metadataStore.findInstance(sopInstanceUID: instanceUID) else {
            throw DICOMwebError.notFound(resource: "Instance \(instanceUID)")
        }
        guard result.study.studyInstanceUID == studyUID,
              result.series.seriesInstanceUID == seriesUID else {
            throw DICOMwebError.notFound(resource: "Instance \(instanceUID) in series \(seriesUID)")
        }
        return try buildMultipartResponse(from: [result])
    }

    // MARK: - Frame Retrieval

    /// Retrieves specific frames from a DICOM instance.
    ///
    /// Frame numbers are 1-based per the DICOMweb specification.
    /// Currently returns the full instance data as a single-frame multipart response;
    /// per-frame extraction requires integration with the image codec layer.
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID.
    ///   - seriesUID: The Series Instance UID.
    ///   - instanceUID: The SOP Instance UID.
    ///   - frameNumbers: Array of 1-based frame numbers to retrieve.
    ///   - acceptedTransferSyntaxes: Transfer syntaxes accepted by the client.
    /// - Returns: A ``WADORSResponse`` with `multipart/related` content.
    /// - Throws: ``DICOMwebError/notFound`` if the instance does not exist.
    public func retrieveFrames(
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        frameNumbers: [Int],
        acceptedTransferSyntaxes: [String] = []
    ) async throws -> WADORSResponse {
        guard let result = await metadataStore.findInstance(sopInstanceUID: instanceUID) else {
            throw DICOMwebError.notFound(resource: "Instance \(instanceUID)")
        }
        guard result.study.studyInstanceUID == studyUID,
              result.series.seriesInstanceUID == seriesUID else {
            throw DICOMwebError.notFound(resource: "Instance \(instanceUID) in series \(seriesUID)")
        }

        // Validate frame numbers
        for frame in frameNumbers where frame < 1 {
            throw DICOMwebError.badRequest(reason: "Frame numbers must be 1-based; got \(frame)")
        }

        // Serve the full instance data — per-frame extraction would require codec integration
        return try buildMultipartResponse(from: [result])
    }

    // MARK: - Metadata Retrieval

    /// Retrieves JSON metadata for all instances in a study.
    ///
    /// Returns the DICOMweb JSON metadata (without bulk data) for all instances,
    /// encoded as `application/dicom+json`.
    ///
    /// - Parameter studyUID: The Study Instance UID.
    /// - Returns: A ``WADORSResponse`` with `application/dicom+json` content.
    /// - Throws: ``DICOMwebError/notFound`` if the study does not exist.
    public func retrieveStudyMetadata(studyUID: String) async throws -> WADORSResponse {
        let instanceResults = await metadataStore.allInstances(inStudy: studyUID)
        guard !instanceResults.isEmpty else {
            throw DICOMwebError.notFound(resource: "Study \(studyUID)")
        }
        return try buildMetadataResponse(from: instanceResults)
    }

    /// Retrieves JSON metadata for all instances in a series.
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID.
    ///   - seriesUID: The Series Instance UID.
    /// - Returns: A ``WADORSResponse`` with `application/dicom+json` content.
    /// - Throws: ``DICOMwebError/notFound`` if the series does not exist.
    public func retrieveSeriesMetadata(studyUID: String, seriesUID: String) async throws -> WADORSResponse {
        let instanceResults = await metadataStore.allInstances(inSeries: seriesUID, study: studyUID)
        guard !instanceResults.isEmpty else {
            throw DICOMwebError.notFound(resource: "Series \(seriesUID)")
        }
        return try buildMetadataResponse(from: instanceResults)
    }

    /// Retrieves JSON metadata for a single instance.
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID.
    ///   - seriesUID: The Series Instance UID.
    ///   - instanceUID: The SOP Instance UID.
    /// - Returns: A ``WADORSResponse`` with `application/dicom+json` content.
    /// - Throws: ``DICOMwebError/notFound`` if the instance does not exist.
    public func retrieveInstanceMetadata(
        studyUID: String,
        seriesUID: String,
        instanceUID: String
    ) async throws -> WADORSResponse {
        guard let result = await metadataStore.findInstance(sopInstanceUID: instanceUID) else {
            throw DICOMwebError.notFound(resource: "Instance \(instanceUID)")
        }
        guard result.study.studyInstanceUID == studyUID,
              result.series.seriesInstanceUID == seriesUID else {
            throw DICOMwebError.notFound(resource: "Instance \(instanceUID) in series \(seriesUID)")
        }
        return try buildMetadataResponse(from: [result])
    }

    // MARK: - Private Helpers

    /// Builds a `multipart/related; type="application/dicom"` response from instance results.
    private func buildMultipartResponse(from results: [InstanceSearchResult]) throws -> WADORSResponse {
        let boundary = MultipartDICOM.generateBoundary()
        var parts: [MultipartPart] = []

        for result in results {
            let absolutePath = archivePath + "/" + result.instance.filePath
            guard let data = FileManager.default.contents(atPath: absolutePath) else {
                // Skip instances whose files cannot be read (e.g. during testing)
                continue
            }
            let headers = [
                "Content-Type": "application/dicom",
                "Content-Location": "studies/\(result.study.studyInstanceUID)/series/\(result.series.seriesInstanceUID)/instances/\(result.instance.sopInstanceUID)"
            ]
            parts.append(MultipartPart(headers: headers, body: data))
        }

        let body = MultipartDICOM.serialise(parts: parts, boundary: boundary)
        let contentType = "multipart/related; type=\"application/dicom\"; boundary=\(boundary)"
        return WADORSResponse(contentType: contentType, body: body)
    }

    /// Builds an `application/dicom+json` metadata response.
    private func buildMetadataResponse(from results: [InstanceSearchResult]) throws -> WADORSResponse {
        let attributes = results.map { r in
            DICOMJSONSerializer.instanceAttributes(
                instance: r.instance,
                series: r.series,
                study: r.study
            )
        }
        let body = try DICOMJSONSerializer.encodeArray(attributes)
        return WADORSResponse(contentType: "application/dicom+json", body: body)
    }
}
