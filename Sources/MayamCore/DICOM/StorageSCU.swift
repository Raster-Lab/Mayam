// SPDX-License-Identifier: (see LICENSE)
// Mayam — Storage SCU (C-STORE Service Class User)

import Foundation
import NIOCore
import NIOPosix
import NIOSSL
import Logging
import DICOMNetwork

/// DICOM Storage Service Class User (C-STORE SCU).
///
/// Sends a DICOM object (raw data set bytes) to a remote DICOM SCP using a
/// C-STORE request.  This is the outbound counterpart to ``StorageSCP`` and is
/// used for routing and forwarding DICOM objects between PACS nodes.
///
/// Reference: DICOM PS3.4 Annex B — Storage Service Class
/// Reference: DICOM PS3.7 Section 9.1.1 — C-STORE Service
///
/// ## Usage
///
/// ```swift
/// let scu = StorageSCU(logger: logger)
/// let result = try await scu.store(
///     dataSet: dicomBytes,
///     sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
///     sopInstanceUID: "1.2.3.4.5",
///     transferSyntaxUID: "1.2.840.10008.1.2.1",
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MAYAM",
///     calledAE: "REMOTE_PACS"
/// )
/// print("Store \(result.success ? "succeeded" : "failed")")
/// ```
public struct StorageSCU: Sendable {

    // MARK: - Stored Properties

    /// Logger for SCU events.
    private let logger: Logger

    // MARK: - Initialiser

    /// Creates a new Storage SCU.
    ///
    /// - Parameter logger: Logger instance for SCU events.
    public init(logger: Logger) {
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Sends a DICOM object to a remote DICOM SCP using C-STORE.
    ///
    /// - Parameters:
    ///   - dataSet: The raw DICOM data set bytes to send.
    ///   - sopClassUID: The SOP Class UID of the object (0008,0016).
    ///   - sopInstanceUID: The SOP Instance UID of the object (0008,0018).
    ///   - transferSyntaxUID: Transfer syntax of the data set.
    ///   - host: The remote host address (IP or hostname).
    ///   - port: The remote DICOM port (default: 11112).
    ///   - callingAE: The local AE Title.
    ///   - calledAE: The remote AE Title.
    ///   - timeout: Connection timeout in seconds (default: 30).
    ///   - tlsEnabled: Whether to use TLS 1.3 (default: `false`).
    /// - Returns: A ``StoreSCUResult`` describing the operation outcome.
    /// - Throws: If the connection or protocol exchange fails.
    public func store(
        dataSet: Data,
        sopClassUID: String,
        sopInstanceUID: String,
        transferSyntaxUID: String,
        host: String,
        port: Int = 11112,
        callingAE: String,
        calledAE: String,
        timeout: TimeInterval = 30,
        tlsEnabled: Bool = false
    ) async throws -> StoreSCUResult {
        let startTime = Date()
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        logger.info("C-STORE SCU: connecting to \(host):\(port) (called AE: '\(calledAE)', sop: '\(sopInstanceUID)')")

        let handler = StorageSCUHandler(
            callingAE: callingAE,
            calledAE: calledAE,
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            transferSyntaxUID: transferSyntaxUID,
            dataSet: dataSet,
            logger: logger
        )

        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelOption(.socketOption(.so_reuseaddr), value: 1)
            .connectTimeout(.seconds(Int64(timeout)))
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    ByteToMessageHandler(PDUFrameDecoder()),
                    handler
                ])
            }

        let channel = try await bootstrap.connect(host: host, port: port).get()
        let (success, status) = try await handler.waitForResult()
        try? await channel.close()
        try await eventLoopGroup.shutdownGracefully()

        let roundTripTime = Date().timeIntervalSince(startTime)
        return StoreSCUResult(
            success: success,
            status: status,
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            roundTripTime: roundTripTime,
            remoteAETitle: calledAE,
            host: host,
            port: port
        )
    }
}

// MARK: - StoreSCUResult

/// The result of a C-STORE SCU operation.
public struct StoreSCUResult: Sendable, Equatable {

    /// Whether the C-STORE operation was accepted with success or warning.
    public let success: Bool

    /// The DIMSE status returned by the remote SCP.
    public let status: DIMSEStatus

    /// The SOP Class UID of the stored object.
    public let sopClassUID: String

    /// The SOP Instance UID of the stored object.
    public let sopInstanceUID: String

    /// Round-trip time for the complete store operation, in seconds.
    public let roundTripTime: TimeInterval

    /// The remote Application Entity title.
    public let remoteAETitle: String

    /// The remote host address.
    public let host: String

    /// The remote port number.
    public let port: Int

    /// Creates a store SCU result.
    public init(
        success: Bool,
        status: DIMSEStatus,
        sopClassUID: String,
        sopInstanceUID: String,
        roundTripTime: TimeInterval,
        remoteAETitle: String,
        host: String,
        port: Int
    ) {
        self.success = success
        self.status = status
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.roundTripTime = roundTripTime
        self.remoteAETitle = remoteAETitle
        self.host = host
        self.port = port
    }
}

