// SPDX-License-Identifier: (see LICENSE)
// Mayam Server — Verification SCP (C-ECHO Service Class Provider)

import Foundation
import DICOMNetwork

/// DICOM Verification Service Class Provider (C-ECHO SCP).
///
/// Handles incoming C-ECHO requests and returns a success response. This is the
/// simplest DICOM service and is used to verify network connectivity between
/// DICOM application entities.
///
/// Reference: DICOM PS3.4 Annex A — Verification Service Class
/// Reference: DICOM PS3.7 Section 9.1.5 — C-ECHO Service
public struct VerificationSCP: SCPService, Sendable {

    // MARK: - SCPService

    /// The Verification SOP Class UID.
    public let supportedSOPClassUIDs: Set<String> = [
        verificationSOPClassUID  // "1.2.840.10008.1.1"
    ]

    // MARK: - Initialiser

    public init() {}

    // MARK: - C-ECHO Handling

    /// Handles an incoming C-ECHO request by returning a success response.
    ///
    /// - Parameters:
    ///   - request: The C-ECHO request message.
    ///   - presentationContextID: The negotiated presentation context ID.
    /// - Returns: A C-ECHO response with status `success` (0x0000).
    public func handleCEcho(request: CEchoRequest, presentationContextID: UInt8) -> CEchoResponse {
        CEchoResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.affectedSOPClassUID,
            status: .success,
            presentationContextID: presentationContextID
        )
    }
}
