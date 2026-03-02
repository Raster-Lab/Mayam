// SPDX-License-Identifier: (see LICENSE)
// Mayam Server — Server Actor

import Logging

/// The top-level server actor that coordinates all PACS subsystems.
///
/// `ServerActor` owns the lifecycle of the DICOM listener, manages the pool of
/// ``AssociationActor`` instances, and coordinates the ``StorageActor`` for
/// persistent object management.
///
/// ## Architecture
///
/// ```
/// ServerActor
/// ├── DICOMListener (Swift NIO TCP listener)
/// │   └── DICOMAssociationHandler (one per active association)
/// └── StorageActor (singleton, manages archive I/O)
/// ```
///
/// All mutable server state is isolated within this actor, eliminating data
/// races under Swift strict concurrency.
public actor ServerActor {

    // MARK: - Stored Properties

    /// The server configuration.
    public let configuration: ServerConfiguration

    /// Logger for server-level events.
    private let logger: MayamLogger

    /// The storage actor for managing DICOM object persistence.
    private let storageActor: StorageActor

    /// The DICOM TCP listener for inbound associations.
    private var dicomListener: DICOMListener?

    /// Tracks whether the server is currently running.
    private var isRunning: Bool = false

    /// The number of active DICOM associations.
    private var activeAssociationCount: Int = 0

    // MARK: - Initialiser

    /// Creates a new server actor with the given configuration.
    ///
    /// - Parameters:
    ///   - configuration: The server configuration.
    ///   - logger: The logger instance for server events.
    public init(configuration: ServerConfiguration, logger: MayamLogger) {
        self.configuration = configuration
        self.logger = logger
        self.storageActor = StorageActor(
            archivePath: configuration.storage.archivePath,
            checksumEnabled: configuration.storage.checksumEnabled,
            logger: MayamLogger(label: "com.raster-lab.mayam.storage")
        )
    }

    // MARK: - Public Methods

    /// Starts the PACS server.
    ///
    /// This method initialises the DICOM TCP listener using Swift NIO and begins
    /// accepting inbound associations. It suspends until the server is shut down.
    ///
    /// - Throws: If the server cannot bind to the configured port.
    public func start() async throws {
        guard !isRunning else {
            logger.warning("Server is already running")
            return
        }

        isRunning = true
        logger.info("Server started on port \(configuration.dicom.port) with AE Title '\(configuration.dicom.aeTitle)'")

        // Create the DICOM listener configuration from the server configuration
        let listenerConfig = DICOMListenerConfiguration(from: configuration)

        // Create and start the DICOM listener
        let listener = DICOMListener(
            configuration: listenerConfig,
            logger: logger.logger
        )
        self.dicomListener = listener

        try await listener.start()

        // Keep the server alive until explicitly stopped.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            _ = continuation
        }
    }

    /// Gracefully shuts down the server.
    ///
    /// Drains in-flight associations before closing the listener.
    public func shutdown() async {
        logger.info("Server shutting down…")

        if let listener = dicomListener {
            await listener.stop()
            try? await listener.shutdownEventLoopGroup()
            dicomListener = nil
        }

        isRunning = false
        logger.info("Server stopped")
    }

    /// Returns the current number of active DICOM associations.
    public func getActiveAssociationCount() -> Int {
        activeAssociationCount
    }

    /// Returns whether the server is currently running.
    public func getIsRunning() -> Bool {
        isRunning
    }
}
