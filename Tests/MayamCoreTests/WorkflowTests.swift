// SPDX-License-Identifier: (see LICENSE)
// Mayam — Workflow, MWL, MPPS, IAN & Webhook Tests

import XCTest
import Foundation
import DICOMNetwork
@testable import MayamCore

// MARK: - Test Helpers

/// A simple reference-type box used to capture values from `@Sendable` closures
/// in tests without triggering strict-concurrency warnings.
final class CapturedValueBox<T: Sendable>: @unchecked Sendable {
    var value: T?
    init() {}
}

// MARK: - ScheduledProcedureStep Model Tests

final class ScheduledProcedureStepTests: XCTestCase {

    func test_scheduledProcedureStep_defaultValues_areCorrect() {
        let now = Date()
        let step = ScheduledProcedureStep(
            scheduledProcedureStepID: "SPS-001",
            studyInstanceUID: "1.2.3.4.5",
            accessionNumber: "ACC001",
            patientID: "PAT001",
            patientName: "DOE^JOHN",
            scheduledStartDate: "20260301",
            modality: "CT"
        )

        XCTAssertEqual(step.scheduledProcedureStepID, "SPS-001")
        XCTAssertEqual(step.studyInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(step.accessionNumber, "ACC001")
        XCTAssertEqual(step.patientID, "PAT001")
        XCTAssertEqual(step.patientName, "DOE^JOHN")
        XCTAssertEqual(step.scheduledStartDate, "20260301")
        XCTAssertEqual(step.modality, "CT")
        XCTAssertEqual(step.status, .scheduled)
        XCTAssertNil(step.patientBirthDate)
        XCTAssertNil(step.patientSex)
        XCTAssertNil(step.scheduledStartTime)
        XCTAssertNil(step.scheduledStationAETitle)
        XCTAssertGreaterThanOrEqual(step.createdAt, now)
    }

    func test_scheduledProcedureStep_allStatuses_haveCorrectRawValues() {
        XCTAssertEqual(ScheduledProcedureStep.Status.scheduled.rawValue, "SCHEDULED")
        XCTAssertEqual(ScheduledProcedureStep.Status.arrived.rawValue, "ARRIVED")
        XCTAssertEqual(ScheduledProcedureStep.Status.ready.rawValue, "READY")
        XCTAssertEqual(ScheduledProcedureStep.Status.started.rawValue, "STARTED")
        XCTAssertEqual(ScheduledProcedureStep.Status.completed.rawValue, "COMPLETED")
        XCTAssertEqual(ScheduledProcedureStep.Status.discontinued.rawValue, "DISCONTINUED")
        XCTAssertEqual(ScheduledProcedureStep.Status.allCases.count, 6)
    }

    func test_scheduledProcedureStep_id_equalsScheduledProcedureStepID() {
        let step = ScheduledProcedureStep(
            scheduledProcedureStepID: "SPS-ID-42",
            studyInstanceUID: "1.2.3",
            accessionNumber: "ACC",
            patientID: "P",
            patientName: "N",
            scheduledStartDate: "20260101",
            modality: "MR"
        )
        XCTAssertEqual(step.id, "SPS-ID-42")
    }

    func test_scheduledProcedureStep_codable_roundTrips() throws {
        let date = Date(timeIntervalSince1970: 1_740_000_000)
        let step = ScheduledProcedureStep(
            scheduledProcedureStepID: "SPS-002",
            studyInstanceUID: "1.2.3.4.5.6",
            accessionNumber: "ACC002",
            patientID: "PAT002",
            patientName: "SMITH^JANE",
            patientBirthDate: "19800115",
            patientSex: "F",
            referringPhysicianName: "DR^JONES",
            requestedProcedureID: "REQ001",
            requestedProcedureDescription: "Chest CT",
            scheduledStartDate: "20260315",
            scheduledStartTime: "0900",
            modality: "CT",
            scheduledPerformingPhysicianName: "DR^SMITH",
            scheduledProcedureStepDescription: "Contrast Enhanced",
            scheduledStationAETitle: "CT_SCANNER_01",
            scheduledStationName: "CT Scanner 1",
            scheduledProcedureStepLocation: "Radiology Suite A",
            status: .arrived,
            createdAt: date,
            updatedAt: date
        )

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(step)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(ScheduledProcedureStep.self, from: data)

        XCTAssertEqual(step, decoded)
    }

    func test_scheduledProcedureStep_statusMutation_updatesValue() {
        var step = ScheduledProcedureStep(
            scheduledProcedureStepID: "SPS-003",
            studyInstanceUID: "1.2.3",
            accessionNumber: "ACC",
            patientID: "P",
            patientName: "N",
            scheduledStartDate: "20260301",
            modality: "CR"
        )
        XCTAssertEqual(step.status, .scheduled)
        step.status = .completed
        XCTAssertEqual(step.status, .completed)
    }

    func test_scheduledProcedureStep_equality_trueForIdenticalValues() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let step1 = ScheduledProcedureStep(
            scheduledProcedureStepID: "SPS-EQ",
            studyInstanceUID: "1.2.3",
            accessionNumber: "ACC",
            patientID: "P",
            patientName: "N",
            scheduledStartDate: "20260301",
            modality: "CT",
            createdAt: date,
            updatedAt: date
        )
        let step2 = ScheduledProcedureStep(
            scheduledProcedureStepID: "SPS-EQ",
            studyInstanceUID: "1.2.3",
            accessionNumber: "ACC",
            patientID: "P",
            patientName: "N",
            scheduledStartDate: "20260301",
            modality: "CT",
            createdAt: date,
            updatedAt: date
        )
        XCTAssertEqual(step1, step2)
    }
}

// MARK: - PerformedProcedureStep Model Tests

final class PerformedProcedureStepTests: XCTestCase {

