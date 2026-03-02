// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOMweb Router Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class DICOMwebRouterTests: XCTestCase {

    private var tempDir: String = ""

    override func setUp() {
        tempDir = NSTemporaryDirectory() + "mayam_router_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    private func makeRouter() -> DICOMwebRouter {
        let store = InMemoryDICOMMetadataStore()
        let storageActor = StorageActor(
            archivePath: tempDir,
            checksumEnabled: false,
            logger: MayamLogger(label: "test.router")
        )
        return DICOMwebRouter(
            qidoRS: QIDORSHandler(metadataStore: store),
            wadoRS: WADORSHandler(archivePath: tempDir, metadataStore: store),
            stowRS: STOWRSHandler(storageActor: storageActor, metadataStore: store),
            upsRS: UPSRSHandler(),
            wadoURI: WADOURIHandler(archivePath: tempDir, metadataStore: store)
        )
    }

    // MARK: - QIDO-RS Routes

    func test_router_getStudies_returns200() async {
        let router = makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/studies")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
    }

    func test_router_getStudiesWithUID_returns404ForEmpty() async {
        let router = makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/studies/1.2.3")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 404)
    }

    func test_router_getSeries_returns200() async {
        let router = makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/studies/1.2.3/series")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
    }

    func test_router_getInstances_returns200() async {
        let router = makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/studies/1.2.3/series/1.2.3.4/instances")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
    }

    // MARK: - STOW-RS Routes

    func test_router_postStudies_withoutMultipart_returns415() async {
        let router = makeRouter()
        let req = DICOMwebRequest(
            method: .post,
            path: "/studies",
            body: Data(),
            headers: ["Content-Type": "application/json"]
        )
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 415)
    }

    // MARK: - UPS-RS Routes

    func test_router_postWorkitems_creates201() async {
        let router = makeRouter()
        let req = DICOMwebRequest(method: .post, path: "/workitems")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 201)
        XCTAssertNotNil(resp.headers["Location"])
    }

    func test_router_getWorkitems_returns200() async {
        let router = makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/workitems")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 200)
    }

    func test_router_getWorkitem_notFound_returns404() async {
        let router = makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/workitems/1.2.nonexistent")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 404)
    }

    func test_router_deleteWorkitemSubscriber_noContent() async {
        let router = makeRouter()
        // First create a workitem and subscriber
        let createReq = DICOMwebRequest(method: .post, path: "/workitems", queryParams: ["workitem": "1.2.3"])
        _ = await router.route(createReq)
        let subReq = DICOMwebRequest(method: .post, path: "/workitems/1.2.3/subscribers/MYAE")
        _ = await router.route(subReq)
        let unsubReq = DICOMwebRequest(method: .delete, path: "/workitems/1.2.3/subscribers/MYAE")
        let resp = await router.route(unsubReq)
        XCTAssertEqual(resp.statusCode, 204)
    }

    // MARK: - WADO-URI Routes

    func test_router_wadoURI_missingParams_returns400() async {
        let router = makeRouter()
        let req = DICOMwebRequest(
            method: .get,
            path: "/wado",
            queryParams: ["requestType": "WADO"]
        )
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 400)
    }

    // MARK: - Unknown Path

    func test_router_unknownPath_returns404() async {
        let router = makeRouter()
        let req = DICOMwebRequest(method: .get, path: "/unknown/endpoint")
        let resp = await router.route(req)
        XCTAssertEqual(resp.statusCode, 404)
    }

    // MARK: - DICOMwebResponse

    func test_dicomwebResponse_ok_json_setsContentType() {
        let resp = DICOMwebResponse.ok(json: Data())
        XCTAssertEqual(resp.headers["Content-Type"], "application/dicom+json")
        XCTAssertEqual(resp.statusCode, 200)
    }

    func test_dicomwebResponse_created_setsLocation() {
        let resp = DICOMwebResponse.created(location: "/workitems/1.2.3")
        XCTAssertEqual(resp.statusCode, 201)
        XCTAssertEqual(resp.headers["Location"], "/workitems/1.2.3")
    }

    func test_dicomwebResponse_noContent_is204() {
        let resp = DICOMwebResponse.noContent()
        XCTAssertEqual(resp.statusCode, 204)
    }

    func test_dicomwebResponse_error_setsStatusCode() {
        let resp = DICOMwebResponse.error(DICOMwebError.notFound(resource: "X"))
        XCTAssertEqual(resp.statusCode, 404)
    }
}
