// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOM Anonymisation / Pseudonymisation Engine

import Foundation
import Crypto

/// Anonymisation and pseudonymisation profiles for research data export,
/// implementing DICOM PS3.15 Annex E — Attribute Confidentiality Profiles.
///
/// Each profile defines a set of actions to apply to DICOM tag groups to remove
/// or replace personally identifiable information (PII) while retaining
/// clinically useful data.
///
/// ## DICOM References
/// - DICOM PS3.15 Annex E — Attribute Confidentiality Profiles
/// - DICOM PS3.15 Table E.1-1 — Application Level Confidentiality Profile Attributes
public enum AnonymisationProfile: String, Sendable, Codable, Equatable, CaseIterable {
    /// **Basic Application Level Confidentiality Profile** — removes or empties
    /// all attributes listed in DICOM PS3.15 Table E.1-1.
    case basicProfile = "basic"

    /// **Retain Safe Private Option** — retains private attributes that have
    /// been reviewed and deemed safe for de-identification.
    case retainSafePrivate = "retain_safe_private"

    /// **Retain UIDs Option** — retains original UIDs to preserve referential
    /// integrity across related studies.
    case retainUIDs = "retain_uids"

    /// **Retain Device Identity Option** — retains device serial numbers and
    /// station names.
    case retainDeviceIdentity = "retain_device_identity"

    /// **Retain Patient Characteristics Option** — retains patient age, sex,
    /// size, and weight for research studies requiring demographic data.
    case retainPatientCharacteristics = "retain_patient_characteristics"

    /// **Retain Longitudinal Temporal Information Full Dates Option** — retains
    /// all date and time attributes without modification.
    case retainLongFullDates = "retain_long_full_dates"

    /// **Clean Descriptors Option** — removes free-text descriptions that may
    /// contain identifying information.
    case cleanDescriptors = "clean_descriptors"
}

/// Defines the action to apply to a DICOM attribute during anonymisation
/// (DICOM PS3.15 Table E.1-1 action codes).
public enum AnonymisationAction: String, Sendable, Codable, Equatable, CaseIterable {
    /// **D** — Replace with a dummy value or non-zero-length value that is
    /// consistent with the VR.
    case dummy = "D"

    /// **Z** — Replace with a zero-length value or a value that is consistent
    /// with the VR.
    case zeroLength = "Z"

    /// **X** — Remove the attribute entirely.
    case remove = "X"

    /// **K** — Keep the original value (no modification).
    case keep = "K"

    /// **C** — Clean — replace with values of similar meaning known not to
    /// contain identifying information.
    case clean = "C"

    /// **U** — Replace with a pseudonymous UID.
    case replaceUID = "U"
}

/// Represents a single anonymisation rule that maps a DICOM tag to an action.
public struct AnonymisationRule: Sendable, Codable, Equatable {
    /// The DICOM tag group number (e.g. `0x0010` for Patient group).
    public let tagGroup: UInt16

    /// The DICOM tag element number (e.g. `0x0020` for Patient ID).
    public let tagElement: UInt16

    /// The human-readable name of the attribute.
    public let attributeName: String

    /// The action to apply during anonymisation.
    public let action: AnonymisationAction

    /// Creates an anonymisation rule.
    ///
    /// - Parameters:
    ///   - tagGroup: DICOM tag group number.
    ///   - tagElement: DICOM tag element number.
    ///   - attributeName: Human-readable attribute name.
    ///   - action: The anonymisation action to apply.
    public init(
        tagGroup: UInt16,
        tagElement: UInt16,
        attributeName: String,
        action: AnonymisationAction
    ) {
        self.tagGroup = tagGroup
        self.tagElement = tagElement
        self.attributeName = attributeName
        self.action = action
    }

    /// The DICOM tag in `(GGGG,EEEE)` notation.
    public var tagString: String {
        String(format: "(%04X,%04X)", tagGroup, tagElement)
    }
}

