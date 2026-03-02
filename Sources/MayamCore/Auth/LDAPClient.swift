// SPDX-License-Identifier: (see LICENSE)
// Mayam — LDAP Client (RFC 4511) over SwiftNIO TCP

import Foundation
import NIOCore
import NIOPosix
import NIOSSL

// MARK: - LDAPError

/// Errors that may occur during LDAP operations.
public enum LDAPError: Error, Sendable, CustomStringConvertible {
    /// The TCP connection to the LDAP server could not be established.
    case connectionFailed
    /// The supplied credentials were rejected (LDAP result code 49).
    case invalidCredentials
    /// The user account was not found in the directory.
    case userNotFound
    /// The LDAP server returned a non-zero, non-49 result code.
    case serverError(code: Int, message: String)
    /// The operation did not complete within the allowed time.
    case timeout

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .connectionFailed:                    return "LDAP connection failed"
        case .invalidCredentials:                  return "LDAP invalid credentials"
        case .userNotFound:                        return "LDAP user not found"
        case .serverError(let code, let msg):      return "LDAP server error \(code): \(msg)"
        case .timeout:                             return "LDAP operation timed out"
        }
    }
}

// MARK: - LDAPUserEntry

/// A user record returned from an LDAP search operation.
public struct LDAPUserEntry: Sendable {
    /// Distinguished Name of the user entry.
    public let dn: String
    /// Username attribute value (e.g. `uid` or `sAMAccountName`).
    public let username: String
    /// E-mail address, if present in the directory.
    public let email: String?
    /// Display name, if present in the directory.
    public let displayName: String?
    /// Group DNs (values of `memberOf` attribute).
    public let groups: [String]

    /// Creates a new LDAP user entry.
    ///
    /// - Parameters:
    ///   - dn: Distinguished Name.
    ///   - username: Username attribute value.
    ///   - email: Optional e-mail address.
    ///   - displayName: Optional display name.
    ///   - groups: Group DN strings from `memberOf`.
    public init(
        dn: String,
        username: String,
        email: String? = nil,
        displayName: String? = nil,
        groups: [String] = []
    ) {
        self.dn = dn
        self.username = username
        self.email = email
        self.displayName = displayName
        self.groups = groups
    }
}

// MARK: - LDAPClient

