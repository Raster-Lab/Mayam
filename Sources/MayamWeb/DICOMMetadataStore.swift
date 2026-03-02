// SPDX-License-Identifier: (see LICENSE)
// Mayam — DICOMweb Metadata Store Protocol

import Foundation
import MayamCore

// MARK: - Search Result Types

/// A study search result containing the study, its patient, and aggregate counts.
public struct StudySearchResult: Sendable {
    /// The study record.
    public let study: Study
    /// The owning patient record.
    public let patient: Patient
    /// Number of series in this study.
    public let numberOfSeries: Int
    /// Number of instances across all series in this study.
    public let numberOfInstances: Int

    public init(study: Study, patient: Patient, numberOfSeries: Int, numberOfInstances: Int) {
        self.study = study
        self.patient = patient
        self.numberOfSeries = numberOfSeries
        self.numberOfInstances = numberOfInstances
    }
}

/// A series search result containing the series, study, and instance count.
public struct SeriesSearchResult: Sendable {
    /// The series record.
    public let series: Series
    /// The owning study record.
    public let study: Study
    /// Number of instances in this series.
    public let numberOfInstances: Int

    public init(series: Series, study: Study, numberOfInstances: Int) {
        self.series = series
        self.study = study
        self.numberOfInstances = numberOfInstances
    }
}

/// An instance search result containing the instance, series, and study.
public struct InstanceSearchResult: Sendable {
    /// The SOP instance record.
    public let instance: Instance
    /// The owning series record.
    public let series: Series
    /// The owning study record.
    public let study: Study

    public init(instance: Instance, series: Series, study: Study) {
        self.instance = instance
        self.series = series
        self.study = study
    }
}

// MARK: - DICOMMetadataStore Protocol

/// A protocol representing an asynchronous store of DICOM metadata.
///
/// `DICOMMetadataStore` is the abstraction layer between the DICOMweb handlers
/// and the underlying storage backend (PostgreSQL, SQLite, or the in-memory
/// index used during development).
///
/// All operations are `async` to support database I/O without blocking.
public protocol DICOMMetadataStore: Sendable {

    // MARK: - Study Operations

    /// Searches for studies matching the given query.
    ///
    /// - Parameter query: The parsed QIDO-RS study query parameters.
    /// - Returns: An array of matching ``StudySearchResult`` values.
    func searchStudies(query: StudyQuery) async -> [StudySearchResult]

    /// Retrieves a study by its UID.
    ///
    /// - Parameter studyUID: The Study Instance UID (0020,000D).
    /// - Returns: The ``StudySearchResult`` if found, otherwise `nil`.
    func findStudy(uid: String) async -> StudySearchResult?

    // MARK: - Series Operations

    /// Searches for series within a specific study.
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID to constrain the search.
    ///   - query: Additional query parameters.
    /// - Returns: An array of matching ``SeriesSearchResult`` values.
    func searchSeries(studyUID: String, query: [String: String]) async -> [SeriesSearchResult]

    /// Retrieves a series by its UID within the context of a study.
    ///
    /// - Parameters:
    ///   - seriesUID: The Series Instance UID (0020,000E).
    ///   - studyUID: The owning study UID.
    /// - Returns: The ``SeriesSearchResult`` if found, otherwise `nil`.
    func findSeries(uid: String, inStudy studyUID: String) async -> SeriesSearchResult?

    // MARK: - Instance Operations

    /// Searches for instances within a specific series.
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID.
    ///   - seriesUID: The Series Instance UID.
    ///   - query: Additional query parameters.
    /// - Returns: An array of matching ``InstanceSearchResult`` values.
    func searchInstances(
        studyUID: String,
        seriesUID: String,
        query: [String: String]
    ) async -> [InstanceSearchResult]

    /// Retrieves all instances for a study, grouped by series.
    ///
    /// - Parameter studyUID: The Study Instance UID.
    /// - Returns: An array of ``InstanceSearchResult`` values.
    func allInstances(inStudy studyUID: String) async -> [InstanceSearchResult]

    /// Retrieves all instances for a series.
    ///
    /// - Parameters:
    ///   - seriesUID: The Series Instance UID.
    ///   - studyUID: The owning study UID.
    /// - Returns: An array of ``InstanceSearchResult`` values.
    func allInstances(inSeries seriesUID: String, study studyUID: String) async -> [InstanceSearchResult]

