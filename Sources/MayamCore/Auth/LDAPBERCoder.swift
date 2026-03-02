// SPDX-License-Identifier: (see LICENSE)
// Mayam — LDAP BER (Basic Encoding Rules) Encoder / Decoder

import Foundation

// MARK: - BERTag

/// ASN.1 / BER tag constants used in LDAP message encoding.
public enum BERTag {

    // MARK: - Universal Tags

    /// ASN.1 BOOLEAN (0x01).
    public static let boolean: UInt8 = 0x01
    /// ASN.1 INTEGER (0x02).
    public static let integer: UInt8 = 0x02
    /// ASN.1 OCTET STRING (0x04).
    public static let octetString: UInt8 = 0x04
    /// ASN.1 ENUMERATED (0x0A).
    public static let enumerated: UInt8 = 0x0A
    /// ASN.1 SEQUENCE (constructed, 0x30).
    public static let sequence: UInt8 = 0x30
    /// ASN.1 SET (constructed, 0x31).
    public static let set: UInt8 = 0x31

    // MARK: - Context-Specific Tag Helpers

    /// Returns a context-specific primitive tag for the given context number.
    ///
    /// - Parameter context: Context number (0–30).
    /// - Returns: The tag byte (0x80 | context).
    public static func contextPrimitive(_ context: UInt8) -> UInt8 {
        0x80 | context
    }

    /// Returns a context-specific constructed tag for the given context number.
    ///
    /// - Parameter context: Context number (0–30).
    /// - Returns: The tag byte (0xA0 | context).
    public static func contextConstructed(_ context: UInt8) -> UInt8 {
        0xA0 | context
    }

    /// Returns an application-class constructed tag for the given application number.
    ///
    /// - Parameter app: Application number (0–30).
    /// - Returns: The tag byte (0x60 | app).
    public static func application(_ app: UInt8) -> UInt8 {
        0x60 | app
    }
}

// MARK: - BEREncoder

/// Encodes Swift values into BER (Basic Encoding Rules) TLV byte sequences
/// as required by the LDAP protocol (RFC 4511).
public struct BEREncoder {

    // MARK: - Public Methods

    /// Encodes a boolean value.
    ///
    /// - Parameter value: The boolean to encode.
    /// - Returns: BER-encoded bytes.
    public static func encodeBoolean(_ value: Bool) -> [UInt8] {
        [BERTag.boolean, 0x01, value ? 0xFF : 0x00]
    }

    /// Encodes an integer value.
    ///
    /// - Parameter value: The integer to encode.
    /// - Returns: BER-encoded bytes.
    public static func encodeInteger(_ value: Int) -> [UInt8] {
        let valueBytes = minimalSignedBytes(value)
        return [BERTag.integer] + encodeLength(valueBytes.count) + valueBytes
    }

    /// Encodes an ENUMERATED value.
    ///
    /// - Parameter value: The enumerated integer to encode.
    /// - Returns: BER-encoded bytes.
    public static func encodeEnumerated(_ value: Int) -> [UInt8] {
        let valueBytes = minimalSignedBytes(value)
        return [BERTag.enumerated] + encodeLength(valueBytes.count) + valueBytes
    }

    /// Encodes a byte sequence as an OCTET STRING.
    ///
    /// - Parameter bytes: The bytes to encode.
    /// - Returns: BER-encoded bytes.
    public static func encodeOctetString(_ bytes: [UInt8]) -> [UInt8] {
        [BERTag.octetString] + encodeLength(bytes.count) + bytes
    }

    /// Encodes a UTF-8 string as an OCTET STRING.
    ///
    /// - Parameter string: The string to encode.
    /// - Returns: BER-encoded bytes.
    public static func encodeOctetString(_ string: String) -> [UInt8] {
        encodeOctetString(Array(string.utf8))
    }

    /// Wraps pre-encoded bytes in a SEQUENCE TLV envelope.
    ///
    /// - Parameter contents: The already-encoded content bytes.
    /// - Returns: BER-encoded SEQUENCE bytes.
    public static func encodeSequence(_ contents: [UInt8]) -> [UInt8] {
        [BERTag.sequence] + encodeLength(contents.count) + contents
    }

