// SPDX-License-Identifier: (see LICENSE)
// Mayam — SCP Service Protocol & Dispatcher

import Foundation
import DICOMNetwork

/// A protocol for DICOM Service Class Provider (SCP) service handlers.
///
/// Each conforming type handles a specific DIMSE service (e.g. C-ECHO, C-STORE,
/// C-FIND, C-MOVE, C-GET) for a set of supported SOP Class UIDs.
///
/// Reference: DICOM PS3.4
public protocol SCPService: Sendable {
    /// The SOP Class UIDs supported by this service.
    var supportedSOPClassUIDs: Set<String> { get }

    /// Handles an incoming C-ECHO request.
    ///
    /// - Parameters:
    ///   - request: The C-ECHO request message.
    ///   - presentationContextID: The negotiated presentation context ID.
    /// - Returns: A C-ECHO response.
    func handleCEcho(request: CEchoRequest, presentationContextID: UInt8) -> CEchoResponse

    /// Handles an incoming C-STORE request.
    ///
    /// - Parameters:
    ///   - request: The decoded C-STORE request.
    ///   - dataSet: The raw DICOM data set bytes to be stored.
    ///   - transferSyntax: The negotiated transfer syntax UID.
    ///   - presentationContextID: The negotiated presentation context ID.
    /// - Returns: A C-STORE response indicating success or failure.
    func handleCStore(
        request: CStoreRequest,
        dataSet: Data,
        transferSyntax: String,
        presentationContextID: UInt8
    ) async -> CStoreResponse
}

/// Default implementations that return generic failures for unimplemented services.
extension SCPService {
    public func handleCEcho(request: CEchoRequest, presentationContextID: UInt8) -> CEchoResponse {
        CEchoResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.affectedSOPClassUID,
            status: .failedUnableToProcess,
            presentationContextID: presentationContextID
        )
    }

    public func handleCStore(
        request: CStoreRequest,
        dataSet: Data,
        transferSyntax: String,
        presentationContextID: UInt8
    ) async -> CStoreResponse {
        CStoreResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.affectedSOPClassUID,
            affectedSOPInstanceUID: request.affectedSOPInstanceUID,
            status: .failedUnableToProcess,
            presentationContextID: presentationContextID
        )
    }
}

/// Routes incoming DIMSE commands to the appropriate ``SCPService`` handler.
///
/// The dispatcher maintains a registry of service handlers keyed by SOP Class UID.
/// When a DIMSE command arrives, the dispatcher looks up the corresponding handler
/// and delegates processing.
public final class SCPDispatcher: Sendable {

    // MARK: - Stored Properties

    /// Registered SCP service handlers.
    private let services: [SCPService]

    /// The Verification SCP (C-ECHO) handler — always available.
    private let verificationSCP: VerificationSCP

    /// The Storage SCP (C-STORE) handler — present when storage is configured.
    private let storageSCP: StorageSCP?

    /// The Query/Retrieve SCP (C-FIND) handler — present when Q/R is configured.
    private let queryRetrieveSCP: QueryRetrieveSCP?

    /// The Retrieve SCP (C-MOVE) handler — present when retrieval is configured.
    private let retrieveSCP: RetrieveSCP?

    /// The Get SCP (C-GET) handler — present when get retrieval is configured.
    private let getSCP: GetSCP?

    /// The Storage Commitment SCP (N-ACTION/N-EVENT-REPORT) handler —
    /// present when storage commitment is configured.
    private let storageCommitmentSCP: StorageCommitmentSCP?

    // MARK: - Initialiser

    /// Creates a new SCP dispatcher.
    ///
    /// - Parameters:
    ///   - services: Additional SCP service handlers to register.
    ///     The Verification SCP is always included automatically.
    ///   - storageSCP: Optional Storage SCP for handling C-STORE requests.
    ///   - queryRetrieveSCP: Optional Query/Retrieve SCP for handling C-FIND requests.
    ///   - retrieveSCP: Optional Retrieve SCP for handling C-MOVE requests.
    ///   - getSCP: Optional Get SCP for handling C-GET requests.
    ///   - storageCommitmentSCP: Optional Storage Commitment SCP for handling
    ///     N-ACTION/N-EVENT-REPORT requests.
    public init(
        services: [SCPService] = [],
        storageSCP: StorageSCP? = nil,
        queryRetrieveSCP: QueryRetrieveSCP? = nil,
        retrieveSCP: RetrieveSCP? = nil,
        getSCP: GetSCP? = nil,
        storageCommitmentSCP: StorageCommitmentSCP? = nil
    ) {
        self.verificationSCP = VerificationSCP()
        self.storageSCP = storageSCP
        self.queryRetrieveSCP = queryRetrieveSCP
        self.retrieveSCP = retrieveSCP
        self.getSCP = getSCP
        self.storageCommitmentSCP = storageCommitmentSCP
        self.services = services
    }

    // MARK: - Public Methods