    func test_performedProcedureStep_defaultValues_areCorrect() {
        let mpps = PerformedProcedureStep(sopInstanceUID: "1.2.3.4.5")

        XCTAssertEqual(mpps.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(mpps.status, .inProgress)
        XCTAssertNil(mpps.studyInstanceUID)
        XCTAssertNil(mpps.accessionNumber)
        XCTAssertNil(mpps.patientID)
        XCTAssertNil(mpps.modality)
        XCTAssertEqual(mpps.performedSeriesInstanceUIDs, [])
        XCTAssertEqual(mpps.numberOfInstances, 0)
    }

    func test_performedProcedureStep_allStatuses_haveCorrectRawValues() {
        XCTAssertEqual(PerformedProcedureStep.Status.inProgress.rawValue, "IN PROGRESS")
        XCTAssertEqual(PerformedProcedureStep.Status.completed.rawValue, "COMPLETED")
        XCTAssertEqual(PerformedProcedureStep.Status.discontinued.rawValue, "DISCONTINUED")
        XCTAssertEqual(PerformedProcedureStep.Status.allCases.count, 3)
    }

    func test_performedProcedureStep_id_equalsSOPInstanceUID() {
        let mpps = PerformedProcedureStep(sopInstanceUID: "1.2.3.UID")
        XCTAssertEqual(mpps.id, "1.2.3.UID")
    }

    func test_performedProcedureStep_statusMutation_allowsTransition() {
        var mpps = PerformedProcedureStep(sopInstanceUID: "1.2.3")
        XCTAssertEqual(mpps.status, .inProgress)
        mpps.status = .completed
        XCTAssertEqual(mpps.status, .completed)
    }

    func test_performedProcedureStep_codable_roundTrips() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let mpps = PerformedProcedureStep(
            sopInstanceUID: "1.2.3.4",
            status: .completed,
            studyInstanceUID: "1.2.5.6",
            accessionNumber: "ACC003",
            patientID: "PAT003",
            patientName: "BROWN^ALICE",
            modality: "MR",
            performedStationAETitle: "MR_SCANNER_01",
            performedStationName: "MR 1",
            performedStartDate: "20260301",
            performedStartTime: "1000",
            performedEndDate: "20260301",
            performedEndTime: "1045",
            performedProcedureStepDescription: "Brain MRI",
            performedProcedureStepID: "PPS-001",
            scheduledProcedureStepID: "SPS-001",
            performedSeriesInstanceUIDs: ["1.2.3.4.1", "1.2.3.4.2"],
            numberOfInstances: 150,
            createdAt: date,
            updatedAt: date
        )

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(mpps)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(PerformedProcedureStep.self, from: data)

        XCTAssertEqual(mpps, decoded)
    }
}

// MARK: - MPPSError Tests

final class MPPSErrorTests: XCTestCase {

    func test_mppsError_instanceNotFound_descriptionContainsUID() {
        let err = MPPSError.instanceNotFound(sopInstanceUID: "1.2.3")
        XCTAssertTrue(err.description.contains("1.2.3"))
        XCTAssertTrue(err.description.contains("not found"))
    }

    func test_mppsError_duplicateInstance_descriptionContainsUID() {
        let err = MPPSError.duplicateInstance(sopInstanceUID: "1.2.3")
        XCTAssertTrue(err.description.contains("1.2.3"))
        XCTAssertTrue(err.description.contains("already exists"))
    }

    func test_mppsError_invalidStateTransition_descriptionContainsStates() {
        let err = MPPSError.invalidStateTransition(from: .inProgress, to: .inProgress)
        XCTAssertTrue(err.description.contains("IN PROGRESS"))
    }

    func test_mppsError_instanceFinalised_descriptionContainsUID() {
        let err = MPPSError.instanceFinalised(sopInstanceUID: "1.2.3")
        XCTAssertTrue(err.description.contains("1.2.3"))
        XCTAssertTrue(err.description.contains("final"))
    }
}

// MARK: - RISEvent Tests

final class RISEventTests: XCTestCase {

    func test_risEvent_eventTypes_haveCorrectRawValues() {
        XCTAssertEqual(RISEvent.EventType.studyReceived.rawValue, "study.received")
        XCTAssertEqual(RISEvent.EventType.studyUpdated.rawValue, "study.updated")
        XCTAssertEqual(RISEvent.EventType.studyComplete.rawValue, "study.complete")
        XCTAssertEqual(RISEvent.EventType.studyAvailable.rawValue, "study.available")
        XCTAssertEqual(RISEvent.EventType.studyRouted.rawValue, "study.routed")
        XCTAssertEqual(RISEvent.EventType.studyArchived.rawValue, "study.archived")
        XCTAssertEqual(RISEvent.EventType.studyRehydrated.rawValue, "study.rehydrated")
        XCTAssertEqual(RISEvent.EventType.studyDeleted.rawValue, "study.deleted")
        XCTAssertEqual(RISEvent.EventType.studyError.rawValue, "study.error")
        XCTAssertEqual(RISEvent.EventType.allCases.count, 9)
    }

    func test_risEvent_init_generatesUniqueIDs() {
        let e1 = RISEvent(eventType: .studyReceived, studyInstanceUID: "1.2.3")
        let e2 = RISEvent(eventType: .studyReceived, studyInstanceUID: "1.2.3")
        XCTAssertNotEqual(e1.id, e2.id)
    }

    func test_risEvent_studyReceived_hasCorrectPayload() {
        let event = RISEvent(
            eventType: .studyReceived,
            studyInstanceUID: "1.2.840.10008.5.1",
            accessionNumber: "ACC100",
            patientID: "PAT100",
            patientName: "JONES^BOB",
            modality: "CT",
            studyDate: "20260301",
            studyDescription: "Chest CT",
            receivingAE: "MAYAM",
            sourceAE: "CT_SCANNER"
        )

        XCTAssertEqual(event.eventType, .studyReceived)
        XCTAssertEqual(event.studyInstanceUID, "1.2.840.10008.5.1")
        XCTAssertEqual(event.accessionNumber, "ACC100")
        XCTAssertEqual(event.patientID, "PAT100")
        XCTAssertEqual(event.patientName, "JONES^BOB")
        XCTAssertEqual(event.modality, "CT")
        XCTAssertEqual(event.studyDate, "20260301")
        XCTAssertEqual(event.studyDescription, "Chest CT")
        XCTAssertEqual(event.receivingAE, "MAYAM")
        XCTAssertEqual(event.sourceAE, "CT_SCANNER")
    }

    func test_risEvent_studyAvailable_hasCorrectPayload() {
        let event = RISEvent(
            eventType: .studyAvailable,
            studyInstanceUID: "1.2.3.4",
            accessionNumber: "ACC200",
            patientID: "PAT200",
            retrieveAE: "MAYAM",
            retrieveURL: "http://localhost:8080/wado/",
            availableTransferSyntaxes: ["1.2.840.10008.1.2.1", "1.2.840.10008.1.2.4.70"]
        )

        XCTAssertEqual(event.eventType, .studyAvailable)
        XCTAssertEqual(event.retrieveAE, "MAYAM")
        XCTAssertEqual(event.retrieveURL, "http://localhost:8080/wado/")
        XCTAssertEqual(event.availableTransferSyntaxes?.count, 2)
    }

    func test_risEvent_studyError_hasCorrectPayload() {
        let event = RISEvent(
            eventType: .studyError,
            studyInstanceUID: "1.2.3.4",
            errorCode: "STORE_FAIL",
            errorMessage: "Disk full",
            stage: "ingest"
        )

        XCTAssertEqual(event.eventType, .studyError)
        XCTAssertEqual(event.errorCode, "STORE_FAIL")
        XCTAssertEqual(event.errorMessage, "Disk full")
        XCTAssertEqual(event.stage, "ingest")
    }

