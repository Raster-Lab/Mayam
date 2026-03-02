// SPDX-License-Identifier: (see LICENSE)
// Mayam — Modality Worklist SCP

import Foundation
import DICOMNetwork

// MARK: - ModalityWorklistSCP

/// Handles Modality Worklist (MWL) C-FIND requests from modalities.
///
/// The MWL SCP serves scheduled procedure step information in response to
/// C-FIND queries, allowing modalities to retrieve patient demographics and
/// procedure details for procedures scheduled to be performed.
///
/// Reference: DICOM PS3.4 Annex K — Modality Worklist Information Model
public actor ModalityWorklistSCP {

    // MARK: - Constants

    /// Modality Worklist Information Model — FIND SOP Class UID.
    /// Reference: DICOM PS3.4 Annex K.
    public static let sopClassUID = "1.2.840.10008.5.1.4.31"

    // MARK: - Stored Properties

    /// A closure that returns all scheduled procedure steps matching
    /// the given query criteria.
    private let worklistProvider: @Sendable (WorklistQuery) async -> [ScheduledProcedureStep]

    /// Logger for worklist events.
    private let logger: MayamLogger

    // MARK: - Initialiser

    /// Creates a new Modality Worklist SCP.
    ///
    /// - Parameters:
    ///   - worklistProvider: A closure that returns matching scheduled
    ///     procedure steps for the given query.
    ///   - logger: Logger instance for worklist events.
    public init(
        worklistProvider: @escaping @Sendable (WorklistQuery) async -> [ScheduledProcedureStep],
        logger: MayamLogger
    ) {
        self.worklistProvider = worklistProvider
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Processes a C-FIND request for scheduled procedure steps.
    ///
    /// Parses the query identifier to extract matching criteria, queries
    /// the worklist provider, and returns matching results as C-FIND
    /// responses.
    ///
    /// - Parameters:
    ///   - request: The C-FIND request message.
    ///   - identifier: The query identifier data set containing search criteria.
    ///   - presentationContextID: The negotiated presentation context ID.
    /// - Returns: An array of C-FIND responses with matching procedure steps.
    public func handleCFind(
        request: CFindRequest,
        identifier: Data,
        presentationContextID: UInt8
    ) async -> [(response: CFindResponse, dataSet: Data?)] {
        logger.info("MWL C-FIND: Processing worklist query from message \(request.messageID)")

        let query = parseWorklistQuery(from: identifier)
        let matchingSteps = await worklistProvider(query)

        logger.info("MWL C-FIND: Found \(matchingSteps.count) matching scheduled procedure step(s)")

        var results: [(response: CFindResponse, dataSet: Data?)] = []

        for step in matchingSteps {
            let responseData = encodeScheduledProcedureStep(step)
            let pendingResponse = CFindResponse(
                messageIDBeingRespondedTo: request.messageID,
                affectedSOPClassUID: request.affectedSOPClassUID,
                status: .pending(warningOptionalKeys: false),
                hasDataSet: true,
                presentationContextID: presentationContextID
            )
            results.append((response: pendingResponse, dataSet: responseData))
        }

        // Final success response
        let finalResponse = CFindResponse(
            messageIDBeingRespondedTo: request.messageID,
            affectedSOPClassUID: request.affectedSOPClassUID,
            status: .success,
            hasDataSet: false,
            presentationContextID: presentationContextID
        )
        results.append((response: finalResponse, dataSet: nil))

        return results
    }

    // MARK: - Private Methods

    /// Parses worklist query criteria from a raw DICOM identifier data set.
    ///
    /// - Parameter data: The raw DICOM identifier bytes.
    /// - Returns: A ``WorklistQuery`` with extracted search criteria.
    private func parseWorklistQuery(from data: Data) -> WorklistQuery {
        var patientID: String?
        var patientName: String?
        var modality: String?
        var scheduledDate: String?
        var scheduledStationAETitle: String?
        var accessionNumber: String?

        var offset = 0
        while offset + 8 <= data.count {
            let group = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            let element = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)

            let lengthOffset = offset + 4
            var valueLength: UInt32 = 0
            var valueOffset = lengthOffset

            // Check for explicit VR (2-char VR code in ASCII range)
            let byte4 = data[offset + 4]
            let byte5 = data[offset + 5]
            let isExplicitVR = (byte4 >= 0x41 && byte4 <= 0x5A) && (byte5 >= 0x41 && byte5 <= 0x5A)

            if isExplicitVR {
                let vr0 = Character(UnicodeScalar(byte4))
                let vr1 = Character(UnicodeScalar(byte5))
                let vrStr = String([vr0, vr1])

                if ["OB", "OD", "OF", "OL", "OW", "SQ", "UC", "UN", "UR", "UT"].contains(vrStr) {
                    // 4-byte length after 2 reserved bytes
                    if offset + 12 <= data.count {
                        valueLength = UInt32(data[offset + 8]) | (UInt32(data[offset + 9]) << 8) |
                                      (UInt32(data[offset + 10]) << 16) | (UInt32(data[offset + 11]) << 24)
                        valueOffset = offset + 12
                    }
                } else {
                    // 2-byte length
                    valueLength = UInt32(UInt16(data[offset + 6]) | (UInt16(data[offset + 7]) << 8))
                    valueOffset = offset + 8
                }
            } else {
                // Implicit VR — 4-byte length
                if offset + 8 <= data.count {
                    valueLength = UInt32(data[offset + 4]) | (UInt32(data[offset + 5]) << 8) |
                                  (UInt32(data[offset + 6]) << 16) | (UInt32(data[offset + 7]) << 24)
                    valueOffset = offset + 8
                }
            }

            if valueLength == 0xFFFFFFFF { valueLength = 0 }

            let endOffset = valueOffset + Int(valueLength)
            if endOffset <= data.count && valueLength > 0 {
                let valueData = data[valueOffset..<endOffset]
                var stringValue = String(data: Data(valueData), encoding: .ascii)?
                    .trimmingCharacters(in: .whitespaces.union(.controlCharacters))

                if stringValue?.isEmpty == true { stringValue = nil }

                switch (group, element) {
                case (0x0010, 0x0020): patientID = stringValue
                case (0x0010, 0x0010): patientName = stringValue
                case (0x0008, 0x0060): modality = stringValue
                case (0x0040, 0x0002): scheduledDate = stringValue
                case (0x0040, 0x0001): scheduledStationAETitle = stringValue
                case (0x0008, 0x0050): accessionNumber = stringValue
                default: break
                }
            }

            offset = endOffset > offset ? endOffset : offset + 8
        }

        return WorklistQuery(
            patientID: patientID,
            patientName: patientName,
            modality: modality,
            scheduledDate: scheduledDate,
            scheduledStationAETitle: scheduledStationAETitle,
            accessionNumber: accessionNumber
        )
    }

    /// Encodes a scheduled procedure step into a DICOM data set for C-FIND response.
    ///
    /// - Parameter step: The scheduled procedure step to encode.
    /// - Returns: Raw DICOM data set bytes.
    private func encodeScheduledProcedureStep(_ step: ScheduledProcedureStep) -> Data {
        var data = Data()

        func appendTag(group: UInt16, element: UInt16, value: String) {
            var tagData = Data()
            tagData.append(UInt8(group & 0xFF))
            tagData.append(UInt8(group >> 8))
            tagData.append(UInt8(element & 0xFF))
            tagData.append(UInt8(element >> 8))

            var padded = value
            if padded.count % 2 != 0 { padded += " " }
            let valueBytes = Array(padded.utf8)
            let length = UInt32(valueBytes.count)
            tagData.append(UInt8(length & 0xFF))
            tagData.append(UInt8((length >> 8) & 0xFF))
            tagData.append(UInt8((length >> 16) & 0xFF))
            tagData.append(UInt8((length >> 24) & 0xFF))
            tagData.append(contentsOf: valueBytes)
            data.append(tagData)
        }

        // Encode key attributes in tag order
        appendTag(group: 0x0008, element: 0x0050, value: step.accessionNumber)
        appendTag(group: 0x0008, element: 0x0060, value: step.modality)
        if let desc = step.requestedProcedureDescription {
            appendTag(group: 0x0008, element: 0x1030, value: desc)
        }
        appendTag(group: 0x0010, element: 0x0010, value: step.patientName)
        appendTag(group: 0x0010, element: 0x0020, value: step.patientID)
        if let dob = step.patientBirthDate {
            appendTag(group: 0x0010, element: 0x0030, value: dob)
        }
        if let sex = step.patientSex {
            appendTag(group: 0x0010, element: 0x0040, value: sex)
        }
        appendTag(group: 0x0020, element: 0x000D, value: step.studyInstanceUID)
        if let ae = step.scheduledStationAETitle {
            appendTag(group: 0x0040, element: 0x0001, value: ae)
        }
        appendTag(group: 0x0040, element: 0x0002, value: step.scheduledStartDate)
        if let time = step.scheduledStartTime {
            appendTag(group: 0x0040, element: 0x0003, value: time)
        }
        if let desc = step.scheduledProcedureStepDescription {
            appendTag(group: 0x0040, element: 0x0007, value: desc)
        }
        appendTag(group: 0x0040, element: 0x0009, value: step.scheduledProcedureStepID)
        if let loc = step.scheduledProcedureStepLocation {
            appendTag(group: 0x0040, element: 0x0011, value: loc)
        }

        return data
    }
}

