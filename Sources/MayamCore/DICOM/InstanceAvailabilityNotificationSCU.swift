// SPDX-License-Identifier: (see LICENSE)
// Mayam — Instance Availability Notification SCU

import Foundation

// MARK: - InstanceAvailabilityNotificationSCU

/// Sends Instance Availability Notification (IAN) messages to downstream
/// systems when studies become available in the archive.
///
/// The IAN SCU notifies registered DICOM peers about study availability
/// changes, enabling RIS and other downstream systems to track the
/// lifecycle of imaging studies.
///
/// Reference: DICOM PS3.4 Annex J — Instance Availability Notification
public actor InstanceAvailabilityNotificationSCU {

    // MARK: - Nested Types

    /// The availability status of instances.
    public enum AvailabilityStatus: String, Sendable, Codable, Equatable {
        /// Instances are available for retrieval (ONLINE).
        case online = "ONLINE"

        /// Instances are on near-line storage and may require recall.
        case nearline = "NEARLINE"

        /// Instances are on offline storage.
        case offline = "OFFLINE"

        /// Instances are not available (deleted or error).
        case unavailable = "UNAVAILABLE"
    }

    /// A reference to a SOP instance in a notification.
    public struct ReferencedSOPInstance: Sendable, Equatable, Codable {
        /// The SOP Class UID (0008,0016).
        public let sopClassUID: String

        /// The SOP Instance UID (0008,0018).
        public let sopInstanceUID: String

        /// Creates a referenced SOP instance.
        public init(sopClassUID: String, sopInstanceUID: String) {
            self.sopClassUID = sopClassUID
            self.sopInstanceUID = sopInstanceUID
        }
    }

    /// Represents a notification to be sent.
    public struct Notification: Sendable, Equatable {
        /// Study Instance UID for which availability changed.
        public let studyInstanceUID: String

        /// The current availability status.
        public let availabilityStatus: AvailabilityStatus

        /// Referenced SOP instances in the study.
        public let referencedInstances: [ReferencedSOPInstance]

        /// AE Title from which instances can be retrieved.
        public let retrieveAETitle: String

        /// Timestamp of the notification.
        public let timestamp: Date

        /// Creates a new notification.
        ///
        /// - Parameters:
        ///   - studyInstanceUID: Study Instance UID.
        ///   - availabilityStatus: Current availability status.
        ///   - referencedInstances: Referenced SOP instances.
        ///   - retrieveAETitle: Retrieve AE Title.
        ///   - timestamp: Notification timestamp.
        public init(
            studyInstanceUID: String,
            availabilityStatus: AvailabilityStatus,
            referencedInstances: [ReferencedSOPInstance] = [],
            retrieveAETitle: String,
            timestamp: Date = Date()
        ) {
            self.studyInstanceUID = studyInstanceUID
            self.availabilityStatus = availabilityStatus
            self.referencedInstances = referencedInstances
            self.retrieveAETitle = retrieveAETitle
            self.timestamp = timestamp
        }
    }

    /// Records the result of a notification delivery attempt.
    public struct DeliveryResult: Sendable, Equatable {
        /// The destination AE Title.
        public let destinationAETitle: String

        /// Whether the delivery succeeded.
        public let success: Bool

        /// Error message if delivery failed.
        public let errorMessage: String?

        /// Timestamp of the delivery attempt.
        public let timestamp: Date

        /// Creates a delivery result.
        public init(destinationAETitle: String, success: Bool, errorMessage: String? = nil, timestamp: Date = Date()) {
            self.destinationAETitle = destinationAETitle
            self.success = success
            self.errorMessage = errorMessage
            self.timestamp = timestamp
        }
    }

    // MARK: - Constants

    /// Instance Availability Notification SOP Class UID.
    public static let sopClassUID = "1.2.840.10008.5.1.4.33"

    // MARK: - Stored Properties

    /// Registered notification destinations (AE Titles).
    private var destinations: [String] = []

    /// History of sent notifications.
    private var sentNotifications: [Notification] = []

    /// History of delivery results.
    private var deliveryResults: [DeliveryResult] = []

    /// Logger for IAN events.
    private let logger: MayamLogger

    /// Callback invoked to deliver a notification to a destination AE.
    private let deliveryHandler: @Sendable (Notification, String) async -> Bool

    // MARK: - Initialiser

    /// Creates a new IAN SCU.
    ///
    /// - Parameters:
    ///   - logger: Logger instance for IAN events.
    ///   - deliveryHandler: A closure that delivers a notification to the
    ///     specified AE Title and returns `true` on success.
    public init(
        logger: MayamLogger,
        deliveryHandler: @escaping @Sendable (Notification, String) async -> Bool
    ) {
        self.logger = logger
        self.deliveryHandler = deliveryHandler
    }

    // MARK: - Public Methods

    /// Registers a destination AE Title for receiving notifications.
    ///
    /// - Parameter aeTitle: The AE Title to register.
    public func registerDestination(aeTitle: String) {
        guard !destinations.contains(aeTitle) else { return }
        destinations.append(aeTitle)
        logger.info("IAN: Registered notification destination '\(aeTitle)'")
    }

    /// Removes a destination AE Title from receiving notifications.
    ///
    /// - Parameter aeTitle: The AE Title to remove.
    public func removeDestination(aeTitle: String) {
        destinations.removeAll { $0 == aeTitle }
        logger.info("IAN: Removed notification destination '\(aeTitle)'")
    }

    /// Returns the list of registered destination AE Titles.
    public func getDestinations() -> [String] {
        destinations
    }

    /// Sends a notification to all registered destinations.
    ///
    /// - Parameter notification: The notification to send.
    /// - Returns: An array of ``DeliveryResult`` records for each destination.
    public func sendNotification(_ notification: Notification) async -> [DeliveryResult] {
        logger.info("IAN: Sending notification for study '\(notification.studyInstanceUID)' status=\(notification.availabilityStatus.rawValue) to \(destinations.count) destination(s)")

        sentNotifications.append(notification)
        var results: [DeliveryResult] = []

        for destination in destinations {
            let success = await deliveryHandler(notification, destination)
            let result = DeliveryResult(
                destinationAETitle: destination,
                success: success,
                errorMessage: success ? nil : "Delivery to '\(destination)' failed"
            )
            results.append(result)
            deliveryResults.append(result)

            if success {
                logger.info("IAN: Notification delivered to '\(destination)' successfully")
            } else {
                logger.warning("IAN: Notification delivery to '\(destination)' failed")
            }
        }

        return results
    }

    /// Returns the history of sent notifications.
    public func getSentNotifications() -> [Notification] {
        sentNotifications
    }

    /// Returns the history of delivery results.
    public func getDeliveryResults() -> [DeliveryResult] {
        deliveryResults
    }

    /// Returns the count of sent notifications.
    public func sentNotificationCount() -> Int {
        sentNotifications.count
    }
}