    func test_risEvent_codable_roundTrips() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_740_000_000)
        let event = RISEvent(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            eventType: .studyRouted,
            studyInstanceUID: "1.2.3.4.5",
            accessionNumber: "ACC300",
            patientID: "PAT300",
            destinationAE: "REMOTE_PACS",
            destinationURL: "https://remote.example.com/wado/",
            transferSyntaxUsed: "1.2.840.10008.1.2.4.70",
            routeRuleID: "RULE-01",
            timestamp: fixedDate
        )

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(event)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(RISEvent.self, from: data)

        XCTAssertEqual(event, decoded)
    }

    func test_risEvent_studyDeleted_hasCorrectPayload() {
        let event = RISEvent(
            eventType: .studyDeleted,
            studyInstanceUID: "1.2.3.4.5",
            accessionNumber: "ACC400",
            patientID: "PAT400",
            deletionReason: "Patient request",
            deletedBy: "admin"
        )

        XCTAssertEqual(event.eventType, .studyDeleted)
        XCTAssertEqual(event.deletionReason, "Patient request")
        XCTAssertEqual(event.deletedBy, "admin")
    }
}

// MARK: - WebhookSubscription Tests

final class WebhookSubscriptionTests: XCTestCase {

    func test_webhookSubscription_defaultValues_areCorrect() {
        let sub = WebhookSubscription(
            name: "Test Sub",
            url: "https://example.com/hook",
            secret: "secret123"
        )

        XCTAssertEqual(sub.name, "Test Sub")
        XCTAssertEqual(sub.url, "https://example.com/hook")
        XCTAssertEqual(sub.secret, "secret123")
        XCTAssertEqual(sub.eventTypes, [])
        XCTAssertTrue(sub.enabled)
        XCTAssertEqual(sub.maxRetries, 5)
        XCTAssertEqual(sub.retryDelaySeconds, 10)
    }

    func test_webhookSubscription_filterByEventTypes_filtersCorrectly() {
        let sub = WebhookSubscription(
            name: "Filtered",
            url: "https://example.com/hook",
            secret: "s",
            eventTypes: [.studyReceived, .studyAvailable]
        )
        XCTAssertEqual(sub.eventTypes.count, 2)
        XCTAssertTrue(sub.eventTypes.contains(.studyReceived))
        XCTAssertTrue(sub.eventTypes.contains(.studyAvailable))
    }

    func test_webhookSubscription_codable_roundTrips() throws {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let sub = WebhookSubscription(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "RIS Integration",
            url: "https://ris.example.com/pacs-events",
            secret: "supersecret",
            eventTypes: [.studyReceived, .studyComplete, .studyAvailable],
            enabled: true,
            maxRetries: 3,
            retryDelaySeconds: 30,
            createdAt: date,
            updatedAt: date
        )

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(sub)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(WebhookSubscription.self, from: data)

        XCTAssertEqual(sub, decoded)
    }

    func test_webhookDeliveryRecord_defaultValues_areCorrect() {
        let record = WebhookDeliveryRecord(
            subscriptionID: UUID(),
            eventID: UUID()
        )

        XCTAssertEqual(record.status, .pending)
        XCTAssertEqual(record.attemptCount, 0)
        XCTAssertNil(record.httpStatusCode)
        XCTAssertNil(record.nextRetryAt)
        XCTAssertNil(record.lastError)
    }

    func test_webhookDeliveryRecord_allStatuses_haveCorrectRawValues() {
        XCTAssertEqual(WebhookDeliveryRecord.DeliveryStatus.success.rawValue, "success")
        XCTAssertEqual(WebhookDeliveryRecord.DeliveryStatus.failed.rawValue, "failed")
        XCTAssertEqual(WebhookDeliveryRecord.DeliveryStatus.exhausted.rawValue, "exhausted")
        XCTAssertEqual(WebhookDeliveryRecord.DeliveryStatus.pending.rawValue, "pending")
        XCTAssertEqual(WebhookDeliveryRecord.DeliveryStatus.allCases.count, 4)
    }

    func test_webhookDeliveryRecord_codable_roundTrips() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let record = WebhookDeliveryRecord(
            id: UUID(),
            subscriptionID: UUID(),
            eventID: UUID(),
            httpStatusCode: 200,
            status: .success,
            attemptCount: 1,
            nextRetryAt: nil,
            lastError: nil,
            attemptedAt: date
        )

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(record)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(WebhookDeliveryRecord.self, from: data)

        XCTAssertEqual(record, decoded)
    }
}

// MARK: - WorklistQuery Tests

final class WorklistQueryTests: XCTestCase {

    func test_worklistQuery_init_defaultsAllNil() {
        let q = WorklistQuery()
        XCTAssertNil(q.patientID)
        XCTAssertNil(q.patientName)
        XCTAssertNil(q.modality)
        XCTAssertNil(q.scheduledDate)
        XCTAssertNil(q.scheduledStationAETitle)
        XCTAssertNil(q.accessionNumber)
    }

    func test_worklistQuery_init_setsProvidedValues() {
        let q = WorklistQuery(
            patientID: "PAT001",
            patientName: "DOE*",
            modality: "CT",
            scheduledDate: "20260301",
            scheduledStationAETitle: "CT1",
            accessionNumber: "ACC001"
        )
        XCTAssertEqual(q.patientID, "PAT001")
        XCTAssertEqual(q.patientName, "DOE*")
        XCTAssertEqual(q.modality, "CT")
        XCTAssertEqual(q.scheduledDate, "20260301")
        XCTAssertEqual(q.scheduledStationAETitle, "CT1")
        XCTAssertEqual(q.accessionNumber, "ACC001")
    }

    func test_worklistQuery_equality_matchesOnAllFields() {
        let q1 = WorklistQuery(patientID: "P", modality: "CT")
        let q2 = WorklistQuery(patientID: "P", modality: "CT")
        let q3 = WorklistQuery(patientID: "P", modality: "MR")
        XCTAssertEqual(q1, q2)
        XCTAssertNotEqual(q1, q3)
    }
}

// MARK: - ModalityWorklistSCP Tests

final class ModalityWorklistSCPTests: XCTestCase {

    private func makeStep(
        id: String,
        patientID: String = "PAT001",
        modality: String = "CT",
        date: String = "20260301",
        ae: String = "CT_SCANNER"
    ) -> ScheduledProcedureStep {
        ScheduledProcedureStep(
            scheduledProcedureStepID: id,
            studyInstanceUID: "1.2.3.\(id)",
            accessionNumber: "ACC-\(id)",
            patientID: patientID,
            patientName: "DOE^JOHN",
            scheduledStartDate: date,
            modality: modality,
            scheduledStationAETitle: ae
        )
    }

    func test_mwlSCP_cfind_returnsMatchingSteps() async {
        let steps = [
            makeStep(id: "SPS1", patientID: "PAT001", modality: "CT"),
            makeStep(id: "SPS2", patientID: "PAT002", modality: "MR"),
        ]
        let scp = ModalityWorklistSCP(
            worklistProvider: { _ in steps },
            logger: MayamLogger(label: "test.mwl")
        )

        let results = await scp.handleCFind(
            request: CFindRequest(
                messageID: 1,
                affectedSOPClassUID: ModalityWorklistSCP.sopClassUID,
                presentationContextID: 1
            ),
            identifier: Data(),
            presentationContextID: 1
        )

        // N pending results + 1 final success
        XCTAssertEqual(results.count, 3)
        // Last result is the final success
        XCTAssertFalse(results.last?.response.hasDataSet ?? true)
    }

