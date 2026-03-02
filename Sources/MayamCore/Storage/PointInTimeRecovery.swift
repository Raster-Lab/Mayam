// SPDX-License-Identifier: (see LICENSE)
// Mayam — Point-in-Time Recovery

import Foundation

// MARK: - PointInTimeRecovery

/// Manages metadata database snapshots for point-in-time recovery.
///
/// The recovery manager creates periodic snapshots of the metadata database
/// and supports restoring to a specific snapshot. Snapshots are stored as
/// timestamped copies of the database file.
///
/// Reference: Milestone 9 — Point-in-Time Recovery
public actor PointInTimeRecovery {

    // MARK: - Nested Types

    /// A record describing a single database snapshot.
    public struct Snapshot: Sendable, Codable, Equatable, Identifiable {

        /// Unique identifier for this snapshot.
        public let id: UUID

        /// When the snapshot was created.
        public let createdAt: Date

        /// File-system path to the snapshot file.
        public let filePath: String

        /// Size of the snapshot in bytes.
        public let sizeBytes: Int64

        /// Optional label for the snapshot.
        public let label: String?

        /// Creates a snapshot record.
        public init(
            id: UUID = UUID(),
            createdAt: Date,
            filePath: String,
            sizeBytes: Int64,
            label: String? = nil
        ) {
            self.id = id
            self.createdAt = createdAt
            self.filePath = filePath
            self.sizeBytes = sizeBytes
            self.label = label
        }
    }

    // MARK: - Stored Properties

    /// Directory where snapshots are stored.
    private let snapshotDirectory: String

    /// Path to the live database file.
    private let databasePath: String

    /// Logger for recovery events.
    private let logger: MayamLogger

    /// Index of available snapshots.
    private var snapshots: [Snapshot] = []

    /// Maximum number of snapshots to retain.
    private let maxSnapshots: Int

    // MARK: - Initialiser

    /// Creates a new point-in-time recovery manager.
    ///
    /// - Parameters:
    ///   - snapshotDirectory: Directory where snapshots are stored.
    ///   - databasePath: Path to the live database file.
    ///   - maxSnapshots: Maximum number of snapshots to retain (default: 10).
    ///   - logger: Logger instance for recovery events.
    public init(
        snapshotDirectory: String,
        databasePath: String,
        maxSnapshots: Int = 10,
        logger: MayamLogger
    ) {
        self.snapshotDirectory = snapshotDirectory
        self.databasePath = databasePath
        self.maxSnapshots = maxSnapshots
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Creates a snapshot of the current database state.
    ///
    /// - Parameter label: Optional human-readable label for the snapshot.
    /// - Returns: The created ``Snapshot`` record.
    /// - Throws: ``RecoveryError`` if the snapshot cannot be created.
    public func createSnapshot(label: String? = nil) throws -> Snapshot {
        let fm = FileManager.default

        // Ensure snapshot directory exists
        if !fm.fileExists(atPath: snapshotDirectory) {
            try fm.createDirectory(
                atPath: snapshotDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Verify the source database exists
        guard fm.fileExists(atPath: databasePath) else {
            throw RecoveryError.databaseNotFound(path: databasePath)
        }

        let now = Date()
        let timestamp = ISO8601DateFormatter().string(from: now)
            .replacingOccurrences(of: ":", with: "-")
        let uniqueSuffix = UUID().uuidString.prefix(8)
        let snapshotPath = snapshotDirectory + "/snapshot-" + timestamp + "-" + uniqueSuffix + ".db"

        do {
            try fm.copyItem(atPath: databasePath, toPath: snapshotPath)
        } catch {
            throw RecoveryError.snapshotFailed(reason: error.localizedDescription)
        }

        let fileSize: Int64 = {
            guard let attrs = try? fm.attributesOfItem(atPath: snapshotPath),
                  let size = attrs[.size] as? Int64 else { return 0 }
            return size
        }()

        let snapshot = Snapshot(
            createdAt: now,
            filePath: snapshotPath,
            sizeBytes: fileSize,
            label: label
        )
        snapshots.append(snapshot)

        // Prune old snapshots if over the limit
        pruneExcessSnapshots()

        logger.info("PITR: Created snapshot at '\(snapshotPath)' (\(fileSize) bytes)")
        return snapshot
    }

    /// Returns all available snapshots, newest first.
    public func listSnapshots() -> [Snapshot] {
        snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    /// Returns the number of available snapshots.
    public func snapshotCount() -> Int {
        snapshots.count
    }

    /// Restores the database from a specific snapshot.
    ///
    /// - Parameter snapshotID: The ID of the snapshot to restore.
    /// - Throws: ``RecoveryError`` if the restore fails.
    public func restore(from snapshotID: UUID) throws {
        guard let snapshot = snapshots.first(where: { $0.id == snapshotID }) else {
            throw RecoveryError.snapshotNotFound(id: snapshotID)
        }

        let fm = FileManager.default

        guard fm.fileExists(atPath: snapshot.filePath) else {
            throw RecoveryError.snapshotFileNotFound(path: snapshot.filePath)
        }

        // Create a backup of the current database before restoring
        let backupPath = databasePath + ".pre-restore"
        if fm.fileExists(atPath: backupPath) {
            try fm.removeItem(atPath: backupPath)
        }

        if fm.fileExists(atPath: databasePath) {
            do {
                try fm.copyItem(atPath: databasePath, toPath: backupPath)
            } catch {
                throw RecoveryError.restoreFailed(reason: "Failed to backup current database: \(error.localizedDescription)")
            }
        }

        // Replace the current database with the snapshot
        do {
            if fm.fileExists(atPath: databasePath) {
                try fm.removeItem(atPath: databasePath)
            }
            try fm.copyItem(atPath: snapshot.filePath, toPath: databasePath)
        } catch {
            // Attempt to recover from the backup
            if fm.fileExists(atPath: backupPath) {
                try? fm.copyItem(atPath: backupPath, toPath: databasePath)
            }
            throw RecoveryError.restoreFailed(reason: error.localizedDescription)
        }

        logger.info("PITR: Restored database from snapshot '\(snapshot.id)' (created \(snapshot.createdAt))")
    }

    // MARK: - Private Helpers

    /// Removes the oldest snapshots when the count exceeds `maxSnapshots`.
    private func pruneExcessSnapshots() {
        guard snapshots.count > maxSnapshots else { return }

        let sorted = snapshots.sorted { $0.createdAt < $1.createdAt }
        let toRemove = sorted.prefix(snapshots.count - maxSnapshots)

        for snapshot in toRemove {
            try? FileManager.default.removeItem(atPath: snapshot.filePath)
            snapshots.removeAll { $0.id == snapshot.id }
        }

        logger.info("PITR: Pruned \(toRemove.count) old snapshot(s), \(snapshots.count) remaining")
    }
}

// MARK: - RecoveryError

/// Errors that may occur during point-in-time recovery operations.
public enum RecoveryError: Error, Sendable, CustomStringConvertible {

    /// The source database file was not found.
    case databaseNotFound(path: String)

    /// A snapshot creation failed.
    case snapshotFailed(reason: String)

    /// The requested snapshot was not found.
    case snapshotNotFound(id: UUID)

    /// The snapshot file was not found on disk.
    case snapshotFileNotFound(path: String)

    /// A restore operation failed.
    case restoreFailed(reason: String)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .databaseNotFound(let path):
            return "Database file not found: '\(path)'"
        case .snapshotFailed(let reason):
            return "Snapshot creation failed: \(reason)"
        case .snapshotNotFound(let id):
            return "Snapshot '\(id)' not found"
        case .snapshotFileNotFound(let path):
            return "Snapshot file not found: '\(path)'"
        case .restoreFailed(let reason):
            return "Database restore failed: \(reason)"
        }
    }
}
