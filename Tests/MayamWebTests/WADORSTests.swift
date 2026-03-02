// SPDX-License-Identifier: (see LICENSE)
// Mayam — WADO-RS Handler Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class WADORSTests: XCTestCase {

    private var tempDir: String = ""

    override func setUp() {
        tempDir = NSTemporaryDirectory() + "mayam_wadors_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    private func makeStore() -> InMemoryDICOMMetadataStore {
        InMemoryDICOMMetadataStore()
    }

    // MARK: - Retrieve Study

    func test_wadoRS_retrieveStudy_notFound_throws() async {
        let store = makeStore()
        let handler = WADORSHandler(archivePath: tempDir, metadataStore: store)
        do {
            _ = try await handler.retrieveStudy(studyUID: "1.2.3.nonexistent")
            XCTFail("Expected DICOMwebError.notFound")
        } catch DICOMwebError.notFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_wadoRS_retrieveStudy_withInstances_returnsMultipart() async throws {
        let store = makeStore()
        let patient = Patient(id: 1, patientID: "P001")
        let study = Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1)
        let series = Series(id: 1, seriesInstanceUID: "1.2.3.4", studyID: 1, instanceCount: 1)

        // Write a fake DICOM file to disk
        let relPath = "P001/1.2.3/1.2.3.4/1.2.3.4.5.dcm"
        let absPath = tempDir + "/" + relPath
        try FileManager.default.createDirectory(
            atPath: (absPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )
        let fakeData = "FAKE_DICOM".data(using: .utf8)!
        try fakeData.write(to: URL(fileURLWithPath: absPath))

        let instance = Instance(
            id: 1,
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesID: 1,
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            fileSizeBytes: Int64(fakeData.count),
            filePath: relPath
        )
        try await store.storeInstance(instance: instance, series: series, study: study, patient: patient)

        let handler = WADORSHandler(archivePath: tempDir, metadataStore: store)
        let response = try await handler.retrieveStudy(studyUID: "1.2.3")
        XCTAssertTrue(response.contentType.contains("multipart/related"))
        XCTAssertFalse(response.body.isEmpty)
    }

    // MARK: - Retrieve Instance Metadata

    func test_wadoRS_retrieveInstanceMetadata_notFound_throws() async {
        let store = makeStore()
        let handler = WADORSHandler(archivePath: tempDir, metadataStore: store)
        do {
            _ = try await handler.retrieveInstanceMetadata(
                studyUID: "1.2.3",
                seriesUID: "1.2.3.4",
                instanceUID: "1.2.3.4.5.nonexistent"
            )
            XCTFail("Expected DICOMwebError.notFound")
        } catch DICOMwebError.notFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_wadoRS_retrieveStudyMetadata_returnsJSON() async throws {
        let store = makeStore()
        let patient = Patient(id: 1, patientID: "P001")
        let study = Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1)
        let series = Series(id: 1, seriesInstanceUID: "1.2.3.4", studyID: 1, instanceCount: 1)
        let instance = Instance(
            id: 1,
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesID: 1,
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            fileSizeBytes: 100,
            filePath: "p/s/s/i.dcm"
        )
        try await store.storeInstance(instance: instance, series: series, study: study, patient: patient)

        let handler = WADORSHandler(archivePath: tempDir, metadataStore: store)
        let response = try await handler.retrieveStudyMetadata(studyUID: "1.2.3")
        XCTAssertEqual(response.contentType, "application/dicom+json")

        let array = try JSONSerialization.jsonObject(with: response.body) as? [[String: Any]]
        XCTAssertEqual(array?.count, 1)
    }

    // MARK: - Retrieve Frames

    func test_wadoRS_retrieveFrames_invalidFrameNumber_throws() async throws {
        let store = makeStore()
        let patient = Patient(id: 1, patientID: "P001")
        let study = Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1)
        let series = Series(id: 1, seriesInstanceUID: "1.2.3.4", studyID: 1, instanceCount: 1)
        let instance = Instance(
            id: 1,
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesID: 1,
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            fileSizeBytes: 100,
            filePath: "p/s/s/i.dcm"
        )
        try await store.storeInstance(instance: instance, series: series, study: study, patient: patient)

        let handler = WADORSHandler(archivePath: tempDir, metadataStore: store)
        do {
            _ = try await handler.retrieveFrames(
                studyUID: "1.2.3",
                seriesUID: "1.2.3.4",
                instanceUID: "1.2.3.4.5",
                frameNumbers: [0] // 0 is invalid (1-based)
            )
            XCTFail("Expected DICOMwebError.badRequest")
        } catch DICOMwebError.badRequest {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
