// SPDX-License-Identifier: (see LICENSE)
// Mayam — Backup Manager

import Foundation
import Crypto

// MARK: - BackupManager

/// Manages scheduled and on-demand backup operations for the PACS archive.
///
/// The backup manager supports three types of backup targets:
/// - **Local** — copy to a local directory or external drive.
/// - **Network** — copy to a network share (SMB/NFS).
/// - **S3** — upload to an S3-compatible object storage endpoint.
///
/// Backups include both DICOM object files and metadata database snapshots
/// (when configured).
///
/// Reference: Milestone 9 — Scheduled and On-Demand Backup
public actor BackupManager {

    // MARK: - Stored Properties

    /// Backup configuration.
    private let configuration: BackupConfiguration

    /// Root path of the DICOM archive to back up.
    private let archivePath: String

    /// Logger for backup events.
    private let logger: MayamLogger

    /// History of backup records.
    private var backupHistory: [BackupRecord] = []

    /// Whether a backup is currently in progress.
    private var isRunning: Bool = false

    // MARK: - Initialiser

    /// Creates a new backup manager.
    ///
    /// - Parameters:
    ///   - configuration: Backup configuration defining targets and schedule.
    ///   - archivePath: Root path of the DICOM archive.
    ///   - logger: Logger instance for backup events.
    public init(
        configuration: BackupConfiguration,
        archivePath: String,
        logger: MayamLogger
    ) {
        self.configuration = configuration
        self.archivePath = archivePath
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Runs an on-demand backup to the specified target.
    ///
    /// Copies DICOM objects from the archive to the backup target.
    ///
    /// - Parameter target: The backup target to write to.
    /// - Returns: A ``BackupRecord`` describing the backup result.
    /// - Throws: ``BackupError`` if the backup fails.
    public func runBackup(to target: BackupTarget) async throws -> BackupRecord {
        guard !isRunning else {
            throw BackupError.backupAlreadyRunning
        }

        isRunning = true
        defer { isRunning = false }

        let startedAt = Date()
        var record = BackupRecord(
            targetID: target.id,
            startedAt: startedAt,
            status: .running
        )

        logger.info("Backup: Starting backup to '\(target.name)' (\(target.targetType.rawValue))")

        do {
            let result = try await performBackup(to: target)
            record.objectCount = result.objectCount
            record.sizeBytes = result.sizeBytes
            record.completedAt = Date()
            record.status = .completed
            backupHistory.append(record)

            logger.info("Backup: Completed to '\(target.name)' — \(result.objectCount) objects, \(result.sizeBytes) bytes")
            return record

        } catch {
            record.completedAt = Date()
            record.status = .failed
            record.errorMessage = error.localizedDescription
            backupHistory.append(record)

            logger.error("Backup: Failed to '\(target.name)': \(error)")
            throw error
        }
    }

    /// Runs backups to all enabled targets in the configuration.
    ///
    /// - Returns: An array of ``BackupRecord`` results, one per target.
    public func runScheduledBackups() async -> [BackupRecord] {
        let enabledTargets = configuration.targets.filter(\.enabled)
        var records: [BackupRecord] = []

        for target in enabledTargets {
            do {
                let record = try await runBackup(to: target)
                records.append(record)
            } catch {
                logger.error("Backup: Scheduled backup to '\(target.name)' failed: \(error)")
            }
        }

        return records
    }

    /// Returns the backup history.
    public func getBackupHistory() -> [BackupRecord] {
        backupHistory
    }

    /// Returns the count of completed backups.
    public func completedBackupCount() -> Int {
        backupHistory.filter { $0.status == .completed }.count
    }

    /// Returns whether a backup is currently running.
    public func isBackupRunning() -> Bool {
        isRunning
    }

    // MARK: - Private Helpers

    /// Performs the actual backup to a target.
    private func performBackup(
        to target: BackupTarget
    ) async throws -> (objectCount: Int, sizeBytes: Int64) {
        switch target.targetType {
        case .local:
            return try await performLocalBackup(to: target.destinationPath)
        case .network:
            return try await performNetworkBackup(to: target.destinationPath)
        case .s3:
            return try await performS3Backup(to: target.destinationPath)
        }
    }

    /// Performs a local directory backup.
    private func performLocalBackup(
        to destinationPath: String
    ) async throws -> (objectCount: Int, sizeBytes: Int64) {
        let fm = FileManager.default

        // Validate destination
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: destinationPath, isDirectory: &isDir) {
            try fm.createDirectory(
                atPath: destinationPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Create a timestamped backup subdirectory
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupDir = destinationPath + "/backup-" + timestamp

        try fm.createDirectory(
            atPath: backupDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        var objectCount = 0
        var totalSize: Int64 = 0

        // Walk the archive directory and copy .dcm files
        guard let enumerator = fm.enumerator(atPath: archivePath) else {
            throw BackupError.sourceNotAccessible(path: archivePath)
        }

        let dcmPaths = enumerator.allObjects.compactMap { $0 as? String }.filter { $0.hasSuffix(".dcm") }
        for relativePath in dcmPaths {
            let sourcePath = archivePath + "/" + relativePath
            let destPath = backupDir + "/" + relativePath

            // Ensure parent directory exists
            let destDir = (destPath as NSString).deletingLastPathComponent
            if !fm.fileExists(atPath: destDir) {
                try fm.createDirectory(
                    atPath: destDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            try fm.copyItem(atPath: sourcePath, toPath: destPath)

            if let attrs = try? fm.attributesOfItem(atPath: destPath),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
            objectCount += 1
        }

        return (objectCount: objectCount, sizeBytes: totalSize)
    }

    /// Performs a network share backup.
    ///
    /// Network shares (SMB/NFS) are expected to be pre-mounted at the
    /// specified path. The backup is performed as a local copy to the
    /// mounted share path.
    private func performNetworkBackup(
        to destinationPath: String
    ) async throws -> (objectCount: Int, sizeBytes: Int64) {
        // Network shares are expected to be mounted; delegate to local backup
        return try await performLocalBackup(to: destinationPath)
    }

    /// Performs an S3-compatible object storage backup.
    ///
    /// > Note: Full S3 integration requires an S3 client library.
    /// > This implementation creates a local staging directory as a
    /// > placeholder; production deployments should use an S3 SDK.
    private func performS3Backup(
        to destinationPath: String
    ) async throws -> (objectCount: Int, sizeBytes: Int64) {
        logger.warning("Backup: S3 backup target '\(destinationPath)' — using local staging (S3 SDK not yet integrated)")
        // S3 backup currently stages to a local directory.
        // A full implementation would use an S3-compatible client.
        let stagingPath = "/tmp/mayam-s3-staging"
        return try await performLocalBackup(to: stagingPath)
    }
}

// MARK: - BackupError

/// Errors that may occur during backup operations.
public enum BackupError: Error, Sendable, CustomStringConvertible {

    /// A backup is already in progress.
    case backupAlreadyRunning

    /// The backup source archive is not accessible.
    case sourceNotAccessible(path: String)

    /// The backup target is not accessible.
    case targetNotAccessible(path: String)

    /// A file copy operation failed.
    case copyFailed(source: String, destination: String, reason: String)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .backupAlreadyRunning:
            return "A backup operation is already in progress"
        case .sourceNotAccessible(let path):
            return "Backup source not accessible: '\(path)'"
        case .targetNotAccessible(let path):
            return "Backup target not accessible: '\(path)'"
        case .copyFailed(let src, let dest, let reason):
            return "Failed to copy '\(src)' to '\(dest)': \(reason)"
        }
    }
}
