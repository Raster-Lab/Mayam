// SPDX-License-Identifier: (see LICENSE)
// Mayam — Configuration Model

import Foundation

/// Top-level server configuration loaded from a YAML file with optional
/// environment variable overrides.
///
/// The configuration defines all tuneable parameters for the Mayam PACS server,
/// organised by subsystem.
public struct ServerConfiguration: Sendable, Equatable {

    // MARK: - Nested Types

    /// DICOM network configuration.
    public struct DICOM: Sendable, Equatable {
        /// The Application Entity Title advertised by this server.
        public var aeTitle: String

        /// TCP port for inbound DICOM associations.
        public var port: Int

        /// Maximum number of concurrent associations.
        public var maxAssociations: Int

        /// Whether TLS 1.3 is enabled for DICOM associations (DICOM PS3.15).
        public var tlsEnabled: Bool

        /// Path to the TLS certificate file (PEM format).
        public var tlsCertificatePath: String?

        /// Path to the TLS private key file (PEM format).
        public var tlsKeyPath: String?

        public init(
            aeTitle: String = "MAYAM",
            port: Int = 11112,
            maxAssociations: Int = 64,
            tlsEnabled: Bool = false,
            tlsCertificatePath: String? = nil,
            tlsKeyPath: String? = nil
        ) {
            self.aeTitle = aeTitle
            self.port = port
            self.maxAssociations = maxAssociations
            self.tlsEnabled = tlsEnabled
            self.tlsCertificatePath = tlsCertificatePath
            self.tlsKeyPath = tlsKeyPath
        }
    }

    /// Storage subsystem configuration.
    public struct Storage: Sendable, Equatable {
        /// Root directory for the DICOM object archive.
        public var archivePath: String

        /// Whether to enable SHA-256 integrity checksums on ingest.
        public var checksumEnabled: Bool

        /// Storage policy governing ingest behaviour, duplicate handling, and
        /// near-line migration triggers.
        public var policy: StoragePolicy

        public init(
            archivePath: String = "/var/lib/mayam/archive",
            checksumEnabled: Bool = true,
            policy: StoragePolicy = .default
        ) {
            self.archivePath = archivePath
            self.checksumEnabled = checksumEnabled
            self.policy = policy
        }
    }

    /// Logging configuration.
    public struct Log: Sendable, Equatable {
        /// Minimum log level (`trace`, `debug`, `info`, `notice`, `warning`, `error`, `critical`).
        public var level: String

        public init(level: String = "info") {
            self.level = level
        }
    }

    /// DICOMweb HTTP server configuration.
    public struct Web: Sendable, Equatable {
        /// TCP port for the DICOMweb HTTP server.
        public var port: Int

        /// Whether TLS is enabled for the DICOMweb server.
        public var tlsEnabled: Bool

        /// Path to the TLS certificate file (PEM format).
        public var tlsCertificatePath: String?

        /// Path to the TLS private key file (PEM format).
        public var tlsKeyPath: String?

        /// Base URL path prefix for all DICOMweb endpoints (e.g. `"/dicomweb"`).
        public var basePath: String

        public init(
            port: Int = 8080,
            tlsEnabled: Bool = false,
            tlsCertificatePath: String? = nil,
            tlsKeyPath: String? = nil,
            basePath: String = ""
        ) {
            self.port = port
            self.tlsEnabled = tlsEnabled
            self.tlsCertificatePath = tlsCertificatePath
            self.tlsKeyPath = tlsKeyPath
            self.basePath = basePath
        }
    }

    /// Admin console HTTP server configuration.
    public struct Admin: Sendable, Equatable {
        /// TCP port for the Admin HTTP server.
        public var port: Int

        /// Whether TLS is enabled for the Admin server.
        public var tlsEnabled: Bool

        /// Path to the TLS certificate file (PEM format).
        public var tlsCertificatePath: String?

        /// Path to the TLS private key file (PEM format).
        public var tlsKeyPath: String?

        /// JWT shared secret for admin session tokens.
        ///
        /// > Important: Change this value before deploying to production.
        public var jwtSecret: String

        /// Session token expiry in seconds (default: 3 600).
        public var sessionExpirySeconds: Int

        /// Whether the first-run setup wizard has been completed.
        ///
        /// Set to `true` by the Setup Wizard handler after all setup steps are
        /// finished.  When `false` the Admin Console will redirect users to the
        /// wizard on first login so that a fresh installation can be configured
        /// before going into production.
        public var setupCompleted: Bool

        public init(
            port: Int = 8081,
            tlsEnabled: Bool = false,
            tlsCertificatePath: String? = nil,
            tlsKeyPath: String? = nil,
            jwtSecret: String = "change-me-in-production",
            sessionExpirySeconds: Int = 3600,
            setupCompleted: Bool = false
        ) {
            self.port = port
            self.tlsEnabled = tlsEnabled
            self.tlsCertificatePath = tlsCertificatePath
            self.tlsKeyPath = tlsKeyPath
            self.jwtSecret = jwtSecret
            self.sessionExpirySeconds = sessionExpirySeconds
            self.setupCompleted = setupCompleted
        }
    }

    /// Codec configuration for image transcoding and compressed copy creation.
    public struct Codec: Sendable, Equatable {
        /// Whether on-demand transcoding is enabled (transcode only when a
        /// client requests a transfer syntax that differs from stored).
        public var onDemandTranscodingEnabled: Bool

        /// Whether background batch transcoding is enabled for existing
        /// archive data.
        public var backgroundTranscodingEnabled: Bool

        /// Maximum number of concurrent transcoding operations.
        public var maxConcurrentTranscodings: Int