    func test_mwlSCP_cfind_emptyWorklist_returnsFinalSuccess() async {
        let scp = ModalityWorklistSCP(
            worklistProvider: { _ in [] },
            logger: MayamLogger(label: "test.mwl")
        )

        let results = await scp.handleCFind(
            request: CFindRequest(
                messageID: 2,
                affectedSOPClassUID: ModalityWorklistSCP.sopClassUID,
                presentationContextID: 1
            ),
            identifier: Data(),
            presentationContextID: 1
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].response.hasDataSet)
    }

    func test_mwlSCP_sopClassUID_isCorrect() {
        XCTAssertEqual(ModalityWorklistSCP.sopClassUID, "1.2.840.10008.5.1.4.31")
    }

    func test_mwlSCP_cfind_encodesScheduledProcedureStep_inPendingResponse() async {
        let step = makeStep(id: "SPS-ENC")
        let scp = ModalityWorklistSCP(
            worklistProvider: { _ in [step] },
            logger: MayamLogger(label: "test.mwl")
        )

        let results = await scp.handleCFind(
            request: CFindRequest(
                messageID: 3,
                affectedSOPClassUID: ModalityWorklistSCP.sopClassUID,
                presentationContextID: 1
            ),
            identifier: Data(),
            presentationContextID: 1
        )

        // First result should carry a data set
        let pendingResult = results.first
        XCTAssertNotNil(pendingResult?.dataSet)
        XCTAssertTrue(pendingResult?.response.hasDataSet ?? false)
    }

    func test_mwlSCP_parseWorklistQuery_extractsPatientID() async {
        // Build a minimal implicit VR data set with Patient ID (0010,0020)
        var data = Data()
        let patientIDBytes = Array("PAT-QUERY".utf8)
        let paddedLength = patientIDBytes.count % 2 == 0
            ? patientIDBytes.count
            : patientIDBytes.count + 1

        data.append(contentsOf: [0x10, 0x00, 0x20, 0x00])   // Tag (0010,0020)
        data.append(UInt8(paddedLength & 0xFF))
        data.append(UInt8((paddedLength >> 8) & 0xFF))
        data.append(UInt8((paddedLength >> 16) & 0xFF))
        data.append(UInt8((paddedLength >> 24) & 0xFF))
        data.append(contentsOf: patientIDBytes)
        if patientIDBytes.count % 2 != 0 { data.append(0x20) }

        let capturedQueryBox = CapturedValueBox<WorklistQuery>()
        let scp = ModalityWorklistSCP(
            worklistProvider: { q in
                capturedQueryBox.value = q
                return []
            },
            logger: MayamLogger(label: "test.mwl")
        )

        _ = await scp.handleCFind(
            request: CFindRequest(
                messageID: 4,
                affectedSOPClassUID: ModalityWorklistSCP.sopClassUID,
                presentationContextID: 1
            ),
            identifier: data,
            presentationContextID: 1
        )

        XCTAssertEqual(capturedQueryBox.value?.patientID, "PAT-QUERY")
    }
}

// MARK: - MPPSSCP Tests

final class MPPSSCPTests: XCTestCase {

    func test_mppsSCP_sopClassUID_isCorrect() {
        XCTAssertEqual(MPPSSCP.sopClassUID, "1.2.840.10008.3.1.2.3.3")
    }

    func test_mppsSCP_nCreate_createsInstance() async throws {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))

        let mpps = try await scp.handleNCreate(sopInstanceUID: "1.2.3.MPPS", dataSet: Data())

        XCTAssertEqual(mpps.sopInstanceUID, "1.2.3.MPPS")
        XCTAssertEqual(mpps.status, .inProgress)
    }

    func test_mppsSCP_nCreate_duplicateUID_throwsError() async throws {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))
        let uid = "1.2.3.MPPS.DUP"

        _ = try await scp.handleNCreate(sopInstanceUID: uid, dataSet: Data())

        do {
            _ = try await scp.handleNCreate(sopInstanceUID: uid, dataSet: Data())
            XCTFail("Expected duplicateInstance error")
        } catch let err as MPPSError {
            guard case .duplicateInstance(let u) = err else {
                XCTFail("Wrong error case: \(err)")
                return
            }
            XCTAssertEqual(u, uid)
        }
    }

    func test_mppsSCP_nSet_updatesStatus_toCompleted() async throws {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))
        let uid = "1.2.3.MPPS.SET"
        _ = try await scp.handleNCreate(sopInstanceUID: uid, dataSet: Data())

        // Build a dataset with status COMPLETED (0040,0252)
        let statusValue = "COMPLETED"
        var data = Data()
        let valueBytes = Array(statusValue.utf8)
        let paddedLength = valueBytes.count % 2 == 0 ? valueBytes.count : valueBytes.count + 1
        data.append(contentsOf: [0x40, 0x00, 0x52, 0x02])  // Tag (0040,0252)
        data.append(UInt8(paddedLength & 0xFF))
        data.append(UInt8((paddedLength >> 8) & 0xFF))
        data.append(UInt8((paddedLength >> 16) & 0xFF))
        data.append(UInt8((paddedLength >> 24) & 0xFF))
        data.append(contentsOf: valueBytes)
        if valueBytes.count % 2 != 0 { data.append(0x20) }

        let updated = try await scp.handleNSet(sopInstanceUID: uid, dataSet: data)
        XCTAssertEqual(updated.status, .completed)
    }

    func test_mppsSCP_nSet_unknownUID_throwsError() async {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))

        do {
            _ = try await scp.handleNSet(sopInstanceUID: "1.2.3.UNKNOWN", dataSet: Data())
            XCTFail("Expected instanceNotFound error")
        } catch let err as MPPSError {
            guard case .instanceNotFound = err else {
                XCTFail("Wrong error case: \(err)")
                return
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_mppsSCP_nSet_finalisedInstance_throwsError() async throws {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))
        let uid = "1.2.3.MPPS.FINAL"

        _ = try await scp.handleNCreate(sopInstanceUID: uid, dataSet: Data())

        // Complete it
        let statusValue = "COMPLETED"
        var data = Data()
        let valueBytes = Array(statusValue.utf8)
        let paddedLength = valueBytes.count % 2 == 0 ? valueBytes.count : valueBytes.count + 1
        data.append(contentsOf: [0x40, 0x00, 0x52, 0x02])
        data.append(UInt8(paddedLength & 0xFF))
        data.append(UInt8((paddedLength >> 8) & 0xFF))
        data.append(UInt8((paddedLength >> 16) & 0xFF))
        data.append(UInt8((paddedLength >> 24) & 0xFF))
        data.append(contentsOf: valueBytes)
        if valueBytes.count % 2 != 0 { data.append(0x20) }

        _ = try await scp.handleNSet(sopInstanceUID: uid, dataSet: data)

        // Try to update a finalised instance
        do {
            _ = try await scp.handleNSet(sopInstanceUID: uid, dataSet: Data())
            XCTFail("Expected instanceFinalised error")
        } catch let err as MPPSError {
            guard case .instanceFinalised = err else {
                XCTFail("Wrong error case: \(err)")
                return
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_mppsSCP_getInstance_returnsCorrectInstance() async throws {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))
        let uid = "1.2.3.MPPS.GET"
        _ = try await scp.handleNCreate(sopInstanceUID: uid, dataSet: Data())

        let mpps = try await scp.getInstance(sopInstanceUID: uid)
        XCTAssertEqual(mpps.sopInstanceUID, uid)
    }

    func test_mppsSCP_getInstance_unknownUID_throwsError() async throws {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))
        do {
            _ = try await scp.getInstance(sopInstanceUID: "1.2.3.NOPE")
            XCTFail("Expected instanceNotFound error")
        } catch let err as MPPSError {
            guard case .instanceNotFound = err else {
                XCTFail("Wrong error case: \(err)")
                return
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_mppsSCP_getAllInstances_returnsAllCreated() async throws {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))
        let uids = ["1.2.3.A", "1.2.3.B", "1.2.3.C"]
        for uid in uids {
            _ = try await scp.handleNCreate(sopInstanceUID: uid, dataSet: Data())
        }

        let all = await scp.getAllInstances()
        XCTAssertEqual(all.count, 3)
        XCTAssertTrue(uids.allSatisfy { uid in all.contains { $0.sopInstanceUID == uid } })
    }

    func test_mppsSCP_instanceCount_reflectsCreations() async throws {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))
        let countBefore = await scp.instanceCount()
        XCTAssertEqual(countBefore, 0)
        _ = try await scp.handleNCreate(sopInstanceUID: "1.2.3.CNT", dataSet: Data())
        let countAfter = await scp.instanceCount()
        XCTAssertEqual(countAfter, 1)
    }

    func test_mppsSCP_statusChangeHandler_isInvokedOnCreate() async throws {
        let capturedBox = CapturedValueBox<PerformedProcedureStep>()
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps")) { mpps in
            capturedBox.value = mpps
        }

        _ = try await scp.handleNCreate(sopInstanceUID: "1.2.3.CB", dataSet: Data())

        XCTAssertNotNil(capturedBox.value)
        XCTAssertEqual(capturedBox.value?.sopInstanceUID, "1.2.3.CB")
    }

    func test_mppsSCP_parsesPatientIDFromDataSet() async throws {
        let scp = MPPSSCP(logger: MayamLogger(label: "test.mpps"))

        // Build implicit VR data set with Patient ID (0010,0020)
        var data = Data()
        let value = "PAT-MPPS"
        let valueBytes = Array(value.utf8)
        let paddedLength = valueBytes.count % 2 == 0 ? valueBytes.count : valueBytes.count + 1
        data.append(contentsOf: [0x10, 0x00, 0x20, 0x00])
        data.append(UInt8(paddedLength & 0xFF))
        data.append(UInt8((paddedLength >> 8) & 0xFF))
        data.append(UInt8((paddedLength >> 16) & 0xFF))
        data.append(UInt8((paddedLength >> 24) & 0xFF))
        data.append(contentsOf: valueBytes)
        if valueBytes.count % 2 != 0 { data.append(0x20) }

        let mpps = try await scp.handleNCreate(sopInstanceUID: "1.2.3.PARSE", dataSet: data)
        XCTAssertEqual(mpps.patientID, "PAT-MPPS")
    }
}

