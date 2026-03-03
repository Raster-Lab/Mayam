// SPDX-License-Identifier: (see LICENSE)
// Mayam — Main Entry Point

import MayamCore
import MayamWeb
import Foundation

/// Mayam application entry point.
///
/// Loads the server configuration, initialises the logging subsystem, runs
/// pending database migrations, and starts the DICOM association listener,
/// DICOMweb HTTP server, and Admin console.  Installs signal handlers for
/// graceful shutdown with in-flight association draining.
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

        // Run automated database migrations
        let migrationLogger = MayamLogger(label: "com.raster-lab.mayam.migrations")
        let migrator = DatabaseMigrator(logger: migrationLogger)
        do {
            let allMigrations = try migrator.discoverMigrations()
            let pending = migrator.pendingMigrations(from: allMigrations)
            if !pending.isEmpty {
                logger.info("Found \(pending.count) pending migration(s)")
                let applied = migrator.applyPendingMigrations(pending)
                logger.info("Applied \(applied.count) migration(s)")
            } else {
                logger.info("Database schema is up to date")
            }
        } catch {
            logger.warning("Database migration discovery failed: \(error) — continuing startup")
        }

        // Initialise metrics and health subsystems
        let metricsCollector = MetricsCollector.shared

        // Initialise the shared metadata store and storage actor
        let metadataStore = InMemoryDICOMMetadataStore()
        let storageActor = StorageActor(
            archivePath: config.storage.archivePath,
            checksumEnabled: config.storage.checksumEnabled,
            logger: MayamLogger(label: "com.raster-lab.mayam.storage")
        )

        // Create metrics and health handlers
        let metricsHandler = MetricsHandler(metricsCollector: metricsCollector)
        let healthChecker = HealthChecker(
            metricsCollector: metricsCollector,
            archivePath: config.storage.archivePath
        )
        let healthHandler = HealthHandler(healthChecker: healthChecker)

        // Initialise the DICOMweb HTTP server
        let webServer = DICOMwebServer(
            configuration: config.web,
            metadataStore: metadataStore,
            storageActor: storageActor,
            archivePath: config.storage.archivePath,
            logger: MayamLogger(label: "com.raster-lab.mayam.web"),
            metricsHandler: metricsHandler,
            healthHandler: healthHandler
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

        // Install graceful shutdown signal handlers
        let shutdown = GracefulShutdown()
        shutdown.installSignalHandlers()

        // Start DICOM listener and graceful shutdown monitor concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await server.start()
            }

            group.addTask {
                for await _ in shutdown.shutdownSignals() {
                    logger.info("Shutdown signal received — draining in-flight associations…")
                    await server.shutdown()
                    await webServer.stop()
                    await adminServer.stop()
                    logger.info("All services stopped — exiting")
                }
            }

            try await group.next()
        }
    }
}

