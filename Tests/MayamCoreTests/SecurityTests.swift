// SPDX-License-Identifier: (see LICENSE)
// Mayam — Security Hardening & IHE Compliance Tests

import XCTest
@testable import MayamCore

final class SecurityTests: XCTestCase {

    // MARK: - ATNA Audit Event Tests

    func test_atnaAuditEvent_defaultValues_areCorrect() {
        let event = ATNAAuditEvent(
            eventID: .userAuthentication,
            eventOutcome: .success
        )

        XCTAssertEqual(event.eventID, .userAuthentication)
        XCTAssertEqual(event.eventOutcome, .success)
        XCTAssertEqual(event.auditSourceID, "MAYAM")
        XCTAssertNil(event.eventActionDescription)
        XCTAssertTrue(event.activeParticipants.isEmpty)
        XCTAssertTrue(event.participantObjects.isEmpty)
        XCTAssertNil(event.integrityHash)
    }

    func test_atnaAuditEvent_customValues_arePreserved() {
        let now = Date()
        let participant = ATNAAuditEvent.ActiveParticipant(
            userID: "admin",
            userName: "Administrator",
            userIsRequestor: true,
            networkAccessPointID: "192.168.1.100",
            networkAccessPointTypeCode: 2
        )
        let object = ATNAAuditEvent.ParticipantObject(
            participantObjectTypeCode: 1,
            participantObjectTypeCodeRole: 1,
            participantObjectID: "PAT001",
            participantObjectName: "Patient"
        )
        let event = ATNAAuditEvent(
            eventID: .dicomInstancesAccessed,
            eventOutcome: .success,
            eventDateTime: now,
            eventActionDescription: "Study accessed",
            activeParticipants: [participant],
            participantObjects: [object],
            auditSourceID: "TEST_NODE"
        )

        XCTAssertEqual(event.eventID, .dicomInstancesAccessed)
        XCTAssertEqual(event.eventOutcome, .success)
        XCTAssertEqual(event.eventDateTime, now)
        XCTAssertEqual(event.eventActionDescription, "Study accessed")
        XCTAssertEqual(event.activeParticipants.count, 1)
        XCTAssertEqual(event.activeParticipants[0].userID, "admin")
        XCTAssertEqual(event.activeParticipants[0].userName, "Administrator")
        XCTAssertTrue(event.activeParticipants[0].userIsRequestor)
        XCTAssertEqual(event.activeParticipants[0].networkAccessPointID, "192.168.1.100")
        XCTAssertEqual(event.participantObjects.count, 1)
        XCTAssertEqual(event.participantObjects[0].participantObjectID, "PAT001")
        XCTAssertEqual(event.auditSourceID, "TEST_NODE")
    }

    func test_atnaAuditEvent_codable_roundTrips() throws {
        let event = ATNAAuditEvent(
            eventID: .securityAlert,
            eventOutcome: .seriousFailure,
            eventActionDescription: "Unauthorised access attempt",
            activeParticipants: [
                ATNAAuditEvent.ActiveParticipant(userID: "hacker", userIsRequestor: true)
            ],
            participantObjects: [
                ATNAAuditEvent.ParticipantObject(
                    participantObjectTypeCode: 2,
                    participantObjectTypeCodeRole: 4,
                    participantObjectID: "1.2.3.4.5"
                )
            ]
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ATNAAuditEvent.self, from: data)

        XCTAssertEqual(event, decoded)
    }

    func test_atnaAuditEvent_toAuditMessageXML_containsRequiredElements() {
        let event = ATNAAuditEvent(
            eventID: .userAuthentication,
            eventOutcome: .success,
            activeParticipants: [
                ATNAAuditEvent.ActiveParticipant(
                    userID: "admin",
                    userName: "Admin User",
                    networkAccessPointID: "10.0.0.1"
                )
            ],
            participantObjects: [
                ATNAAuditEvent.ParticipantObject(
                    participantObjectTypeCode: 1,
                    participantObjectTypeCodeRole: 1,
                    participantObjectID: "PAT001",
                    participantObjectName: "Test Patient"
                )
            ],
            auditSourceID: "MAYAM_TEST"
        )

        let xml = event.toAuditMessageXML()

        XCTAssertTrue(xml.contains("<AuditMessage>"))
        XCTAssertTrue(xml.contains("</AuditMessage>"))
        XCTAssertTrue(xml.contains("<EventIdentification"))
        XCTAssertTrue(xml.contains("EventOutcomeIndicator=\"0\""))
        XCTAssertTrue(xml.contains("<EventID code=\"110114\""))
        XCTAssertTrue(xml.contains("<ActiveParticipant"))
        XCTAssertTrue(xml.contains("UserID=\"admin\""))
        XCTAssertTrue(xml.contains("<AuditSourceIdentification AuditSourceID=\"MAYAM_TEST\""))
        XCTAssertTrue(xml.contains("<ParticipantObjectIdentification"))
        XCTAssertTrue(xml.contains("ParticipantObjectID=\"PAT001\""))
    }

