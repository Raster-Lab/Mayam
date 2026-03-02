// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOMweb Error Types

import Foundation

/// Errors that may occur during DICOMweb service operations.
///
/// Each case represents a distinct failure mode with an associated HTTP status
/// code and descriptive message.
///
/// Reference: DICOM PS3.18 — Web Services
public enum DICOMwebError: Error, Sendable, CustomStringConvertible {

    /// The requested resource was not found (HTTP 404).
    case notFound(resource: String)

    /// The request body or parameters are invalid (HTTP 400).
    case badRequest(reason: String)

    /// The Content-Type is not acceptable for this endpoint (HTTP 415).
    case unsupportedMediaType(mediaType: String)

    /// The Accept header does not match any available representation (HTTP 406).
    case notAcceptable(accepted: String)

    /// The request method is not allowed for this resource (HTTP 405).
    case methodNotAllowed(method: String)

    /// A state transition is not permitted (HTTP 409).
    case conflict(reason: String)

    /// Parsing a multipart body failed.
    case multipartParseFailure(reason: String)

    /// Parsing a DICOM JSON body failed.
    case jsonParseFailure(reason: String)

    /// An underlying I/O error occurred (HTTP 500).
    case internalError(underlying: any Error)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .notFound(let r):
            return "Not found: \(r)"
        case .badRequest(let r):
            return "Bad request: \(r)"
        case .unsupportedMediaType(let m):
            return "Unsupported media type: \(m)"
        case .notAcceptable(let a):
            return "Not acceptable; client accepted: \(a)"
        case .methodNotAllowed(let m):
            return "Method not allowed: \(m)"
        case .conflict(let r):
            return "Conflict: \(r)"
        case .multipartParseFailure(let r):
            return "Multipart parse failure: \(r)"
        case .jsonParseFailure(let r):
            return "JSON parse failure: \(r)"
        case .internalError(let e):
            return "Internal error: \(e)"
        }
    }

    /// The HTTP status code associated with this error.
    public var httpStatusCode: UInt {
        switch self {
        case .notFound: return 404
        case .badRequest: return 400
        case .unsupportedMediaType: return 415
        case .notAcceptable: return 406
        case .methodNotAllowed: return 405
        case .conflict: return 409
        case .multipartParseFailure: return 400
        case .jsonParseFailure: return 400
        case .internalError: return 500
        }
    }
}
