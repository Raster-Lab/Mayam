// SPDX-License-Identifier: (see LICENSE)
// Mayam — Study Archiver

import Foundation

/// Packages a complete DICOM study directory into an archive file for backup,
/// near-line storage, or bulk transfer.
///
/// Two packaging formats are supported:
///
/// - **ZIP** — cross-platform, widely supported; suitable for bulk transfer and
///   web-based download.
/// - **TAR+Zstd** — higher compression ratio and faster decompression; suitable
///   for near-line and offline storage tiers.
///
/// Archive creation delegates to the `zip` and `tar` system utilities which are
/// present on all supported platforms (macOS and Linux).
///
/// > Note: Production deployments should verify that `zip` and `zstd` are
/// > installed and on the system `PATH` before enabling the corresponding
/// > archive format.
public struct StudyArchiver: Sendable {

    // MARK: - Nested Types

    /// The archive format to produce.
    public enum ArchiveFormat: String, Sendable, Equatable, CaseIterable {
        /// ZIP archive (`.zip`).
        case zip
        /// TAR archive with Zstd compression (`.tar.zst`).
        case tarZstd = "tar.zst"
    }

    /// The result of a successful archive operation.
    public struct ArchiveResult: Sendable, Equatable {
        /// The absolute path to the produced archive file.
        public let archivePath: String

        /// The total size of the archive file in bytes.
        public let fileSizeBytes: Int64

        /// The format of the produced archive.
        public let format: ArchiveFormat

        /// Creates an archive result.
        public init(archivePath: String, fileSizeBytes: Int64, format: ArchiveFormat) {
            self.archivePath = archivePath
            self.fileSizeBytes = fileSizeBytes
            self.format = format
        }
    }

    // MARK: - Stored Properties

    /// Logger for archiver events.
    private let logger: MayamLogger

    // MARK: - Initialiser

    /// Creates a new study archiver.
    ///
    /// - Parameter logger: Logger instance for archiver events.
    public init(logger: MayamLogger) {
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Packages a study directory into an archive file.
    ///
    /// The source directory is recursively included in the archive. The output
    /// archive is written to `destinationDirectory` using the study UID as the
    /// base file name.
    ///
    /// - Parameters:
    ///   - studyDirectoryPath: Absolute path to the study directory.
    ///   - studyInstanceUID: Study Instance UID used to name the archive file.
    ///   - destinationDirectory: Directory where the archive file is written.
    ///   - format: The archive format (default: `.zip`).
    /// - Returns: An ``ArchiveResult`` describing the produced archive.
    /// - Throws: ``StudyArchiverError`` if the archive cannot be created.
    public func archive(
        studyDirectoryPath: String,
        studyInstanceUID: String,
        destinationDirectory: String,
        format: ArchiveFormat = .zip
    ) async throws -> ArchiveResult {
        let fm = FileManager.default

        // Validate source directory
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: studyDirectoryPath, isDirectory: &isDir),
              isDir.boolValue else {
            throw StudyArchiverError.sourceDirectoryNotFound(path: studyDirectoryPath)
        }

        // Ensure destination directory exists
        if !fm.fileExists(atPath: destinationDirectory) {
            try fm.createDirectory(
                atPath: destinationDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Derive a safe file name from the study UID (replace dots with underscores)
        let safeUID = studyInstanceUID.replacingOccurrences(of: ".", with: "_")

        switch format {
        case .zip:
            return try await createZIPArchive(
                sourcePath: studyDirectoryPath,
                safeUID: safeUID,
                destinationDirectory: destinationDirectory
            )
        case .tarZstd:
            return try await createTarZstdArchive(
                sourcePath: studyDirectoryPath,
                safeUID: safeUID,
                destinationDirectory: destinationDirectory
            )
        }
    }

    // MARK: - Private Helpers

    private func createZIPArchive(
        sourcePath: String,
        safeUID: String,
        destinationDirectory: String
    ) async throws -> ArchiveResult {
        let archiveName = safeUID + ".zip"
        let archivePath = destinationDirectory + "/" + archiveName

        let exitCode = try await runProcess(
            executablePath: "/usr/bin/zip",
            arguments: ["-r", archivePath, "."],
            workingDirectory: sourcePath
        )

        guard exitCode == 0 else {
            throw StudyArchiverError.archiveCreationFailed(format: "ZIP", exitCode: exitCode)
        }

        let fileSize = (try? FileManager.default
            .attributesOfItem(atPath: archivePath)[.size] as? Int64) ?? 0
        logger.info("Study archive created: \(archivePath) (\(fileSize) bytes, ZIP)")

        return ArchiveResult(archivePath: archivePath, fileSizeBytes: fileSize, format: .zip)
    }

    private func createTarZstdArchive(
        sourcePath: String,
        safeUID: String,
        destinationDirectory: String
    ) async throws -> ArchiveResult {
        let archiveName = safeUID + ".tar.zst"
        let archivePath = destinationDirectory + "/" + archiveName

        let exitCode = try await runProcess(
            executablePath: "/usr/bin/tar",
            arguments: [
                "--use-compress-program=zstd",
                "-cf",
                archivePath,
                "-C",
                sourcePath,
                "."
            ],
            workingDirectory: nil
        )

        guard exitCode == 0 else {
            throw StudyArchiverError.archiveCreationFailed(format: "TAR+Zstd", exitCode: exitCode)
        }

        let fileSize = (try? FileManager.default
            .attributesOfItem(atPath: archivePath)[.size] as? Int64) ?? 0
        logger.info("Study archive created: \(archivePath) (\(fileSize) bytes, TAR+Zstd)")

        return ArchiveResult(archivePath: archivePath, fileSizeBytes: fileSize, format: .tarZstd)
    }

    /// Runs an external process asynchronously and returns its exit code.
    ///
    /// - Parameters:
    ///   - executablePath: Absolute path to the executable.
    ///   - arguments: Command-line arguments.
    ///   - workingDirectory: Working directory for the process (optional).
    /// - Returns: The process exit code.
    /// - Throws: ``StudyArchiverError/processLaunchFailed`` if the process
    ///   cannot be launched.
    private func runProcess(
        executablePath: String,
        arguments: [String],
        workingDirectory: String?
    ) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            if let wd = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: wd)
            }

            // Suppress stdout/stderr from archive utilities
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { p in
                continuation.resume(returning: p.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(
                    throwing: StudyArchiverError.processLaunchFailed(underlying: error)
                )
            }
        }
    }
}

// MARK: - StudyArchiverError

/// Errors that may occur during study archive packaging.
public enum StudyArchiverError: Error, Sendable, CustomStringConvertible {

    /// The source study directory was not found or is not a directory.
    case sourceDirectoryNotFound(path: String)

    /// The archive process exited with a non-zero status code.
    case archiveCreationFailed(format: String, exitCode: Int32)

    /// The archive utility process could not be launched.
    case processLaunchFailed(underlying: any Error)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .sourceDirectoryNotFound(let path):
            return "Study source directory not found: '\(path)'"
        case .archiveCreationFailed(let format, let exitCode):
            return "\(format) archive creation failed with exit code \(exitCode)"
        case .processLaunchFailed(let underlying):
            return "Failed to launch archive process: \(underlying)"
        }
    }
}
