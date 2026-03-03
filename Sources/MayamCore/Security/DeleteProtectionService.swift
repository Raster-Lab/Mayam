// SPDX-License-Identifier: (see LICENSE)
// Mayam — Delete Protection Enforcement Service

import Foundation

/// Enforces delete protection flags on Patient, Accession, and Study entities.
///
/// When the `deleteProtect` flag is set on an entity, all deletion requests
/// for that entity (and its child records) are rejected with a descriptive
/// error.  The flag must be explicitly removed by an authorised user before
/// deletion can proceed.
///
/// ## Audit
/// All enforcement decisions (both rejections and successful checks) are logged
/// for audit purposes.
///
/// ## DICOM References
/// - DICOM PS3.15 — Security and System Management Profiles
public actor DeleteProtectionService {

    // MARK: - Nested Types

    /// Error indicating that a deletion was blocked by delete protection.
    public enum DeleteProtectionError: Error, Sendable, CustomStringConvertible, Equatable {
        /// The patient entity is delete-protected.
        case patientProtected(patientID: String)
        /// The accession entity is delete-protected.
        case accessionProtected(accessionNumber: String)
        /// The study entity is delete-protected.
        case studyProtected(studyInstanceUID: String)

        public var description: String {
            switch self {
            case .patientProtected(let id):
                return "Deletion blocked: Patient '\(id)' is delete-protected. Remove the protection flag before deleting."
            case .accessionProtected(let num):
                return "Deletion blocked: Accession '\(num)' is delete-protected. Remove the protection flag before deleting."
            case .studyProtected(let uid):
                return "Deletion blocked: Study '\(uid)' is delete-protected. Remove the protection flag before deleting."
            }
        }
    }

    // MARK: - Stored Properties

    /// Logger for enforcement operations.
    private let logger: MayamLogger

    /// Optional audit repository for recording enforcement events.
    private let auditRepository: ATNAAuditRepository?

    // MARK: - Initialiser

    /// Creates a new delete protection service.
    ///
    /// - Parameter auditRepository: Optional ATNA audit repository for
    ///   recording enforcement events.
    public init(auditRepository: ATNAAuditRepository? = nil) {
        self.logger = MayamLogger(label: "com.raster-lab.mayam.delete-protection")
        self.auditRepository = auditRepository
    }

    // MARK: - Public Methods

    /// Validates that a patient can be deleted.
    ///
    /// - Parameter patient: The patient entity to check.
    /// - Throws: ``DeleteProtectionError/patientProtected(patientID:)`` if the
    ///   patient's delete protection flag is set.
    public func validateDeletion(of patient: Patient) async throws {
        if patient.deleteProtect {
            logger.warning("Delete protection enforced for Patient: \(patient.patientID)")
            await recordAuditEvent(
                entityType: "Patient",
                entityID: patient.patientID,
                outcome: .seriousFailure
            )
            throw DeleteProtectionError.patientProtected(patientID: patient.patientID)
        }
        logger.info("Delete protection check passed for Patient: \(patient.patientID)")
    }

    /// Validates that an accession can be deleted.
    ///
    /// - Parameter accession: The accession entity to check.
    /// - Throws: ``DeleteProtectionError/accessionProtected(accessionNumber:)``
    ///   if the accession's delete protection flag is set.
    public func validateDeletion(of accession: Accession) async throws {
        if accession.deleteProtect {
            logger.warning("Delete protection enforced for Accession: \(accession.accessionNumber)")
            await recordAuditEvent(
                entityType: "Accession",
                entityID: accession.accessionNumber,
                outcome: .seriousFailure
            )
            throw DeleteProtectionError.accessionProtected(accessionNumber: accession.accessionNumber)
        }
        logger.info("Delete protection check passed for Accession: \(accession.accessionNumber)")
    }

    /// Validates that a study can be deleted.
    ///
    /// - Parameter study: The study entity to check.
    /// - Throws: ``DeleteProtectionError/studyProtected(studyInstanceUID:)`` if
    ///   the study's delete protection flag is set.
    public func validateDeletion(of study: Study) async throws {
        if study.deleteProtect {
            logger.warning("Delete protection enforced for Study: \(study.studyInstanceUID)")
            await recordAuditEvent(
                entityType: "Study",
                entityID: study.studyInstanceUID,
                outcome: .seriousFailure
            )
            throw DeleteProtectionError.studyProtected(studyInstanceUID: study.studyInstanceUID)
        }
        logger.info("Delete protection check passed for Study: \(study.studyInstanceUID)")
    }

    // MARK: - Private Helpers

    /// Records a delete protection enforcement audit event.
    private func recordAuditEvent(
        entityType: String,
        entityID: String,
        outcome: ATNAAuditEvent.EventOutcome
    ) async {
        guard let auditRepository else { return }

        let event = ATNAAuditEvent(
            eventID: .dicomStudyDeleted,
            eventOutcome: outcome,
            eventActionDescription: "Delete protection enforced: \(entityType) \(entityID)",
            participantObjects: [
                ATNAAuditEvent.ParticipantObject(
                    participantObjectTypeCode: 2,
                    participantObjectTypeCodeRole: 4,
                    participantObjectID: entityID,
                    participantObjectName: entityType
                )
            ]
        )
        await auditRepository.record(event)
    }
}
