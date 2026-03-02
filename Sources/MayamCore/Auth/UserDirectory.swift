// SPDX-License-Identifier: (see LICENSE)
// Mayam — User Directory (local accounts + optional LDAP)

import Foundation
import Crypto

// MARK: - AuthSource

/// Indicates whether an authenticated session was established via a local
/// account or an LDAP/Active Directory directory.
public enum AuthSource: String, Codable, Sendable {
    /// Authenticated against the local user database.
    case local
    /// Authenticated against an LDAP / Active Directory server.
    case ldap
}

// MARK: - AuthenticatedUser

/// A successfully authenticated user, returned after a login operation.
public struct AuthenticatedUser: Sendable {
    /// Login username.
    public let username: String
    /// Role governing permissions.
    public let role: AdminRole
    /// E-mail address, if available.
    public let email: String?
    /// Display name, if available.
    public let displayName: String?
    /// Whether the account was authenticated via LDAP or a local store.
    public let source: AuthSource

    /// Creates an authenticated user record.
    public init(
        username: String,
        role: AdminRole,
        email: String? = nil,
        displayName: String? = nil,
        source: AuthSource
    ) {
        self.username = username
        self.role = role
        self.email = email
        self.displayName = displayName
        self.source = source
    }
}

// MARK: - UserRecord

/// A serialisable user record returned by the user management API.
public struct UserRecord: Codable, Sendable {
    /// Unique identifier for this record.
    public let id: UUID
    /// Login username.
    public let username: String
    /// Role governing permissions.
    public let role: AdminRole
    /// E-mail address, if set.
    public let email: String?
    /// Display name, if set.
    public let displayName: String?
    /// `true` for accounts stored locally; `false` for LDAP-only accounts.
    public let isLocal: Bool
    /// When the local account was created.
    public let createdAt: Date

    /// Creates a user record.
    public init(
        id: UUID,
        username: String,
        role: AdminRole,
        email: String? = nil,
        displayName: String? = nil,
        isLocal: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.username = username
        self.role = role
        self.email = email
        self.displayName = displayName
        self.isLocal = isLocal
        self.createdAt = createdAt
    }
}

// MARK: - CreateUserRequest

/// Request body for creating a new local user account.
public struct CreateUserRequest: Codable, Sendable {
    /// Desired username (must be unique).
    public let username: String
    /// Plaintext password; stored as a SHA-256 hash.
    public let password: String
    /// Role to assign.
    public let role: AdminRole
    /// Optional e-mail address.
    public let email: String?
    /// Optional display name.
    public let displayName: String?

    /// Creates a create-user request.
    public init(
        username: String,
        password: String,
        role: AdminRole,
        email: String? = nil,
        displayName: String? = nil
    ) {
        self.username = username
        self.password = password
        self.role = role
        self.email = email
        self.displayName = displayName
    }
}

// MARK: - UpdateUserRequest

/// Request body for updating an existing local user account.
public struct UpdateUserRequest: Codable, Sendable {
    /// New role to assign, or `nil` to leave unchanged.
    public let role: AdminRole?
    /// New e-mail address, or `nil` to leave unchanged.
    public let email: String?
    /// New display name, or `nil` to leave unchanged.
    public let displayName: String?

    /// Creates an update-user request.
    public init(role: AdminRole? = nil, email: String? = nil, displayName: String? = nil) {
        self.role = role
        self.email = email
        self.displayName = displayName
    }
}

// MARK: - LocalUserRecord

/// An internal record representing a locally stored user account.
public struct LocalUserRecord: Sendable {
    /// Login username.
    public let username: String
    /// SHA-256 hex digest of the user's password.
    public let passwordHash: String
    /// Role governing permissions.
    public let role: AdminRole
    /// Optional e-mail address.
    public let email: String?
    /// Optional display name.
    public let displayName: String?
    /// When the account was created.
    public let createdAt: Date
    /// Always `true` for local records.
    public let isLocal: Bool

    /// Creates a local user record.
    public init(
        username: String,
        passwordHash: String,
        role: AdminRole,
        email: String? = nil,
        displayName: String? = nil,
        createdAt: Date = Date(),
        isLocal: Bool = true
    ) {
        self.username = username
        self.passwordHash = passwordHash
        self.role = role
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.isLocal = isLocal
    }
}

