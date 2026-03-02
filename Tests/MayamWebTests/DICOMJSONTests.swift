// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOM JSON Attribute Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class DICOMJSONAttributeTests: XCTestCase {

    // MARK: - DICOMAttribute Encoding

    func test_dicomAttribute_stringValues_encodesCorrectly() throws {
        let attr = DICOMAttribute(vr: "LO", stringValues: ["TEST_VALUE"])
        let data = try JSONEncoder().encode(attr)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["vr"] as? String, "LO")
        XCTAssertEqual((json["Value"] as? [String])?.first, "TEST_VALUE")
    }

    func test_dicomAttribute_numberValues_encodesCorrectly() throws {
        let attr = DICOMAttribute(vr: "US", numberValues: [42.0])
        let data = try JSONEncoder().encode(attr)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["vr"] as? String, "US")
        XCTAssertEqual((json["Value"] as? [Double])?.first, 42.0)
    }

    func test_dicomAttribute_bulkDataURI_encodesCorrectly() throws {
        let attr = DICOMAttribute(vr: "OW", bulkDataURI: "http://example.com/bulk/123")
        let data = try JSONEncoder().encode(attr)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["vr"] as? String, "OW")
        XCTAssertEqual(json["BulkDataURI"] as? String, "http://example.com/bulk/123")
    }

    func test_dicomAttribute_binaryData_encodesAsBase64() throws {
        let bytes = Data([0x01, 0x02, 0x03])
        let attr = DICOMAttribute(vr: "OB", binaryData: bytes)
        let data = try JSONEncoder().encode(attr)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["vr"] as? String, "OB")
        XCTAssertNotNil(json["InlineBinary"])
    }

    // MARK: - DICOMJSONSerializer

    func test_serializer_studyAttributes_containsMandatoryTags() {
        let study = Study(
            studyInstanceUID: "1.2.3.4.5",
            patientID: 1,
            studyDescription: "Test Study",
            modality: "CT"
        )
        let patient = Patient(patientID: "P001", patientName: "Test Patient")

        let attrs = DICOMJSONSerializer.studyAttributes(
            study: study,
            patient: patient,
            numberOfSeries: 2,
            numberOfInstances: 10
        )

        // Mandatory QIDO-RS study attributes
        XCTAssertNotNil(attrs["0020000D"]) // Study Instance UID
        XCTAssertNotNil(attrs["00100020"]) // Patient ID
        XCTAssertNotNil(attrs["00100010"]) // Patient Name
        XCTAssertNotNil(attrs["00201206"]) // Number of Series
        XCTAssertNotNil(attrs["00201208"]) // Number of Instances

        XCTAssertEqual(attrs["0020000D"]?.stringValues?.first, "1.2.3.4.5")
        XCTAssertEqual(attrs["00100020"]?.stringValues?.first, "P001")
        XCTAssertEqual(attrs["00201206"]?.stringValues?.first, "2")
        XCTAssertEqual(attrs["00201208"]?.stringValues?.first, "10")
    }

    func test_serializer_seriesAttributes_containsMandatoryTags() {
        let study = Study(studyInstanceUID: "1.2.3", patientID: 1)
        let series = Series(seriesInstanceUID: "1.2.3.4", studyID: 1, modality: "MR", instanceCount: 5)

        let attrs = DICOMJSONSerializer.seriesAttributes(
            series: series,
            study: study,
            numberOfInstances: 5
        )

        XCTAssertNotNil(attrs["0020000E"]) // Series Instance UID
        XCTAssertNotNil(attrs["00080060"]) // Modality
        XCTAssertNotNil(attrs["00201209"]) // Number of Instances

        XCTAssertEqual(attrs["0020000E"]?.stringValues?.first, "1.2.3.4")
        XCTAssertEqual(attrs["00080060"]?.stringValues?.first, "MR")
        XCTAssertEqual(attrs["00201209"]?.stringValues?.first, "5")
    }

    func test_serializer_instanceAttributes_containsMandatoryTags() {
        let study = Study(studyInstanceUID: "1.2.3", patientID: 1)
        let series = Series(seriesInstanceUID: "1.2.3.4", studyID: 1)
        let instance = Instance(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesID: 1,
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            fileSizeBytes: 1024,
            filePath: "p/s/s/instance.dcm"
        )

        let attrs = DICOMJSONSerializer.instanceAttributes(
            instance: instance,
            series: series,
            study: study
        )

        XCTAssertNotNil(attrs["00080016"]) // SOP Class UID
        XCTAssertNotNil(attrs["00080018"]) // SOP Instance UID
        XCTAssertNotNil(attrs["0020000D"]) // Study Instance UID
        XCTAssertNotNil(attrs["0020000E"]) // Series Instance UID

        XCTAssertEqual(attrs["00080018"]?.stringValues?.first, "1.2.3.4.5")
        XCTAssertEqual(attrs["00080016"]?.stringValues?.first, "1.2.840.10008.5.1.4.1.1.2")
    }

    func test_serializer_encodeArray_producesValidJSON() throws {
        let study = Study(studyInstanceUID: "1.2.3", patientID: 1)
        let patient = Patient(patientID: "P001")
        let attrs = DICOMJSONSerializer.studyAttributes(study: study, patient: patient)

        let data = try DICOMJSONSerializer.encodeArray([attrs])
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(array)
        XCTAssertEqual(array?.count, 1)
    }

    // MARK: - Date Formatting

    func test_formatDICOMDate_producesCorrectFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar.current.date(from: components)!
        XCTAssertEqual(DICOMJSONSerializer.formatDICOMDate(date), "20260302")
    }
}
