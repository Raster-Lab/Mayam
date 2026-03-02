// SPDX-License-Identifier: (see LICENSE)
// Mayam — QIDO-RS Handler Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class QIDORSTests: XCTestCase {

    private func makeStore() -> InMemoryDICOMMetadataStore {
        InMemoryDICOMMetadataStore()
    }

    // MARK: - StudyQuery Parsing

    func test_studyQuery_defaultLimits() {
        let q = StudyQuery(from: [:])
        XCTAssertEqual(q.limit, 100)
        XCTAssertEqual(q.offset, 0)
        XCTAssertNil(q.studyInstanceUID)
        XCTAssertNil(q.patientID)
    }

    func test_studyQuery_parsesStudyInstanceUID() {
        let q = StudyQuery(from: ["StudyInstanceUID": "1.2.3"])
        XCTAssertEqual(q.studyInstanceUID, "1.2.3")
    }

    func test_studyQuery_parsesTagBasedKey() {
        let q = StudyQuery(from: ["0020000D": "1.2.3.4"])
        XCTAssertEqual(q.studyInstanceUID, "1.2.3.4")
    }

    func test_studyQuery_limitsLimitToMax() {
        let q = StudyQuery(from: ["limit": "9999"])
        XCTAssertEqual(q.limit, 1000)
    }

    // MARK: - QIDO-RS Study Search

    func test_qidoRS_searchStudies_emptyStore_returnsEmptyArray() async throws {
        let store = makeStore()
        let handler = QIDORSHandler(metadataStore: store)

        let data = try await handler.searchStudies(queryParams: [:])
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(array)
        XCTAssertEqual(array?.count, 0)
    }

    func test_qidoRS_searchStudies_withMatches_returnsMandatoryTags() async throws {
        let store = makeStore()
        let patient = Patient(id: 1, patientID: "P001", patientName: "Test Patient")
        let study = Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1, studyDescription: "Test")
        let series = Series(id: 1, seriesInstanceUID: "1.2.3.4", studyID: 1, instanceCount: 3)
        let instance = Instance(
            id: 1,
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesID: 1,
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            fileSizeBytes: 1024,
            filePath: "p/s/s/i.dcm"
        )
        try await store.storeInstance(instance: instance, series: series, study: study, patient: patient)

        let handler = QIDORSHandler(metadataStore: store)
        let data = try await handler.searchStudies(queryParams: [:])
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(array?.count, 1)

        let studyObj = array![0]
        XCTAssertNotNil(studyObj["0020000D"]) // Study Instance UID
        XCTAssertNotNil(studyObj["00100020"]) // Patient ID
    }

    func test_qidoRS_searchStudies_filteredByPatientID() async throws {
        let store = makeStore()
        let p1 = Patient(id: 1, patientID: "P001")
        let p2 = Patient(id: 2, patientID: "P002")
        let s1 = Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1)
        let s2 = Study(id: 2, studyInstanceUID: "1.2.4", patientID: 2)
        let series1 = Series(id: 1, seriesInstanceUID: "1.2.3.1", studyID: 1, instanceCount: 1)
        let series2 = Series(id: 2, seriesInstanceUID: "1.2.4.1", studyID: 2, instanceCount: 1)
        let inst1 = Instance(id: 1, sopInstanceUID: "1.1", sopClassUID: "1", seriesID: 1, transferSyntaxUID: "1.2.840.10008.1.2.1", fileSizeBytes: 1, filePath: "a")
        let inst2 = Instance(id: 2, sopInstanceUID: "2.2", sopClassUID: "1", seriesID: 2, transferSyntaxUID: "1.2.840.10008.1.2.1", fileSizeBytes: 1, filePath: "b")

        try await store.storeInstance(instance: inst1, series: series1, study: s1, patient: p1)
        try await store.storeInstance(instance: inst2, series: series2, study: s2, patient: p2)

        let handler = QIDORSHandler(metadataStore: store)
        let data = try await handler.searchStudies(queryParams: ["PatientID": "P001"])
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(array?.count, 1)
    }

    // MARK: - QIDO-RS Series Search

    func test_qidoRS_searchSeries_emptyStudyUID_throws() async {
        let store = makeStore()
        let handler = QIDORSHandler(metadataStore: store)
        do {
            _ = try await handler.searchSeries(studyUID: "", queryParams: [:])
            XCTFail("Expected DICOMwebError.badRequest")
        } catch DICOMwebError.badRequest {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_qidoRS_searchSeries_unknownStudy_returnsEmpty() async throws {
        let store = makeStore()
        let handler = QIDORSHandler(metadataStore: store)
        let data = try await handler.searchSeries(studyUID: "1.2.3.nonexistent", queryParams: [:])
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(array?.count, 0)
    }

    // MARK: - QIDO-RS Instance Search

    func test_qidoRS_searchInstances_emptySeriesUID_throws() async {
        let store = makeStore()
        let handler = QIDORSHandler(metadataStore: store)
        do {
            _ = try await handler.searchInstances(studyUID: "1.2.3", seriesUID: "", queryParams: [:])
            XCTFail("Expected DICOMwebError.badRequest")
        } catch DICOMwebError.badRequest {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
