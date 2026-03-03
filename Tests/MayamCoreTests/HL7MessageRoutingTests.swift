// SPDX-License-Identifier: (see LICENSE)
// Mayam — HL7 Message Routing and Transformation Rule Tests

import XCTest
import Foundation
@testable import MayamCore

// MARK: - HL7RoutingRule Tests

final class HL7RoutingRuleTests: XCTestCase {

    // MARK: - Codable

    func test_routingRule_codable_roundTrips() throws {
        let rule = HL7RoutingRule(
            id: "rule-1",
            name: "Forward ADT",
            sourceMessageType: "ADT",
            sourceSendingApplication: "HIS",
            sourceSendingFacility: "MAIN",
            enabled: true,
            priority: 10,
            action: .forward(destination: "archive:2575")
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(HL7RoutingRule.self, from: data)

        XCTAssertEqual(decoded.id, "rule-1")
        XCTAssertEqual(decoded.name, "Forward ADT")
        XCTAssertEqual(decoded.sourceMessageType, "ADT")
        XCTAssertEqual(decoded.sourceSendingApplication, "HIS")
        XCTAssertEqual(decoded.sourceSendingFacility, "MAIN")
        XCTAssertEqual(decoded.enabled, true)
        XCTAssertEqual(decoded.priority, 10)
        XCTAssertEqual(decoded, rule)
    }

    // MARK: - Equatable

    func test_routingRule_equatable_sameValuesEqual() {
        let ruleA = HL7RoutingRule(
            id: "eq-1",
            name: "Test",
            sourceMessageType: "ORM",
            enabled: true,
            priority: 5,
            action: .discard
        )
        let ruleB = HL7RoutingRule(
            id: "eq-1",
            name: "Test",
            sourceMessageType: "ORM",
            enabled: true,
            priority: 5,
            action: .discard
        )
        XCTAssertEqual(ruleA, ruleB)
    }

    func test_routingRule_equatable_differentValuesNotEqual() {
        let ruleA = HL7RoutingRule(
            id: "ne-1",
            name: "Rule A",
            sourceMessageType: "ADT",
            enabled: true,
            priority: 1,
            action: .forward(destination: "host-a:2575")
        )
        let ruleB = HL7RoutingRule(
            id: "ne-2",
            name: "Rule B",
            sourceMessageType: "ORM",
            enabled: false,
            priority: 99,
            action: .discard
        )
        XCTAssertNotEqual(ruleA, ruleB)
    }
}

// MARK: - RoutingAction Tests

final class RoutingActionTests: XCTestCase {

