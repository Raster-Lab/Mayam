// SPDX-License-Identifier: (see LICENSE)
// Mayam Server — DICOM Component Tests

import XCTest
import NIOCore
import NIOEmbedded
import NIOPosix
@testable import MayamCore
import DICOMNetwork
import Logging

// MARK: - PDUFrameDecoder Tests

final class PDUFrameDecoderTests: XCTestCase {

    func test_pduFrameDecoder_completePDU_decodesSuccessfully() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(PDUFrameDecoder()))
        defer { _ = try? channel.finish() }

        // Build a simple A-ABORT PDU: type=0x07, reserved=0x00, length=4, payload=4 bytes
        var buffer = channel.allocator.buffer(capacity: 10)
        buffer.writeInteger(UInt8(0x07))       // PDU type: A-ABORT
        buffer.writeInteger(UInt8(0x00))       // Reserved
        buffer.writeInteger(UInt32(4))          // Length
        buffer.writeInteger(UInt8(0x00))       // Reserved
        buffer.writeInteger(UInt8(0x00))       // Reserved
        buffer.writeInteger(UInt8(0x00))       // Source
        buffer.writeInteger(UInt8(0x00))       // Reason

        try channel.writeInbound(buffer)

        let decoded: ByteBuffer? = try channel.readInbound()
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.readableBytes, 10) // 6 header + 4 payload
    }

    func test_pduFrameDecoder_incompletePDU_needsMoreData() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(PDUFrameDecoder()))
        defer { _ = try? channel.finish() }

        // Write only the header (6 bytes) with length indicating 100 more bytes needed
        var buffer = channel.allocator.buffer(capacity: 6)
        buffer.writeInteger(UInt8(0x04))       // PDU type: P-DATA-TF
        buffer.writeInteger(UInt8(0x00))       // Reserved
        buffer.writeInteger(UInt32(100))        // Length: 100 bytes

        try channel.writeInbound(buffer)

        // No output yet since the payload is incomplete
        let decoded: ByteBuffer? = try channel.readInbound()
        XCTAssertNil(decoded)
    }

    func test_pduFrameDecoder_headerOnly_needsMoreData() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(PDUFrameDecoder()))
        defer { _ = try? channel.finish() }

        // Write only 3 bytes (less than the 6-byte header)
        var buffer = channel.allocator.buffer(capacity: 3)
        buffer.writeInteger(UInt8(0x04))
        buffer.writeInteger(UInt8(0x00))
        buffer.writeInteger(UInt8(0x00))

        try channel.writeInbound(buffer)

        let decoded: ByteBuffer? = try channel.readInbound()
        XCTAssertNil(decoded)
    }

    func test_pduFrameDecoder_multiplePDUs_decodesAll() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(PDUFrameDecoder()))
        defer { _ = try? channel.finish() }

        // Write two complete PDUs
        var buffer = channel.allocator.buffer(capacity: 20)

        // First PDU: A-ABORT (10 bytes)
        buffer.writeInteger(UInt8(0x07))
        buffer.writeInteger(UInt8(0x00))
        buffer.writeInteger(UInt32(4))
        buffer.writeBytes([0x00, 0x00, 0x00, 0x00])

        // Second PDU: A-RELEASE-RQ (10 bytes)
        buffer.writeInteger(UInt8(0x05))
        buffer.writeInteger(UInt8(0x00))
        buffer.writeInteger(UInt32(4))
        buffer.writeBytes([0x00, 0x00, 0x00, 0x00])

        try channel.writeInbound(buffer)

        let first: ByteBuffer? = try channel.readInbound()
        let second: ByteBuffer? = try channel.readInbound()

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(first?.readableBytes, 10)
        XCTAssertEqual(second?.readableBytes, 10)
    }

    func test_pduFrameDecoder_fragmentedPDU_reassembles() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(PDUFrameDecoder()))
        defer { _ = try? channel.finish() }

        // Write the header first
        var headerBuffer = channel.allocator.buffer(capacity: 6)
        headerBuffer.writeInteger(UInt8(0x07))
        headerBuffer.writeInteger(UInt8(0x00))
        headerBuffer.writeInteger(UInt32(4))

        try channel.writeInbound(headerBuffer)
        XCTAssertNil(try channel.readInbound() as ByteBuffer?)

        // Now write the payload
        var payloadBuffer = channel.allocator.buffer(capacity: 4)
        payloadBuffer.writeBytes([0x00, 0x00, 0x00, 0x00])

        try channel.writeInbound(payloadBuffer)
        let decoded: ByteBuffer? = try channel.readInbound()
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.readableBytes, 10)
    }
}

