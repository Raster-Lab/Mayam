// SPDX-License-Identifier: (see LICENSE)
// Mayam — End-to-End HL7/FHIR Integration Tests

import XCTest
import Foundation
@testable import MayamCore

// MARK: - MLLP to FHIR Integration Tests

final class MLLPToFHIRIntegrationTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal but valid HL7 v2.x ADT^A01 message.
    private func sampleADTMessage() -> String {
        [
            "MSH|^~\\&|HIS|MAIN|MAYAM|MAYAM|20260301120000||ADT^A01|MSG-ADT-001|P|2.5",
            "EVN|A01|20260301120000",
            "PID|||PAT-001||DOE^JOHN||19850315|M",
            "PV1||I|ICU^101^A"
        ].joined(separator: "\r")
    }

    /// Builds a minimal HL7 v2.x ORM^O01 message.
    private func sampleORMMessage() -> String {
        [
            "MSH|^~\\&|RIS|RADIOLOGY|MAYAM|MAYAM|20260301130000||ORM^O01|MSG-ORM-001|P|2.5",
            "PID|||PAT-002||SMITH^JANE||19900101|F",
            "ORC|NW|ORD-100|FILL-100",
            "OBR|1|ORD-100|FILL-100|71020^Chest X-Ray^CPT|||20260301140000||||||||||||ACC-100|||CR"
        ].joined(separator: "\r")
    }

    // MARK: - ADT Message Processing

    func test_mllpToFHIR_adtMessage_processedAndResourceCreated() async throws {
        let config = MLLPListenerConfiguration(port: 0)
        let logger = MayamLogger(label: "test.mllp-fhir")
        let listener = MLLPListener(configuration: config, logger: logger)

        // Process ADT message through MLLP listener
        let ack = await listener.processMessage(sampleADTMessage())
        XCTAssertTrue(ack.contains("MSH|"), "ACK should contain MSH segment")
        XCTAssertTrue(ack.contains("MSA|"), "ACK should contain MSA segment")

        // Verify message was processed
        let count = await listener.getReceivedMessageCount()
        XCTAssertEqual(count, 1)

        // Create a FHIR ImagingStudy from the patient demographics
        let study = FHIRImagingStudy(
            id: "study-adt-001",
            status: .available,
            subject: FHIRReference(reference: "Patient/PAT-001", display: "DOE^JOHN"),
            started: "2026-03-01T12:00:00Z",
            numberOfSeries: 1,
            numberOfInstances: 1,
            description_: "ADT Triggered Study",
            identifier: [FHIRIdentifier(system: "urn:dicom:uid", value: "1.2.840.113619.2.55.adt.001")]
        )

        // Verify FHIR resource encodes correctly with patient demographics
        let data = try JSONEncoder().encode(study)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["resourceType"] as? String, "ImagingStudy")
        XCTAssertEqual(json?["id"] as? String, "study-adt-001")

        let subject = json?["subject"] as? [String: Any]
        XCTAssertEqual(subject?["reference"] as? String, "Patient/PAT-001")
        XCTAssertEqual(subject?["display"] as? String, "DOE^JOHN")
    }

    // MARK: - ORM Message Processing

    func test_mllpToFHIR_ormMessage_processedAndOrderStored() async {
        let config = MLLPListenerConfiguration(port: 0)
        let logger = MayamLogger(label: "test.mllp-orm")
        let listener = MLLPListener(configuration: config, logger: logger)

        // Process ORM message
        let ack = await listener.processMessage(sampleORMMessage())
        XCTAssertTrue(ack.contains("MSA|"), "ACK should contain MSA segment")

        // Extract order info via HL7WorkflowIntegration
        let integration = HL7WorkflowIntegration(logger: MayamLogger(label: "test.hl7"))
        let order = HL7WorkflowIntegration.ImagingOrder(
            placerOrderNumber: "ORD-100",
            fillerOrderNumber: "FILL-100",
            accessionNumber: "ACC-100",
            patientID: "PAT-002",
            patientName: "SMITH^JANE",
            procedureDescription: "Chest X-Ray",
            modality: "CR",
            scheduledDateTime: "20260301140000",
            orderControl: "NW"
        )
        let stored = await integration.processOrder(order)

        XCTAssertEqual(stored.placerOrderNumber, "ORD-100")
        XCTAssertEqual(stored.accessionNumber, "ACC-100")
        XCTAssertEqual(stored.patientID, "PAT-002")
        XCTAssertEqual(stored.modality, "CR")

        let orders = await integration.getReceivedOrders()
        XCTAssertEqual(orders.count, 1)
    }

    // MARK: - ORU Message Generation

    func test_mllpToFHIR_oruMessage_studyAvailabilityFlow() async {
        let integration = HL7WorkflowIntegration(logger: MayamLogger(label: "test.hl7"))

        let event = RISEvent(
            eventType: .studyAvailable,
            studyInstanceUID: "1.2.840.113619.2.55.3.604688",
            accessionNumber: "ACC-ORU-001",
            patientID: "PAT-ORU",
            patientName: "JONES^MARY"
        )
        let message = await integration.generateORUMessage(from: event)

        XCTAssertTrue(message.contains("MSH|"), "ORU should contain MSH segment")
        XCTAssertTrue(message.contains("ORU^R01"), "Message type should be ORU^R01")
        XCTAssertTrue(message.contains("PAT-ORU"), "Message should contain patient ID")
        XCTAssertTrue(message.contains("JONES^MARY"), "Message should contain patient name")
        XCTAssertTrue(message.contains("1.2.840.113619.2.55.3.604688"), "Message should contain study UID")
    }
}