    func test_atnaAuditEvent_xmlEscaping_handlesSpecialCharacters() {
        let event = ATNAAuditEvent(
            eventID: .query,
            eventOutcome: .success,
            activeParticipants: [
                ATNAAuditEvent.ActiveParticipant(userID: "user<&>\"test'")
            ]
        )

        let xml = event.toAuditMessageXML()

        XCTAssertTrue(xml.contains("user&lt;&amp;&gt;&quot;test&apos;"))
    }

    func test_atnaAuditEvent_allEventIDs_areCoverable() {
        XCTAssertEqual(ATNAAuditEvent.EventID.allCases.count, 12)
    }

    func test_atnaAuditEvent_allOutcomes_areCoverable() {
        let outcomes = ATNAAuditEvent.EventOutcome.allCases
        XCTAssertEqual(outcomes.count, 4)
        XCTAssertEqual(ATNAAuditEvent.EventOutcome.success.rawValue, 0)
        XCTAssertEqual(ATNAAuditEvent.EventOutcome.minorFailure.rawValue, 4)
        XCTAssertEqual(ATNAAuditEvent.EventOutcome.seriousFailure.rawValue, 8)
        XCTAssertEqual(ATNAAuditEvent.EventOutcome.majorFailure.rawValue, 12)
    }

    func test_atnaAuditEvent_equatable() {
        let id = UUID()
        let now = Date()
        let a = ATNAAuditEvent(id: id, eventID: .query, eventOutcome: .success, eventDateTime: now)
        let b = ATNAAuditEvent(id: id, eventID: .query, eventOutcome: .success, eventDateTime: now)
        XCTAssertEqual(a, b)

        let c = ATNAAuditEvent(eventID: .securityAlert, eventOutcome: .majorFailure)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - ATNA Audit Repository Tests

    func test_atnaAuditRepository_record_storesEvent() async {
        let repo = ATNAAuditRepository(hmacSecret: "test-secret")
        let event = ATNAAuditEvent(eventID: .applicationActivity, eventOutcome: .success)

        let stored = await repo.record(event)

        XCTAssertNotNil(stored.integrityHash)
        let count = await repo.count()
        XCTAssertEqual(count, 1)
    }

    func test_atnaAuditRepository_record_computesIntegrityHash() async {
        let repo = ATNAAuditRepository(hmacSecret: "test-secret")
        let event = ATNAAuditEvent(eventID: .userAuthentication, eventOutcome: .success)

        let stored = await repo.record(event)

        XCTAssertNotNil(stored.integrityHash)
        XCTAssertFalse(stored.integrityHash!.isEmpty)
    }

    func test_atnaAuditRepository_verifyIntegrity_succeedsForUntamperedEvent() async {
        let repo = ATNAAuditRepository(hmacSecret: "test-secret")
        let event = ATNAAuditEvent(eventID: .query, eventOutcome: .success)

        let stored = await repo.record(event)
        let valid = await repo.verifyIntegrity(of: stored)

        XCTAssertTrue(valid)
    }

    func test_atnaAuditRepository_verifyIntegrity_failsForTamperedEvent() async {
        let repo = ATNAAuditRepository(hmacSecret: "test-secret")
        let event = ATNAAuditEvent(eventID: .query, eventOutcome: .success)

        var stored = await repo.record(event)
        stored.integrityHash = "tampered-hash"
        let valid = await repo.verifyIntegrity(of: stored)

        XCTAssertFalse(valid)
    }

    func test_atnaAuditRepository_verifyAllIntegrity_succeeds() async {
        let repo = ATNAAuditRepository(hmacSecret: "test-secret")
        await repo.record(ATNAAuditEvent(eventID: .query, eventOutcome: .success))
        await repo.record(ATNAAuditEvent(eventID: .userAuthentication, eventOutcome: .success))
        await repo.record(ATNAAuditEvent(eventID: .applicationActivity, eventOutcome: .success))

        let valid = await repo.verifyAllIntegrity()

        XCTAssertTrue(valid)
    }

    func test_atnaAuditRepository_eventsByType_filtersCorrectly() async {
        let repo = ATNAAuditRepository(hmacSecret: "test-secret")
        await repo.record(ATNAAuditEvent(eventID: .query, eventOutcome: .success))
        await repo.record(ATNAAuditEvent(eventID: .userAuthentication, eventOutcome: .success))
        await repo.record(ATNAAuditEvent(eventID: .query, eventOutcome: .minorFailure))

        let queryEvents = await repo.events(ofType: .query)

        XCTAssertEqual(queryEvents.count, 2)
    }

    func test_atnaAuditRepository_eventsByUser_filtersCorrectly() async {
        let repo = ATNAAuditRepository(hmacSecret: "test-secret")
        await repo.record(ATNAAuditEvent(
            eventID: .query,
            eventOutcome: .success,
            activeParticipants: [ATNAAuditEvent.ActiveParticipant(userID: "alice")]
        ))
        await repo.record(ATNAAuditEvent(
            eventID: .query,
            eventOutcome: .success,
            activeParticipants: [ATNAAuditEvent.ActiveParticipant(userID: "bob")]
        ))

        let aliceEvents = await repo.events(forUser: "alice")

        XCTAssertEqual(aliceEvents.count, 1)
    }

    func test_atnaAuditRepository_allEvents_returnsAll() async {
        let repo = ATNAAuditRepository(hmacSecret: "test-secret")
        await repo.record(ATNAAuditEvent(eventID: .query, eventOutcome: .success))
        await repo.record(ATNAAuditEvent(eventID: .securityAlert, eventOutcome: .seriousFailure))

        let all = await repo.allEvents()

        XCTAssertEqual(all.count, 2)
    }

    // MARK: - Syslog Exporter Tests

    func test_syslogExporter_disabledByDefault_returnsNil() async {
        let exporter = SyslogExporter()
        let event = ATNAAuditEvent(eventID: .query, eventOutcome: .success)

        let result = await exporter.export(event)

        XCTAssertNil(result)
    }

    func test_syslogExporter_enabled_formatsSyslogMessage() async {
        let config = SyslogExporter.Configuration(
            enabled: true,
            host: "syslog.example.com",
            port: 6514,
            transport: .tls,
            appName: "mayam-test"
        )
        let exporter = SyslogExporter(configuration: config)
        let event = ATNAAuditEvent(
            eventID: .userAuthentication,
            eventOutcome: .success,
            auditSourceID: "MAYAM_TEST"
        )

        let message = await exporter.export(event)

        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("<86>"))  // priority = 10*8 + 6 = 86
        XCTAssertTrue(message!.contains("mayam-test"))
        XCTAssertTrue(message!.contains("110114"))  // userAuthentication event ID
        XCTAssertTrue(message!.contains("<AuditMessage>"))
    }

