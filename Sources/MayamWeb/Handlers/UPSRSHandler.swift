// SPDX-License-Identifier: (see LICENSE)
// Mayam — UPS-RS Handler

import Foundation
import MayamCore

// MARK: - UPSRSHandler

/// Implements the UPS-RS (Unified Procedure Step by RESTful Services) service.
///
/// UPS-RS provides a RESTful interface for creating, querying, retrieving,
/// updating, and monitoring DICOM Unified Procedure Step workitems.
///
/// ## Supported Endpoints
///
/// - `POST {base}/workitems` — create a new workitem.
/// - `GET {base}/workitems` — query workitems.
/// - `GET {base}/workitems/{workitemUID}` — retrieve a workitem.
/// - `PUT {base}/workitems/{workitemUID}` — update a workitem.
/// - `PUT {base}/workitems/{workitemUID}/state` — change workitem state.
/// - `POST {base}/workitems/{workitemUID}/subscribers/{aeTitle}` — subscribe.
/// - `DELETE {base}/workitems/{workitemUID}/subscribers/{aeTitle}` — unsubscribe.
///
/// Reference: DICOM PS3.18 Section 11 — UPS-RS
public actor UPSRSHandler {

    // MARK: - Stored Properties

    /// In-memory workitem store, keyed by workitem UID.
    private var workitems: [String: UPSRecord] = [:]

    /// Subscriptions: maps workitem UID to a set of subscribed AE Titles.
    private var subscriptions: [String: Set<String>] = [:]

    // MARK: - Initialiser

    /// Creates a new UPS-RS handler with an empty workitem store.
    public init() {}

    // MARK: - Create Workitem

    /// Creates a new UPS workitem.
    ///
    /// The client may supply a preferred workitem UID in the request. If absent,
    /// a new UID is generated automatically.
    ///
    /// - Parameters:
    ///   - preferredUID: An optional client-supplied workitem UID.
    ///   - dataSet: The DICOM JSON dataset for the workitem.
    /// - Returns: The created ``UPSRecord``.
    /// - Throws: ``DICOMwebError/conflict`` if the UID already exists.
    public func createWorkitem(
        preferredUID: String? = nil,
        dataSet: [String: DICOMJSONValue] = [:]
    ) throws -> UPSRecord {
        let uid = preferredUID ?? generateUID()

        if workitems[uid] != nil {
            throw DICOMwebError.conflict(reason: "Workitem \(uid) already exists")
        }

        let record = UPSRecord(
            workitemUID: uid,
            state: .scheduled,
            dataSet: dataSet
        )
        workitems[uid] = record
        return record
    }

    // MARK: - Query Workitems

    /// Queries workitems matching the supplied parameters.
    ///
    /// Supported query parameters:
    /// - `status` — filter by ``UPSRecord/State`` raw value.
    /// - `WorklistLabel` (0074,1202).
    /// - `limit` and `offset` for pagination.
    ///
    /// - Parameter queryParams: URL query parameters.
    /// - Returns: An array of matching ``UPSRecord`` values.
    public func queryWorkitems(queryParams: [String: String]) -> [UPSRecord] {
        var results = Array(workitems.values)

        // Filter by state
        if let status = queryParams["status"] {
            results = results.filter { $0.state.rawValue == status }
        }

        // Filter by WorklistLabel
        if let label = queryParams["WorklistLabel"] {
            results = results.filter { $0.worklistLabel == label }
        }

        // Apply pagination
        let limit = min(Int(queryParams["limit"] ?? "100") ?? 100, 1000)
        let offset = Int(queryParams["offset"] ?? "0") ?? 0
        let sorted = results.sorted { $0.createdAt < $1.createdAt }
        let startIndex = min(offset, sorted.count)
        let endIndex = min(startIndex + limit, sorted.count)
        return Array(sorted[startIndex..<endIndex])
    }

    // MARK: - Retrieve Workitem

    /// Retrieves a single workitem by UID.
    ///
    /// - Parameter uid: The workitem UID.
    /// - Returns: The ``UPSRecord`` if found.
    /// - Throws: ``DICOMwebError/notFound`` if the workitem does not exist.
    public func retrieveWorkitem(uid: String) throws -> UPSRecord {
        guard let record = workitems[uid] else {
            throw DICOMwebError.notFound(resource: "Workitem \(uid)")
        }
        return record
    }

    // MARK: - Update Workitem

    /// Updates an existing workitem with new dataset attributes.
    ///
    /// Only workitems in the `.scheduled` or `.inProgress` state may be updated.
    ///
    /// - Parameters:
    ///   - uid: The workitem UID to update.
    ///   - dataSet: The updated DICOM JSON dataset.
    /// - Returns: The updated ``UPSRecord``.
    /// - Throws: ``DICOMwebError/notFound`` if the workitem does not exist,
    ///   or ``DICOMwebError/conflict`` if the workitem is in a terminal state.
    public func updateWorkitem(uid: String, dataSet: [String: DICOMJSONValue]) throws -> UPSRecord {
        guard let record = workitems[uid] else {
            throw DICOMwebError.notFound(resource: "Workitem \(uid)")
        }
        guard record.state == .scheduled || record.state == .inProgress else {
            throw DICOMwebError.conflict(
                reason: "Cannot update workitem in state \(record.state.rawValue)"
            )
        }

        let updated = UPSRecord(
            workitemUID: record.workitemUID,
            state: record.state,
            scheduledStartDateTime: record.scheduledStartDateTime,
            procedureStepLabel: record.procedureStepLabel,
            worklistLabel: record.worklistLabel,
            scheduledStationName: record.scheduledStationName,
            inputReadinessState: record.inputReadinessState,
            priority: record.priority,
            performerAETitle: record.performerAETitle,
            dataSet: dataSet,
            createdAt: record.createdAt,
            updatedAt: Date()
        )
        workitems[uid] = updated
        return updated
    }

    // MARK: - Change Workitem State

    /// Changes the state of a workitem.
    ///
    /// Valid state transitions:
    /// - `SCHEDULED` → `IN PROGRESS` (claim by a performer)
    /// - `IN PROGRESS` → `COMPLETED`
    /// - `IN PROGRESS` → `CANCELLED`
    /// - `SCHEDULED` → `CANCELLED`
    ///
    /// - Parameters:
    ///   - uid: The workitem UID.
    ///   - newState: The requested new state.
    ///   - performerAETitle: The AE Title of the performer (required when claiming).
    /// - Returns: The updated ``UPSRecord``.
    /// - Throws: ``DICOMwebError/notFound`` or ``DICOMwebError/conflict`` on error.
    public func changeWorkitemState(
        uid: String,
        newState: UPSRecord.State,
        performerAETitle: String? = nil
    ) throws -> UPSRecord {
        guard let record = workitems[uid] else {
            throw DICOMwebError.notFound(resource: "Workitem \(uid)")
        }

        guard isValidTransition(from: record.state, to: newState) else {
            throw DICOMwebError.conflict(
                reason: "Cannot transition workitem from \(record.state.rawValue) to \(newState.rawValue)"
            )
        }

        let updated = UPSRecord(
            workitemUID: record.workitemUID,
            state: newState,
            scheduledStartDateTime: record.scheduledStartDateTime,
            procedureStepLabel: record.procedureStepLabel,
            worklistLabel: record.worklistLabel,
            scheduledStationName: record.scheduledStationName,
            inputReadinessState: record.inputReadinessState,
            priority: record.priority,
            performerAETitle: performerAETitle ?? record.performerAETitle,
            dataSet: record.dataSet,
            createdAt: record.createdAt,
            updatedAt: Date()
        )
        workitems[uid] = updated
        return updated
    }

    // MARK: - Subscriptions

    /// Subscribes an AE Title to state change notifications for a workitem.
    ///
    /// - Parameters:
    ///   - aeTitle: The AE Title to subscribe.
    ///   - workitemUID: The workitem UID to subscribe to.
    /// - Throws: ``DICOMwebError/notFound`` if the workitem does not exist.
    public func subscribe(aeTitle: String, to workitemUID: String) throws {
        guard workitems[workitemUID] != nil else {
            throw DICOMwebError.notFound(resource: "Workitem \(workitemUID)")
        }
        subscriptions[workitemUID, default: []].insert(aeTitle)
    }

    /// Unsubscribes an AE Title from notifications for a workitem.
    ///
    /// - Parameters:
    ///   - aeTitle: The AE Title to unsubscribe.
    ///   - workitemUID: The workitem UID.
    public func unsubscribe(aeTitle: String, from workitemUID: String) {
        subscriptions[workitemUID]?.remove(aeTitle)
    }

    /// Returns the set of AE Titles subscribed to a workitem.
    ///
    /// - Parameter workitemUID: The workitem UID.
    /// - Returns: The set of subscribed AE Titles.
    public func subscribers(for workitemUID: String) -> Set<String> {
        subscriptions[workitemUID] ?? []
    }

    // MARK: - Private Helpers

    /// Validates a UPS state transition.
    private func isValidTransition(from current: UPSRecord.State, to target: UPSRecord.State) -> Bool {
        switch (current, target) {
        case (.scheduled, .inProgress): return true
        case (.scheduled, .cancelled): return true
        case (.inProgress, .completed): return true
        case (.inProgress, .cancelled): return true
        default: return false
        }
    }

    /// Generates a new unique DICOM UID for a workitem.
    private func generateUID() -> String {
        // Root UID: 2.25 prefix (ISO/IEC 8824 UUID-derived)
        let uuid = UUID().uuid
        let uuidInt = UInt128(
            highBits: UInt64(uuid.0) << 56 | UInt64(uuid.1) << 48 |
                      UInt64(uuid.2) << 40 | UInt64(uuid.3) << 32 |
                      UInt64(uuid.4) << 24 | UInt64(uuid.5) << 16 |
                      UInt64(uuid.6) << 8  | UInt64(uuid.7),
            lowBits:  UInt64(uuid.8) << 56 | UInt64(uuid.9) << 48 |
                      UInt64(uuid.10) << 40 | UInt64(uuid.11) << 32 |
                      UInt64(uuid.12) << 24 | UInt64(uuid.13) << 16 |
                      UInt64(uuid.14) << 8  | UInt64(uuid.15)
        )
        return "2.25.\(uuidInt.decimal)"
    }
}

// MARK: - UInt128 helper

/// Minimal 128-bit unsigned integer for UUID-to-DICOM-UID conversion.
private struct UInt128: Sendable {
    let highBits: UInt64
    let lowBits: UInt64

    /// Decimal string representation, used for the 2.25.* UID prefix.
    var decimal: String {
        // Compute decimal via repeated division
        var high = highBits
        var low = lowBits
        if high == 0 && low == 0 { return "0" }
        var digits: [UInt8] = []
        while high != 0 || low != 0 {
            // Divide (high:low) by 10
            let (qHigh, rHigh) = high.quotientAndRemainder(dividingBy: 10)
            let combined = (UInt64(rHigh) << 32) | (low >> 32)
            let (qMid, rMid) = combined.quotientAndRemainder(dividingBy: 10)
            let combined2 = (UInt64(rMid) << 32) | (low & 0xFFFFFFFF)
            let (qLow, rLow) = combined2.quotientAndRemainder(dividingBy: 10)
            digits.append(UInt8(rLow))
            high = qHigh
            low = UInt64(qMid) << 32 | qLow
        }
        return digits.reversed().map { String($0) }.joined()
    }
}
