// SPDX-License-Identifier: (see LICENSE)
// Mayam — LDAP, Permission, and User Directory Tests

import XCTest
import Foundation
@testable import MayamCore

// MARK: - LDAPBERCoderTests

final class LDAPBERCoderTests: XCTestCase {

    // MARK: - BEREncoder Tests

    func test_encodeBoolean_true_producesExpectedBytes() {
        let bytes = BEREncoder.encodeBoolean(true)
        XCTAssertEqual(bytes, [0x01, 0x01, 0xFF])
    }

    func test_encodeBoolean_false_producesExpectedBytes() {
        let bytes = BEREncoder.encodeBoolean(false)
        XCTAssertEqual(bytes, [0x01, 0x01, 0x00])
    }

    func test_encodeInteger_zero_producesExpectedBytes() {
        let bytes = BEREncoder.encodeInteger(0)
        XCTAssertEqual(bytes, [0x02, 0x01, 0x00])
    }

    func test_encodeInteger_positive_encodesCorrectly() {
        let bytes = BEREncoder.encodeInteger(3)
        XCTAssertEqual(bytes[0], 0x02)         // tag
        XCTAssertEqual(bytes[1], 0x01)         // length = 1
        XCTAssertEqual(bytes[2], 0x03)         // value = 3
    }

    func test_encodeInteger_negative_encodesCorrectly() {
        let bytes = BEREncoder.encodeInteger(-1)
        XCTAssertEqual(bytes[0], 0x02)         // tag
        XCTAssertEqual(bytes.last, 0xFF)       // minimal signed -1
    }

    func test_encodeInteger_large_producesMultiByteValue() {
        let bytes = BEREncoder.encodeInteger(256)
        XCTAssertEqual(bytes[0], 0x02)
        // 256 = 0x0100 — requires 2 bytes with sign extension
        XCTAssertGreaterThan(bytes.count, 3)
    }

    func test_encodeEnumerated_zero_producesExpectedTag() {
        let bytes = BEREncoder.encodeEnumerated(0)
        XCTAssertEqual(bytes[0], 0x0A)         // ENUMERATED tag
        XCTAssertEqual(bytes[1], 0x01)
        XCTAssertEqual(bytes[2], 0x00)
    }

    func test_encodeOctetString_empty_producesZeroLengthTLV() {
        let bytes = BEREncoder.encodeOctetString([])
        XCTAssertEqual(bytes, [0x04, 0x00])
    }

    func test_encodeOctetString_string_encodesUTF8() {
        let bytes = BEREncoder.encodeOctetString("hi")
        XCTAssertEqual(bytes[0], 0x04)         // OCTET STRING tag
        XCTAssertEqual(bytes[1], 0x02)         // length = 2
        XCTAssertEqual(bytes[2], UInt8(ascii: "h"))
        XCTAssertEqual(bytes[3], UInt8(ascii: "i"))
    }

    func test_encodeSequence_wrapsContentsCorrectly() {
        let contents: [UInt8] = [0x01, 0x02, 0x03]
        let seq = BEREncoder.encodeSequence(contents)
        XCTAssertEqual(seq[0], 0x30)           // SEQUENCE tag
        XCTAssertEqual(seq[1], 0x03)           // length
        XCTAssertEqual(Array(seq[2...]), contents)
    }

    func test_encodeTagged_contextPrimitive_setsCorrectTag() {
        let tagged = BEREncoder.encodeTagged(tag: BERTag.contextPrimitive(0), contents: [0xAB])
        XCTAssertEqual(tagged[0], 0x80)
    }

    func test_encodeTagged_contextConstructed_setsCorrectTag() {
        let tagged = BEREncoder.encodeTagged(tag: BERTag.contextConstructed(3), contents: [0x01])
        XCTAssertEqual(tagged[0], 0xA3)
    }

    func test_encodeLength_shortForm_singleByte() {
        let len = BEREncoder.encodeLength(127)
        XCTAssertEqual(len, [0x7F])
    }

    func test_encodeLength_longForm_twoBytes() {
        let len = BEREncoder.encodeLength(128)
        XCTAssertEqual(len[0], 0x81)
        XCTAssertEqual(len[1], 0x80)
    }

    // MARK: - BERDecoder Tests

