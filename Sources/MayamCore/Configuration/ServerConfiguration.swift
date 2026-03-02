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

    /// LDAP / Active Directory integration configuration.
    public struct LDAP: Sendable, Equatable {

        /// Schema-mapping configuration for an LDAP directory.
        public struct Schema: Sendable, Equatable {
            /// Attribute used as the login username (`uid` for OpenLDAP,
            /// `sAMAccountName` for Active Directory).
            public var usernameAttribute: String
            /// Attribute containing the user's e-mail address (typically `mail`).
            public var emailAttribute: String
            /// Attribute containing the user's display name (typically `cn`).
            public var displayNameAttribute: String
            /// Attribute listing group DNs the user is a member of (typically `memberOf`).
            public var memberOfAttribute: String
            /// DN of the group whose members receive the `.administrator` role.
            public var adminGroupDN: String
            /// DN of the group whose members receive the `.technologist` role.
            public var techGroupDN: String
            /// DN of the group whose members receive the `.physician` role.
            public var physicianGroupDN: String
            /// DN of the group whose members receive the `.auditor` role.
            public var auditorGroupDN: String

            /// Creates a schema mapping.
            ///
            /// - Parameters:
            ///   - usernameAttribute: Username attribute name.
            ///   - emailAttribute: E-mail attribute name.
            ///   - displayNameAttribute: Display name attribute name.
            ///   - memberOfAttribute: Group membership attribute name.
            ///   - adminGroupDN: Administrator group DN.
            ///   - techGroupDN: Technologist group DN.
            ///   - physicianGroupDN: Physician group DN.
            ///   - auditorGroupDN: Auditor group DN.
            public init(
                usernameAttribute: String = "uid",
                emailAttribute: String = "mail",
                displayNameAttribute: String = "cn",
                memberOfAttribute: String = "memberOf",
                adminGroupDN: String = "",
                techGroupDN: String = "",
                physicianGroupDN: String = "",
                auditorGroupDN: String = ""
            ) {
                self.usernameAttribute = usernameAttribute
                self.emailAttribute = emailAttribute
                self.displayNameAttribute = displayNameAttribute
                self.memberOfAttribute = memberOfAttribute
                self.adminGroupDN = adminGroupDN
                self.techGroupDN = techGroupDN
                self.physicianGroupDN = physicianGroupDN
                self.auditorGroupDN = auditorGroupDN
            }
        }

        /// Whether LDAP integration is enabled.
        public var enabled: Bool
        /// Hostname or IP address of the LDAP server.
        public var host: String
        /// TCP port of the LDAP server (389 for plain, 636 for LDAPS).
        public var port: Int
        /// Whether to use TLS (LDAPS or StartTLS) for the connection.
        public var useTLS: Bool
        /// Distinguished Name used to bind when searching for user entries.
        public var serviceBindDN: String
        /// Password for the service bind DN.
        public var serviceBindPassword: String
        /// Base DN under which user searches are performed.
        public var baseDN: String
        /// LDAP search filter template; `%s` is replaced with the username.
        /// Example: `(objectClass=person)`.
        public var userSearchFilter: String
        /// Base DN under which group searches are performed.
        public var groupSearchBase: String
        /// Directory schema mapping configuration.
        public var schema: Schema

        /// Creates an LDAP configuration.
        public init(
            enabled: Bool = false,
            host: String = "",
            port: Int = 389,
            useTLS: Bool = false,
            serviceBindDN: String = "",
            serviceBindPassword: String = "",
            baseDN: String = "",
            userSearchFilter: String = "(objectClass=person)",
            groupSearchBase: String = "",
            schema: Schema = Schema()
        ) {
            self.enabled = enabled
            self.host = host
            self.port = port
            self.useTLS = useTLS
            self.serviceBindDN = serviceBindDN
            self.serviceBindPassword = serviceBindPassword
            self.baseDN = baseDN
            self.userSearchFilter = userSearchFilter
            self.groupSearchBase = groupSearchBase
            self.schema = schema
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

    /// LDAP / Active Directory integration settings.
    public var ldap: LDAP

    // MARK: - Initialiser

    public init(
        dicom: DICOM = DICOM(),
        storage: Storage = Storage(),
        log: Log = Log(),
        codec: Codec = Codec(),
        web: Web = Web(),
        admin: Admin = Admin(),
        ldap: LDAP = LDAP()
    ) {
        self.dicom = dicom
        self.storage = storage
        self.log = log
        self.codec = codec
        self.web = web
        self.admin = admin
        self.ldap = ldap
    }
}

// MARK: - Codable Conformance with Defaults

extension ServerConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case dicom, storage, log, codec, web, admin, ldap
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dicom = try container.decodeIfPresent(DICOM.self, forKey: .dicom) ?? DICOM()
        self.storage = try container.decodeIfPresent(Storage.self, forKey: .storage) ?? Storage()
        self.log = try container.decodeIfPresent(Log.self, forKey: .log) ?? Log()
        self.codec = try container.decodeIfPresent(Codec.self, forKey: .codec) ?? Codec()
        self.web = try container.decodeIfPresent(Web.self, forKey: .web) ?? Web()
        self.admin = try container.decodeIfPresent(Admin.self, forKey: .admin) ?? Admin()
        self.ldap = try container.decodeIfPresent(LDAP.self, forKey: .ldap) ?? LDAP()
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

extension ServerConfiguration.LDAP.Schema: Codable {
    enum CodingKeys: String, CodingKey {
        case usernameAttribute, emailAttribute, displayNameAttribute, memberOfAttribute
        case adminGroupDN, techGroupDN, physicianGroupDN, auditorGroupDN
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.usernameAttribute    = try c.decodeIfPresent(String.self, forKey: .usernameAttribute)    ?? "uid"
        self.emailAttribute       = try c.decodeIfPresent(String.self, forKey: .emailAttribute)       ?? "mail"
        self.displayNameAttribute = try c.decodeIfPresent(String.self, forKey: .displayNameAttribute) ?? "cn"
        self.memberOfAttribute    = try c.decodeIfPresent(String.self, forKey: .memberOfAttribute)    ?? "memberOf"
        self.adminGroupDN         = try c.decodeIfPresent(String.self, forKey: .adminGroupDN)         ?? ""
        self.techGroupDN          = try c.decodeIfPresent(String.self, forKey: .techGroupDN)          ?? ""
        self.physicianGroupDN     = try c.decodeIfPresent(String.self, forKey: .physicianGroupDN)     ?? ""
        self.auditorGroupDN       = try c.decodeIfPresent(String.self, forKey: .auditorGroupDN)       ?? ""
    }
}

extension ServerConfiguration.LDAP: Codable {
    enum CodingKeys: String, CodingKey {
        case enabled, host, port, useTLS, serviceBindDN, serviceBindPassword
        case baseDN, userSearchFilter, groupSearchBase, schema
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled             = try c.decodeIfPresent(Bool.self,   forKey: .enabled)             ?? false
        self.host                = try c.decodeIfPresent(String.self, forKey: .host)                ?? ""
        self.port                = try c.decodeIfPresent(Int.self,    forKey: .port)                ?? 389
        self.useTLS              = try c.decodeIfPresent(Bool.self,   forKey: .useTLS)              ?? false
        self.serviceBindDN       = try c.decodeIfPresent(String.self, forKey: .serviceBindDN)       ?? ""
        self.serviceBindPassword = try c.decodeIfPresent(String.self, forKey: .serviceBindPassword) ?? ""
        self.baseDN              = try c.decodeIfPresent(String.self, forKey: .baseDN)              ?? ""
        self.userSearchFilter    = try c.decodeIfPresent(String.self, forKey: .userSearchFilter)    ?? "(objectClass=person)"
        self.groupSearchBase     = try c.decodeIfPresent(String.self, forKey: .groupSearchBase)     ?? ""
        self.schema              = try c.decodeIfPresent(Schema.self, forKey: .schema)              ?? Schema()
    }
}