    func test_routingAction_forward_codable_roundTrips() throws {
        let action = RoutingAction.forward(destination: "pacs.local:2575")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(RoutingAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    func test_routingAction_transform_codable_roundTrips() throws {
        let action = RoutingAction.transform(templateID: "tmpl-normalise")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(RoutingAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    func test_routingAction_discard_codable_roundTrips() throws {
        let action = RoutingAction.discard
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(RoutingAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }

    func test_routingAction_delegate_codable_roundTrips() throws {
        let action = RoutingAction.delegate(handlerName: "custom-handler")
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(RoutingAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }
}

// MARK: - HL7TransformationRule Tests

final class HL7TransformationRuleTests: XCTestCase {

    func test_transformationRule_codable_roundTrips() throws {
        let rule = HL7TransformationRule(
            id: "xform-1",
            name: "Normalise PID",
            description_: "Normalises patient ID fields",
            fieldMappings: [
                FieldMapping(sourceField: "PID-3", targetField: "PID-3", operation: .copy),
                FieldMapping(sourceField: "PID-5", targetField: "PID-5", operation: .truncate(maxLength: 64))
            ]
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(HL7TransformationRule.self, from: data)

        XCTAssertEqual(decoded.id, "xform-1")
        XCTAssertEqual(decoded.name, "Normalise PID")
        XCTAssertEqual(decoded.description_, "Normalises patient ID fields")
        XCTAssertEqual(decoded.fieldMappings.count, 2)
        XCTAssertEqual(decoded, rule)
    }

    func test_transformationRule_descriptionKey_encodesCorrectly() throws {
        let rule = HL7TransformationRule(
            id: "desc-key",
            name: "Desc Test",
            description_: "A description",
            fieldMappings: []
        )
        let data = try JSONEncoder().encode(rule)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // The CodingKey maps description_ -> "description" in JSON
        XCTAssertNotNil(json?["description"])
        XCTAssertNil(json?["description_"])
        XCTAssertEqual(json?["description"] as? String, "A description")
    }

    func test_transformationRule_equatable_sameValuesEqual() {
        let mappings = [FieldMapping(sourceField: "PID-3", targetField: "PID-3", operation: .copy)]
        let a = HL7TransformationRule(id: "eq", name: "Rule", description_: "Desc", fieldMappings: mappings)
        let b = HL7TransformationRule(id: "eq", name: "Rule", description_: "Desc", fieldMappings: mappings)
        XCTAssertEqual(a, b)
    }
}

// MARK: - FieldMapping & FieldOperation Tests

final class FieldMappingTests: XCTestCase {

    func test_fieldMapping_codable_roundTrips() throws {
        let mapping = FieldMapping(
            sourceField: "PID-3",
            targetField: "PID-3-OUT",
            operation: .copy
        )
        let data = try JSONEncoder().encode(mapping)
        let decoded = try JSONDecoder().decode(FieldMapping.self, from: data)
        XCTAssertEqual(decoded, mapping)
    }

    func test_fieldOperation_copy_codable_roundTrips() throws {
        let op = FieldOperation.copy
        let data = try JSONEncoder().encode(op)
        let decoded = try JSONDecoder().decode(FieldOperation.self, from: data)
        XCTAssertEqual(decoded, op)
    }

    func test_fieldOperation_mapValue_codable_roundTrips() throws {
        let op = FieldOperation.mapValue(mapping: ["M": "Male", "F": "Female"])
        let data = try JSONEncoder().encode(op)
        let decoded = try JSONDecoder().decode(FieldOperation.self, from: data)
        XCTAssertEqual(decoded, op)
    }

    func test_fieldOperation_setConstant_codable_roundTrips() throws {
        let op = FieldOperation.setConstant(value: "UNKNOWN")
        let data = try JSONEncoder().encode(op)
        let decoded = try JSONDecoder().decode(FieldOperation.self, from: data)
        XCTAssertEqual(decoded, op)
    }

    func test_fieldOperation_truncate_codable_roundTrips() throws {
        let op = FieldOperation.truncate(maxLength: 32)
        let data = try JSONEncoder().encode(op)
        let decoded = try JSONDecoder().decode(FieldOperation.self, from: data)
        XCTAssertEqual(decoded, op)
    }
}

// MARK: - HL7MessageRoutingService Tests

final class HL7MessageRoutingServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeService() -> HL7MessageRoutingService {
        HL7MessageRoutingService(logger: MayamLogger(label: "test.routing"))
    }

    private func sampleRule(
        id: String = "rule-1",
        messageType: String = "ADT",
        sendingApp: String? = nil,
        sendingFacility: String? = nil,
        enabled: Bool = true,
        priority: Int = 0,
        action: RoutingAction = .forward(destination: "dest:2575")
    ) -> HL7RoutingRule {
        HL7RoutingRule(
            id: id,
            name: "Rule \(id)",
            sourceMessageType: messageType,
            sourceSendingApplication: sendingApp,
            sourceSendingFacility: sendingFacility,
            enabled: enabled,
            priority: priority,
            action: action
        )
    }

    // MARK: - Routing Rule Management

    func test_routingService_addRule_storesRule() async {
        let service = makeService()
        let rule = sampleRule()

        await service.addRoutingRule(rule)

        let rules = await service.getRoutingRules()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first, rule)
    }

    func test_routingService_removeRule_removesCorrectly() async {
        let service = makeService()
        await service.addRoutingRule(sampleRule(id: "a"))
        await service.addRoutingRule(sampleRule(id: "b"))

        let removed = await service.removeRoutingRule(id: "a")
        XCTAssertTrue(removed)

        let rules = await service.getRoutingRules()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.id, "b")
    }

    func test_routingService_removeRule_nonexistent_returnsFalse() async {
        let service = makeService()

        let removed = await service.removeRoutingRule(id: "does-not-exist")
        XCTAssertFalse(removed)
    }

    // MARK: - Routing Evaluation

    func test_routingService_evaluateRouting_matchesMessageType() async {
        let service = makeService()
        await service.addRoutingRule(sampleRule(id: "adt", messageType: "ADT"))
        await service.addRoutingRule(sampleRule(id: "orm", messageType: "ORM"))

        let matches = await service.evaluateRouting(
            messageType: "ADT",
            sendingApplication: nil,
            sendingFacility: nil
        )
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.id, "adt")
    }

    func test_routingService_evaluateRouting_wildcardMatchesAll() async {
        let service = makeService()
        await service.addRoutingRule(sampleRule(id: "catch-all", messageType: "*"))

        let adtMatches = await service.evaluateRouting(
            messageType: "ADT",
            sendingApplication: nil,
            sendingFacility: nil
        )
        let ormMatches = await service.evaluateRouting(
            messageType: "ORM",
            sendingApplication: nil,
            sendingFacility: nil
        )

        XCTAssertEqual(adtMatches.count, 1)
        XCTAssertEqual(ormMatches.count, 1)
        XCTAssertEqual(adtMatches.first?.id, "catch-all")
    }

    func test_routingService_evaluateRouting_disabledRulesExcluded() async {
        let service = makeService()
        await service.addRoutingRule(sampleRule(id: "enabled", messageType: "ADT", enabled: true))
        await service.addRoutingRule(sampleRule(id: "disabled", messageType: "ADT", enabled: false))

        let matches = await service.evaluateRouting(
            messageType: "ADT",
            sendingApplication: nil,
            sendingFacility: nil
        )
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.id, "enabled")
    }

    func test_routingService_evaluateRouting_sortedByPriority() async {
        let service = makeService()
        await service.addRoutingRule(sampleRule(id: "low", messageType: "ADT", priority: 100))
        await service.addRoutingRule(sampleRule(id: "high", messageType: "ADT", priority: 1))
        await service.addRoutingRule(sampleRule(id: "mid", messageType: "ADT", priority: 50))

        let matches = await service.evaluateRouting(
            messageType: "ADT",
            sendingApplication: nil,
            sendingFacility: nil
        )
        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0].id, "high")
        XCTAssertEqual(matches[1].id, "mid")
        XCTAssertEqual(matches[2].id, "low")
    }

