// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin API Tests

import XCTest
import Foundation
@testable import MayamWeb
import MayamCore

// MARK: - JWTHelperTests

final class JWTHelperTests: XCTestCase {

    private let secret = "test-secret-32-characters-minimum"

    func test_generateToken_producesThreeParts() throws {
        let token = try JWTHelper.generateToken(
            subject: "alice",
            role: "administrator",
            secret: secret,
            expirySeconds: 3600
        )
        let parts = token.split(separator: ".")
        XCTAssertEqual(parts.count, 3)
    }

    func test_validateToken_validToken_returnsClaims() throws {
        let token = try JWTHelper.generateToken(
            subject: "alice",
            role: "administrator",
            secret: secret,
            expirySeconds: 3600
        )
        let claims = try JWTHelper.validateToken(token, secret: secret)
        XCTAssertEqual(claims.subject, "alice")
        XCTAssertEqual(claims.role, "administrator")
        XCTAssertGreaterThan(claims.expiresAt, Date())
    }

    func test_validateToken_wrongSecret_throwsInvalidSignature() throws {
        let token = try JWTHelper.generateToken(
            subject: "alice",
            role: "administrator",
            secret: secret,
            expirySeconds: 3600
        )
        XCTAssertThrowsError(try JWTHelper.validateToken(token, secret: "wrong-secret")) { error in
            guard let jwtError = error as? JWTError else {
                XCTFail("Expected JWTError, got \(error)")
                return
            }
            XCTAssertEqual(jwtError, .invalidSignature)
        }
    }

    func test_validateToken_expiredToken_throwsExpired() throws {
        let token = try JWTHelper.generateToken(
            subject: "alice",
            role: "administrator",
            secret: secret,
            expirySeconds: -1  // Already expired
        )
        XCTAssertThrowsError(try JWTHelper.validateToken(token, secret: secret)) { error in
            guard let jwtError = error as? JWTError else {
                XCTFail("Expected JWTError, got \(error)")
                return
            }
            XCTAssertEqual(jwtError, .expired)
        }
    }

    func test_validateToken_invalidFormat_throwsInvalidFormat() {
        XCTAssertThrowsError(try JWTHelper.validateToken("not.a.valid.jwt.token", secret: secret)) { error in
            guard let jwtError = error as? JWTError else {
                XCTFail("Expected JWTError, got \(error)")
                return
            }
            XCTAssertEqual(jwtError, .invalidFormat)
        }
    }

