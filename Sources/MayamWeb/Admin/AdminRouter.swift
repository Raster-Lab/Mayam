// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin HTTP Request Router

import Foundation
import MayamCore

// MARK: - AdminRequest

/// A parsed Admin API HTTP request.
public struct AdminRequest: Sendable {

    // MARK: - Stored Properties

    /// HTTP request method.
    public let method: HTTPMethod
    /// Full request path (e.g. `/admin/api/nodes`).
    public let path: String
    /// Query parameters parsed from the URL query string.
    public let queryParams: [String: String]
    /// Request body bytes.
    public let body: Data
    /// Request headers (lower-cased key look-up is handled by the
    /// ``bearerToken`` computed property).
    public let headers: [String: String]

    // MARK: - Initialisers

    /// Creates a new admin request.
    public init(
        method: HTTPMethod,
        path: String,
        queryParams: [String: String] = [:],
        body: Data = Data(),
        headers: [String: String] = [:]
    ) {
        self.method = method
        self.path = path
        self.queryParams = queryParams
        self.body = body
        self.headers = headers
    }

    // MARK: - Computed Properties

    /// Extracts the Bearer token from the `Authorization` header, if present.
    public var bearerToken: String? {
        guard let auth = headers["Authorization"] ?? headers["authorization"],
              auth.hasPrefix("Bearer ") else { return nil }
        return String(auth.dropFirst(7))
    }
}

// MARK: - AdminResponse

/// An Admin API HTTP response.
public struct AdminResponse: Sendable {

    // MARK: - Stored Properties

    /// HTTP status code.
    public let statusCode: UInt
    /// Response body bytes.
    public let body: Data
    /// Response headers.
    public let headers: [String: String]

    // MARK: - Initialiser

    /// Creates a new admin response.
    public init(statusCode: UInt, body: Data = Data(), headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.body = body
        self.headers = headers
    }

    // MARK: - Convenience Factory Methods

    /// Creates a 200 OK response with a JSON body.
    ///
    /// - Parameter json: UTF-8 encoded JSON data.
    /// - Returns: A 200 response with `Content-Type: application/json`.
    public static func ok(json: Data) -> AdminResponse {
        AdminResponse(
            statusCode: 200,
            body: json,
            headers: ["Content-Type": "application/json"]
        )
    }

    /// Creates a 201 Created response with a JSON body.
    ///
    /// - Parameter json: UTF-8 encoded JSON data.
    /// - Returns: A 201 response with `Content-Type: application/json`.
    public static func created(json: Data) -> AdminResponse {
        AdminResponse(
            statusCode: 201,
            body: json,
            headers: ["Content-Type": "application/json"]
        )
    }

    /// Creates a 204 No Content response.
    ///
    /// - Returns: A 204 response with an empty body.
    public static func noContent() -> AdminResponse {
        AdminResponse(statusCode: 204)
    }

    /// Creates an error response with a plain-text message body.
    ///
    /// - Parameters:
    ///   - statusCode: HTTP status code (e.g. 400, 401, 404, 500).
    ///   - message: Human-readable error description.
    /// - Returns: An error response with `Content-Type: text/plain`.
    public static func error(statusCode: UInt, message: String) -> AdminResponse {
        let body = message.data(using: .utf8) ?? Data()
        return AdminResponse(
            statusCode: statusCode,
            body: body,
            headers: ["Content-Type": "text/plain"]
        )
    }

    /// Creates a 200 OK response with an HTML body.
    ///
    /// - Parameter data: UTF-8 encoded HTML data.
    /// - Returns: A 200 response with `Content-Type: text/html; charset=utf-8`.
    public static func html(data: Data) -> AdminResponse {
        AdminResponse(
            statusCode: 200,
            body: data,
            headers: ["Content-Type": "text/html; charset=utf-8"]
        )
    }
}

// MARK: - AdminRouter

/// Routes incoming HTTP requests under `/admin/` to the appropriate handler.
///
/// Protected routes require a valid HS256 JWT bearer token in the
/// `Authorization` header.  The setup and login endpoints are publicly
/// accessible to allow bootstrapping a fresh installation.
///
/// ## API Prefix
/// All REST endpoints are served under `/admin/api/`.  Any other path under
/// `/admin/` returns a simple console placeholder HTML response.
public struct AdminRouter: Sendable {

    // MARK: - Stored Properties

    private let auth: AdminAuthHandler
    private let dashboard: AdminDashboardHandler
    private let nodes: AdminNodeHandler
    private let storage: AdminStorageHandler
    private let logs: AdminLogHandler
    private let settings: AdminSettingsHandler
    private let setup: AdminSetupHandler
    private let archivePath: String

