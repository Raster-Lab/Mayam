// SPDX-License-Identifier: (see LICENSE)
// Mayam — HL7 Configurable Message Routing and Transformation Rules

import Foundation
import HL7Core

// MARK: - RoutingAction

/// Describes the action to take when a routing rule matches an incoming HL7 message.
///
/// Each case represents a different disposition for the matched message,
/// ranging from forwarding to a remote endpoint to silently discarding.
public enum RoutingAction: Sendable, Codable, Equatable {

    /// Forward the message to a remote destination (e.g. `"host:port"`).
    case forward(destination: String)

    /// Apply a named transformation template before further processing.
    case transform(templateID: String)

    /// Silently discard the message (with logging).
    case discard

    /// Delegate processing to a named handler.
    case delegate(handlerName: String)
}

// MARK: - HL7RoutingRule

/// A configurable routing rule that determines how incoming HL7 messages are dispatched.
///
/// Rules are evaluated against MSH-9 (message type), MSH-3 (sending application),
/// and MSH-4 (sending facility) fields. Lower `priority` values are evaluated first.
///
/// ## Example
/// ```swift
/// let rule = HL7RoutingRule(
///     id: "route-adt-to-archive",
///     name: "Route ADT to Archive",
///     sourceMessageType: "ADT",
///     enabled: true,
///     priority: 10,
///     action: .forward(destination: "archive.local:2575")
/// )
/// ```
public struct HL7RoutingRule: Sendable, Codable, Equatable {

    /// Unique rule identifier.
    public var id: String

    /// Human-readable rule name.
    public var name: String

    /// Match incoming messages by MSH-9 message type (e.g. `"ADT"`, `"ORM"`, `"ORU"`, `"*"` for all).
    public var sourceMessageType: String

    /// Optional filter by MSH-3 sending application.
    public var sourceSendingApplication: String?

    /// Optional filter by MSH-4 sending facility.
    public var sourceSendingFacility: String?

    /// Whether the rule is active.
    public var enabled: Bool

    /// Evaluation priority — lower numbers are evaluated first.
    public var priority: Int

    /// The action to take when the rule matches.
    public var action: RoutingAction

    /// Creates a new routing rule.
    ///
    /// - Parameters:
    ///   - id: Unique rule identifier.
    ///   - name: Human-readable rule name.
    ///   - sourceMessageType: MSH-9 message type to match (`"*"` matches all).
    ///   - sourceSendingApplication: Optional MSH-3 filter.
    ///   - sourceSendingFacility: Optional MSH-4 filter.
    ///   - enabled: Whether the rule is active. Defaults to `true`.
    ///   - priority: Evaluation priority (lower first). Defaults to `0`.
    ///   - action: The action to take when the rule matches.
    public init(
        id: String,
        name: String,
        sourceMessageType: String,
        sourceSendingApplication: String? = nil,
        sourceSendingFacility: String? = nil,
        enabled: Bool = true,
        priority: Int = 0,
        action: RoutingAction
    ) {
        self.id = id
        self.name = name
        self.sourceMessageType = sourceMessageType
        self.sourceSendingApplication = sourceSendingApplication
        self.sourceSendingFacility = sourceSendingFacility
        self.enabled = enabled
        self.priority = priority
        self.action = action
    }
}

// MARK: - FieldOperation

/// Describes a field-level transformation operation applied during message transformation.
public enum FieldOperation: Sendable, Codable, Equatable {

    /// Copy the source field value as-is.
    case copy

    /// Map specific values to different values using a lookup dictionary.
    case mapValue(mapping: [String: String])

    /// Set a constant value regardless of the source.
    case setConstant(value: String)

    /// Truncate the value to a maximum length.
    case truncate(maxLength: Int)
}

// MARK: - FieldMapping

/// A single field-level mapping within a transformation rule.
///
/// Describes how one HL7 field is transformed into another using the
/// specified ``FieldOperation``.
public struct FieldMapping: Sendable, Codable, Equatable {

    /// HL7 field path for the source (e.g. `"PID-3"`, `"ORC-2"`, `"MSH-9"`).
    public var sourceField: String

    /// Target field path for the transformation output.
    public var targetField: String

    /// The transformation operation to apply.
    public var operation: FieldOperation

    /// Creates a new field mapping.
    ///
    /// - Parameters:
    ///   - sourceField: HL7 field path (e.g. `"PID-3"`).
    ///   - targetField: Target field path.
    ///   - operation: The transformation operation to apply.
    public init(sourceField: String, targetField: String, operation: FieldOperation) {
        self.sourceField = sourceField
        self.targetField = targetField
        self.operation = operation
    }
}

// MARK: - HL7TransformationRule

