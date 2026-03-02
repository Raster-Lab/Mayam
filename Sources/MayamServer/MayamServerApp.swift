// SPDX-License-Identifier: (see LICENSE)
// Mayam — Main Entry Point

import MayamCore
import MayamWeb
import Foundation

/// Mayam application entry point.
///
/// Loads the server configuration, initialises the logging subsystem, and starts
/// both the DICOM association listener and the DICOMweb HTTP server.
@main
struct MayamServerApp {
    static func main() async throws {
        // Initialise logging
        MayamLogger.bootstrap()
        let logger = MayamLogger(label: "com.raster-lab.mayam.server")

        logger.info("Mayam starting…")

        // Load configuration
        let config: ServerConfiguration
        do {
            config = try ConfigurationLoader.load()
            logger.info("Configuration loaded successfully")
        } catch {
            logger.error("Failed to load configuration: \(error)")
            throw error
        }

        logger.info("AE Title: \(config.dicom.aeTitle)")
        logger.info("DICOM port: \(config.dicom.port)")
        logger.info("DICOMweb port: \(config.web.port)")

        // Initialise the shared metadata store and storage actor
        let metadataStore = InMemoryDICOMMetadataStore()
        let storageActor = StorageActor(
            archivePath: config.storage.archivePath,
            checksumEnabled: config.storage.checksumEnabled,
            logger: MayamLogger(label: "com.raster-lab.mayam.storage")
        )

        // Initialise the DICOMweb HTTP server
        let webServer = DICOMwebServer(
            configuration: config.web,
            metadataStore: metadataStore,
            storageActor: storageActor,
            archivePath: config.storage.archivePath,
            logger: MayamLogger(label: "com.raster-lab.mayam.web")
        )

        // Start DICOMweb server
        do {
            try await webServer.start()
        } catch {
            logger.error("Failed to start DICOMweb server: \(error)")
            // Non-fatal: continue with DICOM listener
        }

        // Initialise and start the Admin console server
        let authHandler = AdminAuthHandler(
            jwtSecret: config.admin.jwtSecret,
            sessionExpirySeconds: config.admin.sessionExpirySeconds
        )
        let adminRouter = AdminRouter(
            auth: authHandler,
            dashboard: AdminDashboardHandler(),
            nodes: AdminNodeHandler(),
            storage: AdminStorageHandler(),
            logs: AdminLogHandler(),
            settings: AdminSettingsHandler(configuration: config, adminPort: config.admin.port),
            setup: AdminSetupHandler(),
            archivePath: config.storage.archivePath
        )
        let adminServer = AdminServer(
            configuration: config.admin,
            router: adminRouter,
            logger: MayamLogger(label: "com.raster-lab.mayam.admin")
        )
        do {
            try await adminServer.start()
            logger.info("Admin console started on port \(config.admin.port)")
        } catch {
            logger.error("Failed to start Admin console: \(error)")
        }

        // Initialise and start the DICOM server actor
        let server = ServerActor(configuration: config, logger: logger)
        try await server.start()
    }
}

