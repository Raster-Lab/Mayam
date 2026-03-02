// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOM JSON Attribute Serialisation

import Foundation
import MayamCore

// MARK: - DICOMAttribute

/// A single DICOM attribute in the DICOMweb JSON encoding.
///
/// The DICOMweb JSON model represents each DICOM attribute as an object
/// with mandatory `"vr"` and optional `"Value"`, `"BulkDataURI"`, or
/// `"InlineBinary"` fields, keyed by the 8-character uppercase hex tag
/// string (e.g. `"00100020"` for Patient ID).
///
/// Reference: DICOM PS3.18 Section F.2 — DICOM JSON Model Attribute Object
public struct DICOMAttribute: Sendable, Codable, Equatable {

    // MARK: - Stored Properties

    /// The DICOM Value Representation (VR) code (e.g. `"LO"`, `"DA"`, `"UI"`).
    public let vr: String

    /// String values (used for VRs: AE, AS, CS, DA, DS, DT, IS, LO, LT,
    /// PN, SH, ST, TM, UC, UI, UR, UT).
    public let stringValues: [String?]?

    /// Numeric values (used for VRs: DS, FL, FD, IS, SL, SS, UL, US).
    public let numberValues: [Double?]?

    /// Sequence items (used for VR: SQ). Each item is a map of tag → attribute.
    public let sequenceItems: [[String: DICOMAttribute]]?

    /// A URI pointing to the bulk data for this attribute.
    public let bulkDataURI: String?

    /// Base64-encoded inline binary data (used for VRs: OB, OD, OF, OL, OV, OW, UN).
    public let inlineBinary: String?

    // MARK: - Codable

    // MARK: - Custom Encoding

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: EncodeKeys.self)
        try container.encode(vr, forKey: .vr)

        if let bulkDataURI {
            try container.encode(bulkDataURI, forKey: .bulkDataURI)
        } else if let inlineBinary {
            try container.encode(inlineBinary, forKey: .inlineBinary)
        } else if let seq = sequenceItems {
            try container.encode(seq, forKey: .value)
        } else if let nums = numberValues {
            try container.encode(nums, forKey: .value)
        } else if let strs = stringValues {
            try container.encode(strs, forKey: .value)
        }
    }

    private enum EncodeKeys: String, CodingKey {
        case vr
        case value = "Value"
        case bulkDataURI = "BulkDataURI"
        case inlineBinary = "InlineBinary"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: EncodeKeys.self)
        self.vr = try container.decode(String.self, forKey: .vr)
        self.bulkDataURI = try container.decodeIfPresent(String.self, forKey: .bulkDataURI)
        self.inlineBinary = try container.decodeIfPresent(String.self, forKey: .inlineBinary)

        // Try sequence
        if let seq = try? container.decodeIfPresent([[String: DICOMAttribute]].self, forKey: .value) {
            self.sequenceItems = seq
            self.stringValues = nil
            self.numberValues = nil
        } else if let nums = try? container.decodeIfPresent([Double?].self, forKey: .value) {
            self.numberValues = nums
            self.stringValues = nil
            self.sequenceItems = nil
        } else if let strs = try? container.decodeIfPresent([String?].self, forKey: .value) {
            self.stringValues = strs
            self.numberValues = nil
            self.sequenceItems = nil
        } else {
            self.stringValues = nil
            self.numberValues = nil
            self.sequenceItems = nil
        }
    }

    // MARK: - Initialisers

    /// Creates a string-valued attribute.
    ///
    /// - Parameters:
    ///   - vr: The DICOM VR code.
    ///   - values: String values, or `nil` entries for absent values.
    public init(vr: String, stringValues: [String?]) {
        self.vr = vr
        self.stringValues = stringValues
        self.numberValues = nil
        self.sequenceItems = nil
        self.bulkDataURI = nil
        self.inlineBinary = nil
    }

    /// Creates a numeric-valued attribute.
    ///
    /// - Parameters:
    ///   - vr: The DICOM VR code.
    ///   - values: Numeric values, or `nil` entries for absent values.
    public init(vr: String, numberValues: [Double?]) {
        self.vr = vr
        self.stringValues = nil
        self.numberValues = numberValues
        self.sequenceItems = nil
        self.bulkDataURI = nil
        self.inlineBinary = nil
    }

    /// Creates a sequence-valued attribute.
    ///
    /// - Parameters:
    ///   - items: The sequence items, each a map of hex tag → attribute.
    public init(sequenceItems: [[String: DICOMAttribute]]) {
        self.vr = "SQ"
        self.stringValues = nil
        self.numberValues = nil
        self.sequenceItems = sequenceItems
        self.bulkDataURI = nil
        self.inlineBinary = nil
    }

    /// Creates a bulk data URI reference attribute.
    ///
    /// - Parameters:
    ///   - vr: The DICOM VR code.
    ///   - bulkDataURI: URI pointing to the bulk data location.
    public init(vr: String, bulkDataURI: String) {
        self.vr = vr
        self.stringValues = nil
        self.numberValues = nil
        self.sequenceItems = nil
        self.bulkDataURI = bulkDataURI
        self.inlineBinary = nil
    }

    /// Creates an inline-binary attribute.
    ///
    /// - Parameters:
    ///   - vr: The DICOM VR code.
    ///   - data: The binary data to encode as Base64.
    public init(vr: String, binaryData: Data) {
        self.vr = vr
        self.stringValues = nil
        self.numberValues = nil
        self.sequenceItems = nil
        self.bulkDataURI = nil
        self.inlineBinary = binaryData.base64EncodedString()
    }
}