    func test_routingService_evaluateRouting_filtersBySendingApplication() async {
        let service = makeService()
        await service.addRoutingRule(sampleRule(id: "his-only", messageType: "ADT", sendingApp: "HIS"))
        await service.addRoutingRule(sampleRule(id: "any-app", messageType: "ADT"))

        let matches = await service.evaluateRouting(
            messageType: "ADT",
            sendingApplication: "HIS",
            sendingFacility: nil
        )
        XCTAssertEqual(matches.count, 2)

        let noMatch = await service.evaluateRouting(
            messageType: "ADT",
            sendingApplication: "RIS",
            sendingFacility: nil
        )
        // "his-only" should not match "RIS", but "any-app" (no filter) still matches.
        XCTAssertEqual(noMatch.count, 1)
        XCTAssertEqual(noMatch.first?.id, "any-app")
    }

    func test_routingService_evaluateRouting_filtersBySendingFacility() async {
        let service = makeService()
        await service.addRoutingRule(sampleRule(id: "main-only", messageType: "ORM", sendingFacility: "MAIN"))
        await service.addRoutingRule(sampleRule(id: "any-fac", messageType: "ORM"))

        let matches = await service.evaluateRouting(
            messageType: "ORM",
            sendingApplication: nil,
            sendingFacility: "MAIN"
        )
        XCTAssertEqual(matches.count, 2)

        let noMatch = await service.evaluateRouting(
            messageType: "ORM",
            sendingApplication: nil,
            sendingFacility: "BRANCH"
        )
        XCTAssertEqual(noMatch.count, 1)
        XCTAssertEqual(noMatch.first?.id, "any-fac")
    }

    // MARK: - Transformation Rule Management

    func test_routingService_addTransformationRule_storesRule() async {
        let service = makeService()
        let rule = HL7TransformationRule(
            id: "xform-1",
            name: "Copy PID",
            fieldMappings: [FieldMapping(sourceField: "PID-3", targetField: "PID-3", operation: .copy)]
        )

        await service.addTransformationRule(rule)

        let rules = await service.getTransformationRules()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first, rule)
    }