// MARK: - WorklistQuery

/// Encapsulates query criteria for a Modality Worklist C-FIND request.
public struct WorklistQuery: Sendable, Equatable {

    /// Patient ID filter (supports wildcards).
    public var patientID: String?

    /// Patient Name filter (supports wildcards).
    public var patientName: String?

    /// Modality filter.
    public var modality: String?

    /// Scheduled Date filter (DICOM DA format, supports ranges).
    public var scheduledDate: String?

    /// Scheduled Station AE Title filter.
    public var scheduledStationAETitle: String?

    /// Accession Number filter.
    public var accessionNumber: String?

    /// Creates a worklist query.
    ///
    /// - Parameters:
    ///   - patientID: Patient ID filter.
    ///   - patientName: Patient Name filter.
    ///   - modality: Modality filter.
    ///   - scheduledDate: Scheduled date filter.
    ///   - scheduledStationAETitle: Station AE Title filter.
    ///   - accessionNumber: Accession Number filter.
    public init(
        patientID: String? = nil,
        patientName: String? = nil,
        modality: String? = nil,
        scheduledDate: String? = nil,
        scheduledStationAETitle: String? = nil,
        accessionNumber: String? = nil
    ) {
        self.patientID = patientID
        self.patientName = patientName
        self.modality = modality
        self.scheduledDate = scheduledDate
        self.scheduledStationAETitle = scheduledStationAETitle
        self.accessionNumber = accessionNumber
    }
}
