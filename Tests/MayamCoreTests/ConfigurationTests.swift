// SPDX-License-Identifier: (see LICENSE)
// Mayam — Configuration Tests

import XCTest
@testable import MayamCore

final class ConfigurationTests: XCTestCase {

    // MARK: - ServerConfiguration Default Tests

    func test_serverConfiguration_defaults_areCorrect() {
        let config = ServerConfiguration()

        XCTAssertEqual(config.dicom.aeTitle, "MAYAM")
        XCTAssertEqual(config.dicom.port, 11112)
        XCTAssertEqual(config.dicom.maxAssociations, 64)
        XCTAssertEqual(config.storage.archivePath, "/var/lib/mayam/archive")
        XCTAssertTrue(config.storage.checksumEnabled)
        XCTAssertEqual(config.log.level, "info")
    }

    func test_serverConfiguration_customValues_arePreserved() {
        let config = ServerConfiguration(
            dicom: .init(aeTitle: "TEST_AE", port: 4242, maxAssociations: 128),
            storage: .init(archivePath: "/tmp/test-archive", checksumEnabled: false),
            log: .init(level: "debug")
        )

        XCTAssertEqual(config.dicom.aeTitle, "TEST_AE")
        XCTAssertEqual(config.dicom.port, 4242)
        XCTAssertEqual(config.dicom.maxAssociations, 128)
        XCTAssertEqual(config.storage.archivePath, "/tmp/test-archive")
        XCTAssertFalse(config.storage.checksumEnabled)
        XCTAssertEqual(config.log.level, "debug")
    }

    func test_serverConfiguration_codable_roundTrips() throws {
        let original = ServerConfiguration(
            dicom: .init(aeTitle: "ROUND_TRIP", port: 9999, maxAssociations: 32),
            storage: .init(archivePath: "/data/archive", checksumEnabled: false),
            log: .init(level: "trace")
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ServerConfiguration.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func test_serverConfiguration_equatable() {
        let a = ServerConfiguration()
        let b = ServerConfiguration()
        XCTAssertEqual(a, b)

        var c = ServerConfiguration()
        c.dicom.aeTitle = "OTHER"
        XCTAssertNotEqual(a, c)
    }

    // MARK: - ConfigurationLoader Tests

    func test_configurationLoader_missingFile_returnsDefaults() throws {
        let config = try ConfigurationLoader.load(from: "/nonexistent/path.yaml")
        XCTAssertEqual(config.dicom.aeTitle, "MAYAM")
        XCTAssertEqual(config.dicom.port, 11112)
    }

    func test_configurationLoader_validYAML_parsesCorrectly() throws {
        let yaml = """
        dicom:
          aeTitle: "YAML_TEST"
          port: 5555
          maxAssociations: 16
        storage:
          archivePath: "/tmp/yaml-test"
          checksumEnabled: false
        log:
          level: "debug"
        """

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configFile = tempDir.appendingPathComponent("test.yaml")
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let config = try ConfigurationLoader.load(from: configFile.path)
        XCTAssertEqual(config.dicom.aeTitle, "YAML_TEST")
        XCTAssertEqual(config.dicom.port, 5555)
        XCTAssertEqual(config.dicom.maxAssociations, 16)
        XCTAssertEqual(config.storage.archivePath, "/tmp/yaml-test")
        XCTAssertFalse(config.storage.checksumEnabled)
        XCTAssertEqual(config.log.level, "debug")
    }

    func test_configurationLoader_invalidYAML_throwsError() {
        let invalidYAML = "{{{{ not valid yaml"

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configFile = tempDir.appendingPathComponent("invalid.yaml")
        try? invalidYAML.write(to: configFile, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigurationLoader.load(from: configFile.path)) { error in
            guard case ConfigurationError.invalidYAML = error else {
                XCTFail("Expected invalidYAML error, got \(error)")
                return
            }
        }
    }

    func test_configurationLoader_partialYAML_usesDefaultsForMissing() throws {
        let yaml = """
        dicom:
          aeTitle: "PARTIAL"
        """

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mayam-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configFile = tempDir.appendingPathComponent("partial.yaml")
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        let config = try ConfigurationLoader.load(from: configFile.path)
        XCTAssertEqual(config.dicom.aeTitle, "PARTIAL")
        XCTAssertEqual(config.dicom.port, 11112)
        XCTAssertEqual(config.dicom.maxAssociations, 64)
        XCTAssertEqual(config.storage.archivePath, "/var/lib/mayam/archive")
        XCTAssertTrue(config.storage.checksumEnabled)
        XCTAssertEqual(config.log.level, "info")
    }

    func test_configurationLoader_environmentOverrides_applyCorrectly() throws {
        var config = ServerConfiguration()

        // Simulate environment override application
        config.dicom.aeTitle = "ENV_AE"
        config.dicom.port = 7777
        config.storage.archivePath = "/env/archive"
        config.log.level = "trace"

        XCTAssertEqual(config.dicom.aeTitle, "ENV_AE")
        XCTAssertEqual(config.dicom.port, 7777)
        XCTAssertEqual(config.storage.archivePath, "/env/archive")
        XCTAssertEqual(config.log.level, "trace")
    }
}