extension StoreSCUResult: CustomStringConvertible {
    public var description: String {
        let statusStr = success ? "SUCCESS" : "FAILED"
        return "C-STORE \(statusStr) to \(remoteAETitle)@\(host):\(port) " +
               "sop=\(sopInstanceUID) rtt=\(String(format: "%.3f", roundTripTime))s"
    }
}

// MARK: - StorageSCU Channel Handler

/// NIO channel handler implementing the C-STORE SCU protocol exchange.
///
/// Performs outbound association negotiation, sends a C-STORE request with the
/// DICOM data set, receives the response, then releases the association.
///
/// > Concurrency: Marked `@unchecked Sendable` because all mutable state is
/// > accessed exclusively on the NIO EventLoop thread, as guaranteed by NIO's
/// > threading model.  The `resultContinuation` is set before activation and
/// > resumed exactly once.
final class StorageSCUHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    // MARK: - Private State

    private enum State {
        case connecting
        case awaitingAssociateAccept
        case awaitingCStoreResponse
        case awaitingReleaseResponse
        case completed
    }

    private let callingAE: String
    private let calledAE: String
    private let sopClassUID: String
    private let sopInstanceUID: String
    private let transferSyntaxUID: String
    private let dataSet: Data
    private let logger: Logger

    private var state: State = .connecting
    private let assembler = MessageAssembler()
    /// Maximum PDU size used to fragment outbound C-STORE messages.
    ///
    /// Initialised to the local default; updated to the minimum of the local
    /// default and the remote's declared maximum once the A-ASSOCIATE-AC is
    /// received.  Until then, the local default is used conservatively.
    private var negotiatedMaxPDUSize: UInt32 = DICOMListenerConfiguration.defaultMaxPDUSize
    private var acceptedPresentationContextID: UInt8 = 1

    private var resultContinuation: CheckedContinuation<(Bool, DIMSEStatus), any Error>?

    // MARK: - Initialiser

    init(
        callingAE: String,
        calledAE: String,
        sopClassUID: String,
        sopInstanceUID: String,
        transferSyntaxUID: String,
        dataSet: Data,
        logger: Logger
    ) {
        self.callingAE = callingAE
        self.calledAE = calledAE
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.transferSyntaxUID = transferSyntaxUID
        self.dataSet = dataSet
        self.logger = logger
    }

    /// Awaits the completion of the C-STORE exchange.
    ///
    /// - Returns: A tuple of `(success, status)` where success is `true` if
    ///   the SCP returned a success or warning status.
    func waitForResult() async throws -> (Bool, DIMSEStatus) {
        try await withCheckedThrowingContinuation { self.resultContinuation = $0 }
    }

    // MARK: - NIO Handlers

    func channelActive(context: ChannelHandlerContext) {
        sendAssociateRequest(context: context)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = Self.unwrapInboundIn(data)

        guard let pduTypeByte = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
            completeWithError(StorageSCUError.invalidResponse)
            context.close(promise: nil)
            return
        }

        switch pduTypeByte {
        case 0x02: handleAssociateAccept(context: context, buffer: &buffer)
        case 0x03:
            logger.warning("C-STORE SCU: association rejected by remote SCP")
            completeWithResult(false, status: .failedUnableToProcess)
            context.close(promise: nil)
        case 0x04: handleDataTransfer(context: context, buffer: &buffer)
        case 0x06:
            logger.debug("C-STORE SCU: A-RELEASE-RP received")
            // completeWithResult already called after response
            context.close(promise: nil)
        case 0x07:
            logger.warning("C-STORE SCU: A-ABORT received from remote SCP")
            completeWithResult(false, status: .failedUnableToProcess)
            context.close(promise: nil)
        default:
            logger.warning("C-STORE SCU: unexpected PDU type 0x\(String(pduTypeByte, radix: 16))")
            completeWithResult(false, status: .failedUnableToProcess)
            context.close(promise: nil)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        logger.error("C-STORE SCU: connection error: \(error)")
        completeWithError(error)
        context.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        if state != .completed {
            completeWithResult(false, status: .failedUnableToProcess)
        }
        context.fireChannelInactive()
    }

    // MARK: - Protocol Exchange

    private func sendAssociateRequest(context: ChannelHandlerContext) {
        state = .awaitingAssociateAccept
        do {
            let presentationContext = try PresentationContext(
                id: 1,
                abstractSyntax: sopClassUID,
                transferSyntaxes: [
                    transferSyntaxUID,
                    explicitVRLittleEndianTransferSyntaxUID,
                    implicitVRLittleEndianTransferSyntaxUID
                ]
            )

            let requestPDU = AssociateRequestPDU(
                calledAETitle: try AETitle(calledAE),
                callingAETitle: try AETitle(callingAE),
                presentationContexts: [presentationContext],
                maxPDUSize: DICOMListenerConfiguration.defaultMaxPDUSize,
                implementationClassUID: DICOMListenerConfiguration.defaultImplementationClassUID,
                implementationVersionName: DICOMListenerConfiguration.defaultImplementationVersionName
            )

            let encoded = try requestPDU.encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer), promise: nil)
            logger.debug("C-STORE SCU: A-ASSOCIATE-RQ sent to '\(calledAE)'")
        } catch {
            logger.error("C-STORE SCU: failed to send A-ASSOCIATE-RQ: \(error)")
            completeWithError(error)
            context.close(promise: nil)
        }
    }

    private func handleAssociateAccept(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        let data = Data(buffer.readableBytesView)
        do {
            let decoded = try PDUDecoder.decode(from: data)
            guard let acceptPDU = decoded as? AssociateAcceptPDU else {
                completeWithResult(false, status: .failedUnableToProcess)
                context.close(promise: nil)
                return
            }

            // Verify presentation context 1 was accepted
            guard acceptPDU.acceptedContextIDs.contains(1) else {
                logger.warning("C-STORE SCU: SOP class '\(sopClassUID)' not accepted by remote SCP")
                sendAbort(context: context)
                completeWithResult(false, status: .failedUnableToProcess)
                return
            }

            if acceptPDU.maxPDUSize > 0 {
                negotiatedMaxPDUSize = min(acceptPDU.maxPDUSize, DICOMListenerConfiguration.defaultMaxPDUSize)
            }

            logger.debug("C-STORE SCU: association accepted by '\(calledAE)'")
            state = .awaitingCStoreResponse
            sendCStoreRequest(context: context)
        } catch {
            logger.error("C-STORE SCU: failed to decode A-ASSOCIATE-AC: \(error)")
            completeWithResult(false, status: .failedUnableToProcess)
            context.close(promise: nil)
        }
    }

    private func sendCStoreRequest(context: ChannelHandlerContext) {
        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: sopClassUID,
            affectedSOPInstanceUID: sopInstanceUID,
            presentationContextID: acceptedPresentationContextID
        )

        let fragmenter = MessageFragmenter(maxPDUSize: negotiatedMaxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: request.commandSet,
            dataSet: dataSet,
            presentationContextID: acceptedPresentationContextID
        )

        do {
            for pdu in pdus {
                let encoded = try pdu.encode()
                var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
                outBuffer.writeBytes(encoded)
                context.writeAndFlush(Self.wrapOutboundOut(outBuffer), promise: nil)
            }
            logger.debug("C-STORE SCU: C-STORE-RQ sent (\(dataSet.count) bytes)")
        } catch {
            logger.error("C-STORE SCU: failed to send C-STORE-RQ: \(error)")
            completeWithError(error)
            context.close(promise: nil)
        }
    }

    private func handleDataTransfer(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        let data = Data(buffer.readableBytesView)
        do {
            let decoded = try PDUDecoder.decode(from: data)
            guard let dataPDU = decoded as? DataTransferPDU else { return }

            if let message = try assembler.addPDVs(from: dataPDU),
               let response = message.asCStoreResponse() {
                let success = response.status.isSuccess || response.status.isWarning
                logger.debug("C-STORE SCU: C-STORE-RSP received, status=\(response.status)")
                state = .awaitingReleaseResponse
                completeWithResult(success, status: response.status)
                sendReleaseRequest(context: context)
            }
        } catch {
            logger.error("C-STORE SCU: error processing response: \(error)")
            completeWithResult(false, status: .failedUnableToProcess)
            context.close(promise: nil)
        }
    }

    private func sendReleaseRequest(context: ChannelHandlerContext) {
        do {
            let encoded = try ReleaseRequestPDU().encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer), promise: nil)
        } catch {
            logger.error("C-STORE SCU: failed to send A-RELEASE-RQ: \(error)")
            context.close(promise: nil)
        }
    }

    private func sendAbort(context: ChannelHandlerContext) {
        do {
            let encoded = try AbortPDU(source: .serviceUser, reason: 0).encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer)).whenComplete { _ in
                context.close(promise: nil)
            }
        } catch {
            context.close(promise: nil)
        }
    }

    // MARK: - Result Completion

    private func completeWithResult(_ success: Bool, status: DIMSEStatus) {
        guard state != .completed else { return }
        state = .completed
        resultContinuation?.resume(returning: (success, status))
        resultContinuation = nil
    }

    private func completeWithError(_ error: any Error) {
        guard state != .completed else { return }
        state = .completed
        resultContinuation?.resume(throwing: error)
        resultContinuation = nil
    }
}

// MARK: - StorageSCU Errors

/// Errors specific to the Storage SCU.
public enum StorageSCUError: Error, Sendable {
    /// The remote SCP sent an invalid or unexpected response.
    case invalidResponse
}
