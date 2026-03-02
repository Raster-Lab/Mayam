// SPDX-License-Identifier: (see LICENSE)
// Mayam — Image Codec Integration Tests

import XCTest
import Foundation
@testable import MayamCore
import Logging

// MARK: - TransferSyntaxRegistry Tests

final class TransferSyntaxRegistryTests: XCTestCase {

    // MARK: - UID Constants

    func test_registry_implicitVRLittleEndianUID_isCorrect() {
        XCTAssertEqual(TransferSyntaxRegistry.implicitVRLittleEndianUID, "1.2.840.10008.1.2")
    }

    func test_registry_explicitVRLittleEndianUID_isCorrect() {
        XCTAssertEqual(TransferSyntaxRegistry.explicitVRLittleEndianUID, "1.2.840.10008.1.2.1")
    }

    func test_registry_jpeg2000LosslessUID_isCorrect() {
        XCTAssertEqual(TransferSyntaxRegistry.jpeg2000LosslessUID, "1.2.840.10008.1.2.4.90")
    }

    func test_registry_jpeg2000LossyUID_isCorrect() {
        XCTAssertEqual(TransferSyntaxRegistry.jpeg2000LossyUID, "1.2.840.10008.1.2.4.91")
    }

    func test_registry_jpegLSLosslessUID_isCorrect() {
        XCTAssertEqual(TransferSyntaxRegistry.jpegLSLosslessUID, "1.2.840.10008.1.2.4.80")
    }

    func test_registry_jpegLSNearLosslessUID_isCorrect() {
        XCTAssertEqual(TransferSyntaxRegistry.jpegLSNearLosslessUID, "1.2.840.10008.1.2.4.81")
    }

    func test_registry_htj2kLosslessUID_isCorrect() {
        XCTAssertEqual(TransferSyntaxRegistry.htj2kLosslessUID, "1.2.840.10008.1.2.4.201")
    }

    func test_registry_jpegXLLosslessUID_isCorrect() {
        XCTAssertEqual(TransferSyntaxRegistry.jpegXLLosslessUID, "1.2.840.10008.1.2.4.110")
    }

    func test_registry_rleLosslessUID_isCorrect() {
        XCTAssertEqual(TransferSyntaxRegistry.rleLosslessUID, "1.2.840.10008.1.2.5")
    }

    // MARK: - Lookup Methods

