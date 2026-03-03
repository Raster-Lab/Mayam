// SPDX-License-Identifier: (see LICENSE)
// Mayam — Privacy Flag Enforcement Service

import Foundation

/// Enforces privacy flag restrictions on query and retrieve operations.
///
/// When the `privacyFlag` is set on a Patient or Study entity, access to that
/// entity's data is restricted.  The service filters query results and
/// validates retrieve requests against ACLs.
///
/// ## Enforcement Rules
/// - **C-FIND / QIDO-RS queries**: Flagged entities are suppressed from
///   results for unauthorised users.
/// - **C-MOVE / C-GET / WADO-RS retrieval**: Retrieve requests for flagged
///   entities are rejected for unauthorised users.
/// - **Routing rules**: Flagged entities are excluded from automatic routing
///   unless an explicit override is present.
/// - **Administrators** are exempt from privacy flag restrictions.
///
/// ## DICOM References
/// - DICOM PS3.15 — Security and System Management Profiles
public actor PrivacyFlagService {

    // MARK: - Nested Types

    /// Error indicating that access was denied due to a privacy flag.
    public enum PrivacyError: Error, Sendable, CustomStringConvertible, Equatable {
        /// Access to a patient was denied due to the privacy flag.
        case patientAccessDenied(patientID: String)
        /// Access to a study was denied due to the privacy flag.
        case studyAccessDenied(studyInstanceUID: String)

        public var description: String {
            switch self {
            case .patientAccessDenied(let id):
                return "Access denied: Patient '\(id)' has the privacy flag set. Authorisation required."
            case .studyAccessDenied(let uid):
                return "Access denied: Study '\(uid)' has the privacy flag set. Authorisation required."
            }
        }
    }

    // MARK: - Stored Properties

    /// The access control service used to evaluate ACLs.
    private let accessControlService: AccessControlService?

    /// Logger for privacy enforcement operations.
    private let logger: MayamLogger

    /// Optional audit repository for recording enforcement events.
    private let auditRepository: ATNAAuditRepository?

    // MARK: - Initialiser

    /// Creates a new privacy flag service.
    ///
    /// - Parameters:
    ///   - accessControlService: The ACL service for authorisation checks.
    ///   - auditRepository: Optional ATNA audit repository for recording
    ///     enforcement events.
    public init(
        accessControlService: AccessControlService? = nil,
        auditRepository: ATNAAuditRepository? = nil
    ) {
        self.accessControlService = accessControlService
        self.auditRepository = auditRepository
        self.logger = MayamLogger(label: "com.raster-lab.mayam.privacy")
    }

    // MARK: - Query Filtering

    /// Filters a list of patients, removing those with the privacy flag set
    /// for which the user is not authorised.
    ///
    /// - Parameters:
    ///   - patients: The full list of patients.
    ///   - username: The authenticated user's username.
    ///   - role: The user's administrative role.
    /// - Returns: The filtered list of patients the user may see.
    public func filterPatients(
        _ patients: [Patient],
        forUser username: String,
        role: AdminRole
    ) async -> [Patient] {
        // Administrators see everything.
        if role == .administrator { return patients }

        var result: [Patient] = []
        for patient in patients {
            if patient.privacyFlag {
                guard let acl = accessControlService else { continue }
                guard let patientDBID = patient.id else { continue }
                let authorised = await acl.isAuthorised(
                    username: username,
                    role: role,
                    entityType: .patient,
                    entityID: patientDBID
                )
                if authorised {
                    result.append(patient)
                } else {
                    logger.info("Privacy filter: Patient \(patient.patientID) suppressed for user \(username)")
                }
            } else {
                result.append(patient)
            }
        }
        return result
    }

    /// Filters a list of studies, removing those with the privacy flag set
    /// for which the user is not authorised.
    ///
    /// - Parameters:
    ///   - studies: The full list of studies.
    ///   - username: The authenticated user's username.
    ///   - role: The user's administrative role.
    /// - Returns: The filtered list of studies the user may see.
    public func filterStudies(
        _ studies: [Study],
        forUser username: String,
        role: AdminRole
    ) async -> [Study] {
        // Administrators see everything.
        if role == .administrator { return studies }

        var result: [Study] = []
        for study in studies {
            if study.privacyFlag {
                guard let acl = accessControlService else { continue }
                guard let studyDBID = study.id else { continue }
                let authorised = await acl.isAuthorised(
                    username: username,
                    role: role,
                    entityType: .study,
                    entityID: studyDBID
                )
                if authorised {
                    result.append(study)
                } else {
                    logger.info("Privacy filter: Study \(study.studyInstanceUID) suppressed for user \(username)")
                }
            } else {
                result.append(study)
            }
        }
        return result
    }

    // MARK: - Retrieve Validation

    /// Validates that a user is authorised to retrieve a patient's data.
    ///
    /// - Parameters:
    ///   - patient: The patient whose data is being retrieved.
    ///   - username: The authenticated user's username.
    ///   - role: The user's administrative role.
    /// - Throws: ``PrivacyError/patientAccessDenied(patientID:)`` if the
    ///   patient's privacy flag is set and the user is not authorised.
    public func validateAccess(
        to patient: Patient,
        username: String,
        role: AdminRole
    ) async throws {
        guard patient.privacyFlag else { return }
        if role == .administrator { return }

        if let acl = accessControlService, let patientDBID = patient.id {
            let authorised = await acl.isAuthorised(
                username: username,
                role: role,
                entityType: .patient,
                entityID: patientDBID
            )
            if authorised { return }
        }

        logger.warning("Privacy flag enforcement: access denied to Patient \(patient.patientID) for user \(username)")
        await recordAuditEvent(entityType: "Patient", entityID: patient.patientID, username: username)
        throw PrivacyError.patientAccessDenied(patientID: patient.patientID)
    }

    /// Validates that a user is authorised to retrieve a study's data.
    ///
    /// - Parameters:
    ///   - study: The study whose data is being retrieved.
    ///   - username: The authenticated user's username.
    ///   - role: The user's administrative role.
    /// - Throws: ``PrivacyError/studyAccessDenied(studyInstanceUID:)`` if the
    ///   study's privacy flag is set and the user is not authorised.
    public func validateAccess(
        to study: Study,
        username: String,
        role: AdminRole
    ) async throws {
        guard study.privacyFlag else { return }
        if role == .administrator { return }

        if let acl = accessControlService, let studyDBID = study.id {
            let authorised = await acl.isAuthorised(
                username: username,
                role: role,
                entityType: .study,
                entityID: studyDBID
            )
            if authorised { return }
        }

        logger.warning("Privacy flag enforcement: access denied to Study \(study.studyInstanceUID) for user \(username)")
        await recordAuditEvent(entityType: "Study", entityID: study.studyInstanceUID, username: username)
        throw PrivacyError.studyAccessDenied(studyInstanceUID: study.studyInstanceUID)
    }

    // MARK: - Routing Filter

    /// Determines whether a study should be included in automatic routing.
    ///
    /// Studies with the privacy flag set are excluded from routing unless an
    /// explicit override is present.
    ///
    /// - Parameters:
    ///   - study: The study being considered for routing.
    ///   - overrideEnabled: Whether a routing override is in effect.
    /// - Returns: `true` if the study should be routed; `false` otherwise.
    public func shouldRoute(study: Study, overrideEnabled: Bool = false) -> Bool {
        if study.privacyFlag && !overrideEnabled {
            logger.info("Privacy flag: Study \(study.studyInstanceUID) excluded from routing")
            return false
        }
        return true
    }

    // MARK: - Private Helpers

    /// Records a privacy enforcement audit event.
    private func recordAuditEvent(
        entityType: String,
        entityID: String,
        username: String
    ) async {
        guard let auditRepository else { return }

        let event = ATNAAuditEvent(
            eventID: .securityAlert,
            eventOutcome: .seriousFailure,
            eventActionDescription: "Privacy flag access denied: \(entityType) \(entityID)",
            activeParticipants: [
                ATNAAuditEvent.ActiveParticipant(userID: username, userIsRequestor: true)
            ],
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
