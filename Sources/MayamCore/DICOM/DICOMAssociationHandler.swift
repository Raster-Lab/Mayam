// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOM Association Handler

import Foundation
import NIOCore
import DICOMNetwork
import Logging

/// Manages a single inbound DICOM association over a Swift NIO `Channel`.
///
/// This handler processes the DICOM Upper Layer Protocol:
/// 1. Receives and validates A-ASSOCIATE-RQ PDUs.
/// 2. Negotiates presentation contexts and replies with A-ASSOCIATE-AC or
///    A-ASSOCIATE-RJ.
/// 3. During data transfer, assembles DIMSE messages from P-DATA-TF PDUs and
///    dispatches them to the appropriate ``SCPService`` via the ``SCPDispatcher``.
/// 4. Handles A-RELEASE-RQ/RP and A-ABORT.
///
/// Reference: DICOM PS3.8 Section 9
///
/// > Concurrency: This handler is marked `@unchecked Sendable` because all
/// > mutable state is accessed exclusively on the NIO `EventLoop` thread
/// > associated with the channel, as guaranteed by the NIO threading model.
public final class DICOMAssociationHandler: ChannelInboundHandler, @unchecked Sendable {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer

    // MARK: - Nested Types

    /// The current state of the association.
    private enum State {
        case awaitingAssociateRequest
        case established
        case releasing
        case closed
    }

    // MARK: - Stored Properties

    /// The server configuration governing this association.
    private let configuration: DICOMListenerConfiguration

    /// The SCP dispatcher for routing DIMSE commands.
    private let dispatcher: SCPDispatcher

    /// Logger for this association.
    private let logger: Logger

    /// The current state of the association.
    private var state: State = .awaitingAssociateRequest

    /// Message assembler for incoming P-DATA-TF PDUs.
    private let assembler = MessageAssembler()

    /// Mapping of accepted presentation context IDs to their abstract and transfer syntaxes.
    private var acceptedContexts: [UInt8: (abstractSyntax: String, transferSyntax: String)] = [:]

    /// Negotiated maximum PDU size for outgoing PDUs.
    private var negotiatedMaxPDUSize: UInt32

    /// The remote AE Title once negotiated.
    private var remoteAETitle: String = ""

    // MARK: - Initialiser

    /// Creates a new association handler.
    ///
    /// - Parameters:
    ///   - configuration: The listener configuration.
    ///   - dispatcher: The SCP dispatcher for routing DIMSE commands.
    ///   - logger: Logger instance for association events.
    public init(
        configuration: DICOMListenerConfiguration,
        dispatcher: SCPDispatcher,
        logger: Logger
    ) {
        self.configuration = configuration
        self.dispatcher = dispatcher
        self.logger = logger
        self.negotiatedMaxPDUSize = configuration.maxPDUSize
    }

    // MARK: - ChannelInboundHandler

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = Self.unwrapInboundIn(data)