// MARK: - VerificationSCP Tests

final class VerificationSCPTests: XCTestCase {

    func test_verificationSCP_supportedSOPClasses_containsVerificationUID() {
        let scp = VerificationSCP()
        XCTAssertTrue(scp.supportedSOPClassUIDs.contains(verificationSOPClassUID))
        XCTAssertEqual(scp.supportedSOPClassUIDs.count, 1)
    }

    func test_verificationSCP_handleCEcho_returnsSuccess() {
        let scp = VerificationSCP()

        let request = CEchoRequest(
            messageID: 42,
            affectedSOPClassUID: verificationSOPClassUID,
            presentationContextID: 1
        )

        let response = scp.handleCEcho(request: request, presentationContextID: 1)

        XCTAssertEqual(response.messageIDBeingRespondedTo, 42)
        XCTAssertEqual(response.presentationContextID, 1)
        XCTAssertTrue(response.status.isSuccess)
    }

    func test_verificationSCP_handleCEcho_preservesMessageID() {
        let scp = VerificationSCP()

        for messageID: UInt16 in [1, 100, 1000, UInt16.max] {
            let request = CEchoRequest(
                messageID: messageID,
                affectedSOPClassUID: verificationSOPClassUID,
                presentationContextID: 1
            )
            let response = scp.handleCEcho(request: request, presentationContextID: 1)
            XCTAssertEqual(response.messageIDBeingRespondedTo, messageID)
        }
    }

    func test_verificationSCP_handleCEcho_preservesPresentationContextID() {
        let scp = VerificationSCP()

        for contextID: UInt8 in [1, 3, 5, 127] {
            let request = CEchoRequest(
                messageID: 1,
                affectedSOPClassUID: verificationSOPClassUID,
                presentationContextID: contextID
            )
            let response = scp.handleCEcho(request: request, presentationContextID: contextID)
            XCTAssertEqual(response.presentationContextID, contextID)
        }
    }
}

// MARK: - SCPDispatcher Tests

final class SCPDispatcherTests: XCTestCase {

    func test_scpDispatcher_handleCEcho_returnsSuccessResponse() {
        let dispatcher = SCPDispatcher()

        let request = CEchoRequest(
            messageID: 1,
            affectedSOPClassUID: verificationSOPClassUID,
            presentationContextID: 1
        )

        let response = dispatcher.handleCEcho(request: request, presentationContextID: 1)

        XCTAssertTrue(response.status.isSuccess)
        XCTAssertEqual(response.messageIDBeingRespondedTo, 1)
    }

    func test_scpDispatcher_canBeCreatedWithEmptyServices() {
        let dispatcher = SCPDispatcher(services: [])

        let request = CEchoRequest(
            messageID: 1,
            affectedSOPClassUID: verificationSOPClassUID,
            presentationContextID: 1
        )

        let response = dispatcher.handleCEcho(request: request, presentationContextID: 1)
        XCTAssertTrue(response.status.isSuccess)
    }
}

// MARK: - DICOMListenerConfiguration Tests

final class DICOMListenerConfigurationTests: XCTestCase {

    func test_listenerConfiguration_defaults_areCorrect() {
        let config = DICOMListenerConfiguration()

        XCTAssertEqual(config.aeTitle, "MAYAM")
        XCTAssertEqual(config.port, 11112)
        XCTAssertEqual(config.maxPDUSize, 16_384)
        XCTAssertEqual(config.maxAssociations, 64)
        XCTAssertTrue(config.acceptedSOPClasses.contains(verificationSOPClassUID))
        XCTAssertTrue(config.acceptedTransferSyntaxes.contains(implicitVRLittleEndianTransferSyntaxUID))
        XCTAssertTrue(config.acceptedTransferSyntaxes.contains(explicitVRLittleEndianTransferSyntaxUID))
        XCTAssertFalse(config.tlsEnabled)
        XCTAssertNil(config.tlsCertificatePath)
        XCTAssertNil(config.tlsKeyPath)
    }

