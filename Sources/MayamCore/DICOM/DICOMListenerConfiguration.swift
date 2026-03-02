// SPDX-License-Identifier: (see LICENSE)
// Mayam Server — DICOM Listener Configuration

import Foundation
import DICOMNetwork

/// Configuration for the DICOM TCP listener and association negotiation.
///
/// This type captures all settings needed to accept inbound DICOM associations,
/// including the local AE Title, port, maximum PDU size, accepted SOP Classes,
/// accepted transfer syntaxes, and TLS options.
public struct DICOMListenerConfiguration: Sendable, Equatable {

    // MARK: - Stored Properties

    /// The Application Entity Title advertised by this server.
    public var aeTitle: String

    /// TCP port for inbound DICOM associations.
    public var port: Int

    /// Maximum PDU size for outgoing PDUs.
    public var maxPDUSize: UInt32

    /// Maximum number of concurrent associations.
    public var maxAssociations: Int

    /// Implementation Class UID for this DICOM implementation.
    public var implementationClassUID: String

    /// Implementation Version Name (optional).
    public var implementationVersionName: String?

    /// The set of accepted SOP Class UIDs (abstract syntaxes).
    public var acceptedSOPClasses: Set<String>

    /// The set of accepted Transfer Syntax UIDs.
    public var acceptedTransferSyntaxes: Set<String>

    /// Whether TLS is enabled for inbound associations.
    public var tlsEnabled: Bool

    /// Path to the TLS certificate file (PEM format).
    public var tlsCertificatePath: String?

    /// Path to the TLS private key file (PEM format).
    public var tlsKeyPath: String?

    // MARK: - Constants

    /// Default Implementation Class UID for Mayam Server.
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.2.1"

    /// Default Implementation Version Name for Mayam Server.
    public static let defaultImplementationVersionName = "MAYAM_001"

    /// Default maximum PDU size (16 KB).
    public static let defaultMaxPDUSize: UInt32 = 16_384

    /// Default SOP Classes accepted by the server.
    ///
    /// Initially includes only the Verification SOP Class (C-ECHO).
    /// Additional SOP Classes (C-STORE, C-FIND, etc.) will be added in
    /// subsequent milestones.
    public static let defaultAcceptedSOPClasses: Set<String> = [
        verificationSOPClassUID  // "1.2.840.10008.1.1"
    ]

    /// Default transfer syntaxes accepted by the server.
    public static let defaultAcceptedTransferSyntaxes: Set<String> = [
        implicitVRLittleEndianTransferSyntaxUID,   // "1.2.840.10008.1.2"
        explicitVRLittleEndianTransferSyntaxUID     // "1.2.840.10008.1.2.1"
    ]

    // MARK: - Initialiser

    /// Creates a new listener configuration.
    ///
    /// - Parameters:
    ///   - aeTitle: The local AE Title (default: `"MAYAM"`).
    ///   - port: TCP port number (default: `11112`).
    ///   - maxPDUSize: Maximum PDU size (default: 16384).
    ///   - maxAssociations: Maximum concurrent associations (default: `64`).
    ///   - implementationClassUID: Implementation Class UID.
    ///   - implementationVersionName: Implementation Version Name.
    ///   - acceptedSOPClasses: Accepted SOP Class UIDs.
    ///   - acceptedTransferSyntaxes: Accepted Transfer Syntax UIDs.
    ///   - tlsEnabled: Whether TLS is enabled (default: `false`).
    ///   - tlsCertificatePath: Path to TLS certificate (default: `nil`).
    ///   - tlsKeyPath: Path to TLS private key (default: `nil`).
    public init(
        aeTitle: String = "MAYAM",
        port: Int = 11112,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        maxAssociations: Int = 64,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        acceptedSOPClasses: Set<String> = defaultAcceptedSOPClasses,
        acceptedTransferSyntaxes: Set<String> = defaultAcceptedTransferSyntaxes,
        tlsEnabled: Bool = false,
        tlsCertificatePath: String? = nil,
        tlsKeyPath: String? = nil
    ) {
        self.aeTitle = aeTitle
        self.port = port
        self.maxPDUSize = maxPDUSize
        self.maxAssociations = maxAssociations
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.acceptedSOPClasses = acceptedSOPClasses
        self.acceptedTransferSyntaxes = acceptedTransferSyntaxes
        self.tlsEnabled = tlsEnabled
        self.tlsCertificatePath = tlsCertificatePath
        self.tlsKeyPath = tlsKeyPath
    }

    /// Creates a listener configuration from a ``ServerConfiguration``.
    ///
    /// - Parameter serverConfig: The server configuration.
    /// - Returns: A listener configuration derived from the server settings.
    public init(from serverConfig: ServerConfiguration) {
        self.init(
            aeTitle: serverConfig.dicom.aeTitle,
            port: serverConfig.dicom.port,
            maxAssociations: serverConfig.dicom.maxAssociations,
            tlsEnabled: serverConfig.dicom.tlsEnabled,
            tlsCertificatePath: serverConfig.dicom.tlsCertificatePath,
            tlsKeyPath: serverConfig.dicom.tlsKeyPath
        )
    }
}