// MARK: - UserDirectory

/// Manages user authentication and account administration.
///
/// On initialisation a default `admin` account (password `"admin"`) is created
/// automatically; operators should change the password immediately after first
/// login.
///
/// When an ``LDAPClient`` is provided, LDAP authentication is attempted first
/// for any login attempt.  Local account authentication is used as a fallback
/// if LDAP is unavailable or if the user is not found in the directory.
public actor UserDirectory {

    // MARK: - Stored Properties

    /// In-memory local user store keyed by username.
    private var localUsers: [String: LocalUserRecord]

    /// Optional LDAP client for directory authentication.
    private let ldapClient: LDAPClient?

    /// Optional LDAP configuration (schema + group DN mappings).
    private let ldapConfiguration: ServerConfiguration.LDAP?

    // MARK: - Initialiser

    /// Creates a user directory with an optional LDAP integration.
    ///
    /// A default `admin` account is always created.
    ///
    /// - Parameters:
    ///   - ldapClient: An optional ``LDAPClient`` for directory authentication.
    ///   - ldapConfiguration: LDAP configuration providing schema and group DN
    ///     mappings used to derive an ``AdminRole`` from LDAP group membership.
    public init(
        ldapClient: LDAPClient? = nil,
        ldapConfiguration: ServerConfiguration.LDAP? = nil
    ) {
        self.ldapClient = ldapClient
        self.ldapConfiguration = ldapConfiguration
        let defaultHash = Self.sha256Hex("admin")
        let defaultAdmin = LocalUserRecord(
            username: "admin",
            passwordHash: defaultHash,
            role: .administrator
        )
        self.localUsers = ["admin": defaultAdmin]
    }

    // MARK: - Authentication

    /// Authenticates a user using LDAP (if configured) or local credentials.
    ///
    /// LDAP is attempted first when ``ServerConfiguration/LDAP/enabled`` is
    /// `true` and an ``LDAPClient`` is present.  On LDAP failure the method
    /// falls back to local account lookup.
    ///
    /// - Parameters:
    ///   - username: Login username.
    ///   - password: Plaintext password.
    /// - Returns: An ``AuthenticatedUser`` on success.
    /// - Throws: ``AdminError/unauthorised`` if credentials are invalid.
    public func authenticate(username: String, password: String) async throws -> AuthenticatedUser {
        // Attempt LDAP first when configured.
        if let ldapClient, let ldapConfig = ldapConfiguration, ldapConfig.enabled {
            do {
                let entry = try await ldapClient.authenticate(username: username, password: password)
                let role = resolveRole(from: entry.groups, using: ldapConfig.schema)
                return AuthenticatedUser(
                    username: entry.username,
                    role: role,
                    email: entry.email,
                    displayName: entry.displayName,
                    source: .ldap
                )
            } catch LDAPError.invalidCredentials {
                throw AdminError.unauthorised
            } catch LDAPError.userNotFound {
                // Fall through to local authentication.
                ()
            } catch {
                // LDAP unavailable — fall through to local authentication.
                ()
            }
        }

        // Local authentication.
        guard let user = localUsers[username] else {
            throw AdminError.unauthorised
        }
        guard user.passwordHash == Self.sha256Hex(password) else {
            throw AdminError.unauthorised
        }
        return AuthenticatedUser(
            username: user.username,
            role: user.role,
            email: user.email,
            displayName: user.displayName,
            source: .local
        )
    }

    // MARK: - User Management

    /// Returns all local user records as ``UserRecord`` values.
    ///
    /// - Returns: An array of user records sorted by username.
    public func listUsers() -> [UserRecord] {
        localUsers.values
            .sorted { $0.username < $1.username }
            .map { record in
                UserRecord(
                    id: UUID(),
                    username: record.username,
                    role: record.role,
                    email: record.email,
                    displayName: record.displayName,
                    isLocal: record.isLocal,
                    createdAt: record.createdAt
                )
            }
    }

    /// Creates a new local user account.
    ///
    /// - Parameter req: The create-user request.
    /// - Returns: The newly created ``UserRecord``.
    /// - Throws: ``AdminError/conflict(reason:)`` if the username is already taken.
    @discardableResult
    public func createUser(_ req: CreateUserRequest) throws -> UserRecord {
        guard localUsers[req.username] == nil else {
            throw AdminError.conflict(reason: "User '\(req.username)' already exists")
        }
        let record = LocalUserRecord(
            username: req.username,
            passwordHash: Self.sha256Hex(req.password),
            role: req.role,
            email: req.email,
            displayName: req.displayName
        )
        localUsers[req.username] = record
        return UserRecord(
            id: UUID(),
            username: record.username,
            role: record.role,
            email: record.email,
            displayName: record.displayName,
            isLocal: record.isLocal,
            createdAt: record.createdAt
        )
    }

    /// Updates the role, e-mail, or display name of an existing local user.
    ///
    /// - Parameters:
    ///   - username: Username of the account to update.
    ///   - req: The update request containing new values (nil fields are unchanged).
    /// - Returns: The updated ``UserRecord``.
    /// - Throws: ``AdminError/notFound(resource:)`` if the user does not exist.
    @discardableResult
    public func updateUser(username: String, req: UpdateUserRequest) throws -> UserRecord {
        guard let existing = localUsers[username] else {
            throw AdminError.notFound(resource: "user \(username)")
        }
        let updated = LocalUserRecord(
            username: existing.username,
            passwordHash: existing.passwordHash,
            role: req.role ?? existing.role,
            email: req.email ?? existing.email,
            displayName: req.displayName ?? existing.displayName,
            createdAt: existing.createdAt
        )
        localUsers[username] = updated
        return UserRecord(
            id: UUID(),
            username: updated.username,
            role: updated.role,
            email: updated.email,
            displayName: updated.displayName,
            isLocal: updated.isLocal,
            createdAt: updated.createdAt
        )
    }

    /// Deletes a local user account.
    ///
    /// - Parameter username: Username of the account to delete.
    /// - Throws: ``AdminError/notFound(resource:)`` if the user does not exist.
    public func deleteUser(username: String) throws {
        guard localUsers[username] != nil else {
            throw AdminError.notFound(resource: "user \(username)")
        }
        localUsers.removeValue(forKey: username)
    }

    /// Changes a user's password after verifying the current password.
    ///
    /// - Parameters:
    ///   - username: Username of the account.
    ///   - oldPassword: Current plaintext password.
    ///   - newPassword: Desired new plaintext password.
    /// - Throws: ``AdminError/notFound(resource:)`` if the user does not exist;
    ///   ``AdminError/unauthorised`` if `oldPassword` is incorrect.
    public func changePassword(username: String, oldPassword: String, newPassword: String) throws {
        guard let existing = localUsers[username] else {
            throw AdminError.notFound(resource: "user \(username)")
        }
        guard existing.passwordHash == Self.sha256Hex(oldPassword) else {
            throw AdminError.unauthorised
        }
        let updated = LocalUserRecord(
            username: existing.username,
            passwordHash: Self.sha256Hex(newPassword),
            role: existing.role,
            email: existing.email,
            displayName: existing.displayName,
            createdAt: existing.createdAt
        )
        localUsers[username] = updated
    }

    // MARK: - Private Helpers

    /// Returns the SHA-256 hex digest of the given string (UTF-8 encoded).
    private static func sha256Hex(_ string: String) -> String {
        let hash = SHA256.hash(data: Data(string.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Derives an ``AdminRole`` from a list of LDAP group DNs using the
    /// configured group mappings.
    ///
    /// The most privileged matching role is returned (administrator > technologist
    /// > physician > auditor).  If no group matches, `.auditor` is returned.
    ///
    /// - Parameters:
    ///   - groups: Group DNs from the `memberOf` attribute.
    ///   - schema: LDAP schema containing the group DN mappings.
    /// - Returns: The most privileged matching ``AdminRole``.
    private func resolveRole(
        from groups: [String],
        using schema: ServerConfiguration.LDAP.Schema
    ) -> AdminRole {
        if !schema.adminGroupDN.isEmpty && groups.contains(schema.adminGroupDN) {
            return .administrator
        }
        if !schema.techGroupDN.isEmpty && groups.contains(schema.techGroupDN) {
            return .technologist
        }
        if !schema.physicianGroupDN.isEmpty && groups.contains(schema.physicianGroupDN) {
            return .physician
        }
        return .auditor
    }
}