    func test_listenerConfiguration_customValues_arePreserved() {
        let config = DICOMListenerConfiguration(
            aeTitle: "CUSTOM_AE",
            port: 4242,
            maxPDUSize: 32_768,
            maxAssociations: 128,
            tlsEnabled: true,
            tlsCertificatePath: "/etc/certs/cert.pem",
            tlsKeyPath: "/etc/certs/key.pem"
        )

        XCTAssertEqual(config.aeTitle, "CUSTOM_AE")
        XCTAssertEqual(config.port, 4242)
        XCTAssertEqual(config.maxPDUSize, 32_768)
        XCTAssertEqual(config.maxAssociations, 128)
        XCTAssertTrue(config.tlsEnabled)
        XCTAssertEqual(config.tlsCertificatePath, "/etc/certs/cert.pem")
        XCTAssertEqual(config.tlsKeyPath, "/etc/certs/key.pem")
    }

    func test_listenerConfiguration_equatable() {
        let a = DICOMListenerConfiguration()
        let b = DICOMListenerConfiguration()
        XCTAssertEqual(a, b)

        let c = DICOMListenerConfiguration(aeTitle: "OTHER")
        XCTAssertNotEqual(a, c)
    }

    func test_listenerConfiguration_fromServerConfiguration_mapsCorrectly() {
        let serverConfig = ServerConfiguration(
            dicom: .init(aeTitle: "SRV_AE", port: 9999, maxAssociations: 32, tlsEnabled: true, tlsCertificatePath: "/cert.pem", tlsKeyPath: "/key.pem")
        )

        let listenerConfig = DICOMListenerConfiguration(from: serverConfig)

        XCTAssertEqual(listenerConfig.aeTitle, "SRV_AE")
        XCTAssertEqual(listenerConfig.port, 9999)
        XCTAssertEqual(listenerConfig.maxAssociations, 32)
        XCTAssertTrue(listenerConfig.tlsEnabled)
        XCTAssertEqual(listenerConfig.tlsCertificatePath, "/cert.pem")
        XCTAssertEqual(listenerConfig.tlsKeyPath, "/key.pem")
    }

    func test_listenerConfiguration_defaultAcceptedSOPClasses_includesVerification() {
        let classes = DICOMListenerConfiguration.defaultAcceptedSOPClasses
        XCTAssertTrue(classes.contains("1.2.840.10008.1.1"))
    }

    func test_listenerConfiguration_defaultAcceptedTransferSyntaxes_includesBoth() {
        let syntaxes = DICOMListenerConfiguration.defaultAcceptedTransferSyntaxes
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2"))     // Implicit VR LE
        XCTAssertTrue(syntaxes.contains("1.2.840.10008.1.2.1"))   // Explicit VR LE
    }

    func test_listenerConfiguration_implementationClassUID_isWellFormed() {
        let uid = DICOMListenerConfiguration.defaultImplementationClassUID
        XCTAssertFalse(uid.isEmpty)
        XCTAssertTrue(uid.count <= 64)
        XCTAssertTrue(uid.allSatisfy { $0.isNumber || $0 == "." })
    }

    func test_listenerConfiguration_implementationVersionName_isNotEmpty() {
        XCTAssertFalse(DICOMListenerConfiguration.defaultImplementationVersionName.isEmpty)
    }
}

// MARK: - DICOMListener Tests

final class DICOMListenerTests: XCTestCase {

    func test_dicomListener_initialState_isNotListening() async {
        let config = DICOMListenerConfiguration()
        let logger = Logger(label: "test.listener")
        let listener = DICOMListener(configuration: config, logger: logger)

        let listening = await listener.isListening()
        XCTAssertFalse(listening)
    }

    func test_dicomListener_start_bindsToPort() async throws {
        let config = DICOMListenerConfiguration(port: 0) // Use ephemeral port
        let logger = Logger(label: "test.listener")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let listener = DICOMListener(
            configuration: config,
            logger: logger,
            eventLoopGroup: eventLoopGroup
        )

        // Start should succeed on ephemeral port
        try await listener.start()
        let listening = await listener.isListening()
        XCTAssertTrue(listening)

        // Clean up
        await listener.stop()
        try await eventLoopGroup.shutdownGracefully()
    }

    func test_dicomListener_stop_closesListener() async throws {
        let config = DICOMListenerConfiguration(port: 0)
        let logger = Logger(label: "test.listener")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let listener = DICOMListener(
            configuration: config,
            logger: logger,
            eventLoopGroup: eventLoopGroup
        )

        try await listener.start()
        await listener.stop()
        let listening = await listener.isListening()
        XCTAssertFalse(listening)

        try await eventLoopGroup.shutdownGracefully()
    }

