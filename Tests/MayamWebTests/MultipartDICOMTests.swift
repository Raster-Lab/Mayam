// SPDX-License-Identifier: (see LICENSE)
// Mayam — Multipart DICOM Tests

import XCTest
@testable import MayamWeb

final class MultipartDICOMTests: XCTestCase {

    // MARK: - Boundary Extraction

    func test_extractBoundary_standard_returnsBoundary() {
        let ct = "multipart/related; type=\"application/dicom\"; boundary=myboundary"
        XCTAssertEqual(MultipartDICOM.extractBoundary(from: ct), "myboundary")
    }

    func test_extractBoundary_quotedBoundary_returnsBoundary() {
        let ct = "multipart/related; boundary=\"my-boundary-123\""
        XCTAssertEqual(MultipartDICOM.extractBoundary(from: ct), "my-boundary-123")
    }

    func test_extractBoundary_missingBoundary_returnsNil() {
        let ct = "multipart/related; type=\"application/dicom\""
        XCTAssertNil(MultipartDICOM.extractBoundary(from: ct))
    }

    func test_extractBoundary_emptyBoundary_returnsNil() {
        let ct = "multipart/related; boundary="
        XCTAssertNil(MultipartDICOM.extractBoundary(from: ct))
    }

    // MARK: - Boundary Generation

    func test_generateBoundary_hasPrefix() {
        let b = MultipartDICOM.generateBoundary()
        XCTAssertTrue(b.hasPrefix("mayam_boundary_"))
    }

    func test_generateBoundary_isUnique() {
        let b1 = MultipartDICOM.generateBoundary()
        let b2 = MultipartDICOM.generateBoundary()
        XCTAssertNotEqual(b1, b2)
    }

    // MARK: - Serialisation and Round-Trip

    func test_serialise_singlePart_roundTrips() throws {
        let boundary = "test_boundary_123"
        let body = "DICOM_DATA".data(using: .utf8)!
        let headers = ["Content-Type": "application/dicom"]
        let part = MultipartPart(headers: headers, body: body)

        let serialised = MultipartDICOM.serialise(parts: [part], boundary: boundary)
        let parsed = try MultipartDICOM.parse(data: serialised, boundary: boundary)

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].body, body)
        XCTAssertEqual(parsed[0].contentType, "application/dicom")
    }

    func test_serialise_multipleParts_roundTrips() throws {
        let boundary = "b12345"
        let parts = [
            MultipartPart(
                headers: ["Content-Type": "application/dicom"],
                body: "PART1".data(using: .utf8)!
            ),
            MultipartPart(
                headers: ["Content-Type": "application/dicom", "Content-Location": "/instances/1"],
                body: "PART2".data(using: .utf8)!
            ),
        ]

        let serialised = MultipartDICOM.serialise(parts: parts, boundary: boundary)
        let parsed = try MultipartDICOM.parse(data: serialised, boundary: boundary)

        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].body, "PART1".data(using: .utf8)!)
        XCTAssertEqual(parsed[1].body, "PART2".data(using: .utf8)!)
        XCTAssertEqual(parsed[1].contentLocation, "/instances/1")
    }

    func test_serialise_emptyParts_producesClosingBoundary() {
        let boundary = "empty"
        let data = MultipartDICOM.serialise(parts: [], boundary: boundary)
        let str = String(data: data, encoding: .utf8)!
        XCTAssertTrue(str.contains("--empty--"))
    }

    // MARK: - Parse Error

    func test_parse_noBoundaryInData_throws() {
        let data = "no boundary here".data(using: .utf8)!
        XCTAssertThrowsError(try MultipartDICOM.parse(data: data, boundary: "missing")) { error in
            guard case DICOMwebError.multipartParseFailure = error else {
                XCTFail("Expected multipartParseFailure, got \(error)")
                return
            }
        }
    }
}