    // MARK: - Initialisers

    /// Creates a new admin router with all handler dependencies.
    ///
    /// - Parameters:
    ///   - auth: Authentication handler.
    ///   - dashboard: Dashboard statistics handler.
    ///   - nodes: DICOM node registry handler.
    ///   - storage: Storage pool and integrity handler.
    ///   - logs: Log buffer handler.
    ///   - settings: Settings handler.
    ///   - setup: Setup wizard handler.
    ///   - archivePath: Root path of the DICOM archive (used for storage stats).
    public init(
        auth: AdminAuthHandler,
        dashboard: AdminDashboardHandler,
        nodes: AdminNodeHandler,
        storage: AdminStorageHandler,
        logs: AdminLogHandler,
        settings: AdminSettingsHandler,
        setup: AdminSetupHandler,
        archivePath: String
    ) {
        self.auth = auth
        self.dashboard = dashboard
        self.nodes = nodes
        self.storage = storage
        self.logs = logs
        self.settings = settings
        self.setup = setup
        self.archivePath = archivePath
    }

    // MARK: - Route

    /// Dispatches an HTTP request to the appropriate admin handler.
    ///
    /// - Parameter request: The incoming admin request.
    /// - Returns: The HTTP response.
    public func route(_ request: AdminRequest) async -> AdminResponse {
        do {
            return try await dispatch(request)
        } catch let error as AdminError {
            return AdminResponse.error(statusCode: error.httpStatusCode, message: error.description)
        } catch let error as JWTError {
            switch error {
            case .expired:
                return AdminResponse.error(statusCode: 401, message: "Token expired")
            default:
                return AdminResponse.error(statusCode: 401, message: "Invalid token")
            }
        } catch {
            return AdminResponse.error(statusCode: 500, message: "Internal error: \(error)")
        }
    }

    // MARK: - Dispatch

    private func dispatch(_ request: AdminRequest) async throws -> AdminResponse {
        let path = request.path
        let method = request.method

        // Non-API admin paths: serve a console placeholder page.
        guard path.hasPrefix("/admin/api") else {
            if path.hasPrefix("/admin") {
                return AdminResponse.html(data: consolePlaceholderHTML())
            }
            throw AdminError.notFound(resource: path)
        }

        // Strip the `/admin/api` prefix to obtain the API-relative path.
        let apiPath = String(path.dropFirst("/admin/api".count))
        let components = apiPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        // MARK: Unauthenticated routes

        // POST /admin/api/auth/login
        if components == ["auth", "login"] && method == .post {
            return try await handleLogin(request)
        }

        // GET /admin/api/setup
        if components == ["setup"] && method == .get {
            return try jsonResponse(await setup.getStatus())
        }

        // POST /admin/api/setup/advance
        if components == ["setup", "advance"] && method == .post {
            return try jsonResponse(await setup.advanceStep())
        }

        // POST /admin/api/setup/complete
        if components == ["setup", "complete"] && method == .post {
            return try jsonResponse(await setup.complete())
        }

        // MARK: Authenticated routes — validate bearer token first.
        _ = try await requireAuth(from: request)

        // GET /admin/api/dashboard
        if components == ["dashboard"] && method == .get {
            return try jsonResponse(await dashboard.getDashboardStats(archivePath: archivePath))
        }

        // GET /admin/api/nodes
        if components == ["nodes"] && method == .get {
            return try jsonResponse(await nodes.listNodes())
        }

        // POST /admin/api/nodes
        if components == ["nodes"] && method == .post {
            let node: DicomNode = try decodeBody(request.body)
            return try jsonResponse(await nodes.createNode(node), statusCode: 201)
        }

        // GET /admin/api/nodes/{id}
        if components.count == 2 && components[0] == "nodes" && method == .get {
            let id = try parseUUID(components[1], resource: "node")
            return try jsonResponse(try await nodes.getNode(id: id))
        }

        // PUT /admin/api/nodes/{id}
        if components.count == 2 && components[0] == "nodes" && method == .put {
            let id = try parseUUID(components[1], resource: "node")
            let updated: DicomNode = try decodeBody(request.body)
            return try jsonResponse(try await nodes.updateNode(id: id, with: updated))
        }

        // DELETE /admin/api/nodes/{id}
        if components.count == 2 && components[0] == "nodes" && method == .delete {
            let id = try parseUUID(components[1], resource: "node")
            try await nodes.deleteNode(id: id)
            return AdminResponse.noContent()
        }

        // POST /admin/api/nodes/{id}/verify
        if components.count == 3 && components[0] == "nodes" && components[2] == "verify" && method == .post {
            let id = try parseUUID(components[1], resource: "node")
            let reachable = try await nodes.verifyNode(id: id)
            return try jsonResponse(["reachable": reachable])
        }

        // GET /admin/api/storage
        if components == ["storage"] && method == .get {
            return try jsonResponse(await storage.getStoragePools(archivePath: archivePath))
        }

        // POST /admin/api/storage/check
        if components == ["storage", "check"] && method == .post {
            return try jsonResponse(await storage.runIntegrityCheck(archivePath: archivePath))
        }

        // GET /admin/api/logs
        if components == ["logs"] && method == .get {
            let level = request.queryParams["level"]
            let label = request.queryParams["label"]
            let limit = Int(request.queryParams["limit"] ?? "") ?? 100
            let offset = Int(request.queryParams["offset"] ?? "") ?? 0
            return try jsonResponse(await logs.getLogs(level: level, label: label, limit: limit, offset: offset))
        }

        // GET /admin/api/settings
        if components == ["settings"] && method == .get {
            return try jsonResponse(await settings.getSettings())
        }

        // PUT /admin/api/settings
        if components == ["settings"] && method == .put {
            let payload: AdminSettingsPayload = try decodeBody(request.body)
            return try jsonResponse(await settings.updateSettings(payload))
        }

        throw AdminError.notFound(resource: path)
    }