// MARK: - DICOMJSONSerializer

/// Serialises Mayam metadata models to the DICOMweb JSON format.
///
/// The DICOMweb JSON encoding represents a DICOM object as a flat dictionary
/// mapping 8-character hex tag strings to ``DICOMAttribute`` objects.
///
/// Reference: DICOM PS3.18 Section F — DICOM JSON Model
public enum DICOMJSONSerializer {

    // MARK: - Study Metadata

    /// Builds a DICOM JSON object representing a study result for QIDO-RS.
    ///
    /// Includes the mandatory and commonly-used study-level attributes.
    ///
    /// - Parameters:
    ///   - study: The study model.
    ///   - patient: The owning patient model.
    ///   - numberOfSeries: The number of series in the study.
    ///   - numberOfInstances: The total number of instances in the study.
    /// - Returns: A dictionary mapping tag strings to ``DICOMAttribute`` values.
    public static func studyAttributes(
        study: Study,
        patient: Patient,
        numberOfSeries: Int = 0,
        numberOfInstances: Int = 0
    ) -> [String: DICOMAttribute] {
        var attrs: [String: DICOMAttribute] = [:]

        // (0008,0020) Study Date
        if let date = study.studyDate {
            attrs["00080020"] = DICOMAttribute(vr: "DA", stringValues: [formatDICOMDate(date)])
        } else {
            attrs["00080020"] = DICOMAttribute(vr: "DA", stringValues: [])
        }

        // (0008,0030) Study Time
        if let date = study.studyDate {
            attrs["00080030"] = DICOMAttribute(vr: "TM", stringValues: [formatDICOMTime(date)])
        } else {
            attrs["00080030"] = DICOMAttribute(vr: "TM", stringValues: [])
        }

        // (0008,0050) Accession Number
        attrs["00080050"] = DICOMAttribute(vr: "SH", stringValues: [])

        // (0008,0056) Instance Availability
        attrs["00080056"] = DICOMAttribute(vr: "CS", stringValues: ["ONLINE"])

        // (0008,0061) Modalities in Study
        if let modality = study.modality {
            attrs["00080061"] = DICOMAttribute(vr: "CS", stringValues: [modality])
        } else {
            attrs["00080061"] = DICOMAttribute(vr: "CS", stringValues: [])
        }

        // (0008,1030) Study Description
        attrs["00081030"] = DICOMAttribute(vr: "LO", stringValues: [study.studyDescription])

        // (0008,1190) Retrieve URL
        attrs["00081190"] = DICOMAttribute(vr: "UR", stringValues: [])

        // (0010,0010) Patient Name
        attrs["00100010"] = DICOMAttribute(vr: "PN", stringValues: [patient.patientName])

        // (0010,0020) Patient ID
        attrs["00100020"] = DICOMAttribute(vr: "LO", stringValues: [patient.patientID])

        // (0020,000D) Study Instance UID
        attrs["0020000D"] = DICOMAttribute(vr: "UI", stringValues: [study.studyInstanceUID])

        // (0020,0010) Study ID
        attrs["00200010"] = DICOMAttribute(vr: "SH", stringValues: [])

        // (0020,1206) Number of Study Related Series
        attrs["00201206"] = DICOMAttribute(vr: "IS", stringValues: [String(numberOfSeries)])

        // (0020,1208) Number of Study Related Instances
        attrs["00201208"] = DICOMAttribute(vr: "IS", stringValues: [String(numberOfInstances)])

        return attrs
    }

    // MARK: - Series Metadata