/// A configurable rule that defines field-level transformations for HL7 messages.
///
/// Transformation rules are referenced by ``RoutingAction/transform(templateID:)``
/// and applied via ``HL7MessageRoutingService/applyTransformation(ruleID:inputFields:)``.
///
/// ## Example
/// ```swift
/// let rule = HL7TransformationRule(
///     id: "normalise-pid",
///     name: "Normalise Patient ID",
///     fieldMappings: [
///         FieldMapping(sourceField: "PID-3", targetField: "PID-3", operation: .copy),
///         FieldMapping(sourceField: "PID-5", targetField: "PID-5", operation: .truncate(maxLength: 64))
///     ]
/// )
/// ```
public struct HL7TransformationRule: Sendable, Codable, Equatable {

    /// Unique rule identifier.
    public var id: String

    /// Human-readable rule name.
    public var name: String

    /// Optional description of the transformation rule.
    public var description_: String?

    /// Array of field-level mappings that define the transformation.
    public var fieldMappings: [FieldMapping]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description_ = "description"
        case fieldMappings
    }

    /// Creates a new transformation rule.
    ///
    /// - Parameters:
    ///   - id: Unique rule identifier.
    ///   - name: Human-readable rule name.
    ///   - description_: Optional description.
    ///   - fieldMappings: Array of field-level mappings.
    public init(
        id: String,
        name: String,
        description_: String? = nil,
        fieldMappings: [FieldMapping]
    ) {
        self.id = id
        self.name = name
        self.description_ = description_
        self.fieldMappings = fieldMappings
    }
}

// MARK: - HL7MessageRoutingService