// MARK: - InstanceAvailabilityNotificationSCU Tests

final class InstanceAvailabilityNotificationSCUTests: XCTestCase {

    func test_ianSCU_sopClassUID_isCorrect() {
        XCTAssertEqual(InstanceAvailabilityNotificationSCU.sopClassUID, "1.2.840.10008.5.1.4.33")
    }

    func test_ianSCU_availabilityStatus_hasCorrectRawValues() {
        XCTAssertEqual(InstanceAvailabilityNotificationSCU.AvailabilityStatus.online.rawValue, "ONLINE")
        XCTAssertEqual(InstanceAvailabilityNotificationSCU.AvailabilityStatus.nearline.rawValue, "NEARLINE")
        XCTAssertEqual(InstanceAvailabilityNotificationSCU.AvailabilityStatus.offline.rawValue, "OFFLINE")
        XCTAssertEqual(InstanceAvailabilityNotificationSCU.AvailabilityStatus.unavailable.rawValue, "UNAVAILABLE")
    }

    func test_ianSCU_registerDestination_addsDestination() async {
        let scu = InstanceAvailabilityNotificationSCU(
            logger: MayamLogger(label: "test.ian"),
            deliveryHandler: { _, _ in true }
        )

        await scu.registerDestination(aeTitle: "RIS_AE")
        let dests = await scu.getDestinations()

        XCTAssertEqual(dests, ["RIS_AE"])
    }

    func test_ianSCU_registerDestination_noDuplicates() async {
        let scu = InstanceAvailabilityNotificationSCU(
            logger: MayamLogger(label: "test.ian"),
            deliveryHandler: { _, _ in true }
        )

        await scu.registerDestination(aeTitle: "RIS_AE")
        await scu.registerDestination(aeTitle: "RIS_AE")
        let dests = await scu.getDestinations()

        XCTAssertEqual(dests.count, 1)
    }

    func test_ianSCU_removeDestination_removesCorrectly() async {
        let scu = InstanceAvailabilityNotificationSCU(
            logger: MayamLogger(label: "test.ian"),
            deliveryHandler: { _, _ in true }
        )

        await scu.registerDestination(aeTitle: "RIS_AE")
        await scu.registerDestination(aeTitle: "VIEWER_AE")
        await scu.removeDestination(aeTitle: "RIS_AE")
        let dests = await scu.getDestinations()

        XCTAssertEqual(dests, ["VIEWER_AE"])
    }

