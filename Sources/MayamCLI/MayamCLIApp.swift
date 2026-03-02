// SPDX-License-Identifier: (see LICENSE)
// Mayam — Command-Line Interface

import MayamCore
import Foundation

/// Mayam CLI — command-line administration tools for Mayam.
///
/// ## Planned Commands
/// - `mayam-cli status` — display server health.
/// - `mayam-cli echo <host> <port>` — send a C-ECHO to a remote AE.
/// - `mayam-cli config validate` — validate a configuration file.
///
/// > Note: Full command set is developed across later milestones.
@main
struct MayamCLIApp {
    static func main() async throws {
        MayamLogger.bootstrap()
        let logger = MayamLogger(label: "com.raster-lab.mayam.cli")

        let args = CommandLine.arguments.dropFirst()

        if args.first == "config" && args.dropFirst().first == "validate" {
            let configPath = args.dropFirst().dropFirst().first
            do {
                let config = try ConfigurationLoader.load(from: configPath)
                print("Configuration is valid.")
                print("  AE Title: \(config.dicom.aeTitle)")
                print("  Port: \(config.dicom.port)")
                print("  Archive Path: \(config.storage.archivePath)")
            } catch {
                logger.error("Configuration validation failed: \(error)")
            }
        } else {
            print("Mayam CLI v0.1.0")
            print("Usage: mayam-cli <command>")
            print("")
            print("Commands:")
            print("  config validate [path]  Validate a configuration file")
        }
    }
}
