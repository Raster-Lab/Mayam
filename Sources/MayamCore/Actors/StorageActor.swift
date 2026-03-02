// SPDX-License-Identifier: (see LICENSE)
// Mayam — Storage Actor

import Foundation

/// Manages DICOM object persistence and archive integrity.
///
/// `StorageActor` is a singleton within the server that serialises all
/// write operations to the on-disk archive.  It is responsible for:
/// - Writing received DICOM objects to the configured storage path.
/// - Computing and verifying SHA-256 integrity checksums.
/// - Enforcing store-as-received semantics (preserving the original transfer
///   syntax).
///
/// > Note: Full storage implementation is part of Milestone 3.  This actor
/// > defines the concurrency-safe skeleton and validates the archive path.
public actor StorageActor {

    // MARK: - Stored Properties

    /// Root path for the DICOM object archive.
    public let archivePath: String

    /// Whether SHA-256 checksums are computed on ingest.
    public let checksumEnabled: Bool

    /// Logger for storage events.
    private let logger: MayamLogger

    /// Tracks the total number of objects stored.
    private var storedObjectCount: Int = 0

    // MARK: - Initialiser

    /// Creates a new storage actor.
    ///
    /// - Parameters:
    ///   - archivePath: Root directory for the DICOM archive.
    ///   - checksumEnabled: Whether to compute SHA-256 checksums.
    ///   - logger: Logger instance for storage events.
    public init(archivePath: String, checksumEnabled: Bool, logger: MayamLogger) {
        self.archivePath = archivePath
        self.checksumEnabled = checksumEnabled
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Returns the total number of objects stored since the actor was created.
    public func getStoredObjectCount() -> Int {
        storedObjectCount
    }

    /// Validates that the archive directory exists and is writable.
    ///
    /// - Throws: ``StorageError/archivePathNotFound`` or
    ///   ``StorageError/archivePathNotWritable`` if validation fails.
    public func validateArchivePath() throws {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: archivePath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw StorageError.archivePathNotFound(path: archivePath)
        }

        guard fm.isWritableFile(atPath: archivePath) else {
            throw StorageError.archivePathNotWritable(path: archivePath)
        }

        logger.info("Archive path validated: \(archivePath)")
    }
}

/// Errors that may occur during storage operations.
public enum StorageError: Error, Sendable, CustomStringConvertible {

    /// The configured archive path does not exist or is not a directory.
    case archivePathNotFound(path: String)

    /// The configured archive path is not writable.
    case archivePathNotWritable(path: String)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .archivePathNotFound(let path):
            return "Archive path not found or is not a directory: '\(path)'"
        case .archivePathNotWritable(let path):
            return "Archive path is not writable: '\(path)'"
        }
    }
}
