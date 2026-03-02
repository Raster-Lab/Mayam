// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin User Management Handler

import Foundation
import MayamCore

// MARK: - AdminUserHandler

/// Handles admin API requests for local user account management.
///
/// Delegates all operations to the underlying ``UserDirectory`` actor.
public actor AdminUserHandler {

    // MARK: - Stored Properties

    /// The user directory backing this handler.
    private let userDirectory: UserDirectory

    // MARK: - Initialiser

    /// Creates a new user handler backed by the given directory.
    ///
    /// - Parameter userDirectory: The ``UserDirectory`` to use.
    public init(userDirectory: UserDirectory) {
        self.userDirectory = userDirectory
    }

    // MARK: - Public Methods

    /// Returns all local user accounts.
    ///
    /// - Returns: An array of ``UserRecord`` values.
    public func listUsers() async -> [UserRecord] {
        await userDirectory.listUsers()
    }

    /// Creates a new local user account.
    ///
    /// - Parameter req: The create-user request.
    /// - Returns: The newly created ``UserRecord``.
    /// - Throws: ``AdminError/conflict(reason:)`` if the username is already taken.
    @discardableResult
    public func createUser(_ req: CreateUserRequest) async throws -> UserRecord {
        try await userDirectory.createUser(req)
    }

    /// Retrieves a single user record by username.
    ///
    /// - Parameter username: The login username.
    /// - Returns: The matching ``UserRecord``.
    /// - Throws: ``AdminError/notFound(resource:)`` if the user does not exist.
    public func getUser(username: String) async throws -> UserRecord {
        let users = await userDirectory.listUsers()
        guard let user = users.first(where: { $0.username == username }) else {
            throw AdminError.notFound(resource: "user \(username)")
        }
        return user
    }

    /// Updates an existing user's role, e-mail, or display name.
    ///
    /// - Parameters:
    ///   - username: The login username.
    ///   - req: The update request.
    /// - Returns: The updated ``UserRecord``.
    /// - Throws: ``AdminError/notFound(resource:)`` if the user does not exist.
    @discardableResult
    public func updateUser(username: String, req: UpdateUserRequest) async throws -> UserRecord {
        try await userDirectory.updateUser(username: username, req: req)
    }

    /// Deletes a local user account.
    ///
    /// - Parameter username: The login username to delete.
    /// - Throws: ``AdminError/notFound(resource:)`` if the user does not exist.
    public func deleteUser(username: String) async throws {
        try await userDirectory.deleteUser(username: username)
    }

    /// Changes a user's password.
    ///
    /// - Parameters:
    ///   - username: The login username.
    ///   - req: A ``ChangePasswordRequest`` containing the old and new passwords.
    /// - Throws: ``AdminError/notFound(resource:)`` if the user does not exist;
    ///   ``AdminError/unauthorised`` if the old password is incorrect.
    public func changePassword(username: String, req: ChangePasswordRequest) async throws {
        try await userDirectory.changePassword(
            username: username,
            oldPassword: req.oldPassword,
            newPassword: req.newPassword
        )
    }
}
