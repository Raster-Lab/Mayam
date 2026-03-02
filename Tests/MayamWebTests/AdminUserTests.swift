// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin User and LDAP Handler Tests

import XCTest
import Foundation
@testable import MayamWeb
import MayamCore

// MARK: - Helpers

private let testJWTSecret = "test-secret-for-user-ldap-tests-32chars"

/// Generates a JWT token for the given username and role for use in tests.
private func makeToken(username: String, role: AdminRole) throws -> String {
    try JWTHelper.generateToken(
        subject: username,
        role: role.rawValue,
        secret: testJWTSecret,
        expirySeconds: 3600
    )
}

/// Creates a test AdminRouter with default handlers.
private func makeRouter() -> AdminRouter {
    let userDirectory = UserDirectory()
    let userHandler = AdminUserHandler(userDirectory: userDirectory)
    let authHandler = AdminAuthHandler(
        userDirectory: userDirectory,
        jwtSecret: testJWTSecret,
        sessionExpirySeconds: 3600
    )
    return AdminRouter(
        auth: authHandler,
        dashboard: AdminDashboardHandler(),
        nodes: AdminNodeHandler(),
        storage: AdminStorageHandler(),
        logs: AdminLogHandler(),
        settings: AdminSettingsHandler(configuration: ServerConfiguration(), adminPort: 8081),
        setup: AdminSetupHandler(),
        users: userHandler,
        ldap: AdminLDAPHandler(),
        archivePath: "/tmp"
    )
}

/// Returns an authenticated request with a Bearer token for the given role.
private func authRequest(
    method: HTTPMethod,
    path: String,
    body: Data = Data(),
    username: String = "admin",
    role: AdminRole = .administrator
) throws -> AdminRequest {
    let token = try makeToken(username: username, role: role)
    return AdminRequest(
        method: method,
        path: path,
        body: body,
        headers: ["Authorization": "Bearer \(token)"]
    )
}

// MARK: - AdminUserHandlerTests

final class AdminUserHandlerTests: XCTestCase {

    // MARK: - List Users

    func test_listUsers_returnsDefaultAdmin() async {
        let handler = AdminUserHandler(userDirectory: UserDirectory())
        let users = await handler.listUsers()
        XCTAssertTrue(users.contains { $0.username == "admin" })
    }

    // MARK: - Create User

    func test_createUser_newUser_returnsRecord() async throws {
        let handler = AdminUserHandler(userDirectory: UserDirectory())
        let req = CreateUserRequest(username: "testUser", password: "pass", role: .technologist)
        let record = try await handler.createUser(req)
        XCTAssertEqual(record.username, "testUser")
        XCTAssertEqual(record.role, .technologist)
    }

    func test_createUser_duplicate_throwsConflict() async throws {
        let handler = AdminUserHandler(userDirectory: UserDirectory())
        let req = CreateUserRequest(username: "admin", password: "p", role: .auditor)
        do {
            _ = try await handler.createUser(req)
            XCTFail("Expected conflict error")
        } catch AdminError.conflict {
            // Expected
        }
    }

    // MARK: - Get User

    func test_getUser_existingUser_returnsRecord() async throws {
        let handler = AdminUserHandler(userDirectory: UserDirectory())
        let record = try await handler.getUser(username: "admin")
        XCTAssertEqual(record.username, "admin")
    }

    func test_getUser_unknownUser_throwsNotFound() async throws {
        let handler = AdminUserHandler(userDirectory: UserDirectory())
        do {
            _ = try await handler.getUser(username: "nobody")
            XCTFail("Expected notFound error")
        } catch AdminError.notFound {
            // Expected
        }
    }

    // MARK: - Update User

    func test_updateUser_changesRole() async throws {
        let dir = UserDirectory()
        _ = try await dir.createUser(
            CreateUserRequest(username: "frank", password: "pw", role: .auditor)
        )
        let handler = AdminUserHandler(userDirectory: dir)
        let updated = try await handler.updateUser(
            username: "frank",
            req: UpdateUserRequest(role: .physician)
        )
        XCTAssertEqual(updated.role, .physician)
    }

    func test_updateUser_unknownUser_throwsNotFound() async throws {
        let handler = AdminUserHandler(userDirectory: UserDirectory())
        do {
            _ = try await handler.updateUser(
                username: "ghost",
                req: UpdateUserRequest(role: .auditor)
            )
            XCTFail("Expected notFound error")
        } catch AdminError.notFound {
            // Expected
        }
    }

    // MARK: - Delete User

    func test_deleteUser_existingUser_removesIt() async throws {
        let dir = UserDirectory()
        _ = try await dir.createUser(
            CreateUserRequest(username: "greta", password: "pw", role: .auditor)
        )
        let handler = AdminUserHandler(userDirectory: dir)
        try await handler.deleteUser(username: "greta")
        let users = await handler.listUsers()
        XCTAssertFalse(users.contains { $0.username == "greta" })
    }

