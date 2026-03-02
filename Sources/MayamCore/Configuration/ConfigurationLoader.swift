// SPDX-License-Identifier: (see LICENSE)
// Mayam — YAML Configuration Loader

import Foundation
import Yams

/// Loads a ``ServerConfiguration`` from a YAML file on disk and applies any
/// environment variable overrides.
///
/// ## Configuration Resolution Order
/// 1. Built-in defaults (defined in ``ServerConfiguration``).
/// 2. YAML configuration file (default: `Config/mayam.yaml` or the path
///    specified by the `MAYAM_CONFIG` environment variable).
/// 3. Environment variable overrides (e.g. `MAYAM_DICOM_AE_TITLE`).
public enum ConfigurationLoader: Sendable {

    // MARK: - Public Methods

    /// Loads the server configuration.
    ///
    /// - Parameter path: Optional explicit path to a YAML file.  When `nil` the
    ///   loader checks the `MAYAM_CONFIG` environment variable and then falls
    ///   back to `Config/mayam.yaml`.
    /// - Returns: A fully resolved ``ServerConfiguration``.
    /// - Throws: ``ConfigurationError`` if the file cannot be read or parsed.
    public static func load(from path: String? = nil) throws -> ServerConfiguration {
        var config = try loadFromFile(path: path)
        applyEnvironmentOverrides(&config)
        return config
    }

    // MARK: - Internal Helpers

    /// Loads configuration from a YAML file, falling back to defaults when no
    /// file is found.
    static func loadFromFile(path: String?) throws -> ServerConfiguration {
        let resolvedPath = path
            ?? ProcessInfo.processInfo.environment["MAYAM_CONFIG"]
            ?? "Config/mayam.yaml"

        let url = URL(fileURLWithPath: resolvedPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            // No config file — return defaults.
            return ServerConfiguration()
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ConfigurationError.unreadableFile(path: resolvedPath, underlying: error)
        }

        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw ConfigurationError.invalidEncoding(path: resolvedPath)
        }

        do {
            let decoder = YAMLDecoder()
            return try decoder.decode(ServerConfiguration.self, from: yamlString)
        } catch {
            throw ConfigurationError.invalidYAML(path: resolvedPath, underlying: error)
        }
    }

    /// Applies environment variable overrides to the configuration.
    ///
    /// Supported environment variables:
    /// - `MAYAM_DICOM_AE_TITLE` → ``ServerConfiguration/DICOM/aeTitle``
    /// - `MAYAM_DICOM_PORT` → ``ServerConfiguration/DICOM/port``
    /// - `MAYAM_DICOM_MAX_ASSOCIATIONS` → ``ServerConfiguration/DICOM/maxAssociations``
    /// - `MAYAM_DICOM_TLS_ENABLED` → ``ServerConfiguration/DICOM/tlsEnabled``
    /// - `MAYAM_DICOM_TLS_CERTIFICATE_PATH` → ``ServerConfiguration/DICOM/tlsCertificatePath``
    /// - `MAYAM_DICOM_TLS_KEY_PATH` → ``ServerConfiguration/DICOM/tlsKeyPath``
    /// - `MAYAM_STORAGE_ARCHIVE_PATH` → ``ServerConfiguration/Storage/archivePath``
    /// - `MAYAM_STORAGE_CHECKSUM_ENABLED` → ``ServerConfiguration/Storage/checksumEnabled``
    /// - `MAYAM_LOG_LEVEL` → ``ServerConfiguration/Log/level``
    /// - `MAYAM_ADMIN_PORT` → ``ServerConfiguration/Admin/port``
    /// - `MAYAM_ADMIN_TLS_ENABLED` → ``ServerConfiguration/Admin/tlsEnabled``
    /// - `MAYAM_ADMIN_TLS_CERTIFICATE_PATH` → ``ServerConfiguration/Admin/tlsCertificatePath``
    /// - `MAYAM_ADMIN_TLS_KEY_PATH` → ``ServerConfiguration/Admin/tlsKeyPath``
    /// - `MAYAM_ADMIN_JWT_SECRET` → ``ServerConfiguration/Admin/jwtSecret``
    /// - `MAYAM_ADMIN_SESSION_EXPIRY_SECONDS` → ``ServerConfiguration/Admin/sessionExpirySeconds``
    static func applyEnvironmentOverrides(_ config: inout ServerConfiguration) {
        let env = ProcessInfo.processInfo.environment

        if let aeTitle = env["MAYAM_DICOM_AE_TITLE"] {
            config.dicom.aeTitle = aeTitle
        }
        if let portString = env["MAYAM_DICOM_PORT"], let port = Int(portString) {
            config.dicom.port = port
        }
        if let maxString = env["MAYAM_DICOM_MAX_ASSOCIATIONS"], let max = Int(maxString) {
            config.dicom.maxAssociations = max
        }
        if let tlsString = env["MAYAM_DICOM_TLS_ENABLED"] {
            config.dicom.tlsEnabled = tlsString.lowercased() == "true"
                || tlsString == "1"
        }
        if let certPath = env["MAYAM_DICOM_TLS_CERTIFICATE_PATH"] {
            config.dicom.tlsCertificatePath = certPath
        }
        if let keyPath = env["MAYAM_DICOM_TLS_KEY_PATH"] {
            config.dicom.tlsKeyPath = keyPath
        }
        if let archivePath = env["MAYAM_STORAGE_ARCHIVE_PATH"] {
            config.storage.archivePath = archivePath
        }
        if let checksumString = env["MAYAM_STORAGE_CHECKSUM_ENABLED"] {
            config.storage.checksumEnabled = checksumString.lowercased() == "true"
                || checksumString == "1"
        }
        if let logLevel = env["MAYAM_LOG_LEVEL"] {
            config.log.level = logLevel
        }
        if let portString = env["MAYAM_ADMIN_PORT"], let port = Int(portString) {
            config.admin.port = port
        }
        if let tlsString = env["MAYAM_ADMIN_TLS_ENABLED"] {
            config.admin.tlsEnabled = tlsString.lowercased() == "true" || tlsString == "1"
        }
        if let certPath = env["MAYAM_ADMIN_TLS_CERTIFICATE_PATH"] {
            config.admin.tlsCertificatePath = certPath
        }
        if let keyPath = env["MAYAM_ADMIN_TLS_KEY_PATH"] {
            config.admin.tlsKeyPath = keyPath
        }
        if let jwtSecret = env["MAYAM_ADMIN_JWT_SECRET"] {
            config.admin.jwtSecret = jwtSecret
        }
        if let expiryString = env["MAYAM_ADMIN_SESSION_EXPIRY_SECONDS"],
           let expiry = Int(expiryString) {
            config.admin.sessionExpirySeconds = expiry
        }
    }
}
