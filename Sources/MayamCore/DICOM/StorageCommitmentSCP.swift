// SPDX-License-Identifier: (see LICENSE)
// Mayam — Storage Commitment SCP

import Foundation
import DICOMNetwork

// MARK: - StorageCommitmentSCP

/// Handles DICOM Storage Commitment (N-ACTION / N-EVENT-REPORT) requests.
///
/// The Storage Commitment SCP confirms to modalities that their transmitted
/// studies have been safely archived. When a modality sends an N-ACTION
/// request with a list of SOP Instance UIDs, this SCP verifies that each
/// instance exists in the archive and responds with an N-EVENT-REPORT
/// confirming the commitment status of each referenced instance.
///
/// Reference: DICOM PS3.4 Annex J — Storage Commitment Push Model
public actor StorageCommitmentSCP {

    // MARK: - Nested Types

    /// The result of a storage commitment request.
    public struct CommitmentResult: Sendable, Equatable {

        /// The Transaction UID identifying this commitment request.
        public let transactionUID: String

        /// Instances that are successfully committed (present in archive).
        public let successInstances: [ReferencedInstance]

        /// Instances that failed commitment (not found or integrity error).
        public let failedInstances: [ReferencedInstance]

        /// Creates a commitment result.
        public init(
            transactionUID: String,
            successInstances: [ReferencedInstance],
            failedInstances: [ReferencedInstance]
        ) {
            self.transactionUID = transactionUID
            self.successInstances = successInstances
            self.failedInstances = failedInstances
        }
    }

    /// A reference to a single SOP instance in a commitment request.
    public struct ReferencedInstance: Sendable, Equatable, Codable {

        /// The SOP Class UID (0008,0016).
        public let sopClassUID: String

        /// The SOP Instance UID (0008,0018).
        public let sopInstanceUID: String

        /// The failure reason code, if applicable. `nil` for success.
        /// Reference: DICOM PS3.4 Table J.3-1.
        public let failureReason: UInt16?

        /// Creates a referenced instance.
        public init(sopClassUID: String, sopInstanceUID: String, failureReason: UInt16? = nil) {
            self.sopClassUID = sopClassUID
            self.sopInstanceUID = sopInstanceUID
            self.failureReason = failureReason
        }
    }

    // MARK: - Constants

    /// Storage Commitment Push Model SOP Class UID.
    /// Reference: DICOM PS3.4 Annex J.
    public static let sopClassUID = "1.2.840.10008.1.20.1"

    /// Failure reason: No such object instance (0112H).
    public static let failureReasonNoSuchInstance: UInt16 = 0x0112

    // MARK: - Stored Properties

    /// A closure that checks whether a SOP instance exists in the archive.
    private let instanceExistsCheck: @Sendable (String) async -> Bool

    /// Logger for commitment events.
    private let logger: MayamLogger

    /// Tracks pending commitment transactions.
    private var pendingTransactions: [String: CommitmentResult] = [:]

    /// History of completed commitment transactions.
    private var completedTransactions: [CommitmentResult] = []

    // MARK: - Initialiser

    /// Creates a new Storage Commitment SCP.
    ///
    /// - Parameters:
    ///   - instanceExistsCheck: A closure that returns `true` if the given
    ///     SOP Instance UID exists in the archive.
    ///   - logger: Logger instance for commitment events.
    public init(
        instanceExistsCheck: @escaping @Sendable (String) async -> Bool,
        logger: MayamLogger
    ) {
        self.instanceExistsCheck = instanceExistsCheck
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Processes a storage commitment request (N-ACTION).
    ///
    /// Verifies each referenced SOP instance against the archive and
    /// produces a commitment result.
    ///
    /// - Parameters:
    ///   - transactionUID: The Transaction UID for this commitment.
    ///   - referencedInstances: The list of SOP instances to commit.
    /// - Returns: A ``CommitmentResult`` indicating which instances are
    ///   committed and which failed.
    public func processCommitmentRequest(
        transactionUID: String,
        referencedInstances: [(sopClassUID: String, sopInstanceUID: String)]
    ) async -> CommitmentResult {
        logger.info("Storage Commitment: Processing request '\(transactionUID)' with \(referencedInstances.count) instance(s)")

        var successInstances: [ReferencedInstance] = []
        var failedInstances: [ReferencedInstance] = []

        for instance in referencedInstances {
            let exists = await instanceExistsCheck(instance.sopInstanceUID)

            if exists {
                successInstances.append(ReferencedInstance(
                    sopClassUID: instance.sopClassUID,
                    sopInstanceUID: instance.sopInstanceUID
                ))
            } else {
                failedInstances.append(ReferencedInstance(
                    sopClassUID: instance.sopClassUID,
                    sopInstanceUID: instance.sopInstanceUID,
                    failureReason: Self.failureReasonNoSuchInstance
                ))
            }
        }

        let result = CommitmentResult(
            transactionUID: transactionUID,
            successInstances: successInstances,
            failedInstances: failedInstances
        )

        completedTransactions.append(result)

        logger.info("Storage Commitment: Completed '\(transactionUID)' — \(successInstances.count) committed, \(failedInstances.count) failed")

        return result
    }

    /// Returns the history of completed commitment transactions.
    public func getCompletedTransactions() -> [CommitmentResult] {
        completedTransactions
    }

    /// Returns the count of completed commitment transactions.
    public func completedTransactionCount() -> Int {
        completedTransactions.count
    }
}

// MARK: - StorageCommitmentError

/// Errors that may occur during storage commitment operations.
public enum StorageCommitmentError: Error, Sendable, CustomStringConvertible {

    /// The transaction UID was not found.
    case transactionNotFound(transactionUID: String)

    /// The commitment request contained invalid data.
    case invalidRequest(reason: String)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .transactionNotFound(let uid):
            return "Storage commitment transaction '\(uid)' not found"
        case .invalidRequest(let reason):
            return "Invalid storage commitment request: \(reason)"
        }
    }
}
