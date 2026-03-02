// SPDX-License-Identifier: (see LICENSE)
// Mayam — UPS-RS Handler Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class UPSRSTests: XCTestCase {

    // MARK: - UPSRecord

    func test_upsRecord_defaultState_isScheduled() {
        let r = UPSRecord(workitemUID: "1.2.3")
        XCTAssertEqual(r.state, .scheduled)
    }

    func test_upsRecord_id_equalsWorkitemUID() {
        let r = UPSRecord(workitemUID: "1.2.3.4")
        XCTAssertEqual(r.id, "1.2.3.4")
    }

    func test_upsRecord_state_allCases() {
        XCTAssertEqual(UPSRecord.State.allCases.count, 4)
        XCTAssertTrue(UPSRecord.State.allCases.contains(.scheduled))
        XCTAssertTrue(UPSRecord.State.allCases.contains(.inProgress))
        XCTAssertTrue(UPSRecord.State.allCases.contains(.completed))
        XCTAssertTrue(UPSRecord.State.allCases.contains(.cancelled))
    }

    // MARK: - Create Workitem

    func test_upsRS_createWorkitem_withPreferredUID_usesUID() async throws {
        let handler = UPSRSHandler()
        let record = try await handler.createWorkitem(preferredUID: "1.2.3.4.5")
        XCTAssertEqual(record.workitemUID, "1.2.3.4.5")
        XCTAssertEqual(record.state, .scheduled)
    }

    func test_upsRS_createWorkitem_withoutUID_generatesUID() async throws {
        let handler = UPSRSHandler()
        let record = try await handler.createWorkitem()
        XCTAssertFalse(record.workitemUID.isEmpty)
        XCTAssertTrue(record.workitemUID.hasPrefix("2.25."))
    }

    func test_upsRS_createWorkitem_duplicateUID_throws() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        do {
            _ = try await handler.createWorkitem(preferredUID: "1.2.3")
            XCTFail("Expected DICOMwebError.conflict")
        } catch DICOMwebError.conflict {
            // expected
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    // MARK: - Query Workitems

    func test_upsRS_queryWorkitems_emptyStore_returnsEmpty() async {
        let handler = UPSRSHandler()
        let results = await handler.queryWorkitems(queryParams: [:])
        XCTAssertTrue(results.isEmpty)
    }

    func test_upsRS_queryWorkitems_filteredByState() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        _ = try await handler.createWorkitem(preferredUID: "1.2.4")
        _ = try await handler.changeWorkitemState(uid: "1.2.4", newState: .inProgress)

        let scheduled = await handler.queryWorkitems(queryParams: ["status": "SCHEDULED"])
        let inProgress = await handler.queryWorkitems(queryParams: ["status": "IN PROGRESS"])

        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(inProgress.count, 1)
    }

    // MARK: - Retrieve Workitem

    func test_upsRS_retrieveWorkitem_exists_returnsRecord() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        let record = try await handler.retrieveWorkitem(uid: "1.2.3")
        XCTAssertEqual(record.workitemUID, "1.2.3")
    }

    func test_upsRS_retrieveWorkitem_notFound_throws() async {
        let handler = UPSRSHandler()
        do {
            _ = try await handler.retrieveWorkitem(uid: "1.2.nonexistent")
            XCTFail("Expected DICOMwebError.notFound")
        } catch DICOMwebError.notFound {
            // expected
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    // MARK: - Update Workitem

    func test_upsRS_updateWorkitem_scheduled_succeeds() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        let updated = try await handler.updateWorkitem(uid: "1.2.3", dataSet: [:])
        XCTAssertEqual(updated.workitemUID, "1.2.3")
    }

    func test_upsRS_updateWorkitem_completed_throws() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        _ = try await handler.changeWorkitemState(uid: "1.2.3", newState: .inProgress)
        _ = try await handler.changeWorkitemState(uid: "1.2.3", newState: .completed)

        do {
            _ = try await handler.updateWorkitem(uid: "1.2.3", dataSet: [:])
            XCTFail("Expected DICOMwebError.conflict")
        } catch DICOMwebError.conflict {
            // expected
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    // MARK: - State Transitions

    func test_upsRS_stateTransition_scheduledToInProgress_succeeds() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        let updated = try await handler.changeWorkitemState(uid: "1.2.3", newState: .inProgress, performerAETitle: "AE1")
        XCTAssertEqual(updated.state, .inProgress)
        XCTAssertEqual(updated.performerAETitle, "AE1")
    }

    func test_upsRS_stateTransition_inProgressToCompleted_succeeds() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        _ = try await handler.changeWorkitemState(uid: "1.2.3", newState: .inProgress)
        let completed = try await handler.changeWorkitemState(uid: "1.2.3", newState: .completed)
        XCTAssertEqual(completed.state, .completed)
    }

    func test_upsRS_stateTransition_completedToAny_throws() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        _ = try await handler.changeWorkitemState(uid: "1.2.3", newState: .inProgress)
        _ = try await handler.changeWorkitemState(uid: "1.2.3", newState: .completed)

        do {
            _ = try await handler.changeWorkitemState(uid: "1.2.3", newState: .cancelled)
            XCTFail("Expected DICOMwebError.conflict")
        } catch DICOMwebError.conflict {
            // expected
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func test_upsRS_stateTransition_scheduledToCancelled_succeeds() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        let cancelled = try await handler.changeWorkitemState(uid: "1.2.3", newState: .cancelled)
        XCTAssertEqual(cancelled.state, .cancelled)
    }

    // MARK: - Subscriptions

    func test_upsRS_subscribe_addsSubscriber() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        try await handler.subscribe(aeTitle: "AE1", to: "1.2.3")
        let subs = await handler.subscribers(for: "1.2.3")
        XCTAssertTrue(subs.contains("AE1"))
    }

    func test_upsRS_unsubscribe_removesSubscriber() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        try await handler.subscribe(aeTitle: "AE1", to: "1.2.3")
        await handler.unsubscribe(aeTitle: "AE1", from: "1.2.3")
        let subs = await handler.subscribers(for: "1.2.3")
        XCTAssertFalse(subs.contains("AE1"))
    }

    func test_upsRS_subscribe_nonexistentWorkitem_throws() async throws {
        let handler = UPSRSHandler()
        do {
            try await handler.subscribe(aeTitle: "AE1", to: "1.2.nonexistent")
            XCTFail("Expected DICOMwebError.notFound")
        } catch DICOMwebError.notFound {
            // expected
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func test_upsRS_subscribers_emptyForNewWorkitem() async throws {
        let handler = UPSRSHandler()
        _ = try await handler.createWorkitem(preferredUID: "1.2.3")
        let subs = await handler.subscribers(for: "1.2.3")
        XCTAssertTrue(subs.isEmpty)
    }
}
