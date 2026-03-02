// SPDX-License-Identifier: (see LICENSE)
// Mayam — STOW-RS Handler

import Foundation
import MayamCore

// MARK: - STOWRSResult

/// Describes the outcome of a STOW-RS store operation.
public struct STOWRSResult: Sendable, Equatable {

    /// The SOP Instance UID that was stored (or failed).
    public let sopInstanceUID: String

    /// The SOP Class UID of the stored instance.
    public let sopClassUID: String

    /// The HTTP status code for this instance (200 success, 409 conflict, etc.).
    public let statusCode: UInt

    /// A description of any failure reason, or `nil` on success.
    public let failureReason: String?

    /// Whether this instance was stored successfully.
    public var isSuccess: Bool { statusCode == 200 }

    public init(
        sopInstanceUID: String,
        sopClassUID: String,
        statusCode: UInt = 200,
        failureReason: String? = nil
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.statusCode = statusCode
        self.failureReason = failureReason
    }
}

// MARK: - STOWRSResponse

/// The full response body for a STOW-RS store operation.
public struct STOWRSResponse: Sendable {
    /// Results for each instance submitted.
    public let results: [STOWRSResult]

    /// The overall HTTP status code (200 if all succeeded, 202 if partially successful).
    public var httpStatusCode: UInt {
        if results.allSatisfy(\.isSuccess) { return 200 }
        if results.contains(where: \.isSuccess) { return 202 }
        return 409
    }

    public init(results: [STOWRSResult]) {
        self.results = results
    }

    /// JSON-encodes this response in the format required by DICOM PS3.18.
    ///
    /// The response contains a `ReferencedSOPSequence` for successfully stored
    /// instances and a `FailedSOPSequence` for failed instances.
    ///
    /// - Returns: JSON-encoded response body as `Data`.
    /// - Throws: If JSON encoding fails.
    public func encode() throws -> Data {
        var responseDict: [String: [[String: String]]] = [:]

        let succeeded = results.filter(\.isSuccess)
        let failed = results.filter { !$0.isSuccess }

        if !succeeded.isEmpty {
            responseDict["00081199"] = succeeded.map { r in
                ["00081150": r.sopClassUID, "00081155": r.sopInstanceUID]
            }
        }

        if !failed.isEmpty {
            responseDict["00081198"] = failed.map { r in
                var entry = ["00081150": r.sopClassUID, "00081155": r.sopInstanceUID]
                if let reason = r.failureReason {
                    entry["00081197"] = reason
                }
                return entry
            }
        }

        return try JSONSerialization.data(withJSONObject: responseDict)
    }
}

// MARK: - STOWRSHandler

/// Implements the STOW-RS (Store Over the Web by RESTful Services) service.
///
/// STOW-RS allows clients to store DICOM instances via HTTP POST with a
/// `multipart/related` body containing one or more DICOM datasets.
///
/// ## Supported Endpoints
///
/// - `POST {base}/studies` — store instances without constraining to a study.
/// - `POST {base}/studies/{studyUID}` — store instances, validating that
///   each instance belongs to the given study.
///
/// Reference: DICOM PS3.18 Section 10.5 — STOW-RS
public struct STOWRSHandler: Sendable {

    // MARK: - Stored Properties

    /// The storage actor for persisting DICOM objects to the archive.
    private let storageActor: StorageActor

    /// The metadata store for registering newly stored instances.
    private let metadataStore: DICOMMetadataStore

    // MARK: - Initialiser

    /// Creates a new STOW-RS handler.
    ///
    /// - Parameters:
    ///   - storageActor: The archive storage actor.
    ///   - metadataStore: The metadata store to update after storage.
    public init(storageActor: StorageActor, metadataStore: DICOMMetadataStore) {
        self.storageActor = storageActor
        self.metadataStore = metadataStore
    }

    // MARK: - Store Instances

