// SPDX-License-Identifier: (see LICENSE)
// Mayam Server — Verification SCU (C-ECHO Service Class User)

import Foundation
import NIOCore
import NIOPosix
import NIOSSL
import Logging
import DICOMNetwork

/// DICOM Verification Service Class User (C-ECHO SCU).
///
/// Sends a C-ECHO request to a remote DICOM SCP to test network connectivity.
/// This is the outbound counterpart to ``VerificationSCP``.
///
/// Reference: DICOM PS3.4 Annex A — Verification Service Class
/// Reference: DICOM PS3.7 Section 9.1.5 — C-ECHO Service
///
/// ## Usage
///
/// ```swift
/// let scu = VerificationSCU(logger: logger)
/// let result = try await scu.echo(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MAYAM",
///     calledAE: "REMOTE_PACS"
/// )
/// print("Verification \(result.success ? "succeeded" : "failed")")
/// ```
public struct VerificationSCU: Sendable {

    // MARK: - Stored Properties

    /// Logger for SCU events.
    private let logger: Logger

    // MARK: - Initialiser

    /// Creates a new Verification SCU.
    ///
    /// - Parameter logger: Logger instance for SCU events.
    public init(logger: Logger) {
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Performs a C-ECHO verification against a remote DICOM SCP.
    ///
    /// - Parameters:
    ///   - host: The remote host address (IP or hostname).
    ///   - port: The remote port number (default: 11112).
    ///   - callingAE: The local Application Entity title.
    ///   - calledAE: The remote Application Entity title.
    ///   - timeout: Connection timeout in seconds (default: 30).
    ///   - tlsEnabled: Whether to use TLS for the connection (default: `false`).
    /// - Returns: A ``VerificationSCUResult`` with details of the verification.
    /// - Throws: If the connection or verification fails.
    public func echo(
        host: String,
        port: Int = 11112,
        callingAE: String,
        calledAE: String,
        timeout: TimeInterval = 30,
        tlsEnabled: Bool = false
    ) async throws -> VerificationSCUResult {
        let startTime = Date()
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        logger.info("C-ECHO SCU: connecting to \(host):\(port) (called AE: '\(calledAE)')")

        let handler = VerificationSCUHandler(
            callingAE: callingAE,
            calledAE: calledAE,
            logger: logger
        )

        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelOption(.socketOption(.so_reuseaddr), value: 1)
            .connectTimeout(.seconds(Int64(timeout)))
            .channelInitializer { channel in
                var handlers: [ChannelHandler] = []
                handlers.append(ByteToMessageHandler(PDUFrameDecoder()))
                handlers.append(handler)
                return channel.pipeline.addHandlers(handlers)
            }

        let channel = try await bootstrap.connect(host: host, port: port).get()

        // Wait for the handler to complete (success or failure)
        let result = try await handler.waitForResult()

        // Close the channel
        try? await channel.close()

        // Shut down the event loop group
        try await eventLoopGroup.shutdownGracefully()

        let endTime = Date()
        let roundTripTime = endTime.timeIntervalSince(startTime)

        return VerificationSCUResult(
            success: result,
            roundTripTime: roundTripTime,
            remoteAETitle: calledAE,
            host: host,
            port: port
        )
    }
}

// MARK: - Verification SCU Result

/// The result of a C-ECHO verification operation.
public struct VerificationSCUResult: Sendable, Equatable {

    /// Whether the verification was successful.
    public let success: Bool

    /// Round-trip time in seconds.
    public let roundTripTime: TimeInterval

    /// The remote Application Entity title.
    public let remoteAETitle: String

    /// The remote host address.
    public let host: String

    /// The remote port number.
    public let port: Int

