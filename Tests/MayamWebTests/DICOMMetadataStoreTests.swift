// SPDX-License-Identifier: (see LICENSE)
// Mayam — In-Memory DICOM Metadata Store Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class DICOMMetadataStoreTests: XCTestCase {

    private func makeStore() -> InMemoryDICOMMetadataStore {
        InMemoryDICOMMetadataStore()
    }

    private func storeTestInstance(
        in store: InMemoryDICOMMetadataStore,
        sopUID: String = "1.2.3.4.5",
        seriesUID: String = "1.2.3.4",
        studyUID: String = "1.2.3",
        patientID: String = "P001"
    ) async throws {
        let patient = Patient(id: 1, patientID: patientID)
        let study = Study(id: 1, studyInstanceUID: studyUID, patientID: 1)
        let series = Series(id: 1, seriesInstanceUID: seriesUID, studyID: 1, instanceCount: 1)
        let instance = Instance(
            id: 1,
            sopInstanceUID: sopUID,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesID: 1,
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            fileSizeBytes: 512,
            filePath: "\(patientID)/\(studyUID)/\(seriesUID)/\(sopUID).dcm"
        )
        try await store.storeInstance(instance: instance, series: series, study: study, patient: patient)
    }

    // MARK: - Study Operations

    func test_store_searchStudies_empty_returnsEmpty() async {
        let store = makeStore()
        let results = await store.searchStudies(query: StudyQuery(from: [:]))
        XCTAssertTrue(results.isEmpty)
    }

    func test_store_searchStudies_afterStore_returnsResult() async throws {
        let store = makeStore()
        try await storeTestInstance(in: store)
        let results = await store.searchStudies(query: StudyQuery(from: [:]))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].study.studyInstanceUID, "1.2.3")
        XCTAssertEqual(results[0].patient.patientID, "P001")
    }

    func test_store_findStudy_exists_returnsResult() async throws {
        let store = makeStore()
        try await storeTestInstance(in: store)
        let result = await store.findStudy(uid: "1.2.3")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.study.studyInstanceUID, "1.2.3")
    }

    func test_store_findStudy_notFound_returnsNil() async {
        let store = makeStore()
        let result = await store.findStudy(uid: "1.2.nonexistent")
        XCTAssertNil(result)
    }

    // MARK: - Series Operations

    func test_store_searchSeries_afterStore_returnsResult() async throws {
        let store = makeStore()
        try await storeTestInstance(in: store)
        let results = await store.searchSeries(studyUID: "1.2.3", query: [:])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].series.seriesInstanceUID, "1.2.3.4")
    }

    func test_store_findSeries_exists_returnsResult() async throws {
        let store = makeStore()
        try await storeTestInstance(in: store)
        let result = await store.findSeries(uid: "1.2.3.4", inStudy: "1.2.3")
        XCTAssertNotNil(result)
    }

    func test_store_findSeries_wrongStudy_returnsNil() async throws {
        let store = makeStore()
        try await storeTestInstance(in: store)
        let result = await store.findSeries(uid: "1.2.3.4", inStudy: "1.2.wrong")
        XCTAssertNil(result)
    }

    // MARK: - Instance Operations

    func test_store_findInstance_exists_returnsResult() async throws {
        let store = makeStore()
        try await storeTestInstance(in: store)
        let result = await store.findInstance(sopInstanceUID: "1.2.3.4.5")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.instance.sopInstanceUID, "1.2.3.4.5")
    }

    func test_store_findInstance_notFound_returnsNil() async {
        let store = makeStore()
        let result = await store.findInstance(sopInstanceUID: "1.2.nonexistent")
        XCTAssertNil(result)
    }

    func test_store_allInstances_inStudy_returnsAll() async throws {
        let store = makeStore()
        try await storeTestInstance(in: store, sopUID: "1.2.3.4.5")
        // Store a second instance in a different series of the same study
        let patient = Patient(id: 1, patientID: "P001")
        let study = Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1)
        let series2 = Series(id: 2, seriesInstanceUID: "1.2.3.5", studyID: 1, instanceCount: 1)
        let instance2 = Instance(
            id: 2,
            sopInstanceUID: "1.2.3.5.6",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesID: 2,
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            fileSizeBytes: 512,
            filePath: "P001/1.2.3/1.2.3.5/1.2.3.5.6.dcm"
        )
        try await store.storeInstance(instance: instance2, series: series2, study: study, patient: patient)

        let all = await store.allInstances(inStudy: "1.2.3")
        XCTAssertEqual(all.count, 2)
    }

    func test_store_searchInstances_filteredBySOPUID() async throws {
        let store = makeStore()
        try await storeTestInstance(in: store, sopUID: "1.2.3.4.5")
        let results = await store.searchInstances(
            studyUID: "1.2.3",
            seriesUID: "1.2.3.4",
            query: ["SOPInstanceUID": "1.2.3.4.5"]
        )
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Multiple Studies

    func test_store_multipleStudies_allReturned() async throws {
        let store = makeStore()
        // Insert 3 studies for different patients
        for i in 1...3 {
            let pid = "P\(String(format: "%03d", i))"
            let studyUID = "1.2.3.\(i)"
            let seriesUID = "1.2.3.\(i).1"
            let sopUID = "1.2.3.\(i).1.1"
            let patient = Patient(id: Int64(i), patientID: pid)
            let study = Study(id: Int64(i), studyInstanceUID: studyUID, patientID: Int64(i))
            let series = Series(id: Int64(i), seriesInstanceUID: seriesUID, studyID: Int64(i), instanceCount: 1)
            let instance = Instance(
                id: Int64(i),
                sopInstanceUID: sopUID,
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                seriesID: Int64(i),
                transferSyntaxUID: "1.2.840.10008.1.2.1",
                fileSizeBytes: 512,
                filePath: "\(pid)/\(studyUID)/\(seriesUID)/\(sopUID).dcm"
            )
            try await store.storeInstance(instance: instance, series: series, study: study, patient: patient)
        }

        let results = await store.searchStudies(query: StudyQuery(from: [:]))
        XCTAssertEqual(results.count, 3)
    }
}