    func test_syslogExporter_tracksExportedCount() async {
        let config = SyslogExporter.Configuration(enabled: true)
        let exporter = SyslogExporter(configuration: config)

        await exporter.export(ATNAAuditEvent(eventID: .query, eventOutcome: .success))
        await exporter.export(ATNAAuditEvent(eventID: .query, eventOutcome: .success))

        let count = await exporter.totalExported()
        XCTAssertEqual(count, 2)
    }

    func test_syslogExporter_pendingMessages_queuesCorrectly() async {
        let config = SyslogExporter.Configuration(enabled: true)
        let exporter = SyslogExporter(configuration: config)

        await exporter.export(ATNAAuditEvent(eventID: .query, eventOutcome: .success))

        let pending = await exporter.pending()
        XCTAssertEqual(pending.count, 1)

        await exporter.clearPending()
        let cleared = await exporter.pending()
        XCTAssertTrue(cleared.isEmpty)
    }

    func test_syslogExporter_configuration_codable_roundTrips() throws {
        let config = SyslogExporter.Configuration(
            enabled: true,
            host: "syslog.local",
            port: 514,
            transport: .udp,
            facility: 10,
            appName: "mayam"
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(SyslogExporter.Configuration.self, from: data)

        XCTAssertEqual(config, decoded)
    }

    func test_syslogExporter_allTransports_areCoverable() {
        XCTAssertEqual(SyslogExporter.Transport.allCases.count, 3)
    }

    // MARK: - Anonymisation Profile Tests

    func test_anonymisationProfile_allCases() {
        XCTAssertEqual(AnonymisationProfile.allCases.count, 7)
    }

    func test_anonymisationProfile_codable_roundTrips() throws {
        for profile in AnonymisationProfile.allCases {
            let data = try JSONEncoder().encode(profile)
            let decoded = try JSONDecoder().decode(AnonymisationProfile.self, from: data)
            XCTAssertEqual(profile, decoded)
        }
    }

    func test_anonymisationAction_allCases() {
        XCTAssertEqual(AnonymisationAction.allCases.count, 6)
    }

    func test_anonymisationRule_tagString_formatsCorrectly() {
        let rule = AnonymisationRule(
            tagGroup: 0x0010,
            tagElement: 0x0020,
            attributeName: "Patient ID",
            action: .dummy
        )
        XCTAssertEqual(rule.tagString, "(0010,0020)")
    }

    func test_anonymisationRule_codable_roundTrips() throws {
        let rule = AnonymisationRule(
            tagGroup: 0x0008,
            tagElement: 0x0050,
            attributeName: "Accession Number",
            action: .zeroLength
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(AnonymisationRule.self, from: data)
        XCTAssertEqual(rule, decoded)
    }

    // MARK: - DICOM Anonymiser Tests

    func test_dicomAnonymiser_basicProfile_removesPatientName() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile])
        let attributes: [String: String] = [
            "(0010,0010)": "DOE^JOHN",
            "(0010,0020)": "PAT001",
            "(0008,0060)": "CT"  // Modality — should remain
        ]

        let result = await anonymiser.anonymise(attributes)