    public init(
        success: Bool,
        roundTripTime: TimeInterval,
        remoteAETitle: String,
        host: String,
        port: Int
    ) {
        self.success = success
        self.roundTripTime = roundTripTime
        self.remoteAETitle = remoteAETitle
        self.host = host
        self.port = port
    }
}

extension VerificationSCUResult: CustomStringConvertible {
    public var description: String {
        let statusStr = success ? "SUCCESS" : "FAILED"
        return "C-ECHO \(statusStr) to \(remoteAETitle)@\(host):\(port) (rtt=\(String(format: "%.3f", roundTripTime))s)"
    }
}

// MARK: - Verification SCU Channel Handler

/// NIO channel handler for C-ECHO SCU protocol exchange.
///
/// Performs the outbound association negotiation, sends a C-ECHO request,
/// processes the response, and releases the association.
///
/// > Concurrency: This handler is marked `@unchecked Sendable` because all
/// > mutable state is accessed exclusively on the NIO `EventLoop` thread
/// > associated with the channel, as guaranteed by the NIO threading model.
/// > The `resultContinuation` is set once before channel activation and
/// > resumed exactly once from the EventLoop.
final class VerificationSCUHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private enum State {
        case connecting
        case awaitingAssociateAccept
        case awaitingCEchoResponse
        case awaitingReleaseResponse
        case completed
    }

    private let callingAE: String
    private let calledAE: String
    private let logger: Logger
    private var state: State = .connecting
    private let assembler = MessageAssembler()

    /// Continuation for the result
    private var resultContinuation: CheckedContinuation<Bool, any Error>?

    init(callingAE: String, calledAE: String, logger: Logger) {
        self.callingAE = callingAE
        self.calledAE = calledAE
        self.logger = logger
    }

