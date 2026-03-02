// SPDX-License-Identifier: (see LICENSE)
// Mayam — Workflow Engine

import Foundation

// MARK: - WorkflowEngine

/// Central workflow engine that coordinates study lifecycle events,
/// MPPS status tracking, and notification delivery.
///
/// The workflow engine is the hub through which all study lifecycle events
/// flow. It maintains an event log, notifies registered webhook subscribers,
/// and triggers IAN notifications to DICOM peers.
public actor WorkflowEngine {

    // MARK: - Stored Properties

    /// In-memory event log of all published RIS events.
    private var events: [RISEvent] = []

    /// Registered webhook subscriptions.
    private var subscriptions: [UUID: WebhookSubscription] = [:]

    /// Delivery records for webhook attempts.
    private var deliveryRecords: [WebhookDeliveryRecord] = []

    /// Logger for workflow events.
    private let logger: MayamLogger

    /// Optional callback invoked for each published event, enabling
    /// external systems (e.g. webhook delivery, IAN) to react.
    private let eventHandler: (@Sendable (RISEvent) async -> Void)?

    // MARK: - Initialiser

    /// Creates a new workflow engine.
    ///
    /// - Parameters:
    ///   - logger: Logger instance for workflow events.
    ///   - eventHandler: Optional callback invoked for each published event.
    public init(
        logger: MayamLogger,
        eventHandler: (@Sendable (RISEvent) async -> Void)? = nil
    ) {
        self.logger = logger
        self.eventHandler = eventHandler
    }

    // MARK: - Event Publishing

    /// Publishes a study lifecycle event.
    ///
    /// The event is logged, and all matching webhook subscribers and
    /// the optional event handler are notified.
    ///
    /// - Parameter event: The RIS event to publish.
    public func publishEvent(_ event: RISEvent) async {
        events.append(event)
        logger.info("Workflow: Published event '\(event.eventType.rawValue)' for study '\(event.studyInstanceUID)'")

        if let handler = eventHandler {
            await handler(event)
        }
    }

    /// Returns all published events, optionally filtered by event type.
    ///
    /// - Parameter eventType: Optional event type filter.
    /// - Returns: Matching events sorted by timestamp (newest first).
    public func getEvents(eventType: RISEvent.EventType? = nil) -> [RISEvent] {
        let filtered: [RISEvent]
        if let type = eventType {
            filtered = events.filter { $0.eventType == type }
        } else {
            filtered = events
        }
        return filtered.sorted { $0.timestamp > $1.timestamp }
    }

    /// Returns events for a specific study.
    ///
    /// - Parameter studyInstanceUID: The Study Instance UID to filter by.
    /// - Returns: Matching events sorted by timestamp (newest first).
    public func getEventsForStudy(studyInstanceUID: String) -> [RISEvent] {
        events.filter { $0.studyInstanceUID == studyInstanceUID }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Returns the total number of published events.
    public func eventCount() -> Int {
        events.count
    }

    // MARK: - Webhook Subscription Management

    /// Registers a new webhook subscription.
    ///
    /// - Parameter subscription: The subscription to register.
    public func addSubscription(_ subscription: WebhookSubscription) {
        subscriptions[subscription.id] = subscription
        logger.info("Workflow: Added webhook subscription '\(subscription.name)' (id: \(subscription.id))")
    }

    /// Updates an existing webhook subscription.
    ///
    /// - Parameter subscription: The updated subscription.
    /// - Throws: ``WorkflowError/subscriptionNotFound(id:)`` if not found.
    public func updateSubscription(_ subscription: WebhookSubscription) throws {
        guard subscriptions[subscription.id] != nil else {
            throw WorkflowError.subscriptionNotFound(id: subscription.id)
        }
        subscriptions[subscription.id] = subscription
        logger.info("Workflow: Updated webhook subscription '\(subscription.name)' (id: \(subscription.id))")
    }

    /// Removes a webhook subscription.
    ///
    /// - Parameter id: The subscription identifier to remove.
    /// - Throws: ``WorkflowError/subscriptionNotFound(id:)`` if not found.
    public func removeSubscription(id: UUID) throws {
        guard subscriptions.removeValue(forKey: id) != nil else {
            throw WorkflowError.subscriptionNotFound(id: id)
        }
        logger.info("Workflow: Removed webhook subscription (id: \(id))")
    }

    /// Returns all registered webhook subscriptions.
    ///
    /// - Returns: An array of ``WebhookSubscription`` records.
    public func getSubscriptions() -> [WebhookSubscription] {
        Array(subscriptions.values).sorted { $0.name < $1.name }
    }

    /// Returns a specific subscription by identifier.
    ///
    /// - Parameter id: The subscription identifier.
    /// - Returns: The matching ``WebhookSubscription``.
    /// - Throws: ``WorkflowError/subscriptionNotFound(id:)`` if not found.
    public func getSubscription(id: UUID) throws -> WebhookSubscription {
        guard let subscription = subscriptions[id] else {
            throw WorkflowError.subscriptionNotFound(id: id)
        }
        return subscription
    }

    // MARK: - Delivery Records

    /// Records a webhook delivery attempt.
    ///
    /// - Parameter record: The delivery record to store.
    public func addDeliveryRecord(_ record: WebhookDeliveryRecord) {
        deliveryRecords.append(record)
    }

    /// Returns delivery records, optionally filtered by subscription.
    ///
    /// - Parameter subscriptionID: Optional subscription identifier filter.
    /// - Returns: Matching delivery records sorted by timestamp (newest first).
    public func getDeliveryRecords(subscriptionID: UUID? = nil) -> [WebhookDeliveryRecord] {
        let filtered: [WebhookDeliveryRecord]
        if let subID = subscriptionID {
            filtered = deliveryRecords.filter { $0.subscriptionID == subID }
        } else {
            filtered = deliveryRecords
        }
        return filtered.sorted { $0.attemptedAt > $1.attemptedAt }
    }

    // MARK: - Convenience Event Factories

    /// Publishes a `study.received` event.
    ///
    /// - Parameters:
    ///   - studyInstanceUID: Study Instance UID.
    ///   - accessionNumber: Accession Number.
    ///   - patientID: Patient ID.
    ///   - patientName: Patient Name.
    ///   - modality: Modality.
    ///   - studyDate: Study Date.
    ///   - studyDescription: Study Description (nullable).
    ///   - receivingAE: Receiving AE Title.
    ///   - sourceAE: Source AE Title.
    public func publishStudyReceived(
        studyInstanceUID: String,
        accessionNumber: String? = nil,
        patientID: String? = nil,
        patientName: String? = nil,
        modality: String? = nil,
        studyDate: String? = nil,
        studyDescription: String? = nil,
        receivingAE: String? = nil,
        sourceAE: String? = nil
    ) async {
        let event = RISEvent(
            eventType: .studyReceived,
            studyInstanceUID: studyInstanceUID,
            accessionNumber: accessionNumber,
            patientID: patientID,
            patientName: patientName,
            modality: modality,
            studyDate: studyDate,
            studyDescription: studyDescription,
            receivingAE: receivingAE,
            sourceAE: sourceAE
        )
        await publishEvent(event)
    }

    /// Publishes a `study.available` event.
    ///
    /// - Parameters:
    ///   - studyInstanceUID: Study Instance UID.
    ///   - accessionNumber: Accession Number.
    ///   - patientID: Patient ID.
    ///   - retrieveAE: Retrieve AE Title.
    ///   - retrieveURL: Retrieve URL.
    ///   - availableTransferSyntaxes: Available transfer syntaxes.
    public func publishStudyAvailable(
        studyInstanceUID: String,
        accessionNumber: String? = nil,
        patientID: String? = nil,
        retrieveAE: String? = nil,
        retrieveURL: String? = nil,
        availableTransferSyntaxes: [String]? = nil
    ) async {
        let event = RISEvent(
            eventType: .studyAvailable,
            studyInstanceUID: studyInstanceUID,
            accessionNumber: accessionNumber,
            patientID: patientID,
            retrieveAE: retrieveAE,
            retrieveURL: retrieveURL,
            availableTransferSyntaxes: availableTransferSyntaxes
        )
        await publishEvent(event)
    }

    /// Publishes a `study.error` event.
    ///
    /// - Parameters:
    ///   - studyInstanceUID: Study Instance UID.
    ///   - accessionNumber: Accession Number.
    ///   - errorCode: Error code.
    ///   - errorMessage: Error message.
    ///   - stage: Processing stage.
    public func publishStudyError(
        studyInstanceUID: String,
        accessionNumber: String? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        stage: String? = nil
    ) async {
        let event = RISEvent(
            eventType: .studyError,
            studyInstanceUID: studyInstanceUID,
            accessionNumber: accessionNumber,
            errorCode: errorCode,
            errorMessage: errorMessage,
            stage: stage
        )
        await publishEvent(event)
    }
}

// MARK: - WorkflowError

/// Errors that may occur during workflow operations.
public enum WorkflowError: Error, Sendable, CustomStringConvertible {

    /// A webhook subscription was not found.
    case subscriptionNotFound(id: UUID)

    /// An event could not be published.
    case eventPublishFailed(reason: String)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .subscriptionNotFound(let id):
            return "Webhook subscription '\(id)' not found"
        case .eventPublishFailed(let reason):
            return "Failed to publish event: \(reason)"
        }
    }
}
