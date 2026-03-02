// SPDX-License-Identifier: (see LICENSE)
// Mayam — Actor Tests

import XCTest
@testable import MayamCore

final class ActorTests: XCTestCase {

    // MARK: - AssociationActor Tests

    func test_associationActor_initialState_isIdle() async {
        let actor = AssociationActor(remoteAETitle: "REMOTE", localAETitle: "MAYAM")

        let state = await actor.getState()
        XCTAssertEqual(state, .idle)
    }

    func test_associationActor_stateTransitions_followProtocol() async {
        let actor = AssociationActor(remoteAETitle: "REMOTE", localAETitle: "MAYAM")

        await actor.beginNegotiation()
        var state = await actor.getState()
        XCTAssertEqual(state, .negotiating)

        await actor.establish()
        state = await actor.getState()
        XCTAssertEqual(state, .established)

        await actor.release()
        state = await actor.getState()
        XCTAssertEqual(state, .releasing)

        await actor.close()
        state = await actor.getState()
        XCTAssertEqual(state, .closed)
    }

    func test_associationActor_properties_areCorrect() async {
        let actor = AssociationActor(remoteAETitle: "SCANNER1", localAETitle: "PACS")

        let remoteAE = await actor.remoteAETitle
        let localAE = await actor.localAETitle
        let id = await actor.id

        XCTAssertEqual(remoteAE, "SCANNER1")
        XCTAssertEqual(localAE, "PACS")
        XCTAssertNotNil(id)
    }

    func test_associationActor_uniqueIDs() async {
        let a = AssociationActor(remoteAETitle: "R", localAETitle: "L")
        let b = AssociationActor(remoteAETitle: "R", localAETitle: "L")

        let idA = await a.id
        let idB = await b.id
        XCTAssertNotEqual(idA, idB)
    }

    // MARK: - StorageActor Tests

    func test_storageActor_initialCount_isZero() async {
        let logger = MayamLogger(label: "test.storage")
        let actor = StorageActor(
            archivePath: "/tmp/test",
            checksumEnabled: true,
            logger: logger
        )

        let count = await actor.getStoredObjectCount()
        XCTAssertEqual(count, 0)
    }

    func test_storageActor_properties_areCorrect() async {
        let logger = MayamLogger(label: "test.storage")
        let actor = StorageActor(
            archivePath: "/data/archive",
            checksumEnabled: false,
            logger: logger
        )

        let path = await actor.archivePath
        let checksum = await actor.checksumEnabled
        XCTAssertEqual(path, "/data/archive")
        XCTAssertFalse(checksum)
    }

    func test_storageActor_validateArchivePath_validDirectory_succeeds() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let logger = MayamLogger(label: "test.storage")
        let actor = StorageActor(
            archivePath: tempDir.path,
            checksumEnabled: true,
            logger: logger
        )

        try await actor.validateArchivePath()
    }

    func test_storageActor_validateArchivePath_missingDirectory_throws() async {
        let logger = MayamLogger(label: "test.storage")
        let actor = StorageActor(
            archivePath: "/nonexistent/path/\(UUID().uuidString)",
            checksumEnabled: true,
            logger: logger
        )

        do {
            try await actor.validateArchivePath()
            XCTFail("Expected StorageError.archivePathNotFound")
        } catch {
            guard case StorageError.archivePathNotFound = error else {
                XCTFail("Expected archivePathNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - ServerActor Tests

    func test_serverActor_initialState_isNotRunning() async {
        let config = ServerConfiguration()
        let logger = MayamLogger(label: "test.server")
        let actor = ServerActor(configuration: config, logger: logger)

        let running = await actor.getIsRunning()
        XCTAssertFalse(running)
    }

    func test_serverActor_configuration_isPreserved() async {
        let config = ServerConfiguration(
            dicom: .init(aeTitle: "TEST_SRV", port: 8888)
        )
        let logger = MayamLogger(label: "test.server")
        let actor = ServerActor(configuration: config, logger: logger)

        let storedConfig = await actor.configuration
        XCTAssertEqual(storedConfig.dicom.aeTitle, "TEST_SRV")
        XCTAssertEqual(storedConfig.dicom.port, 8888)
    }

    func test_serverActor_activeAssociationCount_isInitiallyZero() async {
        let config = ServerConfiguration()
        let logger = MayamLogger(label: "test.server")
        let actor = ServerActor(configuration: config, logger: logger)

        let count = await actor.getActiveAssociationCount()
        XCTAssertEqual(count, 0)
    }

    func test_serverActor_shutdown_setsNotRunning() async {
        let config = ServerConfiguration()
        let logger = MayamLogger(label: "test.server")
        let actor = ServerActor(configuration: config, logger: logger)

        await actor.shutdown()
        let running = await actor.getIsRunning()
        XCTAssertFalse(running)
    }
}