    /// Handles an incoming C-ECHO request.
    ///
    /// - Parameters:
    ///   - request: The C-ECHO request message.
    ///   - presentationContextID: The negotiated presentation context ID.
    /// - Returns: A C-ECHO response.
    public func handleCEcho(request: CEchoRequest, presentationContextID: UInt8) -> CEchoResponse {
        verificationSCP.handleCEcho(request: request, presentationContextID: presentationContextID)
    }

    /// Handles an incoming C-STORE request.
    ///
    /// Routes to the configured ``StorageSCP`` if present; otherwise returns a
    /// "not supported" failure response.
    ///
    /// - Parameters:
    ///   - request: The decoded C-STORE request.
    ///   - dataSet: The raw DICOM data set bytes.
    ///   - transferSyntax: The negotiated transfer syntax UID.
    ///   - presentationContextID: The negotiated presentation context ID.
    /// - Returns: A C-STORE response.
    public func handleCStore(
        request: CStoreRequest,
        dataSet: Data,
        transferSyntax: String,
        presentationContextID: UInt8
    ) async -> CStoreResponse {
        if let scp = storageSCP {
            return await scp.handleCStore(
                request: request,
                dataSet: dataSet,
                transferSyntax: transferSyntax,
                presentationContextID: presentationContextID
            )
        }
        return CStoreResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.affectedSOPClassUID,
            affectedSOPInstanceUID: request.affectedSOPInstanceUID,
            status: .failedUnableToProcess,
            presentationContextID: presentationContextID
        )
    }

    /// Handles an incoming C-FIND request.
    ///
    /// Routes to the configured ``QueryRetrieveSCP`` if present; otherwise
    /// returns a failure response.
    ///
    /// - Parameters:
    ///   - request: The decoded C-FIND request.
    ///   - identifier: The query identifier data set.
    ///   - presentationContextID: The negotiated presentation context ID.
    /// - Returns: An array of C-FIND responses (pending matches + final status).
    public func handleCFind(
        request: CFindRequest,
        identifier: Data,
        presentationContextID: UInt8
    ) async -> [(response: CFindResponse, dataSet: Data?)] {
        if let scp = queryRetrieveSCP {
            return await scp.handleCFind(
                request: request,
                identifier: identifier,
                presentationContextID: presentationContextID
            )
        }
        return [(
            response: CFindResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: .failedUnableToProcess,
                hasDataSet: false,
                presentationContextID: presentationContextID
            ),
            dataSet: nil
        )]
    }

    /// Handles an incoming C-MOVE request.
    ///
    /// Routes to the configured ``RetrieveSCP`` if present; otherwise returns
    /// a failure response.
    ///
    /// - Parameters:
    ///   - request: The decoded C-MOVE request.
    ///   - identifier: The query identifier data set.
    ///   - presentationContextID: The negotiated presentation context ID.
    /// - Returns: An array of C-MOVE responses tracking sub-operation progress.
    public func handleCMove(
        request: CMoveRequest,
        identifier: Data,
        presentationContextID: UInt8
    ) async -> [CMoveResponse] {
        if let scp = retrieveSCP {
            return await scp.handleCMove(
                request: request,
                identifier: identifier,
                presentationContextID: presentationContextID
            )
        }
        return [CMoveResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.affectedSOPClassUID,
            status: .failedUnableToProcess,
            presentationContextID: presentationContextID
        )]
    }

    /// Handles an incoming C-GET request.
    ///
    /// Routes to the configured ``GetSCP`` if present; otherwise returns
    /// a failure response.
    ///
    /// - Parameters:
    ///   - request: The decoded C-GET request.
    ///   - identifier: The query identifier data set.
    ///   - presentationContextID: The negotiated presentation context ID.
    /// - Returns: A tuple containing C-GET responses and data sets for C-STORE sub-operations.
    public func handleCGet(
        request: CGetRequest,
        identifier: Data,
        presentationContextID: UInt8
    ) async -> (responses: [CGetResponse], dataSets: [(sopClassUID: String, sopInstanceUID: String, transferSyntaxUID: String, data: Data)]) {
        if let scp = getSCP {
            return await scp.handleCGet(
                request: request,
                identifier: identifier,
                presentationContextID: presentationContextID
            )
        }
        return (
            responses: [CGetResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: .failedUnableToProcess,
                presentationContextID: presentationContextID
            )],
            dataSets: []
        )
    }

    /// Handles an incoming Storage Commitment N-ACTION request.
    ///
    /// Routes to the configured ``StorageCommitmentSCP`` if present; otherwise
    /// returns `nil`.
    ///
    /// - Parameters:
    ///   - transactionUID: The Transaction UID for the commitment.
    ///   - referencedInstances: The list of SOP instances to commit.
    /// - Returns: A ``StorageCommitmentSCP/CommitmentResult``, or `nil` if
    ///   storage commitment is not configured.
    public func handleStorageCommitment(
        transactionUID: String,
        referencedInstances: [(sopClassUID: String, sopInstanceUID: String)]
    ) async -> StorageCommitmentSCP.CommitmentResult? {
        guard let scp = storageCommitmentSCP else { return nil }
        return await scp.processCommitmentRequest(
            transactionUID: transactionUID,
            referencedInstances: referencedInstances
        )
    }
}
