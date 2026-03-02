// SPDX-License-Identifier: (see LICENSE)
// Mayam Server — DICOM TCP Listener (Swift NIO)

import Foundation
import NIOCore
import NIOPosix
import NIOSSL
import Logging

/// A DICOM TCP listener built on Swift NIO that accepts inbound DICOM
/// associations and processes DIMSE commands.
///
/// `DICOMListener` binds to a configured TCP port and creates a new
/// ``DICOMAssociationHandler`` for each inbound connection. It supports
/// optional TLS 1.3 for secure DICOM associations (DICOM PS3.15).
///
/// ## Architecture
///
/// ```
/// DICOMListener (TCP bind)
///   └── per-connection channel pipeline:
///       ├── [NIOSSLServerHandler]  (optional, TLS 1.3)
///       ├── PDUFrameDecoder        (byte-to-message framing)
///       └── DICOMAssociationHandler (protocol handling)
/// ```
///
/// Reference: DICOM PS3.8 — Network Communication Support
public actor DICOMListener {

    // MARK: - Stored Properties

    /// The listener configuration.
    public let configuration: DICOMListenerConfiguration

    /// The SCP dispatcher for routing DIMSE commands.
    private let dispatcher: SCPDispatcher

    /// Logger for listener events.
    private let logger: Logger

    /// The NIO event loop group for the listener.
    private let eventLoopGroup: MultiThreadedEventLoopGroup

    /// The bound server channel (non-nil while listening).
    private var serverChannel: Channel?

    /// The number of active associations.
    private var activeAssociationCount: Int = 0

    // MARK: - Initialiser

    /// Creates a new DICOM listener.
    ///
    /// - Parameters:
    ///   - configuration: The listener configuration.
    ///   - dispatcher: The SCP dispatcher for routing DIMSE commands.
    ///   - logger: Logger instance for listener events.
    ///   - eventLoopGroup: The NIO event loop group (default: creates a new one).
    public init(
        configuration: DICOMListenerConfiguration,
        dispatcher: SCPDispatcher = SCPDispatcher(),
        logger: Logger,
        eventLoopGroup: MultiThreadedEventLoopGroup? = nil
    ) {
        self.configuration = configuration
        self.dispatcher = dispatcher
        self.logger = logger
        self.eventLoopGroup = eventLoopGroup ?? MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }

    // MARK: - Public Methods

    /// Starts listening for inbound DICOM associations.
    ///
    /// - Throws: If the listener cannot bind to the configured port.
    public func start() async throws {
        let tlsContext = try makeTLSContext()
        let listenerConfig = self.configuration
        let scpDispatcher = self.dispatcher
        let listenerLogger = self.logger

        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                var handlers: [ChannelHandler] = []

                // Add TLS handler if configured
                if let sslContext = tlsContext {
                    let sslHandler = NIOSSLServerHandler(context: sslContext)
                    handlers.append(sslHandler)
                }

                // Add PDU framing decoder
                handlers.append(ByteToMessageHandler(PDUFrameDecoder()))

                // Add DICOM association handler
                let associationHandler = DICOMAssociationHandler(
                    configuration: listenerConfig,
                    dispatcher: scpDispatcher,
                    logger: listenerLogger
                )
                handlers.append(associationHandler)

                return channel.pipeline.addHandlers(handlers)
            }
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 16)

        let channel = try await bootstrap.bind(host: "0.0.0.0", port: configuration.port).get()
        serverChannel = channel

        logger.info("DICOM listener started on port \(configuration.port) with AE Title '\(configuration.aeTitle)'")

        if tlsContext != nil {
            logger.info("TLS 1.3 enabled for DICOM associations")
        }
    }

    /// Stops the DICOM listener and closes all active associations.
    public func stop() async {
        logger.info("Stopping DICOM listener…")

        if let channel = serverChannel {
            try? await channel.close()
            serverChannel = nil
        }

        logger.info("DICOM listener stopped")
    }

    /// Shuts down the event loop group.
    ///
    /// Call this only when the server is shutting down permanently.
    public func shutdownEventLoopGroup() async throws {
        try await eventLoopGroup.shutdownGracefully()
    }

    /// Returns the number of active associations.
    public func getActiveAssociationCount() -> Int {
        activeAssociationCount
    }

    /// Returns whether the listener is currently accepting connections.
    public func isListening() -> Bool {
        serverChannel?.isActive ?? false
    }

    /// Returns the actual bound port number.
    ///
    /// Useful when binding to port `0` to discover the ephemeral port assigned
    /// by the operating system.
    ///
    /// - Returns: The bound port, or `nil` if the listener is not active.
    public func localPort() -> Int? {
        serverChannel?.localAddress?.port
    }

    // MARK: - TLS Configuration

    /// Creates a NIO SSL context if TLS is enabled.
    ///
    /// - Returns: An `NIOSSLContext` if TLS is configured, `nil` otherwise.
    /// - Throws: If TLS certificate or key files cannot be loaded.
    private func makeTLSContext() throws -> NIOSSLContext? {
        guard configuration.tlsEnabled else { return nil }

        guard let certPath = configuration.tlsCertificatePath,
              let keyPath = configuration.tlsKeyPath else {
            logger.error("TLS enabled but certificate or key path not configured")
            throw DICOMListenerError.tlsConfigurationMissing
        }

        let certificates = try NIOSSLCertificate.fromPEMFile(certPath)
        let privateKey = try NIOSSLPrivateKey(file: keyPath, format: .pem)

        var tlsConfig = TLSConfiguration.makeServerConfiguration(
            certificateChain: certificates.map { .certificate($0) },
            privateKey: .privateKey(privateKey)
        )
        tlsConfig.minimumTLSVersion = .tlsv13

        return try NIOSSLContext(configuration: tlsConfig)
    }
}

// MARK: - DICOM Listener Errors

/// Errors that may occur during DICOM listener operations.
public enum DICOMListenerError: Error, Sendable, CustomStringConvertible {

    /// TLS is enabled but the certificate or key path is not configured.
    case tlsConfigurationMissing

    /// The listener failed to bind to the configured port.
    case bindFailed(port: Int, underlying: any Error)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .tlsConfigurationMissing:
            return "TLS is enabled but certificate or key path is not configured"
        case .bindFailed(let port, let underlying):
            return "Failed to bind DICOM listener to port \(port): \(underlying)"
        }
    }
}