    func test_registry_infoForKnownUID_returnsInfo() {
        let info = TransferSyntaxRegistry.info(for: "1.2.840.10008.1.2.4.90")
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.name, "JPEG 2000 Lossless")
        XCTAssertTrue(info?.isCompressed ?? false)
        XCTAssertTrue(info?.isLossless ?? false)
        XCTAssertEqual(info?.codec, .jpeg2000)
    }

    func test_registry_infoForUnknownUID_returnsNil() {
        let info = TransferSyntaxRegistry.info(for: "9.9.9.9.9")
        XCTAssertNil(info)
    }

    func test_registry_isCompressed_implicitVR_returnsFalse() {
        XCTAssertFalse(TransferSyntaxRegistry.isCompressed("1.2.840.10008.1.2"))
    }

    func test_registry_isCompressed_jpeg2000_returnsTrue() {
        XCTAssertTrue(TransferSyntaxRegistry.isCompressed("1.2.840.10008.1.2.4.90"))
    }

    func test_registry_isCompressed_unknownUID_returnsFalse() {
        XCTAssertFalse(TransferSyntaxRegistry.isCompressed("9.9.9.9.9"))
    }

    func test_registry_isLossless_implicitVR_returnsTrue() {
        XCTAssertTrue(TransferSyntaxRegistry.isLossless("1.2.840.10008.1.2"))
    }

    func test_registry_isLossless_jpeg2000Lossy_returnsFalse() {
        XCTAssertFalse(TransferSyntaxRegistry.isLossless("1.2.840.10008.1.2.4.91"))
    }

    func test_registry_isLossless_unknownUID_returnsTrue() {
        // Conservative assumption: unknown is lossless
        XCTAssertTrue(TransferSyntaxRegistry.isLossless("9.9.9.9.9"))
    }

    func test_registry_codecForJPEG2000_returnsJPEG2000() {
        XCTAssertEqual(TransferSyntaxRegistry.codec(for: "1.2.840.10008.1.2.4.90"), .jpeg2000)
    }

    func test_registry_codecForJPEGLS_returnsJPEGLS() {
        XCTAssertEqual(TransferSyntaxRegistry.codec(for: "1.2.840.10008.1.2.4.80"), .jpegLS)
    }

    func test_registry_codecForJPEGXL_returnsJPEGXL() {
        XCTAssertEqual(TransferSyntaxRegistry.codec(for: "1.2.840.10008.1.2.4.110"), .jpegXL)
    }

    func test_registry_codecForRLE_returnsRLE() {
        XCTAssertEqual(TransferSyntaxRegistry.codec(for: "1.2.840.10008.1.2.5"), .rle)
    }

    func test_registry_codecForImplicitVR_returnsNil() {
        XCTAssertNil(TransferSyntaxRegistry.codec(for: "1.2.840.10008.1.2"))
    }

    func test_registry_codecForHTJ2K_returnsJPEG2000() {
        XCTAssertEqual(TransferSyntaxRegistry.codec(for: "1.2.840.10008.1.2.4.201"), .jpeg2000)
    }

    // MARK: - UID Collections

    func test_registry_uncompressedUIDs_containsImplicitVR() {
        XCTAssertTrue(TransferSyntaxRegistry.uncompressedUIDs.contains("1.2.840.10008.1.2"))
    }

    func test_registry_uncompressedUIDs_doesNotContainJPEG2000() {
        XCTAssertFalse(TransferSyntaxRegistry.uncompressedUIDs.contains("1.2.840.10008.1.2.4.90"))
    }

    func test_registry_compressedUIDs_containsJPEG2000() {
        XCTAssertTrue(TransferSyntaxRegistry.compressedUIDs.contains("1.2.840.10008.1.2.4.90"))
    }

    func test_registry_compressedUIDs_containsJPEGLS() {
        XCTAssertTrue(TransferSyntaxRegistry.compressedUIDs.contains("1.2.840.10008.1.2.4.80"))
    }

    func test_registry_compressedUIDs_containsJPEGXL() {
        XCTAssertTrue(TransferSyntaxRegistry.compressedUIDs.contains("1.2.840.10008.1.2.4.110"))
    }

    func test_registry_losslessUIDs_containsJPEG2000Lossless() {
        XCTAssertTrue(TransferSyntaxRegistry.losslessUIDs.contains("1.2.840.10008.1.2.4.90"))
    }

    func test_registry_losslessUIDs_doesNotContainJPEG2000Lossy() {
        XCTAssertFalse(TransferSyntaxRegistry.losslessUIDs.contains("1.2.840.10008.1.2.4.91"))
    }

    func test_registry_uidsForJPEG2000_containsLosslessAndLossy() {
        let uids = TransferSyntaxRegistry.uids(for: .jpeg2000)
        XCTAssertTrue(uids.contains("1.2.840.10008.1.2.4.90"))
        XCTAssertTrue(uids.contains("1.2.840.10008.1.2.4.91"))
    }

    func test_registry_uidsForJPEGLS_containsBothModes() {
        let uids = TransferSyntaxRegistry.uids(for: .jpegLS)
        XCTAssertTrue(uids.contains("1.2.840.10008.1.2.4.80"))
        XCTAssertTrue(uids.contains("1.2.840.10008.1.2.4.81"))
    }

    func test_registry_allSupportedUIDs_isNotEmpty() {
        XCTAssertFalse(TransferSyntaxRegistry.allSupportedUIDs.isEmpty)
    }

    func test_registry_allSupportedUIDs_containsAllExpectedSyntaxes() {
        let expected: [String] = [
            "1.2.840.10008.1.2",
            "1.2.840.10008.1.2.1",
            "1.2.840.10008.1.2.5",
            "1.2.840.10008.1.2.4.90",
            "1.2.840.10008.1.2.4.91",
            "1.2.840.10008.1.2.4.80",
            "1.2.840.10008.1.2.4.81",
            "1.2.840.10008.1.2.4.201",
            "1.2.840.10008.1.2.4.110",
            "1.2.840.10008.1.2.4.111",
        ]
        for uid in expected {
            XCTAssertTrue(TransferSyntaxRegistry.allSupportedUIDs.contains(uid), "Missing UID: \(uid)")
        }
    }

    func test_registry_allSyntaxList_matchesAllSyntaxesCount() {
        XCTAssertEqual(TransferSyntaxRegistry.allSyntaxList.count, TransferSyntaxRegistry.allSyntaxes.count)
    }
}

// MARK: - TransferSyntaxInfo Tests

final class TransferSyntaxInfoTests: XCTestCase {

    func test_transferSyntaxInfo_equatable_equalInstances() {
        let a = TransferSyntaxInfo(uid: "1.2.3", name: "Test", isCompressed: true, isLossless: true, codec: .jpeg2000)
        let b = TransferSyntaxInfo(uid: "1.2.3", name: "Test", isCompressed: true, isLossless: true, codec: .jpeg2000)
        XCTAssertEqual(a, b)
    }

