// SPDX-License-Identifier: (see LICENSE)
// Mayam — Backup Configuration Model

import Foundation

// MARK: - BackupTargetType

/// Defines the type of backup destination.
public enum BackupTargetType: String, Sendable, Codable, Equatable, CaseIterable {

    /// A local directory or external drive.
    case local

    /// A network share (SMB or NFS).
    case network

    /// An S3-compatible object storage endpoint.
    case s3
}

// MARK: - BackupTarget

/// A configured backup destination.
///
/// Each target defines where backup data is written and what type of
/// storage it uses.
public struct BackupTarget: Sendable, Codable, Equatable, Identifiable {

    /// Unique identifier for this backup target.
    public let id: UUID

    /// Human-readable name for the target.
    public var name: String

    /// The type of backup destination.
    public var targetType: BackupTargetType

    /// The destination path or URI:
    /// - For `local`: an absolute directory path.
    /// - For `network`: a UNC path (e.g. `//server/share/path`).
    /// - For `s3`: an S3 bucket URI (e.g. `s3://bucket-name/prefix`).
    public var destinationPath: String

    /// Whether this target is enabled for scheduled backups.
    public var enabled: Bool

    /// Creates a backup target.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (default: auto-generated).
    ///   - name: Human-readable name.
    ///   - targetType: The type of backup destination.
    ///   - destinationPath: The destination path or URI.
    ///   - enabled: Whether this target is enabled (default: `true`).
    public init(
        id: UUID = UUID(),
        name: String,
        targetType: BackupTargetType,
        destinationPath: String,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.targetType = targetType
        self.destinationPath = destinationPath
        self.enabled = enabled
    }
}

// MARK: - BackupSchedule

/// Defines the schedule for automated backups.
public struct BackupSchedule: Sendable, Codable, Equatable {

    /// Interval in seconds between scheduled backup runs.
    public var intervalSeconds: Int

    /// Whether to include the metadata database in backups.
    public var includeDatabase: Bool

    /// Whether to include DICOM objects in backups.
    public var includeDICOMObjects: Bool

    /// Creates a backup schedule.
    ///
    /// - Parameters:
    ///   - intervalSeconds: Interval between runs in seconds (default: 86400 = 24 hours).
    ///   - includeDatabase: Whether to backup the database (default: `true`).
    ///   - includeDICOMObjects: Whether to backup DICOM objects (default: `true`).
    public init(
        intervalSeconds: Int = 86_400,
        includeDatabase: Bool = true,
        includeDICOMObjects: Bool = true
    ) {
        self.intervalSeconds = intervalSeconds
        self.includeDatabase = includeDatabase
        self.includeDICOMObjects = includeDICOMObjects
    }
}

// MARK: - BackupConfiguration

/// Configuration for the backup subsystem.
public struct BackupConfiguration: Sendable, Codable, Equatable {

    /// Whether the backup subsystem is enabled.
    public var enabled: Bool

    /// Configured backup targets.
    public var targets: [BackupTarget]

    /// The backup schedule for automated runs.
    public var schedule: BackupSchedule

    /// The default backup configuration (disabled, no targets).
    public static let `default` = BackupConfiguration(
        enabled: false,
        targets: [],
        schedule: BackupSchedule()
    )

    /// Creates a backup configuration.
    ///
    /// - Parameters:
    ///   - enabled: Whether the backup subsystem is enabled (default: `false`).
    ///   - targets: Backup targets (default: empty).
    ///   - schedule: Backup schedule (default: daily).
    public init(
        enabled: Bool = false,
        targets: [BackupTarget] = [],
        schedule: BackupSchedule = BackupSchedule()
    ) {
        self.enabled = enabled
        self.targets = targets
        self.schedule = schedule
    }
}

// MARK: - BackupRecord

/// Records the result of a single backup operation.
public struct BackupRecord: Sendable, Codable, Equatable, Identifiable {

    /// Unique identifier for this backup record.
    public let id: UUID

    /// The ID of the backup target used.
    public let targetID: UUID

    /// When the backup started.
    public let startedAt: Date

    /// When the backup completed, or `nil` if still running.
    public var completedAt: Date?

    /// Total number of objects backed up.
    public var objectCount: Int

    /// Total size of the backup in bytes.
    public var sizeBytes: Int64

    /// Status of the backup operation.
    public var status: BackupStatus

    /// Error message if the backup failed.
    public var errorMessage: String?

    /// Creates a backup record.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (default: auto-generated).
    ///   - targetID: The target ID.
    ///   - startedAt: Start timestamp.
    ///   - completedAt: Completion timestamp (optional).
    ///   - objectCount: Number of objects backed up (default: 0).
    ///   - sizeBytes: Total backup size in bytes (default: 0).
    ///   - status: Status of the backup (default: `.running`).
    ///   - errorMessage: Error message if failed (default: `nil`).
    public init(
        id: UUID = UUID(),
        targetID: UUID,
        startedAt: Date,
        completedAt: Date? = nil,
        objectCount: Int = 0,
        sizeBytes: Int64 = 0,
        status: BackupStatus = .running,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.targetID = targetID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.objectCount = objectCount
        self.sizeBytes = sizeBytes
        self.status = status
        self.errorMessage = errorMessage
    }
}

// MARK: - BackupStatus

/// Status of a backup operation.
public enum BackupStatus: String, Sendable, Codable, Equatable, CaseIterable {
    /// The backup is currently running.
    case running
    /// The backup completed successfully.
    case completed
    /// The backup failed.
    case failed
    /// The backup was cancelled.
    case cancelled
}
