// SPDX-License-Identifier: (see LICENSE)
// Mayam — Association Actor

import Foundation

/// Manages a single DICOM association between Mayam and a remote
/// DICOM application entity.
///
/// Each inbound TCP connection produces one `AssociationActor`.  The actor
/// handles the DICOM Upper Layer Protocol (A-ASSOCIATE, A-RELEASE, A-ABORT)
/// and dispatches DIMSE commands to the appropriate service handlers.
///
/// ## Lifecycle
/// 1. **Negotiation** — receives and validates A-ASSOCIATE-RQ; replies with
///    A-ASSOCIATE-AC or A-ASSOCIATE-RJ.
/// 2. **Data Transfer** — routes P-DATA-TF PDUs to service class handlers
///    (C-ECHO, C-STORE, C-FIND, etc.).
/// 3. **Release** — processes A-RELEASE-RQ/RP or handles A-ABORT.
///
/// > Note: The actual protocol implementation is provided in Milestone 2.
/// > This actor defines the concurrency-safe skeleton.
public actor AssociationActor {

    // MARK: - Nested Types

    /// The current state of the association.
    public enum State: Sendable {
        /// Waiting for A-ASSOCIATE-RQ.
        case idle
        /// Association negotiation in progress.
        case negotiating
        /// Association established; data transfer is active.
        case established
        /// Association release in progress.
        case releasing
        /// Association has been closed.
        case closed
    }

    // MARK: - Stored Properties

    /// A unique identifier for this association.
    public let id: UUID

    /// The remote AE Title.
    public let remoteAETitle: String

    /// The local AE Title accepted for this association.
    public let localAETitle: String

    /// The current state of the association.
    private var state: State

    // MARK: - Initialiser

    /// Creates a new association actor.
    ///
    /// - Parameters:
    ///   - remoteAETitle: The AE Title of the remote peer.
    ///   - localAETitle: The AE Title of the local server.
    public init(remoteAETitle: String, localAETitle: String) {
        self.id = UUID()
        self.remoteAETitle = remoteAETitle
        self.localAETitle = localAETitle
        self.state = .idle
    }

    // MARK: - Public Methods

    /// Returns the current state of the association.
    public func getState() -> State {
        state
    }

    /// Transitions the association to the negotiating state.
    public func beginNegotiation() {
        state = .negotiating
    }

    /// Marks the association as established after successful negotiation.
    public func establish() {
        state = .established
    }

    /// Initiates the release sequence.
    public func release() {
        state = .releasing
    }

    /// Closes the association.
    public func close() {
        state = .closed
    }
}