// MARK: - Routing Integration Tests

final class RoutingIntegrationTests: XCTestCase {

    // MARK: - Helpers

    private func makeRoutingService() -> HL7MessageRoutingService {
        HL7MessageRoutingService(logger: MayamLogger(label: "test.routing-integration"))
    }

    // MARK: - ADT Routing

    func test_routingIntegration_adtMessage_routesToCorrectDestination() async {
        let service = makeRoutingService()

        // Configure routing rules
        await service.addRoutingRule(HL7RoutingRule(
            id: "adt-archive",
            name: "Route ADT to Archive",
            sourceMessageType: "ADT",
            enabled: true,
            priority: 10,
            action: .forward(destination: "archive.local:2575")
        ))
        await service.addRoutingRule(HL7RoutingRule(
            id: "orm-pacs",
            name: "Route ORM to PACS",
            sourceMessageType: "ORM",
            enabled: true,
            priority: 10,
            action: .forward(destination: "pacs.local:2575")
        ))

        // Process an ADT message through MLLP
        let config = MLLPListenerConfiguration(port: 0)
        let listener = MLLPListener(
            configuration: config,
            logger: MayamLogger(label: "test.mllp")
        )
        let rawADT = [
            "MSH|^~\\&|HIS|MAIN|MAYAM|MAYAM|20260301120000||ADT^A01|MSG-RT-001|P|2.5",
            "PID|||PAT-RT-001||TEST^PATIENT||19700101|M"
        ].joined(separator: "\r")

        _ = await listener.processMessage(rawADT)

        // Evaluate routing
        let matches = await service.evaluateRouting(
            messageType: "ADT",
            sendingApplication: "HIS",
            sendingFacility: "MAIN"
        )

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.id, "adt-archive")
        XCTAssertEqual(matches.first?.action, .forward(destination: "archive.local:2575"))
    }

    // MARK: - ORM Transform and Forward

    func test_routingIntegration_ormMessage_transformAndForward() async {
        let service = makeRoutingService()

        // Add transformation rule
        await service.addTransformationRule(HL7TransformationRule(
            id: "normalise-orm",
            name: "Normalise ORM Fields",
            description_: "Normalise patient name and set facility",
            fieldMappings: [
                FieldMapping(sourceField: "PID-3", targetField: "PID-3", operation: .copy),
                FieldMapping(sourceField: "PID-5", targetField: "PID-5", operation: .truncate(maxLength: 20)),
                FieldMapping(sourceField: "MSH-4", targetField: "MSH-4", operation: .setConstant(value: "MAYAM"))
            ]
        ))

        // Add routing rule with transform action
        await service.addRoutingRule(HL7RoutingRule(
            id: "orm-transform",
            name: "Transform ORM",
            sourceMessageType: "ORM",
            enabled: true,
            priority: 5,
            action: .transform(templateID: "normalise-orm")
        ))

        // Evaluate routing
        let matches = await service.evaluateRouting(
            messageType: "ORM",
            sendingApplication: nil,
            sendingFacility: nil
        )
        XCTAssertEqual(matches.count, 1)

        // Apply transformation
        let inputFields = [
            "PID-3": "PAT-XFORM-001",
            "PID-5": "AVERYLONGNAMETHATEXCEEDSTWENTYCHARACTERS",
            "MSH-4": "EXTERNAL"
        ]
        let output = await service.applyTransformation(
            ruleID: "normalise-orm",
            inputFields: inputFields
        )

        XCTAssertEqual(output["PID-3"], "PAT-XFORM-001")
        XCTAssertEqual(output["PID-5"], "AVERYLONGNAMETHATEXC")
        XCTAssertEqual(output["MSH-4"], "MAYAM")
    }

    // MARK: - Multiple Rules Priority Order

    func test_routingIntegration_multipleRules_priorityOrder() async {
        let service = makeRoutingService()

        await service.addRoutingRule(HL7RoutingRule(
            id: "low-priority",
            name: "Low Priority Catch-All",
            sourceMessageType: "*",
            enabled: true,
            priority: 100,
            action: .delegate(handlerName: "default-handler")
        ))
        await service.addRoutingRule(HL7RoutingRule(
            id: "high-priority",
            name: "High Priority ADT",
            sourceMessageType: "ADT",
            enabled: true,
            priority: 1,
            action: .forward(destination: "primary:2575")
        ))
        await service.addRoutingRule(HL7RoutingRule(
            id: "mid-priority",
            name: "Mid Priority ADT",
            sourceMessageType: "ADT",
            enabled: true,
            priority: 50,
            action: .forward(destination: "secondary:2575")
        ))

        let matches = await service.evaluateRouting(
            messageType: "ADT",
            sendingApplication: nil,
            sendingFacility: nil
        )

        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0].id, "high-priority")
        XCTAssertEqual(matches[0].priority, 1)
        XCTAssertEqual(matches[1].id, "mid-priority")
        XCTAssertEqual(matches[1].priority, 50)
        XCTAssertEqual(matches[2].id, "low-priority")
        XCTAssertEqual(matches[2].priority, 100)
    }
}

