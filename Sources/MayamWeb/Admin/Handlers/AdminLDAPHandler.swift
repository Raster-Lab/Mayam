// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin LDAP Configuration Handler

import Foundation
import MayamCore

// MARK: - LDAPConfigurationPayload

/// A Codable, Sendable representation of the LDAP integration configuration
/// for use in the admin REST API.
public struct LDAPConfigurationPayload: Codable, Sendable {
    /// Whether LDAP integration is enabled.
    public let enabled: Bool
    /// Hostname or IP address of the LDAP server.
    public let host: String
    /// TCP port of the LDAP server.
    public let port: Int
    /// Whether to use TLS for the connection.
    public let useTLS: Bool
    /// Distinguished Name used for service bind searches.
    public let serviceBindDN: String
    /// Password for the service bind DN.
    public let serviceBindPassword: String
    /// Base DN under which user searches are performed.
    public let baseDN: String
    /// LDAP user search filter.
    public let userSearchFilter: String
    /// Attribute used as the login username.
    public let usernameAttribute: String
    /// Attribute containing the user's e-mail address.
    public let emailAttribute: String
    /// Attribute containing the user's display name.
    public let displayNameAttribute: String
    /// Attribute listing group membership.
    public let memberOfAttribute: String
    /// DN of the administrator group.
    public let adminGroupDN: String
    /// DN of the technologist group.
    public let techGroupDN: String
    /// DN of the physician group.
    public let physicianGroupDN: String
    /// DN of the auditor group.
    public let auditorGroupDN: String

    /// Creates an LDAP configuration payload.
    public init(
        enabled: Bool = false,
        host: String = "",
        port: Int = 389,
        useTLS: Bool = false,
        serviceBindDN: String = "",
        serviceBindPassword: String = "",
        baseDN: String = "",
        userSearchFilter: String = "(objectClass=person)",
        usernameAttribute: String = "uid",
        emailAttribute: String = "mail",
        displayNameAttribute: String = "cn",
        memberOfAttribute: String = "memberOf",
        adminGroupDN: String = "",
        techGroupDN: String = "",
        physicianGroupDN: String = "",
        auditorGroupDN: String = ""
    ) {
        self.enabled = enabled
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.serviceBindDN = serviceBindDN
        self.serviceBindPassword = serviceBindPassword
        self.baseDN = baseDN
        self.userSearchFilter = userSearchFilter
        self.usernameAttribute = usernameAttribute
        self.emailAttribute = emailAttribute
        self.displayNameAttribute = displayNameAttribute
        self.memberOfAttribute = memberOfAttribute
        self.adminGroupDN = adminGroupDN
        self.techGroupDN = techGroupDN
        self.physicianGroupDN = physicianGroupDN
        self.auditorGroupDN = auditorGroupDN
    }
}

// MARK: - LDAPConnectionTestResult

/// The result of an LDAP connectivity test.
public struct LDAPConnectionTestResult: Codable, Sendable {
    /// Whether the connection attempt was successful.
    public let success: Bool
    /// Human-readable status or error message.
    public let message: String
    /// Round-trip latency in milliseconds, if measured.
    public let latencyMs: Double?

    /// Creates a test result.
    public init(success: Bool, message: String, latencyMs: Double? = nil) {
        self.success = success
        self.message = message
        self.latencyMs = latencyMs
    }
}

// MARK: - AdminLDAPHandler

/// Handles admin API requests for LDAP integration configuration.
///
/// Maintains an in-memory copy of the LDAP configuration payload and provides
/// a connectivity test endpoint.
public actor AdminLDAPHandler {

    // MARK: - Stored Properties

    /// Current in-memory LDAP configuration.
    private var current: LDAPConfigurationPayload

    // MARK: - Initialiser

    /// Creates a new LDAP handler with default (disabled) configuration.
    ///
    /// - Parameter initial: Optional initial configuration to use.
    public init(initial: LDAPConfigurationPayload = LDAPConfigurationPayload()) {
        self.current = initial
    }

    // MARK: - Public Methods

    /// Returns the current LDAP configuration.
    ///
    /// - Returns: The current ``LDAPConfigurationPayload``.
    public func getConfiguration() -> LDAPConfigurationPayload {
        current
    }

    /// Replaces the in-memory LDAP configuration with the provided values.
    ///
    /// - Parameter config: The new configuration to apply.
    /// - Returns: The updated ``LDAPConfigurationPayload``.
    @discardableResult
    public func updateConfiguration(_ config: LDAPConfigurationPayload) -> LDAPConfigurationPayload {
        current = config
        return current
    }

    /// Attempts an anonymous bind to verify connectivity to the configured
    /// LDAP server.
    ///
    /// If the configuration has `enabled = false` or the host is empty, the
    /// test returns a failure without attempting a network connection.
    ///
    /// - Returns: A ``LDAPConnectionTestResult`` describing the outcome.
    public func testConnection() async -> LDAPConnectionTestResult {
        guard current.enabled && !current.host.isEmpty else {
            return LDAPConnectionTestResult(
                success: false,
                message: "LDAP is not enabled or host is not configured"
            )
        }

        let schema = ServerConfiguration.LDAP.Schema(
            usernameAttribute: current.usernameAttribute,
            emailAttribute: current.emailAttribute,
            displayNameAttribute: current.displayNameAttribute,
            memberOfAttribute: current.memberOfAttribute,
            adminGroupDN: current.adminGroupDN,
            techGroupDN: current.techGroupDN,
            physicianGroupDN: current.physicianGroupDN,
            auditorGroupDN: current.auditorGroupDN
        )
        let ldapConfig = ServerConfiguration.LDAP(
            enabled: current.enabled,
            host: current.host,
            port: current.port,
            useTLS: current.useTLS,
            serviceBindDN: current.serviceBindDN,
            serviceBindPassword: current.serviceBindPassword,
            baseDN: current.baseDN,
            userSearchFilter: current.userSearchFilter,
            groupSearchBase: "",
            schema: schema
        )
        let client = LDAPClient(configuration: ldapConfig)

        let startTime = Date()
        do {
            _ = try await client.testConnection()
            let latencyMs = Date().timeIntervalSince(startTime) * 1000
            return LDAPConnectionTestResult(
                success: true,
                message: "Successfully connected to \(current.host):\(current.port)",
                latencyMs: latencyMs
            )
        } catch let error as LDAPError {
            return LDAPConnectionTestResult(
                success: false,
                message: error.description
            )
        } catch {
            return LDAPConnectionTestResult(
                success: false,
                message: "Connection failed: \(error)"
            )
        }
    }
}