    func test_transferSyntaxInfo_equatable_differentInstances() {
        let a = TransferSyntaxInfo(uid: "1.2.3", name: "Test A", isCompressed: true, isLossless: true, codec: .jpeg2000)
        let b = TransferSyntaxInfo(uid: "1.2.4", name: "Test B", isCompressed: false, isLossless: true, codec: nil)
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - CodecFramework Tests

final class CodecFrameworkTests: XCTestCase {

    func test_codecFramework_allCases_containsExpectedCodecs() {
        let cases = CodecFramework.allCases
        XCTAssertTrue(cases.contains(.jpeg2000))
        XCTAssertTrue(cases.contains(.jpegLS))
        XCTAssertTrue(cases.contains(.jpegXL))
        XCTAssertTrue(cases.contains(.jp3d))
        XCTAssertTrue(cases.contains(.rle))
    }

    func test_codecFramework_rawValues_areCorrect() {
        XCTAssertEqual(CodecFramework.jpeg2000.rawValue, "J2KSwift")
        XCTAssertEqual(CodecFramework.jpegLS.rawValue, "JLSwift")
        XCTAssertEqual(CodecFramework.jpegXL.rawValue, "JXLSwift")
        XCTAssertEqual(CodecFramework.jp3d.rawValue, "J2K3D")
        XCTAssertEqual(CodecFramework.rle.rawValue, "RLE")
    }

    func test_codecFramework_codable_roundTrip() throws {
        let original = CodecFramework.jpeg2000
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodecFramework.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - CodecError Tests

final class CodecErrorTests: XCTestCase {

    func test_codecError_unsupportedTransferSyntax_description() {
        let error = CodecError.unsupportedTransferSyntax(uid: "1.2.3")
        XCTAssertTrue(error.description.contains("1.2.3"))
    }

    func test_codecError_encodingFailed_description() {
        let error = CodecError.encodingFailed(codec: .jpeg2000, reason: "test reason")
        XCTAssertTrue(error.description.contains("J2KSwift"))
        XCTAssertTrue(error.description.contains("test reason"))
    }

    func test_codecError_decodingFailed_description() {
        let error = CodecError.decodingFailed(codec: .jpegLS, reason: "bad data")
        XCTAssertTrue(error.description.contains("JLSwift"))
        XCTAssertTrue(error.description.contains("bad data"))
    }

    func test_codecError_invalidSourceData_description() {
        let error = CodecError.invalidSourceData(reason: "empty buffer")
        XCTAssertTrue(error.description.contains("empty buffer"))
    }

    func test_codecError_transcodingNotSupported_description() {
        let error = CodecError.transcodingNotSupported(from: "A", to: "B")
        XCTAssertTrue(error.description.contains("A"))
        XCTAssertTrue(error.description.contains("B"))
    }

    func test_codecError_derivativeLimitExceeded_description() {
        let error = CodecError.derivativeLimitExceeded(studyInstanceUID: "1.2.3", limit: 3)
        XCTAssertTrue(error.description.contains("1.2.3"))
        XCTAssertTrue(error.description.contains("3"))
    }

    func test_codecError_batchTranscodingFailed_description() {
        let error = CodecError.batchTranscodingFailed(studyInstanceUID: "1.2.3", reason: "timeout")
        XCTAssertTrue(error.description.contains("1.2.3"))
        XCTAssertTrue(error.description.contains("timeout"))
    }
}

// MARK: - ImageParameters Tests

final class ImageParametersTests: XCTestCase {

    func test_imageParameters_defaultValues() {
        let params = ImageParameters()
        XCTAssertEqual(params.rows, 512)
        XCTAssertEqual(params.columns, 512)
        XCTAssertEqual(params.bitsAllocated, 16)
        XCTAssertEqual(params.bitsStored, 12)
        XCTAssertEqual(params.highBit, 11)
        XCTAssertEqual(params.pixelRepresentation, 0)
        XCTAssertEqual(params.samplesPerPixel, 1)
        XCTAssertEqual(params.numberOfFrames, 1)
        XCTAssertEqual(params.photometricInterpretation, "MONOCHROME2")
    }

    func test_imageParameters_customValues() {
        let params = ImageParameters(
            rows: 256,
            columns: 256,
            bitsAllocated: 8,
            bitsStored: 8,
            highBit: 7,
            pixelRepresentation: 0,
            samplesPerPixel: 3,
            numberOfFrames: 10,
            photometricInterpretation: "RGB"
        )
        XCTAssertEqual(params.rows, 256)
        XCTAssertEqual(params.columns, 256)
        XCTAssertEqual(params.bitsAllocated, 8)
        XCTAssertEqual(params.samplesPerPixel, 3)
        XCTAssertEqual(params.numberOfFrames, 10)
    }

    func test_imageParameters_codable_roundTrip() throws {
        let original = ImageParameters(rows: 128, columns: 128, bitsAllocated: 8, bitsStored: 8, highBit: 7)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageParameters.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_imageParameters_equatable() {
        let a = ImageParameters(rows: 100, columns: 200)
        let b = ImageParameters(rows: 100, columns: 200)
        XCTAssertEqual(a, b)
    }
}

// MARK: - TranscodingResult Tests

final class TranscodingResultTests: XCTestCase {

    func test_transcodingResult_properties_arePreserved() {
        let data = Data([0x00, 0x01, 0x02])
        let result = TranscodingResult(
            data: data,
            transferSyntaxUID: "1.2.840.10008.1.2.4.90",
            wasTranscoded: true
        )
        XCTAssertEqual(result.data, data)
        XCTAssertEqual(result.transferSyntaxUID, "1.2.840.10008.1.2.4.90")
        XCTAssertTrue(result.wasTranscoded)
    }

    func test_transcodingResult_notTranscoded() {
        let result = TranscodingResult(data: Data(), transferSyntaxUID: "1.2.840.10008.1.2", wasTranscoded: false)
        XCTAssertFalse(result.wasTranscoded)
    }
}

// MARK: - ImageCodecService Tests

final class ImageCodecServiceTests: XCTestCase {

    private func makeLogger() -> Logger {
        Logger(label: "test.codec")
    }

    func test_imageCodecService_canTranscode_sameUID_returnsTrue() async {
        let service = ImageCodecService(logger: makeLogger())
        XCTAssertTrue(service.canTranscode(from: "1.2.840.10008.1.2", to: "1.2.840.10008.1.2"))
    }

    func test_imageCodecService_canTranscode_knownUIDs_returnsTrue() async {
        let service = ImageCodecService(logger: makeLogger())
        XCTAssertTrue(service.canTranscode(from: "1.2.840.10008.1.2", to: "1.2.840.10008.1.2.4.90"))
    }

    func test_imageCodecService_canTranscode_unknownUID_returnsFalse() async {
        let service = ImageCodecService(logger: makeLogger())
        XCTAssertFalse(service.canTranscode(from: "9.9.9.9", to: "1.2.840.10008.1.2.4.90"))
    }

    func test_imageCodecService_supportedTargets_knownUID_returnsAllSupported() async {
        let service = ImageCodecService(logger: makeLogger())
        let targets = service.supportedTargets(from: "1.2.840.10008.1.2")
        XCTAssertEqual(targets, TransferSyntaxRegistry.allSupportedUIDs)
    }

    func test_imageCodecService_supportedTargets_unknownUID_returnsEmpty() async {
        let service = ImageCodecService(logger: makeLogger())
        let targets = service.supportedTargets(from: "9.9.9.9")
        XCTAssertTrue(targets.isEmpty)
    }

    func test_imageCodecService_transcode_sameUID_returnsOriginal() async throws {
        let service = ImageCodecService(logger: makeLogger())
        let data = Data([0x00, 0x01, 0x02])
        let result = try await service.transcode(
            pixelData: data,
            from: "1.2.840.10008.1.2",
            to: "1.2.840.10008.1.2",
            imageParameters: ImageParameters()
        )
        XCTAssertEqual(result.data, data)
        XCTAssertFalse(result.wasTranscoded)
    }

    func test_imageCodecService_transcode_unknownSourceUID_throwsError() async {
        let service = ImageCodecService(logger: makeLogger())
        do {
            _ = try await service.transcode(
                pixelData: Data(),
                from: "9.9.9.9",
                to: "1.2.840.10008.1.2.4.90",
                imageParameters: ImageParameters()
            )
            XCTFail("Expected error")
        } catch {
            if case CodecError.unsupportedTransferSyntax(let uid) = error {
                XCTAssertEqual(uid, "9.9.9.9")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func test_imageCodecService_transcode_unknownTargetUID_throwsError() async {
        let service = ImageCodecService(logger: makeLogger())
        do {
            _ = try await service.transcode(
                pixelData: Data(),
                from: "1.2.840.10008.1.2",
                to: "9.9.9.9",
                imageParameters: ImageParameters()
            )
            XCTFail("Expected error")
        } catch {
            if case CodecError.unsupportedTransferSyntax(let uid) = error {
                XCTAssertEqual(uid, "9.9.9.9")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func test_imageCodecService_transcodingCount_incrementsOnTranscode() async throws {
        let service = ImageCodecService(logger: makeLogger())
        let count0 = await service.getTranscodingCount()
        XCTAssertEqual(count0, 0)

        // Uncompressed → uncompressed (still counts if different UIDs)
        _ = try await service.transcode(
            pixelData: Data([0x00]),
            from: "1.2.840.10008.1.2",
            to: "1.2.840.10008.1.2.1",
            imageParameters: ImageParameters()
        )
        let count1 = await service.getTranscodingCount()
        XCTAssertEqual(count1, 1)
    }

    func test_imageCodecService_selectBestTransferSyntax_directMatch() async {
        let service = ImageCodecService(logger: makeLogger())
        let stored: Set<String> = ["1.2.840.10008.1.2", "1.2.840.10008.1.2.4.90"]
        let client: Set<String> = ["1.2.840.10008.1.2.4.90"]
        let best = service.selectBestTransferSyntax(storedSyntaxUIDs: stored, clientAcceptedUIDs: client)
        XCTAssertEqual(best, "1.2.840.10008.1.2.4.90")
    }

    func test_imageCodecService_selectBestTransferSyntax_prefersLossless() async {
        let service = ImageCodecService(logger: makeLogger())
        let stored: Set<String> = ["1.2.840.10008.1.2.4.90", "1.2.840.10008.1.2.4.91"]
        let client: Set<String> = ["1.2.840.10008.1.2.4.90", "1.2.840.10008.1.2.4.91"]
        let best = service.selectBestTransferSyntax(storedSyntaxUIDs: stored, clientAcceptedUIDs: client)
        XCTAssertEqual(best, "1.2.840.10008.1.2.4.90")
    }

    func test_imageCodecService_selectBestTransferSyntax_noMatch_returnsNil() async {
        let service = ImageCodecService(logger: makeLogger())
        let stored: Set<String> = ["1.2.840.10008.1.2"]
        let client: Set<String> = ["1.2.840.10008.1.2.4.90"]
        let best = service.selectBestTransferSyntax(storedSyntaxUIDs: stored, clientAcceptedUIDs: client)
        XCTAssertNil(best)
    }
}

// MARK: - Representation Tests

final class RepresentationTests: XCTestCase {

    func test_representation_properties_arePreserved() {
        let rep = Representation(
            id: "test-id",
            sopInstanceUID: "1.2.3.4",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "PAT001/1.2.3/1.2.3.4/1.2.3.4.5.dcm",
            fileSizeBytes: 1024,
            isOriginal: true,
            isDerived: false,
            checksumSHA256: "abc123"
        )
        XCTAssertEqual(rep.id, "test-id")
        XCTAssertEqual(rep.sopInstanceUID, "1.2.3.4")
        XCTAssertEqual(rep.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(rep.transferSyntaxUID, "1.2.840.10008.1.2")
        XCTAssertTrue(rep.isOriginal)
        XCTAssertFalse(rep.isDerived)
        XCTAssertEqual(rep.checksumSHA256, "abc123")
    }

    func test_representation_defaults_isOriginalTrue() {
        let rep = Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "test.dcm",
            fileSizeBytes: 0
        )
        XCTAssertTrue(rep.isOriginal)
        XCTAssertFalse(rep.isDerived)
        XCTAssertNil(rep.codec)
    }

    func test_representation_codable_roundTrip() throws {
        let original = Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.4.90",
            filePath: "test.dcm",
            fileSizeBytes: 512,
            codec: .jpeg2000
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Representation.self, from: data)
        XCTAssertEqual(original.sopInstanceUID, decoded.sopInstanceUID)
        XCTAssertEqual(original.transferSyntaxUID, decoded.transferSyntaxUID)
        XCTAssertEqual(original.codec, decoded.codec)
    }
}

// MARK: - RepresentationSet Tests

final class RepresentationSetTests: XCTestCase {

    func test_representationSet_empty_hasNoRepresentations() {
        let set = RepresentationSet(sopInstanceUID: "1.2.3")
        XCTAssertEqual(set.count, 0)
        XCTAssertNil(set.original)
        XCTAssertTrue(set.derived.isEmpty)
        XCTAssertTrue(set.availableTransferSyntaxUIDs.isEmpty)
    }

    func test_representationSet_addRepresentation_incrementsCount() {
        var set = RepresentationSet(sopInstanceUID: "1.2.3")
        set.add(Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "test.dcm",
            fileSizeBytes: 100
        ))
        XCTAssertEqual(set.count, 1)
    }

    func test_representationSet_original_returnsFirstOriginal() {
        var set = RepresentationSet(sopInstanceUID: "1.2.3")
        set.add(Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "test.dcm",
            fileSizeBytes: 100,
            isOriginal: true
        ))
        XCTAssertNotNil(set.original)
        XCTAssertEqual(set.original?.transferSyntaxUID, "1.2.840.10008.1.2")
    }

    func test_representationSet_derived_returnsDerivedOnly() {
        var set = RepresentationSet(sopInstanceUID: "1.2.3")
        set.add(Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "original.dcm",
            fileSizeBytes: 100,
            isOriginal: true,
            isDerived: false
        ))
        set.add(Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.4.90",
            filePath: "compressed.dcm",
            fileSizeBytes: 50,
            isOriginal: false,
            isDerived: true
        ))
        XCTAssertEqual(set.derived.count, 1)
        XCTAssertEqual(set.derived.first?.transferSyntaxUID, "1.2.840.10008.1.2.4.90")
    }

    func test_representationSet_availableTransferSyntaxUIDs() {
        var set = RepresentationSet(sopInstanceUID: "1.2.3")
        set.add(Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "a.dcm",
            fileSizeBytes: 100
        ))
        set.add(Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.4.90",
            filePath: "b.dcm",
            fileSizeBytes: 50,
            isOriginal: false,
            isDerived: true
        ))
        XCTAssertEqual(set.availableTransferSyntaxUIDs.count, 2)
        XCTAssertTrue(set.availableTransferSyntaxUIDs.contains("1.2.840.10008.1.2"))
        XCTAssertTrue(set.availableTransferSyntaxUIDs.contains("1.2.840.10008.1.2.4.90"))
    }

    func test_representationSet_bestMatch_directMatch() {
        var set = RepresentationSet(sopInstanceUID: "1.2.3")
        set.add(Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "a.dcm",
            fileSizeBytes: 100
        ))
        set.add(Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.4.90",
            filePath: "b.dcm",
            fileSizeBytes: 50,
            isOriginal: false,
            isDerived: true
        ))
        let match = set.bestMatch(for: ["1.2.840.10008.1.2.4.90"])
        XCTAssertEqual(match?.transferSyntaxUID, "1.2.840.10008.1.2.4.90")
    }

    func test_representationSet_bestMatch_noMatch_fallsBackToOriginal() {
        var set = RepresentationSet(sopInstanceUID: "1.2.3")
        set.add(Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "a.dcm",
            fileSizeBytes: 100,
            isOriginal: true
        ))
        let match = set.bestMatch(for: ["1.2.840.10008.1.2.4.80"])
        XCTAssertEqual(match?.transferSyntaxUID, "1.2.840.10008.1.2")
    }
}

// MARK: - RepresentationPolicy Tests

final class RepresentationPolicyTests: XCTestCase {