    func test_deleteUser_unknownUser_throwsNotFound() async throws {
        let handler = AdminUserHandler(userDirectory: UserDirectory())
        do {
            try await handler.deleteUser(username: "nobody")
            XCTFail("Expected notFound error")
        } catch AdminError.notFound {
            // Expected
        }
    }

    // MARK: - Change Password

    func test_changePassword_correctOldPassword_succeeds() async throws {
        let handler = AdminUserHandler(userDirectory: UserDirectory())
        try await handler.changePassword(
            username: "admin",
            req: ChangePasswordRequest(oldPassword: "admin", newPassword: "newPass")
        )
        // Success if no throw.
    }

    func test_changePassword_wrongOldPassword_throwsUnauthorised() async throws {
        let handler = AdminUserHandler(userDirectory: UserDirectory())
        do {
            try await handler.changePassword(
                username: "admin",
                req: ChangePasswordRequest(oldPassword: "wrong", newPassword: "new")
            )
            XCTFail("Expected unauthorised error")
        } catch AdminError.unauthorised {
            // Expected
        }
    }
}

// MARK: - AdminLDAPHandlerTests

final class AdminLDAPHandlerTests: XCTestCase {

    func test_getConfiguration_returnsDefault() async {
        let handler = AdminLDAPHandler()
        let config = await handler.getConfiguration()
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.port, 389)
    }

    func test_updateConfiguration_replacesValues() async {
        let handler = AdminLDAPHandler()
        let newConfig = LDAPConfigurationPayload(
            enabled: true,
            host: "ldap.example.com",
            port: 636,
            useTLS: true,
            serviceBindDN: "cn=service,dc=example,dc=com",
            serviceBindPassword: "secret",
            baseDN: "dc=example,dc=com",
            userSearchFilter: "(objectClass=person)",
            usernameAttribute: "uid",
            emailAttribute: "mail",
            displayNameAttribute: "cn",
            memberOfAttribute: "memberOf",
            adminGroupDN: "cn=admins,dc=example,dc=com",
            techGroupDN: "",
            physicianGroupDN: "",
            auditorGroupDN: ""
        )
        let updated = await handler.updateConfiguration(newConfig)
        XCTAssertTrue(updated.enabled)
        XCTAssertEqual(updated.host, "ldap.example.com")
        XCTAssertEqual(updated.port, 636)
    }

    func test_testConnection_notEnabled_returnsFailed() async {
        let handler = AdminLDAPHandler()
        let result = await handler.testConnection()
        XCTAssertFalse(result.success)
        XCTAssertFalse(result.message.isEmpty)
    }

    func test_testConnection_emptyHost_returnsFailed() async {
        let handler = AdminLDAPHandler(
            initial: LDAPConfigurationPayload(enabled: true, host: "")
        )
        let result = await handler.testConnection()
        XCTAssertFalse(result.success)
    }

    func test_testConnection_unreachableHost_returnsFailed() async {
        let handler = AdminLDAPHandler(
            initial: LDAPConfigurationPayload(
                enabled: true,
                host: "127.0.0.1",
                port: 19389  // unlikely to be open
            )
        )
        let result = await handler.testConnection()
        XCTAssertFalse(result.success)
    }

    func test_ldapConnectionTestResult_init() {
        let result = LDAPConnectionTestResult(
            success: true,
            message: "OK",
            latencyMs: 5.2
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "OK")
        XCTAssertEqual(result.latencyMs, 5.2)
    }

    func test_ldapConfigurationPayload_codableRoundTrip() throws {
        let payload = LDAPConfigurationPayload(
            enabled: true,
            host: "ldap.test.com",
            port: 389,
            useTLS: false,
            serviceBindDN: "cn=svc,dc=test,dc=com",
            serviceBindPassword: "pass",
            baseDN: "dc=test,dc=com",
            userSearchFilter: "(objectClass=person)",
            usernameAttribute: "uid",
            emailAttribute: "mail",
            displayNameAttribute: "cn",
            memberOfAttribute: "memberOf",
            adminGroupDN: "cn=admins,dc=test,dc=com",
            techGroupDN: "",
            physicianGroupDN: "",
            auditorGroupDN: ""
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(LDAPConfigurationPayload.self, from: data)
        XCTAssertEqual(decoded.host, payload.host)
        XCTAssertEqual(decoded.enabled, payload.enabled)
        XCTAssertEqual(decoded.adminGroupDN, payload.adminGroupDN)
    }
}

// MARK: - AdminRouterUserTests

final class AdminRouterUserTests: XCTestCase {

    // MARK: - GET /admin/api/users

    func test_listUsers_withAdminToken_returns200() async throws {
        let router = makeRouter()
        let req = try authRequest(method: .get, path: "/admin/api/users")
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_listUsers_withoutToken_returns401() async {
        let router = makeRouter()
        let req = AdminRequest(method: .get, path: "/admin/api/users")
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 401)
    }

    // MARK: - POST /admin/api/users

