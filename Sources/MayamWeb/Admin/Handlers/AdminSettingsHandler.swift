// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin Settings Handler

import Foundation
import MayamCore

// MARK: - AdminSettingsPayload

/// A subset of server configuration that can be inspected and updated via the
/// admin API.
///
/// This type mirrors the most commonly adjusted fields from
/// ``ServerConfiguration``.  Persistence to the YAML configuration file is a
/// future enhancement; changes made through this API are applied to the
/// in-memory configuration only and are lost on restart unless separately
/// persisted.
public struct AdminSettingsPayload: Codable, Sendable {
    /// The DICOM Application Entity Title.
    public let aeTitle: String
    /// TCP port for the DICOM listener.
    public let dicomPort: Int
    /// TCP port for the DICOMweb HTTP server.
    public let webPort: Int
    /// TCP port for the admin HTTP server.
    public let adminPort: Int
    /// Root path of the DICOM archive.
    public let archivePath: String
    /// Minimum log level string (e.g. `"info"`, `"debug"`).
    public let logLevel: String
    /// Whether SHA-256 integrity checksums are computed on ingest.
    public let checksumEnabled: Bool

    /// Creates a settings payload.
    public init(
        aeTitle: String,
        dicomPort: Int,
        webPort: Int,
        adminPort: Int,
        archivePath: String,
        logLevel: String,
        checksumEnabled: Bool
    ) {
        self.aeTitle = aeTitle
        self.dicomPort = dicomPort
        self.webPort = webPort
        self.adminPort = adminPort
        self.archivePath = archivePath
        self.logLevel = logLevel
        self.checksumEnabled = checksumEnabled
    }
}

// MARK: - AdminSettingsHandler

/// Manages the in-memory copy of admin-facing server settings.
///
/// Settings are initialised from the loaded ``ServerConfiguration`` and may be
/// updated at runtime via ``updateSettings(_:)``.  Changes are not persisted
/// to disk in the current implementation.
public actor AdminSettingsHandler {

    // MARK: - Stored Properties

    /// Current in-memory settings snapshot.
    private var current: AdminSettingsPayload

    // MARK: - Initialiser

    /// Creates a new settings handler from the current server configuration.
    ///
    /// - Parameters:
    ///   - configuration: The loaded server configuration.
    ///   - adminPort: The admin HTTP server port (sourced from
    ///     ``ServerConfiguration/Admin/port``).
    public init(configuration: ServerConfiguration, adminPort: Int) {
        self.current = AdminSettingsPayload(
            aeTitle: configuration.dicom.aeTitle,
            dicomPort: configuration.dicom.port,
            webPort: configuration.web.port,
            adminPort: adminPort,
            archivePath: configuration.storage.archivePath,
            logLevel: configuration.log.level,
            checksumEnabled: configuration.storage.checksumEnabled
        )
    }

    // MARK: - Public Methods

    /// Returns the current settings snapshot.
    ///
    /// - Returns: The current ``AdminSettingsPayload``.
    public func getSettings() -> AdminSettingsPayload {
        current
    }

    /// Replaces the in-memory settings with the provided values.
    ///
    /// - Parameter payload: The new settings to apply.
    /// - Returns: The updated ``AdminSettingsPayload``.
    @discardableResult
    public func updateSettings(_ payload: AdminSettingsPayload) -> AdminSettingsPayload {
        current = payload
        return current
    }
}