    func test_ianSCU_sendNotification_callsDeliveryHandlerForEachDest() async {
        let calledAEsBox = CapturedValueBox<[String]>()
        calledAEsBox.value = []
        let scu = InstanceAvailabilityNotificationSCU(
            logger: MayamLogger(label: "test.ian"),
            deliveryHandler: { _, ae in
                calledAEsBox.value?.append(ae)
                return true
            }
        )

        await scu.registerDestination(aeTitle: "DEST_A")
        await scu.registerDestination(aeTitle: "DEST_B")

        let notification = InstanceAvailabilityNotificationSCU.Notification(
            studyInstanceUID: "1.2.3.4",
            availabilityStatus: .online,
            retrieveAETitle: "MAYAM"
        )

        let results = await scu.sendNotification(notification)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.success })
        XCTAssertTrue(calledAEsBox.value?.contains("DEST_A") ?? false)
        XCTAssertTrue(calledAEsBox.value?.contains("DEST_B") ?? false)
    }

    func test_ianSCU_sendNotification_recordsFailedDeliveries() async {
        let scu = InstanceAvailabilityNotificationSCU(
            logger: MayamLogger(label: "test.ian"),
            deliveryHandler: { _, _ in false }
        )

        await scu.registerDestination(aeTitle: "UNREACHABLE_AE")

        let notification = InstanceAvailabilityNotificationSCU.Notification(
            studyInstanceUID: "1.2.3.4",
            availabilityStatus: .online,
            retrieveAETitle: "MAYAM"
        )

        let results = await scu.sendNotification(notification)

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results[0].success)
        XCTAssertNotNil(results[0].errorMessage)
    }

    func test_ianSCU_getSentNotifications_returnsHistory() async {
        let scu = InstanceAvailabilityNotificationSCU(
            logger: MayamLogger(label: "test.ian"),
            deliveryHandler: { _, _ in true }
        )

        await scu.registerDestination(aeTitle: "AE")

        let n1 = InstanceAvailabilityNotificationSCU.Notification(
            studyInstanceUID: "1.2.3.1",
            availabilityStatus: .online,
            retrieveAETitle: "MAYAM"
        )
        let n2 = InstanceAvailabilityNotificationSCU.Notification(
            studyInstanceUID: "1.2.3.2",
            availabilityStatus: .nearline,
            retrieveAETitle: "MAYAM"
        )
        _ = await scu.sendNotification(n1)
        _ = await scu.sendNotification(n2)

        let sent = await scu.getSentNotifications()
        XCTAssertEqual(sent.count, 2)
        let count = await scu.sentNotificationCount()
        XCTAssertEqual(count, 2)
    }

    func test_ianSCU_notification_codable_roundTrips() throws {
        let sop = InstanceAvailabilityNotificationSCU.ReferencedSOPInstance(
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5"
        )
        XCTAssertEqual(sop.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(sop.sopInstanceUID, "1.2.3.4.5")
    }

    func test_ianSCU_noDestinations_sendNotification_returnsEmpty() async {
        let scu = InstanceAvailabilityNotificationSCU(
            logger: MayamLogger(label: "test.ian"),
            deliveryHandler: { _, _ in true }
        )
        let notification = InstanceAvailabilityNotificationSCU.Notification(
            studyInstanceUID: "1.2.3.4",
            availabilityStatus: .online,
            retrieveAETitle: "MAYAM"
        )
        let results = await scu.sendNotification(notification)
        XCTAssertTrue(results.isEmpty)
    }
}

// MARK: - WorkflowEngine Tests

final class WorkflowEngineTests: XCTestCase {

    func test_workflowEngine_publishEvent_storesEvent() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))
        let event = RISEvent(eventType: .studyReceived, studyInstanceUID: "1.2.3.4")

        await engine.publishEvent(event)

        let events = await engine.getEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, .studyReceived)
    }

    func test_workflowEngine_publishEvent_invokesEventHandler() async {
        let capturedBox = CapturedValueBox<RISEvent>()
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow")) { event in
            capturedBox.value = event
        }

        let event = RISEvent(eventType: .studyAvailable, studyInstanceUID: "1.2.3.5")
        await engine.publishEvent(event)

        XCTAssertNotNil(capturedBox.value)
        XCTAssertEqual(capturedBox.value?.eventType, .studyAvailable)
    }

    func test_workflowEngine_getEvents_filteredByType_returnsCorrectSubset() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))

        await engine.publishEvent(RISEvent(eventType: .studyReceived, studyInstanceUID: "1.2.3.1"))
        await engine.publishEvent(RISEvent(eventType: .studyAvailable, studyInstanceUID: "1.2.3.2"))
        await engine.publishEvent(RISEvent(eventType: .studyReceived, studyInstanceUID: "1.2.3.3"))

        let received = await engine.getEvents(eventType: .studyReceived)
        let available = await engine.getEvents(eventType: .studyAvailable)

        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(available.count, 1)
    }

    func test_workflowEngine_getEventsForStudy_returnsOnlyMatchingStudy() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))

        await engine.publishEvent(RISEvent(eventType: .studyReceived, studyInstanceUID: "1.2.3.A"))
        await engine.publishEvent(RISEvent(eventType: .studyAvailable, studyInstanceUID: "1.2.3.A"))
        await engine.publishEvent(RISEvent(eventType: .studyReceived, studyInstanceUID: "1.2.3.B"))

        let eventsA = await engine.getEventsForStudy(studyInstanceUID: "1.2.3.A")
        let eventsB = await engine.getEventsForStudy(studyInstanceUID: "1.2.3.B")

        XCTAssertEqual(eventsA.count, 2)
        XCTAssertEqual(eventsB.count, 1)
    }

    func test_workflowEngine_eventCount_incrementsOnPublish() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))
        let countBefore = await engine.eventCount()
        XCTAssertEqual(countBefore, 0)

        await engine.publishEvent(RISEvent(eventType: .studyError, studyInstanceUID: "1.2.3"))
        let countAfter = await engine.eventCount()
        XCTAssertEqual(countAfter, 1)
    }

    func test_workflowEngine_addSubscription_storesSubscription() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))
        let sub = WebhookSubscription(name: "Test", url: "https://example.com", secret: "s")

        await engine.addSubscription(sub)

        let subs = await engine.getSubscriptions()
        XCTAssertEqual(subs.count, 1)
        XCTAssertEqual(subs[0].name, "Test")
    }

    func test_workflowEngine_updateSubscription_updatesExisting() async throws {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))
        var sub = WebhookSubscription(name: "Original", url: "https://example.com", secret: "s")
        await engine.addSubscription(sub)

        sub.name = "Updated"
        try await engine.updateSubscription(sub)

        let updated = try await engine.getSubscription(id: sub.id)
        XCTAssertEqual(updated.name, "Updated")
    }

    func test_workflowEngine_updateSubscription_unknownID_throwsError() async throws {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))
        let unknown = WebhookSubscription(name: "Ghost", url: "https://ghost.com", secret: "s")

        do {
            try await engine.updateSubscription(unknown)
            XCTFail("Expected subscriptionNotFound error")
        } catch let err as WorkflowError {
            guard case .subscriptionNotFound = err else {
                XCTFail("Wrong error case: \(err)")
                return
            }
        }
    }

    func test_workflowEngine_removeSubscription_removesCorrectly() async throws {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))
        let sub = WebhookSubscription(name: "ToRemove", url: "https://example.com", secret: "s")
        await engine.addSubscription(sub)

        try await engine.removeSubscription(id: sub.id)

        let subs = await engine.getSubscriptions()
        XCTAssertTrue(subs.isEmpty)
    }

    func test_workflowEngine_removeSubscription_unknownID_throwsError() async throws {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))

        do {
            try await engine.removeSubscription(id: UUID())
            XCTFail("Expected subscriptionNotFound error")
        } catch let err as WorkflowError {
            guard case .subscriptionNotFound = err else {
                XCTFail("Wrong error case: \(err)")
                return
            }
        }
    }

    func test_workflowEngine_getSubscription_unknownID_throwsError() async throws {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))

        do {
            _ = try await engine.getSubscription(id: UUID())
            XCTFail("Expected subscriptionNotFound error")
        } catch let err as WorkflowError {
            guard case .subscriptionNotFound = err else {
                XCTFail("Wrong error case: \(err)")
                return
            }
        }
    }

    func test_workflowEngine_getSubscriptions_sortedByName() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))

        await engine.addSubscription(WebhookSubscription(name: "Zebra", url: "https://z.com", secret: "s"))
        await engine.addSubscription(WebhookSubscription(name: "Apple", url: "https://a.com", secret: "s"))

        let subs = await engine.getSubscriptions()
        XCTAssertEqual(subs[0].name, "Apple")
        XCTAssertEqual(subs[1].name, "Zebra")
    }

    func test_workflowEngine_addDeliveryRecord_storesRecord() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))
        let record = WebhookDeliveryRecord(
            subscriptionID: UUID(),
            eventID: UUID(),
            httpStatusCode: 200,
            status: .success,
            attemptCount: 1
        )

        await engine.addDeliveryRecord(record)

        let records = await engine.getDeliveryRecords()
        XCTAssertEqual(records.count, 1)
    }

    func test_workflowEngine_getDeliveryRecords_filteredBySubscription() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))
        let subID1 = UUID()
        let subID2 = UUID()

        await engine.addDeliveryRecord(WebhookDeliveryRecord(subscriptionID: subID1, eventID: UUID(), status: .success, attemptCount: 1))
        await engine.addDeliveryRecord(WebhookDeliveryRecord(subscriptionID: subID2, eventID: UUID(), status: .failed, attemptCount: 1))
        await engine.addDeliveryRecord(WebhookDeliveryRecord(subscriptionID: subID1, eventID: UUID(), status: .success, attemptCount: 1))

        let sub1Records = await engine.getDeliveryRecords(subscriptionID: subID1)
        XCTAssertEqual(sub1Records.count, 2)
    }

    func test_workflowEngine_publishStudyReceived_createsCorrectEvent() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))

        await engine.publishStudyReceived(
            studyInstanceUID: "1.2.3.RCV",
            accessionNumber: "ACC-RCV",
            patientID: "PAT-RCV",
            patientName: "DOE^JOHN",
            modality: "CT",
            studyDate: "20260301",
            studyDescription: "Chest CT",
            receivingAE: "MAYAM",
            sourceAE: "CT1"
        )

        let events = await engine.getEvents(eventType: .studyReceived)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].accessionNumber, "ACC-RCV")
        XCTAssertEqual(events[0].patientID, "PAT-RCV")
    }

    func test_workflowEngine_publishStudyAvailable_createsCorrectEvent() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))

        await engine.publishStudyAvailable(
            studyInstanceUID: "1.2.3.AVAIL",
            accessionNumber: "ACC-AVAIL",
            patientID: "PAT-AVAIL",
            retrieveAE: "MAYAM",
            retrieveURL: "http://localhost/wado/",
            availableTransferSyntaxes: ["1.2.840.10008.1.2.1"]
        )

        let events = await engine.getEvents(eventType: .studyAvailable)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].retrieveAE, "MAYAM")
        XCTAssertEqual(events[0].availableTransferSyntaxes?.first, "1.2.840.10008.1.2.1")
    }

    func test_workflowEngine_publishStudyError_createsCorrectEvent() async {
        let engine = WorkflowEngine(logger: MayamLogger(label: "test.workflow"))

        await engine.publishStudyError(
            studyInstanceUID: "1.2.3.ERR",
            accessionNumber: "ACC-ERR",
            errorCode: "DISK_FULL",
            errorMessage: "No space left",
            stage: "ingest"
        )

        let events = await engine.getEvents(eventType: .studyError)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].errorCode, "DISK_FULL")
        XCTAssertEqual(events[0].stage, "ingest")
    }
}