    func test_representationPolicy_default_compressedCopyDisabled() {
        let policy = RepresentationPolicy.default
        XCTAssertFalse(policy.compressedCopyOnReceipt)
        XCTAssertEqual(policy.defaultCompressedCopySyntaxUID, TransferSyntaxRegistry.jpeg2000LosslessUID)
        XCTAssertTrue(policy.modalityRules.isEmpty)
        XCTAssertTrue(policy.siteProfiles.isEmpty)
        XCTAssertTrue(policy.teleRadiologyDestinations.isEmpty)
        XCTAssertEqual(policy.derivativeLimit, 3)
    }

    func test_representationPolicy_targetSyntaxUID_withModalityRule() {
        let policy = RepresentationPolicy(
            modalityRules: [
                ModalityCodecRule(modality: "CT", targetTransferSyntaxUID: "1.2.840.10008.1.2.4.80")
            ]
        )
        XCTAssertEqual(
            policy.targetSyntaxUID(for: "CT"),
            "1.2.840.10008.1.2.4.80"
        )
    }

    func test_representationPolicy_targetSyntaxUID_noRule_usesDefault() {
        let policy = RepresentationPolicy()
        XCTAssertEqual(
            policy.targetSyntaxUID(for: "CT"),
            TransferSyntaxRegistry.jpeg2000LosslessUID
        )
    }