    // MARK: - Auth Helper

    /// Extracts and validates the bearer token from the request.
    ///
    /// - Parameter request: The incoming request.
    /// - Returns: Validated ``JWTClaims``.
    /// - Throws: ``AdminError/unauthorised`` if no token is present;
    ///   ``JWTError`` if the token is invalid or expired.
    private func requireAuth(from request: AdminRequest) async throws -> JWTClaims {
        guard let token = request.bearerToken else {
            throw AdminError.unauthorised
        }
        return try await auth.validateToken(token)
    }

    // MARK: - Login Handler

    private func handleLogin(_ request: AdminRequest) async throws -> AdminResponse {
        let loginReq: AdminLoginRequest = try decodeBody(request.body)
        let response = try await auth.login(username: loginReq.username, password: loginReq.password)
        return try jsonResponse(response)
    }

    // MARK: - Encoding / Decoding Helpers

    /// JSON encoder with ISO 8601 date encoding strategy.
    private static var encoder: JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    /// JSON decoder with ISO 8601 date decoding strategy.
    private static var decoder: JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    /// Encodes a value as JSON and wraps it in an `AdminResponse`.
    ///
    /// - Parameters:
    ///   - value: The value to encode.
    ///   - statusCode: HTTP status code (default 200).
    /// - Returns: An ``AdminResponse`` with the JSON body.
    /// - Throws: If JSON encoding fails.
    private func jsonResponse<T: Encodable>(_ value: T, statusCode: UInt = 200) throws -> AdminResponse {
        let data = try Self.encoder.encode(value)
        return statusCode == 201
            ? AdminResponse.created(json: data)
            : AdminResponse.ok(json: data)
    }

    /// Decodes the request body as a JSON-encoded value of the given type.
    ///
    /// - Parameter body: Raw request body bytes.
    /// - Returns: The decoded value.
    /// - Throws: ``AdminError/badRequest(reason:)`` if decoding fails.
    private func decodeBody<T: Decodable>(_ body: Data) throws -> T {
        do {
            return try Self.decoder.decode(T.self, from: body)
        } catch {
            throw AdminError.badRequest(reason: "Invalid request body: \(error)")
        }
    }

    /// Parses a UUID from a path component string.
    ///
    /// - Parameters:
    ///   - string: The path component to parse.
    ///   - resource: Resource name used in the not-found error message.
    /// - Returns: The parsed `UUID`.
    /// - Throws: ``AdminError/notFound(resource:)`` if the string is not a valid UUID.
    private func parseUUID(_ string: String, resource: String) throws -> UUID {
        guard let id = UUID(uuidString: string) else {
            throw AdminError.notFound(resource: "\(resource) \(string)")
        }
        return id
    }

    // MARK: - Console Placeholder

    /// Returns a simple HTML response indicating the admin console is available.
    private func consolePlaceholderHTML() -> Data {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head><meta charset="utf-8"><title>Mayam Admin Console</title></head>
        <body>
        <h1>Mayam Admin Console</h1>
        <p>The Admin REST API is available at <code>/admin/api/</code>.</p>
        </body>
        </html>
        """
        return Data(html.utf8)
    }
}
