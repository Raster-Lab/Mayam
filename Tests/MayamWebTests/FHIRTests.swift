// SPDX-License-Identifier: (see LICENSE)
// Mayam — FHIR R4 Handler and Router Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class FHIRHandlerTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore() -> InMemoryFHIRResourceStore {
        InMemoryFHIRResourceStore()
    }

    private func makeHandler(store: InMemoryFHIRResourceStore) -> FHIRHandler {
        FHIRHandler(store: store)
    }

    private func samplePatient(id: String = "pat-1") -> FHIRPatientResource {
        FHIRPatientResource(
            id: id,
            identifier: [FHIRIdentifier(system: "urn:oid:2.16.840.1.113883.2.1", value: "NHS123")],
            active: true,
            name: [FHIRHumanName(family: "Smith", given: ["John"])],
            gender: "male",
            birthDate: "1990-01-15"
        )
    }

    private func sampleImagingStudy(id: String = "study-1") -> FHIRImagingStudy {
        FHIRImagingStudy(
            id: id,
            status: .available,
            subject: FHIRReference(reference: "Patient/pat-1"),
            started: "2025-06-01T10:00:00Z",
            numberOfSeries: 1,
            numberOfInstances: 5
        )
    }

    private func sampleDiagnosticReport(id: String = "report-1") -> FHIRDiagnosticReportResource {
        FHIRDiagnosticReportResource(
            id: id,
            status: "final",
            code: FHIRCodeableConcept(
                coding: [FHIRCoding(system: "http://loinc.org", code: "18748-4")],
                text: "Diagnostic Imaging Study"
            ),
            subject: FHIRReference(reference: "Patient/pat-1"),
            issued: "2025-06-01T12:00:00Z",
            conclusion: "Normal findings"
        )
    }

    private func sampleEndpoint(id: String = "ep-1") -> FHIREndpoint {
        FHIREndpoint(
            id: id,
            status: .active,
            connectionType: FHIRCoding(
                system: "http://terminology.hl7.org/CodeSystem/endpoint-connection-type",
                code: "dicom-wado-rs"
            ),
            name: "Mayam WADO-RS",
            payloadType: [FHIRCodeableConcept(text: "DICOM WADO-RS")],
            payloadMimeType: ["application/dicom"],
            address: "https://pacs.example.com/wado-rs"
        )
    }

    // MARK: - Patient Tests

    func test_handler_searchPatients_returnsEmptyArray() async throws {
        let store = makeStore()
        let handler = makeHandler(store: store)
        let data = try await handler.searchPatients(params: [:])
        let patients = try JSONDecoder().decode([FHIRPatientResource].self, from: data)
        XCTAssertTrue(patients.isEmpty)
    }

    func test_handler_searchPatients_returnsMatchingPatients() async throws {
        let store = makeStore()
        await store.addPatient(samplePatient())
        await store.addPatient(samplePatient(id: "pat-2"))
        let handler = makeHandler(store: store)
        let data = try await handler.searchPatients(params: [:])
        let patients = try JSONDecoder().decode([FHIRPatientResource].self, from: data)
        XCTAssertEqual(patients.count, 2)
    }

    func test_handler_getPatient_returnsPatient() async throws {
        let store = makeStore()
        await store.addPatient(samplePatient())
        let handler = makeHandler(store: store)
        let data = try await handler.getPatient(id: "pat-1")
        let patient = try JSONDecoder().decode(FHIRPatientResource.self, from: data)
        XCTAssertEqual(patient.id, "pat-1")
        XCTAssertEqual(patient.resourceType, "Patient")
    }

    func test_handler_getPatient_throwsNotFoundForMissing() async {
        let store = makeStore()
        let handler = makeHandler(store: store)
        do {
            _ = try await handler.getPatient(id: "nonexistent")
            XCTFail("Expected error to be thrown")
        } catch let error as DICOMwebError {
            XCTAssertEqual(error.httpStatusCode, 404)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - ImagingStudy Tests

    func test_handler_searchImagingStudies_returnsEmptyArray() async throws {
        let store = makeStore()
        let handler = makeHandler(store: store)
        let data = try await handler.searchImagingStudies(params: [:])
        let studies = try JSONDecoder().decode([FHIRImagingStudy].self, from: data)
        XCTAssertTrue(studies.isEmpty)
    }

    func test_handler_searchImagingStudies_returnsMatchingStudies() async throws {
        let store = makeStore()
        await store.addImagingStudy(sampleImagingStudy())
        let handler = makeHandler(store: store)
        let data = try await handler.searchImagingStudies(params: [:])
        let studies = try JSONDecoder().decode([FHIRImagingStudy].self, from: data)
        XCTAssertEqual(studies.count, 1)
        XCTAssertEqual(studies[0].id, "study-1")
    }

    func test_handler_getImagingStudy_returnsStudy() async throws {
        let store = makeStore()
        await store.addImagingStudy(sampleImagingStudy())
        let handler = makeHandler(store: store)
        let data = try await handler.getImagingStudy(id: "study-1")
        let study = try JSONDecoder().decode(FHIRImagingStudy.self, from: data)
        XCTAssertEqual(study.id, "study-1")
        XCTAssertEqual(study.resourceType, "ImagingStudy")
    }

    func test_handler_getImagingStudy_throwsNotFoundForMissing() async {
        let store = makeStore()
        let handler = makeHandler(store: store)
        do {
            _ = try await handler.getImagingStudy(id: "nonexistent")
            XCTFail("Expected error to be thrown")
        } catch let error as DICOMwebError {
            XCTAssertEqual(error.httpStatusCode, 404)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - DiagnosticReport Tests

    func test_handler_searchDiagnosticReports_returnsEmptyArray() async throws {
        let store = makeStore()
        let handler = makeHandler(store: store)
        let data = try await handler.searchDiagnosticReports(params: [:])
        let reports = try JSONDecoder().decode([FHIRDiagnosticReportResource].self, from: data)
        XCTAssertTrue(reports.isEmpty)
    }

    func test_handler_searchDiagnosticReports_returnsMatchingReports() async throws {
        let store = makeStore()
        await store.addDiagnosticReport(sampleDiagnosticReport())
        let handler = makeHandler(store: store)
        let data = try await handler.searchDiagnosticReports(params: [:])
        let reports = try JSONDecoder().decode([FHIRDiagnosticReportResource].self, from: data)
        XCTAssertEqual(reports.count, 1)
    }

    func test_handler_getDiagnosticReport_returnsReport() async throws {
        let store = makeStore()
        await store.addDiagnosticReport(sampleDiagnosticReport())
        let handler = makeHandler(store: store)
        let data = try await handler.getDiagnosticReport(id: "report-1")
        let report = try JSONDecoder().decode(FHIRDiagnosticReportResource.self, from: data)
        XCTAssertEqual(report.id, "report-1")
        XCTAssertEqual(report.resourceType, "DiagnosticReport")
    }

    func test_handler_getDiagnosticReport_throwsNotFoundForMissing() async {
        let store = makeStore()
        let handler = makeHandler(store: store)
        do {
            _ = try await handler.getDiagnosticReport(id: "nonexistent")
            XCTFail("Expected error to be thrown")
        } catch let error as DICOMwebError {
            XCTAssertEqual(error.httpStatusCode, 404)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Endpoint Tests

    func test_handler_searchEndpoints_returnsEmptyArray() async throws {
        let store = makeStore()
        let handler = makeHandler(store: store)
        let data = try await handler.searchEndpoints(params: [:])
        let endpoints = try JSONDecoder().decode([FHIREndpoint].self, from: data)
        XCTAssertTrue(endpoints.isEmpty)
    }

    func test_handler_searchEndpoints_returnsMatchingEndpoints() async throws {
        let store = makeStore()
        await store.addEndpoint(sampleEndpoint())
        let handler = makeHandler(store: store)
        let data = try await handler.searchEndpoints(params: [:])
        let endpoints = try JSONDecoder().decode([FHIREndpoint].self, from: data)
        XCTAssertEqual(endpoints.count, 1)
    }

    func test_handler_getEndpoint_returnsEndpoint() async throws {
        let store = makeStore()
        await store.addEndpoint(sampleEndpoint())
        let handler = makeHandler(store: store)
        let data = try await handler.getEndpoint(id: "ep-1")
        let endpoint = try JSONDecoder().decode(FHIREndpoint.self, from: data)
        XCTAssertEqual(endpoint.id, "ep-1")
        XCTAssertEqual(endpoint.resourceType, "Endpoint")
    }

    func test_handler_getEndpoint_throwsNotFoundForMissing() async {
        let store = makeStore()
        let handler = makeHandler(store: store)
        do {
            _ = try await handler.getEndpoint(id: "nonexistent")
            XCTFail("Expected error to be thrown")
        } catch let error as DICOMwebError {
            XCTAssertEqual(error.httpStatusCode, 404)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - InMemoryFHIRResourceStore Filter Tests

    func test_store_searchPatients_filtersByName() async {
        let store = makeStore()
        await store.addPatient(samplePatient())
        await store.addPatient(FHIRPatientResource(
            id: "pat-2",
            name: [FHIRHumanName(family: "Jones", given: ["Jane"])]
        ))
        let results = await store.searchPatients(params: ["name": "Smith"])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "pat-1")
    }

    func test_store_searchPatients_filtersByGender() async {
        let store = makeStore()
        await store.addPatient(samplePatient())
        let results = await store.searchPatients(params: ["gender": "female"])
        XCTAssertTrue(results.isEmpty)
    }

    func test_store_searchImagingStudies_filtersByPatient() async {
        let store = makeStore()
        await store.addImagingStudy(sampleImagingStudy())
        let results = await store.searchImagingStudies(params: ["patient": "Patient/pat-999"])
        XCTAssertTrue(results.isEmpty)
    }

    func test_store_searchImagingStudies_filtersByStatus() async {
        let store = makeStore()
        await store.addImagingStudy(sampleImagingStudy())
        let results = await store.searchImagingStudies(params: ["status": "cancelled"])
        XCTAssertTrue(results.isEmpty)
    }

    func test_store_searchDiagnosticReports_filtersByStatus() async {
        let store = makeStore()
        await store.addDiagnosticReport(sampleDiagnosticReport())
        let results = await store.searchDiagnosticReports(params: ["status": "preliminary"])
        XCTAssertTrue(results.isEmpty)
    }

    func test_store_searchDiagnosticReports_filtersBySubject() async {
        let store = makeStore()
        await store.addDiagnosticReport(sampleDiagnosticReport())
        let results = await store.searchDiagnosticReports(params: ["subject": "Patient/pat-1"])
        XCTAssertEqual(results.count, 1)
    }

    func test_store_searchEndpoints_filtersByStatus() async {
        let store = makeStore()
        await store.addEndpoint(sampleEndpoint())
        let results = await store.searchEndpoints(params: ["status": "off"])
        XCTAssertTrue(results.isEmpty)
    }

    func test_store_searchEndpoints_filtersByConnectionType() async {
        let store = makeStore()
        await store.addEndpoint(sampleEndpoint())
        let results = await store.searchEndpoints(params: ["connection-type": "dicom-wado-rs"])
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Model Codable Round-Trip Tests

    func test_patientResource_codableRoundTrip() throws {
        let patient = samplePatient()
        let data = try JSONEncoder().encode(patient)
        let decoded = try JSONDecoder().decode(FHIRPatientResource.self, from: data)
        XCTAssertEqual(patient, decoded)
    }

    func test_diagnosticReportResource_codableRoundTrip() throws {
        let report = sampleDiagnosticReport()
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(FHIRDiagnosticReportResource.self, from: data)
        XCTAssertEqual(report, decoded)
    }

    func test_humanName_codableRoundTrip() throws {
        let name = FHIRHumanName(family: "Doe", given: ["Jane", "Marie"])
        let data = try JSONEncoder().encode(name)
        let decoded = try JSONDecoder().decode(FHIRHumanName.self, from: data)
        XCTAssertEqual(name, decoded)
    }

    // MARK: - Model Property Tests

    func test_patientResource_resourceTypeIsPatient() {
        let patient = FHIRPatientResource(id: "test")
        XCTAssertEqual(patient.resourceType, "Patient")
    }

    func test_diagnosticReportResource_resourceTypeIsDiagnosticReport() {
        let report = FHIRDiagnosticReportResource(id: "test", status: "final")
        XCTAssertEqual(report.resourceType, "DiagnosticReport")
    }
}

// MARK: - FHIRRouterTests

final class FHIRRouterTests: XCTestCase {

    // MARK: - Helpers

    private func makeRouter() async -> (FHIRRouter, InMemoryFHIRResourceStore) {
        let store = InMemoryFHIRResourceStore()
        let handler = FHIRHandler(store: store)
        let router = FHIRRouter(handler: handler)
        return (router, store)
    }

    private func samplePatient() -> FHIRPatientResource {
        FHIRPatientResource(
            id: "pat-1",
            active: true,
            name: [FHIRHumanName(family: "Smith", given: ["John"])],
            gender: "male",
            birthDate: "1990-01-15"
        )
    }

    private func sampleImagingStudy() -> FHIRImagingStudy {
        FHIRImagingStudy(
            id: "study-1",
            status: .available,
            subject: FHIRReference(reference: "Patient/pat-1")
        )
    }

    private func sampleDiagnosticReport() -> FHIRDiagnosticReportResource {
        FHIRDiagnosticReportResource(
            id: "report-1",
            status: "final",
            subject: FHIRReference(reference: "Patient/pat-1")
        )
    }

    private func sampleEndpoint() -> FHIREndpoint {
        FHIREndpoint(
            id: "ep-1",
            status: .active,
            connectionType: FHIRCoding(code: "dicom-wado-rs"),
            payloadType: [FHIRCodeableConcept(text: "DICOM")],
            address: "https://pacs.example.com/wado-rs"
        )
    }

    // MARK: - Metadata Tests

    func test_router_getMetadata_returns200() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/metadata")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.headers["Content-Type"], "application/fhir+json")
    }

    func test_router_getMetadata_containsCapabilityStatement() async throws {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/metadata")
        let resp = await router.route(req)
        let json = try JSONSerialization.jsonObject(with: resp.body) as? [String: Any]
        XCTAssertEqual(json?["resourceType"] as? String, "CapabilityStatement")
        XCTAssertEqual(json?["fhirVersion"] as? String, "4.0.1")
    }

    func test_router_postMetadata_returns405() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .post, path: "/metadata")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 405)
    }

    // MARK: - Patient Route Tests

    func test_router_searchPatients_returns200() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/Patient")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.headers["Content-Type"], "application/fhir+json")
    }

    func test_router_getPatient_returns200() async {
        let (router, store) = await makeRouter()
        await store.addPatient(samplePatient())
        let req = DICOMwebRequest(method: .get, path: "/Patient/pat-1")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.headers["Content-Type"], "application/fhir+json")
    }

    func test_router_getPatient_returns404ForMissing() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/Patient/nonexistent")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 404)
    }

    func test_router_postPatient_returns405() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .post, path: "/Patient")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 405)
    }

    // MARK: - ImagingStudy Route Tests

    func test_router_searchImagingStudies_returns200() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/ImagingStudy")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
        XCTAssertEqual(resp.headers["Content-Type"], "application/fhir+json")
    }

    func test_router_getImagingStudy_returns200() async {
        let (router, store) = await makeRouter()
        await store.addImagingStudy(sampleImagingStudy())
        let req = DICOMwebRequest(method: .get, path: "/ImagingStudy/study-1")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
    }

    func test_router_getImagingStudy_returns404ForMissing() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/ImagingStudy/nonexistent")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 404)
    }

    func test_router_deleteImagingStudy_returns405() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .delete, path: "/ImagingStudy/study-1")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 405)
    }

    // MARK: - DiagnosticReport Route Tests

    func test_router_searchDiagnosticReports_returns200() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/DiagnosticReport")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
    }

    func test_router_getDiagnosticReport_returns200() async {
        let (router, store) = await makeRouter()
        await store.addDiagnosticReport(sampleDiagnosticReport())
        let req = DICOMwebRequest(method: .get, path: "/DiagnosticReport/report-1")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
    }

    func test_router_getDiagnosticReport_returns404ForMissing() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/DiagnosticReport/nonexistent")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 404)
    }

    // MARK: - Endpoint Route Tests

    func test_router_searchEndpoints_returns200() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/Endpoint")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
    }

    func test_router_getEndpoint_returns200() async {
        let (router, store) = await makeRouter()
        await store.addEndpoint(sampleEndpoint())
        let req = DICOMwebRequest(method: .get, path: "/Endpoint/ep-1")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
    }

    func test_router_getEndpoint_returns404ForMissing() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/Endpoint/nonexistent")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 404)
    }

    // MARK: - Unknown Resource Tests

    func test_router_unknownResource_returns404() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/UnknownResource")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 404)
    }

    func test_router_emptyPath_returns404() async {
        let (router, _) = await makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 404)
    }

    // MARK: - Query Parameter Pass-Through Tests

    func test_router_searchPatients_passesQueryParams() async throws {
        let (router, store) = await makeRouter()
        await store.addPatient(samplePatient())
        await store.addPatient(FHIRPatientResource(
            id: "pat-2",
            name: [FHIRHumanName(family: "Jones", given: ["Jane"])],
            gender: "female"
        ))
        let req = DICOMwebRequest(method: .get, path: "/Patient", queryParams: ["gender": "male"])
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
        let patients = try JSONDecoder().decode([FHIRPatientResource].self, from: resp.body)
        XCTAssertEqual(patients.count, 1)
        XCTAssertEqual(patients[0].id, "pat-1")
    }
}
