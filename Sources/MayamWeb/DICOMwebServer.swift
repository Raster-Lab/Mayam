// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOMweb HTTP Server

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOSSL
import MayamCore

// MARK: - DICOMwebServer

/// The DICOMweb HTTP server actor.
///
/// `DICOMwebServer` owns the NIO event loop group and channel pipeline for the
/// DICOMweb HTTP service. It exposes WADO-RS, QIDO-RS, STOW-RS, UPS-RS, and
/// WADO-URI endpoints as defined by DICOM PS3.18.
///
/// ## TLS Support
///
/// When ``ServerConfiguration/Web/tlsEnabled`` is `true` and valid certificate
/// and key paths are configured, all connections are upgraded to TLS 1.3.
///
/// ## Usage
///
/// ```swift
/// let server = DICOMwebServer(configuration: config, metadataStore: store, archivePath: "/archive")
/// try await server.start()
/// ```
///
/// Reference: DICOM PS3.18 — Web Services
public actor DICOMwebServer {

    // MARK: - Stored Properties

    /// Server configuration.
    private let configuration: ServerConfiguration.Web

    /// Archive root path for object retrieval.
    private let archivePath: String

    /// The DICOMweb request router.
    private let router: DICOMwebRouter

    /// Logger for HTTP server events.
    private let logger: MayamLogger

    /// The NIO event loop group.
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    /// The bound server channel, set after `start()`.
    private var serverChannel: (any Channel)?

    /// The UPS-RS handler (held separately to allow state inspection in tests).
    let upsHandler: UPSRSHandler

    // MARK: - Initialiser

    /// Creates a new DICOMweb HTTP server.
    ///
    /// - Parameters:
    ///   - configuration: The DICOMweb server configuration section.
    ///   - metadataStore: The metadata store shared with the DICOM service layer.
    ///   - storageActor: The archive storage actor for STOW-RS.
    ///   - archivePath: Root path of the DICOM archive for WADO-RS retrieval.
    ///   - logger: Logger instance for HTTP server events.
    public init(
        configuration: ServerConfiguration.Web,
        metadataStore: any DICOMMetadataStore,
        storageActor: StorageActor,
        archivePath: String,
        logger: MayamLogger
    ) {
        self.configuration = configuration
        self.archivePath = archivePath
        self.logger = logger
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let upsHandler = UPSRSHandler()
        self.upsHandler = upsHandler

        self.router = DICOMwebRouter(
            qidoRS: QIDORSHandler(metadataStore: metadataStore),
            wadoRS: WADORSHandler(archivePath: archivePath, metadataStore: metadataStore),
            stowRS: STOWRSHandler(storageActor: storageActor, metadataStore: metadataStore),
            upsRS: upsHandler,
            wadoURI: WADOURIHandler(archivePath: archivePath, metadataStore: metadataStore)
        )
    }

    // MARK: - Public Methods

    /// Starts the DICOMweb HTTP server and begins accepting connections.
    ///
    /// Binds to the configured port and sets up the NIO channel pipeline with
    /// HTTP/1.1 codec and the DICOMweb request handler. If TLS is configured,
    /// the pipeline includes a TLS handler.
    ///
    /// - Throws: If binding fails or TLS configuration is invalid.
    public func start() async throws {
        let router = self.router
        let basePath = self.configuration.basePath
        let logger = self.logger

        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(
                        DICOMwebChannelHandler(router: router, basePath: basePath, logger: logger)
                    )
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        let channel = try await bootstrap.bind(host: "0.0.0.0", port: configuration.port).get()
        self.serverChannel = channel

        logger.info("DICOMweb server started on port \(configuration.port)")
    }

    /// Gracefully shuts down the HTTP server and the event loop group.
    ///
    /// Closes the server channel and waits for all in-flight requests to complete.
    public func stop() async {
        if let channel = serverChannel {
            try? await channel.close().get()
            serverChannel = nil
        }
        try? await eventLoopGroup.shutdownGracefully()
        logger.info("DICOMweb server stopped")
    }

    /// Returns the actual bound port (useful when `port = 0` for ephemeral binding).
    ///
    /// - Returns: The bound port number, or `nil` if the server has not started.
    public func localPort() -> Int? {
        serverChannel?.localAddress?.port
    }
}

// MARK: - DICOMwebChannelHandler

/// A NIO `ChannelInboundHandler` that processes HTTP/1.1 requests for the
/// DICOMweb service layer.
///
/// This handler aggregates `HTTPServerRequestPart` events into a complete
/// ``DICOMwebRequest``, dispatches it to the ``DICOMwebRouter``, and writes
/// the resulting ``DICOMwebResponse`` back as HTTP/1.1 parts.
final class DICOMwebChannelHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let router: DICOMwebRouter
    private let basePath: String
    private let logger: MayamLogger

    private var requestHead: HTTPRequestHead?
    private var requestBodyBuffer: ByteBuffer = ByteBuffer()

    init(router: DICOMwebRouter, basePath: String, logger: MayamLogger) {
        self.router = router
        self.basePath = basePath
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

            // Strip base path from URI
            var uri = head.uri
            if !basePath.isEmpty && uri.hasPrefix(basePath) {
                uri = String(uri.dropFirst(basePath.count))
            }

            // Parse path and query params
            let (path, queryParams) = parseURI(uri)

            // Extract body data
            let bodyData = requestBodyBuffer.readBytes(length: requestBodyBuffer.readableBytes)
                .map { Data($0) } ?? Data()

            let request = DICOMwebRequest(
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
        response: DICOMwebResponse,
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
        logger.error("DICOMweb channel error: \(error)")
        context.close(promise: nil)
    }
}
