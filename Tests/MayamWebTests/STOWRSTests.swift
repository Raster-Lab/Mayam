// SPDX-License-Identifier: (see LICENSE)
// Mayam — STOW-RS Handler Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class STOWRSTests: XCTestCase {

    private var tempDir: String = ""

    override func setUp() {
        tempDir = NSTemporaryDirectory() + "mayam_stowrs_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    private func makeStorageActor() -> StorageActor {
        StorageActor(
            archivePath: tempDir,
            checksumEnabled: false,
            logger: MayamLogger(label: "test.stow")
        )
    }

    // MARK: - STOWRSResult

    func test_stowRSResult_isSuccess_whenStatusCode200() {
        let r = STOWRSResult(sopInstanceUID: "1.2.3", sopClassUID: "1.2.3.4", statusCode: 200)
        XCTAssertTrue(r.isSuccess)
    }

    func test_stowRSResult_isFailure_whenStatusCode409() {
        let r = STOWRSResult(sopInstanceUID: "1.2.3", sopClassUID: "1.2.3.4", statusCode: 409)
        XCTAssertFalse(r.isSuccess)
    }

    // MARK: - STOWRSResponse

    func test_stowRSResponse_allSucceeded_httpStatus200() {
        let r = STOWRSResponse(results: [
            STOWRSResult(sopInstanceUID: "1", sopClassUID: "c", statusCode: 200),
            STOWRSResult(sopInstanceUID: "2", sopClassUID: "c", statusCode: 200),
        ])
        XCTAssertEqual(r.httpStatusCode, 200)
    }

    func test_stowRSResponse_noneSucceeded_httpStatus409() {
        let r = STOWRSResponse(results: [
            STOWRSResult(sopInstanceUID: "1", sopClassUID: "c", statusCode: 409, failureReason: "dup"),
        ])
        XCTAssertEqual(r.httpStatusCode, 409)
    }

    func test_stowRSResponse_partialSuccess_httpStatus202() {
        let r = STOWRSResponse(results: [
            STOWRSResult(sopInstanceUID: "1", sopClassUID: "c", statusCode: 200),
            STOWRSResult(sopInstanceUID: "2", sopClassUID: "c", statusCode: 409, failureReason: "dup"),
        ])
        XCTAssertEqual(r.httpStatusCode, 202)
    }

    func test_stowRSResponse_encode_producesValidJSON() throws {
        let r = STOWRSResponse(results: [
            STOWRSResult(sopInstanceUID: "1.2.3", sopClassUID: "1.2.840.10008.5.1.4.1.1.2"),
        ])
        let data = try r.encode()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["00081199"]) // ReferencedSOPSequence
    }

    // MARK: - STOW-RS Handler

    func test_stowRS_missingBoundary_throws() async {
        let store = InMemoryDICOMMetadataStore()
        let handler = STOWRSHandler(storageActor: makeStorageActor(), metadataStore: store)
        do {
            _ = try await handler.storeInstances(
                body: Data(),
                contentType: "multipart/related; type=\"application/dicom\""
            )
            XCTFail("Expected DICOMwebError.badRequest")
        } catch DICOMwebError.badRequest {
            // expected
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func test_stowRS_emptyBody_throws() async {
        let store = InMemoryDICOMMetadataStore()
        let handler = STOWRSHandler(storageActor: makeStorageActor(), metadataStore: store)
        do {
            _ = try await handler.storeInstances(
                body: Data(),
                contentType: "multipart/related; type=\"application/dicom\"; boundary=b123"
            )
            XCTFail("Expected DICOMwebError.badRequest")
        } catch DICOMwebError.badRequest {
            // expected
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func test_stowRS_validMultipart_storesInstances() async throws {
        let store = InMemoryDICOMMetadataStore()
        let handler = STOWRSHandler(storageActor: makeStorageActor(), metadataStore: store)

        // Build a minimal multipart/related body with one DICOM part
        let boundary = "test_stow_boundary"
        let fakeSOPUID = "1.2.3.4.5.6.7"
        let contentType = "multipart/related; type=\"application/dicom\"; boundary=\(boundary)"
        let part = MultipartPart(
            headers: [
                "Content-Type": "application/dicom",
                "Content-Location": "studies/1.2.3/series/1.2.3.4/instances/\(fakeSOPUID)"
            ],
            body: "FAKE_DICOM_DATA".data(using: .utf8)!
        )
        let body = MultipartDICOM.serialise(parts: [part], boundary: boundary)

        let result = try await handler.storeInstances(body: body, contentType: contentType)
        XCTAssertFalse(result.results.isEmpty)
    }
}
