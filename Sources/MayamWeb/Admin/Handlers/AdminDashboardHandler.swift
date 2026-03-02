// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin Dashboard Handler

import Foundation
import MayamCore

// MARK: - AdminDashboardHandler

/// Provides aggregated statistics and activity data for the admin dashboard.
///
/// Uptime is measured from the time the handler was initialised.  Storage
/// statistics are read from the file system at the time of each request.
public actor AdminDashboardHandler {

    // MARK: - Stored Properties

    /// The timestamp at which the server was started.
    private let startTime: Date

    /// Recent activity entries (up to 100).
    private var recentActivity: [ActivityEntry]

    // MARK: - Initialiser

    /// Creates a new dashboard handler, recording the current time as the
    /// server start time.
    public init() {
        self.startTime = Date()
        self.recentActivity = []
    }

    // MARK: - Public Methods

    /// Computes and returns the current dashboard statistics.
    ///
    /// Storage figures are derived from the file-system volume containing the
    /// archive path.  If the path does not exist or the volume cannot be
    /// queried, storage bytes are reported as zero.
    ///
    /// - Parameter archivePath: Root path of the DICOM archive.
    /// - Returns: A ``DashboardStats`` snapshot.
    public func getDashboardStats(archivePath: String) async -> DashboardStats {
        let uptime = Date().timeIntervalSince(startTime)
        var storageUsedBytes: Int64 = 0
        var storageFreeBytes: Int64 = 0

        let url = URL(fileURLWithPath: archivePath)
        if let resourceValues = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]) {
            let total = resourceValues.volumeTotalCapacity.map { Int64($0) } ?? 0
            let free = resourceValues.volumeAvailableCapacity.map { Int64($0) } ?? 0
            storageUsedBytes = total - free
            storageFreeBytes = free
        }

        return DashboardStats(
            serverVersion: MayamWeb.version,
            uptimeSeconds: uptime,
            activeAssociations: 0,
            totalStoredInstances: 0,
            storageUsedBytes: storageUsedBytes,
            storageFreeBytes: storageFreeBytes,
            recentActivity: Array(recentActivity.suffix(10))
        )
    }

    /// Appends an activity entry to the recent-activity ring buffer.
    ///
    /// The buffer retains only the most recent 100 entries.
    ///
    /// - Parameter entry: The ``ActivityEntry`` to record.
    public func addActivity(_ entry: ActivityEntry) {
        recentActivity.append(entry)
        if recentActivity.count > 100 {
            recentActivity = Array(recentActivity.suffix(100))
        }
    }
}
