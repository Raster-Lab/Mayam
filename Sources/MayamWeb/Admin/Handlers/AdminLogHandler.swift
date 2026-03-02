// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin Log Handler

import Foundation
import MayamCore

// MARK: - AdminLogHandler

/// Maintains an in-memory ring buffer of structured log entries for the admin
/// console log viewer.
///
/// Log entries may be injected by any subsystem via ``addEntry(_:)`` and
/// queried via ``getLogs(level:label:limit:offset:)``.
public actor AdminLogHandler {

    // MARK: - Stored Properties

    /// In-memory ring buffer; capped at 1 000 entries.
    private var logBuffer: [LogEntry]

    // MARK: - Initialiser

    /// Creates a new log handler with an empty buffer.
    public init() {
        self.logBuffer = []
    }

    // MARK: - Public Methods

    /// Appends a log entry to the buffer.
    ///
    /// When the buffer exceeds 1 000 entries the oldest entries are discarded.
    ///
    /// - Parameter entry: The ``LogEntry`` to record.
    public func addEntry(_ entry: LogEntry) {
        logBuffer.append(entry)
        if logBuffer.count > 1_000 {
            logBuffer = Array(logBuffer.suffix(1_000))
        }
    }

    /// Returns a filtered, paginated slice of log entries.
    ///
    /// Entries are returned in chronological order (oldest first after
    /// applying filters).
    ///
    /// - Parameters:
    ///   - level: Optional minimum log level to filter by (case-insensitive
    ///     string match).
    ///   - label: Optional logger label substring filter.
    ///   - limit: Maximum number of entries to return.
    ///   - offset: Number of entries to skip before returning results.
    /// - Returns: The filtered and paginated log entries.
    public func getLogs(
        level: String?,
        label: String?,
        limit: Int,
        offset: Int
    ) -> [LogEntry] {
        var filtered = logBuffer

        if let level = level, !level.isEmpty {
            filtered = filtered.filter { $0.level.lowercased() == level.lowercased() }
        }
        if let label = label, !label.isEmpty {
            filtered = filtered.filter { $0.label.contains(label) }
        }

        let safeOffset = min(offset, filtered.count)
        let slice = filtered.dropFirst(safeOffset)
        let safeLimit = max(0, limit)
        return Array(slice.prefix(safeLimit))
    }
}