    func test_validateToken_tamperedPayload_throwsInvalidSignature() throws {
        let token = try JWTHelper.generateToken(
            subject: "alice",
            role: "administrator",
            secret: secret,
            expirySeconds: 3600
        )
        // Tamper with the middle part (payload)
        var parts = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        parts[1] = JWTHelper.base64URLEncode(Data(#"{"sub":"admin","role":"administrator","iat":0,"exp":9999999999}"#.utf8))
        let tampered = parts.joined(separator: ".")
        XCTAssertThrowsError(try JWTHelper.validateToken(tampered, secret: secret)) { error in
            XCTAssertTrue(error is JWTError)
        }
    }

    func test_generateToken_specialCharactersInSubject_doesNotInjectJSON() throws {
        let subject = #"user"with"quotes"#
        let token = try JWTHelper.generateToken(
            subject: subject,
            role: "administrator",
            secret: secret,
            expirySeconds: 3600
        )
        let claims = try JWTHelper.validateToken(token, secret: secret)
        XCTAssertEqual(claims.subject, subject)
    }

    func test_base64URLEncode_noPaddingCharacters() {
        let data = Data([0x01, 0x02, 0x03])
        let encoded = JWTHelper.base64URLEncode(data)
        XCTAssertFalse(encoded.contains("="))
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
    }

    func test_base64URLDecode_roundTrip() {
        let original = Data("hello world".utf8)
        let encoded = JWTHelper.base64URLEncode(original)
        let decoded = JWTHelper.base64URLDecode(encoded)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - JWTError Equatable

extension JWTError: Equatable {
    public static func == (lhs: JWTError, rhs: JWTError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidFormat, .invalidFormat): return true
        case (.invalidSignature, .invalidSignature): return true
        case (.expired, .expired): return true
        case (.invalidClaims, .invalidClaims): return true
        default: return false
        }
    }
}

// MARK: - AdminAuthHandlerTests

final class AdminAuthHandlerTests: XCTestCase {

    private let jwtSecret = "test-admin-secret-for-auth-tests"

    func test_login_validCredentials_returnsToken() async throws {
        let handler = AdminAuthHandler(jwtSecret: jwtSecret, sessionExpirySeconds: 3600)
        let response = try await handler.login(username: "admin", password: "admin")
        XCTAssertFalse(response.token.isEmpty)
        XCTAssertEqual(response.username, "admin")
        XCTAssertEqual(response.role, .administrator)
        XCTAssertGreaterThan(response.expiresAt, Date())
    }

    func test_login_wrongPassword_throwsUnauthorised() async {
        let handler = AdminAuthHandler(jwtSecret: jwtSecret, sessionExpirySeconds: 3600)
        do {
            _ = try await handler.login(username: "admin", password: "wrong")
            XCTFail("Expected AdminError.unauthorised")
        } catch let error as AdminError {
            if case .unauthorised = error { /* pass */ } else {
                XCTFail("Expected .unauthorised, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_login_unknownUser_throwsUnauthorised() async {
        let handler = AdminAuthHandler(jwtSecret: jwtSecret, sessionExpirySeconds: 3600)
        do {
            _ = try await handler.login(username: "nobody", password: "anything")
            XCTFail("Expected AdminError.unauthorised")
        } catch let error as AdminError {
            if case .unauthorised = error { /* pass */ } else {
                XCTFail("Expected .unauthorised, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_validateToken_validToken_returnsClaims() async throws {
        let handler = AdminAuthHandler(jwtSecret: jwtSecret, sessionExpirySeconds: 3600)
        let loginResponse = try await handler.login(username: "admin", password: "admin")
        let claims = try await handler.validateToken(loginResponse.token)
        XCTAssertEqual(claims.subject, "admin")
    }

    func test_changePassword_validOldPassword_succeeds() async throws {
        let handler = AdminAuthHandler(jwtSecret: jwtSecret, sessionExpirySeconds: 3600)
        let loginResponse = try await handler.login(username: "admin", password: "admin")
        try await handler.changePassword(
            token: loginResponse.token,
            oldPassword: "admin",
            newPassword: "newpass123"
        )
        // Old password should no longer work
        do {
            _ = try await handler.login(username: "admin", password: "admin")
            XCTFail("Expected login with old password to fail")
        } catch { /* expected */ }
        // New password should work
        let newResponse = try await handler.login(username: "admin", password: "newpass123")
        XCTAssertEqual(newResponse.username, "admin")
    }

    func test_changePassword_wrongOldPassword_throwsUnauthorised() async throws {
        let handler = AdminAuthHandler(jwtSecret: jwtSecret, sessionExpirySeconds: 3600)
        let loginResponse = try await handler.login(username: "admin", password: "admin")
        do {
            try await handler.changePassword(
                token: loginResponse.token,
                oldPassword: "wrong",
                newPassword: "newpass123"
            )
            XCTFail("Expected AdminError.unauthorised")
        } catch let error as AdminError {
            if case .unauthorised = error { /* pass */ } else {
                XCTFail("Expected .unauthorised, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - AdminNodeHandlerTests

final class AdminNodeHandlerTests: XCTestCase {

    func test_listNodes_empty_returnsEmptyArray() async {
        let handler = AdminNodeHandler()
        let nodes = await handler.listNodes()
        XCTAssertTrue(nodes.isEmpty)
    }

    func test_createNode_storesAndReturns() async {
        let handler = AdminNodeHandler()
        let node = DicomNode(aeTitle: "REMOTE", host: "192.168.1.1", port: 11112)
        let created = await handler.createNode(node)
        XCTAssertEqual(created.aeTitle, "REMOTE")
        let list = await handler.listNodes()
        XCTAssertEqual(list.count, 1)
    }

    func test_listNodes_sortedByAETitle() async {
        let handler = AdminNodeHandler()
        _ = await handler.createNode(DicomNode(aeTitle: "ZZZ", host: "1.1.1.1", port: 104))
        _ = await handler.createNode(DicomNode(aeTitle: "AAA", host: "1.1.1.2", port: 104))
        let list = await handler.listNodes()
        XCTAssertEqual(list.map(\.aeTitle), ["AAA", "ZZZ"])
    }

    func test_getNode_existingId_returnsNode() async throws {
        let handler = AdminNodeHandler()
        let node = DicomNode(aeTitle: "TEST", host: "10.0.0.1", port: 11112)
        _ = await handler.createNode(node)
        let fetched = try await handler.getNode(id: node.id)
        XCTAssertEqual(fetched.id, node.id)
    }

    func test_getNode_unknownId_throwsNotFound() async {
        let handler = AdminNodeHandler()
        do {
            _ = try await handler.getNode(id: UUID())
            XCTFail("Expected AdminError.notFound")
        } catch let error as AdminError {
            if case .notFound = error { /* pass */ } else {
                XCTFail("Expected .notFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_updateNode_updatesFields() async throws {
        let handler = AdminNodeHandler()
        let node = DicomNode(aeTitle: "ORIG", host: "1.1.1.1", port: 11112)
        _ = await handler.createNode(node)
        let updated = DicomNode(aeTitle: "UPDATED", host: "2.2.2.2", port: 104)
        let result = try await handler.updateNode(id: node.id, with: updated)
        XCTAssertEqual(result.aeTitle, "UPDATED")
        XCTAssertEqual(result.id, node.id)
    }

    func test_deleteNode_removesNode() async throws {
        let handler = AdminNodeHandler()
        let node = DicomNode(aeTitle: "DEL", host: "1.1.1.1", port: 11112)
        _ = await handler.createNode(node)
        try await handler.deleteNode(id: node.id)
        let list = await handler.listNodes()
        XCTAssertTrue(list.isEmpty)
    }

    func test_deleteNode_unknownId_throwsNotFound() async {
        let handler = AdminNodeHandler()
        do {
            try await handler.deleteNode(id: UUID())
            XCTFail("Expected AdminError.notFound")
        } catch let error as AdminError {
            if case .notFound = error { /* pass */ } else {
                XCTFail("Expected .notFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_verifyNode_existingNode_returnsTrue() async throws {
        let handler = AdminNodeHandler()
        let node = DicomNode(aeTitle: "ECHO", host: "1.1.1.1", port: 11112)
        _ = await handler.createNode(node)
        let reachable = try await handler.verifyNode(id: node.id)
        XCTAssertTrue(reachable)
    }
}

// MARK: - AdminSetupHandlerTests

final class AdminSetupHandlerTests: XCTestCase {

    func test_getStatus_initialState_isNotCompleted() async {
        let handler = AdminSetupHandler()
        let status = await handler.getStatus()
        XCTAssertFalse(status.completed)
        XCTAssertEqual(status.setupStep, 0)
        XCTAssertEqual(status.totalSteps, 5)
    }

    func test_advanceStep_incrementsStep() async {
        let handler = AdminSetupHandler()
        let status = await handler.advanceStep()
        XCTAssertEqual(status.setupStep, 1)
        XCTAssertFalse(status.completed)
    }

    func test_advanceStep_toFinalStep_setsCompleted() async {
        let handler = AdminSetupHandler()
        for _ in 0..<5 { _ = await handler.advanceStep() }
        let status = await handler.getStatus()
        XCTAssertTrue(status.completed)
        XCTAssertEqual(status.setupStep, 5)
    }

    func test_advanceStep_beyondTotalSteps_doesNotExceedMax() async {
        let handler = AdminSetupHandler()
        for _ in 0..<10 { _ = await handler.advanceStep() }
        let status = await handler.getStatus()
        XCTAssertEqual(status.setupStep, status.totalSteps)
    }

    func test_complete_setsCompletedTrue() async {
        let handler = AdminSetupHandler()
        let status = await handler.complete()
        XCTAssertTrue(status.completed)
        XCTAssertEqual(status.setupStep, status.totalSteps)
    }

    func test_reset_restoresInitialState() async {
        let handler = AdminSetupHandler()
        _ = await handler.complete()
        let status = await handler.reset()
        XCTAssertFalse(status.completed)
        XCTAssertEqual(status.setupStep, 0)
    }
}

// MARK: - AdminLogHandlerTests

final class AdminLogHandlerTests: XCTestCase {

    func test_addEntry_storesEntry() async {
        let handler = AdminLogHandler()
        let entry = LogEntry(timestamp: Date(), level: "info", label: "test", message: "hello")
        await handler.addEntry(entry)
        let logs = await handler.getLogs(level: nil, label: nil, limit: 10, offset: 0)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].message, "hello")
    }

    func test_getLogs_filterByLevel() async {
        let handler = AdminLogHandler()
        await handler.addEntry(LogEntry(timestamp: Date(), level: "info", label: "test", message: "info msg"))
        await handler.addEntry(LogEntry(timestamp: Date(), level: "error", label: "test", message: "error msg"))
        let errors = await handler.getLogs(level: "error", label: nil, limit: 10, offset: 0)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0].level, "error")
    }

    func test_getLogs_filterByLabel() async {
        let handler = AdminLogHandler()
        await handler.addEntry(LogEntry(timestamp: Date(), level: "info", label: "com.test.alpha", message: "a"))
        await handler.addEntry(LogEntry(timestamp: Date(), level: "info", label: "com.test.beta", message: "b"))
        let alpha = await handler.getLogs(level: nil, label: "alpha", limit: 10, offset: 0)
        XCTAssertEqual(alpha.count, 1)
        XCTAssertEqual(alpha[0].message, "a")
    }

    func test_getLogs_pagination_limitAndOffset() async {
        let handler = AdminLogHandler()
        for i in 0..<10 {
            await handler.addEntry(LogEntry(timestamp: Date(), level: "info", label: "test", message: "msg\(i)"))
        }
        let page = await handler.getLogs(level: nil, label: nil, limit: 3, offset: 2)
        XCTAssertEqual(page.count, 3)
        XCTAssertEqual(page[0].message, "msg2")
    }

    func test_addEntry_ringBufferCapsAt1000() async {
        let handler = AdminLogHandler()
        for i in 0..<1100 {
            await handler.addEntry(LogEntry(timestamp: Date(), level: "info", label: "test", message: "msg\(i)"))
        }
        let all = await handler.getLogs(level: nil, label: nil, limit: 1100, offset: 0)
        XCTAssertEqual(all.count, 1000)
    }
}

// MARK: - AdminRoleTests

final class AdminRoleTests: XCTestCase {

    func test_adminRole_caseIterable_allCases() {
        let cases = AdminRole.allCases
        XCTAssertEqual(cases.count, 4)
        XCTAssertTrue(cases.contains(.administrator))
        XCTAssertTrue(cases.contains(.technologist))
        XCTAssertTrue(cases.contains(.physician))
        XCTAssertTrue(cases.contains(.auditor))
    }

    func test_adminRole_codable_roundTrip() throws {
        for role in AdminRole.allCases {
            let data = try JSONEncoder().encode(role)
            let decoded = try JSONDecoder().decode(AdminRole.self, from: data)
            XCTAssertEqual(decoded, role)
        }
    }

    func test_adminRole_rawValues_matchStrings() {
        XCTAssertEqual(AdminRole.administrator.rawValue, "administrator")
        XCTAssertEqual(AdminRole.technologist.rawValue, "technologist")
        XCTAssertEqual(AdminRole.physician.rawValue, "physician")
        XCTAssertEqual(AdminRole.auditor.rawValue, "auditor")
    }
}

// MARK: - AdminModelsTests

final class AdminModelsTests: XCTestCase {

    func test_dicomNode_defaultInit_setsTimestamps() {
        let before = Date()
        let node = DicomNode(aeTitle: "TEST", host: "localhost", port: 11112)
        let after = Date()
        XCTAssertGreaterThanOrEqual(node.createdAt, before)
        XCTAssertLessThanOrEqual(node.createdAt, after)
        XCTAssertFalse(node.id.uuidString.isEmpty)
    }

    func test_dicomNode_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let node = DicomNode(
            aeTitle: "REMOTE",
            host: "192.168.1.1",
            port: 104,
            description: "Test node",
            tlsEnabled: true
        )
        let data = try encoder.encode(node)
        let decoded = try decoder.decode(DicomNode.self, from: data)
        XCTAssertEqual(decoded.id, node.id)
        XCTAssertEqual(decoded.aeTitle, node.aeTitle)
        XCTAssertEqual(decoded.host, node.host)
        XCTAssertEqual(decoded.port, node.port)
        XCTAssertEqual(decoded.description, node.description)
        XCTAssertEqual(decoded.tlsEnabled, node.tlsEnabled)
    }

    func test_adminAPIResponse_ok_hasSuccessTrue() {
        let response = AdminAPIResponse.ok()
        XCTAssertTrue(response.success)
        XCTAssertNil(response.error)
    }

    func test_adminAPIResponse_failure_hasSuccessFalse() {
        let response = AdminAPIResponse.failure("Something went wrong")
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.error, "Something went wrong")
    }

    func test_adminError_httpStatusCodes() {
        XCTAssertEqual(AdminError.unauthorised.httpStatusCode, 401)
        XCTAssertEqual(AdminError.notFound(resource: "x").httpStatusCode, 404)
        XCTAssertEqual(AdminError.badRequest(reason: "x").httpStatusCode, 400)
        XCTAssertEqual(AdminError.conflict(reason: "x").httpStatusCode, 409)
    }

    func test_setupStatus_init_defaultsTotalSteps() {
        let status = SetupStatus(completed: false, setupStep: 0)
        XCTAssertEqual(status.totalSteps, 5)
    }
}

// MARK: - AdminSettingsHandlerTests

final class AdminSettingsHandlerTests: XCTestCase {

    func test_getSettings_returnsConfiguredValues() async {
        let config = ServerConfiguration()
        let handler = AdminSettingsHandler(configuration: config, adminPort: 8081)
        let settings = await handler.getSettings()
        XCTAssertEqual(settings.aeTitle, config.dicom.aeTitle)
        XCTAssertEqual(settings.dicomPort, config.dicom.port)
        XCTAssertEqual(settings.webPort, config.web.port)
        XCTAssertEqual(settings.adminPort, 8081)
        XCTAssertEqual(settings.logLevel, config.log.level)
    }

    func test_updateSettings_replacesCurrentValues() async {
        let config = ServerConfiguration()
        let handler = AdminSettingsHandler(configuration: config, adminPort: 8081)
        let updated = AdminSettingsPayload(
            aeTitle: "NEW",
            dicomPort: 9999,
            webPort: 9998,
            adminPort: 9997,
            archivePath: "/new/path",
            logLevel: "debug",
            checksumEnabled: false
        )
        let result = await handler.updateSettings(updated)
        XCTAssertEqual(result.aeTitle, "NEW")
        XCTAssertEqual(result.dicomPort, 9999)
        let current = await handler.getSettings()
        XCTAssertEqual(current.aeTitle, "NEW")
    }
}

// MARK: - AdminRouterTests

final class AdminRouterTests: XCTestCase {

    private func makeRouter() -> AdminRouter {
        let auth = AdminAuthHandler(jwtSecret: "test-secret", sessionExpirySeconds: 3600)
        return AdminRouter(
            auth: auth,
            dashboard: AdminDashboardHandler(),
            nodes: AdminNodeHandler(),
            storage: AdminStorageHandler(),
            logs: AdminLogHandler(),
            settings: AdminSettingsHandler(
                configuration: ServerConfiguration(),
                adminPort: 8081
            ),
            setup: AdminSetupHandler(),
            archivePath: "/tmp"
        )
    }

    func test_route_setupStatus_noAuth_returns200() async {
        let router = makeRouter()
        let request = AdminRequest(method: .get, path: "/admin/api/setup")
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_route_login_validCredentials_returns200() async throws {
        let router = makeRouter()
        let body = try JSONEncoder().encode(AdminLoginRequest(username: "admin", password: "admin"))
        let request = AdminRequest(
            method: .post,
            path: "/admin/api/auth/login",
            body: body,
            headers: ["Content-Type": "application/json"]
        )
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_route_protectedRoute_withoutToken_returns401() async {
        let router = makeRouter()
        let request = AdminRequest(method: .get, path: "/admin/api/dashboard")
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 401)
    }

    func test_route_unknownAPIPath_requiresAuth_returns401() async {
        let router = makeRouter()
        let request = AdminRequest(method: .get, path: "/admin/api/unknown/path")
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 401)
    }

    func test_route_nonAPIAdminPath_returnsHTML() async {
        let router = makeRouter()
        let request = AdminRequest(method: .get, path: "/admin/")
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(response.headers["Content-Type"]?.contains("text/html") ?? false)
    }

    func test_route_setupAdvance_noAuth_returns200() async {
        let router = makeRouter()
        let request = AdminRequest(method: .post, path: "/admin/api/setup/advance")
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_route_setupComplete_noAuth_returns200() async {
        let router = makeRouter()
        let request = AdminRequest(method: .post, path: "/admin/api/setup/complete")
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_route_login_invalidCredentials_returns401() async throws {
        let router = makeRouter()
        let body = try JSONEncoder().encode(AdminLoginRequest(username: "admin", password: "wrong"))
        let request = AdminRequest(
            method: .post,
            path: "/admin/api/auth/login",
            body: body,
            headers: ["Content-Type": "application/json"]
        )
        let response = await router.route(request)
        XCTAssertEqual(response.statusCode, 401)
    }

    func test_adminRequest_bearerToken_extractsFromAuthorizationHeader() {
        let request = AdminRequest(
            method: .get,
            path: "/admin/api/dashboard",
            headers: ["Authorization": "Bearer my-token"]
        )
        XCTAssertEqual(request.bearerToken, "my-token")
    }

    func test_adminRequest_bearerToken_lowercaseHeader_extractsToken() {
        let request = AdminRequest(
            method: .get,
            path: "/admin/api/dashboard",
            headers: ["authorization": "Bearer my-token"]
        )
        XCTAssertEqual(request.bearerToken, "my-token")
    }

    func test_adminRequest_bearerToken_missingHeader_returnsNil() {
        let request = AdminRequest(method: .get, path: "/admin/api/dashboard")
        XCTAssertNil(request.bearerToken)
    }
}
