// SPDX-License-Identifier: (see LICENSE)
// Mayam — Storage Component Tests

import XCTest
import Foundation
@testable import MayamCore
import DICOMNetwork
import Logging
import NIOPosix

// MARK: - StorageLayout Tests

final class StorageLayoutTests: XCTestCase {

    func test_storageLayout_relativePath_isCorrect() {
        let layout = StorageLayout(archivePath: "/archive")
        let path = layout.relativePath(
            patientID: "PAT001",
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            sopInstanceUID: "1.2.3.4.5"
        )
        XCTAssertEqual(path, "PAT001/1.2.3/1.2.3.4/1.2.3.4.5.dcm")
    }

    func test_storageLayout_absolutePath_prependsArchiveRoot() {
        let layout = StorageLayout(archivePath: "/archive")
        let path = layout.absolutePath(
            patientID: "PAT001",
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            sopInstanceUID: "1.2.3.4.5"
        )
        XCTAssertTrue(path.hasPrefix("/archive/"))
        XCTAssertTrue(path.hasSuffix(".dcm"))
    }

    func test_storageLayout_sanitise_replacesUnsafeCharacters() {
        let layout = StorageLayout(archivePath: "/archive")
        let safe = layout.sanitise("test/path\\evil:file*name")
        XCTAssertFalse(safe.contains("/"))
        XCTAssertFalse(safe.contains("\\"))
        XCTAssertFalse(safe.contains(":"))
        XCTAssertFalse(safe.contains("*"))
    }

    func test_storageLayout_sanitise_preservesDots() {
        let layout = StorageLayout(archivePath: "/archive")
        let uid = "1.2.840.10008.5.1.4.1.1.2"
        XCTAssertEqual(layout.sanitise(uid), uid)
    }

    func test_storageLayout_seriesDirectoryPath_isCorrect() {
        let layout = StorageLayout(archivePath: "/archive")
        let path = layout.seriesDirectoryPath(
            patientID: "PAT001",
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4"
        )
        XCTAssertEqual(path, "/archive/PAT001/1.2.3/1.2.3.4")
    }

    func test_storageLayout_studyDirectoryPath_isCorrect() {
        let layout = StorageLayout(archivePath: "/archive")
        let path = layout.studyDirectoryPath(patientID: "PAT001", studyInstanceUID: "1.2.3")
        XCTAssertEqual(path, "/archive/PAT001/1.2.3")
    }

    func test_storageLayout_createDirectoryHierarchy_createsDirectories() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_layout_test_\(UUID().uuidString)")
            .path
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let layout = StorageLayout(archivePath: tmp)
        XCTAssertNoThrow(
            try layout.createDirectoryHierarchy(
                patientID: "PAT001",
                studyInstanceUID: "1.2.3",
                seriesInstanceUID: "1.2.3.4"
            )
        )

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: tmp + "/PAT001/1.2.3/1.2.3.4",
            isDirectory: &isDir
        )
        XCTAssertTrue(exists)
        XCTAssertTrue(isDir.boolValue)
    }

    func test_storageLayoutError_description_containsPath() {
        let err = StorageLayoutError.directoryCreationFailed(
            path: "/bad/path",
            underlying: NSError(domain: "test", code: 1)
        )
        XCTAssertTrue(err.description.contains("/bad/path"))
    }
}

// MARK: - StoragePolicy Tests

final class StoragePolicyTests: XCTestCase {

