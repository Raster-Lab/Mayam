// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOMweb Error Tests

import XCTest
@testable import MayamWeb

final class DICOMwebErrorTests: XCTestCase {

    func test_notFound_httpStatus_is404() {
        XCTAssertEqual(DICOMwebError.notFound(resource: "Study 1.2.3").httpStatusCode, 404)
    }

    func test_badRequest_httpStatus_is400() {
        XCTAssertEqual(DICOMwebError.badRequest(reason: "bad").httpStatusCode, 400)
    }

    func test_unsupportedMediaType_httpStatus_is415() {
        XCTAssertEqual(DICOMwebError.unsupportedMediaType(mediaType: "text/plain").httpStatusCode, 415)
    }

    func test_notAcceptable_httpStatus_is406() {
        XCTAssertEqual(DICOMwebError.notAcceptable(accepted: "image/jpeg").httpStatusCode, 406)
    }

    func test_methodNotAllowed_httpStatus_is405() {
        XCTAssertEqual(DICOMwebError.methodNotAllowed(method: "DELETE").httpStatusCode, 405)
    }

    func test_conflict_httpStatus_is409() {
        XCTAssertEqual(DICOMwebError.conflict(reason: "duplicate UID").httpStatusCode, 409)
    }

    func test_multipartParseFailure_httpStatus_is400() {
        XCTAssertEqual(DICOMwebError.multipartParseFailure(reason: "no boundary").httpStatusCode, 400)
    }

    func test_jsonParseFailure_httpStatus_is400() {
        XCTAssertEqual(DICOMwebError.jsonParseFailure(reason: "invalid JSON").httpStatusCode, 400)
    }

    func test_internalError_httpStatus_is500() {
        struct E: Error {}
        XCTAssertEqual(DICOMwebError.internalError(underlying: E()).httpStatusCode, 500)
    }

    func test_description_containsRelevantInfo() {
        XCTAssertTrue(DICOMwebError.notFound(resource: "Study X").description.contains("Study X"))
        XCTAssertTrue(DICOMwebError.badRequest(reason: "missing param").description.contains("missing param"))
        XCTAssertTrue(DICOMwebError.conflict(reason: "duplicate").description.contains("duplicate"))
    }
}