    func test_representationPolicy_shouldCompressOnReceipt_disabled() {
        let policy = RepresentationPolicy(compressedCopyOnReceipt: false)
        XCTAssertFalse(policy.shouldCompressOnReceipt(modality: "CT"))
    }

    func test_representationPolicy_shouldCompressOnReceipt_enabled() {
        let policy = RepresentationPolicy(compressedCopyOnReceipt: true)
        XCTAssertTrue(policy.shouldCompressOnReceipt(modality: "CT"))
    }

    func test_representationPolicy_shouldCompressOnReceipt_modalityRuleOverride() {
        let policy = RepresentationPolicy(
            compressedCopyOnReceipt: true,
            modalityRules: [
                ModalityCodecRule(modality: "US", targetTransferSyntaxUID: "1.2.840.10008.1.2", compressOnReceipt: false)
            ]
        )
        XCTAssertFalse(policy.shouldCompressOnReceipt(modality: "US"))
        XCTAssertTrue(policy.shouldCompressOnReceipt(modality: "CT"))
    }

    func test_representationPolicy_codable_roundTrip() throws {
        let original = RepresentationPolicy(
            compressedCopyOnReceipt: true,
            modalityRules: [
                ModalityCodecRule(modality: "CT", targetTransferSyntaxUID: "1.2.840.10008.1.2.4.90")
            ],
            derivativeLimit: 5
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RepresentationPolicy.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ModalityCodecRule Tests

final class ModalityCodecRuleTests: XCTestCase {

    func test_modalityCodecRule_properties() {
        let rule = ModalityCodecRule(
            modality: "CT",
            targetTransferSyntaxUID: "1.2.840.10008.1.2.4.90",
            compressOnReceipt: true
        )
        XCTAssertEqual(rule.modality, "CT")
        XCTAssertEqual(rule.targetTransferSyntaxUID, "1.2.840.10008.1.2.4.90")
        XCTAssertTrue(rule.compressOnReceipt)
    }

    func test_modalityCodecRule_defaultCompressOnReceipt_isTrue() {
        let rule = ModalityCodecRule(modality: "MR", targetTransferSyntaxUID: "1.2.840.10008.1.2.4.80")
        XCTAssertTrue(rule.compressOnReceipt)
    }
}

// MARK: - SiteStorageProfile Tests

final class SiteStorageProfileTests: XCTestCase {

    func test_siteStorageProfile_properties() {
        let profile = SiteStorageProfile(
            siteID: "SITE001",
            siteName: "Main Hospital",
            retainOriginal: true,
            compressedCopySyntaxes: ["1.2.840.10008.1.2.4.90"]
        )
        XCTAssertEqual(profile.siteID, "SITE001")
        XCTAssertEqual(profile.siteName, "Main Hospital")
        XCTAssertTrue(profile.retainOriginal)
        XCTAssertEqual(profile.compressedCopySyntaxes.count, 1)
    }

    func test_siteStorageProfile_defaults() {
        let profile = SiteStorageProfile(siteID: "S1", siteName: "Test")
        XCTAssertTrue(profile.retainOriginal)
        XCTAssertTrue(profile.compressedCopySyntaxes.isEmpty)
    }
}

// MARK: - TeleRadiologyDestination Tests

final class TeleRadiologyDestinationTests: XCTestCase {

    func test_teleRadiologyDestination_properties() {
        let dest = TeleRadiologyDestination(
            destinationID: "DEST001",
            destinationAETitle: "REMOTE_AE",
            preferredTransferSyntaxUID: "1.2.840.10008.1.2.4.91",
            preBuildOnIngest: true,
            bandwidthMbps: 100.0
        )
        XCTAssertEqual(dest.destinationID, "DEST001")
        XCTAssertEqual(dest.destinationAETitle, "REMOTE_AE")
        XCTAssertEqual(dest.preferredTransferSyntaxUID, "1.2.840.10008.1.2.4.91")
        XCTAssertTrue(dest.preBuildOnIngest)
        XCTAssertEqual(dest.bandwidthMbps, 100.0)
    }

    func test_teleRadiologyDestination_defaults() {
        let dest = TeleRadiologyDestination(
            destinationID: "D1",
            destinationAETitle: "AE1",
            preferredTransferSyntaxUID: "1.2.840.10008.1.2"
        )
        XCTAssertFalse(dest.preBuildOnIngest)
        XCTAssertNil(dest.bandwidthMbps)
    }
}

// MARK: - CompressedCopyManager Tests

final class CompressedCopyManagerTests: XCTestCase {

    private func makeLogger() -> Logger {
        Logger(label: "test.compressed-copy")
    }

    func test_compressedCopyManager_initialState_noCopies() async {
        let service = ImageCodecService(logger: makeLogger())
        let manager = CompressedCopyManager(codecService: service, logger: makeLogger())
        let count = await manager.getCompressedCopiesCreated()
        XCTAssertEqual(count, 0)
    }

    func test_compressedCopyManager_registerOriginal_tracked() async {
        let service = ImageCodecService(logger: makeLogger())
        let manager = CompressedCopyManager(codecService: service, logger: makeLogger())
        let rep = Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "test.dcm",
            fileSizeBytes: 100
        )
        await manager.registerOriginal(rep)
        let set = await manager.representationSet(for: "1.2.3")
        XCTAssertNotNil(set)
        XCTAssertEqual(set?.count, 1)
    }

    func test_compressedCopyManager_createCompressedCopy_policyDisabled_returnsNil() async throws {
        let service = ImageCodecService(logger: makeLogger())
        let policy = RepresentationPolicy(compressedCopyOnReceipt: false)
        let manager = CompressedCopyManager(codecService: service, policy: policy, logger: makeLogger())
        let result = try await manager.createCompressedCopyOnReceipt(
            pixelData: Data([0x00]),
            sourceTransferSyntaxUID: "1.2.840.10008.1.2",
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            imageParameters: ImageParameters()
        )
        XCTAssertNil(result)
    }

    func test_compressedCopyManager_enqueueBatchTranscoding_addsJob() async {
        let service = ImageCodecService(logger: makeLogger())
        let manager = CompressedCopyManager(codecService: service, logger: makeLogger())
        await manager.enqueueBatchTranscoding(
            studyInstanceUID: "1.2.3",
            targetSyntaxUID: "1.2.840.10008.1.2.4.90",
            imageParameters: ImageParameters()
        )
        let count = await manager.pendingJobCount()
        XCTAssertEqual(count, 1)
    }

    func test_compressedCopyManager_getPendingJobs_returnsEnqueuedJobs() async {
        let service = ImageCodecService(logger: makeLogger())
        let manager = CompressedCopyManager(codecService: service, logger: makeLogger())
        await manager.enqueueBatchTranscoding(
            studyInstanceUID: "1.2.3",
            targetSyntaxUID: "1.2.840.10008.1.2.4.90",
            imageParameters: ImageParameters()
        )
        let jobs = await manager.getPendingJobs()
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs.first?.studyInstanceUID, "1.2.3")
        XCTAssertEqual(jobs.first?.status, .pending)
    }

    func test_compressedCopyManager_selectBestRepresentation_returnsDirectMatch() async {
        let service = ImageCodecService(logger: makeLogger())
        let manager = CompressedCopyManager(codecService: service, logger: makeLogger())
        let rep = Representation(
            sopInstanceUID: "1.2.3",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2",
            filePath: "test.dcm",
            fileSizeBytes: 100
        )
        await manager.registerOriginal(rep)
        let best = await manager.selectBestRepresentation(
            for: "1.2.3",
            clientAcceptedUIDs: ["1.2.840.10008.1.2"]
        )
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.transferSyntaxUID, "1.2.840.10008.1.2")
    }
}

// MARK: - BatchTranscodingJob Tests

final class BatchTranscodingJobTests: XCTestCase {