    /// Finds a specific instance by its SOP Instance UID.
    ///
    /// - Parameter sopInstanceUID: The SOP Instance UID (0008,0018).
    /// - Returns: The ``InstanceSearchResult`` if found, otherwise `nil`.
    func findInstance(sopInstanceUID: String) async -> InstanceSearchResult?

    // MARK: - Storage

    /// Stores a new DICOM instance into the metadata index.
    ///
    /// This is called by STOW-RS after successfully writing the object to disk.
    ///
    /// - Parameters:
    ///   - instance: The instance record to store.
    ///   - series: The series record (will be created or updated).
    ///   - study: The study record (will be created or updated).
    ///   - patient: The patient record (will be created or updated).
    func storeInstance(
        instance: Instance,
        series: Series,
        study: Study,
        patient: Patient
    ) async throws
}

// MARK: - InMemoryDICOMMetadataStore

/// An in-memory implementation of ``DICOMMetadataStore``.
///
/// Used for development, testing, and lightweight single-node deployments
/// where the full PostgreSQL database is not available.
///
/// > Important: This implementation does not persist metadata across restarts.
///   Use the PostgreSQL-backed store in production deployments.
public actor InMemoryDICOMMetadataStore: DICOMMetadataStore {

    // MARK: - Stored Properties

    private var patients: [String: Patient] = [:]          // keyed by patientID string
    private var studies: [String: Study] = [:]              // keyed by studyInstanceUID
    private var series: [String: Series] = [:]              // keyed by seriesInstanceUID
    private var instances: [String: Instance] = [:]         // keyed by sopInstanceUID

    // MARK: - Initialiser

    /// Creates a new empty in-memory metadata store.
    public init() {}

    // MARK: - Study Operations

    public func searchStudies(query: StudyQuery) async -> [StudySearchResult] {
        var results: [StudySearchResult] = []

        for study in studies.values {
            // Filter by StudyInstanceUID
            if let uid = query.studyInstanceUID, uid != study.studyInstanceUID { continue }

            // Find the patient
            guard let patient = patients.values.first(where: { $0.id == study.patientID }) else {
                continue
            }

            // Filter by PatientID
            if let pid = query.patientID, pid != patient.patientID { continue }

            // Filter by PatientName (case-insensitive, wildcard suffix)
            if let pname = query.patientName, !pname.isEmpty {
                let name = patient.patientName ?? ""
                if pname.hasSuffix("*") {
                    let prefix = String(pname.dropLast())
                    if !name.lowercased().hasPrefix(prefix.lowercased()) { continue }
                } else {
                    if !name.lowercased().contains(pname.lowercased()) { continue }
                }
            }

            // Filter by Modality
            if let mod = query.modality, let sm = study.modality, mod != sm { continue }

            let studySeries = series.values.filter { $0.studyID == study.id }
            let instanceCount = studySeries.reduce(0) { $0 + $1.instanceCount }

            results.append(StudySearchResult(
                study: study,
                patient: patient,
                numberOfSeries: studySeries.count,
                numberOfInstances: instanceCount
            ))
        }

        // Apply pagination
        let sorted = results.sorted { ($0.study.studyDate ?? Date.distantPast) > ($1.study.studyDate ?? Date.distantPast) }
        let startIndex = min(query.offset, sorted.count)
        let endIndex = min(startIndex + query.limit, sorted.count)
        return Array(sorted[startIndex..<endIndex])
    }

    public func findStudy(uid: String) async -> StudySearchResult? {
        guard let study = studies[uid] else { return nil }
        guard let patient = patients.values.first(where: { $0.id == study.patientID }) else {
            return nil
        }
        let studySeries = series.values.filter { $0.studyID == study.id }
        let instanceCount = studySeries.reduce(0) { $0 + $1.instanceCount }
        return StudySearchResult(
            study: study,
            patient: patient,
            numberOfSeries: studySeries.count,
            numberOfInstances: instanceCount
        )
    }

    // MARK: - Series Operations

    public func searchSeries(studyUID: String, query: [String: String]) async -> [SeriesSearchResult] {
        guard let study = studies[studyUID] else { return [] }

        var results: [SeriesSearchResult] = []
        for s in series.values where s.studyID == study.id {
            // Filter by SeriesInstanceUID
            if let suid = query["SeriesInstanceUID"] ?? query["0020000E"],
               suid != s.seriesInstanceUID { continue }

            // Filter by Modality
            if let mod = query["Modality"] ?? query["00080060"],
               let sm = s.modality, mod != sm { continue }

            results.append(SeriesSearchResult(
                series: s,
                study: study,
                numberOfInstances: s.instanceCount
            ))
        }

        let sorted = results.sorted { ($0.series.seriesNumber ?? 0) < ($1.series.seriesNumber ?? 0) }
        let limit = min(Int(query["limit"] ?? "100") ?? 100, 1000)
        let offset = Int(query["offset"] ?? "0") ?? 0
        let startIndex = min(offset, sorted.count)
        let endIndex = min(startIndex + limit, sorted.count)
        return Array(sorted[startIndex..<endIndex])
    }

    public func findSeries(uid: String, inStudy studyUID: String) async -> SeriesSearchResult? {
        guard let s = series[uid], let study = studies[studyUID] else { return nil }
        guard s.studyID == study.id else { return nil }
        return SeriesSearchResult(series: s, study: study, numberOfInstances: s.instanceCount)
    }

    // MARK: - Instance Operations

    public func searchInstances(
        studyUID: String,
        seriesUID: String,
        query: [String: String]
    ) async -> [InstanceSearchResult] {
        guard let study = studies[studyUID],
              let s = series[seriesUID],
              s.studyID == study.id else { return [] }

        var results: [InstanceSearchResult] = []
        for inst in instances.values where inst.seriesID == s.id {
            if let sopUID = query["SOPInstanceUID"] ?? query["00080018"],
               sopUID != inst.sopInstanceUID { continue }
            results.append(InstanceSearchResult(instance: inst, series: s, study: study))
        }

        let sorted = results.sorted { ($0.instance.instanceNumber ?? 0) < ($1.instance.instanceNumber ?? 0) }
        let limit = min(Int(query["limit"] ?? "100") ?? 100, 1000)
        let offset = Int(query["offset"] ?? "0") ?? 0
        let startIndex = min(offset, sorted.count)
        let endIndex = min(startIndex + limit, sorted.count)
        return Array(sorted[startIndex..<endIndex])
    }

    public func allInstances(inStudy studyUID: String) async -> [InstanceSearchResult] {
        guard let study = studies[studyUID] else { return [] }
        var results: [InstanceSearchResult] = []
        for s in series.values where s.studyID == study.id {
            for inst in instances.values where inst.seriesID == s.id {
                results.append(InstanceSearchResult(instance: inst, series: s, study: study))
            }
        }
        return results.sorted { ($0.instance.instanceNumber ?? 0) < ($1.instance.instanceNumber ?? 0) }
    }

    public func allInstances(inSeries seriesUID: String, study studyUID: String) async -> [InstanceSearchResult] {
        guard let study = studies[studyUID],
              let s = series[seriesUID],
              s.studyID == study.id else { return [] }
        return instances.values
            .filter { $0.seriesID == s.id }
            .map { InstanceSearchResult(instance: $0, series: s, study: study) }
            .sorted { ($0.instance.instanceNumber ?? 0) < ($1.instance.instanceNumber ?? 0) }
    }

    public func findInstance(sopInstanceUID: String) async -> InstanceSearchResult? {
        guard let inst = instances[sopInstanceUID] else { return nil }
        guard let s = series.values.first(where: { $0.id == inst.seriesID }) else { return nil }
        guard let study = studies.values.first(where: { $0.id == s.studyID }) else { return nil }
        return InstanceSearchResult(instance: inst, series: s, study: study)
    }

    // MARK: - Storage

    public func storeInstance(
        instance: Instance,
        series newSeries: Series,
        study newStudy: Study,
        patient newPatient: Patient
    ) async throws {
        // Upsert patient
        patients[newPatient.patientID] = newPatient

        // Upsert study
        studies[newStudy.studyInstanceUID] = newStudy

        // Upsert series — update instance count
        if let existing = series[newSeries.seriesInstanceUID] {
            if instances[instance.sopInstanceUID] == nil {
                // New instance: increment count
                let updated = Series(
                    id: existing.id,
                    seriesInstanceUID: existing.seriesInstanceUID,
                    studyID: existing.studyID,
                    seriesNumber: existing.seriesNumber,
                    modality: existing.modality,
                    seriesDescription: existing.seriesDescription,
                    instanceCount: existing.instanceCount + 1,
                    createdAt: existing.createdAt,
                    updatedAt: Date()
                )
                series[newSeries.seriesInstanceUID] = updated
            }
        } else {
            series[newSeries.seriesInstanceUID] = newSeries
        }

        // Upsert instance
        instances[instance.sopInstanceUID] = instance
    }
}