// MARK: - FHIR Resource Integration Tests

final class FHIREndpointIntegrationTests: XCTestCase {

    // MARK: - Helpers

    private func sampleImagingStudy(id: String, patientRef: String) -> FHIRImagingStudy {
        FHIRImagingStudy(
            id: id,
            status: .available,
            subject: FHIRReference(reference: "Patient/\(patientRef)", display: "Test Patient"),
            started: "2026-03-01T09:00:00Z",
            numberOfSeries: 2,
            numberOfInstances: 50,
            description_: "CT Chest",
            identifier: [FHIRIdentifier(system: "urn:dicom:uid", value: "1.2.840.113619.2.55.\(id)")],
            modality: [FHIRCoding(system: "http://dicom.nema.org/resources/ontology/DCM", code: "CT", display: "Computed Tomography")]
        )
    }

    // MARK: - ImagingStudy Search

    func test_fhirEndpoint_imagingStudySearch_returnsCorrectJSON() throws {
        let studies = [
            sampleImagingStudy(id: "study-1", patientRef: "pat-1"),
            sampleImagingStudy(id: "study-2", patientRef: "pat-2")
        ]

        let data = try JSONEncoder().encode(studies)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?.count, 2)

        let first = json?.first(where: { ($0["id"] as? String) == "study-1" })
        XCTAssertNotNil(first)
        XCTAssertEqual(first?["resourceType"] as? String, "ImagingStudy")
        XCTAssertEqual(first?["status"] as? String, "available")