    func test_batchTranscodingJob_properties() {
        let job = BatchTranscodingJob(
            studyInstanceUID: "1.2.3",
            targetSyntaxUID: "1.2.840.10008.1.2.4.90",
            imageParameters: ImageParameters(),
            status: .pending
        )
        XCTAssertEqual(job.studyInstanceUID, "1.2.3")
        XCTAssertEqual(job.targetSyntaxUID, "1.2.840.10008.1.2.4.90")
        XCTAssertEqual(job.status, .pending)
    }

    func test_batchTranscodingJob_status_allCases() {
        XCTAssertEqual(BatchTranscodingJob.Status.pending.rawValue, "pending")
        XCTAssertEqual(BatchTranscodingJob.Status.running.rawValue, "running")
        XCTAssertEqual(BatchTranscodingJob.Status.completed.rawValue, "completed")
        XCTAssertEqual(BatchTranscodingJob.Status.failed.rawValue, "failed")
    }
}

// MARK: - StoragePolicy Integration Tests

final class StoragePolicyCodecTests: XCTestCase {

    func test_storagePolicy_default_hasRepresentationPolicy() {
        let policy = StoragePolicy.default
        XCTAssertEqual(policy.representationPolicy, RepresentationPolicy.default)
        XCTAssertFalse(policy.representationPolicy.compressedCopyOnReceipt)
    }

