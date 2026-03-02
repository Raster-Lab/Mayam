// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin Authentication Handler

import Foundation
import Crypto
import MayamCore

// MARK: - AdminAuthHandler

/// Handles admin user authentication and session token management.
///
/// This actor maintains an in-memory user store and issues HS256 JWT tokens
/// upon successful authentication.  On first boot a default `admin` user is
/// created automatically; operators should change the password via
/// `changePassword(token:oldPassword:newPassword:)` after first login.
public actor AdminAuthHandler {

    // MARK: - Stored Properties

    /// In-memory user store keyed by username.
    private var users: [String: AdminUser]

    /// Shared secret used to sign and verify JWT tokens.
    private let jwtSecret: String

    /// Session token lifetime in seconds.
    private let sessionExpirySeconds: Int

    // MARK: - Initialiser

    /// Creates a new auth handler with a default administrator account.
    ///
    /// The default admin user is created with username `"admin"` and password
    /// `"admin"`.  The password should be changed immediately via
    /// ``changePassword(token:oldPassword:newPassword:)`` after the first login.
    ///
    /// - Parameters:
    ///   - jwtSecret: Shared secret used to sign JWT tokens.
    ///   - sessionExpirySeconds: Number of seconds before a token expires.
    public init(jwtSecret: String, sessionExpirySeconds: Int) {
        self.jwtSecret = jwtSecret
        self.sessionExpirySeconds = sessionExpirySeconds
        let defaultHash = Self.staticSha256Hex("admin")
        let defaultAdmin = AdminUser(
            username: "admin",
            passwordHash: defaultHash,
            role: .administrator
        )
        self.users = ["admin": defaultAdmin]
    }

    // MARK: - Public Methods

    /// Authenticates a user and returns a session token on success.
    ///
    /// - Parameters:
    ///   - username: Login username.
    ///   - password: Plaintext password.
    /// - Returns: An ``AdminLoginResponse`` containing a JWT bearer token.
    /// - Throws: ``AdminError/unauthorised`` if credentials are invalid.
    public func login(username: String, password: String) throws -> AdminLoginResponse {
        guard let user = users[username] else {
            throw AdminError.unauthorised
        }
        let hash = sha256Hex(password)
        guard user.passwordHash == hash else {
            throw AdminError.unauthorised
        }
        let token = try JWTHelper.generateToken(
            subject: username,
            role: user.role.rawValue,
            secret: jwtSecret,
            expirySeconds: sessionExpirySeconds
        )
        let expiresAt = Date().addingTimeInterval(TimeInterval(sessionExpirySeconds))
        return AdminLoginResponse(
            token: token,
            expiresAt: expiresAt,
            username: username,
            role: user.role
        )
    }

    /// Validates a JWT token and returns the embedded claims.
    ///
    /// - Parameter token: The JWT bearer token to validate.
    /// - Returns: Parsed ``JWTClaims``.
    /// - Throws: ``JWTError`` if the token is invalid or expired.
    public func validateToken(_ token: String) throws -> JWTClaims {
        try JWTHelper.validateToken(token, secret: jwtSecret)
    }

    /// Changes a user's password after verifying the current credentials.
    ///
    /// - Parameters:
    ///   - token: A valid JWT token identifying the requesting user.
    ///   - oldPassword: The current plaintext password.
    ///   - newPassword: The desired new plaintext password.
    /// - Throws: ``AdminError/unauthorised`` if the token or old password is
    ///   invalid; ``AdminError/notFound(resource:)`` if the user no longer exists.
    public func changePassword(token: String, oldPassword: String, newPassword: String) throws {
        let claims = try JWTHelper.validateToken(token, secret: jwtSecret)
        let username = claims.subject
        guard let user = users[username] else {
            throw AdminError.notFound(resource: "user \(username)")
        }
        guard user.passwordHash == sha256Hex(oldPassword) else {
            throw AdminError.unauthorised
        }
        users[username] = AdminUser(
            username: username,
            passwordHash: sha256Hex(newPassword),
            role: user.role
        )
    }

    // MARK: - Private Helpers

    /// Returns the SHA-256 hex digest of the given string.
    ///
    /// - Parameter string: Input string to hash (UTF-8 encoded).
    /// - Returns: Lowercase hexadecimal SHA-256 digest.
    private func sha256Hex(_ string: String) -> String {
        Self.staticSha256Hex(string)
    }

    /// Non-isolated version of ``sha256Hex(_:)`` used during initialisation.
    private static func staticSha256Hex(_ string: String) -> String {
        let hash = SHA256.hash(data: Data(string.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
