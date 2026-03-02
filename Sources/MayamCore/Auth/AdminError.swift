// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin API Error Types

import Foundation

// MARK: - AdminError

/// Errors that may occur during admin API operations.
public enum AdminError: Error, Sendable, CustomStringConvertible {

    /// The request is not authenticated or the token is invalid/expired.
    case unauthorised
    /// The requesting user does not have the required permission (HTTP 403).
    case forbidden(reason: String)
    /// The requested resource was not found.
    case notFound(resource: String)
    /// The request body or parameters are invalid.
    case badRequest(reason: String)
    /// The operation conflicts with current server state.
    case conflict(reason: String)
    /// An unexpected internal error occurred.
    case internalError(underlying: any Error)

    // MARK: - HTTP Status Code

    /// The HTTP status code associated with this error.
    public var httpStatusCode: UInt {
        switch self {
        case .unauthorised:         return 401
        case .forbidden:            return 403
        case .notFound:             return 404
        case .badRequest:           return 400
        case .conflict:             return 409
        case .internalError:        return 500
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .unauthorised:
            return "Unauthorised: missing or invalid authentication token"
        case .forbidden(let r):
            return "Forbidden: \(r)"
        case .notFound(let r):
            return "Not found: \(r)"
        case .badRequest(let r):
            return "Bad request: \(r)"
        case .conflict(let r):
            return "Conflict: \(r)"
        case .internalError(let e):
            return "Internal error: \(e)"
        }
    }
}
