// SPDX-License-Identifier: (see LICENSE)
// Mayam — Configuration Errors

import Foundation

/// Errors that may occur during configuration loading.
public enum ConfigurationError: Error, Sendable, CustomStringConvertible {

    /// The configuration file at the given path could not be read.
    case unreadableFile(path: String, underlying: any Error)

    /// The configuration file is not valid UTF-8.
    case invalidEncoding(path: String)

    /// The configuration file contains invalid YAML.
    case invalidYAML(path: String, underlying: any Error)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .unreadableFile(let path, let underlying):
            return "Cannot read configuration file at '\(path)': \(underlying)"
        case .invalidEncoding(let path):
            return "Configuration file at '\(path)' is not valid UTF-8"
        case .invalidYAML(let path, let underlying):
            return "Invalid YAML in configuration file at '\(path)': \(underlying)"
        }
    }
}
