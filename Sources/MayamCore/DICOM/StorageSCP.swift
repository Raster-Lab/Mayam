// SPDX-License-Identifier: (see LICENSE)
// Mayam — Storage SCP (C-STORE Service Class Provider)

import Foundation
import DICOMNetwork
import Logging

/// DICOM Storage Service Class Provider (C-STORE SCP).
///
/// Handles incoming C-STORE requests by persisting the received DICOM object
/// to the on-disk archive via ``StorageActor``.
///
/// ## Store-As-Received Semantics
///
/// Received objects are written verbatim to disk in their original transfer
/// syntax without decompression or transcoding.  The stored transfer syntax
/// UID is recorded alongside the file so that serve-as-stored semantics can
/// be applied when the object is later retrieved.
///
/// ## Duplicate Detection
///
/// Before writing, the SCP checks for a duplicate SOP Instance UID.  The
/// behaviour is governed by ``StoragePolicy/duplicatePolicy``:
/// - `.reject` — returns a C-STORE failure (status 0xA701).
/// - `.overwrite` — replaces the existing file.
/// - `.keepBoth` — stores the new file under a unique name.
///
/// Reference: DICOM PS3.4 Annex B — Storage Service Class
public struct StorageSCP: SCPService, Sendable {

    // MARK: - SCPService

    /// All common storage SOP Classes supported by this SCP.
    ///
    /// Uses the common SOP class set from `DICOMNetwork.StorageSCPConfiguration`.
    public let supportedSOPClassUIDs: Set<String> = StorageSCPConfiguration.commonStorageSOPClasses

    // MARK: - Stored Properties

    /// The storage actor responsible for persisting DICOM objects.
    private let storageActor: StorageActor

    /// The storage policy governing ingest behaviour.
    private let policy: StoragePolicy

    /// Logger for SCP events.
    private let logger: Logger

    // MARK: - Initialiser

    /// Creates a new Storage SCP.
    ///
    /// - Parameters:
    ///   - storageActor: The actor responsible for persisting DICOM objects.
    ///   - policy: The storage policy governing ingest behaviour.
    ///   - logger: Logger instance for SCP events.
    public init(
        storageActor: StorageActor,
        policy: StoragePolicy = .default,
        logger: Logger
    ) {
        self.storageActor = storageActor
        self.policy = policy
        self.logger = logger
    }

    // MARK: - C-STORE Handling

    /// Handles an incoming C-STORE request by storing the DICOM object.
    ///
    /// - Parameters:
    ///   - request: The decoded C-STORE request.
    ///   - dataSet: The raw DICOM data set bytes (the object to be stored).
    ///   - transferSyntax: The negotiated transfer syntax UID for this
    ///     presentation context.
    ///   - presentationContextID: The presentation context ID.
    /// - Returns: A C-STORE response indicating success or failure.
    public func handleCStore(
        request: CStoreRequest,
        dataSet: Data,
        transferSyntax: String,
        presentationContextID: UInt8
    ) async -> CStoreResponse {
        let sopInstanceUID = request.affectedSOPInstanceUID
        let sopClassUID = request.affectedSOPClassUID

        guard !sopInstanceUID.isEmpty, !sopClassUID.isEmpty else {
            logger.error("C-STORE-RQ: empty SOP Instance UID or SOP Class UID")
            return CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: sopClassUID,
                affectedSOPInstanceUID: sopInstanceUID,
                status: .failedUnableToProcess,
                presentationContextID: presentationContextID
            )
        }

        logger.info("C-STORE-RQ: sopInstance=\(sopInstanceUID) sopClass=\(sopClassUID) ts=\(transferSyntax) size=\(dataSet.count)B")

        do {
            let stored = try await storageActor.store(
                sopInstanceUID: sopInstanceUID,
                sopClassUID: sopClassUID,
                transferSyntaxUID: transferSyntax,
                dataSet: dataSet,
                policy: policy
            )
            logger.info("C-STORE: stored '\(sopInstanceUID)' → '\(stored.filePath)'")
            return CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: sopClassUID,
                affectedSOPInstanceUID: sopInstanceUID,
                status: .success,
                presentationContextID: presentationContextID
            )
        } catch StorageError.duplicateInstance(let uid) {
            logger.warning("C-STORE: duplicate SOP Instance '\(uid)' — rejected per policy")
            return CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: sopClassUID,
                affectedSOPInstanceUID: sopInstanceUID,
                status: .failedDuplicateSOPInstance,
                presentationContextID: presentationContextID
            )
        } catch {
            logger.error("C-STORE: failed to store '\(sopInstanceUID)': \(error)")
            return CStoreResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: sopClassUID,
                affectedSOPInstanceUID: sopInstanceUID,
                status: .failedUnableToProcess,
                presentationContextID: presentationContextID
            )
        }
    }
}