/// An async LDAP client that communicates using SwiftNIO TCP sockets and
/// hand-encoded BER messages as defined by RFC 4511.
///
/// All LDAP messages are encoded/decoded using ``LDAPBERCoder``.  The client
/// supports simple bind, subtree-scope search, and an anonymous-bind
/// connectivity test.
///
/// ## Usage
/// ```swift
/// let client = LDAPClient(configuration: ldapConfig)
/// try await client.bind(dn: "cn=service,dc=example,dc=com", password: "secret")
/// let entry = try await client.searchUser(username: "jsmith")
/// ```
public actor LDAPClient {

    // MARK: - Stored Properties

    /// LDAP connection configuration sourced from ``ServerConfiguration/LDAP``.
    private let configuration: ServerConfiguration.LDAP

    /// The shared SwiftNIO event loop group for TCP I/O.
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    // MARK: - Initialiser

    /// Creates a new LDAP client with the given configuration.
    ///
    /// - Parameter configuration: LDAP server and schema settings.
    public init(configuration: ServerConfiguration.LDAP) {
        self.configuration = configuration
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    // MARK: - Public Methods

    /// Tests connectivity to the LDAP server by performing an anonymous bind.
    ///
    /// - Returns: `true` if the connection was established and the anonymous
    ///   bind succeeded.
    /// - Throws: ``LDAPError/connectionFailed`` or ``LDAPError/timeout`` on
    ///   network failure.
    public func testConnection() async throws -> Bool {
        try await performBind(dn: "", password: "")
        return true
    }

    /// Performs a simple LDAP bind (authentication) with the given DN and password.
    ///
    /// - Parameters:
    ///   - dn: The Distinguished Name to bind as.
    ///   - password: The plaintext password (transmitted over TLS when enabled).
    /// - Throws: ``LDAPError/invalidCredentials`` if the server returns result
    ///   code 49; ``LDAPError/serverError(code:message:)`` for other non-zero
    ///   result codes; ``LDAPError/connectionFailed`` on network failure.
    public func bind(dn: String, password: String) async throws {
        try await performBind(dn: dn, password: password)
    }

    /// Searches the directory for a user matching the configured username attribute.
    ///
    /// The search uses wholeSubtree scope under `baseDN`, an equality filter on
    /// the `usernameAttribute`, and requests `cn`, `mail`, and `memberOf`
    /// attributes.
    ///
    /// - Parameter username: The username to search for.
    /// - Returns: An ``LDAPUserEntry`` if found, otherwise `nil`.
    /// - Throws: ``LDAPError`` on connection or server errors.
    public func searchUser(username: String) async throws -> LDAPUserEntry? {
        let channel = try await openChannel()
        defer { _ = channel.close() }

        // Bind as service account first.
        try await sendBind(
            channel: channel,
            messageID: 1,
            dn: configuration.serviceBindDN,
            password: configuration.serviceBindPassword
        )
        let bindResponse = try await readMessage(channel: channel)
        try checkBindResult(bindResponse)

        // Build and send the search request.
        let searchRequest = buildSearchRequest(
            messageID: 2,
            username: username
        )
        try await channel.writeAndFlush(ByteBuffer(bytes: searchRequest)).get()

        // Collect search result entries.
        return try await collectSearchResult(channel: channel, username: username)
    }

    /// Authenticates a user by first searching for their DN, then binding with
    /// their password.
    ///
    /// - Parameters:
    ///   - username: Login username.
    ///   - password: Plaintext password.
    /// - Returns: The authenticated ``LDAPUserEntry``.
    /// - Throws: ``LDAPError/userNotFound`` if the username is not in the
    ///   directory; ``LDAPError/invalidCredentials`` if the password is wrong.
    public func authenticate(username: String, password: String) async throws -> LDAPUserEntry {
        guard let entry = try await searchUser(username: username) else {
            throw LDAPError.userNotFound
        }
        try await bind(dn: entry.dn, password: password)
        return entry
    }

    // MARK: - Private — TCP Channel

    /// Opens a NIO channel to the LDAP server.
    private func openChannel() async throws -> Channel {
        do {
            if configuration.useTLS {
                return try await openTLSChannel()
            } else {
                return try await openPlainChannel()
            }
        } catch {
            throw LDAPError.connectionFailed
        }
    }

    private func openPlainChannel() async throws -> Channel {
        try await ClientBootstrap(group: eventLoopGroup)
            .connectTimeout(.seconds(5))
            .connect(host: configuration.host, port: configuration.port)
            .get()
    }

    private func openTLSChannel() async throws -> Channel {
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        tlsConfig.certificateVerification = .none
        let sslContext = try NIOSSLContext(configuration: tlsConfig)
        return try await ClientBootstrap(group: eventLoopGroup)
            .connectTimeout(.seconds(5))
            .channelInitializer { channel in
                let sslHandler = try! NIOSSLClientHandler(
                    context: sslContext,
                    serverHostname: self.configuration.host
                )
                return channel.pipeline.addHandler(sslHandler)
            }
            .connect(host: configuration.host, port: configuration.port)
            .get()
    }

    // MARK: - Private — Bind

    @discardableResult
    private func performBind(dn: String, password: String) async throws -> [UInt8] {
        let channel = try await openChannel()
        defer { _ = channel.close() }
        try await sendBind(channel: channel, messageID: 1, dn: dn, password: password)
        let response = try await readMessage(channel: channel)
        try checkBindResult(response)
        return response
    }

    private func sendBind(
        channel: Channel,
        messageID: Int,
        dn: String,
        password: String
    ) async throws {
        // BindRequest ::= [APPLICATION 0] SEQUENCE {
        //   version      INTEGER (1..127),
        //   name         LDAPDN,
        //   authentication AuthenticationChoice }
        // AuthenticationChoice ::= CHOICE {
        //   simple [0] OCTET STRING }
        let versionBytes = BEREncoder.encodeInteger(3)
        let dnBytes = BEREncoder.encodeOctetString(dn)
        let simpleAuth = BEREncoder.encodeTagged(tag: BERTag.contextPrimitive(0), contents: Array(password.utf8))
        let bindRequestContents = versionBytes + dnBytes + simpleAuth
        let bindRequest = BEREncoder.encodeTagged(
            tag: BERTag.application(0),
            contents: bindRequestContents
        )
        let messageContents = BEREncoder.encodeInteger(messageID) + bindRequest
        let envelope = BEREncoder.encodeSequence(messageContents)
        var buffer = channel.allocator.buffer(capacity: envelope.count)
        buffer.writeBytes(envelope)
        try await channel.writeAndFlush(buffer).get()
    }

    private func checkBindResult(_ bytes: [UInt8]) throws {
        // Parse the outer SEQUENCE envelope.
        var offset = 0
        guard let outerContents = try? BERDecoder.readSequence(from: bytes, offset: &offset) else {
            throw LDAPError.serverError(code: -1, message: "Malformed bind response")
        }
        var inner = 0
        // Skip messageID integer.
        _ = try? BERDecoder.readInteger(from: outerContents, offset: &inner)
        // Read BindResponse (APPLICATION 1).
        guard inner < outerContents.count else {
            throw LDAPError.serverError(code: -1, message: "Truncated bind response")
        }
        let appTag = outerContents[inner]
        inner += 1
        guard let responseLength = try? parseLengthAt(bytes: outerContents, offset: &inner) else {
            throw LDAPError.serverError(code: -1, message: "Cannot parse response length")
        }
        guard inner + responseLength <= outerContents.count else {
            throw LDAPError.serverError(code: -1, message: "Truncated response payload")
        }
        let responseContents = Array(outerContents[inner ..< inner + responseLength])
        _ = appTag  // APPLICATION 1 for BindResponse

        // LDAPResult: resultCode (ENUMERATED), matchedDN (OCTET STRING), errorMessage (OCTET STRING)
        var rc = 0
        var errorMessage = ""
        do {
            var rcOffset = 0
            rc = try BERDecoder.readEnumerated(from: responseContents, offset: &rcOffset)
            _ = try? BERDecoder.readOctetString(from: responseContents, offset: &rcOffset)
            errorMessage = (try? BERDecoder.readOctetString(from: responseContents, offset: &rcOffset)) ?? ""
        } catch {
            throw LDAPError.serverError(code: -1, message: "Cannot parse result code")
        }

        switch rc {
        case 0:
            return  // success
        case 49:
            throw LDAPError.invalidCredentials
        default:
            throw LDAPError.serverError(code: rc, message: errorMessage)
        }
    }

    // MARK: - Private — Search

    private func buildSearchRequest(messageID: Int, username: String) -> [UInt8] {
        // SearchRequest ::= [APPLICATION 3] SEQUENCE {
        //   baseObject   LDAPDN,
        //   scope        ENUMERATED { baseObject(0), singleLevel(1), wholeSubtree(2) },
        //   derefAliases ENUMERATED { ... },
        //   sizeLimit    INTEGER,
        //   timeLimit    INTEGER,
        //   typesOnly    BOOLEAN,
        //   filter       Filter,
        //   attributes   AttributeDescriptionList }
        let baseObject = BEREncoder.encodeOctetString(configuration.baseDN)
        let scope = BEREncoder.encodeEnumerated(2)          // wholeSubtree
        let derefAliases = BEREncoder.encodeEnumerated(0)   // neverDerefAliases
        let sizeLimit = BEREncoder.encodeInteger(0)
        let timeLimit = BEREncoder.encodeInteger(30)
        let typesOnly = BEREncoder.encodeBoolean(false)

        // Filter: equalityMatch [3] (usernameAttribute = username)
        let attributeAssertion =
            BEREncoder.encodeOctetString(configuration.schema.usernameAttribute) +
            BEREncoder.encodeOctetString(username)
        let equalityFilter = BEREncoder.encodeTagged(
            tag: BERTag.contextConstructed(3),
            contents: attributeAssertion
        )

        // Requested attributes: cn, mail, memberOf
        let requestedAttrs: [UInt8] = [
            BEREncoder.encodeOctetString("cn"),
            BEREncoder.encodeOctetString(configuration.schema.emailAttribute),
            BEREncoder.encodeOctetString(configuration.schema.memberOfAttribute)
        ].flatMap { $0 }
        let attrList = BEREncoder.encodeSequence(requestedAttrs)

        let searchContents =
            baseObject + scope + derefAliases + sizeLimit +
            timeLimit + typesOnly + equalityFilter + attrList

        let searchRequest = BEREncoder.encodeTagged(
            tag: BERTag.application(3),
            contents: searchContents
        )
        let messageContents = BEREncoder.encodeInteger(messageID) + searchRequest
        return BEREncoder.encodeSequence(messageContents)
    }

    private func collectSearchResult(channel: Channel, username: String) async throws -> LDAPUserEntry? {
        var dn = ""
        var emailVal: String?
        var displayName: String?
        var groups: [String] = []
        var foundEntry = false

        for _ in 0 ..< 100 {
            let msgBytes: [UInt8]
            do {
                msgBytes = try await readMessage(channel: channel)
            } catch {
                break
            }

            // Parse outer SEQUENCE.
            var offset = 0
            guard let outerContents = try? BERDecoder.readSequence(from: msgBytes, offset: &offset) else {
                break
            }
            var inner = 0
            _ = try? BERDecoder.readInteger(from: outerContents, offset: &inner)
            guard inner < outerContents.count else { break }

            let appTag = outerContents[inner]
            inner += 1
            guard let responseLength = try? parseLengthAt(bytes: outerContents, offset: &inner) else { break }
            guard inner + responseLength <= outerContents.count else { break }
            let responseContents = Array(outerContents[inner ..< inner + responseLength])

            // APPLICATION 4 = SearchResultEntry; APPLICATION 5 = SearchResultDone
            if appTag == BERTag.application(4) {
                // SearchResultEntry: objectName LDAPDN, attributes PartialAttributeList
                var rOffset = 0
                if let objectName = try? BERDecoder.readOctetString(from: responseContents, offset: &rOffset) {
                    dn = objectName
                }
                if rOffset < responseContents.count,
                   let attrListContents = try? BERDecoder.readSequence(from: responseContents, offset: &rOffset) {
                    parseAttributes(
                        attrListContents,
                        dn: &dn,
                        email: &emailVal,
                        displayName: &displayName,
                        groups: &groups,
                        username: username
                    )
                }
                foundEntry = true
            } else if appTag == BERTag.application(5) {
                // SearchResultDone — stop reading.
                break
            }
        }

        guard foundEntry else { return nil }
        return LDAPUserEntry(
            dn: dn,
            username: username,
            email: emailVal,
            displayName: displayName,
            groups: groups
        )
    }

    private func parseAttributes(
        _ bytes: [UInt8],
        dn: inout String,
        email: inout String?,
        displayName: inout String?,
        groups: inout [String],
        username: String
    ) {
        var offset = 0
        while offset < bytes.count {
            guard let (attrTag, attrContents) = try? BERDecoder.readTLV(from: bytes, offset: &offset) else { break }
            _ = attrTag  // should be SEQUENCE
            var aInner = 0
            guard let attrName = try? BERDecoder.readOctetString(from: attrContents, offset: &aInner) else { continue }
            guard aInner < attrContents.count else { continue }
            // Read SET of values.
            guard let (setTag, setContents) = try? BERDecoder.readTLV(from: attrContents, offset: &aInner) else { continue }
            _ = setTag
            var sInner = 0
            var values: [String] = []
            while sInner < setContents.count {
                guard let val = try? BERDecoder.readOctetString(from: setContents, offset: &sInner) else { break }
                values.append(val)
            }
            let attrNameLower = attrName.lowercased()
            if attrNameLower == "mail" || attrNameLower == configuration.schema.emailAttribute.lowercased() {
                email = values.first
            } else if attrNameLower == "cn" || attrNameLower == configuration.schema.displayNameAttribute.lowercased() {
                displayName = values.first
            } else if attrNameLower == configuration.schema.memberOfAttribute.lowercased() {
                groups = values
            }
        }
    }

    // MARK: - Private — I/O Helpers

    /// Reads one LDAP message (complete BER TLV) from the channel.
    private func readMessage(channel: Channel) async throws -> [UInt8] {
        let promise = channel.eventLoop.makePromise(of: ByteBuffer.self)
        // Use a simple accumulating read approach via NIO.
        let handler = SingleMessageReadHandler(promise: promise)
        try await channel.pipeline.addHandler(handler, position: .last).get()
        let buffer = try await withThrowingTaskGroup(of: ByteBuffer.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    promise.futureResult.whenComplete { result in
                        switch result {
                        case .success(let buf): continuation.resume(returning: buf)
                        case .failure(let err): continuation.resume(throwing: err)
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw LDAPError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
        return Array(buffer.readableBytesView)
    }

    // MARK: - Private — Length Parsing Shortcut

    private func parseLengthAt(bytes: [UInt8], offset: inout Int) throws -> Int {
        guard offset < bytes.count else { throw BERDecoder.Error.truncated }
        let first = bytes[offset]
        offset += 1
        if first & 0x80 == 0 { return Int(first) }
        let numBytes = Int(first & 0x7F)
        guard numBytes > 0 && numBytes <= 4 && offset + numBytes <= bytes.count else {
            throw BERDecoder.Error.invalidLength
        }
        var length = 0
        for i in 0 ..< numBytes {
            length = (length << 8) | Int(bytes[offset + i])
        }
        offset += numBytes
        return length
    }
}

// MARK: - SingleMessageReadHandler

/// A NIO channel handler that collects inbound bytes until a complete BER
/// SEQUENCE TLV has been received, then fulfils the given promise.
private final class SingleMessageReadHandler: ChannelInboundHandler, RemovableChannelHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer

    private var accumulated: [UInt8] = []
    private let promise: EventLoopPromise<ByteBuffer>
    private var fulfilled = false

    init(promise: EventLoopPromise<ByteBuffer>) {
        self.promise = promise
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buf = unwrapInboundIn(data)
        accumulated += Array(buf.readableBytesView)
        if let completeMessage = extractCompleteMessage() {
            if !fulfilled {
                fulfilled = true
                var result = context.channel.allocator.buffer(capacity: completeMessage.count)
                result.writeBytes(completeMessage)
                promise.succeed(result)
                _ = context.pipeline.removeHandler(self)
            }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        if !fulfilled {
            fulfilled = true
            promise.fail(error)
        }
    }

    private func extractCompleteMessage() -> [UInt8]? {
        guard accumulated.count >= 2 else { return nil }
        guard accumulated[0] == BERTag.sequence else { return nil }
        var offset = 1
        guard let length = try? parseLengthAt(bytes: accumulated, offset: &offset) else { return nil }
        let totalNeeded = offset + length
        guard accumulated.count >= totalNeeded else { return nil }
        let msg = Array(accumulated[0 ..< totalNeeded])
        accumulated.removeFirst(totalNeeded)
        return msg
    }

    private func parseLengthAt(bytes: [UInt8], offset: inout Int) throws -> Int {
        guard offset < bytes.count else { throw BERDecoder.Error.truncated }
        let first = bytes[offset]
        offset += 1
        if first & 0x80 == 0 { return Int(first) }
        let numBytes = Int(first & 0x7F)
        guard numBytes > 0 && numBytes <= 4 && offset + numBytes <= bytes.count else {
            throw BERDecoder.Error.invalidLength
        }
        var length = 0
        for i in 0 ..< numBytes {
            length = (length << 8) | Int(bytes[offset + i])
        }
        offset += numBytes
        return length
    }
}