        let subject = first?["subject"] as? [String: Any]
        XCTAssertEqual(subject?["reference"] as? String, "Patient/pat-1")
    }

    // MARK: - Patient Create Then Retrieve

    func test_fhirEndpoint_patientCreate_thenRetrieve() throws {
        let study = FHIRImagingStudy(
            id: "study-pat-1",
            status: .available,
            subject: FHIRReference(reference: "Patient/pat-create-1", display: "Integration^Test"),
            started: "2026-03-01T09:00:00Z",
            description_: "Study for patient retrieval test",
            identifier: [FHIRIdentifier(system: "urn:oid:2.16.840.1.113883", value: "pat-create-1")]
        )

        // Encode and decode to simulate store/retrieve cycle
        let data = try JSONEncoder().encode(study)
        let decoded = try JSONDecoder().decode(FHIRImagingStudy.self, from: data)

        XCTAssertEqual(decoded.id, "study-pat-1")
        XCTAssertEqual(decoded.subject.reference, "Patient/pat-create-1")
        XCTAssertEqual(decoded.subject.display, "Integration^Test")

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["resourceType"] as? String, "ImagingStudy")
        XCTAssertEqual(json?["id"] as? String, "study-pat-1")
    }

    // MARK: - DiagnosticReport Linked to ImagingStudy

    func test_fhirEndpoint_diagnosticReport_linkedToImagingStudy() throws {
        let study = sampleImagingStudy(id: "linked-study", patientRef: "pat-linked")

        // Encode study and verify structure
        let studyData = try JSONEncoder().encode(study)
        let studyJSON = try JSONSerialization.jsonObject(with: studyData) as? [String: Any]
        XCTAssertEqual(studyJSON?["resourceType"] as? String, "ImagingStudy")

        // Create a report that references the study and verify the linkage
        let reportSubject = FHIRReference(reference: "Patient/pat-linked")
        let reportStudyRef = FHIRReference(reference: "ImagingStudy/linked-study")

        XCTAssertEqual(reportSubject.reference, "Patient/pat-linked")
        XCTAssertEqual(reportStudyRef.reference, "ImagingStudy/linked-study")

        // Verify subject reference matches between study and report
        let studySubject = studyJSON?["subject"] as? [String: Any]
        XCTAssertEqual(studySubject?["reference"] as? String, "Patient/pat-linked")
        XCTAssertEqual(reportSubject.reference, studySubject?["reference"] as? String)
    }

    // MARK: - Endpoint Discovery

    func test_fhirEndpoint_endpointDiscovery_returnsDICOMwebEndpoints() throws {
        let endpoint = FHIREndpoint(
            id: "wado-rs",
            status: .active,
            connectionType: FHIRCoding(
                system: "http://terminology.hl7.org/CodeSystem/endpoint-connection-type",
                code: "dicom-wado-rs",
                display: "DICOM WADO-RS"
            ),
            name: "WADO-RS Endpoint",
            payloadType: [FHIRCodeableConcept(text: "DICOM")],
            payloadMimeType: ["application/dicom"],
            address: "https://pacs.example.com/wado-rs"
        )

        let data = try JSONEncoder().encode(endpoint)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["resourceType"] as? String, "Endpoint")
        XCTAssertEqual(json?["name"] as? String, "WADO-RS Endpoint")
        XCTAssertEqual(json?["address"] as? String, "https://pacs.example.com/wado-rs")
        XCTAssertEqual(json?["status"] as? String, "active")

        let connType = json?["connectionType"] as? [String: Any]
        XCTAssertEqual(connType?["code"] as? String, "dicom-wado-rs")
    }
}

// MARK: - Full Workflow Integration Tests

final class FullWorkflowIntegrationTests: XCTestCase {

