// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin Storage Handler

import Foundation
import MayamCore

// MARK: - AdminStorageHandler

/// Provides storage pool information, archive integrity checking, and
/// HSM / backup management for the admin web console.
///
/// Storage statistics are derived from the file-system volume that hosts the
/// archive path.  The integrity check is a basic walk of the archive directory
/// tree that counts `.dcm` files; deep validation of DICOM data is a future
/// enhancement.
public actor AdminStorageHandler {

    // MARK: - Initialiser

    /// Creates a new storage handler.
    public init() {}

    // MARK: - Public Methods

    /// Returns a list of storage pools visible to the archive.
    ///
    /// Currently returns a single pool for the configured archive path.
    /// Multi-pool and nearline-tier support is planned for a future milestone.
    ///
    /// - Parameter archivePath: Root path of the DICOM archive.
    /// - Returns: An array of ``StoragePool`` descriptors.
    public func getStoragePools(archivePath: String) async -> [StoragePool] {
        var totalBytes: Int64 = 0
        var freeBytes: Int64 = 0

        let url = URL(fileURLWithPath: archivePath)
        if let resourceValues = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]) {
            totalBytes = resourceValues.volumeTotalCapacity.map { Int64($0) } ?? 0
            freeBytes = resourceValues.volumeAvailableCapacity.map { Int64($0) } ?? 0
        }

        let usedBytes = totalBytes - freeBytes
        let pool = StoragePool(
            name: "Primary Archive",
            path: archivePath,
            totalBytes: totalBytes,
            usedBytes: usedBytes,
            freeBytes: freeBytes,
            tier: "online"
        )
        return [pool]
    }

    /// Runs a basic integrity check over the archive directory.
    ///
    /// Walks the archive directory tree and counts `.dcm` files.  Deep DICOM
    /// data validation (checksum verification, tag completeness) is planned
    /// for a future milestone.
    ///
    /// - Parameter archivePath: Root path of the DICOM archive.
    /// - Returns: An ``IntegrityCheckResult`` with the count of examined files.
    public func runIntegrityCheck(archivePath: String) async -> IntegrityCheckResult {
        let startedAt = Date()
        let checkedCount = AdminStorageHandler.countDCMFiles(at: archivePath)

        return IntegrityCheckResult(
            startedAt: startedAt,
            completedAt: Date(),
            checkedCount: checkedCount,
            errorCount: 0,
            status: "complete"
        )
    }

    /// Counts `.dcm` files under the given path.
    ///
    /// This is a `nonisolated` synchronous helper so that
    /// `NSDirectoryEnumerator` iteration (which is unavailable from async
    /// contexts in Swift 6.2) can be used directly.
    private nonisolated static func countDCMFiles(at archivePath: String) -> Int {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: archivePath) else { return 0 }
        var count = 0
        for case let filePath as String in enumerator where filePath.hasSuffix(".dcm") {
            count += 1
        }
        return count
    }

    /// Returns the current HSM status including tier statistics.
    ///
    /// - Parameter hsmConfig: The HSM configuration.
    /// - Returns: An ``HSMStatus`` describing the current state.
    public func getHSMStatus(hsmConfig: ServerConfiguration.HSM) async -> HSMStatus {
        HSMStatus(
            enabled: hsmConfig.enabled,
            tierCount: hsmConfig.tiers.count,
            migrationRuleCount: hsmConfig.migrationRules.count,
            migrationScanIntervalSeconds: hsmConfig.migrationScanIntervalSeconds
        )
    }

    /// Returns the current backup status.
    ///
    /// - Parameter backupConfig: The backup configuration.
    /// - Returns: A ``BackupStatus`` describing the current state.
    public func getBackupStatus(backupConfig: ServerConfiguration.Backup) async -> AdminBackupStatus {
        AdminBackupStatus(
            enabled: backupConfig.enabled,
            targetCount: backupConfig.targets.count,
            enabledTargetCount: backupConfig.targets.filter(\.enabled).count,
            scheduleIntervalSeconds: backupConfig.schedule.intervalSeconds
        )
    }
}