    func test_readTLV_integer_decodesCorrectly() throws {
        let bytes: [UInt8] = [0x02, 0x01, 0x07]
        var offset = 0
        let (tag, value) = try BERDecoder.readTLV(from: bytes, offset: &offset)
        XCTAssertEqual(tag, 0x02)
        XCTAssertEqual(value, [0x07])
        XCTAssertEqual(offset, 3)
    }

    func test_readInteger_decodesPositiveValue() throws {
        let bytes = BEREncoder.encodeInteger(42)
        var offset = 0
        let value = try BERDecoder.readInteger(from: bytes, offset: &offset)
        XCTAssertEqual(value, 42)
    }

    func test_readInteger_decodesNegativeValue() throws {
        let bytes = BEREncoder.encodeInteger(-5)
        var offset = 0
        let value = try BERDecoder.readInteger(from: bytes, offset: &offset)
        XCTAssertEqual(value, -5)
    }

    func test_readInteger_wrongTag_throwsUnexpectedTag() {
        let bytes: [UInt8] = [0x04, 0x01, 0x00]   // OCTET STRING, not INTEGER
        var offset = 0
        XCTAssertThrowsError(try BERDecoder.readInteger(from: bytes, offset: &offset)) { error in
            guard case BERDecoder.Error.unexpectedTag = error else {
                XCTFail("Expected unexpectedTag, got \(error)")
                return
            }
        }
    }

    func test_readOctetString_decodesUTF8() throws {
        let bytes = BEREncoder.encodeOctetString("hello")
        var offset = 0
        let decoded = try BERDecoder.readOctetString(from: bytes, offset: &offset)
        XCTAssertEqual(decoded, "hello")
    }

    func test_readEnumerated_decodesValue() throws {
        let bytes = BEREncoder.encodeEnumerated(49)
        var offset = 0
        let value = try BERDecoder.readEnumerated(from: bytes, offset: &offset)
        XCTAssertEqual(value, 49)
    }

    func test_readSequence_decodesContents() throws {
        let inner = BEREncoder.encodeInteger(1)
        let seq = BEREncoder.encodeSequence(inner)
        var offset = 0
        let contents = try BERDecoder.readSequence(from: seq, offset: &offset)
        XCTAssertEqual(contents, inner)
    }

    func test_readTLV_truncated_throwsTruncated() {
        let bytes: [UInt8] = [0x02, 0x03, 0x01]   // claims 3 bytes but only 1 present
        var offset = 0
        XCTAssertThrowsError(try BERDecoder.readTLV(from: bytes, offset: &offset)) { error in
            guard case BERDecoder.Error.truncated = error else {
                XCTFail("Expected truncated, got \(error)")
                return
            }
        }
    }

    // MARK: - Round-Trip Tests

    func test_roundTrip_integer_encodesAndDecodes() throws {
        for value in [-128, -1, 0, 1, 127, 255, 65535] {
            let encoded = BEREncoder.encodeInteger(value)
            var offset = 0
            let decoded = try BERDecoder.readInteger(from: encoded, offset: &offset)
            XCTAssertEqual(decoded, value, "Round-trip failed for \(value)")
        }
    }

    func test_roundTrip_octetString_encodesAndDecodes() throws {
        let original = "MAYAM-PACS"
        let encoded = BEREncoder.encodeOctetString(original)
        var offset = 0
        let decoded = try BERDecoder.readOctetString(from: encoded, offset: &offset)
        XCTAssertEqual(decoded, original)
    }

    func test_roundTrip_sequence_wrapsAndUnwraps() throws {
        let contents = BEREncoder.encodeInteger(7) + BEREncoder.encodeOctetString("test")
        let seq = BEREncoder.encodeSequence(contents)
        var offset = 0
        let decoded = try BERDecoder.readSequence(from: seq, offset: &offset)
        XCTAssertEqual(decoded, contents)
    }
}

// MARK: - LDAPErrorTests

final class LDAPErrorTests: XCTestCase {

    func test_ldapError_connectionFailed_hasDescription() {
        let error = LDAPError.connectionFailed
        XCTAssertFalse(error.description.isEmpty)
        XCTAssertTrue(error.description.contains("connection"))
    }

    func test_ldapError_invalidCredentials_hasDescription() {
        let error = LDAPError.invalidCredentials
        XCTAssertFalse(error.description.isEmpty)
    }

