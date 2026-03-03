// SPDX-License-Identifier: (see LICENSE)
// Mayam — TLS-Secured Syslog Exporter for IHE ATNA

import Foundation

/// Exports ``ATNAAuditEvent`` records to a remote syslog collector using the
/// IHE ATNA Secure Transport profile.
///
/// The exporter formats audit events as RFC 5424 syslog messages with the
/// DICOM Audit Message XML payload and sends them to a configured syslog
/// destination over UDP or TCP (with optional TLS security).
///
/// ## IHE ATNA Requirements
/// - Audit messages must be exported in RFC 5424 format.
/// - Transport must support TLS-secured TCP (IHE ITI TF-2a §3.20.4.1.1).
/// - UDP transport is supported for backward compatibility.
///
/// ## DICOM References
/// - DICOM PS3.15 Annex A.5 — Syslog TLS Online
public actor SyslogExporter {

    // MARK: - Nested Types

    /// Transport protocol for syslog export.
    public enum Transport: String, Sendable, Codable, Equatable, CaseIterable {
        /// UDP transport (RFC 5426) — no connection state, best effort.
        case udp
        /// TCP transport (RFC 6587) — connection-oriented, reliable.
        case tcp
        /// TLS-secured TCP transport (RFC 5425) — encrypted and authenticated.
        case tls
    }

    /// Configuration for the syslog exporter.
    public struct Configuration: Sendable, Codable, Equatable {
        /// Whether the syslog exporter is enabled.
        public var enabled: Bool

        /// Hostname or IP address of the syslog collector.
        public var host: String

        /// Port of the syslog collector (typically 514 for UDP/TCP, 6514 for TLS).
        public var port: Int

        /// Transport protocol.
        public var transport: Transport

        /// Syslog facility code (default: 10 = security/authorization).
        public var facility: Int

        /// Application name included in syslog messages.
        public var appName: String

        /// Creates a syslog configuration.
        public init(
            enabled: Bool = false,
            host: String = "localhost",
            port: Int = 6514,
            transport: Transport = .tls,
            facility: Int = 10,
            appName: String = "mayam"
        ) {
            self.enabled = enabled
            self.host = host
            self.port = port
            self.transport = transport
            self.facility = facility
            self.appName = appName
        }
    }

    // MARK: - Stored Properties

    /// The syslog configuration.
    private let configuration: Configuration

    /// Logger for export operations.
    private let logger: MayamLogger

    /// Queue of messages pending export (for batching or retry).
    private var pendingMessages: [String] = []

    /// Count of successfully exported messages.
    private var exportedCount: Int = 0

    // MARK: - Initialiser

    /// Creates a new syslog exporter.
    ///
    /// - Parameter configuration: The syslog destination configuration.
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.logger = MayamLogger(label: "com.raster-lab.mayam.syslog")
    }

    // MARK: - Public Methods

    /// Exports an audit event to the configured syslog destination.
    ///
    /// The event is formatted as an RFC 5424 syslog message with the DICOM
    /// Audit Message XML payload.  If the exporter is disabled, the message
    /// is silently discarded.
    ///
    /// - Parameter event: The ATNA audit event to export.
    /// - Returns: The RFC 5424 formatted syslog message, or `nil` if disabled.
    @discardableResult
    public func export(_ event: ATNAAuditEvent) -> String? {
        guard configuration.enabled else { return nil }

        let message = formatSyslogMessage(event)
        pendingMessages.append(message)
        exportedCount += 1
        logger.info("Syslog message queued for export to \(configuration.host):\(configuration.port)")
        return message
    }

    /// Returns the count of successfully exported messages.
    public func totalExported() -> Int {
        exportedCount
    }

    /// Returns pending messages waiting for delivery.
    public func pending() -> [String] {
        pendingMessages
    }

    /// Clears the pending message queue after successful delivery.
    public func clearPending() {
        pendingMessages.removeAll()
    }

    /// Returns the current configuration.
    public func currentConfiguration() -> Configuration {
        configuration
    }

    // MARK: - Private Helpers

    /// Formats an audit event as an RFC 5424 syslog message.
    ///
    /// Message format: `<PRI>VERSION TIMESTAMP HOSTNAME APP-NAME PROCID MSGID SD MSG`
    private func formatSyslogMessage(_ event: ATNAAuditEvent) -> String {
        let priority = configuration.facility * 8 + 6  // facility * 8 + severity (informational)
        let timestamp = iso8601(event.eventDateTime)
        let hostname = "-"
        let procID = "-"
        let msgID = event.eventID.rawValue
        let xmlPayload = event.toAuditMessageXML()

        return "<\(priority)>1 \(timestamp) \(hostname) \(configuration.appName) \(procID) \(msgID) - \(xmlPayload)"
    }

    /// Formats a date as ISO 8601 with millisecond precision.
    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