    func test_createUser_withAdminToken_returns201() async throws {
        let router = makeRouter()
        let body = try JSONEncoder().encode(
            CreateUserRequest(username: "newuser", password: "pw123", role: .auditor)
        )
        let req = try authRequest(method: .post, path: "/admin/api/users", body: body)
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 201)
    }

    func test_createUser_invalidBody_returns400() async throws {
        let router = makeRouter()
        let req = try authRequest(
            method: .post,
            path: "/admin/api/users",
            body: Data("not json".utf8)
        )
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 400)
    }

    // MARK: - GET /admin/api/users/{username}

    func test_getUser_existingUser_returns200() async throws {
        let router = makeRouter()
        let req = try authRequest(method: .get, path: "/admin/api/users/admin")
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_getUser_unknownUser_returns404() async throws {
        let router = makeRouter()
        let req = try authRequest(method: .get, path: "/admin/api/users/nobody")
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 404)
    }

    // MARK: - PUT /admin/api/users/{username}

    func test_updateUser_existingUser_returns200() async throws {
        let router = makeRouter()
        let body = try JSONEncoder().encode(UpdateUserRequest(role: .auditor))
        let req = try authRequest(method: .put, path: "/admin/api/users/admin", body: body)
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 200)
    }

    // MARK: - DELETE /admin/api/users/{username}

    func test_deleteUser_nonExistentUser_returns404() async throws {
        let router = makeRouter()
        let req = try authRequest(method: .delete, path: "/admin/api/users/nobody")
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 404)
    }

    // MARK: - POST /admin/api/users/{username}/password

    func test_changePassword_selfChange_returns204() async throws {
        let router = makeRouter()
        let body = try JSONEncoder().encode(
            ChangePasswordRequest(oldPassword: "admin", newPassword: "newpass")
        )
        // Admin changing their own password.
        let req = try authRequest(
            method: .post,
            path: "/admin/api/users/admin/password",
            body: body,
            username: "admin",
            role: .administrator
        )
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 204)
    }

    // MARK: - RBAC Tests

    func test_listUsers_technologistRole_returns403() async throws {
        let router = makeRouter()
        let req = try authRequest(
            method: .get,
            path: "/admin/api/users",
            username: "tech1",
            role: .technologist
        )
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 403)
    }

    func test_listUsers_physicianRole_returns403() async throws {
        let router = makeRouter()
        let req = try authRequest(
            method: .get,
            path: "/admin/api/users",
            username: "dr",
            role: .physician
        )
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 403)
    }

    func test_listUsers_auditorRole_returns403() async throws {
        let router = makeRouter()
        let req = try authRequest(
            method: .get,
            path: "/admin/api/users",
            username: "auditor1",
            role: .auditor
        )
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 403)
    }
}

// MARK: - AdminRouterLDAPTests

final class AdminRouterLDAPTests: XCTestCase {

    // MARK: - GET /admin/api/ldap

    func test_getLDAPConfig_withAdminToken_returns200() async throws {
        let router = makeRouter()
        let req = try authRequest(method: .get, path: "/admin/api/ldap")
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_getLDAPConfig_technologistRole_returns403() async throws {
        let router = makeRouter()
        let req = try authRequest(
            method: .get,
            path: "/admin/api/ldap",
            username: "tech",
            role: .technologist
        )
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 403)
    }

    // MARK: - PUT /admin/api/ldap

    func test_updateLDAPConfig_withAdminToken_returns200() async throws {
        let router = makeRouter()
        let payload = LDAPConfigurationPayload()
        let body = try JSONEncoder().encode(payload)
        let req = try authRequest(method: .put, path: "/admin/api/ldap", body: body)
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 200)
    }

    // MARK: - POST /admin/api/ldap/test

    func test_testLDAPConnection_withAdminToken_returns200() async throws {
        let router = makeRouter()
        let req = try authRequest(method: .post, path: "/admin/api/ldap/test")
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 200)
        // The response body should be a LDAPConnectionTestResult JSON.
        let result = try JSONDecoder().decode(LDAPConnectionTestResult.self, from: response.body)
        XCTAssertFalse(result.success)  // LDAP is not configured in tests.
    }

    func test_testLDAPConnection_physicianRole_returns403() async throws {
        let router = makeRouter()
        let req = try authRequest(
            method: .post,
            path: "/admin/api/ldap/test",
            username: "dr",
            role: .physician
        )
        let response = await router.route(req)
        XCTAssertEqual(response.statusCode, 403)
    }
}

// MARK: - AdminErrorForbiddenTests

final class AdminErrorForbiddenTests: XCTestCase {

    func test_forbidden_httpStatusCode_is403() {
        let error = AdminError.forbidden(reason: "Insufficient permissions")
        XCTAssertEqual(error.httpStatusCode, 403)
    }

    func test_forbidden_description_containsReason() {
        let error = AdminError.forbidden(reason: "No access")
        XCTAssertTrue(error.description.contains("No access"))
    }

    func test_changePasswordRequest_codableRoundTrip() throws {
        let req = ChangePasswordRequest(oldPassword: "old", newPassword: "new")
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(ChangePasswordRequest.self, from: data)
        XCTAssertEqual(decoded.oldPassword, "old")
        XCTAssertEqual(decoded.newPassword, "new")
    }
}