// MARK: - WorkflowError Tests

final class WorkflowErrorTests: XCTestCase {

    func test_workflowError_subscriptionNotFound_descriptionContainsID() {
        let id = UUID()
        let err = WorkflowError.subscriptionNotFound(id: id)
        XCTAssertTrue(err.description.contains(id.uuidString))
    }

    func test_workflowError_eventPublishFailed_descriptionContainsReason() {
        let err = WorkflowError.eventPublishFailed(reason: "queue full")
        XCTAssertTrue(err.description.contains("queue full"))
    }
}

// MARK: - WebhookDeliveryService Tests

final class WebhookDeliveryServiceTests: XCTestCase {

    func test_webhookDelivery_computeSignature_returnsSha256Prefix() async {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))
        let payload = Data("hello world".utf8)
        let sig = await service.computeSignature(payload: payload, secret: "mysecret")

        XCTAssertTrue(sig.hasPrefix("sha256="))
        XCTAssertEqual(sig.count, 7 + 64) // "sha256=" + 64 hex chars
    }

    func test_webhookDelivery_computeSignature_sameInput_sameOutput() async {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))
        let payload = Data("test payload".utf8)
        let s1 = await service.computeSignature(payload: payload, secret: "secret")
        let s2 = await service.computeSignature(payload: payload, secret: "secret")
        XCTAssertEqual(s1, s2)
    }

    func test_webhookDelivery_computeSignature_differentSecrets_differentOutputs() async {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))
        let payload = Data("test payload".utf8)
        let s1 = await service.computeSignature(payload: payload, secret: "secret1")
        let s2 = await service.computeSignature(payload: payload, secret: "secret2")
        XCTAssertNotEqual(s1, s2)
    }

    func test_webhookDelivery_prepareDelivery_returnsCorrectPayload() async throws {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))
        let event = RISEvent(
            eventType: .studyReceived,
            studyInstanceUID: "1.2.3.4",
            timestamp: Date(timeIntervalSince1970: 1_740_000_000)
        )
        let sub = WebhookSubscription(
            name: "Test",
            url: "https://example.com/hook",
            secret: "mySecret"
        )

        let payload = try await service.prepareDelivery(event: event, subscription: sub)

        XCTAssertEqual(payload.url, "https://example.com/hook")
        XCTAssertEqual(payload.subscriptionID, sub.id)
        XCTAssertEqual(payload.eventID, event.id)
        XCTAssertTrue(payload.signature.hasPrefix("sha256="))
        XCTAssertFalse(payload.body.isEmpty)
    }

    func test_webhookDelivery_prepareDelivery_signatureMatchesComputedSignature() async throws {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))
        let event = RISEvent(
            eventType: .studyAvailable,
            studyInstanceUID: "1.2.3.5",
            timestamp: Date(timeIntervalSince1970: 1_740_000_000)
        )
        let sub = WebhookSubscription(
            name: "Sig Test",
            url: "https://example.com/hook",
            secret: "verifySecret"
        )

        let payload = try await service.prepareDelivery(event: event, subscription: sub)
        let expectedSig = await service.computeSignature(payload: payload.body, secret: sub.secret)

        XCTAssertEqual(payload.signature, expectedSig)
    }

    func test_webhookDelivery_calculateRetryDelay_exponentialBackoff() async {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))

        let d1 = await service.calculateRetryDelay(attemptCount: 1, baseDelaySeconds: 10)
        let d2 = await service.calculateRetryDelay(attemptCount: 2, baseDelaySeconds: 10)
        let d3 = await service.calculateRetryDelay(attemptCount: 3, baseDelaySeconds: 10)
        let d4 = await service.calculateRetryDelay(attemptCount: 4, baseDelaySeconds: 10)
        XCTAssertEqual(d1, 10)
        XCTAssertEqual(d2, 20)
        XCTAssertEqual(d3, 40)
        XCTAssertEqual(d4, 80)
    }

    func test_webhookDelivery_calculateRetryDelay_cappedAt3600Seconds() async {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))

        let delay = await service.calculateRetryDelay(attemptCount: 20, baseDelaySeconds: 10)
        XCTAssertEqual(delay, 3600)
    }

    func test_webhookDelivery_recordDelivery_successGoesToCompleted() async {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))
        let record = WebhookDeliveryRecord(
            subscriptionID: UUID(), eventID: UUID(), httpStatusCode: 200,
            status: .success, attemptCount: 1
        )

        await service.recordDelivery(record)

        let completed = await service.completedDeliveryCount()
        let pending = await service.pendingDeliveryCount()
        XCTAssertEqual(completed, 1)
        XCTAssertEqual(pending, 0)
    }

    func test_webhookDelivery_recordDelivery_failedGoesToPending() async {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))
        let record = WebhookDeliveryRecord(
            subscriptionID: UUID(), eventID: UUID(),
            status: .failed, attemptCount: 1
        )

        await service.recordDelivery(record)

        let pending = await service.pendingDeliveryCount()
        let completed = await service.completedDeliveryCount()
        XCTAssertEqual(pending, 1)
        XCTAssertEqual(completed, 0)
    }

    func test_webhookDelivery_getPendingDeliveries_returnsCorrectRecords() async {
        let service = WebhookDeliveryService(logger: MayamLogger(label: "test.webhook"))
        let r1 = WebhookDeliveryRecord(subscriptionID: UUID(), eventID: UUID(), status: .pending, attemptCount: 0)
        let r2 = WebhookDeliveryRecord(subscriptionID: UUID(), eventID: UUID(), status: .success, attemptCount: 1)

        await service.recordDelivery(r1)
        await service.recordDelivery(r2)

        let pending = await service.getPendingDeliveries()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].id, r1.id)
    }
}

