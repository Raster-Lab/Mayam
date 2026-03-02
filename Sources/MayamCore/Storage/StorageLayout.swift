// SPDX-License-Identifier: (see LICENSE)
// Mayam — Storage Layout

import Foundation

/// Computes and manages the on-disk directory hierarchy for the DICOM archive.
///
/// The default layout organises DICOM objects by Patient / Study / Series:
///
/// ```
/// {archivePath}/
///   {sanitisedPatientID}/
///     {studyInstanceUID}/
///       {seriesInstanceUID}/
///         {sopInstanceUID}.dcm
/// ```
///
/// Path components are sanitised to replace characters that are unsafe on
/// POSIX and Windows file systems (e.g. `/`, `\`, `:`) with underscores.
public struct StorageLayout: Sendable {

    // MARK: - Stored Properties

    /// The root directory of the DICOM archive.
    public let archivePath: String

    // MARK: - Initialiser

    /// Creates a new storage layout rooted at the given archive path.
    ///
    /// - Parameter archivePath: The absolute path to the archive root directory.
    public init(archivePath: String) {
        self.archivePath = archivePath
    }

    // MARK: - Path Computation

    /// Computes the relative file path for a DICOM instance within the archive.
    ///
    /// - Parameters:
    ///   - patientID: DICOM Patient ID (0010,0020).
    ///   - studyInstanceUID: DICOM Study Instance UID (0020,000D).
    ///   - seriesInstanceUID: DICOM Series Instance UID (0020,000E).
    ///   - sopInstanceUID: DICOM SOP Instance UID (0008,0018).
    /// - Returns: The relative path (no leading `/`) within the archive root.
    public func relativePath(
        patientID: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String
    ) -> String {
        let components = [
            sanitise(patientID),
            sanitise(studyInstanceUID),
            sanitise(seriesInstanceUID),
            sanitise(sopInstanceUID) + ".dcm"
        ]
        return components.joined(separator: "/")
    }

    /// Computes the absolute file path for a DICOM instance.
    ///
    /// - Parameters:
    ///   - patientID: DICOM Patient ID (0010,0020).
    ///   - studyInstanceUID: DICOM Study Instance UID (0020,000D).
    ///   - seriesInstanceUID: DICOM Series Instance UID (0020,000E).
    ///   - sopInstanceUID: DICOM SOP Instance UID (0008,0018).
    /// - Returns: The absolute path to the stored file.
    public func absolutePath(
        patientID: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        sopInstanceUID: String
    ) -> String {
        archivePath + "/" + relativePath(
            patientID: patientID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            sopInstanceUID: sopInstanceUID
        )
    }

    /// Computes the absolute directory path for a given series.
    ///
    /// - Parameters:
    ///   - patientID: DICOM Patient ID (0010,0020).
    ///   - studyInstanceUID: DICOM Study Instance UID (0020,000D).
    ///   - seriesInstanceUID: DICOM Series Instance UID (0020,000E).
    /// - Returns: The absolute path to the series directory.
    public func seriesDirectoryPath(
        patientID: String,
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) -> String {
        [
            archivePath,
            sanitise(patientID),
            sanitise(studyInstanceUID),
            sanitise(seriesInstanceUID)
        ].joined(separator: "/")
    }

    /// Computes the absolute directory path for a given study.
    ///
    /// - Parameters:
    ///   - patientID: DICOM Patient ID (0010,0020).
    ///   - studyInstanceUID: DICOM Study Instance UID (0020,000D).
    /// - Returns: The absolute path to the study directory.
    public func studyDirectoryPath(
        patientID: String,
        studyInstanceUID: String
    ) -> String {
        [
            archivePath,
            sanitise(patientID),
            sanitise(studyInstanceUID)
        ].joined(separator: "/")
    }

    // MARK: - Directory Management

    /// Creates the full directory hierarchy for a DICOM instance.
    ///
    /// Creates all intermediate directories in the hierarchy if they do not
    /// already exist.
    ///
    /// - Parameters:
    ///   - patientID: DICOM Patient ID (0010,0020).
    ///   - studyInstanceUID: DICOM Study Instance UID (0020,000D).
    ///   - seriesInstanceUID: DICOM Series Instance UID (0020,000E).
    /// - Throws: ``StorageLayoutError/directoryCreationFailed`` if the directory
    ///   cannot be created.
    public func createDirectoryHierarchy(
        patientID: String,
        studyInstanceUID: String,
        seriesInstanceUID: String
    ) throws {
        let dirPath = seriesDirectoryPath(
            patientID: patientID,
            studyInstanceUID: studyInstanceUID,
            seriesInstanceUID: seriesInstanceUID
        )
        do {
            try FileManager.default.createDirectory(
                atPath: dirPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw StorageLayoutError.directoryCreationFailed(path: dirPath, underlying: error)
        }
    }

    // MARK: - Sanitisation

    /// Sanitises a string for use as a file-system path component.
    ///
    /// Replaces characters that are unsafe in POSIX or Windows file paths
    /// (including `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`, and the null
    /// byte) with underscores.
    ///
    /// - Parameter value: The raw string to sanitise.
    /// - Returns: A file-system-safe string.
    func sanitise(_ value: String) -> String {
        let unsafe = CharacterSet(charactersIn: "/\\:*?\"<>|\0")
        return value.unicodeScalars.map { scalar in
            unsafe.contains(scalar) ? "_" : Character(scalar)
        }.map(String.init).joined()
    }
}

// MARK: - StorageLayoutError

/// Errors that may occur during storage layout operations.
public enum StorageLayoutError: Error, Sendable, CustomStringConvertible {

    /// The directory hierarchy could not be created.
    case directoryCreationFailed(path: String, underlying: any Error)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .directoryCreationFailed(let path, let underlying):
            return "Failed to create archive directory at '\(path)': \(underlying)"
        }
    }
}