    func test_ldapError_userNotFound_hasDescription() {
        let error = LDAPError.userNotFound
        XCTAssertFalse(error.description.isEmpty)
    }

    func test_ldapError_serverError_includesCodeAndMessage() {
        let error = LDAPError.serverError(code: 32, message: "No such object")
        XCTAssertTrue(error.description.contains("32"))
        XCTAssertTrue(error.description.contains("No such object"))
    }

    func test_ldapError_timeout_hasDescription() {
        let error = LDAPError.timeout
        XCTAssertFalse(error.description.isEmpty)
    }

    func test_ldapError_isSendable() {
        // Verifies Sendable conformance compiles correctly.
        let _: any Sendable = LDAPError.connectionFailed
    }
}

// MARK: - PermissionTests

final class PermissionTests: XCTestCase {

    func test_administrator_hasAllPermissions() {
        let role = AdminRole.administrator
        for permission in Permission.allCases {
            XCTAssertTrue(
                role.hasPermission(permission),
                "Administrator should have permission: \(permission.rawValue)"
            )
        }
    }

    func test_technologist_hasExpectedPermissions() {
        let role = AdminRole.technologist
        XCTAssertTrue(role.hasPermission(.viewDashboard))
        XCTAssertTrue(role.hasPermission(.manageNodes))
        XCTAssertTrue(role.hasPermission(.manageStorage))
        XCTAssertTrue(role.hasPermission(.viewLogs))
        XCTAssertTrue(role.hasPermission(.queryRetrieve))
        XCTAssertTrue(role.hasPermission(.viewPatients))
    }

    func test_technologist_lacksAdminOnlyPermissions() {
        let role = AdminRole.technologist
        XCTAssertFalse(role.hasPermission(.manageUsers))
        XCTAssertFalse(role.hasPermission(.manageLDAP))
        XCTAssertFalse(role.hasPermission(.manageSettings))
    }

    func test_physician_hasExpectedPermissions() {
        let role = AdminRole.physician
        XCTAssertTrue(role.hasPermission(.viewDashboard))
        XCTAssertTrue(role.hasPermission(.queryRetrieve))
        XCTAssertTrue(role.hasPermission(.viewPatients))
        XCTAssertTrue(role.hasPermission(.viewLogs))
    }

    func test_physician_lacksManagementPermissions() {
        let role = AdminRole.physician
        XCTAssertFalse(role.hasPermission(.manageUsers))
        XCTAssertFalse(role.hasPermission(.manageLDAP))
        XCTAssertFalse(role.hasPermission(.manageNodes))
        XCTAssertFalse(role.hasPermission(.manageStorage))
        XCTAssertFalse(role.hasPermission(.manageSettings))
    }

    func test_auditor_hasExpectedPermissions() {
        let role = AdminRole.auditor
        XCTAssertTrue(role.hasPermission(.viewDashboard))
        XCTAssertTrue(role.hasPermission(.viewLogs))
    }

    func test_auditor_lacksAllOtherPermissions() {
        let role = AdminRole.auditor
        let auditorOnly: Set<Permission> = [.viewDashboard, .viewLogs]
        for permission in Permission.allCases where !auditorOnly.contains(permission) {
            XCTAssertFalse(
                role.hasPermission(permission),
                "Auditor should not have permission: \(permission.rawValue)"
            )
        }
    }

    func test_permission_allCases_containsExpectedCases() {
        XCTAssertTrue(Permission.allCases.contains(.viewDashboard))
        XCTAssertTrue(Permission.allCases.contains(.manageUsers))
        XCTAssertTrue(Permission.allCases.contains(.manageLDAP))
        XCTAssertTrue(Permission.allCases.contains(.queryRetrieve))
    }
}

// MARK: - DICOMLDAPSchemaTests

final class DICOMLDAPSchemaTests: XCTestCase {

    func test_schemaConstants_haveExpectedValues() {
        XCTAssertEqual(DICOMLDAPSchema.configurationRootClass, "dicomConfigurationRoot")
        XCTAssertEqual(DICOMLDAPSchema.deviceClass, "dicomDevice")
        XCTAssertEqual(DICOMLDAPSchema.networkAEClass, "dicomNetworkAE")
        XCTAssertEqual(DICOMLDAPSchema.networkConnectionClass, "dicomNetworkConnection")
    }

