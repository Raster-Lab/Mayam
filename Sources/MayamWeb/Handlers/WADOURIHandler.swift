// SPDX-License-Identifier: (see LICENSE)
// Mayam — WADO-URI Handler

import Foundation
import MayamCore

// MARK: - WADOURIRequest

/// A parsed WADO-URI request.
///
/// WADO-URI is the legacy DICOMweb retrieval service defined by DICOM PS3.18
/// Section 8.1. It uses HTTP GET with mandatory query parameters to retrieve
/// a single DICOM object or a rendered image.
public struct WADOURIRequest: Sendable {

    // MARK: - RequestType

    /// The type of WADO-URI request.
    public enum RequestType: String, Sendable {
        /// Standard DICOM WADO retrieval.
        case wado = "WADO"
    }

    // MARK: - ContentType

    /// The requested content type for the response.
    public enum ContentType: String, Sendable, CaseIterable {
        /// Return the raw DICOM object.
        case applicationDICOM = "application/dicom"
        /// Return a JPEG rendered image.
        case imageJPEG = "image/jpeg"
        /// Return a PNG rendered image.
        case imagePNG = "image/png"
    }

    // MARK: - Stored Properties

    /// Request type (always `.wado`).
    public let requestType: RequestType

    /// DICOM Study Instance UID (0020,000D).
    public let studyUID: String

    /// DICOM Series Instance UID (0020,000E).
    public let seriesUID: String

    /// DICOM SOP Instance UID (0008,0018).
    public let objectUID: String

    /// Requested content type.
    public let contentType: ContentType

    /// Optional frame number (1-based). If absent, all frames are returned.
    public let frameNumber: Int?

    // MARK: - Parsing

    /// Parses a ``WADOURIRequest`` from URL query parameters.
    ///
    /// - Parameter queryParams: URL query parameters.
    /// - Returns: A parsed request, or `nil` if required parameters are missing.
    /// - Throws: ``DICOMwebError/badRequest`` for invalid parameters.
    public static func parse(queryParams: [String: String]) throws -> WADOURIRequest {
        guard let requestType = queryParams["requestType"],
              requestType == "WADO" else {
            throw DICOMwebError.badRequest(reason: "requestType must be 'WADO'")
        }

        guard let studyUID = queryParams["studyUID"], !studyUID.isEmpty else {
            throw DICOMwebError.badRequest(reason: "studyUID is required")
        }
        guard let seriesUID = queryParams["seriesUID"], !seriesUID.isEmpty else {
            throw DICOMwebError.badRequest(reason: "seriesUID is required")
        }
        guard let objectUID = queryParams["objectUID"], !objectUID.isEmpty else {
            throw DICOMwebError.badRequest(reason: "objectUID is required")
        }

        // Parse content type
        let contentTypeParam = queryParams["contentType"] ?? "application/dicom"
        let contentType = ContentType(rawValue: contentTypeParam) ?? .applicationDICOM

        // Parse optional frame number
        let frameNumber: Int?
        if let frameStr = queryParams["frameNumber"] {
            guard let n = Int(frameStr), n >= 1 else {
                throw DICOMwebError.badRequest(reason: "frameNumber must be a positive integer")
            }
            frameNumber = n
        } else {
            frameNumber = nil
        }

        return WADOURIRequest(
            requestType: .wado,
            studyUID: studyUID,
            seriesUID: seriesUID,
            objectUID: objectUID,
            contentType: contentType,
            frameNumber: frameNumber
        )
    }

    private init(
        requestType: RequestType,
        studyUID: String,
        seriesUID: String,
        objectUID: String,
        contentType: ContentType,
        frameNumber: Int?
    ) {
        self.requestType = requestType
        self.studyUID = studyUID
        self.seriesUID = seriesUID
        self.objectUID = objectUID
        self.contentType = contentType
        self.frameNumber = frameNumber
    }
}

// MARK: - WADOURIHandler

/// Implements the legacy WADO-URI (Web Access to DICOM Objects — URI-based)
/// service for backward compatibility with older DICOMweb clients.
///
/// WADO-URI uses HTTP GET with URL query parameters to retrieve a single
/// DICOM object or rendered image. It is the predecessor to WADO-RS.
///
/// ## Endpoint
///
/// `GET {base}/wado?requestType=WADO&studyUID=...&seriesUID=...&objectUID=...`
///
/// Reference: DICOM PS3.18 Section 8.1 — WADO-URI
public struct WADOURIHandler: Sendable {

    // MARK: - Stored Properties

    /// Archive root path for reading stored DICOM objects.
    private let archivePath: String

    /// The metadata store for UID resolution.
    private let metadataStore: DICOMMetadataStore

    // MARK: - Initialiser

    /// Creates a new WADO-URI handler.
    ///
    /// - Parameters:
    ///   - archivePath: The root path of the DICOM archive.
    ///   - metadataStore: The metadata store for UID resolution.
    public init(archivePath: String, metadataStore: DICOMMetadataStore) {
        self.archivePath = archivePath
        self.metadataStore = metadataStore
    }

    // MARK: - Retrieve

    /// Handles a WADO-URI retrieve request.
    ///
    /// Returns the raw DICOM object (when `contentType=application/dicom`) or
    /// a rendered image (when `contentType=image/jpeg` or `image/png`).
    ///
    /// > Note: Rendered image support requires codec integration. Currently
    ///   only `application/dicom` is fully implemented; image rendering
    ///   falls back to the raw DICOM object.
    ///
    /// - Parameter request: The parsed WADO-URI request.
    /// - Returns: The response body data and MIME content type.
    /// - Throws: ``DICOMwebError/notFound`` if the instance does not exist.
    public func retrieve(
        request: WADOURIRequest
    ) async throws -> (body: Data, contentType: String) {
        guard let result = await metadataStore.findInstance(sopInstanceUID: request.objectUID) else {
            throw DICOMwebError.notFound(resource: "Instance \(request.objectUID)")
        }

        guard result.study.studyInstanceUID == request.studyUID else {
            throw DICOMwebError.notFound(
                resource: "Instance \(request.objectUID) in study \(request.studyUID)"
            )
        }
        guard result.series.seriesInstanceUID == request.seriesUID else {
            throw DICOMwebError.notFound(
                resource: "Instance \(request.objectUID) in series \(request.seriesUID)"
            )
        }

        let absolutePath = archivePath + "/" + result.instance.filePath
        guard let data = FileManager.default.contents(atPath: absolutePath) else {
            throw DICOMwebError.internalError(underlying: CocoaError(.fileReadNoSuchFile))
        }

        // Serve as stored (serve-as-stored semantics)
        return (body: data, contentType: "application/dicom")
    }
}