    func test_duplicatePolicy_rawValues_areDistinct() {
        let cases = DuplicatePolicy.allCases
        let rawValues = cases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, cases.count)
    }

    func test_storagePolicy_defaults_areCorrect() {
        let policy = StoragePolicy.default
        XCTAssertEqual(policy.duplicatePolicy, .reject)
        XCTAssertTrue(policy.checksumEnabled)
        XCTAssertNil(policy.nearLineMigrationAgeDays)
        XCTAssertFalse(policy.zipOnArchive)
    }

    func test_storagePolicy_customValues_arePreserved() {
        let policy = StoragePolicy(
            duplicatePolicy: .overwrite,
            checksumEnabled: false,
            nearLineMigrationAgeDays: 30,
            zipOnArchive: true
        )
        XCTAssertEqual(policy.duplicatePolicy, .overwrite)
        XCTAssertFalse(policy.checksumEnabled)
        XCTAssertEqual(policy.nearLineMigrationAgeDays, 30)
        XCTAssertTrue(policy.zipOnArchive)
    }

    func test_storagePolicy_codable_roundTrips() throws {
        let original = StoragePolicy(
            duplicatePolicy: .keepBoth,
            checksumEnabled: true,
            nearLineMigrationAgeDays: 90,
            zipOnArchive: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StoragePolicy.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_storagePolicy_equatable() {
        XCTAssertEqual(StoragePolicy.default, StoragePolicy.default)
        let a = StoragePolicy(duplicatePolicy: .reject)
        let b = StoragePolicy(duplicatePolicy: .overwrite)
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - StorageActor Tests

final class StorageActorTests: XCTestCase {

    private func makeActor(in directory: String) -> StorageActor {
        StorageActor(
            archivePath: directory,
            checksumEnabled: true,
            logger: MayamLogger(label: "test.storage")
        )
    }

    func test_storageActor_validateArchivePath_succeeds_whenDirectoryExists() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_actor_test_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let actor = makeActor(in: tmp)
        // Validation should succeed — if it throws the test will fail automatically
        try await actor.validateArchivePath()
    }

    func test_storageActor_validateArchivePath_throws_whenPathMissing() async throws {
        let actor = makeActor(in: "/nonexistent/path/\(UUID().uuidString)")
        do {
            try await actor.validateArchivePath()
            XCTFail("Expected archivePathNotFound")
        } catch let error as MayamCore.StorageError {
            if case .archivePathNotFound = error { /* expected */ }
            else { XCTFail("Wrong error: \(error)") }
        }
    }

    func test_storageActor_store_writesFileToDisk() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_store_test_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let actor = makeActor(in: tmp)
        let testData = Data("DICOM test payload".utf8)
        let policy = StoragePolicy(duplicatePolicy: .reject, checksumEnabled: true)

        let stored = try await actor.store(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            patientID: "PAT001",
            studyInstanceUID: "1.2.3",
            seriesInstanceUID: "1.2.3.4",
            dataSet: testData,
            policy: policy
        )

        XCTAssertEqual(stored.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(stored.transferSyntaxUID, "1.2.840.10008.1.2.1")
        XCTAssertNotNil(stored.checksumSHA256)
        XCTAssertEqual(stored.fileSizeBytes, Int64(testData.count))

        // Verify file exists on disk
        let fullPath = tmp + "/" + stored.filePath
        XCTAssertTrue(FileManager.default.fileExists(atPath: fullPath))

        // Verify file content
        let readBack = try Data(contentsOf: URL(fileURLWithPath: fullPath))
        XCTAssertEqual(readBack, testData)
    }

    func test_storageActor_store_computesChecksumCorrectly() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_checksum_test_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let actor = makeActor(in: tmp)
        let testData = Data("CHECKSUM TEST".utf8)
        let policy = StoragePolicy(checksumEnabled: true)

        let stored = try await actor.store(
            sopInstanceUID: "1.2.3.4.6",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            dataSet: testData,
            policy: policy
        )

        // SHA-256 checksum should be a 64-character hex string
        let checksum = try XCTUnwrap(stored.checksumSHA256)
        XCTAssertEqual(checksum.count, 64)
        XCTAssertTrue(checksum.allSatisfy { $0.isHexDigit })
    }

    func test_storageActor_store_noChecksum_whenDisabled() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_nochecksum_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let actor = makeActor(in: tmp)
        let policy = StoragePolicy(checksumEnabled: false)

        let stored = try await actor.store(
            sopInstanceUID: "1.2.3.4.7",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            dataSet: Data("test".utf8),
            policy: policy
        )

        XCTAssertNil(stored.checksumSHA256)
    }

    func test_storageActor_duplicateReject_throwsDuplicateError() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_dup_reject_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let actor = makeActor(in: tmp)
        let policy = StoragePolicy(duplicatePolicy: .reject)
        let uid = "1.2.3.4.8"

        // First store should succeed
        try await actor.store(
            sopInstanceUID: uid,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            dataSet: Data("first".utf8),
            policy: policy
        )

        // Second store with same UID should throw
        do {
            try await actor.store(
                sopInstanceUID: uid,
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                transferSyntaxUID: "1.2.840.10008.1.2.1",
                dataSet: Data("second".utf8),
                policy: policy
            )
            XCTFail("Expected duplicateInstance error")
        } catch let error as MayamCore.StorageError {
            if case .duplicateInstance(sopInstanceUID: let dupeUID) = error {
                XCTAssertEqual(dupeUID, uid)
            } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    func test_storageActor_duplicateOverwrite_succeeds() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_dup_overwrite_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let actor = makeActor(in: tmp)
        let policy = StoragePolicy(duplicatePolicy: .overwrite)
        let uid = "1.2.3.4.9"

        let first = try await actor.store(
            sopInstanceUID: uid,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            dataSet: Data("first".utf8),
            policy: policy
        )

        let second = try await actor.store(
            sopInstanceUID: uid,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            dataSet: Data("second".utf8),
            policy: policy
        )

        XCTAssertEqual(first.filePath, second.filePath)
        XCTAssertNotEqual(first.checksumSHA256, second.checksumSHA256)
    }

    func test_storageActor_duplicateKeepBoth_storesBothFiles() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_dup_keepboth_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let actor = makeActor(in: tmp)
        let policy = StoragePolicy(duplicatePolicy: .keepBoth)
        let uid = "1.2.3.4.10"

        let first = try await actor.store(
            sopInstanceUID: uid,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            dataSet: Data("first".utf8),
            policy: policy
        )
        let second = try await actor.store(
            sopInstanceUID: uid,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            dataSet: Data("second".utf8),
            policy: policy
        )

        // Both should exist on disk
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp + "/" + first.filePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp + "/" + second.filePath))
        XCTAssertNotEqual(first.filePath, second.filePath)
    }

    func test_storageActor_instanceExists_returnsTrueAfterStore() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_exists_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let actor = makeActor(in: tmp)
        let uid = "1.2.3.4.11"

        let existsBefore = await actor.instanceExists(sopInstanceUID: uid)
        XCTAssertFalse(existsBefore)

        try await actor.store(
            sopInstanceUID: uid,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            dataSet: Data("test".utf8),
            policy: .default
        )

        let existsAfter = await actor.instanceExists(sopInstanceUID: uid)
        XCTAssertTrue(existsAfter)
    }

    func test_storageActor_getStoredObjectCount_incrementsAfterStore() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_count_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let actor = makeActor(in: tmp)
        let countBefore = await actor.getStoredObjectCount()
        XCTAssertEqual(countBefore, 0)

        try await actor.store(
            sopInstanceUID: "1.2.3.4.20",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            dataSet: Data("a".utf8),
            policy: .default
        )

        let countAfter = await actor.getStoredObjectCount()
        XCTAssertEqual(countAfter, 1)
    }
}

