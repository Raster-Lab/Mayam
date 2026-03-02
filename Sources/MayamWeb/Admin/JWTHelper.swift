// SPDX-License-Identifier: (see LICENSE)
// Mayam — JWT Helper (HS256)

import Foundation
import Crypto

// MARK: - JWTClaims

/// Parsed claims extracted from a validated JWT token.
public struct JWTClaims: Sendable {
    /// Subject of the token (typically the username).
    public let subject: String
    /// Role string embedded in the token.
    public let role: String
    /// When the token was issued.
    public let issuedAt: Date
    /// When the token expires.
    public let expiresAt: Date

    /// Creates a new claims value.
    public init(subject: String, role: String, issuedAt: Date, expiresAt: Date) {
        self.subject = subject
        self.role = role
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }
}

// MARK: - JWTError

/// Errors that may be thrown during JWT operations.
public enum JWTError: Error, Sendable {
    /// The token does not consist of three dot-separated parts.
    case invalidFormat
    /// The HMAC-SHA256 signature does not match the expected value.
    case invalidSignature
    /// The token has passed its `exp` claim.
    case expired
    /// One or more required claims are missing or of the wrong type.
    case invalidClaims
}

// MARK: - JWTHelper

/// Minimal HS256 JSON Web Token helper.
///
/// Generates and validates compact JWTs signed with HMAC-SHA256.  Only the
/// `sub`, `role`, `iat`, and `exp` claims are written/read; additional claims
/// are ignored during validation.
///
/// ## Token format
/// ```
/// base64url(header) . base64url(payload) . base64url(signature)
/// ```
public enum JWTHelper: Sendable {

    // MARK: - Token Generation

    /// Generates an HS256 JWT token.
    ///
    /// - Parameters:
    ///   - subject: The `sub` claim value (typically a username).
    ///   - role: A role string embedded as a custom `role` claim.
    ///   - secret: Shared secret used for HMAC-SHA256 signing.
    ///   - expirySeconds: Number of seconds from now until the token expires.
    /// - Returns: A compact JWT string.
    /// - Throws: Never throws in the current implementation; declared `throws`
    ///   for forward compatibility.
    public static func generateToken(
        subject: String,
        role: String,
        secret: String,
        expirySeconds: Int
    ) throws -> String {
        let headerJSON = #"{"alg":"HS256","typ":"JWT"}"#
        let now = Int(Date().timeIntervalSince1970)
        let exp = now + expirySeconds
        let payloadJSON = """
        {"sub":"\(subject)","role":"\(role)","iat":\(now),"exp":\(exp)}
        """
        let headerEncoded = base64URLEncode(Data(headerJSON.utf8))
        let payloadEncoded = base64URLEncode(Data(payloadJSON.utf8))
        let signingInput = "\(headerEncoded).\(payloadEncoded)"
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        let signatureEncoded = base64URLEncode(Data(mac))
        return "\(signingInput).\(signatureEncoded)"
    }

    // MARK: - Token Validation

    /// Validates an HS256 JWT token and returns the embedded claims.
    ///
    /// - Parameters:
    ///   - token: The compact JWT string to validate.
    ///   - secret: Shared secret used to verify the HMAC-SHA256 signature.
    /// - Returns: The parsed ``JWTClaims``.
    /// - Throws: ``JWTError`` if the token is malformed, the signature is
    ///   invalid, or the token has expired.
    public static func validateToken(_ token: String, secret: String) throws -> JWTClaims {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw JWTError.invalidFormat }

        let headerB64 = String(parts[0])
        let payloadB64 = String(parts[1])
        let signatureB64 = String(parts[2])

        // Verify signature
        let signingInput = "\(headerB64).\(payloadB64)"
        let key = SymmetricKey(data: Data(secret.utf8))
        guard let expectedSigData = base64URLDecode(signatureB64) else {
            throw JWTError.invalidSignature
        }
        let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
        guard Data(mac) == expectedSigData else {
            throw JWTError.invalidSignature
        }

        // Decode and parse payload claims
        guard let payloadData = base64URLDecode(payloadB64),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else {
            throw JWTError.invalidClaims
        }
        guard
            let subject = payloadJSON["sub"] as? String,
            let role = payloadJSON["role"] as? String,
            let iat = payloadJSON["iat"] as? Int,
            let exp = payloadJSON["exp"] as? Int
        else {
            throw JWTError.invalidClaims
        }

        let expiresAt = Date(timeIntervalSince1970: TimeInterval(exp))
        guard expiresAt > Date() else { throw JWTError.expired }

        return JWTClaims(
            subject: subject,
            role: role,
            issuedAt: Date(timeIntervalSince1970: TimeInterval(iat)),
            expiresAt: expiresAt
        )
    }

    // MARK: - Base64URL Helpers

    /// Base64URL-encodes the given data (no padding, URL-safe alphabet).
    ///
    /// - Parameter data: Raw bytes to encode.
    /// - Returns: Base64URL-encoded string without `=` padding.
    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes a base64URL-encoded string back to raw bytes.
    ///
    /// - Parameter string: Base64URL-encoded string (with or without padding).
    /// - Returns: Decoded `Data`, or `nil` if the string is not valid base64.
    static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}