    /// Encodes a TLV with an arbitrary tag byte.
    ///
    /// - Parameters:
    ///   - tag: The tag byte.
    ///   - contents: The value bytes (already encoded if constructed).
    /// - Returns: BER TLV bytes.
    public static func encodeTagged(tag: UInt8, contents: [UInt8]) -> [UInt8] {
        [tag] + encodeLength(contents.count) + contents
    }

    // MARK: - Internal Helpers

    /// Encodes a length value in BER definite-length form.
    ///
    /// - Parameter length: The number of value bytes.
    /// - Returns: BER length bytes.
    static func encodeLength(_ length: Int) -> [UInt8] {
        if length < 0x80 {
            return [UInt8(length)]
        }
        var remaining = length
        var lengthBytes: [UInt8] = []
        while remaining > 0 {
            lengthBytes.insert(UInt8(remaining & 0xFF), at: 0)
            remaining >>= 8
        }
        return [0x80 | UInt8(lengthBytes.count)] + lengthBytes
    }

    /// Returns the minimal big-endian two's-complement signed byte representation
    /// of `value`.
    ///
    /// - Parameter value: The integer to encode.
    /// - Returns: Minimal signed byte array.
    static func minimalSignedBytes(_ value: Int) -> [UInt8] {
        if value == 0 { return [0x00] }
        var v = value
        var bytes: [UInt8] = []
        while v != 0 && v != -1 {
            bytes.insert(UInt8(bitPattern: Int8(truncatingIfNeeded: v)), at: 0)
            v >>= 8
        }
        if bytes.isEmpty {
            // value was already at the loop termination value (-1 or 0).
            bytes.append(value < 0 ? 0xFF : 0x00)
        } else {
            // Ensure correct sign extension byte is present when needed.
            if value > 0 && (bytes.first ?? 0) & 0x80 != 0 {
                bytes.insert(0x00, at: 0)
            } else if value < 0 && (bytes.first ?? 0xFF) & 0x80 == 0 {
                bytes.insert(0xFF, at: 0)
            }
        }
        return bytes
    }
}

// MARK: - BERDecoder

/// Decodes BER (Basic Encoding Rules) TLV byte sequences as produced by LDAP
/// servers (RFC 4511).
public struct BERDecoder {

    // MARK: - Errors

    /// Errors that may occur during BER decoding.
    public enum Error: Swift.Error, Sendable {
        /// The input buffer is truncated or malformed.
        case truncated
        /// An unexpected tag was encountered.
        case unexpectedTag(expected: UInt8, found: UInt8)
        /// The length encoding is invalid.
        case invalidLength
        /// An integer value overflows the Swift `Int` type.
        case overflow
    }

    // MARK: - Public Methods

    /// Decodes a single BER TLV element from the given byte slice.
    ///
    /// - Parameters:
    ///   - bytes: The input bytes.
    ///   - offset: Start position within `bytes` (updated on return to point
    ///     past the decoded element).
    /// - Returns: A tuple of `(tag, value)` where `value` is the raw content bytes.
    /// - Throws: ``BERDecoder/Error`` if the input is malformed.
    public static func readTLV(from bytes: [UInt8], offset: inout Int) throws -> (tag: UInt8, value: [UInt8]) {
        guard offset < bytes.count else { throw Error.truncated }
        let tag = bytes[offset]
        offset += 1
        let length = try readLength(from: bytes, offset: &offset)
        guard offset + length <= bytes.count else { throw Error.truncated }
        let value = Array(bytes[offset ..< offset + length])
        offset += length
        return (tag, value)
    }

    /// Decodes an INTEGER from the given bytes.
    ///
    /// - Parameters:
    ///   - bytes: The input bytes starting at the tag byte.
    ///   - offset: Current offset (updated on return).
    /// - Returns: The decoded integer value.
    /// - Throws: ``BERDecoder/Error`` if the tag is wrong or the input is malformed.
    public static func readInteger(from bytes: [UInt8], offset: inout Int) throws -> Int {
        let (tag, value) = try readTLV(from: bytes, offset: &offset)
        guard tag == BERTag.integer else { throw Error.unexpectedTag(expected: BERTag.integer, found: tag) }
        return try decodeSignedInt(value)
    }

