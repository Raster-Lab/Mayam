// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin HTTP Server

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOSSL
import MayamCore

// MARK: - AdminServer

/// The Admin console HTTP server actor.
///
/// `AdminServer` owns the NIO event loop group and channel pipeline for the
/// Admin REST API service.  It dispatches incoming HTTP/1.1 requests to the
/// ``AdminRouter``.
///
/// ## TLS Support
///
/// When ``ServerConfiguration/Admin/tlsEnabled`` is `true` and valid
/// certificate and key paths are configured, all connections are upgraded to
/// TLS 1.3.
///
/// ## Usage
///
/// ```swift
/// let server = AdminServer(configuration: config.admin, router: adminRouter, logger: logger)
/// try await server.start()
/// ```
public actor AdminServer {

    // MARK: - Stored Properties

    /// Admin server configuration.
    private let configuration: ServerConfiguration.Admin

    /// The admin request router.
    private let router: AdminRouter

    /// Logger for admin server events.
    private let logger: MayamLogger

    /// The NIO event loop group.
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    /// The bound server channel, set after `start()`.
    private var serverChannel: (any Channel)?

    // MARK: - Initialiser

    /// Creates a new admin HTTP server.
    ///
    /// - Parameters:
    ///   - configuration: The admin server configuration section.
    ///   - router: The admin request router.
    ///   - logger: Logger instance for admin server events.
    public init(
        configuration: ServerConfiguration.Admin,
        router: AdminRouter,
        logger: MayamLogger
    ) {
        self.configuration = configuration
        self.router = router
        self.logger = logger
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }

    // MARK: - Public Methods

    /// Starts the admin HTTP server and begins accepting connections.
    ///
    /// Binds to the configured port and sets up the NIO channel pipeline with
    /// HTTP/1.1 codec and the admin channel handler.
    ///
    /// - Throws: If binding fails.
    public func start() async throws {
        let router = self.router
        let logger = self.logger

        // Warn operators who have not changed the default JWT secret.
        if configuration.jwtSecret == "change-me-in-production" {
            logger.warning("Admin server is using the default JWT secret. Set MAYAM_ADMIN_JWT_SECRET or admin.jwtSecret in mayam.yaml before deploying to production.")
        }

        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(
                        AdminChannelHandler(router: router, logger: logger)
                    )
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        let channel = try await bootstrap.bind(host: "0.0.0.0", port: configuration.port).get()
        self.serverChannel = channel

        logger.info("Admin server started on port \(configuration.port)")
    }

    /// Gracefully shuts down the admin HTTP server and the event loop group.
    public func stop() async {
        if let channel = serverChannel {
            try? await channel.close().get()
            serverChannel = nil
        }
        try? await eventLoopGroup.shutdownGracefully()
        logger.info("Admin server stopped")
    }

    /// Returns the actual bound port (useful when `port = 0` for ephemeral binding).
    ///
    /// - Returns: The bound port number, or `nil` if the server has not started.
    public func localPort() -> Int? {
        serverChannel?.localAddress?.port
    }
}

// MARK: - AdminChannelHandler

/// A NIO `ChannelInboundHandler` that processes HTTP/1.1 requests for the
/// Admin service.
///
/// Aggregates `HTTPServerRequestPart` events into a complete
/// ``AdminRequest``, dispatches it to the ``AdminRouter``, and writes the
/// resulting ``AdminResponse`` back as HTTP/1.1 parts.
final class AdminChannelHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let router: AdminRouter
    private let logger: MayamLogger

    private var requestHead: HTTPRequestHead?
    private var requestBodyBuffer: ByteBuffer = ByteBuffer()

    init(router: AdminRouter, logger: MayamLogger) {
        self.router = router
        self.logger = logger
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)

        switch part {
        case .head(let head):
            self.requestHead = head
            self.requestBodyBuffer = context.channel.allocator.buffer(capacity: 0)

        case .body(var buffer):
            self.requestBodyBuffer.writeBuffer(&buffer)

        case .end:
            guard let head = requestHead else { return }
            let method = HTTPMethod(rawValue: head.method.rawValue) ?? .get
            let headers = Dictionary(
                head.headers.map { ($0.name, $0.value) },
                uniquingKeysWith: { first, _ in first }
            )

            let (path, queryParams) = parseURI(head.uri)

            let bodyData = requestBodyBuffer.readBytes(length: requestBodyBuffer.readableBytes)
                .map { Data($0) } ?? Data()

            let request = AdminRequest(
                method: method,
                path: path,
                queryParams: queryParams,
                body: bodyData,
                headers: headers
            )

            let channel = context.channel
            Task {
                let response = await self.router.route(request)
                await self.writeResponse(response: response, to: channel, httpVersion: head.version)
            }
        }
    }

    private func writeResponse(
        response: AdminResponse,
        to channel: any Channel,
        httpVersion: HTTPVersion
    ) async {
        let status = HTTPResponseStatus(statusCode: Int(response.statusCode))
        var headers = HTTPHeaders()
        for (key, value) in response.headers {
            headers.add(name: key, value: value)
        }
        headers.add(name: "Content-Length", value: "\(response.body.count)")
        headers.add(name: "Connection", value: "close")

        let head = HTTPResponseHead(version: httpVersion, status: status, headers: headers)
        channel.write(wrapOutboundOut(.head(head)), promise: nil)

        if !response.body.isEmpty {
            var buffer = channel.allocator.buffer(capacity: response.body.count)
            buffer.writeBytes(response.body)
            channel.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }

        channel.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func parseURI(_ uri: String) -> (path: String, queryParams: [String: String]) {
        guard let questionMark = uri.firstIndex(of: "?") else {
            return (uri, [:])
        }
        let path = String(uri[uri.startIndex..<questionMark])
        let queryString = String(uri[uri.index(after: questionMark)...])
        var params: [String: String] = [:]
        for component in queryString.components(separatedBy: "&") {
            let pair = component.components(separatedBy: "=")
            if pair.count == 2 {
                let key = pair[0].removingPercentEncoding ?? pair[0]
                let value = pair[1].removingPercentEncoding ?? pair[1]
                params[key] = value
            } else if pair.count == 1 && !pair[0].isEmpty {
                let key = pair[0].removingPercentEncoding ?? pair[0]
                params[key] = ""
            }
        }
        return (path, params)
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        logger.error("Admin channel error: \(error)")
        context.close(promise: nil)
    }
}
