// SPDX-License-Identifier: (see LICENSE)
// Mayam — FHIR R4 Resource Model Tests

import XCTest
@testable import MayamCore

final class FHIRResourceModelTests: XCTestCase {

    // MARK: - Supporting Types

    func test_fhirReference_defaultInit_allNil() {
        let ref = FHIRReference()
        XCTAssertNil(ref.reference)
        XCTAssertNil(ref.display)
        XCTAssertNil(ref.type)
    }

    func test_fhirReference_fullInit_storesValues() {
        let ref = FHIRReference(reference: "Patient/1", display: "Jane", type: "Patient")
        XCTAssertEqual(ref.reference, "Patient/1")
        XCTAssertEqual(ref.display, "Jane")
        XCTAssertEqual(ref.type, "Patient")
    }

    func test_fhirIdentifier_roundTrip_preservesValues() throws {
        let identifier = FHIRIdentifier(system: "urn:dicom:uid", value: "1.2.3")
        let data = try JSONEncoder().encode(identifier)
        let decoded = try JSONDecoder().decode(FHIRIdentifier.self, from: data)
        XCTAssertEqual(identifier, decoded)
    }

    func test_fhirCoding_roundTrip_preservesValues() throws {
        let coding = FHIRCoding(system: "http://example.org", code: "CT", display: "Computed Tomography")
        let data = try JSONEncoder().encode(coding)
        let decoded = try JSONDecoder().decode(FHIRCoding.self, from: data)
        XCTAssertEqual(coding, decoded)
    }

    func test_fhirCodeableConcept_withCodingAndText_roundTrips() throws {
        let concept = FHIRCodeableConcept(
            coding: [FHIRCoding(system: "http://example.org", code: "A")],
            text: "Test concept"
        )
        let data = try JSONEncoder().encode(concept)
        let decoded = try JSONDecoder().decode(FHIRCodeableConcept.self, from: data)
        XCTAssertEqual(concept, decoded)
    }

    func test_fhirAnnotation_storesText() {
        let annotation = FHIRAnnotation(text: "Important note")
        XCTAssertEqual(annotation.text, "Important note")
    }

    func test_fhirContactPoint_roundTrip_preservesValues() throws {
        let contact = FHIRContactPoint(system: "email", value: "admin@example.org")
        let data = try JSONEncoder().encode(contact)
        let decoded = try JSONDecoder().decode(FHIRContactPoint.self, from: data)
        XCTAssertEqual(contact, decoded)
    }

    func test_fhirPeriod_roundTrip_preservesValues() throws {
        let period = FHIRPeriod(start: "2025-01-01", end: "2025-12-31")
        let data = try JSONEncoder().encode(period)
        let decoded = try JSONDecoder().decode(FHIRPeriod.self, from: data)
        XCTAssertEqual(period, decoded)
    }

    // MARK: - FHIRImagingStudy

    func test_imagingStudy_resourceType_isImagingStudy() {
        let study = FHIRImagingStudy(
            status: .available,
            subject: FHIRReference(reference: "Patient/1")
        )
        XCTAssertEqual(study.resourceType, "ImagingStudy")
    }

