// SPDX-License-Identifier: (see LICENSE)
// Mayam — HL7 v2.x Workflow Integration

import Foundation

// MARK: - HL7WorkflowIntegration

/// Integrates with HL7 v2.x ORM (Order) and ORU (Result) messages for
/// order-driven imaging workflows.
///
/// This service bridges the Mayam workflow engine with HL7 v2.x messaging,
/// translating between RIS events and HL7 message types. It uses
/// [HL7kit](https://github.com/Raster-Lab/HL7kit)'s `HL7v2Kit` module for
/// message parsing, serialisation, and MLLP transport.
///
/// Reference: HL7 v2.x Chapter 4 (Order Entry) and Chapter 7 (Observation Reporting)
public actor HL7WorkflowIntegration {

    // MARK: - Nested Types

    /// Supported HL7 v2.x message types for workflow integration.
    public enum MessageType: String, Sendable, Codable, Equatable, CaseIterable {
        /// ORM — General Order Message (new order, order update, cancel).
        case orm = "ORM"

        /// ORU — Observation Result (unsolicited) — study availability notification.
        case oru = "ORU"

        /// ADT — Admit/Discharge/Transfer — patient demographic updates.
        case adt = "ADT"

        /// ACK — General Acknowledgement.
        case ack = "ACK"
    }

    /// Represents an HL7 v2.x order extracted from an ORM message.
    public struct ImagingOrder: Sendable, Codable, Equatable {
        /// Placer Order Number (ORC-2).
        public var placerOrderNumber: String?

        /// Filler Order Number (ORC-3).
        public var fillerOrderNumber: String?

        /// Accession Number (OBR-18).
        public var accessionNumber: String?

        /// Patient ID (PID-3).
        public var patientID: String?

        /// Patient Name (PID-5).
        public var patientName: String?

        /// Requested Procedure Description (OBR-4).
        public var procedureDescription: String?

        /// Modality from the order (OBR-24).
        public var modality: String?

        /// Scheduled date/time (OBR-36 or TQ1-7).
        public var scheduledDateTime: String?

        /// Order control code (ORC-1): NW (new), CA (cancel), XO (change).
        public var orderControl: String?

        /// Creates an imaging order.
        public init(
            placerOrderNumber: String? = nil,
            fillerOrderNumber: String? = nil,
            accessionNumber: String? = nil,
            patientID: String? = nil,
            patientName: String? = nil,
            procedureDescription: String? = nil,
            modality: String? = nil,
            scheduledDateTime: String? = nil,
            orderControl: String? = nil
        ) {
            self.placerOrderNumber = placerOrderNumber
            self.fillerOrderNumber = fillerOrderNumber
            self.accessionNumber = accessionNumber
            self.patientID = patientID
            self.patientName = patientName
            self.procedureDescription = procedureDescription
            self.modality = modality
            self.scheduledDateTime = scheduledDateTime
            self.orderControl = orderControl
        }
    }

    // MARK: - Stored Properties

    /// Logger for HL7 workflow events.
    private let logger: MayamLogger

    /// Received imaging orders from ORM messages.
    private var receivedOrders: [ImagingOrder] = []

    /// Whether the HL7 integration is currently active.
    private var isActive: Bool = false

    // MARK: - Initialiser

    /// Creates a new HL7 workflow integration service.
    ///
    /// - Parameter logger: Logger instance for HL7 events.
    public init(logger: MayamLogger) {
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Processes an incoming HL7 v2.x ORM (Order) message.
    ///
    /// Extracts the imaging order details and stores them. When the HL7kit
    /// dependency is fully integrated, this will parse actual HL7 v2.x
    /// message segments.
    ///
    /// - Parameter order: The extracted imaging order.
    /// - Returns: The processed order.
    public func processOrder(_ order: ImagingOrder) async -> ImagingOrder {
        receivedOrders.append(order)
        logger.info("HL7: Received ORM order — accession='\(order.accessionNumber ?? "unknown")', control='\(order.orderControl ?? "NW")'")
        return order
    }

    /// Converts a RIS event into an HL7 v2.x ORU message payload.
    ///
    /// Generates a simplified ORU message structure from the given RIS event.
    /// When HL7kit is fully integrated, this will produce a properly encoded
    /// HL7 v2.x message via `HL7v2Kit`.
    ///
    /// - Parameter event: The RIS event to convert.
    /// - Returns: The HL7 v2.x message string.
    public func generateORUMessage(from event: RISEvent) -> String {
        let timestamp = ISO8601DateFormatter().string(from: event.timestamp)
        let pid = event.patientID ?? ""
        let pname = event.patientName ?? ""
        let acc = event.accessionNumber ?? ""
        let studyUID = event.studyInstanceUID

        var message = "MSH|^~\\&|MAYAM|MAYAM|||"
        message += "\(timestamp)||ORU^R01|"
        message += "\(event.id.uuidString)|P|2.5\r"
        message += "PID|||"
        message += "\(pid)||"
        message += "\(pname)\r"
        message += "OBR|1||"
        message += "\(acc)|"
        message += "|||||||||||||||"
        message += "\(studyUID)\r"

        logger.info("HL7: Generated ORU message for study '\(studyUID)'")
        return message
    }

    /// Returns all received imaging orders.
    public func getReceivedOrders() -> [ImagingOrder] {
        receivedOrders
    }

    /// Returns the count of received orders.
    public func receivedOrderCount() -> Int {
        receivedOrders.count
    }

    /// Returns whether the integration is active.
    public func getIsActive() -> Bool {
        isActive
    }

    /// Activates the HL7 workflow integration.
    public func activate() {
        isActive = true
        logger.info("HL7: Workflow integration activated")
    }

    /// Deactivates the HL7 workflow integration.
    public func deactivate() {
        isActive = false
        logger.info("HL7: Workflow integration deactivated")
    }
}