// MARK: - StorageError Tests

final class StorageErrorTests: XCTestCase {

    func test_archivePathNotFound_description() {
        let err = StorageError.archivePathNotFound(path: "/missing")
        XCTAssertTrue(err.description.contains("/missing"))
    }

    func test_archivePathNotWritable_description() {
        let err = StorageError.archivePathNotWritable(path: "/readonly")
        XCTAssertTrue(err.description.contains("/readonly"))
    }

    func test_duplicateInstance_description() {
        let err = StorageError.duplicateInstance(sopInstanceUID: "1.2.3")
        XCTAssertTrue(err.description.contains("1.2.3"))
    }

    func test_writeFailed_description() {
        let err = StorageError.writeFailed(path: "/bad/path", underlying: NSError(domain: "test", code: 1))
        XCTAssertTrue(err.description.contains("/bad/path"))
    }
}

// MARK: - StoredInstance Tests

final class StoredInstanceTests: XCTestCase {

    func test_storedInstance_properties_arePreserved() {
        let instance = StoredInstance(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            filePath: "PAT/STU/SER/SOP.dcm",
            fileSizeBytes: 1024,
            checksumSHA256: "abc123"
        )

        XCTAssertEqual(instance.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(instance.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(instance.transferSyntaxUID, "1.2.840.10008.1.2.1")
        XCTAssertEqual(instance.filePath, "PAT/STU/SER/SOP.dcm")
        XCTAssertEqual(instance.fileSizeBytes, 1024)
        XCTAssertEqual(instance.checksumSHA256, "abc123")
    }
}

// MARK: - Series Model Tests

final class SeriesModelTests: XCTestCase {

    func test_series_properties_arePreserved() {
        let series = Series(
            id: 1,
            seriesInstanceUID: "1.2.3.4",
            studyID: 42,
            seriesNumber: 3,
            modality: "CT",
            seriesDescription: "Chest CT",
            instanceCount: 120
        )

        XCTAssertEqual(series.id, 1)
        XCTAssertEqual(series.seriesInstanceUID, "1.2.3.4")
        XCTAssertEqual(series.studyID, 42)
        XCTAssertEqual(series.seriesNumber, 3)
        XCTAssertEqual(series.modality, "CT")
        XCTAssertEqual(series.seriesDescription, "Chest CT")
        XCTAssertEqual(series.instanceCount, 120)
    }

    func test_series_codable_roundTrips() throws {
        let original = Series(
            seriesInstanceUID: "1.2.3.4",
            studyID: 1,
            modality: "MR",
            instanceCount: 36
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Series.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - Instance Model Tests

final class InstanceModelTests: XCTestCase {

    func test_instance_properties_arePreserved() {
        let instance = Instance(
            id: 5,
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            seriesID: 10,
            instanceNumber: 1,
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            checksumSHA256: "deadbeef",
            fileSizeBytes: 2048,
            filePath: "PAT/STU/SER/SOP.dcm",
            callingAETitle: "MODALITY_AE"
        )

        XCTAssertEqual(instance.id, 5)
        XCTAssertEqual(instance.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(instance.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(instance.seriesID, 10)
        XCTAssertEqual(instance.transferSyntaxUID, "1.2.840.10008.1.2.1")
        XCTAssertEqual(instance.checksumSHA256, "deadbeef")
        XCTAssertEqual(instance.fileSizeBytes, 2048)
        XCTAssertEqual(instance.callingAETitle, "MODALITY_AE")
    }

    func test_instance_codable_roundTrips() throws {
        let original = Instance(
            sopInstanceUID: "1.2.3.4.5",
            sopClassUID: "1.2.840.10008.5.1.4.1.1.4",
            seriesID: 1,
            transferSyntaxUID: "1.2.840.10008.1.2",
            fileSizeBytes: 512,
            filePath: "P/S/SE/I.dcm"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Instance.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ProtectionFlagAudit Tests

final class ProtectionFlagAuditTests: XCTestCase {

    func test_protectionFlagAudit_properties_arePreserved() {
        let audit = ProtectionFlagAudit(
            id: 1,
            entityType: .study,
            entityID: 42,
            flagName: .deleteProtect,
            oldValue: false,
            newValue: true,
            changedBy: "admin",
            reason: "Legal hold"
        )

        XCTAssertEqual(audit.entityType, .study)
        XCTAssertEqual(audit.entityID, 42)
        XCTAssertEqual(audit.flagName, .deleteProtect)
        XCTAssertFalse(audit.oldValue)
        XCTAssertTrue(audit.newValue)
        XCTAssertEqual(audit.changedBy, "admin")
        XCTAssertEqual(audit.reason, "Legal hold")
    }

    func test_protectionFlagAudit_codable_roundTrips() throws {
        let original = ProtectionFlagAudit(
            entityType: .patient,
            entityID: 1,
            flagName: .privacyFlag,
            oldValue: false,
            newValue: true,
            changedBy: "system",
            reason: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProtectionFlagAudit.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_entityType_rawValues_areDistinct() {
        let cases = ProtectionFlagAudit.EntityType.allCases
        XCTAssertEqual(Set(cases.map(\.rawValue)).count, cases.count)
    }

    func test_flagName_rawValues_matchDatabaseColumns() {
        XCTAssertEqual(ProtectionFlagAudit.FlagName.deleteProtect.rawValue, "delete_protect")
        XCTAssertEqual(ProtectionFlagAudit.FlagName.privacyFlag.rawValue, "privacy_flag")
    }
}

// MARK: - StorageSCP Tests

final class StorageSCPTests: XCTestCase {

    private func makeActor(in directory: String) -> StorageActor {
        StorageActor(
            archivePath: directory,
            checksumEnabled: true,
            logger: MayamLogger(label: "test.storage.scp")
        )
    }

    func test_storageSCP_supportedSOPClasses_containsCT() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        let actor = makeActor(in: tmp)
        let scp = StorageSCP(
            storageActor: actor,
            logger: Logger(label: "test")
        )
        XCTAssertTrue(scp.supportedSOPClassUIDs.contains("1.2.840.10008.5.1.4.1.1.2"))
    }

    func test_storageSCP_handleCStore_emptyUID_returnsFailure() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let actor = makeActor(in: tmp)
        let scp = StorageSCP(storageActor: actor, logger: Logger(label: "test"))

        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "",
            affectedSOPInstanceUID: "",
            presentationContextID: 1
        )

        let response = await scp.handleCStore(
            request: request,
            dataSet: Data(),
            transferSyntax: "1.2.840.10008.1.2.1",
            presentationContextID: 1
        )

        XCTAssertFalse(response.status.isSuccess)
    }

    func test_storageSCP_handleCStore_success() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let actor = makeActor(in: tmp)
        let policy = StoragePolicy(duplicatePolicy: .reject)
        let scp2 = StorageSCP(storageActor: actor, policy: policy, logger: Logger(label: "test"))

        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5",
            presentationContextID: 1
        )

        let response = await scp2.handleCStore(
            request: request,
            dataSet: Data("DICOM".utf8),
            transferSyntax: "1.2.840.10008.1.2.1",
            presentationContextID: 1
        )

        XCTAssertTrue(response.status.isSuccess)
        XCTAssertEqual(response.messageIDBeingRespondedTo, 1)
    }

    func test_storageSCP_handleCStore_duplicate_returnsFailure() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let actor = makeActor(in: tmp)
        let policy = StoragePolicy(duplicatePolicy: .reject)
        let scp = StorageSCP(storageActor: actor, policy: policy, logger: Logger(label: "test"))

        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5",
            presentationContextID: 1
        )

        // First store
        _ = await scp.handleCStore(
            request: request,
            dataSet: Data("first".utf8),
            transferSyntax: "1.2.840.10008.1.2.1",
            presentationContextID: 1
        )

        // Duplicate store should fail
        let response = await scp.handleCStore(
            request: request,
            dataSet: Data("second".utf8),
            transferSyntax: "1.2.840.10008.1.2.1",
            presentationContextID: 1
        )

        XCTAssertFalse(response.status.isSuccess)
    }
}

// MARK: - SCPDispatcher C-STORE Tests

final class SCPDispatcherCStoreTests: XCTestCase {

    func test_scpDispatcher_handleCStore_noStorageSCP_returnsFailure() async {
        let dispatcher = SCPDispatcher()

        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5",
            presentationContextID: 1
        )

        let response = await dispatcher.handleCStore(
            request: request,
            dataSet: Data("test".utf8),
            transferSyntax: "1.2.840.10008.1.2.1",
            presentationContextID: 1
        )

        XCTAssertFalse(response.status.isSuccess)
    }

    func test_scpDispatcher_withStorageSCP_routesToStorageSCP() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        let actor = StorageActor(
            archivePath: tmp,
            checksumEnabled: false,
            logger: MayamLogger(label: "test")
        )
        let storageSCP = StorageSCP(storageActor: actor, logger: Logger(label: "test"))
        let dispatcher = SCPDispatcher(storageSCP: storageSCP)

        let request = CStoreRequest(
            messageID: 1,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.99",
            presentationContextID: 1
        )

        let response = await dispatcher.handleCStore(
            request: request,
            dataSet: Data("DICOM".utf8),
            transferSyntax: "1.2.840.10008.1.2.1",
            presentationContextID: 1
        )

        XCTAssertTrue(response.status.isSuccess)
    }
}

// MARK: - StoreSCUResult Tests

final class StoreSCUResultTests: XCTestCase {

    func test_storeSCUResult_properties_arePreserved() {
        let result = StoreSCUResult(
            success: true,
            status: .success,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5",
            roundTripTime: 0.05,
            remoteAETitle: "REMOTE",
            host: "192.168.1.1",
            port: 11112
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.sopClassUID, "1.2.840.10008.5.1.4.1.1.2")
        XCTAssertEqual(result.sopInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(result.remoteAETitle, "REMOTE")
        XCTAssertEqual(result.port, 11112)
    }

    func test_storeSCUResult_description_containsStatus() {
        let success = StoreSCUResult(
            success: true,
            status: .success,
            sopClassUID: "1.2.3",
            sopInstanceUID: "1.2.3.4",
            roundTripTime: 0.1,
            remoteAETitle: "AE",
            host: "localhost",
            port: 11112
        )
        XCTAssertTrue(success.description.contains("SUCCESS"))

        let failure = StoreSCUResult(
            success: false,
            status: .failedUnableToProcess,
            sopClassUID: "1.2.3",
            sopInstanceUID: "1.2.3.4",
            roundTripTime: 0.1,
            remoteAETitle: "AE",
            host: "localhost",
            port: 11112
        )
        XCTAssertTrue(failure.description.contains("FAILED"))
    }
}

// MARK: - DICOMListenerConfiguration Storage SOP Classes Tests

final class DICOMListenerConfigurationStorageTests: XCTestCase {

    func test_listenerConfiguration_defaultSOPClasses_includesStorageSOPClasses() {
        let classes = DICOMListenerConfiguration.defaultAcceptedSOPClasses
        // Verification
        XCTAssertTrue(classes.contains("1.2.840.10008.1.1"))
        // CT Image Storage
        XCTAssertTrue(classes.contains("1.2.840.10008.5.1.4.1.1.2"))
        // MR Image Storage
        XCTAssertTrue(classes.contains("1.2.840.10008.5.1.4.1.1.4"))
        // CR Image Storage
        XCTAssertTrue(classes.contains("1.2.840.10008.5.1.4.1.1.1"))
    }

    func test_listenerConfiguration_defaultTransferSyntaxes_includesAllCoreSet() {
        let syntaxes = DICOMListenerConfiguration.defaultAcceptedTransferSyntaxes
        // Implicit VR Little Endian
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2"))
        // Explicit VR Little Endian
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.1"))
        // Deflated Explicit VR Little Endian
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.1.99"))
        // RLE Lossless
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.5"))
    }
}

// MARK: - ServerConfiguration Storage Policy Tests

final class ServerConfigurationStoragePolicyTests: XCTestCase {

    func test_storageConfig_defaults_includePolicy() {
        let config = ServerConfiguration.Storage()
        XCTAssertEqual(config.policy.duplicatePolicy, .reject)
        XCTAssertTrue(config.policy.checksumEnabled)
    }

    func test_storageConfig_codable_roundTrips_withPolicy() throws {
        let original = ServerConfiguration.Storage(
            archivePath: "/data/archive",
            checksumEnabled: true,
            policy: StoragePolicy(
                duplicatePolicy: .keepBoth,
                checksumEnabled: true,
                nearLineMigrationAgeDays: 60,
                zipOnArchive: true
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerConfiguration.Storage.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - C-STORE Integration Test

final class CStoreIntegrationTests: XCTestCase {

    func test_cStoreSCPSCU_endToEnd_succeeds() async throws {
        // Set up temporary archive directory
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_cstore_integration_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        // Create storage actor and SCP
        let storageActor = StorageActor(
            archivePath: tmp,
            checksumEnabled: true,
            logger: MayamLogger(label: "test.storage")
        )
        let storageSCP = StorageSCP(
            storageActor: storageActor,
            policy: StoragePolicy(duplicatePolicy: .reject),
            logger: Logger(label: "test.storage.scp")
        )
        let dispatcher = SCPDispatcher(storageSCP: storageSCP)

        // Configure listener with storage SOP classes
        let config = DICOMListenerConfiguration(aeTitle: "TEST_SCP", port: 0)
        let logger = Logger(label: "test.integration.cstore")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)

        let listener = DICOMListener(
            configuration: config,
            dispatcher: dispatcher,
            logger: logger,
            eventLoopGroup: eventLoopGroup
        )

        try await listener.start()

        guard let port = await listener.localPort() else {
            XCTFail("Failed to get bound port")
            await listener.stop()
            try await eventLoopGroup.shutdownGracefully()
            return
        }

        // Send a C-STORE request using the SCU
        let scu = StorageSCU(logger: logger)
        let testData = Data("DICOM object payload".utf8)

        let result = try await scu.store(
            dataSet: testData,
            sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
            sopInstanceUID: "1.2.3.4.5.6.7.8",
            transferSyntaxUID: "1.2.840.10008.1.2.1",
            host: "127.0.0.1",
            port: port,
            callingAE: "TEST_SCU",
            calledAE: "TEST_SCP",
            timeout: 10
        )

        XCTAssertTrue(result.success, "C-STORE should succeed against local SCP")
        XCTAssertEqual(result.sopInstanceUID, "1.2.3.4.5.6.7.8")
        XCTAssertEqual(result.remoteAETitle, "TEST_SCP")
        XCTAssertGreaterThan(result.roundTripTime, 0)

        // Verify the file was stored on disk
        let storedCount = await storageActor.getStoredObjectCount()
        XCTAssertEqual(storedCount, 1)

        // Clean up
        await listener.stop()
        try await eventLoopGroup.shutdownGracefully()
    }

    func test_cStoreSCU_wrongCalledAE_fails() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam_cstore_wrongae_\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)

        let storageActor = StorageActor(
            archivePath: tmp,
            checksumEnabled: false,
            logger: MayamLogger(label: "test.storage")
        )
        let storageSCP = StorageSCP(storageActor: storageActor, logger: Logger(label: "test"))
        let dispatcher = SCPDispatcher(storageSCP: storageSCP)

        let config = DICOMListenerConfiguration(aeTitle: "REAL_SCP", port: 0)
        let logger = Logger(label: "test.integration.cstore.wrongae")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)

        let listener = DICOMListener(
            configuration: config,
            dispatcher: dispatcher,
            logger: logger,
            eventLoopGroup: eventLoopGroup
        )

        try await listener.start()
        guard let port = await listener.localPort() else {
            await listener.stop()
            try await eventLoopGroup.shutdownGracefully()
            XCTFail("Port not found")
            return
        }

        let scu = StorageSCU(logger: logger)

        do {
            let result = try await scu.store(
                dataSet: Data("test".utf8),
                sopClassUID: "1.2.840.10008.5.1.4.1.1.2",
                sopInstanceUID: "1.2.3.4.5",
                transferSyntaxUID: "1.2.840.10008.1.2.1",
                host: "127.0.0.1",
                port: port,
                callingAE: "SCU",
                calledAE: "WRONG_SCP",  // Intentionally wrong
                timeout: 10
            )
            XCTAssertFalse(result.success, "Store with wrong AE should fail")
        } catch {
            // An error is also an acceptable outcome for a rejected association
        }

        await listener.stop()
        try await eventLoopGroup.shutdownGracefully()
    }
}