    func test_dicomDevice_init_storesValues() {
        let device = DICOMDevice(
            dicomDeviceName: "MAYAM",
            dicomManufacturer: "Raster Lab",
            dicomSoftwareVersion: ["1.0.0"],
            dicomPrimaryDeviceType: ["ARCHIVE"]
        )
        XCTAssertEqual(device.dicomDeviceName, "MAYAM")
        XCTAssertEqual(device.dicomManufacturer, "Raster Lab")
        XCTAssertEqual(device.dicomSoftwareVersion, ["1.0.0"])
        XCTAssertEqual(device.dicomPrimaryDeviceType, ["ARCHIVE"])
    }

    func test_dicomNetworkAE_init_storesValues() {
        let ae = DICOMNetworkAE(
            dicomAETitle: "MAYAM",
            dicomAssociationInitiator: true,
            dicomAssociationAcceptor: true
        )
        XCTAssertEqual(ae.dicomAETitle, "MAYAM")
        XCTAssertTrue(ae.dicomAssociationInitiator)
        XCTAssertTrue(ae.dicomAssociationAcceptor)
    }

    func test_dicomNetworkConnection_init_storesValues() {
        let conn = DICOMNetworkConnection(
            cn: "mayam-dicom",
            dicomHostname: "pacs.example.com",
            dicomPort: 11112
        )
        XCTAssertEqual(conn.cn, "mayam-dicom")
        XCTAssertEqual(conn.dicomHostname, "pacs.example.com")
        XCTAssertEqual(conn.dicomPort, 11112)
    }

    func test_dicomLDAPConfiguration_init_storesValues() {
        let config = DICOMLDAPConfiguration(
            configurationRoot: "cn=DICOM,dc=example,dc=com",
            devicesRoot: "cn=Devices,cn=DICOM,dc=example,dc=com",
            aeTitlesRoot: "cn=AETitles,cn=DICOM,dc=example,dc=com"
        )
        XCTAssertEqual(config.configurationRoot, "cn=DICOM,dc=example,dc=com")
        XCTAssertTrue(config.devices.isEmpty)
    }

    func test_dicomDevice_codable_roundTrip() throws {
        let device = DICOMDevice(
            dicomDeviceName: "TEST",
            dicomSoftwareVersion: ["2.0"],
            dicomPrimaryDeviceType: ["ARCHIVE"],
            dicomNetworkAEs: [
                DICOMNetworkAE(dicomAETitle: "TEST_AE")
            ]
        )
        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(DICOMDevice.self, from: data)
        XCTAssertEqual(decoded.dicomDeviceName, device.dicomDeviceName)
        XCTAssertEqual(decoded.dicomSoftwareVersion, device.dicomSoftwareVersion)
        XCTAssertEqual(decoded.dicomNetworkAEs.first?.dicomAETitle, "TEST_AE")
    }
}

// MARK: - UserDirectoryTests

final class UserDirectoryTests: XCTestCase {

    // MARK: - Authentication

    func test_authenticate_defaultAdmin_succeeds() async throws {
        let directory = UserDirectory()
        let user = try await directory.authenticate(username: "admin", password: "admin")
        XCTAssertEqual(user.username, "admin")
        XCTAssertEqual(user.role, .administrator)
        XCTAssertEqual(user.source, .local)
    }

    func test_authenticate_wrongPassword_throwsUnauthorised() async throws {
        let directory = UserDirectory()
        do {
            _ = try await directory.authenticate(username: "admin", password: "wrong")
            XCTFail("Expected AdminError.unauthorised to be thrown")
        } catch AdminError.unauthorised {
            // Expected
        }
    }

    func test_authenticate_unknownUser_throwsUnauthorised() async throws {
        let directory = UserDirectory()
        do {
            _ = try await directory.authenticate(username: "nobody", password: "pass")
            XCTFail("Expected AdminError.unauthorised to be thrown")
        } catch AdminError.unauthorised {
            // Expected
        }
    }

    // MARK: - Create User

    func test_createUser_newUsername_succeeds() async throws {
        let directory = UserDirectory()
        let req = CreateUserRequest(username: "alice", password: "secret", role: .technologist)
        let record = try await directory.createUser(req)
        XCTAssertEqual(record.username, "alice")
        XCTAssertEqual(record.role, .technologist)
        XCTAssertTrue(record.isLocal)
    }