    /// Builds a DICOM JSON object representing a series result for QIDO-RS.
    ///
    /// - Parameters:
    ///   - series: The series model.
    ///   - study: The owning study.
    ///   - numberOfInstances: Number of instances in the series.
    /// - Returns: A dictionary mapping tag strings to ``DICOMAttribute`` values.
    public static func seriesAttributes(
        series: Series,
        study: Study,
        numberOfInstances: Int = 0
    ) -> [String: DICOMAttribute] {
        var attrs: [String: DICOMAttribute] = [:]

        // (0008,0060) Modality
        attrs["00080060"] = DICOMAttribute(vr: "CS", stringValues: [series.modality])

        // (0008,103E) Series Description
        attrs["0008103E"] = DICOMAttribute(vr: "LO", stringValues: [series.seriesDescription])

        // (0008,1190) Retrieve URL
        attrs["00081190"] = DICOMAttribute(vr: "UR", stringValues: [])

        // (0020,000D) Study Instance UID
        attrs["0020000D"] = DICOMAttribute(vr: "UI", stringValues: [study.studyInstanceUID])

        // (0020,000E) Series Instance UID
        attrs["0020000E"] = DICOMAttribute(vr: "UI", stringValues: [series.seriesInstanceUID])

        // (0020,0011) Series Number
        if let num = series.seriesNumber {
            attrs["00200011"] = DICOMAttribute(vr: "IS", stringValues: [String(num)])
        } else {
            attrs["00200011"] = DICOMAttribute(vr: "IS", stringValues: [])
        }

        // (0020,1209) Number of Series Related Instances
        attrs["00201209"] = DICOMAttribute(vr: "IS", stringValues: [String(numberOfInstances)])

        return attrs
    }

    // MARK: - Instance Metadata

    /// Builds a DICOM JSON object representing an instance result for QIDO-RS.
    ///
    /// - Parameters:
    ///   - instance: The instance model.
    ///   - series: The owning series.
    ///   - study: The owning study.
    /// - Returns: A dictionary mapping tag strings to ``DICOMAttribute`` values.
    public static func instanceAttributes(
        instance: Instance,
        series: Series,
        study: Study
    ) -> [String: DICOMAttribute] {
        var attrs: [String: DICOMAttribute] = [:]

        // (0008,0016) SOP Class UID
        attrs["00080016"] = DICOMAttribute(vr: "UI", stringValues: [instance.sopClassUID])

        // (0008,0018) SOP Instance UID
        attrs["00080018"] = DICOMAttribute(vr: "UI", stringValues: [instance.sopInstanceUID])

        // (0008,0060) Modality
        attrs["00080060"] = DICOMAttribute(vr: "CS", stringValues: [series.modality])

        // (0008,1190) Retrieve URL
        attrs["00081190"] = DICOMAttribute(vr: "UR", stringValues: [])

        // (0020,000D) Study Instance UID
        attrs["0020000D"] = DICOMAttribute(vr: "UI", stringValues: [study.studyInstanceUID])

        // (0020,000E) Series Instance UID
        attrs["0020000E"] = DICOMAttribute(vr: "UI", stringValues: [series.seriesInstanceUID])

        // (0020,0013) Instance Number
        if let num = instance.instanceNumber {
            attrs["00200013"] = DICOMAttribute(vr: "IS", stringValues: [String(num)])
        } else {
            attrs["00200013"] = DICOMAttribute(vr: "IS", stringValues: [])
        }

        // (0028,0008) Number of Frames
        attrs["00280008"] = DICOMAttribute(vr: "IS", stringValues: [])

        // (0028,0010) Rows
        attrs["00280010"] = DICOMAttribute(vr: "US", numberValues: [])

        // (0028,0011) Columns
        attrs["00280011"] = DICOMAttribute(vr: "US", numberValues: [])

        // (0040,E001) HL7 Instance Identifier — omitted for DICOM instances
        // (0042,0011) Encapsulated Document — omitted

        return attrs
    }

    // MARK: - JSON Encoding

    /// Encodes a DICOM JSON attribute map to `Data` using the standard JSON encoder.
    ///
    /// - Parameter attributes: The attribute map to encode.
    /// - Returns: JSON-encoded `Data`.
    /// - Throws: If JSON encoding fails.
    public static func encode(_ attributes: [String: DICOMAttribute]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(attributes)
    }

    /// Encodes an array of DICOM JSON attribute maps.
    ///
    /// - Parameter attributesList: Array of attribute maps.
    /// - Returns: JSON-encoded `Data` representing a JSON array.
    /// - Throws: If JSON encoding fails.
    public static func encodeArray(_ attributesList: [[String: DICOMAttribute]]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(attributesList)
    }

    // MARK: - Date Formatting Helpers

    /// Formats a `Date` as a DICOM DA string (`YYYYMMDD`).
    public static func formatDICOMDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// Formats a `Date` as a DICOM TM string (`HHMMSS.FFFFFF`).
    ///
    /// DICOM TM format requires exactly 6 fractional-second digits.
    /// `DateFormatter` only supports millisecond precision (3 digits), so
    /// the result is zero-padded to produce the required 6-digit fraction.
    public static func formatDICOMTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let base = formatter.string(from: date)
        // Append milliseconds zero-padded to 6 fractional digits
        let milliFormatter = DateFormatter()
        milliFormatter.dateFormat = "SSS"
        milliFormatter.timeZone = TimeZone(identifier: "UTC")
        let milli = milliFormatter.string(from: date)
        return "\(base).\(milli)000"
    }
}