        guard let pduTypeByte = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
            logger.error("Received empty PDU data")
            context.close(promise: nil)
            return
        }

        switch pduTypeByte {
        case 0x01: // A-ASSOCIATE-RQ
            handleAssociateRequest(context: context, buffer: &buffer)

        case 0x04: // P-DATA-TF
            handleDataTransfer(context: context, buffer: &buffer)

        case 0x05: // A-RELEASE-RQ
            handleReleaseRequest(context: context)

        case 0x07: // A-ABORT
            handleAbort(context: context)

        default:
            logger.warning("Unexpected PDU type: 0x\(String(pduTypeByte, radix: 16))")
            sendAbort(context: context, source: .serviceProvider, reason: 2)
        }
    }

    public func channelInactive(context: ChannelHandlerContext) {
        state = .closed
        logger.debug("Association connection closed")
        context.fireChannelInactive()
    }

    public func errorCaught(context: ChannelHandlerContext, error: any Error) {
        logger.error("Association error: \(error)")
        context.close(promise: nil)
    }

    // MARK: - A-ASSOCIATE-RQ Handling

    private func handleAssociateRequest(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        guard state == .awaitingAssociateRequest else {
            logger.warning("Received A-ASSOCIATE-RQ in unexpected state")
            sendAbort(context: context, source: .serviceProvider, reason: 2)
            return
        }

        // Parse the request PDU
        let data = Data(buffer.readableBytesView)

        let requestPDU: AssociateRequestPDU
        do {
            let decoded = try PDUDecoder.decode(from: data)
            guard let req = decoded as? AssociateRequestPDU else {
                logger.error("Failed to decode A-ASSOCIATE-RQ: unexpected PDU type")
                sendAbort(context: context, source: .serviceProvider, reason: 2)
                return
            }
            requestPDU = req
        } catch {
            logger.error("Failed to decode A-ASSOCIATE-RQ: \(error)")
            sendAbort(context: context, source: .serviceProvider, reason: 2)
            return
        }

        remoteAETitle = requestPDU.callingAETitle.value
        let calledAE = requestPDU.calledAETitle.value

        logger.info("A-ASSOCIATE-RQ from '\(remoteAETitle)' to '\(calledAE)'")

        // Validate called AE Title
        if calledAE != configuration.aeTitle {
            logger.warning("Called AE Title '\(calledAE)' does not match configured '\(configuration.aeTitle)'")
            sendAssociateReject(context: context, result: .rejectedPermanent, source: .serviceUser, reason: 7)
            return
        }

        // Negotiate presentation contexts
        let proposedContexts = requestPDU.presentationContexts
        var responseContexts: [AcceptedPresentationContext] = []

        for proposed in proposedContexts {
            let abstractSyntax = proposed.abstractSyntax

            // Check if we support this SOP Class
            guard configuration.acceptedSOPClasses.contains(abstractSyntax) else {
                responseContexts.append(AcceptedPresentationContext(
                    id: proposed.id,
                    result: .abstractSyntaxNotSupported,
                    transferSyntax: proposed.transferSyntaxes.first ?? implicitVRLittleEndianTransferSyntaxUID
                ))
                continue
            }

            // Find a mutually supported transfer syntax
            let commonTS = proposed.transferSyntaxes.first { ts in
                configuration.acceptedTransferSyntaxes.contains(ts)
            }

            if let acceptedTS = commonTS {
                responseContexts.append(AcceptedPresentationContext(
                    id: proposed.id,
                    result: .acceptance,
                    transferSyntax: acceptedTS
                ))
                acceptedContexts[proposed.id] = (abstractSyntax: abstractSyntax, transferSyntax: acceptedTS)
            } else {
                responseContexts.append(AcceptedPresentationContext(
                    id: proposed.id,
                    result: .transferSyntaxesNotSupported,
                    transferSyntax: proposed.transferSyntaxes.first ?? implicitVRLittleEndianTransferSyntaxUID
                ))
            }
        }

        // Determine negotiated max PDU size
        if requestPDU.maxPDUSize > 0 {
            negotiatedMaxPDUSize = min(requestPDU.maxPDUSize, configuration.maxPDUSize)
        }

        // Build and send A-ASSOCIATE-AC
        do {
            let calledAETitle = try AETitle(calledAE)
            let callingAETitle = try AETitle(remoteAETitle)

            let acceptPDU = AssociateAcceptPDU(
                calledAETitle: calledAETitle,
                callingAETitle: callingAETitle,
                presentationContexts: responseContexts,
                maxPDUSize: configuration.maxPDUSize,
                implementationClassUID: configuration.implementationClassUID,
                implementationVersionName: configuration.implementationVersionName
            )

            let encoded = try acceptPDU.encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer), promise: nil)
            state = .established
            logger.info("Association established with '\(remoteAETitle)'")
        } catch {
            logger.error("Failed to encode A-ASSOCIATE-AC: \(error)")
            sendAbort(context: context, source: .serviceProvider, reason: 2)
        }
    }

    // MARK: - P-DATA-TF Handling

    private func handleDataTransfer(context: ChannelHandlerContext, buffer: inout ByteBuffer) {
        guard state == .established else {
            logger.warning("Received P-DATA-TF in unexpected state")
            sendAbort(context: context, source: .serviceProvider, reason: 2)
            return
        }

        let data = Data(buffer.readableBytesView)

        do {
            let decoded = try PDUDecoder.decode(from: data)
            guard let dataPDU = decoded as? DataTransferPDU else {
                logger.error("Failed to decode P-DATA-TF: unexpected PDU type")
                return
            }

            if let message = try assembler.addPDVs(from: dataPDU) {
                try processMessage(message, context: context)
            }
        } catch {
            logger.error("Error processing P-DATA-TF: \(error)")
        }
    }

    // MARK: - DIMSE Message Processing

    private func processMessage(_ message: AssembledMessage, context: ChannelHandlerContext) throws {
        guard let command = message.command else {
            logger.warning("Received message without command field")
            return
        }

        let contextID = message.presentationContextID
        let transferSyntax = acceptedContexts[contextID]?.transferSyntax
            ?? implicitVRLittleEndianTransferSyntaxUID

        switch command {
        case .cEchoRequest:
            if let request = message.asCEchoRequest() {
                let response = dispatcher.handleCEcho(request: request, presentationContextID: contextID)
                try sendDIMSEResponse(response, presentationContextID: contextID, context: context)
            }

        case .cStoreRequest:
            if let request = message.asCStoreRequest() {
                let dataSet = message.dataSet ?? Data()
                let ts = transferSyntax
                let maxPDU = negotiatedMaxPDUSize
                // Capture the channel (Sendable) rather than the context (non-Sendable)
                let channel = context.channel
                Task {
                    let response = await self.dispatcher.handleCStore(
                        request: request,
                        dataSet: dataSet,
                        transferSyntax: ts,
                        presentationContextID: contextID
                    )
                    channel.eventLoop.execute {
                        let fragmenter = MessageFragmenter(maxPDUSize: maxPDU)
                        let pdus = fragmenter.fragmentMessage(
                            commandSet: response.commandSet,
                            dataSet: nil,
                            presentationContextID: contextID
                        )
                        for pdu in pdus {
                            if let encoded = try? pdu.encode() {
                                var outBuffer = channel.allocator.buffer(capacity: encoded.count)
                                outBuffer.writeBytes(encoded)
                                channel.writeAndFlush(outBuffer, promise: nil)
                            }
                        }
                    }
                }
            }

        default:
            logger.warning("Unsupported DIMSE command: \(command)")
        }
    }

    // MARK: - DIMSE Response Sending

    private func sendDIMSEResponse(
        _ response: any DIMSEResponse,
        presentationContextID: UInt8,
        context: ChannelHandlerContext
    ) throws {
        let fragmenter = MessageFragmenter(maxPDUSize: negotiatedMaxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: response.commandSet,
            dataSet: nil,
            presentationContextID: presentationContextID
        )

        for pdu in pdus {
            let encoded = try pdu.encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer), promise: nil)
        }
    }

    // MARK: - A-RELEASE Handling

    private func handleReleaseRequest(context: ChannelHandlerContext) {
        logger.info("A-RELEASE-RQ received from '\(remoteAETitle)'")
        state = .releasing

        do {
            let releasePDU = ReleaseResponsePDU()
            let encoded = try releasePDU.encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer)).whenComplete { [weak self] _ in
                self?.state = .closed
                context.close(promise: nil)
            }
        } catch {
            logger.error("Failed to encode A-RELEASE-RP: \(error)")
            context.close(promise: nil)
        }
    }

    // MARK: - A-ABORT Handling

    private func handleAbort(context: ChannelHandlerContext) {
        logger.info("A-ABORT received from '\(remoteAETitle)'")
        state = .closed
        context.close(promise: nil)
    }

    // MARK: - Abort Sending

    private func sendAbort(context: ChannelHandlerContext, source: AbortSource, reason: UInt8) {
        do {
            let abortPDU = AbortPDU(source: source, reason: reason)
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

    // MARK: - Associate Reject Sending

    private func sendAssociateReject(context: ChannelHandlerContext, result: AssociateRejectResult, source: AssociateRejectSource, reason: UInt8) {
        let rejectPDU = AssociateRejectPDU(result: result, source: source, reason: reason)
        do {
            let encoded = try rejectPDU.encode()
            var outBuffer = context.channel.allocator.buffer(capacity: encoded.count)
            outBuffer.writeBytes(encoded)
            context.writeAndFlush(Self.wrapOutboundOut(outBuffer)).whenComplete { _ in
                context.close(promise: nil)
            }
        } catch {
            logger.error("Failed to encode A-ASSOCIATE-RJ: \(error)")
            context.close(promise: nil)
        }
    }
}