        public init(
            onDemandTranscodingEnabled: Bool = true,
            backgroundTranscodingEnabled: Bool = false,
            maxConcurrentTranscodings: Int = 4
        ) {
            self.onDemandTranscodingEnabled = onDemandTranscodingEnabled
            self.backgroundTranscodingEnabled = backgroundTranscodingEnabled
            self.maxConcurrentTranscodings = maxConcurrentTranscodings
        }
    }

    // MARK: - Stored Properties

    /// DICOM network settings.
    public var dicom: DICOM

    /// Storage settings.
    public var storage: Storage

    /// Logging settings.
    public var log: Log

    /// Codec settings.
    public var codec: Codec

    /// DICOMweb HTTP server settings.
    public var web: Web

    /// Admin console HTTP server settings.
    public var admin: Admin

    // MARK: - Initialiser

    public init(
        dicom: DICOM = DICOM(),
        storage: Storage = Storage(),
        log: Log = Log(),
        codec: Codec = Codec(),
        web: Web = Web(),
        admin: Admin = Admin()
    ) {
        self.dicom = dicom
        self.storage = storage
        self.log = log
        self.codec = codec
        self.web = web
        self.admin = admin
    }
}

// MARK: - Codable Conformance with Defaults

extension ServerConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case dicom, storage, log, codec, web, admin
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dicom = try container.decodeIfPresent(DICOM.self, forKey: .dicom) ?? DICOM()
        self.storage = try container.decodeIfPresent(Storage.self, forKey: .storage) ?? Storage()
        self.log = try container.decodeIfPresent(Log.self, forKey: .log) ?? Log()
        self.codec = try container.decodeIfPresent(Codec.self, forKey: .codec) ?? Codec()
        self.web = try container.decodeIfPresent(Web.self, forKey: .web) ?? Web()
        self.admin = try container.decodeIfPresent(Admin.self, forKey: .admin) ?? Admin()
    }
}

extension ServerConfiguration.DICOM: Codable {
    enum CodingKeys: String, CodingKey {
        case aeTitle, port, maxAssociations, tlsEnabled, tlsCertificatePath, tlsKeyPath
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.aeTitle = try container.decodeIfPresent(String.self, forKey: .aeTitle) ?? "MAYAM"
        self.port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 11112
        self.maxAssociations = try container.decodeIfPresent(Int.self, forKey: .maxAssociations) ?? 64
        self.tlsEnabled = try container.decodeIfPresent(Bool.self, forKey: .tlsEnabled) ?? false
        self.tlsCertificatePath = try container.decodeIfPresent(String.self, forKey: .tlsCertificatePath)
        self.tlsKeyPath = try container.decodeIfPresent(String.self, forKey: .tlsKeyPath)
    }
}

extension ServerConfiguration.Storage: Codable {
    enum CodingKeys: String, CodingKey {
        case archivePath, checksumEnabled, policy
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.archivePath = try container.decodeIfPresent(String.self, forKey: .archivePath) ?? "/var/lib/mayam/archive"
        self.checksumEnabled = try container.decodeIfPresent(Bool.self, forKey: .checksumEnabled) ?? true
        self.policy = try container.decodeIfPresent(StoragePolicy.self, forKey: .policy) ?? .default
    }
}

extension ServerConfiguration.Log: Codable {
    enum CodingKeys: String, CodingKey {
        case level
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.level = try container.decodeIfPresent(String.self, forKey: .level) ?? "info"
    }
}

extension ServerConfiguration.Codec: Codable {
    enum CodingKeys: String, CodingKey {
        case onDemandTranscodingEnabled, backgroundTranscodingEnabled, maxConcurrentTranscodings
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.onDemandTranscodingEnabled = try container.decodeIfPresent(Bool.self, forKey: .onDemandTranscodingEnabled) ?? true
        self.backgroundTranscodingEnabled = try container.decodeIfPresent(Bool.self, forKey: .backgroundTranscodingEnabled) ?? false
        self.maxConcurrentTranscodings = try container.decodeIfPresent(Int.self, forKey: .maxConcurrentTranscodings) ?? 4
    }
}

extension ServerConfiguration.Web: Codable {
    enum CodingKeys: String, CodingKey {
        case port, tlsEnabled, tlsCertificatePath, tlsKeyPath, basePath
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 8080
        self.tlsEnabled = try container.decodeIfPresent(Bool.self, forKey: .tlsEnabled) ?? false
        self.tlsCertificatePath = try container.decodeIfPresent(String.self, forKey: .tlsCertificatePath)
        self.tlsKeyPath = try container.decodeIfPresent(String.self, forKey: .tlsKeyPath)
        self.basePath = try container.decodeIfPresent(String.self, forKey: .basePath) ?? ""
    }
}

extension ServerConfiguration.Admin: Codable {
    enum CodingKeys: String, CodingKey {
        case port, tlsEnabled, tlsCertificatePath, tlsKeyPath,
             jwtSecret, sessionExpirySeconds, setupCompleted
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 8081
        self.tlsEnabled = try container.decodeIfPresent(Bool.self, forKey: .tlsEnabled) ?? false
        self.tlsCertificatePath = try container.decodeIfPresent(String.self, forKey: .tlsCertificatePath)
        self.tlsKeyPath = try container.decodeIfPresent(String.self, forKey: .tlsKeyPath)
        self.jwtSecret = try container.decodeIfPresent(String.self, forKey: .jwtSecret) ?? "change-me-in-production"
        self.sessionExpirySeconds = try container.decodeIfPresent(Int.self, forKey: .sessionExpirySeconds) ?? 3600
        self.setupCompleted = try container.decodeIfPresent(Bool.self, forKey: .setupCompleted) ?? false
    }
}