    func test_dicomListener_configuration_isPreserved() async {
        let config = DICOMListenerConfiguration(aeTitle: "TEST_AE", port: 4242)
        let logger = Logger(label: "test.listener")
        let listener = DICOMListener(configuration: config, logger: logger)

        let storedConfig = await listener.configuration
        XCTAssertEqual(storedConfig.aeTitle, "TEST_AE")
        XCTAssertEqual(storedConfig.port, 4242)
    }

    func test_dicomListener_tlsWithoutCerts_throwsError() async {
        let config = DICOMListenerConfiguration(tlsEnabled: true) // No certs
        let logger = Logger(label: "test.listener")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let listener = DICOMListener(
            configuration: config,
            logger: logger,
            eventLoopGroup: eventLoopGroup
        )

        do {
            try await listener.start()
            XCTFail("Expected DICOMListenerError.tlsConfigurationMissing")
        } catch {
            guard case DICOMListenerError.tlsConfigurationMissing = error else {
                XCTFail("Expected tlsConfigurationMissing, got \(error)")
                return
            }
        }

        try? await eventLoopGroup.shutdownGracefully()
    }
}

// MARK: - VerificationSCUResult Tests

final class VerificationSCUResultTests: XCTestCase {

    func test_verificationSCUResult_properties_arePreserved() {
        let result = VerificationSCUResult(
            success: true,
            roundTripTime: 0.042,
            remoteAETitle: "REMOTE_AE",
            host: "192.168.1.1",
            port: 11112
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.roundTripTime, 0.042, accuracy: 0.001)
        XCTAssertEqual(result.remoteAETitle, "REMOTE_AE")
        XCTAssertEqual(result.host, "192.168.1.1")
        XCTAssertEqual(result.port, 11112)
    }

    func test_verificationSCUResult_description_containsStatus() {
        let success = VerificationSCUResult(
            success: true,
            roundTripTime: 0.1,
            remoteAETitle: "AE",
            host: "localhost",
            port: 104
        )
        XCTAssertTrue(success.description.contains("SUCCESS"))

        let failure = VerificationSCUResult(
            success: false,
            roundTripTime: 0.5,
            remoteAETitle: "AE",
            host: "localhost",
            port: 104
        )
        XCTAssertTrue(failure.description.contains("FAILED"))
    }

