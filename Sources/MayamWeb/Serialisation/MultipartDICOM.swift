// SPDX-License-Identifier: (see LICENSE)
// Mayam — Multipart DICOM Parser and Serialiser

import Foundation

// MARK: - MultipartPart

/// A single part of a multipart/related message.
public struct MultipartPart: Sendable, Equatable {

    /// The headers for this part (e.g. Content-Type, Content-Location).
    public let headers: [String: String]

    /// The body data of this part.
    public let body: Data

    /// Creates a new multipart part.
    ///
    /// - Parameters:
    ///   - headers: Part-level HTTP headers.
    ///   - body: The part body data.
    public init(headers: [String: String], body: Data) {
        self.headers = headers
        self.body = body
    }

    /// The `Content-Type` header value for this part, or `nil` if absent.
    public var contentType: String? { headers["Content-Type"] }

    /// The `Content-Location` header value for this part, or `nil` if absent.
    public var contentLocation: String? { headers["Content-Location"] }
}

// MARK: - MultipartDICOM

/// Utilities for parsing and serialising `multipart/related` DICOM messages.
///
/// DICOMweb services use `multipart/related` as the transfer encoding for
/// WADO-RS responses and STOW-RS request bodies. Each part contains either a
/// raw DICOM object (`application/dicom`) or DICOM metadata
/// (`application/dicom+json` / `application/dicom+xml`).
///
/// Reference: DICOM PS3.18 Section 6.5 — Multipart MIME
public enum MultipartDICOM {

    // MARK: - Parsing

    /// Parses a `multipart/related` body into its constituent parts.
    ///
    /// - Parameters:
    ///   - data: The raw multipart body bytes.
    ///   - boundary: The boundary string extracted from the `Content-Type` header.
    /// - Returns: An array of ``MultipartPart`` values.
    /// - Throws: ``DICOMwebError/multipartParseFailure`` if parsing fails.
    public static func parse(data: Data, boundary: String) throws -> [MultipartPart] {
        let boundaryData = "--\(boundary)".data(using: .utf8)!
        let closingBoundaryData = "--\(boundary)--".data(using: .utf8)!
        let crlfData = Data([0x0D, 0x0A])

        var parts: [MultipartPart] = []
        var offset = 0

        // Skip preamble up to first boundary
        guard let firstBoundaryRange = data.range(of: boundaryData, in: offset..<data.count) else {
            throw DICOMwebError.multipartParseFailure(reason: "No boundary found in body")
        }
        offset = firstBoundaryRange.upperBound

        while offset < data.count {
            // Check for closing boundary
            if let closingRange = data.range(of: closingBoundaryData, in: max(0, offset - 2)..<data.count),
               closingRange.lowerBound <= offset + 4 {
                break
            }

            // Skip CRLF after boundary
            if data.range(of: crlfData, in: offset..<min(offset + 2, data.count)) != nil {
                offset += 2
            }

            // Find next boundary (marks the end of this part)
            guard let nextBoundaryRange = data.range(of: boundaryData, in: offset..<data.count) else {
                break
            }

            let partData = data[offset..<nextBoundaryRange.lowerBound]
            if let part = parsePart(data: Data(partData)) {
                parts.append(part)
            }

            offset = nextBoundaryRange.upperBound
        }

        return parts
    }

    /// Parses a single multipart part including its headers and body.
    private static func parsePart(data: Data) -> MultipartPart? {
        let crlfcrlf = Data([0x0D, 0x0A, 0x0D, 0x0A])
        let crlf = Data([0x0D, 0x0A])

        guard let headerEndRange = data.range(of: crlfcrlf) else { return nil }

        let headerData = data[data.startIndex..<headerEndRange.lowerBound]
        let bodyData: Data

        // Strip trailing CRLF from body
        let rawBody = data[headerEndRange.upperBound...]
        if rawBody.hasSuffix(crlf) {
            bodyData = Data(rawBody.dropLast(2))
        } else {
            bodyData = Data(rawBody)
        }

        // Parse headers
        guard let headerString = String(data: headerData, encoding: .utf8) else { return nil }
        var headers: [String: String] = [:]
        for line in headerString.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        return MultipartPart(headers: headers, body: bodyData)
    }

    // MARK: - Serialisation

    /// Serialises an array of parts into a `multipart/related` body.
    ///
    /// - Parameters:
    ///   - parts: The parts to serialise.
    ///   - boundary: The boundary string to use.
    /// - Returns: The serialised multipart body as `Data`.
    public static func serialise(parts: [MultipartPart], boundary: String) -> Data {
        var output = Data()
        let crlf = Data([0x0D, 0x0A])

        for part in parts {
            output.append("--\(boundary)".data(using: .utf8)!)
            output.append(crlf)

            for (key, value) in part.headers.sorted(by: { $0.key < $1.key }) {
                output.append("\(key): \(value)".data(using: .utf8)!)
                output.append(crlf)
            }
            output.append(crlf)
            output.append(part.body)
            output.append(crlf)
        }

        output.append("--\(boundary)--".data(using: .utf8)!)
        output.append(crlf)
        return output
    }

    // MARK: - Helpers

    /// Extracts the `boundary` parameter from a `Content-Type` header value.
    ///
    /// For example, given `"multipart/related; type=\"application/dicom\"; boundary=myboundary"`,
    /// this returns `"myboundary"`.
    ///
    /// - Parameter contentType: The full `Content-Type` header value.
    /// - Returns: The boundary string, or `nil` if not found.
    public static func extractBoundary(from contentType: String) -> String? {
        let components = contentType.components(separatedBy: ";")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("boundary=") {
                let value = String(trimmed.dropFirst("boundary=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// Generates a unique MIME boundary string suitable for use in
    /// `multipart/related` messages.
    ///
    /// - Returns: A boundary string prefixed with `"mayam_boundary_"`.
    public static func generateBoundary() -> String {
        "mayam_boundary_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }
}

// MARK: - Data Extension

private extension Data {
    func hasSuffix(_ suffixData: Data) -> Bool {
        guard count >= suffixData.count else { return false }
        return suffix(suffixData.count) == suffixData
    }
}
