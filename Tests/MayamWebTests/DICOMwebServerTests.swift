// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOMweb Server Tests

import XCTest
@testable import MayamWeb
@testable import MayamCore

final class DICOMwebServerTests: XCTestCase {

    private var tempDir: String = ""

    override func setUp() {
        tempDir = NSTemporaryDirectory() + "mayam_server_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    // MARK: - Server Lifecycle

    func test_dicomwebServer_starts_bindsToPort() async throws {
        let config = ServerConfiguration.Web(port: 0)  // ephemeral port
        let store = InMemoryDICOMMetadataStore()
        let storageActor = StorageActor(
            archivePath: tempDir,
            checksumEnabled: false,
            logger: MayamLogger(label: "test.server")
        )
        let server = DICOMwebServer(
            configuration: config,
            metadataStore: store,
            storageActor: storageActor,
            archivePath: tempDir,
            logger: MayamLogger(label: "test.server.web")
        )

        try await server.start()
        let port = await server.localPort()
        XCTAssertNotNil(port, "Server should have a bound port after start()")
        XCTAssertGreaterThan(port ?? 0, 0, "Bound port should be positive")

        await server.stop()
    }

    func test_dicomwebServer_stop_closesServer() async throws {
        let config = ServerConfiguration.Web(port: 0)
        let store = InMemoryDICOMMetadataStore()
        let storageActor = StorageActor(
            archivePath: tempDir,
            checksumEnabled: false,
            logger: MayamLogger(label: "test.server")
        )
        let server = DICOMwebServer(
            configuration: config,
            metadataStore: store,
            storageActor: storageActor,
            archivePath: tempDir,
            logger: MayamLogger(label: "test.server.web")
        )

        try await server.start()
        await server.stop()

        let port = await server.localPort()
        XCTAssertNil(port, "Port should be nil after stop()")
    }

    // MARK: - ServerConfiguration.Web

    func test_serverConfigurationWeb_defaults() {
        let web = ServerConfiguration.Web()
        XCTAssertEqual(web.port, 8080)
        XCTAssertFalse(web.tlsEnabled)
        XCTAssertNil(web.tlsCertificatePath)
        XCTAssertNil(web.tlsKeyPath)
        XCTAssertEqual(web.basePath, "")
    }

    func test_serverConfigurationWeb_customValues() {
        let web = ServerConfiguration.Web(
            port: 443,
            tlsEnabled: true,
            tlsCertificatePath: "/etc/ssl/cert.pem",
            tlsKeyPath: "/etc/ssl/key.pem",
            basePath: "/dicomweb"
        )
        XCTAssertEqual(web.port, 443)
        XCTAssertTrue(web.tlsEnabled)
        XCTAssertEqual(web.tlsCertificatePath, "/etc/ssl/cert.pem")
        XCTAssertEqual(web.tlsKeyPath, "/etc/ssl/key.pem")
        XCTAssertEqual(web.basePath, "/dicomweb")
    }

    func test_serverConfiguration_hasWebSection() {
        let config = ServerConfiguration()
        XCTAssertEqual(config.web.port, 8080)
    }
}