    func test_verificationSCUResult_equatable() {
        let a = VerificationSCUResult(success: true, roundTripTime: 0.1, remoteAETitle: "AE", host: "h", port: 1)
        let b = VerificationSCUResult(success: true, roundTripTime: 0.1, remoteAETitle: "AE", host: "h", port: 1)
        XCTAssertEqual(a, b)

        let c = VerificationSCUResult(success: false, roundTripTime: 0.1, remoteAETitle: "AE", host: "h", port: 1)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - DICOMListenerError Tests

final class DICOMListenerErrorTests: XCTestCase {

    func test_tlsConfigurationMissing_description() {
        let error = DICOMListenerError.tlsConfigurationMissing
        XCTAssertTrue(error.description.contains("TLS"))
        XCTAssertTrue(error.description.contains("certificate"))
    }

    func test_bindFailed_description_containsPort() {
        let underlying = NSError(domain: "test", code: 1)
        let error = DICOMListenerError.bindFailed(port: 11112, underlying: underlying)
        XCTAssertTrue(error.description.contains("11112"))
    }
}

// MARK: - ServerConfiguration TLS Tests

final class ServerConfigurationTLSTests: XCTestCase {

    func test_dicomConfiguration_tlsDefaults() {
        let config = ServerConfiguration.DICOM()
        XCTAssertFalse(config.tlsEnabled)
        XCTAssertNil(config.tlsCertificatePath)
        XCTAssertNil(config.tlsKeyPath)
    }

    func test_dicomConfiguration_tlsCustomValues() {
        let config = ServerConfiguration.DICOM(
            tlsEnabled: true,
            tlsCertificatePath: "/cert.pem",
            tlsKeyPath: "/key.pem"
        )
        XCTAssertTrue(config.tlsEnabled)
        XCTAssertEqual(config.tlsCertificatePath, "/cert.pem")
        XCTAssertEqual(config.tlsKeyPath, "/key.pem")
    }

    func test_dicomConfiguration_tlsCodable_roundTrips() throws {
        let original = ServerConfiguration.DICOM(
            aeTitle: "TLS_AE",
            port: 2762,
            maxAssociations: 16,
            tlsEnabled: true,
            tlsCertificatePath: "/etc/cert.pem",
            tlsKeyPath: "/etc/key.pem"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ServerConfiguration.DICOM.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func test_serverConfiguration_withTLS_codable_roundTrips() throws {
        let original = ServerConfiguration(
            dicom: .init(aeTitle: "TLS_SRV", port: 2762, tlsEnabled: true, tlsCertificatePath: "/cert.pem", tlsKeyPath: "/key.pem")
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ServerConfiguration.self, from: data)

        XCTAssertEqual(original, decoded)
    }
}

// MARK: - C-ECHO Integration Tests

final class CEchoIntegrationTests: XCTestCase {

    func test_cEchoSCPSCU_endToEnd_succeeds() async throws {
        // Start a DICOM listener on an ephemeral port
        let config = DICOMListenerConfiguration(aeTitle: "TEST_SCP", port: 0)
        let logger = Logger(label: "test.integration")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)

        let listener = DICOMListener(
            configuration: config,
            logger: logger,
            eventLoopGroup: eventLoopGroup
        )

        try await listener.start()

        // Get the actual bound port
        guard let actualPort = await listener.localPort() else {
            XCTFail("Failed to get bound port")
            await listener.stop()
            try await eventLoopGroup.shutdownGracefully()
            return
        }

        // Now perform a C-ECHO SCU against the running SCP
        let scu = VerificationSCU(logger: logger)

        let result = try await scu.echo(
            host: "127.0.0.1",
            port: actualPort,
            callingAE: "TEST_SCU",
            calledAE: "TEST_SCP",
            timeout: 10
        )

        XCTAssertTrue(result.success, "C-ECHO should succeed against local SCP")
        XCTAssertEqual(result.remoteAETitle, "TEST_SCP")
        XCTAssertEqual(result.host, "127.0.0.1")
        XCTAssertEqual(result.port, actualPort)
        XCTAssertGreaterThan(result.roundTripTime, 0)

        // Clean up
        await listener.stop()
        try await eventLoopGroup.shutdownGracefully()
    }

    func test_cEchoSCPSCU_withFixedPort_succeeds() async throws {
        // Use an ephemeral port for the integration test
        let config = DICOMListenerConfiguration(aeTitle: "TEST_SCP", port: 0)
        let logger = Logger(label: "test.integration")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)

        let listener = DICOMListener(
            configuration: config,
            logger: logger,
            eventLoopGroup: eventLoopGroup
        )

        try await listener.start()

        guard let testPort = await listener.localPort() else {
            XCTFail("Failed to get bound port")
            await listener.stop()
            try await eventLoopGroup.shutdownGracefully()
            return
        }

        // Now perform a C-ECHO SCU against the running SCP
        let scu = VerificationSCU(logger: logger)

        let result = try await scu.echo(
            host: "127.0.0.1",
            port: testPort,
            callingAE: "TEST_SCU",
            calledAE: "TEST_SCP",
            timeout: 10
        )

        XCTAssertTrue(result.success, "C-ECHO should succeed against local SCP")
        XCTAssertEqual(result.remoteAETitle, "TEST_SCP")
        XCTAssertEqual(result.host, "127.0.0.1")
        XCTAssertEqual(result.port, testPort)
        XCTAssertGreaterThan(result.roundTripTime, 0)

        // Clean up
        await listener.stop()
        try await eventLoopGroup.shutdownGracefully()
    }

    func test_cEchoSCU_wrongCalledAE_getsRejected() async throws {
        let config = DICOMListenerConfiguration(aeTitle: "REAL_AE", port: 0)
        let logger = Logger(label: "test.integration")
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)

        let listener = DICOMListener(
            configuration: config,
            logger: logger,
            eventLoopGroup: eventLoopGroup
        )

        try await listener.start()

        guard let testPort = await listener.localPort() else {
            XCTFail("Failed to get bound port")
            await listener.stop()
            try await eventLoopGroup.shutdownGracefully()
            return
        }

        let scu = VerificationSCU(logger: logger)

        do {
            let result = try await scu.echo(
                host: "127.0.0.1",
                port: testPort,
                callingAE: "SCU",
                calledAE: "WRONG_AE",  // This doesn't match REAL_AE
                timeout: 10
            )

            // The association should be rejected
            XCTAssertFalse(result.success, "C-ECHO with wrong called AE should fail")
        } catch {
            // An error is also an acceptable outcome for a rejected association
        }

        // Clean up
        await listener.stop()
        try await eventLoopGroup.shutdownGracefully()
    }
}
