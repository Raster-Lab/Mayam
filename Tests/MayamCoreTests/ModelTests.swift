// SPDX-License-Identifier: (see LICENSE)
// Mayam — Model Tests

import XCTest
@testable import MayamCore

final class ModelTests: XCTestCase {

    // MARK: - Patient Tests

    func test_patient_defaultValues_areCorrect() {
        let patient = Patient(patientID: "PAT001")

        XCTAssertNil(patient.id)
        XCTAssertEqual(patient.patientID, "PAT001")
        XCTAssertNil(patient.patientName)
        XCTAssertFalse(patient.deleteProtect)
        XCTAssertFalse(patient.privacyFlag)
        XCTAssertNil(patient.createdAt)
        XCTAssertNil(patient.updatedAt)
    }

    func test_patient_customValues_arePreserved() {
        let now = Date()
        let patient = Patient(
            id: 42,
            patientID: "PAT002",
            patientName: "DOE^JOHN",
            deleteProtect: true,
            privacyFlag: true,
            createdAt: now,
            updatedAt: now
        )

        XCTAssertEqual(patient.id, 42)
        XCTAssertEqual(patient.patientID, "PAT002")
        XCTAssertEqual(patient.patientName, "DOE^JOHN")
        XCTAssertTrue(patient.deleteProtect)
        XCTAssertTrue(patient.privacyFlag)
        XCTAssertEqual(patient.createdAt, now)
        XCTAssertEqual(patient.updatedAt, now)
    }

    func test_patient_codable_roundTrips() throws {
        let patient = Patient(id: 1, patientID: "PAT003", patientName: "SMITH^JANE")

        let data = try JSONEncoder().encode(patient)
        let decoded = try JSONDecoder().decode(Patient.self, from: data)

        XCTAssertEqual(patient, decoded)
    }

    func test_patient_equatable() {
        let a = Patient(patientID: "PAT004")
        let b = Patient(patientID: "PAT004")
        XCTAssertEqual(a, b)

        let c = Patient(patientID: "PAT005")
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Accession Tests

    func test_accession_defaultValues_areCorrect() {
        let accession = Accession(accessionNumber: "ACC001", patientID: 1)

        XCTAssertNil(accession.id)
        XCTAssertEqual(accession.accessionNumber, "ACC001")
        XCTAssertEqual(accession.patientID, 1)
        XCTAssertFalse(accession.deleteProtect)
        XCTAssertFalse(accession.privacyFlag)
        XCTAssertNil(accession.createdAt)
        XCTAssertNil(accession.updatedAt)
    }

    func test_accession_customValues_arePreserved() {
        let now = Date()
        let accession = Accession(
            id: 10,
            accessionNumber: "ACC002",
            patientID: 5,
            deleteProtect: true,
            privacyFlag: false,
            createdAt: now,
            updatedAt: now
        )

        XCTAssertEqual(accession.id, 10)
        XCTAssertEqual(accession.accessionNumber, "ACC002")
        XCTAssertEqual(accession.patientID, 5)
        XCTAssertTrue(accession.deleteProtect)
        XCTAssertFalse(accession.privacyFlag)
    }

    func test_accession_codable_roundTrips() throws {
        let accession = Accession(id: 7, accessionNumber: "ACC003", patientID: 2)

        let data = try JSONEncoder().encode(accession)
        let decoded = try JSONDecoder().decode(Accession.self, from: data)

        XCTAssertEqual(accession, decoded)
    }

    func test_accession_equatable() {
        let a = Accession(accessionNumber: "ACC004", patientID: 1)
        let b = Accession(accessionNumber: "ACC004", patientID: 1)
        XCTAssertEqual(a, b)

        let c = Accession(accessionNumber: "ACC005", patientID: 1)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Study Tests

    func test_study_defaultValues_areCorrect() {
        let study = Study(studyInstanceUID: "1.2.3.4.5", patientID: 1)

        XCTAssertNil(study.id)
        XCTAssertEqual(study.studyInstanceUID, "1.2.3.4.5")
        XCTAssertNil(study.accessionID)
        XCTAssertEqual(study.patientID, 1)
        XCTAssertNil(study.studyDate)
        XCTAssertNil(study.studyDescription)
        XCTAssertNil(study.modality)
        XCTAssertFalse(study.deleteProtect)
        XCTAssertFalse(study.privacyFlag)
        XCTAssertNil(study.checksumSHA256)
        XCTAssertNil(study.createdAt)
        XCTAssertNil(study.updatedAt)
    }

    func test_study_customValues_arePreserved() {
        let now = Date()
        let study = Study(
            id: 100,
            studyInstanceUID: "1.2.840.113619.2.1",
            accessionID: 10,
            patientID: 5,
            studyDate: now,
            studyDescription: "CT Abdomen",
            modality: "CT",
            deleteProtect: true,
            privacyFlag: true,
            checksumSHA256: "abc123",
            createdAt: now,
            updatedAt: now
        )

        XCTAssertEqual(study.id, 100)
        XCTAssertEqual(study.studyInstanceUID, "1.2.840.113619.2.1")
        XCTAssertEqual(study.accessionID, 10)
        XCTAssertEqual(study.patientID, 5)
        XCTAssertEqual(study.studyDescription, "CT Abdomen")
        XCTAssertEqual(study.modality, "CT")
        XCTAssertTrue(study.deleteProtect)
        XCTAssertTrue(study.privacyFlag)
        XCTAssertEqual(study.checksumSHA256, "abc123")
    }

    func test_study_codable_roundTrips() throws {
        let study = Study(id: 50, studyInstanceUID: "1.2.3", patientID: 3, modality: "MR")

        let data = try JSONEncoder().encode(study)
        let decoded = try JSONDecoder().decode(Study.self, from: data)

        XCTAssertEqual(study, decoded)
    }

    func test_study_equatable() {
        let a = Study(studyInstanceUID: "1.2.3", patientID: 1)
        let b = Study(studyInstanceUID: "1.2.3", patientID: 1)
        XCTAssertEqual(a, b)

        let c = Study(studyInstanceUID: "1.2.4", patientID: 1)
        XCTAssertNotEqual(a, c)
    }
}