    /// Processes a STOW-RS request body and stores the contained DICOM instances.
    ///
    /// Parses the `multipart/related` body, extracts each DICOM part, stores
    /// it via the ``StorageActor``, and registers it in the metadata store.
    ///
    /// - Parameters:
    ///   - body: The raw HTTP request body.
    ///   - contentType: The `Content-Type` header value (must include `boundary=`).
    ///   - expectedStudyUID: If non-nil, instances not belonging to this study
    ///     are rejected with a `409 Conflict` result.
    /// - Returns: A ``STOWRSResponse`` summarising the outcome for each instance.
    /// - Throws: ``DICOMwebError`` if the body cannot be parsed.
    public func storeInstances(
        body: Data,
        contentType: String,
        expectedStudyUID: String? = nil
    ) async throws -> STOWRSResponse {
        guard let boundary = MultipartDICOM.extractBoundary(from: contentType) else {
            throw DICOMwebError.badRequest(reason: "Missing boundary in Content-Type")
        }

        guard !body.isEmpty else {
            throw DICOMwebError.badRequest(reason: "Request body is empty")
        }

        let parts = try MultipartDICOM.parse(data: body, boundary: boundary)

        if parts.isEmpty {
            throw DICOMwebError.badRequest(reason: "No DICOM parts found in multipart body")
        }

        var results: [STOWRSResult] = []

        for part in parts {
            let partContentType = part.contentType ?? ""
            guard partContentType.contains("application/dicom") else {
                // Skip non-DICOM parts (e.g. metadata parts)
                continue
            }

            let result = await storePart(part: part, expectedStudyUID: expectedStudyUID)
            results.append(result)
        }

        return STOWRSResponse(results: results)
    }

    // MARK: - Private Helpers

    /// Stores a single multipart part as a DICOM instance.
    private func storePart(
        part: MultipartPart,
        expectedStudyUID: String?
    ) async -> STOWRSResult {
        // Extract minimal metadata from the DICOM dataset.
        // A full implementation would parse the dataset with DICOMKit.
        // Here we extract UIDs from the Content-Location header or generate placeholders.
        let (sopInstanceUID, sopClassUID, studyUID, seriesUID, patientID) =
            extractMinimalMetadata(from: part)

        // Validate study UID constraint
        if let expected = expectedStudyUID, expected != studyUID {
            return STOWRSResult(
                sopInstanceUID: sopInstanceUID,
                sopClassUID: sopClassUID,
                statusCode: 409,
                failureReason: "Instance belongs to study \(studyUID), not \(expected)"
            )
        }

        // Store to archive
        do {
            let stored = try await storageActor.store(
                sopInstanceUID: sopInstanceUID,
                sopClassUID: sopClassUID,
                transferSyntaxUID: TransferSyntaxRegistry.explicitVRLittleEndianUID,
                patientID: patientID,
                studyInstanceUID: studyUID,
                seriesInstanceUID: seriesUID,
                dataSet: part.body
            )

            // Register in metadata store
            let instance = Instance(
                sopInstanceUID: sopInstanceUID,
                sopClassUID: sopClassUID,
                seriesID: 0,
                transferSyntaxUID: stored.transferSyntaxUID,
                checksumSHA256: stored.checksumSHA256,
                fileSizeBytes: stored.fileSizeBytes,
                filePath: stored.filePath
            )
            let series = Series(
                seriesInstanceUID: seriesUID,
                studyID: 0,
                instanceCount: 1
            )
            let study = Study(
                studyInstanceUID: studyUID,
                patientID: 0
            )
            let patient = Patient(patientID: patientID)
            try await metadataStore.storeInstance(
                instance: instance,
                series: series,
                study: study,
                patient: patient
            )

            return STOWRSResult(
                sopInstanceUID: sopInstanceUID,
                sopClassUID: sopClassUID,
                statusCode: 200
            )
        } catch {
            return STOWRSResult(
                sopInstanceUID: sopInstanceUID,
                sopClassUID: sopClassUID,
                statusCode: 500,
                failureReason: error.localizedDescription
            )
        }
    }

