// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOM PS3.15 Annex H LDAP Schema Representation

import Foundation

// MARK: - DICOMNetworkConnection

/// Represents a `dicomNetworkConnection` LDAP object class as defined in
/// DICOM PS3.15 Annex H.1.3.
public struct DICOMNetworkConnection: Codable, Sendable {
    /// Common Name (`cn`) used as the LDAP RDN for this connection.
    public let cn: String
    /// Hostname or IP address (`dicomHostname`).
    public let dicomHostname: String
    /// TCP port number (`dicomPort`).
    public let dicomPort: Int
    /// TLS cipher suite OIDs or names (`dicomTLSCyphersuite`).
    public let dicomTLSCyphersuite: [String]

    /// Creates a network connection descriptor.
    ///
    /// - Parameters:
    ///   - cn: LDAP common name (RDN).
    ///   - dicomHostname: Hostname or IP address.
    ///   - dicomPort: TCP port number.
    ///   - dicomTLSCyphersuite: TLS cipher suites.
    public init(
        cn: String,
        dicomHostname: String,
        dicomPort: Int,
        dicomTLSCyphersuite: [String] = []
    ) {
        self.cn = cn
        self.dicomHostname = dicomHostname
        self.dicomPort = dicomPort
        self.dicomTLSCyphersuite = dicomTLSCyphersuite
    }
}

// MARK: - DICOMNetworkAE

/// Represents a `dicomNetworkAE` LDAP object class as defined in
/// DICOM PS3.15 Annex H.1.2.
public struct DICOMNetworkAE: Codable, Sendable {
    /// DICOM Application Entity Title (`dicomAETitle`).
    public let dicomAETitle: String
    /// DNs of the network connections associated with this AE
    /// (`dicomNetworkConnectionReference`).
    public let dicomNetworkConnectionReference: [String]
    /// Whether this AE can initiate associations (`dicomAssociationInitiator`).
    public let dicomAssociationInitiator: Bool
    /// Whether this AE can accept associations (`dicomAssociationAcceptor`).
    public let dicomAssociationAcceptor: Bool
    /// Optional human-readable description (`dicomDescription`).
    public let dicomDescription: String?
    /// Application cluster labels (`dicomApplicationCluster`).
    public let dicomApplicationCluster: [String]
    /// Supported transfer role strings (`dicomSupportedTransferRole`).
    public let dicomSupportedTransferRole: [String]
    /// Preferred transfer syntax UIDs (`dicomPreferredTransferSyntax`).
    public let dicomPreferredTransferSyntax: [String]

    /// Creates a network AE descriptor.
    public init(
        dicomAETitle: String,
        dicomNetworkConnectionReference: [String] = [],
        dicomAssociationInitiator: Bool = true,
        dicomAssociationAcceptor: Bool = true,
        dicomDescription: String? = nil,
        dicomApplicationCluster: [String] = [],
        dicomSupportedTransferRole: [String] = [],
        dicomPreferredTransferSyntax: [String] = []
    ) {
        self.dicomAETitle = dicomAETitle
        self.dicomNetworkConnectionReference = dicomNetworkConnectionReference
        self.dicomAssociationInitiator = dicomAssociationInitiator
        self.dicomAssociationAcceptor = dicomAssociationAcceptor
        self.dicomDescription = dicomDescription
        self.dicomApplicationCluster = dicomApplicationCluster
        self.dicomSupportedTransferRole = dicomSupportedTransferRole
        self.dicomPreferredTransferSyntax = dicomPreferredTransferSyntax
    }
}

// MARK: - DICOMDevice

/// Represents a `dicomDevice` LDAP object class as defined in
/// DICOM PS3.15 Annex H.1.1.
public struct DICOMDevice: Codable, Sendable {
    /// Device name (`dicomDeviceName`).
    public let dicomDeviceName: String
    /// Optional description (`dicomDescription`).
    public let dicomDescription: String?
    /// Manufacturer name (`dicomManufacturer`).
    public let dicomManufacturer: String?
    /// Software version strings (`dicomSoftwareVersion`).
    public let dicomSoftwareVersion: [String]
    /// Primary device type labels (`dicomPrimaryDeviceType`).
    public let dicomPrimaryDeviceType: [String]
    /// DNs of related devices (`dicomRelatedDeviceReference`).
    public let dicomRelatedDeviceReference: [String]
    /// Network AE descriptors for this device.
    public let dicomNetworkAEs: [DICOMNetworkAE]
    /// Network connection descriptors for this device.
    public let dicomNetworkConnections: [DICOMNetworkConnection]

    /// Creates a DICOM device descriptor.
    public init(
        dicomDeviceName: String,
        dicomDescription: String? = nil,
        dicomManufacturer: String? = nil,
        dicomSoftwareVersion: [String] = [],
        dicomPrimaryDeviceType: [String] = [],
        dicomRelatedDeviceReference: [String] = [],
        dicomNetworkAEs: [DICOMNetworkAE] = [],
        dicomNetworkConnections: [DICOMNetworkConnection] = []
    ) {
        self.dicomDeviceName = dicomDeviceName
        self.dicomDescription = dicomDescription
        self.dicomManufacturer = dicomManufacturer
        self.dicomSoftwareVersion = dicomSoftwareVersion
        self.dicomPrimaryDeviceType = dicomPrimaryDeviceType
        self.dicomRelatedDeviceReference = dicomRelatedDeviceReference
        self.dicomNetworkAEs = dicomNetworkAEs
        self.dicomNetworkConnections = dicomNetworkConnections
    }
}

// MARK: - DICOMLDAPConfiguration

/// The root configuration tree stored in LDAP per DICOM PS3.15 Annex H.
public struct DICOMLDAPConfiguration: Codable, Sendable {
    /// DN of the DICOM configuration root entry.
    public let configurationRoot: String
    /// DN of the devices subtree.
    public let devicesRoot: String
    /// DN of the AE titles subtree.
    public let aeTitlesRoot: String
    /// All device entries.
    public let devices: [DICOMDevice]

    /// Creates a DICOM LDAP configuration root.
    public init(
        configurationRoot: String,
        devicesRoot: String,
        aeTitlesRoot: String,
        devices: [DICOMDevice] = []
    ) {
        self.configurationRoot = configurationRoot
        self.devicesRoot = devicesRoot
        self.aeTitlesRoot = aeTitlesRoot
        self.devices = devices
    }
}

// MARK: - DICOMLDAPSchema

/// Type-namespace providing LDAP object class names from DICOM PS3.15 Annex H.
///
/// These constants should be used when constructing LDAP `objectClass` values
/// for DICOM device entries.
public enum DICOMLDAPSchema {

    // MARK: - Object Class Names (PS3.15 H.1)

    /// LDAP object class for the DICOM configuration root (`dicomConfigurationRoot`).
    public static let configurationRootClass = "dicomConfigurationRoot"

    /// LDAP object class for DICOM device entries (`dicomDevice`).
    public static let deviceClass = "dicomDevice"

    /// LDAP object class for DICOM network AE entries (`dicomNetworkAE`).
    public static let networkAEClass = "dicomNetworkAE"

    /// LDAP object class for DICOM network connection entries (`dicomNetworkConnection`).
    public static let networkConnectionClass = "dicomNetworkConnection"
}
