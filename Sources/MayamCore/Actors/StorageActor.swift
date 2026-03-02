// SPDX-License-Identifier: (see LICENSE)
// Mayam — Storage Actor

import Foundation
import Crypto

/// Manages DICOM object persistence and archive integrity.
///
/// `StorageActor` is a singleton within the server that serialises all
/// write operations to the on-disk archive.  It is responsible for:
/// - Writing received DICOM objects to the configured storage path.
/// - Computing and verifying SHA-256 integrity checksums.
/// - Enforcing store-as-received semantics (preserving the original transfer
///   syntax without decompression or transcoding).
/// - Performing duplicate SOP Instance detection and applying the configured
///   ``StoragePolicy/duplicatePolicy``.
///
/// Reference: DICOM PS3.4 Annex B — Storage Service Class
public actor StorageActor {

    // MARK: - Stored Properties

    /// Root path for the DICOM object archive.
    public let archivePath: String

    /// Whether SHA-256 checksums are computed on ingest.
    public let checksumEnabled: Bool

    /// On-disk layout helper.
    private let layout: StorageLayout

    /// Logger for storage events.
    private let logger: MayamLogger

    /// Tracks the total number of objects stored since the actor was created.
    private var storedObjectCount: Int = 0

    /// In-memory index of stored SOP Instance UIDs mapped to their relative
    /// file paths.  This is populated on each `store(…)` call and provides
    /// fast duplicate detection within a session.
    ///
    /// - Important: This index is **not persisted across server restarts**.
    ///   A full implementation will back this with the metadata database so
    ///   that duplicate detection survives process lifecycle events.
    ///   TODO: Replace with database-backed index in Milestone 5 (Q/R Services).
    private var storedInstancePaths: [String: String] = [:]

    // MARK: - Initialiser

    /// Creates a new storage actor.
    ///
    /// - Parameters:
    ///   - archivePath: Root directory for the DICOM archive.
    ///   - checksumEnabled: Whether to compute SHA-256 checksums on ingest.
    ///   - logger: Logger instance for storage events.
    public init(archivePath: String, checksumEnabled: Bool, logger: MayamLogger) {
        self.archivePath = archivePath
        self.checksumEnabled = checksumEnabled
        self.layout = StorageLayout(archivePath: archivePath)
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

    /// Returns whether a SOP instance with the given UID has already been stored
    /// in this session.
    ///
    /// - Parameter sopInstanceUID: The DICOM SOP Instance UID (0008,0018).
    /// - Returns: `true` if the instance was previously stored.
    public func instanceExists(sopInstanceUID: String) -> Bool {
        storedInstancePaths[sopInstanceUID] != nil
    }

    /// Returns the relative file path for a stored SOP instance.
    ///
    /// - Parameter sopInstanceUID: The DICOM SOP Instance UID (0008,0018).
    /// - Returns: The relative path within the archive root, or `nil` if not found.
    public func filePath(for sopInstanceUID: String) -> String? {
        storedInstancePaths[sopInstanceUID]
    }

    /// Stores a DICOM object to the on-disk archive using store-as-received
    /// semantics.
    ///
    /// The raw data set bytes are written verbatim to disk without
    /// decompression or transcoding, preserving the original transfer syntax.
    /// An optional SHA-256 integrity checksum is computed and returned.
    ///
    /// Duplicate detection is performed according to the supplied
    /// ``StoragePolicy/duplicatePolicy``:
    /// - `.reject` — throws ``StorageError/duplicateInstance``.
    /// - `.overwrite` — replaces the existing file.
    /// - `.keepBoth` — stores the new file under a suffixed name.
    ///
    /// - Parameters:
    ///   - sopInstanceUID: DICOM SOP Instance UID (0008,0018).
    ///   - sopClassUID: DICOM SOP Class UID (0008,0016).
    ///   - transferSyntaxUID: Transfer syntax of the stored data set.
    ///   - patientID: DICOM Patient ID (0010,0020); used in path layout.
    ///   - studyInstanceUID: DICOM Study Instance UID (0020,000D).
    ///   - seriesInstanceUID: DICOM Series Instance UID (0020,000E).
    ///   - dataSet: The raw DICOM data set bytes to store.
    ///   - policy: The storage policy governing duplicate handling and checksums.
    /// - Returns: A ``StoredInstance`` describing the persisted object.
    /// - Throws: ``StorageError`` if storage fails.
    public func store(
        sopInstanceUID: String,
        sopClassUID: String,
        transferSyntaxUID: String,
        patientID: String = "UNKNOWN",
        studyInstanceUID: String = "UNKNOWN",
        seriesInstanceUID: String = "UNKNOWN",
        dataSet: Data,
        policy: StoragePolicy = .default
    ) throws -> StoredInstance {
        // Duplicate detection
        if let existingPath = storedInstancePaths[sopInstanceUID] {
            switch policy.duplicatePolicy {
            case .reject:
                throw StorageError.duplicateInstance(sopInstanceUID: sopInstanceUID)
            case .overwrite:
                logger.warning("Overwriting duplicate SOP instance '\(sopInstanceUID)'")
            case .keepBoth:
                logger.info("Keeping both copies of SOP instance '\(sopInstanceUID)'")
                // Derive a guaranteed-unique UID using a UUID suffix to avoid
                // collisions even when multiple duplicates arrive simultaneously.
                let uniqueUID = sopInstanceUID + "_dup_\(UUID().uuidString)"
                return try storeData(
                    dataSet: dataSet,
                    sopInstanceUID: uniqueUID,
                    sopClassUID: sopClassUID,
                    transferSyntaxUID: transferSyntaxUID,
                    patientID: patientID,
                    studyInstanceUID: studyInstanceUID,
                    seriesInstanceUID: seriesInstanceUID,
                    policy: policy
                )
            }
            _ = existingPath
        }

        return try storeData(
            dataSet: dataSet,
            sopInstanceUID: sopInstanceUID,
            sopClassUID: sopClassUID,
            transferSyntaxUID: transferSyntaxUID,
            patientID: patientID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            policy: policy
        )
    }

    // MARK: - Private Helpers

    /// Writes the DICOM data to disk and records the stored instance.
    private func storeData(
        dataSet: Data,
        sopInstanceUID: String,
        sopClassUID: String,
        transferSyntaxUID: String,
        patientID: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        policy: StoragePolicy
    ) throws -> StoredInstance {
        // Create directory hierarchy
        try layout.createDirectoryHierarchy(
            patientID: patientID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID
        )

        let filePath = layout.absolutePath(
            patientID: patientID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            sopInstanceUID: sopInstanceUID
        )

        let relPath = layout.relativePath(
            patientID: patientID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            sopInstanceUID: sopInstanceUID
        )

        // Write data to disk (store-as-received)
        do {
            try dataSet.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        } catch {
            throw StorageError.writeFailed(path: filePath, underlying: error)
        }

        // Compute SHA-256 checksum if enabled
        var checksum: String? = nil
        if policy.checksumEnabled {
            var hasher = SHA256()
            hasher.update(data: dataSet)
            let digest = hasher.finalize()
            checksum = digest.map { String(format: "%02x", $0) }.joined()
        }

        storedInstancePaths[sopInstanceUID] = relPath
        storedObjectCount += 1

        logger.debug("Stored '\(sopInstanceUID)' at '\(relPath)' (\(dataSet.count) bytes)")

        return StoredInstance(
            sopInstanceUID: sopInstanceUID,
            sopClassUID: sopClassUID,
            transferSyntaxUID: transferSyntaxUID,
            filePath: relPath,
            fileSizeBytes: Int64(dataSet.count),
            checksumSHA256: checksum
        )
    }
}

// MARK: - StoredInstance

/// Describes a DICOM object that has been successfully persisted to the archive.
public struct StoredInstance: Sendable, Equatable {
    /// The stored DICOM SOP Instance UID (0008,0018).
    public let sopInstanceUID: String

    /// The DICOM SOP Class UID (0008,0016).
    public let sopClassUID: String

    /// The transfer syntax UID of the stored data set (store-as-received).
    public let transferSyntaxUID: String

    /// Relative path within the archive root.
    public let filePath: String

    /// Size of the stored file in bytes.
    public let fileSizeBytes: Int64

    /// Hex-encoded SHA-256 checksum of the file, or `nil` if checksums are disabled.
    public let checksumSHA256: String?

    /// Creates a new stored-instance descriptor.
    public init(
        sopInstanceUID: String,
        sopClassUID: String,
        transferSyntaxUID: String,
        filePath: String,
        fileSizeBytes: Int64,
        checksumSHA256: String? = nil
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.transferSyntaxUID = transferSyntaxUID
        self.filePath = filePath
        self.fileSizeBytes = fileSizeBytes
        self.checksumSHA256 = checksumSHA256
    }
}

// MARK: - StorageError

/// Errors that may occur during storage operations.
public enum StorageError: Error, Sendable, CustomStringConvertible {

    /// The configured archive path does not exist or is not a directory.
    case archivePathNotFound(path: String)

    /// The configured archive path is not writable.
    case archivePathNotWritable(path: String)

    /// A SOP instance with the same UID already exists and the policy is `.reject`.
    case duplicateInstance(sopInstanceUID: String)

    /// Writing the data set to disk failed.
    case writeFailed(path: String, underlying: any Error)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .archivePathNotFound(let path):
            return "Archive path not found or is not a directory: '\(path)'"
        case .archivePathNotWritable(let path):
            return "Archive path is not writable: '\(path)'"
        case .duplicateInstance(let uid):
            return "Duplicate SOP Instance UID '\(uid)' — rejected per storage policy"
        case .writeFailed(let path, let underlying):
            return "Failed to write DICOM object to '\(path)': \(underlying)"
        }
    }
}