    func test_imagingStudy_resourceType_includedInEncodedJSON() throws {
        let study = FHIRImagingStudy(
            status: .available,
            subject: FHIRReference(reference: "Patient/1")
        )
        let data = try JSONEncoder().encode(study)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["resourceType"] as? String, "ImagingStudy")
    }

    func test_imagingStudy_statusEncoding_handlesEnteredInError() throws {
        let study = FHIRImagingStudy(
            status: .enteredInError,
            subject: FHIRReference(reference: "Patient/1")
        )
        let data = try JSONEncoder().encode(study)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"entered-in-error\""))
    }

    func test_imagingStudy_fullRoundTrip_preservesAllFields() throws {
        let instance = FHIRImagingStudy.Series.Instance(
            uid: "1.2.3.4.5",
            sopClass: FHIRCoding(system: "urn:ietf:rfc:3986", code: "1.2.840.10008.5.1.4.1.1.2"),
            number: 1,
            title: "Axial slice"
        )
        let series = FHIRImagingStudy.Series(
            uid: "1.2.3.4",
            number: 1,
            modality: FHIRCoding(system: "http://dicom.nema.org/resources/ontology/DCM", code: "CT"),
            description_: "CT Abdomen",
            numberOfInstances: 1,
            endpoint: [FHIRReference(reference: "Endpoint/wado")],
            bodySite: FHIRCoding(code: "T-D4000"),
            laterality: FHIRCoding(code: "R"),
            started: "2025-06-01T10:00:00Z",
            instance: [instance]
        )
        let study = FHIRImagingStudy(
            id: "study-1",
            status: .available,
            subject: FHIRReference(reference: "Patient/1", display: "Test Patient"),
            started: "2025-06-01T10:00:00Z",
            basedOn: [FHIRReference(reference: "ServiceRequest/1")],
            referrer: FHIRReference(reference: "Practitioner/1"),
            endpoint: [FHIRReference(reference: "Endpoint/wado")],
            numberOfSeries: 1,
            numberOfInstances: 1,
            description_: "CT Abdomen/Pelvis",
            series: [series],
            identifier: [FHIRIdentifier(system: "urn:dicom:uid", value: "1.2.3")],
            modality: [FHIRCoding(code: "CT")],
            reasonCode: [FHIRCodeableConcept(text: "Abdominal pain")],
            note: [FHIRAnnotation(text: "Urgent")]
        )
        let data = try JSONEncoder().encode(study)
        let decoded = try JSONDecoder().decode(FHIRImagingStudy.self, from: data)
        XCTAssertEqual(study, decoded)
    }

    func test_imagingStudy_descriptionKey_encodesAsDescription() throws {
        let study = FHIRImagingStudy(
            status: .registered,
            subject: FHIRReference(reference: "Patient/1"),
            description_: "Test study"
        )
        let data = try JSONEncoder().encode(study)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"description\""))
        XCTAssertFalse(json.contains("\"description_\""))
    }

    func test_imagingStudy_seriesDescriptionKey_encodesAsDescription() throws {
        let series = FHIRImagingStudy.Series(
            uid: "1.2.3",
            modality: FHIRCoding(code: "MR"),
            description_: "Brain MRI"
        )
        let data = try JSONEncoder().encode(series)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"description\""))
        XCTAssertFalse(json.contains("\"description_\""))
    }

    func test_imagingStudy_minimalInit_optionalsAreNil() {
        let study = FHIRImagingStudy(
            status: .unknown,
            subject: FHIRReference()
        )
        XCTAssertNil(study.id)
        XCTAssertNil(study.started)
        XCTAssertNil(study.basedOn)
        XCTAssertNil(study.referrer)
        XCTAssertNil(study.endpoint)
        XCTAssertNil(study.numberOfSeries)
        XCTAssertNil(study.numberOfInstances)
        XCTAssertNil(study.description_)
        XCTAssertNil(study.series)
        XCTAssertNil(study.identifier)
        XCTAssertNil(study.modality)
        XCTAssertNil(study.reasonCode)
        XCTAssertNil(study.note)
    }

    func test_imagingStudy_allStatuses_roundTrip() throws {
        let statuses: [FHIRImagingStudy.Status] = [
            .registered, .available, .cancelled, .enteredInError, .unknown
        ]
        for status in statuses {
            let study = FHIRImagingStudy(status: status, subject: FHIRReference())
            let data = try JSONEncoder().encode(study)
            let decoded = try JSONDecoder().decode(FHIRImagingStudy.self, from: data)
            XCTAssertEqual(decoded.status, status)
        }
    }

    // MARK: - FHIREndpoint

    func test_endpoint_resourceType_isEndpoint() {
        let ep = FHIREndpoint(
            status: .active,
            connectionType: FHIRCoding(code: "dicom-wado-rs"),
            payloadType: [FHIRCodeableConcept(text: "DICOM")],
            address: "https://pacs.example.org/wado-rs"
        )
        XCTAssertEqual(ep.resourceType, "Endpoint")
    }

    func test_endpoint_resourceType_includedInEncodedJSON() throws {
        let ep = FHIREndpoint(
            status: .active,
            connectionType: FHIRCoding(code: "dicom-wado-rs"),
            payloadType: [],
            address: "https://pacs.example.org/wado-rs"
        )
        let data = try JSONEncoder().encode(ep)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["resourceType"] as? String, "Endpoint")
    }

    func test_endpoint_fullRoundTrip_preservesAllFields() throws {
        let ep = FHIREndpoint(
            id: "ep-1",
            status: .active,
            connectionType: FHIRCoding(
                system: "http://terminology.hl7.org/CodeSystem/endpoint-connection-type",
                code: "dicom-wado-rs",
                display: "DICOM WADO-RS"
            ),
            name: "Main PACS WADO-RS",
            managingOrganization: FHIRReference(reference: "Organization/1"),
            contact: [FHIRContactPoint(system: "email", value: "admin@example.org")],
            period: FHIRPeriod(start: "2025-01-01"),
            payloadType: [FHIRCodeableConcept(text: "DICOM")],
            payloadMimeType: ["application/dicom"],
            address: "https://pacs.example.org/wado-rs",
            header: ["Authorization: Bearer token"],
            identifier: [FHIRIdentifier(system: "urn:example", value: "ep-001")]
        )
        let data = try JSONEncoder().encode(ep)
        let decoded = try JSONDecoder().decode(FHIREndpoint.self, from: data)
        XCTAssertEqual(ep, decoded)
    }

    func test_endpoint_statusEncoding_handlesEnteredInError() throws {
        let ep = FHIREndpoint(
            status: .enteredInError,
            connectionType: FHIRCoding(code: "dicom-wado-rs"),
            payloadType: [FHIRCodeableConcept(text: "DICOM")],
            address: "https://pacs.example.org"
        )
        let data = try JSONEncoder().encode(ep)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"entered-in-error\""))
    }

    func test_endpoint_allStatuses_roundTrip() throws {
        let statuses: [FHIREndpoint.Status] = [
            .active, .suspended, .error, .off, .enteredInError
        ]
        for status in statuses {
            let ep = FHIREndpoint(
                status: status,
                connectionType: FHIRCoding(code: "test"),
                payloadType: [],
                address: "https://example.org"
            )
            let data = try JSONEncoder().encode(ep)
            let decoded = try JSONDecoder().decode(FHIREndpoint.self, from: data)
            XCTAssertEqual(decoded.status, status)
        }
    }

    func test_endpoint_minimalInit_optionalsAreNil() {
        let ep = FHIREndpoint(
            status: .active,
            connectionType: FHIRCoding(code: "dicom-wado-rs"),
            payloadType: [],
            address: "https://pacs.example.org"
        )
        XCTAssertNil(ep.id)
        XCTAssertNil(ep.name)
        XCTAssertNil(ep.managingOrganization)
        XCTAssertNil(ep.contact)
        XCTAssertNil(ep.period)
        XCTAssertNil(ep.payloadMimeType)
        XCTAssertNil(ep.header)
        XCTAssertNil(ep.identifier)
    }

    // MARK: - Equatable

    func test_fhirReference_equatable_differentValuesNotEqual() {
        let a = FHIRReference(reference: "Patient/1")
        let b = FHIRReference(reference: "Patient/2")
        XCTAssertNotEqual(a, b)
    }

    func test_imagingStudy_equatable_sameValuesEqual() {
        let a = FHIRImagingStudy(status: .available, subject: FHIRReference(reference: "Patient/1"))
        let b = FHIRImagingStudy(status: .available, subject: FHIRReference(reference: "Patient/1"))
        XCTAssertEqual(a, b)
    }

    // MARK: - JSON Decode from External

    func test_imagingStudy_decodesFromExternalJSON() throws {
        let json = """
        {
            "resourceType": "ImagingStudy",
            "id": "ext-1",
            "status": "available",
            "subject": { "reference": "Patient/42" },
            "description": "External study",
            "numberOfSeries": 3,
            "numberOfInstances": 150
        }
        """
        let data = json.data(using: .utf8)!
        let study = try JSONDecoder().decode(FHIRImagingStudy.self, from: data)
        XCTAssertEqual(study.id, "ext-1")
        XCTAssertEqual(study.status, .available)
        XCTAssertEqual(study.subject.reference, "Patient/42")
        XCTAssertEqual(study.description_, "External study")
        XCTAssertEqual(study.numberOfSeries, 3)
        XCTAssertEqual(study.numberOfInstances, 150)
    }

    func test_endpoint_decodesFromExternalJSON() throws {
        let json = """
        {
            "resourceType": "Endpoint",
            "id": "ep-ext",
            "status": "active",
            "connectionType": { "code": "dicom-wado-rs" },
            "payloadType": [{ "text": "DICOM" }],
            "address": "https://external.pacs/wado-rs"
        }
        """
        let data = json.data(using: .utf8)!
        let ep = try JSONDecoder().decode(FHIREndpoint.self, from: data)
        XCTAssertEqual(ep.id, "ep-ext")
        XCTAssertEqual(ep.status, .active)
        XCTAssertEqual(ep.connectionType.code, "dicom-wado-rs")
        XCTAssertEqual(ep.address, "https://external.pacs/wado-rs")
    }
}