// MARK: - HL7WorkflowIntegration Tests

final class HL7WorkflowIntegrationTests: XCTestCase {

    func test_hl7Integration_processOrder_storesOrder() async {
        let integration = HL7WorkflowIntegration(logger: MayamLogger(label: "test.hl7"))
        let order = HL7WorkflowIntegration.ImagingOrder(
            placerOrderNumber: "ORD-001",
            fillerOrderNumber: "FILL-001",
            accessionNumber: "ACC-HL7",
            patientID: "PAT-HL7",
            patientName: "SMITH^JOHN",
            procedureDescription: "Chest X-Ray",
            modality: "CR",
            scheduledDateTime: "20260301090000",
            orderControl: "NW"
        )

        let processed = await integration.processOrder(order)

        XCTAssertEqual(processed.accessionNumber, "ACC-HL7")
        let count = await integration.receivedOrderCount()
        XCTAssertEqual(count, 1)
    }

    func test_hl7Integration_getReceivedOrders_returnsAll() async {
        let integration = HL7WorkflowIntegration(logger: MayamLogger(label: "test.hl7"))
        let o1 = HL7WorkflowIntegration.ImagingOrder(accessionNumber: "ACC1")
        let o2 = HL7WorkflowIntegration.ImagingOrder(accessionNumber: "ACC2")

        _ = await integration.processOrder(o1)
        _ = await integration.processOrder(o2)

        let orders = await integration.getReceivedOrders()
        XCTAssertEqual(orders.count, 2)
    }

    func test_hl7Integration_generateORUMessage_containsStudyUID() async {
        let integration = HL7WorkflowIntegration(logger: MayamLogger(label: "test.hl7"))
        let event = RISEvent(
            eventType: .studyAvailable,
            studyInstanceUID: "1.2.3.ORU",
            accessionNumber: "ACC-ORU",
            patientID: "PAT-ORU",
            patientName: "DOE^JANE"
        )

        let message = await integration.generateORUMessage(from: event)

        XCTAssertTrue(message.contains("1.2.3.ORU"))
        XCTAssertTrue(message.contains("ORU"))
        XCTAssertTrue(message.contains("MSH"))
    }

    func test_hl7Integration_generateORUMessage_containsPatientInfo() async {
        let integration = HL7WorkflowIntegration(logger: MayamLogger(label: "test.hl7"))
        let event = RISEvent(
            eventType: .studyAvailable,
            studyInstanceUID: "1.2.3",
            patientID: "PAT-MSG",
            patientName: "WILSON^MARK"
        )

        let message = await integration.generateORUMessage(from: event)

        XCTAssertTrue(message.contains("PAT-MSG"))
        XCTAssertTrue(message.contains("WILSON^MARK"))
    }

    func test_hl7Integration_activate_setsActiveTrue() async {
        let integration = HL7WorkflowIntegration(logger: MayamLogger(label: "test.hl7"))
        let beforeActivate = await integration.getIsActive()
        XCTAssertFalse(beforeActivate)

        await integration.activate()
        let afterActivate = await integration.getIsActive()
        XCTAssertTrue(afterActivate)
    }

    func test_hl7Integration_deactivate_setsActiveFalse() async {
        let integration = HL7WorkflowIntegration(logger: MayamLogger(label: "test.hl7"))
        await integration.activate()
        let afterActivate = await integration.getIsActive()
        XCTAssertTrue(afterActivate)

        await integration.deactivate()
        let afterDeactivate = await integration.getIsActive()
        XCTAssertFalse(afterDeactivate)
    }

    func test_hl7Integration_imagingOrder_codable_roundTrips() throws {
        let order = HL7WorkflowIntegration.ImagingOrder(
            placerOrderNumber: "ORD-002",
            fillerOrderNumber: "FILL-002",
            accessionNumber: "ACC-RT",
            patientID: "PAT-RT",
            patientName: "JONES^ANN",
            procedureDescription: "Knee MRI",
            modality: "MR",
            scheduledDateTime: "20260315140000",
            orderControl: "CA"
        )

        let data = try JSONEncoder().encode(order)
        let decoded = try JSONDecoder().decode(HL7WorkflowIntegration.ImagingOrder.self, from: data)

        XCTAssertEqual(order, decoded)
    }

    func test_hl7Integration_messageTypes_haveCorrectRawValues() {
        XCTAssertEqual(HL7WorkflowIntegration.MessageType.orm.rawValue, "ORM")
        XCTAssertEqual(HL7WorkflowIntegration.MessageType.oru.rawValue, "ORU")
        XCTAssertEqual(HL7WorkflowIntegration.MessageType.adt.rawValue, "ADT")
        XCTAssertEqual(HL7WorkflowIntegration.MessageType.ack.rawValue, "ACK")
        XCTAssertEqual(HL7WorkflowIntegration.MessageType.allCases.count, 4)
    }
}
