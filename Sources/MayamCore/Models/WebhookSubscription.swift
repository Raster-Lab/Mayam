// SPDX-License-Identifier: (see LICENSE)
// Mayam — Webhook Subscription Model

import Foundation

/// Represents a webhook subscription for receiving RIS lifecycle event
/// notifications via JSON/HTTPS POST.
///
/// Each subscription targets a specific URL endpoint and may optionally
/// filter for specific event types. Webhook deliveries are signed with
/// HMAC-SHA256 using a per-subscription shared secret for integrity
/// verification.
///
/// Reference: Mayam Milestone 10 — Webhook Delivery
public struct WebhookSubscription: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Stored Properties

    /// Unique identifier for this subscription.
    public let id: UUID

    /// Human-readable name for this subscription.
    public var name: String

    /// The HTTPS endpoint URL to which events are delivered.
    public var url: String

    /// Shared secret used to compute HMAC-SHA256 signatures for deliveries.
    /// The signature is sent in the `X-Mayam-Signature` HTTP header.
    public var secret: String

    /// Event types to subscribe to. If empty, all event types are delivered.
    public var eventTypes: [RISEvent.EventType]

    /// Whether this subscription is currently active.
    public var enabled: Bool

    /// Maximum number of delivery retry attempts before marking as failed.
    public var maxRetries: Int

    /// Base delay in seconds for exponential back-off between retries.
    public var retryDelaySeconds: Int

    /// Row creation timestamp.
    public let createdAt: Date

    /// Row last-update timestamp.
    public var updatedAt: Date

    // MARK: - Initialiser

    /// Creates a new webhook subscription.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Human-readable subscription name.
    ///   - url: Target HTTPS endpoint URL.
    ///   - secret: HMAC-SHA256 shared secret.
    ///   - eventTypes: Event types to filter (empty = all events).
    ///   - enabled: Whether the subscription is active.
    ///   - maxRetries: Maximum retry attempts (default: 5).
    ///   - retryDelaySeconds: Base retry delay in seconds (default: 10).
    ///   - createdAt: Creation timestamp.
    ///   - updatedAt: Last-update timestamp.
    public init(
        id: UUID = UUID(),
        name: String,
        url: String,
        secret: String,
        eventTypes: [RISEvent.EventType] = [],
        enabled: Bool = true,
        maxRetries: Int = 5,
        retryDelaySeconds: Int = 10,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.secret = secret
        self.eventTypes = eventTypes
        self.enabled = enabled
        self.maxRetries = maxRetries
        self.retryDelaySeconds = retryDelaySeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - WebhookDeliveryRecord

/// Records the outcome of a single webhook delivery attempt.
public struct WebhookDeliveryRecord: Sendable, Identifiable, Codable, Equatable {

    // MARK: - Nested Types

    /// The outcome status of a delivery attempt.
    public enum DeliveryStatus: String, Sendable, Codable, Equatable, CaseIterable {
        /// Delivery succeeded (HTTP 2xx response).
        case success = "success"

        /// Delivery failed and will be retried.
        case failed = "failed"

        /// All retry attempts exhausted.
        case exhausted = "exhausted"

        /// Delivery is pending (queued for retry).
        case pending = "pending"
    }

    // MARK: - Stored Properties

    /// Unique identifier for this delivery record.
    public let id: UUID

    /// The subscription that triggered this delivery.
    public let subscriptionID: UUID

    /// The event that was delivered.
    public let eventID: UUID

    /// HTTP status code received from the endpoint (nil if connection failed).
    public var httpStatusCode: Int?

    /// Current delivery status.
    public var status: DeliveryStatus

    /// Number of delivery attempts made so far.
    public var attemptCount: Int

    /// Timestamp of the next scheduled retry (nil if no more retries).
    public var nextRetryAt: Date?

    /// Error message from the last failed attempt.
    public var lastError: String?

    /// Timestamp of the delivery attempt.
    public let attemptedAt: Date

    // MARK: - Initialiser

    /// Creates a new webhook delivery record.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - subscriptionID: Subscription identifier.
    ///   - eventID: Event identifier.
    ///   - httpStatusCode: HTTP response status code.
    ///   - status: Delivery status.
    ///   - attemptCount: Number of attempts.
    ///   - nextRetryAt: Next retry timestamp.
    ///   - lastError: Error message.
    ///   - attemptedAt: Attempt timestamp.
    public init(
        id: UUID = UUID(),
        subscriptionID: UUID,
        eventID: UUID,
        httpStatusCode: Int? = nil,
        status: DeliveryStatus = .pending,
        attemptCount: Int = 0,
        nextRetryAt: Date? = nil,
        lastError: String? = nil,
        attemptedAt: Date = Date()
    ) {
        self.id = id
        self.subscriptionID = subscriptionID
        self.eventID = eventID
        self.httpStatusCode = httpStatusCode
        self.status = status
        self.attemptCount = attemptCount
        self.nextRetryAt = nextRetryAt
        self.lastError = lastError
        self.attemptedAt = attemptedAt
    }
}