    func test_routingService_removeTransformationRule_removesCorrectly() async {
        let service = makeService()
        let ruleA = HL7TransformationRule(id: "xa", name: "A", fieldMappings: [])
        let ruleB = HL7TransformationRule(id: "xb", name: "B", fieldMappings: [])
        await service.addTransformationRule(ruleA)
        await service.addTransformationRule(ruleB)

        let removed = await service.removeTransformationRule(id: "xa")
        XCTAssertTrue(removed)

        let rules = await service.getTransformationRules()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.id, "xb")
    }

    // MARK: - Transformation Application

    func test_routingService_applyTransformation_copy_copiesValue() async {
        let service = makeService()
        let rule = HL7TransformationRule(
            id: "copy-rule",
            name: "Copy",
            fieldMappings: [FieldMapping(sourceField: "PID-3", targetField: "PID-3-OUT", operation: .copy)]
        )
        await service.addTransformationRule(rule)

        let result = await service.applyTransformation(
            ruleID: "copy-rule",
            inputFields: ["PID-3": "12345"]
        )
        XCTAssertEqual(result["PID-3-OUT"], "12345")
    }

    func test_routingService_applyTransformation_mapValue_mapsCorrectly() async {
        let service = makeService()
        let rule = HL7TransformationRule(
            id: "map-rule",
            name: "Map Gender",
            fieldMappings: [
                FieldMapping(
                    sourceField: "PID-8",
                    targetField: "PID-8-OUT",
                    operation: .mapValue(mapping: ["M": "Male", "F": "Female"])
                )
            ]
        )
        await service.addTransformationRule(rule)

        let result = await service.applyTransformation(
            ruleID: "map-rule",
            inputFields: ["PID-8": "M"]
        )
        XCTAssertEqual(result["PID-8-OUT"], "Male")
    }

    func test_routingService_applyTransformation_setConstant_setsValue() async {
        let service = makeService()
        let rule = HL7TransformationRule(
            id: "const-rule",
            name: "Set Constant",
            fieldMappings: [
                FieldMapping(
                    sourceField: "PID-3",
                    targetField: "MSH-4",
                    operation: .setConstant(value: "MAYAM")
                )
            ]
        )
        await service.addTransformationRule(rule)

        let result = await service.applyTransformation(
            ruleID: "const-rule",
            inputFields: ["PID-3": "ignored"]
        )
        XCTAssertEqual(result["MSH-4"], "MAYAM")
    }

    func test_routingService_applyTransformation_truncate_truncatesLongValue() async {
        let service = makeService()
        let rule = HL7TransformationRule(
            id: "trunc-rule",
            name: "Truncate",
            fieldMappings: [
                FieldMapping(
                    sourceField: "PID-5",
                    targetField: "PID-5-OUT",
                    operation: .truncate(maxLength: 5)
                )
            ]
        )
        await service.addTransformationRule(rule)

        let result = await service.applyTransformation(
            ruleID: "trunc-rule",
            inputFields: ["PID-5": "VERYLONGNAME"]
        )
        XCTAssertEqual(result["PID-5-OUT"], "VERYL")
    }

    func test_routingService_applyTransformation_truncate_preservesShortValue() async {
        let service = makeService()
        let rule = HL7TransformationRule(
            id: "trunc-short",
            name: "Truncate Short",
            fieldMappings: [
                FieldMapping(
                    sourceField: "PID-5",
                    targetField: "PID-5-OUT",
                    operation: .truncate(maxLength: 64)
                )
            ]
        )
        await service.addTransformationRule(rule)

        let result = await service.applyTransformation(
            ruleID: "trunc-short",
            inputFields: ["PID-5": "SHORT"]
        )
        XCTAssertEqual(result["PID-5-OUT"], "SHORT")
    }

    func test_routingService_applyTransformation_unknownRule_returnsInput() async {
        let service = makeService()

        let input = ["PID-3": "12345", "PID-5": "DOE^JOHN"]
        let result = await service.applyTransformation(
            ruleID: "nonexistent",
            inputFields: input
        )
        XCTAssertEqual(result, input)
    }
}