    func test_createUser_duplicateUsername_throwsConflict() async throws {
        let directory = UserDirectory()
        let req = CreateUserRequest(username: "admin", password: "newpass", role: .auditor)
        do {
            _ = try await directory.createUser(req)
            XCTFail("Expected AdminError.conflict to be thrown")
        } catch AdminError.conflict {
            // Expected
        }
    }

    func test_createUser_thenAuthenticate_succeeds() async throws {
        let directory = UserDirectory()
        let req = CreateUserRequest(username: "bob", password: "p@ss", role: .physician)
        _ = try await directory.createUser(req)
        let user = try await directory.authenticate(username: "bob", password: "p@ss")
        XCTAssertEqual(user.role, .physician)
    }

    // MARK: - List Users

    func test_listUsers_returnsDefaultAdmin() async {
        let directory = UserDirectory()
        let users = await directory.listUsers()
        XCTAssertTrue(users.contains { $0.username == "admin" })
    }

    func test_listUsers_afterCreate_includesNewUser() async throws {
        let directory = UserDirectory()
        let req = CreateUserRequest(username: "carol", password: "pw", role: .auditor)
        _ = try await directory.createUser(req)
        let users = await directory.listUsers()
        XCTAssertTrue(users.contains { $0.username == "carol" })
    }

    // MARK: - Update User

    func test_updateUser_changesRole() async throws {
        let directory = UserDirectory()
        let createReq = CreateUserRequest(username: "dave", password: "pw", role: .auditor)
        _ = try await directory.createUser(createReq)
        let updateReq = UpdateUserRequest(role: .technologist)
        let updated = try await directory.updateUser(username: "dave", req: updateReq)
        XCTAssertEqual(updated.role, .technologist)
    }

    func test_updateUser_unknownUser_throwsNotFound() async throws {
        let directory = UserDirectory()
        let req = UpdateUserRequest(role: .physician)
        do {
            _ = try await directory.updateUser(username: "ghost", req: req)
            XCTFail("Expected AdminError.notFound to be thrown")
        } catch AdminError.notFound {
            // Expected
        }
    }

    // MARK: - Delete User

    func test_deleteUser_existingUser_removesFromList() async throws {
        let directory = UserDirectory()
        let req = CreateUserRequest(username: "eve", password: "pw", role: .auditor)
        _ = try await directory.createUser(req)
        try await directory.deleteUser(username: "eve")
        let users = await directory.listUsers()
        XCTAssertFalse(users.contains { $0.username == "eve" })
    }

    func test_deleteUser_unknownUser_throwsNotFound() async throws {
        let directory = UserDirectory()
        do {
            try await directory.deleteUser(username: "nobody")
            XCTFail("Expected AdminError.notFound to be thrown")
        } catch AdminError.notFound {
            // Expected
        }
    }

    // MARK: - Change Password

    func test_changePassword_correctOldPassword_updatesPassword() async throws {
        let directory = UserDirectory()
        try await directory.changePassword(
            username: "admin",
            oldPassword: "admin",
            newPassword: "newSecret123"
        )
        // Old password should no longer work.
        do {
            _ = try await directory.authenticate(username: "admin", password: "admin")
            XCTFail("Old password should no longer be valid")
        } catch AdminError.unauthorised {
            // Expected
        }
        // New password should work.
        let user = try await directory.authenticate(username: "admin", password: "newSecret123")
        XCTAssertEqual(user.username, "admin")
    }

    func test_changePassword_wrongOldPassword_throwsUnauthorised() async throws {
        let directory = UserDirectory()
        do {
            try await directory.changePassword(
                username: "admin",
                oldPassword: "wrong",
                newPassword: "new"
            )
            XCTFail("Expected AdminError.unauthorised to be thrown")
        } catch AdminError.unauthorised {
            // Expected
        }
    }

    func test_changePassword_unknownUser_throwsNotFound() async throws {
        let directory = UserDirectory()
        do {
            try await directory.changePassword(
                username: "ghost",
                oldPassword: "old",
                newPassword: "new"
            )
            XCTFail("Expected AdminError.notFound to be thrown")
        } catch AdminError.notFound {
            // Expected
        }
    }
}
