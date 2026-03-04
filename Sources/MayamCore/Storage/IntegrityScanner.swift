// SPDX-License-Identifier: (see LICENSE)
// Mayam — Integrity Scanner

import Foundation
import Crypto

// MARK: - IntegrityScanner

/// Performs periodic SHA-256 checksum verification across all archived
/// DICOM objects to detect data corruption or tampering.
///
/// The scanner walks the archive directory tree, computes SHA-256 checksums
/// for each `.dcm` file, and compares them against the stored checksums in
/// the metadata index. Discrepancies are recorded as integrity violations.
///
/// Reference: Milestone 9 — Periodic Integrity Scan
public actor IntegrityScanner {

    // MARK: - Nested Types

    /// The result of an integrity scan operation.
    public struct ScanResult: Sendable, Codable, Equatable {

        /// Unique identifier for this scan.
        public let id: UUID

        /// When the scan started.
        public let startedAt: Date

        /// When the scan completed, or `nil` if still running.
        public var completedAt: Date?

        /// Total number of files scanned.
        public var scannedCount: Int

        /// Number of files with valid checksums.
        public var validCount: Int

        /// Number of files with checksum mismatches.
        public var mismatchCount: Int

        /// Number of files that could not be read.
        public var errorCount: Int

        /// Detailed violation records.
        public var violations: [IntegrityViolation]

        /// Status of the scan.
        public var status: String

        /// Creates a scan result.
        public init(
            id: UUID = UUID(),
            startedAt: Date,
            completedAt: Date? = nil,
            scannedCount: Int = 0,
            validCount: Int = 0,
            mismatchCount: Int = 0,
            errorCount: Int = 0,
            violations: [IntegrityViolation] = [],
            status: String = "running"
        ) {
            self.id = id
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.scannedCount = scannedCount
            self.validCount = validCount
            self.mismatchCount = mismatchCount
            self.errorCount = errorCount
            self.violations = violations
            self.status = status
        }
    }

    /// A single integrity violation discovered during a scan.
    public struct IntegrityViolation: Sendable, Codable, Equatable {

        /// The relative file path within the archive.
        public let filePath: String

        /// The expected SHA-256 checksum.
        public let expectedChecksum: String

        /// The computed SHA-256 checksum, or `nil` if the file could not be read.
        public let computedChecksum: String?

        /// The type of violation.
        public let violationType: ViolationType

        /// Creates an integrity violation.
        public init(
            filePath: String,
            expectedChecksum: String,
            computedChecksum: String?,
            violationType: ViolationType
        ) {
            self.filePath = filePath
            self.expectedChecksum = expectedChecksum
            self.computedChecksum = computedChecksum
            self.violationType = violationType
        }
    }

    /// The type of integrity violation.
    public enum ViolationType: String, Sendable, Codable, Equatable {
        /// The computed checksum does not match the stored checksum.
        case checksumMismatch
        /// The file could not be read for verification.
        case fileUnreadable
        /// The file was not found at the expected path.
        case fileNotFound
    }

    // MARK: - Stored Properties

    /// Root path of the DICOM archive.
    private let archivePath: String

    /// A closure that retrieves the expected SHA-256 checksum for a relative
    /// file path. Returns `nil` if no checksum is stored.
    private let checksumLookup: @Sendable (String) async -> String?

    /// Logger for scanner events.
    private let logger: MayamLogger

    /// History of scan results.
    private var scanHistory: [ScanResult] = []

    /// Whether a scan is currently in progress.
    private var isRunning: Bool = false

    // MARK: - Initialiser

    /// Creates a new integrity scanner.
    ///
    /// - Parameters:
    ///   - archivePath: Root path of the DICOM archive.
    ///   - checksumLookup: Closure that retrieves expected checksums by relative
    ///     file path.
    ///   - logger: Logger instance for scanner events.
    public init(
        archivePath: String,
        checksumLookup: @escaping @Sendable (String) async -> String?,
        logger: MayamLogger
    ) {
        self.archivePath = archivePath
        self.checksumLookup = checksumLookup
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Runs a full integrity scan of the archive.
    ///
    /// Walks all `.dcm` files, computes their SHA-256 checksums, and compares
    /// against the stored checksums.
    ///
    /// - Returns: A ``ScanResult`` with the scan outcome.
    /// - Throws: ``IntegrityScanError`` if the scan cannot be started.
    public func runScan() async throws -> ScanResult {
        guard !isRunning else {
            throw IntegrityScanError.scanAlreadyRunning
        }

        isRunning = true
        defer { isRunning = false }

        let startedAt = Date()
        var result = ScanResult(startedAt: startedAt)

        logger.info("Integrity scan: Starting full archive scan at '\(archivePath)'")

        let dcmPaths = try IntegrityScanner.collectDCMPaths(at: archivePath)

        for relativePath in dcmPaths {
            result.scannedCount += 1
            let absolutePath = archivePath + "/" + relativePath

            // Look up expected checksum
            guard let expectedChecksum = await checksumLookup(relativePath) else {
                // No stored checksum — skip verification for this file
                result.validCount += 1
                continue
            }

            // Read file and compute checksum
            let fm = FileManager.default
            guard let fileData = fm.contents(atPath: absolutePath) else {
                result.errorCount += 1
                result.violations.append(IntegrityViolation(
                    filePath: relativePath,
                    expectedChecksum: expectedChecksum,
                    computedChecksum: nil,
                    violationType: .fileUnreadable
                ))
                continue
            }

            var hasher = SHA256()
            hasher.update(data: fileData)
            let digest = hasher.finalize()
            let computedChecksum = digest.map { String(format: "%02x", $0) }.joined()

            if computedChecksum == expectedChecksum {
                result.validCount += 1
            } else {
                result.mismatchCount += 1
                result.violations.append(IntegrityViolation(
                    filePath: relativePath,
                    expectedChecksum: expectedChecksum,
                    computedChecksum: computedChecksum,
                    violationType: .checksumMismatch
                ))
            }
        }

        result.completedAt = Date()
        result.status = result.mismatchCount == 0 && result.errorCount == 0 ? "passed" : "violations_found"
        scanHistory.append(result)

        logger.info("Integrity scan: Completed — \(result.scannedCount) scanned, \(result.validCount) valid, \(result.mismatchCount) mismatches, \(result.errorCount) errors")

        return result
    }

    /// Collects `.dcm` file paths from the archive directory.
    ///
    /// This is a `nonisolated` synchronous helper so that
    /// `NSDirectoryEnumerator` iteration (which is unavailable from async
    /// contexts in Swift 6.2) can be used directly.
    private nonisolated static func collectDCMPaths(at archivePath: String) throws -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: archivePath) else {
            throw IntegrityScanError.archiveNotAccessible(path: archivePath)
        }
        var paths: [String] = []
        for case let relativePath as String in enumerator where relativePath.hasSuffix(".dcm") {
            paths.append(relativePath)
        }
        return paths
    }

    /// Returns the history of scan results.
    public func getScanHistory() -> [ScanResult] {
        scanHistory
    }

    /// Returns the most recent scan result.
    public func lastScanResult() -> ScanResult? {
        scanHistory.last
    }

    /// Returns whether a scan is currently in progress.
    public func isScanRunning() -> Bool {
        isRunning
    }
}

// MARK: - IntegrityScanError

/// Errors that may occur during integrity scanning.
public enum IntegrityScanError: Error, Sendable, CustomStringConvertible {

    /// A scan is already in progress.
    case scanAlreadyRunning

    /// The archive directory is not accessible.
    case archiveNotAccessible(path: String)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .scanAlreadyRunning:
            return "An integrity scan is already in progress"
        case .archiveNotAccessible(let path):
            return "Archive directory not accessible: '\(path)'"
        }
    }
}