    /// Decodes an ENUMERATED from the given bytes.
    ///
    /// - Parameters:
    ///   - bytes: The input bytes starting at the tag byte.
    ///   - offset: Current offset (updated on return).
    /// - Returns: The decoded enumerated integer value.
    /// - Throws: ``BERDecoder/Error`` if the tag is wrong or the input is malformed.
    public static func readEnumerated(from bytes: [UInt8], offset: inout Int) throws -> Int {
        let (tag, value) = try readTLV(from: bytes, offset: &offset)
        guard tag == BERTag.enumerated else { throw Error.unexpectedTag(expected: BERTag.enumerated, found: tag) }
        return try decodeSignedInt(value)
    }

    /// Decodes an OCTET STRING from the given bytes and interprets it as UTF-8.
    ///
    /// - Parameters:
    ///   - bytes: The input bytes starting at the tag byte.
    ///   - offset: Current offset (updated on return).
    /// - Returns: The decoded string.
    /// - Throws: ``BERDecoder/Error`` if the tag is wrong or the input is malformed.
    public static func readOctetString(from bytes: [UInt8], offset: inout Int) throws -> String {
        let rawBytes = try readOctetStringBytes(from: bytes, offset: &offset)
        return String(bytes: rawBytes, encoding: .utf8) ?? ""
    }

    /// Decodes an OCTET STRING from the given bytes and returns raw bytes.
    ///
    /// - Parameters:
    ///   - bytes: The input bytes starting at the tag byte.
    ///   - offset: Current offset (updated on return).
    /// - Returns: The raw content bytes.
    /// - Throws: ``BERDecoder/Error`` if the tag is wrong or the input is malformed.
    public static func readOctetStringBytes(from bytes: [UInt8], offset: inout Int) throws -> [UInt8] {
        let (tag, value) = try readTLV(from: bytes, offset: &offset)
        guard tag == BERTag.octetString else { throw Error.unexpectedTag(expected: BERTag.octetString, found: tag) }
        return value
    }

    /// Decodes a SEQUENCE and returns its raw content bytes.
    ///
    /// - Parameters:
    ///   - bytes: The input bytes starting at the tag byte.
    ///   - offset: Current offset (updated on return).
    /// - Returns: The raw contents of the sequence.
    /// - Throws: ``BERDecoder/Error`` if the tag is wrong or the input is malformed.
    public static func readSequence(from bytes: [UInt8], offset: inout Int) throws -> [UInt8] {
        let (tag, value) = try readTLV(from: bytes, offset: &offset)
        guard tag == BERTag.sequence else { throw Error.unexpectedTag(expected: BERTag.sequence, found: tag) }
        return value
    }

    // MARK: - Private Helpers

    /// Reads and decodes a BER definite-length encoding.
    private static func readLength(from bytes: [UInt8], offset: inout Int) throws -> Int {
        guard offset < bytes.count else { throw Error.truncated }
        let first = bytes[offset]
        offset += 1
        if first & 0x80 == 0 {
            return Int(first)
        }
        let lengthBytes = Int(first & 0x7F)
        guard lengthBytes > 0 && lengthBytes <= 4 else { throw Error.invalidLength }
        guard offset + lengthBytes <= bytes.count else { throw Error.truncated }
        var length = 0
        for i in 0 ..< lengthBytes {
            length = (length << 8) | Int(bytes[offset + i])
        }
        offset += lengthBytes
        return length
    }

    /// Converts a minimal signed-byte array to a Swift `Int`.
    private static func decodeSignedInt(_ bytes: [UInt8]) throws -> Int {
        guard !bytes.isEmpty else { return 0 }
        guard bytes.count <= MemoryLayout<Int>.size else { throw Error.overflow }
        var result: Int = Int8(bitPattern: bytes[0]) < 0 ? -1 : 0
        for byte in bytes {
            result = (result << 8) | Int(byte)
        }
        return result
    }
}
