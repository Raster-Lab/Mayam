// SPDX-License-Identifier: (see LICENSE)
// Mayam — IHE ATNA Audit Repository

import Foundation
import Crypto

/// Tamper-evident local audit log storage conforming to the IHE ATNA profile.
///
/// The repository persists ``ATNAAuditEvent`` records in an in-memory store
/// (replaceable with a database-backed implementation) and computes HMAC-SHA256
/// integrity hashes to detect tampering.
///
/// ## IHE ATNA Requirements
/// - All security-relevant events are persisted.
/// - Each record includes an integrity hash to support tamper detection.
/// - Audit records are queryable by event type, date range, and participant.
///
/// ## DICOM References
/// - DICOM PS3.15 Annex A — Audit Trail Message Format Profile
public actor ATNAAuditRepository {

    // MARK: - Stored Properties

    /// In-memory audit event store (to be replaced by database in production).
    private var events: [ATNAAuditEvent] = []

    /// HMAC key used for tamper-evident integrity hashing.
    private let hmacKey: SymmetricKey

    /// Logger for audit repository operations.
    private let logger: MayamLogger

    // MARK: - Initialiser

    /// Creates a new audit repository.
    ///
    /// - Parameter hmacSecret: A shared secret used to compute HMAC-SHA256
    ///   integrity hashes.  Defaults to `"mayam-audit-key"` for development;
    ///   **must** be changed for production deployments.
    public init(hmacSecret: String = "mayam-audit-key") {
        self.hmacKey = SymmetricKey(data: Data(hmacSecret.utf8))
        self.logger = MayamLogger(label: "com.raster-lab.mayam.atna")
    }

    // MARK: - Public Methods

    /// Records an audit event with an integrity hash.
    ///
    /// The HMAC-SHA256 hash is computed over the event's serialised JSON
    /// representation (excluding the `integrityHash` field) and stored
    /// alongside the event for tamper detection.
    ///
    /// - Parameter event: The audit event to record.
    /// - Returns: The recorded event with the computed integrity hash.
    @discardableResult
    public func record(_ event: ATNAAuditEvent) -> ATNAAuditEvent {
        var stored = event
        stored.integrityHash = computeHMAC(for: event)
        events.append(stored)
        logger.info("Audit event recorded: \(event.eventID.rawValue) outcome=\(event.eventOutcome.rawValue)")
        return stored
    }

    /// Returns all recorded audit events.
    ///
    /// - Returns: An array of audit events in chronological order.
    public func allEvents() -> [ATNAAuditEvent] {
        events
    }

    /// Queries audit events by event type.
    ///
    /// - Parameter eventID: The event type to filter by.
    /// - Returns: An array of matching events.
    public func events(ofType eventID: ATNAAuditEvent.EventID) -> [ATNAAuditEvent] {
        events.filter { $0.eventID == eventID }
    }

    /// Queries audit events within a date range.
    ///
    /// - Parameters:
    ///   - from: The start of the date range (inclusive).
    ///   - to: The end of the date range (inclusive).
    /// - Returns: An array of matching events.
    public func events(from: Date, to: Date) -> [ATNAAuditEvent] {
        events.filter { $0.eventDateTime >= from && $0.eventDateTime <= to }
    }

    /// Queries audit events by participant user ID.
    ///
    /// - Parameter userID: The user ID to search for.
    /// - Returns: An array of events where the specified user is a participant.
    public func events(forUser userID: String) -> [ATNAAuditEvent] {
        events.filter { event in
            event.activeParticipants.contains { $0.userID == userID }
        }
    }

    /// Verifies the integrity of a stored audit event.
    ///
    /// - Parameter event: The event to verify.
    /// - Returns: `true` if the event's integrity hash matches the recomputed
    ///   HMAC, indicating the record has not been tampered with.
    public func verifyIntegrity(of event: ATNAAuditEvent) -> Bool {
        guard let storedHash = event.integrityHash else { return false }
        let computed = computeHMAC(for: event)
        return storedHash == computed
    }

    /// Verifies the integrity of all stored audit events.
    ///
    /// - Returns: `true` if all events pass integrity verification.
    public func verifyAllIntegrity() -> Bool {
        events.allSatisfy { verifyIntegrity(of: $0) }
    }

    /// Returns the total number of recorded audit events.
    public func count() -> Int {
        events.count
    }

    // MARK: - Private Helpers

    /// Computes an HMAC-SHA256 hash for the given event (excluding its
    /// `integrityHash` field).
    private func computeHMAC(for event: ATNAAuditEvent) -> String {
        var hashableEvent = event
        hashableEvent.integrityHash = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(hashableEvent) else {
            return ""
        }
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: hmacKey)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }
}