    func test_storagePolicy_customRepresentationPolicy() {
        let repPolicy = RepresentationPolicy(
            compressedCopyOnReceipt: true,
            derivativeLimit: 5
        )
        let policy = StoragePolicy(representationPolicy: repPolicy)
        XCTAssertTrue(policy.representationPolicy.compressedCopyOnReceipt)
        XCTAssertEqual(policy.representationPolicy.derivativeLimit, 5)
    }

    func test_storagePolicy_codable_withRepresentationPolicy() throws {
        let repPolicy = RepresentationPolicy(
            compressedCopyOnReceipt: true,
            modalityRules: [
                ModalityCodecRule(modality: "CT", targetTransferSyntaxUID: "1.2.840.10008.1.2.4.90")
            ]
        )
        let policy = StoragePolicy(representationPolicy: repPolicy)
        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(StoragePolicy.self, from: data)
        XCTAssertEqual(decoded, policy)
    }
}

// MARK: - ServerConfiguration Codec Tests

final class ServerConfigurationCodecTests: XCTestCase {

    func test_serverConfiguration_defaultCodecConfig() {
        let config = ServerConfiguration()
        XCTAssertTrue(config.codec.onDemandTranscodingEnabled)
        XCTAssertFalse(config.codec.backgroundTranscodingEnabled)
        XCTAssertEqual(config.codec.maxConcurrentTranscodings, 4)
    }

