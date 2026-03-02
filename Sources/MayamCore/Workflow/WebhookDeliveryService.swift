// SPDX-License-Identifier: (see LICENSE)
// Mayam — Webhook Delivery Service

import Foundation
import Crypto

// MARK: - WebhookDeliveryService

/// Delivers RIS lifecycle events to webhook subscribers via JSON/HTTPS POST
/// with HMAC-SHA256 signatures and exponential back-off retry.
///
/// Each delivery includes an `X-Mayam-Signature` header containing the
/// HMAC-SHA256 digest of the request body, computed using the subscription's
/// shared secret. This allows receivers to verify message integrity and
/// authenticity.
///
/// Reference: Mayam Milestone 10 — Webhook Delivery
public actor WebhookDeliveryService {

    // MARK: - Stored Properties

    /// Logger for delivery events.
    private let logger: MayamLogger

    /// JSON encoder configured for webhook payloads.
    private let encoder: JSONEncoder

    /// Pending delivery queue.
    private var pendingDeliveries: [WebhookDeliveryRecord] = []

    /// Completed delivery records.
    private var completedDeliveries: [WebhookDeliveryRecord] = []

    // MARK: - Initialiser

    /// Creates a new webhook delivery service.
    ///
    /// - Parameter logger: Logger instance for delivery events.
    public init(logger: MayamLogger) {
        self.logger = logger
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys]
        self.encoder = enc
    }

    // MARK: - Public Methods

    /// Computes the HMAC-SHA256 signature for a payload using the given secret.
    ///
    /// - Parameters:
    ///   - payload: The JSON payload bytes.
    ///   - secret: The shared secret string.
    /// - Returns: The hex-encoded HMAC-SHA256 signature prefixed with `sha256=`.
    public func computeSignature(payload: Data, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let hexDigest = signature.map { String(format: "%02x", $0) }.joined()
        return "sha256=\(hexDigest)"
    }

    /// Prepares a webhook delivery for an event and subscription.
    ///
    /// Encodes the event as JSON, computes the HMAC-SHA256 signature, and
    /// returns a delivery payload ready for HTTP POST.
    ///
    /// - Parameters:
    ///   - event: The RIS event to deliver.
    ///   - subscription: The target webhook subscription.
    /// - Returns: A ``WebhookPayload`` containing the delivery details.
    /// - Throws: If JSON encoding fails.
    public func prepareDelivery(
        event: RISEvent,
        subscription: WebhookSubscription
    ) throws -> WebhookPayload {
        let jsonData = try encoder.encode(event)
        let signature = computeSignature(payload: jsonData, secret: subscription.secret)

        return WebhookPayload(
            url: subscription.url,
            body: jsonData,
            signature: signature,
            subscriptionID: subscription.id,
            eventID: event.id
        )
    }

    /// Records a delivery attempt result.
    ///
    /// - Parameter record: The delivery record to store.
    public func recordDelivery(_ record: WebhookDeliveryRecord) {
        if record.status == .pending || record.status == .failed {
            pendingDeliveries.append(record)
        } else {
            completedDeliveries.append(record)
        }
    }

    /// Calculates the next retry delay using exponential back-off.
    ///
    /// The delay is calculated as `baseDelay * 2^(attemptCount - 1)` with
    /// a maximum cap of 3600 seconds (1 hour).
    ///
    /// - Parameters:
    ///   - attemptCount: The current attempt number (1-based).
    ///   - baseDelaySeconds: The base delay in seconds.
    /// - Returns: The delay in seconds until the next retry.
    public func calculateRetryDelay(attemptCount: Int, baseDelaySeconds: Int) -> Int {
        let exponent = max(0, attemptCount - 1)
        let delay = baseDelaySeconds * (1 << exponent)
        return min(delay, 3600)
    }

    /// Returns the count of pending deliveries.
    public func pendingDeliveryCount() -> Int {
        pendingDeliveries.count
    }

    /// Returns the count of completed deliveries.
    public func completedDeliveryCount() -> Int {
        completedDeliveries.count
    }

    /// Returns all pending delivery records.
    public func getPendingDeliveries() -> [WebhookDeliveryRecord] {
        pendingDeliveries
    }

    /// Returns all completed delivery records.
    public func getCompletedDeliveries() -> [WebhookDeliveryRecord] {
        completedDeliveries
    }
}

// MARK: - WebhookPayload

/// Contains the prepared payload for a single webhook delivery.
public struct WebhookPayload: Sendable, Equatable {

    /// The target URL for the HTTP POST.
    public let url: String

    /// The JSON-encoded event body.
    public let body: Data

    /// The HMAC-SHA256 signature for the `X-Mayam-Signature` header.
    public let signature: String

    /// The subscription identifier.
    public let subscriptionID: UUID

    /// The event identifier.
    public let eventID: UUID

    /// Creates a webhook payload.
    ///
    /// - Parameters:
    ///   - url: Target URL.
    ///   - body: JSON body data.
    ///   - signature: HMAC-SHA256 signature.
    ///   - subscriptionID: Subscription identifier.
    ///   - eventID: Event identifier.
    public init(url: String, body: Data, signature: String, subscriptionID: UUID, eventID: UUID) {
        self.url = url
        self.body = body
        self.signature = signature
        self.subscriptionID = subscriptionID
        self.eventID = eventID
    }
}