        XCTAssertEqual(result["(0010,0010)"], "ANONYMISED")
        XCTAssertEqual(result["(0010,0020)"], "ANONYMISED")
        XCTAssertEqual(result["(0008,0060)"], "CT")
    }

    func test_dicomAnonymiser_basicProfile_removesDateTags() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile])
        let attributes: [String: String] = [
            "(0010,0030)": "19800101",  // Patient Birth Date
            "(0008,0020)": "20260101",  // Study Date
            "(0008,0060)": "MR"         // Modality
        ]

        let result = await anonymiser.anonymise(attributes)

        XCTAssertNil(result["(0010,0030)"])
        XCTAssertNil(result["(0008,0020)"])
        XCTAssertEqual(result["(0008,0060)"], "MR")
    }

    func test_dicomAnonymiser_basicProfile_zeroLengthsAccessionNumber() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile])
        let attributes: [String: String] = [
            "(0008,0050)": "ACC001"
        ]

        let result = await anonymiser.anonymise(attributes)

        XCTAssertEqual(result["(0008,0050)"], "")
    }

    func test_dicomAnonymiser_basicProfile_replacesUIDs() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile], pseudonymSalt: "test-salt")
        let attributes: [String: String] = [
            "(0020,000D)": "1.2.840.113619.2.1"
        ]

        let result = await anonymiser.anonymise(attributes)

        XCTAssertNotEqual(result["(0020,000D)"], "1.2.840.113619.2.1")
        XCTAssertTrue(result["(0020,000D)"]!.hasPrefix("2.25."))
    }

    func test_dicomAnonymiser_retainLongFullDates_keepsDateTags() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile, .retainLongFullDates])
        let attributes: [String: String] = [
            "(0008,0020)": "20260101",
            "(0010,0030)": "19800101",
            "(0010,0010)": "DOE^JOHN"
        ]

        let result = await anonymiser.anonymise(attributes)

        XCTAssertEqual(result["(0008,0020)"], "20260101")
        XCTAssertEqual(result["(0010,0030)"], "19800101")
        XCTAssertEqual(result["(0010,0010)"], "ANONYMISED")
    }

    func test_dicomAnonymiser_retainPatientCharacteristics_keepsCharacteristics() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile, .retainPatientCharacteristics])
        let attributes: [String: String] = [
            "(0010,0040)": "M",       // Patient Sex
            "(0010,1010)": "045Y",    // Patient Age
            "(0010,1020)": "1.80",    // Patient Size
            "(0010,1030)": "80.5",    // Patient Weight
            "(0010,0010)": "DOE^JOHN" // Patient Name — still anonymised
        ]

        let result = await anonymiser.anonymise(attributes)

        XCTAssertEqual(result["(0010,0040)"], "M")
        XCTAssertEqual(result["(0010,1010)"], "045Y")
        XCTAssertEqual(result["(0010,1020)"], "1.80")
        XCTAssertEqual(result["(0010,1030)"], "80.5")
        XCTAssertEqual(result["(0010,0010)"], "ANONYMISED")
    }

    func test_dicomAnonymiser_retainUIDs_keepsOriginalUIDs() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile, .retainUIDs])
        let attributes: [String: String] = [
            "(0020,000D)": "1.2.840.113619.2.1",
            "(0020,000E)": "1.2.840.113619.2.2"
        ]

        let result = await anonymiser.anonymise(attributes)

        XCTAssertEqual(result["(0020,000D)"], "1.2.840.113619.2.1")
        XCTAssertEqual(result["(0020,000E)"], "1.2.840.113619.2.2")
    }

    func test_dicomAnonymiser_retainDeviceIdentity_keepsDeviceInfo() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile, .retainDeviceIdentity])
        let attributes: [String: String] = [
            "(0008,1010)": "CT_SCANNER_01",  // Station Name
            "(0018,1000)": "SN12345",         // Device Serial Number
            "(0010,0010)": "DOE^JOHN"
        ]

        let result = await anonymiser.anonymise(attributes)

        XCTAssertEqual(result["(0008,1010)"], "CT_SCANNER_01")
        XCTAssertEqual(result["(0018,1000)"], "SN12345")
        XCTAssertEqual(result["(0010,0010)"], "ANONYMISED")
    }

    func test_dicomAnonymiser_pseudonymousUID_isDeterministic() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile], pseudonymSalt: "fixed-salt")
        let attributes1: [String: String] = ["(0020,000D)": "1.2.3.4.5"]
        let attributes2: [String: String] = ["(0020,000D)": "1.2.3.4.5"]

        let result1 = await anonymiser.anonymise(attributes1)
        let result2 = await anonymiser.anonymise(attributes2)

        XCTAssertEqual(result1["(0020,000D)"], result2["(0020,000D)"])
    }

    func test_dicomAnonymiser_currentRules_returnsRules() async {
        let anonymiser = DICOMAnonymiser(profiles: [.basicProfile])
        let rules = await anonymiser.currentRules()
        XCTAssertFalse(rules.isEmpty)
    }

    func test_dicomAnonymiser_activeProfiles_returnsProfiles() async {
        let profiles: Set<AnonymisationProfile> = [.basicProfile, .retainLongFullDates]
        let anonymiser = DICOMAnonymiser(profiles: profiles)
        let active = await anonymiser.activeProfiles()
        XCTAssertEqual(active, profiles)
    }

    // MARK: - Access Control Entry Tests

    func test_accessControlEntry_defaultValues_areCorrect() {
        let entry = AccessControlEntry(
            entityType: .patient,
            entityID: 1,
            principalType: .user,
            principalID: "admin",
            permission: .allow
        )

        XCTAssertNil(entry.id)
        XCTAssertEqual(entry.entityType, .patient)
        XCTAssertEqual(entry.entityID, 1)
        XCTAssertEqual(entry.principalType, .user)
        XCTAssertEqual(entry.principalID, "admin")
        XCTAssertEqual(entry.permission, .allow)
        XCTAssertNil(entry.createdBy)
        XCTAssertNil(entry.createdAt)
    }

    func test_accessControlEntry_codable_roundTrips() throws {
        let entry = AccessControlEntry(
            id: 1,
            entityType: .study,
            entityID: 42,
            principalType: .role,
            principalID: "physician",
            permission: .allow,
            createdBy: "admin"
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(AccessControlEntry.self, from: data)

        XCTAssertEqual(entry, decoded)
    }

    func test_accessControlEntry_equatable() {
        let a = AccessControlEntry(entityType: .patient, entityID: 1, principalType: .user, principalID: "alice", permission: .allow)
        let b = AccessControlEntry(entityType: .patient, entityID: 1, principalType: .user, principalID: "alice", permission: .allow)
        XCTAssertEqual(a, b)

        let c = AccessControlEntry(entityType: .patient, entityID: 1, principalType: .user, principalID: "bob", permission: .deny)
        XCTAssertNotEqual(a, c)
    }

    func test_accessControlEntry_allEntityTypes_areCoverable() {
        XCTAssertEqual(AccessControlEntry.EntityType.allCases.count, 2)
    }

    func test_accessControlEntry_allPrincipalTypes_areCoverable() {
        XCTAssertEqual(AccessControlEntry.PrincipalType.allCases.count, 2)
    }

    func test_accessControlEntry_allPermissions_areCoverable() {
        XCTAssertEqual(AccessControlEntry.AccessPermission.allCases.count, 2)
    }

    // MARK: - Access Control Service Tests

    func test_accessControlService_addEntry_addsSuccessfully() async {
        let service = AccessControlService()
        let entry = AccessControlEntry(
            entityType: .patient,
            entityID: 1,
            principalType: .user,
            principalID: "alice",
            permission: .allow
        )

        await service.addEntry(entry)
        let all = await service.allEntries()

        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].principalID, "alice")
    }

    func test_accessControlService_removeEntry_removesSuccessfully() async {
        let service = AccessControlService()
        let entry = AccessControlEntry(
            id: 1,
            entityType: .patient,
            entityID: 1,
            principalType: .user,
            principalID: "alice",
            permission: .allow
        )

        await service.addEntry(entry)
        let removed = await service.removeEntry(id: 1)

        XCTAssertTrue(removed)
        let all = await service.allEntries()
        XCTAssertTrue(all.isEmpty)
    }

    func test_accessControlService_removeEntry_returnsFalseForMissing() async {
        let service = AccessControlService()
        let removed = await service.removeEntry(id: 999)
        XCTAssertFalse(removed)
    }

    func test_accessControlService_entriesForEntity_filtersCorrectly() async {
        let service = AccessControlService()
        await service.addEntry(AccessControlEntry(entityType: .patient, entityID: 1, principalType: .user, principalID: "alice", permission: .allow))
        await service.addEntry(AccessControlEntry(entityType: .patient, entityID: 2, principalType: .user, principalID: "bob", permission: .allow))
        await service.addEntry(AccessControlEntry(entityType: .study, entityID: 1, principalType: .user, principalID: "carol", permission: .allow))

        let patientEntries = await service.entries(for: .patient, entityID: 1)

        XCTAssertEqual(patientEntries.count, 1)
        XCTAssertEqual(patientEntries[0].principalID, "alice")
    }

    func test_accessControlService_isAuthorised_administratorAlwaysAllowed() async {
        let service = AccessControlService()

        let result = await service.isAuthorised(
            username: "admin",
            role: .administrator,
            entityType: .patient,
            entityID: 1
        )

        XCTAssertTrue(result)
    }

    func test_accessControlService_isAuthorised_defaultDenyWhenNoEntries() async {
        let service = AccessControlService()

        let result = await service.isAuthorised(
            username: "alice",
            role: .physician,
            entityType: .patient,
            entityID: 1
        )

        XCTAssertFalse(result)
    }

    func test_accessControlService_isAuthorised_allowedByUserEntry() async {
        let service = AccessControlService()
        await service.addEntry(AccessControlEntry(entityType: .patient, entityID: 1, principalType: .user, principalID: "alice", permission: .allow))

        let result = await service.isAuthorised(
            username: "alice",
            role: .physician,
            entityType: .patient,
            entityID: 1
        )

        XCTAssertTrue(result)
    }

    func test_accessControlService_isAuthorised_allowedByRoleEntry() async {
        let service = AccessControlService()
        await service.addEntry(AccessControlEntry(entityType: .study, entityID: 42, principalType: .role, principalID: "physician", permission: .allow))

        let result = await service.isAuthorised(
            username: "dr_smith",
            role: .physician,
            entityType: .study,
            entityID: 42
        )

        XCTAssertTrue(result)
    }

    func test_accessControlService_isAuthorised_denyOverridesAllow() async {
        let service = AccessControlService()
        await service.addEntry(AccessControlEntry(entityType: .patient, entityID: 1, principalType: .role, principalID: "physician", permission: .allow))
        await service.addEntry(AccessControlEntry(entityType: .patient, entityID: 1, principalType: .user, principalID: "dr_smith", permission: .deny))

        let result = await service.isAuthorised(
            username: "dr_smith",
            role: .physician,
            entityType: .patient,
            entityID: 1
        )

        XCTAssertFalse(result)
    }

    // MARK: - Delete Protection Service Tests

    func test_deleteProtectionService_patient_protectedPreventsRemoval() async {
        let service = DeleteProtectionService()
        let patient = Patient(patientID: "PAT001", deleteProtect: true)

        do {
            try await service.validateDeletion(of: patient)
            XCTFail("Expected DeleteProtectionError to be thrown")
        } catch let error as DeleteProtectionService.DeleteProtectionError {
            XCTAssertEqual(error, .patientProtected(patientID: "PAT001"))
            XCTAssertTrue(error.description.contains("PAT001"))
            XCTAssertTrue(error.description.contains("delete-protected"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_deleteProtectionService_patient_unprotectedAllowsRemoval() async throws {
        let service = DeleteProtectionService()
        let patient = Patient(patientID: "PAT002", deleteProtect: false)

        try await service.validateDeletion(of: patient)
        // No throw means success.
    }

    func test_deleteProtectionService_accession_protectedPreventsRemoval() async {
        let service = DeleteProtectionService()
        let accession = Accession(accessionNumber: "ACC001", patientID: 1, deleteProtect: true)

        do {
            try await service.validateDeletion(of: accession)
            XCTFail("Expected DeleteProtectionError to be thrown")
        } catch let error as DeleteProtectionService.DeleteProtectionError {
            XCTAssertEqual(error, .accessionProtected(accessionNumber: "ACC001"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_deleteProtectionService_accession_unprotectedAllowsRemoval() async throws {
        let service = DeleteProtectionService()
        let accession = Accession(accessionNumber: "ACC002", patientID: 1, deleteProtect: false)

        try await service.validateDeletion(of: accession)
    }

    func test_deleteProtectionService_study_protectedPreventsRemoval() async {
        let service = DeleteProtectionService()
        let study = Study(studyInstanceUID: "1.2.3.4.5", patientID: 1, deleteProtect: true)

        do {
            try await service.validateDeletion(of: study)
            XCTFail("Expected DeleteProtectionError to be thrown")
        } catch let error as DeleteProtectionService.DeleteProtectionError {
            XCTAssertEqual(error, .studyProtected(studyInstanceUID: "1.2.3.4.5"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_deleteProtectionService_study_unprotectedAllowsRemoval() async throws {
        let service = DeleteProtectionService()
        let study = Study(studyInstanceUID: "1.2.3.4.6", patientID: 1, deleteProtect: false)

        try await service.validateDeletion(of: study)
    }

    func test_deleteProtectionService_withAuditRepository_recordsEvent() async {
        let auditRepo = ATNAAuditRepository(hmacSecret: "test")
        let service = DeleteProtectionService(auditRepository: auditRepo)
        let patient = Patient(patientID: "PAT001", deleteProtect: true)

        do {
            try await service.validateDeletion(of: patient)
        } catch {
            // Expected.
        }

        let count = await auditRepo.count()
        XCTAssertEqual(count, 1)
    }

    // MARK: - Privacy Flag Service Tests

    func test_privacyFlagService_filterPatients_removesPrivateForUnauthorised() async {
        let service = PrivacyFlagService()
        let patients = [
            Patient(id: 1, patientID: "PAT001", privacyFlag: false),
            Patient(id: 2, patientID: "PAT002", privacyFlag: true),
            Patient(id: 3, patientID: "PAT003", privacyFlag: false)
        ]

        let filtered = await service.filterPatients(patients, forUser: "dr_smith", role: .physician)

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { !$0.privacyFlag })
    }

    func test_privacyFlagService_filterPatients_administratorSeesAll() async {
        let service = PrivacyFlagService()
        let patients = [
            Patient(id: 1, patientID: "PAT001", privacyFlag: true),
            Patient(id: 2, patientID: "PAT002", privacyFlag: true)
        ]

        let filtered = await service.filterPatients(patients, forUser: "admin", role: .administrator)

        XCTAssertEqual(filtered.count, 2)
    }

    func test_privacyFlagService_filterPatients_authorisedUserSeesPrivate() async {
        let acl = AccessControlService()
        await acl.addEntry(AccessControlEntry(entityType: .patient, entityID: 2, principalType: .user, principalID: "dr_smith", permission: .allow))
        let service = PrivacyFlagService(accessControlService: acl)

        let patients = [
            Patient(id: 1, patientID: "PAT001", privacyFlag: false),
            Patient(id: 2, patientID: "PAT002", privacyFlag: true)
        ]

        let filtered = await service.filterPatients(patients, forUser: "dr_smith", role: .physician)

        XCTAssertEqual(filtered.count, 2)
    }

    func test_privacyFlagService_filterStudies_removesPrivateForUnauthorised() async {
        let service = PrivacyFlagService()
        let studies = [
            Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1, privacyFlag: false),
            Study(id: 2, studyInstanceUID: "1.2.4", patientID: 1, privacyFlag: true)
        ]

        let filtered = await service.filterStudies(studies, forUser: "tech", role: .technologist)

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].studyInstanceUID, "1.2.3")
    }

    func test_privacyFlagService_filterStudies_administratorSeesAll() async {
        let service = PrivacyFlagService()
        let studies = [
            Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1, privacyFlag: true),
            Study(id: 2, studyInstanceUID: "1.2.4", patientID: 1, privacyFlag: true)
        ]

        let filtered = await service.filterStudies(studies, forUser: "admin", role: .administrator)

        XCTAssertEqual(filtered.count, 2)
    }

    func test_privacyFlagService_validateAccess_nonPrivatePatientAllowed() async throws {
        let service = PrivacyFlagService()
        let patient = Patient(patientID: "PAT001", privacyFlag: false)

        try await service.validateAccess(to: patient, username: "anyone", role: .auditor)
    }

    func test_privacyFlagService_validateAccess_privatePatientDenied() async {
        let service = PrivacyFlagService()
        let patient = Patient(id: 1, patientID: "PAT001", privacyFlag: true)

        do {
            try await service.validateAccess(to: patient, username: "tech", role: .technologist)
            XCTFail("Expected PrivacyError to be thrown")
        } catch let error as PrivacyFlagService.PrivacyError {
            XCTAssertEqual(error, .patientAccessDenied(patientID: "PAT001"))
            XCTAssertTrue(error.description.contains("privacy flag"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_privacyFlagService_validateAccess_administratorExempt() async throws {
        let service = PrivacyFlagService()
        let patient = Patient(id: 1, patientID: "PAT001", privacyFlag: true)

        try await service.validateAccess(to: patient, username: "admin", role: .administrator)
    }

    func test_privacyFlagService_validateAccess_privateStudyDenied() async {
        let service = PrivacyFlagService()
        let study = Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1, privacyFlag: true)

        do {
            try await service.validateAccess(to: study, username: "tech", role: .technologist)
            XCTFail("Expected PrivacyError to be thrown")
        } catch let error as PrivacyFlagService.PrivacyError {
            XCTAssertEqual(error, .studyAccessDenied(studyInstanceUID: "1.2.3"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_privacyFlagService_validateAccess_authorisedUserAllowed() async throws {
        let acl = AccessControlService()
        await acl.addEntry(AccessControlEntry(entityType: .study, entityID: 1, principalType: .user, principalID: "dr_jones", permission: .allow))
        let service = PrivacyFlagService(accessControlService: acl)

        let study = Study(id: 1, studyInstanceUID: "1.2.3", patientID: 1, privacyFlag: true)

        try await service.validateAccess(to: study, username: "dr_jones", role: .physician)
    }

    func test_privacyFlagService_shouldRoute_nonPrivateStudyRouted() async {
        let service = PrivacyFlagService()
        let study = Study(studyInstanceUID: "1.2.3", patientID: 1, privacyFlag: false)

        let should = await service.shouldRoute(study: study)

        XCTAssertTrue(should)
    }

    func test_privacyFlagService_shouldRoute_privateStudyExcluded() async {
        let service = PrivacyFlagService()
        let study = Study(studyInstanceUID: "1.2.3", patientID: 1, privacyFlag: true)

        let should = await service.shouldRoute(study: study)

        XCTAssertFalse(should)
    }

    func test_privacyFlagService_shouldRoute_privateStudyRoutedWithOverride() async {
        let service = PrivacyFlagService()
        let study = Study(studyInstanceUID: "1.2.3", patientID: 1, privacyFlag: true)

        let should = await service.shouldRoute(study: study, overrideEnabled: true)

        XCTAssertTrue(should)
    }

    func test_privacyFlagService_withAuditRepository_recordsEvent() async {
        let auditRepo = ATNAAuditRepository(hmacSecret: "test")
        let service = PrivacyFlagService(auditRepository: auditRepo)
        let patient = Patient(id: 1, patientID: "PAT001", privacyFlag: true)

        do {
            try await service.validateAccess(to: patient, username: "tech", role: .technologist)
        } catch {
            // Expected.
        }

        let count = await auditRepo.count()
        XCTAssertEqual(count, 1)
    }

    // MARK: - IHE Integration Statement Tests

    func test_iheIntegrationStatement_allProfiles_areCoverable() {
        XCTAssertEqual(IHEIntegrationStatement.Profile.allCases.count, 6)
    }

    func test_iheIntegrationStatement_allActors_areCoverable() {
        XCTAssertEqual(IHEIntegrationStatement.Actor.allCases.count, 7)
    }

    func test_iheIntegrationStatement_allOptions_areCoverable() {
        XCTAssertEqual(IHEIntegrationStatement.ProfileOption.allCases.count, 6)
    }

    func test_iheIntegrationStatement_allStatements_returnsExpectedProfiles() {
        let statements = IHEIntegrationStatement.allStatements()

        XCTAssertEqual(statements.count, 6)

        let profiles = Set(statements.map(\.profile))
        XCTAssertTrue(profiles.contains(.scheduledWorkflow))
        XCTAssertTrue(profiles.contains(.patientInformationReconciliation))
        XCTAssertTrue(profiles.contains(.consistentPresentationOfImages))
        XCTAssertTrue(profiles.contains(.keyImageNote))
        XCTAssertTrue(profiles.contains(.xdsImaging))
        XCTAssertTrue(profiles.contains(.auditTrailNodeAuthentication))
    }

    func test_iheIntegrationStatement_codable_roundTrips() throws {
        let statement = IHEIntegrationStatement(
            profile: .scheduledWorkflow,
            actors: [.imageArchive, .imageManager],
            options: [.dicomStorageAndRetrieval],
            notes: "Test note"
        )

        let data = try JSONEncoder().encode(statement)
        let decoded = try JSONDecoder().decode(IHEIntegrationStatement.self, from: data)

        XCTAssertEqual(statement, decoded)
    }

    func test_iheIntegrationStatement_equatable() {
        let id = UUID()
        let now = Date()
        let a = IHEIntegrationStatement(id: id, profile: .scheduledWorkflow, actors: [.imageArchive], statementDate: now)
        let b = IHEIntegrationStatement(id: id, profile: .scheduledWorkflow, actors: [.imageArchive], statementDate: now)
        XCTAssertEqual(a, b)
    }

    func test_iheIntegrationStatement_swfProfile_hasCorrectActors() {
        let statements = IHEIntegrationStatement.allStatements()
        let swf = statements.first { $0.profile == .scheduledWorkflow }

        XCTAssertNotNil(swf)
        XCTAssertTrue(swf!.actors.contains(.imageArchive))
        XCTAssertTrue(swf!.actors.contains(.imageManager))
        XCTAssertTrue(swf!.actors.contains(.orderFiller))
    }

    func test_iheIntegrationStatement_atnaProfile_hasCorrectActors() {
        let statements = IHEIntegrationStatement.allStatements()
        let atna = statements.first { $0.profile == .auditTrailNodeAuthentication }

        XCTAssertNotNil(atna)
        XCTAssertTrue(atna!.actors.contains(.secureNode))
        XCTAssertTrue(atna!.actors.contains(.auditRecordRepository))
        XCTAssertTrue(atna!.options.contains(.auditTrail))
        XCTAssertTrue(atna!.options.contains(.tlsNodeAuthentication))
    }

    // MARK: - Security Configuration Tests

    func test_securityConfiguration_defaultValues_areCorrect() {
        let config = ServerConfiguration.Security()

        XCTAssertFalse(config.atnaEnabled)
        XCTAssertEqual(config.atnaHMACSecret, "change-me-in-production")
        XCTAssertFalse(config.syslog.enabled)
        XCTAssertFalse(config.anonymisationEnabled)
        XCTAssertFalse(config.aclEnabled)
        XCTAssertTrue(config.deleteProtectionEnabled)
        XCTAssertTrue(config.privacyFlagEnabled)
    }

    func test_securityConfiguration_codable_roundTrips() throws {
        let config = ServerConfiguration.Security(
            atnaEnabled: true,
            atnaHMACSecret: "test-secret",
            syslog: SyslogExporter.Configuration(enabled: true, host: "syslog.local"),
            anonymisationEnabled: true,
            aclEnabled: true,
            deleteProtectionEnabled: true,
            privacyFlagEnabled: true
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ServerConfiguration.Security.self, from: data)

        XCTAssertEqual(config, decoded)
    }

    func test_serverConfiguration_securitySection_existsInConfig() {
        let config = ServerConfiguration()

        XCTAssertFalse(config.security.atnaEnabled)
        XCTAssertTrue(config.security.deleteProtectionEnabled)
        XCTAssertTrue(config.security.privacyFlagEnabled)
    }

    func test_serverConfiguration_withSecurity_codable_roundTrips() throws {
        var config = ServerConfiguration()
        config.security = ServerConfiguration.Security(atnaEnabled: true)

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ServerConfiguration.self, from: data)

        XCTAssertEqual(config.security, decoded.security)
    }
}
