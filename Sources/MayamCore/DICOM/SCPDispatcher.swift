// SPDX-License-Identifier: (see LICENSE)
// Mayam — SCP Service Protocol & Dispatcher

import Foundation
import DICOMNetwork

/// A protocol for DICOM Service Class Provider (SCP) service handlers.
///
/// Each conforming type handles a specific DIMSE service (e.g. C-ECHO, C-STORE)
/// for a set of supported SOP Class UIDs.
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

    // MARK: - Initialiser

    /// Creates a new SCP dispatcher.
    ///
    /// - Parameters:
    ///   - services: Additional SCP service handlers to register.
    ///     The Verification SCP is always included automatically.
    ///   - storageSCP: Optional Storage SCP for handling C-STORE requests.
    public init(services: [SCPService] = [], storageSCP: StorageSCP? = nil) {
        self.verificationSCP = VerificationSCP()
        self.storageSCP = storageSCP
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
}