/// Manages configurable HL7 message routing and transformation rules.
///
/// `HL7MessageRoutingService` evaluates incoming messages against a prioritised
/// set of routing rules and applies field-level transformations. It leverages
/// HL7Core's ``MessageRouter`` for format-based routing (v2, v3, FHIR) and
/// extends it with configurable, rule-driven dispatch and transformation logic.
///
/// ## Usage
/// ```swift
/// let logger = MayamLogger(label: "com.raster-lab.mayam.hl7.routing")
/// let service = HL7MessageRoutingService(logger: logger)
///
/// await service.addRoutingRule(HL7RoutingRule(
///     id: "forward-adt",
///     name: "Forward ADT",
///     sourceMessageType: "ADT",
///     action: .forward(destination: "archive:2575")
/// ))
///
/// let matches = await service.evaluateRouting(
///     messageType: "ADT",
///     sendingApplication: nil,
///     sendingFacility: nil
/// )
/// ```
public actor HL7MessageRoutingService {

    // MARK: - Stored Properties

    /// Configurable routing rules, evaluated in priority order.
    private var routingRules: [HL7RoutingRule] = []

    /// Configurable transformation rules, keyed by rule ID at application time.
    private var transformationRules: [HL7TransformationRule] = []

    /// Logger for routing and transformation events.
    private let logger: MayamLogger

    /// Optional HL7Core format-based message router for v2/v3/FHIR dispatch.
    private var formatRouter: MessageRouter?

    // MARK: - Initialiser

    /// Creates a new HL7 message routing service.
    ///
    /// - Parameter logger: Logger instance for routing events.
    public init(logger: MayamLogger) {
        self.logger = logger
        self.formatRouter = nil
        logger.info("HL7 Routing: Service initialised")
    }

    /// Creates a new HL7 message routing service with an HL7Core ``MessageRouter``.
    ///
    /// - Parameters:
    ///   - logger: Logger instance for routing events.
    ///   - formatRouter: An HL7Core `MessageRouter` for format-based (v2/v3/FHIR) dispatch.
    public init(logger: MayamLogger, formatRouter: MessageRouter) {
        self.logger = logger
        self.formatRouter = formatRouter
        logger.info("HL7 Routing: Service initialised with format router")
    }

    // MARK: - Routing Rule Management

    /// Adds a routing rule to the service.
    ///
    /// - Parameter rule: The routing rule to add.
    public func addRoutingRule(_ rule: HL7RoutingRule) {
        routingRules.append(rule)
        logger.info("HL7 Routing: Added rule '\(rule.name)' (id=\(rule.id), type=\(rule.sourceMessageType), priority=\(rule.priority))")
    }

    /// Removes a routing rule by its identifier.
    ///
    /// - Parameter id: The unique identifier of the rule to remove.
    /// - Returns: `true` if a rule was removed, `false` if no rule matched.
    @discardableResult
    public func removeRoutingRule(id: String) -> Bool {
        guard let index = routingRules.firstIndex(where: { $0.id == id }) else {
            logger.warning("HL7 Routing: No routing rule found with id '\(id)'")
            return false
        }
        let removed = routingRules.remove(at: index)
        logger.info("HL7 Routing: Removed rule '\(removed.name)' (id=\(id))")
        return true
    }

    /// Returns all configured routing rules.
    ///
    /// - Returns: An array of ``HL7RoutingRule`` instances.
    public func getRoutingRules() -> [HL7RoutingRule] {
        routingRules
    }

    // MARK: - Transformation Rule Management

    /// Adds a transformation rule to the service.
    ///
    /// - Parameter rule: The transformation rule to add.
    public func addTransformationRule(_ rule: HL7TransformationRule) {
        transformationRules.append(rule)
        logger.info("HL7 Routing: Added transformation rule '\(rule.name)' (id=\(rule.id), mappings=\(rule.fieldMappings.count))")
    }

    /// Removes a transformation rule by its identifier.
    ///
    /// - Parameter id: The unique identifier of the rule to remove.
    /// - Returns: `true` if a rule was removed, `false` if no rule matched.
    @discardableResult
    public func removeTransformationRule(id: String) -> Bool {
        guard let index = transformationRules.firstIndex(where: { $0.id == id }) else {
            logger.warning("HL7 Routing: No transformation rule found with id '\(id)'")
            return false
        }
        let removed = transformationRules.remove(at: index)
        logger.info("HL7 Routing: Removed transformation rule '\(removed.name)' (id=\(id))")
        return true
    }

    /// Returns all configured transformation rules.
    ///
    /// - Returns: An array of ``HL7TransformationRule`` instances.
    public func getTransformationRules() -> [HL7TransformationRule] {
        transformationRules
    }

    // MARK: - Routing Evaluation

    /// Evaluates routing rules against the given message attributes and returns matching rules.
    ///
    /// Only enabled rules are considered. A rule matches when:
    /// - Its `sourceMessageType` equals `"*"` or matches the provided `messageType`.
    /// - Its `sourceSendingApplication`, if set, matches the provided `sendingApplication`.
    /// - Its `sourceSendingFacility`, if set, matches the provided `sendingFacility`.
    ///
    /// Results are sorted by ascending `priority` (lower numbers first).
    ///
    /// - Parameters:
    ///   - messageType: MSH-9 message type of the incoming message (e.g. `"ADT"`).
    ///   - sendingApplication: MSH-3 sending application, if available.
    ///   - sendingFacility: MSH-4 sending facility, if available.
    /// - Returns: An array of matching ``HL7RoutingRule`` instances, sorted by priority.
    public func evaluateRouting(
        messageType: String,
        sendingApplication: String?,
        sendingFacility: String?
    ) -> [HL7RoutingRule] {
        let matched = routingRules.filter { rule in
            guard rule.enabled else { return false }

            // Match message type: wildcard or exact match.
            guard rule.sourceMessageType == "*" || rule.sourceMessageType == messageType else {
                return false
            }

            // Match sending application if specified.
            if let requiredApp = rule.sourceSendingApplication {
                guard sendingApplication == requiredApp else { return false }
            }

            // Match sending facility if specified.
            if let requiredFacility = rule.sourceSendingFacility {
                guard sendingFacility == requiredFacility else { return false }
            }

            return true
        }

        let sorted = matched.sorted { $0.priority < $1.priority }

        logger.debug("HL7 Routing: Evaluated \(routingRules.count) rules for type='\(messageType)' — \(sorted.count) matched")
        return sorted
    }

    // MARK: - Transformation Application

    /// Applies a transformation rule to the given input fields and returns the transformed output.
    ///
    /// Each ``FieldMapping`` in the rule is applied sequentially. The source value is
    /// looked up in `inputFields` using the mapping's `sourceField` key, transformed
    /// according to the ``FieldOperation``, and written to the output under the
    /// mapping's `targetField` key.
    ///
    /// - Parameters:
    ///   - ruleID: The identifier of the transformation rule to apply.
    ///   - inputFields: A dictionary of field path to value (e.g. `["PID-3": "12345"]`).
    /// - Returns: A dictionary of transformed field values.
    public func applyTransformation(
        ruleID: String,
        inputFields: [String: String]
    ) -> [String: String] {
        guard let rule = transformationRules.first(where: { $0.id == ruleID }) else {
            logger.warning("HL7 Routing: Transformation rule '\(ruleID)' not found")
            return inputFields
        }

        var output: [String: String] = [:]

        for mapping in rule.fieldMappings {
            let sourceValue = inputFields[mapping.sourceField] ?? ""

            let transformed: String
            switch mapping.operation {
            case .copy:
                transformed = sourceValue

            case .mapValue(let valueMapping):
                transformed = valueMapping[sourceValue] ?? sourceValue

            case .setConstant(let value):
                transformed = value

            case .truncate(let maxLength):
                if sourceValue.count > maxLength {
                    transformed = String(sourceValue.prefix(maxLength))
                } else {
                    transformed = sourceValue
                }
            }

            output[mapping.targetField] = transformed
        }

        logger.debug("HL7 Routing: Applied transformation '\(rule.name)' — \(rule.fieldMappings.count) field(s) mapped")
        return output
    }
}
