// SPDX-License-Identifier: (see LICENSE)
// Mayam Server — SCP Service Protocol & Dispatcher

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
}

/// Default implementation that returns a generic failure for unimplemented services.
extension SCPService {
    public func handleCEcho(request: CEchoRequest, presentationContextID: UInt8) -> CEchoResponse {
        return CEchoResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.affectedSOPClassUID,
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

    // MARK: - Initialiser

    /// Creates a new SCP dispatcher.
    ///
    /// - Parameter services: The SCP service handlers to register.
    ///   The Verification SCP is always included automatically.
    public init(services: [SCPService] = []) {
        self.verificationSCP = VerificationSCP()
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
}
