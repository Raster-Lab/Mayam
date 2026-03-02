// SPDX-License-Identifier: (see LICENSE)
// Mayam — Logging Tests

import XCTest
@testable import MayamCore
import Logging

final class LoggingTests: XCTestCase {

    func test_logLevel_fromString_mapsCorrectly() {
        XCTAssertEqual(logLevel(from: "trace"), .trace)
        XCTAssertEqual(logLevel(from: "debug"), .debug)
        XCTAssertEqual(logLevel(from: "info"), .info)
        XCTAssertEqual(logLevel(from: "notice"), .notice)
        XCTAssertEqual(logLevel(from: "warning"), .warning)
        XCTAssertEqual(logLevel(from: "error"), .error)
        XCTAssertEqual(logLevel(from: "critical"), .critical)
    }

    func test_logLevel_fromString_caseInsensitive() {
        XCTAssertEqual(logLevel(from: "DEBUG"), .debug)
        XCTAssertEqual(logLevel(from: "Info"), .info)
        XCTAssertEqual(logLevel(from: "WARNING"), .warning)
    }

    func test_logLevel_fromString_unknownDefaultsToInfo() {
        XCTAssertEqual(logLevel(from: "unknown"), .info)
        XCTAssertEqual(logLevel(from: ""), .info)
        XCTAssertEqual(logLevel(from: "verbose"), .info)
    }

    func test_mayamLogger_canBeCreated() {
        let logger = MayamLogger(label: "test.logger")
        // Verify it doesn't crash and the underlying logger is accessible
        XCTAssertNotNil(logger.logger)
    }

    func test_mayamLogger_loggingMethods_doNotCrash() {
        let logger = MayamLogger(label: "test.methods")
        // These should not throw or crash
        logger.trace("trace message")
        logger.debug("debug message")
        logger.info("info message")
        logger.notice("notice message")
        logger.warning("warning message")
        logger.error("error message")
        logger.critical("critical message")
    }
}
