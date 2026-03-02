// SPDX-License-Identifier: (see LICENSE)
// Mayam — PDU Frame Decoder (NIO Channel Handler)

import Foundation
import NIOCore

/// A Swift NIO `ByteToMessageDecoder` that frames incoming TCP data into
/// complete DICOM PDUs (Protocol Data Units).
///
/// Each PDU consists of a 1-byte type, 1 reserved byte, and a 4-byte big-endian
/// length field, followed by `length` bytes of payload.
///
/// Reference: DICOM PS3.8 Section 9.3
public struct PDUFrameDecoder: ByteToMessageDecoder, Sendable {
    public typealias InboundOut = ByteBuffer

    // MARK: - Constants

    /// Size of the PDU header: 1 (type) + 1 (reserved) + 4 (length).
    private static let headerSize = 6

    // MARK: - Initialiser

    public init() {}

    // MARK: - ByteToMessageDecoder

    public mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard buffer.readableBytes >= Self.headerSize else {
            return .needMoreData
        }

        // Peek at the length field (bytes 2–5, big-endian UInt32).
        let lengthOffset = buffer.readerIndex + 2
        let pduLength = buffer.getInteger(at: lengthOffset, as: UInt32.self)!

        let totalLength = Self.headerSize + Int(pduLength)
        guard buffer.readableBytes >= totalLength else {
            return .needMoreData
        }

        // Read the entire PDU as a slice.
        let pduBuffer = buffer.readSlice(length: totalLength)!
        context.fireChannelRead(Self.wrapInboundOut(pduBuffer))
        return .continue
    }
}