    func test_serverConfiguration_customCodecConfig() {
        let config = ServerConfiguration(
            codec: .init(
                onDemandTranscodingEnabled: false,
                backgroundTranscodingEnabled: true,
                maxConcurrentTranscodings: 8
            )
        )
        XCTAssertFalse(config.codec.onDemandTranscodingEnabled)
        XCTAssertTrue(config.codec.backgroundTranscodingEnabled)
        XCTAssertEqual(config.codec.maxConcurrentTranscodings, 8)
    }

    func test_serverConfiguration_codecCodable_roundTrip() throws {
        let config = ServerConfiguration(
            codec: .init(
                onDemandTranscodingEnabled: true,
                backgroundTranscodingEnabled: true,
                maxConcurrentTranscodings: 16
            )
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ServerConfiguration.self, from: data)
        XCTAssertEqual(decoded.codec, config.codec)
    }

    func test_serverConfiguration_codecCodable_missingKey_usesDefaults() throws {
        let json = """
        {
            "dicom": { "aeTitle": "TEST" }
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ServerConfiguration.self, from: json)
        XCTAssertTrue(decoded.codec.onDemandTranscodingEnabled)
        XCTAssertFalse(decoded.codec.backgroundTranscodingEnabled)
        XCTAssertEqual(decoded.codec.maxConcurrentTranscodings, 4)
    }
}

// MARK: - DICOMListenerConfiguration Transfer Syntax Tests

final class DICOMListenerConfigurationCodecTests: XCTestCase {

    func test_defaultAcceptedTransferSyntaxes_includesJPEG2000() {
        let syntaxes = DICOMListenerConfiguration.defaultAcceptedTransferSyntaxes
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.4.90"), "Missing JPEG 2000 Lossless")
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.4.91"), "Missing JPEG 2000 Lossy")
    }

    func test_defaultAcceptedTransferSyntaxes_includesJPEGLS() {
        let syntaxes = DICOMListenerConfiguration.defaultAcceptedTransferSyntaxes
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.4.80"), "Missing JPEG-LS Lossless")
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.4.81"), "Missing JPEG-LS Near-Lossless")
    }

    func test_defaultAcceptedTransferSyntaxes_includesHTJ2K() {
        let syntaxes = DICOMListenerConfiguration.defaultAcceptedTransferSyntaxes
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.4.201"), "Missing HTJ2K Lossless")
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.4.202"), "Missing HTJ2K Lossy")
    }

    func test_defaultAcceptedTransferSyntaxes_includesJPEGXL() {
        let syntaxes = DICOMListenerConfiguration.defaultAcceptedTransferSyntaxes
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.4.110"), "Missing JPEG XL Lossless")
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.4.111"), "Missing JPEG XL Lossy")
    }

    func test_defaultAcceptedTransferSyntaxes_includesUncompressed() {
        let syntaxes = DICOMListenerConfiguration.defaultAcceptedTransferSyntaxes
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2"), "Missing Implicit VR LE")
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.1"), "Missing Explicit VR LE")
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.5"), "Missing RLE Lossless")
    }

    func test_defaultAcceptedTransferSyntaxes_matchesRegistryAll() {
        let syntaxes = DICOMListenerConfiguration.defaultAcceptedTransferSyntaxes
        XCTAssertEqual(syntaxes, TransferSyntaxRegistry.allSupportedUIDs)
    }
}
