// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin Authentication Handler

import Foundation
import Crypto
import MayamCore

// MARK: - AdminAuthHandler

/// Handles admin user authentication and session token management.
///
/// This actor issues HS256 JWT tokens upon successful authentication.
/// Authentication is delegated to the backing ``UserDirectory``, which supports
/// both local accounts and optional LDAP integration.
///
/// On first boot a default `admin` user (password `"admin"`) is created
/// automatically in the ``UserDirectory``; operators should change the password
/// via `changePassword` after first login.
public actor AdminAuthHandler {

    // MARK: - Stored Properties

    /// The user directory used for credential verification.
    private let userDirectory: UserDirectory

    /// Shared secret used to sign and verify JWT tokens.
    private let jwtSecret: String

    /// Session token lifetime in seconds.
    private let sessionExpirySeconds: Int

    // MARK: - Initialisers

    /// Creates an auth handler backed by the given user directory.
    ///
    /// - Parameters:
    ///   - userDirectory: The ``UserDirectory`` to use for authentication.
    ///   - jwtSecret: Shared secret used to sign JWT tokens.
    ///   - sessionExpirySeconds: Number of seconds before a token expires.
    public init(userDirectory: UserDirectory, jwtSecret: String, sessionExpirySeconds: Int) {
        self.userDirectory = userDirectory
        self.jwtSecret = jwtSecret
        self.sessionExpirySeconds = sessionExpirySeconds
    }

    /// Creates an auth handler with a fresh ``UserDirectory`` (no LDAP).
    ///
    /// A default `admin` account (password `"admin"`) is created automatically.
    ///
    /// - Parameters:
    ///   - jwtSecret: Shared secret used to sign JWT tokens.
    ///   - sessionExpirySeconds: Number of seconds before a token expires.
    public init(jwtSecret: String, sessionExpirySeconds: Int) {
        self.userDirectory = UserDirectory()
        self.jwtSecret = jwtSecret
        self.sessionExpirySeconds = sessionExpirySeconds
    }

    // MARK: - Public Methods

    /// Authenticates a user and returns a session token on success.
    ///
    /// - Parameters:
    ///   - username: Login username.
    ///   - password: Plaintext password.
    /// - Returns: An ``AdminLoginResponse`` containing a JWT bearer token.
    /// - Throws: ``AdminError/unauthorised`` if credentials are invalid.
    public func login(username: String, password: String) async throws -> AdminLoginResponse {
        let authenticated = try await userDirectory.authenticate(username: username, password: password)
        let token = try JWTHelper.generateToken(
            subject: authenticated.username,
            role: authenticated.role.rawValue,
            secret: jwtSecret,
            expirySeconds: sessionExpirySeconds
        )
        let expiresAt = Date().addingTimeInterval(TimeInterval(sessionExpirySeconds))
        return AdminLoginResponse(
            token: token,
            expiresAt: expiresAt,
            username: authenticated.username,
            role: authenticated.role
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
    public func changePassword(token: String, oldPassword: String, newPassword: String) async throws {
        let claims = try JWTHelper.validateToken(token, secret: jwtSecret)
        try await userDirectory.changePassword(
            username: claims.subject,
            oldPassword: oldPassword,
            newPassword: newPassword
        )
    }
}