    /// Wait for the C-ECHO exchange to complete.
    func waitForResult() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            self.resultContinuation = continuation
        }
    }

    func channelActive(context: ChannelHandlerContext) {
        // Send A-ASSOCIATE-RQ
        sendAssociateRequest(context: context)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = Self.unwrapInboundIn(data)

        guard let pduTypeByte = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
            completeWithError(VerificationSCUError.invalidResponse)
            context.close(promise: nil)
            return
        }

        switch pduTypeByte {
        case 0x02: // A-ASSOCIATE-AC
            handleAssociateAccept(context: context, buffer: &buffer)

        case 0x03: // A-ASSOCIATE-RJ
            logger.warning("Association rejected by remote SCP")
            completeWithResult(false)
            context.close(promise: nil)

        case 0x04: // P-DATA-TF
            handleDataTransfer(context: context, buffer: &buffer)

        case 0x06: // A-RELEASE-RP
            logger.debug("A-RELEASE-RP received")
            completeWithResult(true)
            context.close(promise: nil)

        case 0x07: // A-ABORT
            logger.warning("Association aborted by remote SCP")
            completeWithResult(false)
            context.close(promise: nil)

        default:
            logger.warning("Unexpected PDU type: 0x\(String(pduTypeByte, radix: 16))")
            completeWithResult(false)
            context.close(promise: nil)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        logger.error("SCU connection error: \(error)")
        completeWithError(error)
        context.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        if state != .completed {
            completeWithResult(false)
        }
        context.fireChannelInactive()
    }

    // MARK: - Protocol Exchange

    private func sendAssociateRequest(context: ChannelHandlerContext) {
        state = .awaitingAssociateAccept

        do {
            let presentationContext = try PresentationContext(
                id: 1,
                abstractSyntax: verificationSOPClassUID,
                transferSyntaxes: [
                    explicitVRLittleEndianTransferSyntaxUID,
                    implicitVRLittleEndianTransferSyntaxUID
                ]
            )

            let calledAETitle = try AETitle(calledAE)
            let callingAETitle = try AETitle(callingAE)

            let requestPDU = AssociateRequestPDU(
                calledAETitle: calledAETitle,
                callingAETitle: callingAETitle,
                presentationContexts: [presentationContext],
                maxPDUSize: DICOMListenerConfiguration.defaultMaxPDUSize,
                implementationClassUID: DICOMListenerConfiguration.defaultImplementationClassUID,
                implementationVersionName: DICOMListenerConfiguration.defaultImplementationVersionName
            )

            let encoded = try requestPDU.encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer), promise: nil)

            logger.debug("A-ASSOCIATE-RQ sent to '\(calledAE)'")
        } catch {
            logger.error("Failed to encode A-ASSOCIATE-RQ: \(error)")
            completeWithError(error)
            context.close(promise: nil)
        }
    }

    private func handleAssociateAccept(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        let data = Data(buffer.readableBytesView)

        do {
            let decoded = try PDUDecoder.decode(from: data)
            guard let acceptPDU = decoded as? AssociateAcceptPDU else {
                logger.error("Failed to decode A-ASSOCIATE-AC")
                completeWithResult(false)
                context.close(promise: nil)
                return
            }

            // Verify that the Verification SOP Class was accepted
            guard acceptPDU.acceptedContextIDs.contains(1) else {
                logger.warning("Verification SOP Class not accepted by remote SCP")
                sendAbort(context: context)
                completeWithResult(false)
                return
            }

            logger.debug("Association accepted by '\(calledAE)'")
            state = .awaitingCEchoResponse
            sendCEchoRequest(context: context, maxPDUSize: acceptPDU.maxPDUSize)
        } catch {
            logger.error("Failed to decode A-ASSOCIATE-AC: \(error)")
            completeWithResult(false)
            context.close(promise: nil)
        }
    }

    private func sendCEchoRequest(context: ChannelHandlerContext, maxPDUSize: UInt32) {
        let request = CEchoRequest(
            messageID: 1,
            affectedSOPClassUID: verificationSOPClassUID,
            presentationContextID: 1
        )

        let fragmenter = MessageFragmenter(maxPDUSize: maxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: nil,
            presentationContextID: 1
        )

        do {
            for pdu in pdus {
                let encoded = try pdu.encode()
                var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
                outBuffer.writeBytes(encoded)
                context.writeAndFlush(Self.wrapOutboundOut(outBuffer), promise: nil)
            }
            logger.debug("C-ECHO-RQ sent")
        } catch {
            logger.error("Failed to send C-ECHO-RQ: \(error)")
            completeWithError(error)
            context.close(promise: nil)
        }
    }

    private func handleDataTransfer(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        let data = Data(buffer.readableBytesView)

        do {
            let decoded = try PDUDecoder.decode(from: data)
            guard let dataPDU = decoded as? DataTransferPDU else {
                return
            }

            if let message = try assembler.addPDVs(from: dataPDU) {
                if message.asCEchoResponse() != nil {
                    logger.debug("C-ECHO-RSP received (success)")
                    state = .awaitingReleaseResponse
                    sendReleaseRequest(context: context)
                } else {
                    logger.warning("Unexpected DIMSE response")
                    completeWithResult(false)
                    context.close(promise: nil)
                }
            }
        } catch {
            logger.error("Error processing response: \(error)")
            completeWithResult(false)
            context.close(promise: nil)
        }
    }

    private func sendReleaseRequest(context: ChannelHandlerContext) {
        do {
            let releasePDU = ReleaseRequestPDU()
            let encoded = try releasePDU.encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer), promise: nil)
            logger.debug("A-RELEASE-RQ sent")
        } catch {
            logger.error("Failed to encode A-RELEASE-RQ: \(error)")
            completeWithResult(false)
            context.close(promise: nil)
        }
    }

    private func sendAbort(context: ChannelHandlerContext) {
        do {
            let abortPDU = AbortPDU(source: .serviceUser, reason: 0)
            let encoded = try abortPDU.encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer)).whenComplete { _ in
                context.close(promise: nil)
            }
        } catch {
            logger.error("Failed to encode A-ABORT: \(error)")
            context.close(promise: nil)
        }
    }

    // MARK: - Result Completion

    private func completeWithResult(_ success: Bool) {
        guard state != .completed else { return }
        state = .completed
        resultContinuation?.resume(returning: success)
        resultContinuation = nil
    }

    private func completeWithError(_ error: any Error) {
        guard state != .completed else { return }
        state = .completed
        resultContinuation?.resume(throwing: error)
        resultContinuation = nil
    }
}

// MARK: - Verification SCU Errors

/// Errors specific to the Verification SCU.
public enum VerificationSCUError: Error, Sendable {
    /// The remote SCP sent an invalid or unexpected response.
    case invalidResponse
}
