// SPDX-License-Identifier: (see LICENSE)
// Mayam — Logging Subsystem

import Logging
import Foundation

/// Cross-platform logging facade for Mayam.
///
/// On all platforms the subsystem uses `swift-log` (`Logging` module).
/// The default bootstrap configures `StreamLogHandler` (stderr).
/// A custom bootstrap can be provided to route logs through Apple's `os_log`
/// on macOS or any other `swift-log`-compatible backend.
///
/// ## Usage
/// ```swift
/// MayamLogger.bootstrap()
/// let logger = MayamLogger(label: "com.raster-lab.mayam.storage")
/// logger.info("Storage initialised")
/// ```
public struct MayamLogger: Sendable {

    // MARK: - Stored Properties

    /// The underlying `swift-log` logger instance.
    public var logger: Logger

    // MARK: - Initialiser

    /// Creates a new Mayam logger with the given subsystem label.
    ///
    /// - Parameter label: A reverse-DNS label identifying the subsystem
    ///   (e.g. `"com.raster-lab.mayam.server"`).
    public init(label: String) {
        self.logger = Logger(label: label)
    }

    // MARK: - Bootstrap

    /// Bootstraps the logging system.
    ///
    /// Call this once at application startup before creating any loggers.
    /// On macOS this will route through `os_log`; on Linux it defaults to
    /// `StreamLogHandler` (stderr).
    public static func bootstrap(level: Logger.Level = .info) {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = level
            return handler
        }
    }

    // MARK: - Convenience Logging Methods

    /// Logs a message at the `trace` level.
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        logger.trace(message(), file: file, function: function, line: line)
    }

    /// Logs a message at the `debug` level.
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        logger.debug(message(), file: file, function: function, line: line)
    }

    /// Logs a message at the `info` level.
    public func info(_ message: @autoclosure () -> Logger.Message,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        logger.info(message(), file: file, function: function, line: line)
    }

    /// Logs a message at the `notice` level.
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       file: String = #file, function: String = #function, line: UInt = #line) {
        logger.notice(message(), file: file, function: function, line: line)
    }

    /// Logs a message at the `warning` level.
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        file: String = #file, function: String = #function, line: UInt = #line) {
        logger.warning(message(), file: file, function: function, line: line)
    }

    /// Logs a message at the `error` level.
    public func error(_ message: @autoclosure () -> Logger.Message,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        logger.error(message(), file: file, function: function, line: line)
    }

    /// Logs a message at the `critical` level.
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         file: String = #file, function: String = #function, line: UInt = #line) {
        logger.critical(message(), file: file, function: function, line: line)
    }
}

/// Maps a string log level name to a `Logger.Level` value.
///
/// - Parameter name: A case-insensitive log level name (e.g. `"info"`, `"DEBUG"`).
/// - Returns: The corresponding `Logger.Level`, or `.info` if the name is unrecognised.
public func logLevel(from name: String) -> Logger.Level {
    switch name.lowercased() {
    case "trace":    return .trace
    case "debug":    return .debug
    case "info":     return .info
    case "notice":   return .notice
    case "warning":  return .warning
    case "error":    return .error
    case "critical": return .critical
    default:         return .info
    }
}