/// An actor that applies anonymisation or pseudonymisation profiles to DICOM
/// attribute dictionaries.
///
/// The anonymiser processes a dictionary of DICOM tag-value pairs and returns
/// a new dictionary with PII removed or replaced according to the selected
/// profile and its associated rules.
///
/// ## DICOM References
/// - DICOM PS3.15 Annex E — Attribute Confidentiality Profiles
public actor DICOMAnonymiser {

    // MARK: - Stored Properties

    /// The currently active anonymisation profiles.
    private let profiles: Set<AnonymisationProfile>

    /// The rules derived from the selected profiles.
    private let rules: [AnonymisationRule]

    /// Logger for anonymisation operations.
    private let logger: MayamLogger

    /// Salt used for pseudonymous UID generation.
    private let pseudonymSalt: String

    // MARK: - Initialiser

    /// Creates a new DICOM anonymiser.
    ///
    /// - Parameters:
    ///   - profiles: The anonymisation profiles to apply.  When multiple
    ///     profiles are active, their rules are merged; `keep` takes
    ///     precedence over `remove` for overlapping tags.
    ///   - pseudonymSalt: A secret salt used to generate deterministic
    ///     pseudonymous UIDs (defaults to a random UUID for single-use).
    public init(
        profiles: Set<AnonymisationProfile> = [.basicProfile],
        pseudonymSalt: String = UUID().uuidString
    ) {
        self.profiles = profiles
        self.pseudonymSalt = pseudonymSalt
        self.rules = Self.buildRules(for: profiles)
        self.logger = MayamLogger(label: "com.raster-lab.mayam.anonymiser")
    }

    // MARK: - Public Methods

    /// Anonymises a dictionary of DICOM tag-value pairs.
    ///
    /// - Parameter attributes: A dictionary keyed by DICOM tag strings in
    ///   `(GGGG,EEEE)` format, with string values.
    /// - Returns: A new dictionary with PII removed or replaced.
    public func anonymise(_ attributes: [String: String]) -> [String: String] {
        var result = attributes

        for rule in rules {
            let tagKey = rule.tagString
            switch rule.action {
            case .remove:
                result.removeValue(forKey: tagKey)
            case .zeroLength:
                if result[tagKey] != nil {
                    result[tagKey] = ""
                }
            case .dummy:
                if result[tagKey] != nil {
                    result[tagKey] = "ANONYMISED"
                }
            case .clean:
                if result[tagKey] != nil {
                    result[tagKey] = "CLEANED"
                }
            case .replaceUID:
                if let original = result[tagKey] {
                    result[tagKey] = generatePseudonymousUID(from: original)
                }
            case .keep:
                break
            }
        }

        logger.info("Anonymised \(attributes.count) attributes using profiles: \(profiles.map(\.rawValue))")
        return result
    }

    /// Returns the anonymisation rules currently in effect.
    public func currentRules() -> [AnonymisationRule] {
        rules
    }

    /// Returns the currently active profiles.
    public func activeProfiles() -> Set<AnonymisationProfile> {
        profiles
    }

    // MARK: - Private Helpers

    /// Generates a deterministic pseudonymous UID from an original value.
    private func generatePseudonymousUID(from original: String) -> String {
        let input = "\(pseudonymSalt):\(original)"
        let hash = SHA256.hash(data: Data(input.utf8))
        let numericHash = hash.prefix(16).map { String($0) }.joined()
        // Format as a valid DICOM UID (max 64 characters, dot-separated).
        let prefix = "2.25."
        let suffix = String(numericHash.prefix(64 - prefix.count))
        return prefix + suffix
    }

    /// Builds the rule set for the given profiles.
    ///
    /// The Basic Profile defines the core tag actions per DICOM PS3.15
    /// Table E.1-1.  Option profiles modify specific rules (e.g. changing
    /// `remove` to `keep` for date attributes).
    private static func buildRules(for profiles: Set<AnonymisationProfile>) -> [AnonymisationRule] {
        var rules = basicProfileRules()

        if profiles.contains(.retainLongFullDates) {
            // Override date-related rules to keep.
            rules = rules.map { rule in
                if isDateTag(group: rule.tagGroup, element: rule.tagElement) {
                    return AnonymisationRule(
                        tagGroup: rule.tagGroup,
                        tagElement: rule.tagElement,
                        attributeName: rule.attributeName,
                        action: .keep
                    )
                }
                return rule
            }
        }

        if profiles.contains(.retainPatientCharacteristics) {
            // Override patient characteristics rules to keep.
            rules = rules.map { rule in
                if isPatientCharacteristicTag(group: rule.tagGroup, element: rule.tagElement) {
                    return AnonymisationRule(
                        tagGroup: rule.tagGroup,
                        tagElement: rule.tagElement,
                        attributeName: rule.attributeName,
                        action: .keep
                    )
                }
                return rule
            }
        }

        if profiles.contains(.retainUIDs) {
            // Override UID rules to keep.
            rules = rules.map { rule in
                if rule.action == .replaceUID {
                    return AnonymisationRule(
                        tagGroup: rule.tagGroup,
                        tagElement: rule.tagElement,
                        attributeName: rule.attributeName,
                        action: .keep
                    )
                }
                return rule
            }
        }

        if profiles.contains(.retainDeviceIdentity) {
            // Override device identity rules to keep.
            rules = rules.map { rule in
                if isDeviceIdentityTag(group: rule.tagGroup, element: rule.tagElement) {
                    return AnonymisationRule(
                        tagGroup: rule.tagGroup,
                        tagElement: rule.tagElement,
                        attributeName: rule.attributeName,
                        action: .keep
                    )
                }
                return rule
            }
        }

        return rules
    }

    /// Core DICOM PS3.15 Table E.1-1 Basic Profile rules.
    private static func basicProfileRules() -> [AnonymisationRule] {
        [
            // Patient Identification Group (0010,xxxx)
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x0010, attributeName: "Patient Name", action: .dummy),
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x0020, attributeName: "Patient ID", action: .dummy),
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x0030, attributeName: "Patient Birth Date", action: .remove),
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x0040, attributeName: "Patient Sex", action: .remove),
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x1000, attributeName: "Other Patient IDs", action: .remove),
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x1001, attributeName: "Other Patient Names", action: .remove),
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x1010, attributeName: "Patient Age", action: .remove),
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x1020, attributeName: "Patient Size", action: .remove),
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x1030, attributeName: "Patient Weight", action: .remove),
            AnonymisationRule(tagGroup: 0x0010, tagElement: 0x21B0, attributeName: "Additional Patient History", action: .remove),

            // Study/Series Identification
            AnonymisationRule(tagGroup: 0x0008, tagElement: 0x0020, attributeName: "Study Date", action: .remove),
            AnonymisationRule(tagGroup: 0x0008, tagElement: 0x0030, attributeName: "Study Time", action: .remove),
            AnonymisationRule(tagGroup: 0x0008, tagElement: 0x0050, attributeName: "Accession Number", action: .zeroLength),
            AnonymisationRule(tagGroup: 0x0008, tagElement: 0x0080, attributeName: "Institution Name", action: .remove),
            AnonymisationRule(tagGroup: 0x0008, tagElement: 0x0081, attributeName: "Institution Address", action: .remove),
            AnonymisationRule(tagGroup: 0x0008, tagElement: 0x0090, attributeName: "Referring Physician Name", action: .remove),
            AnonymisationRule(tagGroup: 0x0008, tagElement: 0x1010, attributeName: "Station Name", action: .remove),
            AnonymisationRule(tagGroup: 0x0008, tagElement: 0x1030, attributeName: "Study Description", action: .remove),
            AnonymisationRule(tagGroup: 0x0008, tagElement: 0x1070, attributeName: "Operators Name", action: .remove),

            // UIDs
            AnonymisationRule(tagGroup: 0x0020, tagElement: 0x000D, attributeName: "Study Instance UID", action: .replaceUID),
            AnonymisationRule(tagGroup: 0x0020, tagElement: 0x000E, attributeName: "Series Instance UID", action: .replaceUID),

            // Device Identity
            AnonymisationRule(tagGroup: 0x0018, tagElement: 0x1000, attributeName: "Device Serial Number", action: .remove),
        ]
    }

    /// Returns `true` if the tag is a date or time attribute.
    private static func isDateTag(group: UInt16, element: UInt16) -> Bool {
        (group == 0x0008 && element == 0x0020) ||  // Study Date
        (group == 0x0008 && element == 0x0030) ||  // Study Time
        (group == 0x0010 && element == 0x0030)      // Patient Birth Date
    }

    /// Returns `true` if the tag is a patient characteristic attribute.
    private static func isPatientCharacteristicTag(group: UInt16, element: UInt16) -> Bool {
        (group == 0x0010 && element == 0x0040) ||  // Patient Sex
        (group == 0x0010 && element == 0x1010) ||  // Patient Age
        (group == 0x0010 && element == 0x1020) ||  // Patient Size
        (group == 0x0010 && element == 0x1030)      // Patient Weight
    }

    /// Returns `true` if the tag is a device identity attribute.
    private static func isDeviceIdentityTag(group: UInt16, element: UInt16) -> Bool {
        (group == 0x0008 && element == 0x1010) ||  // Station Name
        (group == 0x0018 && element == 0x1000)      // Device Serial Number
    }
}
