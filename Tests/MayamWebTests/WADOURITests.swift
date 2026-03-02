// SPDX-License-Identifier: (see LICENSE)
// Mayam — WADO-URI Handler Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class WADOURITests: XCTestCase {

    // MARK: - WADOURIRequest Parsing

    func test_wadoURIRequest_validParams_parsesCorrectly() throws {
        let params: [String: String] = [
            "requestType": "WADO",
            "studyUID": "1.2.3",
            "seriesUID": "1.2.3.4",
            "objectUID": "1.2.3.4.5"
        ]
        let req = try WADOURIRequest.parse(queryParams: params)
        XCTAssertEqual(req.requestType, .wado)
        XCTAssertEqual(req.studyUID, "1.2.3")
        XCTAssertEqual(req.seriesUID, "1.2.3.4")
        XCTAssertEqual(req.objectUID, "1.2.3.4.5")
        XCTAssertEqual(req.contentType, .applicationDICOM)
        XCTAssertNil(req.frameNumber)
    }

    func test_wadoURIRequest_withContentType_parsesContentType() throws {
        let params: [String: String] = [
            "requestType": "WADO",
            "studyUID": "1.2.3",
            "seriesUID": "1.2.3.4",
            "objectUID": "1.2.3.4.5",
            "contentType": "image/jpeg"
        ]
        let req = try WADOURIRequest.parse(queryParams: params)
        XCTAssertEqual(req.contentType, .imageJPEG)
    }

    func test_wadoURIRequest_withFrameNumber_parsesFrame() throws {
        let params: [String: String] = [
            "requestType": "WADO",
            "studyUID": "1.2.3",
            "seriesUID": "1.2.3.4",
            "objectUID": "1.2.3.4.5",
            "frameNumber": "3"
        ]
        let req = try WADOURIRequest.parse(queryParams: params)
        XCTAssertEqual(req.frameNumber, 3)
    }

    func test_wadoURIRequest_missingRequestType_throws() {
        let params: [String: String] = [
            "studyUID": "1.2.3",
            "seriesUID": "1.2.3.4",
            "objectUID": "1.2.3.4.5"
        ]
        XCTAssertThrowsError(try WADOURIRequest.parse(queryParams: params)) { error in
            guard case DICOMwebError.badRequest = error else {
                XCTFail("Expected badRequest")
                return
            }
        }
    }

    func test_wadoURIRequest_missingStudyUID_throws() {
        let params: [String: String] = [
            "requestType": "WADO",
            "seriesUID": "1.2.3.4",
            "objectUID": "1.2.3.4.5"
        ]
        XCTAssertThrowsError(try WADOURIRequest.parse(queryParams: params)) { error in
            guard case DICOMwebError.badRequest = error else {
                XCTFail("Expected badRequest")
                return
            }
        }
    }

    func test_wadoURIRequest_invalidFrameNumber_throws() {
        let params: [String: String] = [
            "requestType": "WADO",
            "studyUID": "1.2.3",
            "seriesUID": "1.2.3.4",
            "objectUID": "1.2.3.4.5",
            "frameNumber": "0"
        ]
        XCTAssertThrowsError(try WADOURIRequest.parse(queryParams: params)) { error in
            guard case DICOMwebError.badRequest = error else {
                XCTFail("Expected badRequest")
                return
            }
        }
    }

    // MARK: - WADO-URI Handler

    func test_wadoURI_retrieve_notFound_throws() async {
        let store = InMemoryDICOMMetadataStore()
        let handler = WADOURIHandler(archivePath: "/tmp", metadataStore: store)
        let params: [String: String] = [
            "requestType": "WADO",
            "studyUID": "1.2.3",
            "seriesUID": "1.2.3.4",
            "objectUID": "1.2.3.nonexistent"
        ]
        do {
            let req = try WADOURIRequest.parse(queryParams: params)
            _ = try await handler.retrieve(request: req)
            XCTFail("Expected DICOMwebError.notFound")
        } catch DICOMwebError.notFound {
            // expected
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }
}