    /// Extracts minimal metadata from a DICOM multipart part.
    ///
    /// In a full implementation this would parse the DICOM dataset. Here we
    /// attempt to extract UIDs from the `Content-Location` header, falling
    /// back to generated placeholder UIDs when the header is absent.
    private func extractMinimalMetadata(
        from part: MultipartPart
    ) -> (sopInstanceUID: String, sopClassUID: String, studyUID: String, seriesUID: String, patientID: String) {
        // Try Content-Location: studies/{study}/series/{series}/instances/{instance}
        if let location = part.contentLocation {
            let components = location.components(separatedBy: "/")
            var studyUID = "1.2.840.10008.99.0"
            var seriesUID = "1.2.840.10008.99.0"
            var sopInstanceUID = generateFallbackUID()
            for (i, c) in components.enumerated() {
                if c == "studies" && i + 1 < components.count { studyUID = components[i + 1] }
                if c == "series" && i + 1 < components.count { seriesUID = components[i + 1] }
                if c == "instances" && i + 1 < components.count { sopInstanceUID = components[i + 1] }
            }
            return (sopInstanceUID, "1.2.840.10008.5.1.4.1.1.2", studyUID, seriesUID, "UNKNOWN")
        }

        // Fall back to parsing first 512 bytes of the dataset for DICOM UIDs
        // This is a minimal heuristic: look for known SOP Instance UID tag (0008,0018)
        let uid = extractUIDFromDataset(part.body) ?? generateFallbackUID()
        return (uid, "1.2.840.10008.5.1.4.1.1.2", "1.2.840.10008.99.0", "1.2.840.10008.99.0", "UNKNOWN")
    }

    /// Generates a valid DICOM UID using the ISO/IEC 8824 UUID-derived 2.25 prefix.
    private func generateFallbackUID() -> String {
        // Use 2.25.* prefix with a UUID decimal value, matching the UPSRSHandler pattern.
        // We use a simpler approach here: take the UUID integer value modulo a large prime.
        let uuidStr = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        // Parse the first 16 hex characters as a UInt64 for a compact decimal suffix
        let hexPrefix = String(uuidStr.prefix(16))
        let decimalSuffix = UInt64(hexPrefix, radix: 16) ?? UInt64.random(in: 1..<UInt64.max)
        return "2.25.\(decimalSuffix)"
    }

    /// Attempts to extract the SOP Instance UID from raw DICOM dataset bytes.
    ///
    /// Scans for tag (0008,0018) in Implicit VR Little Endian encoding.
    ///
    /// - Parameter data: The raw DICOM dataset.
    /// - Returns: The SOP Instance UID string, or `nil` if not found.
    private func extractUIDFromDataset(_ data: Data) -> String? {
        // DICOM preamble is 128 bytes + 4-byte magic "DICM"
        var offset = 0
        if data.count > 132 {
            let magic = data[128..<132]
            if magic == Data([0x44, 0x49, 0x43, 0x4D]) { // "DICM"
                offset = 132
            }
        }

        let targetGroup: UInt16 = 0x0008
        let targetElement: UInt16 = 0x0018

        while offset + 8 <= data.count {
            let group = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            let element = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)
            offset += 4

            guard offset + 4 <= data.count else { break }
            let length = UInt32(data[offset]) |
                        (UInt32(data[offset + 1]) << 8) |
                        (UInt32(data[offset + 2]) << 16) |
                        (UInt32(data[offset + 3]) << 24)
            offset += 4

            if group == targetGroup && element == targetElement {
                guard length > 0, offset + Int(length) <= data.count else { return nil }
                let valueData = data[offset..<(offset + Int(length))]
                return String(data: Data(valueData), encoding: .utf8)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
            }

            guard length < 0xFFFFFFFF else { break }
            offset += Int(length)
        }
        return nil
    }
}
