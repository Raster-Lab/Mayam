// SPDX-License-Identifier: (see LICENSE)
// Mayam — QIDO-RS Handler

import Foundation
import MayamCore

// MARK: - QIDORSHandler

/// Implements the QIDO-RS (Query based on ID for DICOM Objects by RESTful Services)
/// service.
///
/// QIDO-RS allows clients to search for DICOM studies, series, and instances
/// via HTTP GET requests. Results are returned as a JSON array of DICOM attribute
/// objects conforming to the DICOMweb JSON model.
///
/// ## Supported Endpoints
///
/// - `GET {base}/studies` — search for studies.
/// - `GET {base}/studies/{studyUID}/series` — search for series within a study.
/// - `GET {base}/studies/{studyUID}/series/{seriesUID}/instances` — search for instances.
///
/// Reference: DICOM PS3.18 Section 8.3 — QIDO-RS
public struct QIDORSHandler: Sendable {

    // MARK: - Stored Properties

    /// The metadata store providing access to DICOM object metadata.
    private let metadataStore: DICOMMetadataStore

    // MARK: - Initialiser

    /// Creates a new QIDO-RS handler.
    ///
    /// - Parameter metadataStore: The metadata store to query.
    public init(metadataStore: DICOMMetadataStore) {
        self.metadataStore = metadataStore
    }

    // MARK: - Study Search

    /// Searches for studies matching the supplied query parameters.
    ///
    /// Supported query parameters:
    /// - `StudyInstanceUID` (0020,000D)
    /// - `PatientID` (0010,0020)
    /// - `PatientName` (0010,0010) — supports `*` wildcard suffix.
    /// - `StudyDate` (0008,0020) — `YYYYMMDD` or `YYYYMMDD-YYYYMMDD` range.
    /// - `Modality` (0008,0061)
    /// - `limit` — maximum number of results (default 100, max 1000).
    /// - `offset` — result offset for pagination.
    ///
    /// - Parameter queryParams: URL query parameters as a flat string→string map.
    /// - Returns: A JSON `Data` array of study attribute objects.
    /// - Throws: ``DICOMwebError`` if the request is invalid or the query fails.
    public func searchStudies(queryParams: [String: String]) async throws -> Data {
        let query = StudyQuery(from: queryParams)
        let results = await metadataStore.searchStudies(query: query)
        let attributes = results.map { pair in
            DICOMJSONSerializer.studyAttributes(
                study: pair.study,
                patient: pair.patient,
                numberOfSeries: pair.numberOfSeries,
                numberOfInstances: pair.numberOfInstances
            )
        }
        return try DICOMJSONSerializer.encodeArray(attributes)
    }

    // MARK: - Series Search

    /// Searches for series within a specific study.
    ///
    /// Supported query parameters:
    /// - `SeriesInstanceUID` (0020,000E)
    /// - `Modality` (0008,0060)
    /// - `SeriesNumber` (0020,0011)
    /// - `limit` and `offset` for pagination.
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID constraining the search.
    ///   - queryParams: URL query parameters.
    /// - Returns: A JSON `Data` array of series attribute objects.
    /// - Throws: ``DICOMwebError`` if the study is not found or the query fails.
    public func searchSeries(
        studyUID: String,
        queryParams: [String: String]
    ) async throws -> Data {
        guard !studyUID.isEmpty else {
            throw DICOMwebError.badRequest(reason: "studyInstanceUID is required")
        }

        let results = await metadataStore.searchSeries(studyUID: studyUID, query: queryParams)
        let attributes = results.map { pair in
            DICOMJSONSerializer.seriesAttributes(
                series: pair.series,
                study: pair.study,
                numberOfInstances: pair.numberOfInstances
            )
        }
        return try DICOMJSONSerializer.encodeArray(attributes)
    }

    // MARK: - Instance Search

    /// Searches for instances within a specific series.
    ///
    /// Supported query parameters:
    /// - `SOPInstanceUID` (0008,0018)
    /// - `SOPClassUID` (0008,0016)
    /// - `InstanceNumber` (0020,0013)
    /// - `limit` and `offset` for pagination.
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID.
    ///   - seriesUID: The Series Instance UID.
    ///   - queryParams: URL query parameters.
    /// - Returns: A JSON `Data` array of instance attribute objects.
    /// - Throws: ``DICOMwebError`` if the study or series is not found.
    public func searchInstances(
        studyUID: String,
        seriesUID: String,
        queryParams: [String: String]
    ) async throws -> Data {
        guard !studyUID.isEmpty else {
            throw DICOMwebError.badRequest(reason: "studyInstanceUID is required")
        }
        guard !seriesUID.isEmpty else {
            throw DICOMwebError.badRequest(reason: "seriesInstanceUID is required")
        }

        let results = await metadataStore.searchInstances(
            studyUID: studyUID,
            seriesUID: seriesUID,
            query: queryParams
        )
        let attributes = results.map { triple in
            DICOMJSONSerializer.instanceAttributes(
                instance: triple.instance,
                series: triple.series,
                study: triple.study
            )
        }
        return try DICOMJSONSerializer.encodeArray(attributes)
    }
}

// MARK: - StudyQuery

/// A parsed set of QIDO-RS study query parameters.
public struct StudyQuery: Sendable {
    public let studyInstanceUID: String?
    public let patientID: String?
    public let patientName: String?
    public let studyDate: String?
    public let modality: String?
    public let limit: Int
    public let offset: Int

    /// Parses a `StudyQuery` from URL query parameters.
    ///
    /// - Parameter params: The query parameter map.
    public init(from params: [String: String]) {
        self.studyInstanceUID = params["StudyInstanceUID"] ?? params["0020000D"]
        self.patientID = params["PatientID"] ?? params["00100020"]
        self.patientName = params["PatientName"] ?? params["00100010"]
        self.studyDate = params["StudyDate"] ?? params["00080020"]
        self.modality = params["Modality"] ?? params["00080061"]
        self.limit = min(Int(params["limit"] ?? "100") ?? 100, 1000)
        self.offset = Int(params["offset"] ?? "0") ?? 0
    }
}
