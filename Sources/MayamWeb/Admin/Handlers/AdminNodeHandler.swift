// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin DICOM Node Handler

import Foundation
import MayamCore

// MARK: - AdminNodeHandler

/// Manages the in-memory registry of remote DICOM AE nodes.
///
/// Provides CRUD operations on ``DicomNode`` records and a stub C-ECHO
/// verification method.  Persistence to a database is a future enhancement;
/// the current implementation stores nodes in memory only.
public actor AdminNodeHandler {

    // MARK: - Stored Properties

    /// In-memory node store keyed by node identifier.
    private var nodes: [UUID: DicomNode]

    // MARK: - Initialiser

    /// Creates a new node handler with an empty node registry.
    public init() {
        self.nodes = [:]
    }

    // MARK: - Public Methods

    /// Returns all registered nodes sorted by AE Title.
    ///
    /// - Returns: An array of ``DicomNode`` values.
    public func listNodes() -> [DicomNode] {
        nodes.values.sorted { $0.aeTitle < $1.aeTitle }
    }

    /// Retrieves a single node by its identifier.
    ///
    /// - Parameter id: The node's unique identifier.
    /// - Returns: The matching ``DicomNode``.
    /// - Throws: ``AdminError/notFound(resource:)`` if no node exists with the given `id`.
    public func getNode(id: UUID) throws -> DicomNode {
        guard let node = nodes[id] else {
            throw AdminError.notFound(resource: "node \(id)")
        }
        return node
    }

    /// Stores a new node record and returns it.
    ///
    /// - Parameter node: The node to create.
    /// - Returns: The stored ``DicomNode``.
    @discardableResult
    public func createNode(_ node: DicomNode) -> DicomNode {
        nodes[node.id] = node
        return node
    }

    /// Replaces an existing node record with updated values.
    ///
    /// The `updatedAt` timestamp is refreshed to the current time.
    ///
    /// - Parameters:
    ///   - id: The identifier of the node to update.
    ///   - updated: The new node values (the `id` field is ignored; `id` is
    ///     taken from the parameter).
    /// - Returns: The updated ``DicomNode``.
    /// - Throws: ``AdminError/notFound(resource:)`` if no node exists with the given `id`.
    @discardableResult
    public func updateNode(id: UUID, with updated: DicomNode) throws -> DicomNode {
        guard let existing = nodes[id] else {
            throw AdminError.notFound(resource: "node \(id)")
        }
        let refreshed = DicomNode(
            id: id,
            aeTitle: updated.aeTitle,
            host: updated.host,
            port: updated.port,
            description: updated.description,
            tlsEnabled: updated.tlsEnabled,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        nodes[id] = refreshed
        return refreshed
    }

    /// Removes a node from the registry.
    ///
    /// - Parameter id: The identifier of the node to delete.
    /// - Throws: ``AdminError/notFound(resource:)`` if no node exists with the given `id`.
    public func deleteNode(id: UUID) throws {
        guard nodes[id] != nil else {
            throw AdminError.notFound(resource: "node \(id)")
        }
        nodes.removeValue(forKey: id)
    }

    /// Verifies connectivity to a remote node by sending a DICOM C-ECHO request.
    ///
    /// > Note: This is currently a stub that returns `true` unconditionally.
    ///   Full C-ECHO integration via `VerificationSCU` is planned for a future
    ///   milestone.
    ///
    /// - Parameter id: The identifier of the node to verify.
    /// - Returns: `true` if the node responded successfully.
    /// - Throws: ``AdminError/notFound(resource:)`` if the node does not exist.
    public func verifyNode(id: UUID) async throws -> Bool {
        guard nodes[id] != nil else {
            throw AdminError.notFound(resource: "node \(id)")
        }
        // Stub: real implementation would use VerificationSCU (C-ECHO) from MayamCore.
        return true
    }
}
