// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin API Models

import Foundation
import MayamCore

// MARK: - DicomNode

/// A remote DICOM Application Entity (AE) node record.
///
/// Represents a known peer AE for C-ECHO verification, C-MOVE destinations,
/// and other DICOM network operations.
public struct DicomNode: Identifiable, Codable, Sendable, Equatable {

    // MARK: - Stored Properties

    /// Unique identifier for this node record.
    public let id: UUID
    /// DICOM Application Entity Title.
    public let aeTitle: String
    /// Hostname or IP address of the remote AE.
    public let host: String
    /// TCP port of the remote AE.
    public let port: Int
    /// Optional human-readable description.
    public let description: String?
    /// Whether TLS is required for connections to this node.
    public let tlsEnabled: Bool
    /// Timestamp at which this record was created.
    public let createdAt: Date
    /// Timestamp at which this record was last updated.
    public let updatedAt: Date

    // MARK: - Initialisers

    /// Creates a new node record with an auto-generated identifier and current timestamps.
    ///
    /// - Parameters:
    ///   - aeTitle: DICOM AE Title.
    ///   - host: Hostname or IP address.
    ///   - port: TCP port number.
    ///   - description: Optional human-readable description.
    ///   - tlsEnabled: Whether TLS is required.
    public init(
        aeTitle: String,
        host: String,
        port: Int,
        description: String? = nil,
        tlsEnabled: Bool = false
    ) {
        self.id = UUID()
        self.aeTitle = aeTitle
        self.host = host
        self.port = port
        self.description = description
        self.tlsEnabled = tlsEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Creates a node record with explicit values for all fields.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - aeTitle: DICOM AE Title.
    ///   - host: Hostname or IP address.
    ///   - port: TCP port number.
    ///   - description: Optional human-readable description.
    ///   - tlsEnabled: Whether TLS is required.
    ///   - createdAt: Creation timestamp.
    ///   - updatedAt: Last-updated timestamp.
    public init(
        id: UUID,
        aeTitle: String,
        host: String,
        port: Int,
        description: String? = nil,
        tlsEnabled: Bool = false,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.aeTitle = aeTitle
        self.host = host
        self.port = port
        self.description = description
        self.tlsEnabled = tlsEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - AdminUser

/// An administrative user record stored in the server's user directory.
public struct AdminUser: Codable, Sendable {
    /// Login username.
    public let username: String
    /// SHA-256 hex digest of the user's password.
    public let passwordHash: String
    /// Role governing the user's permissions.
    public let role: AdminRole

    /// Creates a new admin user record.
    ///
    /// - Parameters:
    ///   - username: Login username.
    ///   - passwordHash: SHA-256 hex digest of the password.
    ///   - role: Role governing the user's permissions.
    public init(username: String, passwordHash: String, role: AdminRole) {
        self.username = username
        self.passwordHash = passwordHash
        self.role = role
    }
}

// MARK: - AdminLoginRequest

/// A login request body for the admin authentication endpoint.
public struct AdminLoginRequest: Codable, Sendable {
    /// Login username.
    public let username: String
    /// Plaintext password (transmitted over TLS).
    public let password: String

    /// Creates a new login request.
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

// MARK: - AdminLoginResponse

/// A successful login response containing a JWT session token.
public struct AdminLoginResponse: Codable, Sendable {
    /// The JWT bearer token.
    public let token: String
    /// Token expiry timestamp (ISO 8601).
    public let expiresAt: Date
    /// Authenticated username.
    public let username: String
    /// Role of the authenticated user.
    public let role: AdminRole

    /// Creates a new login response.
    public init(token: String, expiresAt: Date, username: String, role: AdminRole) {
        self.token = token
        self.expiresAt = expiresAt
        self.username = username
        self.role = role
    }
}

// MARK: - SetupStatus

/// Current state of the first-run setup wizard.
public struct SetupStatus: Codable, Sendable {
    /// Whether the setup wizard has been completed.
    public let completed: Bool
    /// Current step index (zero-based).
    public let setupStep: Int
    /// Total number of setup steps.
    public let totalSteps: Int

    /// Creates a new setup status value.
    public init(completed: Bool, setupStep: Int, totalSteps: Int = 5) {
        self.completed = completed
        self.setupStep = setupStep
        self.totalSteps = totalSteps
    }
}

// MARK: - DashboardStats

/// Aggregated statistics for the admin dashboard.
public struct DashboardStats: Codable, Sendable {
    /// Current Mayam server version string.
    public let serverVersion: String
    /// Server uptime in seconds.
    public let uptimeSeconds: Double
    /// Number of currently active DICOM associations.
    public let activeAssociations: Int
    /// Total number of DICOM instances stored in the archive.
    public let totalStoredInstances: Int
    /// Archive storage used, in bytes.
    public let storageUsedBytes: Int64
    /// Archive storage free, in bytes.
    public let storageFreeBytes: Int64
    /// Recent activity entries (up to 10).
    public let recentActivity: [ActivityEntry]

    /// Creates a new dashboard statistics snapshot.
    public init(
        serverVersion: String,
        uptimeSeconds: Double,
        activeAssociations: Int,
        totalStoredInstances: Int,
        storageUsedBytes: Int64,
        storageFreeBytes: Int64,
        recentActivity: [ActivityEntry]
    ) {
        self.serverVersion = serverVersion
        self.uptimeSeconds = uptimeSeconds
        self.activeAssociations = activeAssociations
        self.totalStoredInstances = totalStoredInstances
        self.storageUsedBytes = storageUsedBytes
        self.storageFreeBytes = storageFreeBytes
        self.recentActivity = recentActivity
    }
}

// MARK: - ActivityEntry

/// A single server activity log entry shown on the dashboard.
public struct ActivityEntry: Codable, Sendable {
    /// When the activity occurred.
    public let timestamp: Date
    /// Short event type identifier (e.g. `"store"`, `"query"`, `"login"`).
    public let event: String
    /// Human-readable detail string.
    public let detail: String

    /// Creates a new activity entry.
    public init(timestamp: Date, event: String, detail: String) {
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

// MARK: - StoragePool

/// Describes a storage pool available to the archive.
public struct StoragePool: Codable, Sendable {
    /// Human-readable pool name.
    public let name: String
    /// File-system path of the pool root.
    public let path: String
    /// Total capacity of the pool, in bytes.
    public let totalBytes: Int64
    /// Used capacity of the pool, in bytes.
    public let usedBytes: Int64
    /// Free capacity of the pool, in bytes.
    public let freeBytes: Int64
    /// Storage tier label (e.g. `"online"`, `"nearline"`).
    public let tier: String

    /// Creates a new storage pool descriptor.
    public init(name: String, path: String, totalBytes: Int64, usedBytes: Int64, freeBytes: Int64, tier: String) {
        self.name = name
        self.path = path
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.tier = tier
    }
}

// MARK: - IntegrityCheckResult

/// Result of an archive integrity check operation.
public struct IntegrityCheckResult: Codable, Sendable {
    /// When the check began.
    public let startedAt: Date
    /// When the check completed, or `nil` if still running.
    public let completedAt: Date?
    /// Number of DICOM instances examined.
    public let checkedCount: Int
    /// Number of instances with detected errors.
    public let errorCount: Int
    /// Status string (e.g. `"running"`, `"complete"`, `"failed"`).
    public let status: String

    /// Creates a new integrity check result.
    public init(startedAt: Date, completedAt: Date?, checkedCount: Int, errorCount: Int, status: String) {
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.checkedCount = checkedCount
        self.errorCount = errorCount
        self.status = status
    }
}

// MARK: - LogEntry

/// A single structured log entry.
public struct LogEntry: Codable, Sendable {
    /// When the log entry was emitted.
    public let timestamp: Date
    /// Log level string (e.g. `"info"`, `"error"`).
    public let level: String
    /// Logger label (reverse-DNS subsystem identifier).
    public let label: String
    /// Human-readable log message.
    public let message: String

    /// Creates a new log entry.
    public init(timestamp: Date, level: String, label: String, message: String) {
        self.timestamp = timestamp
        self.level = level
        self.label = label
        self.message = message
    }
}

// MARK: - ChangePasswordRequest

/// Request body for changing a user's password.
public struct ChangePasswordRequest: Codable, Sendable {
    /// The user's current plaintext password.
    public let oldPassword: String
    /// The desired new plaintext password.
    public let newPassword: String

    /// Creates a change-password request.
    public init(oldPassword: String, newPassword: String) {
        self.oldPassword = oldPassword
        self.newPassword = newPassword
    }
}

// MARK: - AdminAPIResponse

/// A minimal API response envelope indicating success or failure.
///
/// Use typed response bodies per endpoint; this struct is returned when there
/// is no data payload (e.g. delete operations or error responses).
public struct AdminAPIResponse: Codable, Sendable {
    /// Whether the operation succeeded.
    public let success: Bool
    /// Error message if `success` is `false`, otherwise `nil`.
    public let error: String?

    /// Creates a success response with no error.
    public static func ok() -> AdminAPIResponse {
        AdminAPIResponse(success: true, error: nil)
    }

    /// Creates a failure response with the given error message.
    ///
    /// - Parameter message: Human-readable error description.
    /// - Returns: A failure response.
    public static func failure(_ message: String) -> AdminAPIResponse {
        AdminAPIResponse(success: false, error: message)
    }

    /// Creates a new API response.
    public init(success: Bool, error: String?) {
        self.success = success
        self.error = error
    }
}