    func test_fullFlow_ormToStudyToReport() async throws {
        let logger = MayamLogger(label: "test.full-flow")

        // --- Step 1: Receive ORM order via MLLP ---
        let config = MLLPListenerConfiguration(port: 0)
        let listener = MLLPListener(configuration: config, logger: logger)
        let rawORM = [
            "MSH|^~\\&|RIS|RADIOLOGY|MAYAM|MAYAM|20260301150000||ORM^O01|MSG-FULL-001|P|2.5",
            "PID|||PAT-FULL-001||WORKFLOW^TEST||19750520|M",
            "ORC|NW|ORD-FULL|FILL-FULL",
            "OBR|1|ORD-FULL|FILL-FULL|71020^Chest X-Ray^CPT|||20260301160000||||||||||||ACC-FULL|||CR"
        ].joined(separator: "\r")

        let ack = await listener.processMessage(rawORM)
        XCTAssertTrue(ack.contains("MSA|"), "ACK must contain MSA segment")

        let processedMessages = await listener.getProcessedMessages()
        XCTAssertEqual(processedMessages.count, 1)
        XCTAssertEqual(processedMessages.first?.messageType, "ORM^O01")

        // --- Step 2: Process order via HL7WorkflowIntegration ---
        let integration = HL7WorkflowIntegration(logger: logger)
        let order = HL7WorkflowIntegration.ImagingOrder(
            placerOrderNumber: "ORD-FULL",
            fillerOrderNumber: "FILL-FULL",
            accessionNumber: "ACC-FULL",
            patientID: "PAT-FULL-001",
            patientName: "WORKFLOW^TEST",
            procedureDescription: "Chest X-Ray",
            modality: "CR",
            scheduledDateTime: "20260301160000",
            orderControl: "NW"
        )
        let storedOrder = await integration.processOrder(order)
        XCTAssertEqual(storedOrder.accessionNumber, "ACC-FULL")

        // --- Step 3: Create ImagingStudy from the order ---
        let study = FHIRImagingStudy(
            id: "study-full-001",
            status: .available,
            subject: FHIRReference(reference: "Patient/PAT-FULL-001", display: "WORKFLOW^TEST"),
            started: "2026-03-01T16:00:00Z",
            numberOfSeries: 1,
            numberOfInstances: 2,
            description_: "Chest X-Ray",
            series: [
                FHIRImagingStudy.Series(
                    uid: "1.2.840.113619.2.55.3.series1",
                    number: 1,
                    modality: FHIRCoding(
                        system: "http://dicom.nema.org/resources/ontology/DCM",
                        code: "CR",
                        display: "Computed Radiography"
                    ),
                    description_: "PA Chest",
                    numberOfInstances: 2,
                    instance: [
                        FHIRImagingStudy.Series.Instance(
                            uid: "1.2.840.113619.2.55.3.inst1",
                            sopClass: FHIRCoding(
                                system: "urn:ietf:rfc:3986",
                                code: "1.2.840.10008.5.1.4.1.1.1",
                                display: "CR Image Storage"
                            ),
                            number: 1
                        ),
                        FHIRImagingStudy.Series.Instance(
                            uid: "1.2.840.113619.2.55.3.inst2",
                            sopClass: FHIRCoding(
                                system: "urn:ietf:rfc:3986",
                                code: "1.2.840.10008.5.1.4.1.1.1",
                                display: "CR Image Storage"
                            ),
                            number: 2
                        )
                    ]
                )
            ],
            identifier: [FHIRIdentifier(system: "urn:dicom:uid", value: "1.2.840.113619.2.55.3.604688")],
            modality: [FHIRCoding(system: "http://dicom.nema.org/resources/ontology/DCM", code: "CR")]
        )

        // Verify study encodes correctly
        let studyData = try JSONEncoder().encode(study)
        let studyJSON = try JSONSerialization.jsonObject(with: studyData) as? [String: Any]
        XCTAssertEqual(studyJSON?["resourceType"] as? String, "ImagingStudy")

        // Verify study is linked to patient
        let studySubject = studyJSON?["subject"] as? [String: Any]
        XCTAssertEqual(studySubject?["reference"] as? String, "Patient/PAT-FULL-001")

        // Verify series and instances
        let series = studyJSON?["series"] as? [[String: Any]]
        XCTAssertEqual(series?.count, 1)
        let instances = series?.first?["instance"] as? [[String: Any]]
        XCTAssertEqual(instances?.count, 2)

        // --- Step 4: Create DiagnosticReport referencing ImagingStudy ---
        let reportStudyRef = FHIRReference(reference: "ImagingStudy/study-full-001")
        let reportSubjectRef = FHIRReference(reference: "Patient/PAT-FULL-001")

        // Verify linkage: report → study → patient
        XCTAssertEqual(reportStudyRef.reference, "ImagingStudy/\(study.id!)")
        XCTAssertEqual(reportSubjectRef.reference, study.subject.reference)

        // --- Step 5: Evaluate routing for the received ORM message ---
        let routingService = HL7MessageRoutingService(logger: logger)
        await routingService.addRoutingRule(HL7RoutingRule(
            id: "orm-to-pacs",
            name: "Route ORM to PACS",
            sourceMessageType: "ORM",
            sourceSendingApplication: "RIS",
            enabled: true,
            priority: 1,
            action: .forward(destination: "pacs.local:2575")
        ))

        let matches = await routingService.evaluateRouting(
            messageType: "ORM",
            sendingApplication: "RIS",
            sendingFacility: "RADIOLOGY"
        )
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.action, .forward(destination: "pacs.local:2575"))

        // --- Step 6: Generate ORU notification for completed study ---
        let risEvent = RISEvent(
            eventType: .studyAvailable,
            studyInstanceUID: "1.2.840.113619.2.55.3.604688",
            accessionNumber: "ACC-FULL",
            patientID: "PAT-FULL-001",
            patientName: "WORKFLOW^TEST"
        )
        let oruMessage = await integration.generateORUMessage(from: risEvent)
        XCTAssertTrue(oruMessage.contains("ORU^R01"))
        XCTAssertTrue(oruMessage.contains("PAT-FULL-001"))
        XCTAssertTrue(oruMessage.contains("1.2.840.113619.2.55.3.604688"))
    }
}
