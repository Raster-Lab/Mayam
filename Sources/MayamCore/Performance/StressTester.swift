// SPDX-License-Identifier: (see LICENSE)
// Mayam — Synthetic DICOM Stress Tester

import Foundation

/// Generates synthetic DICOM datasets and conducts stress testing of
/// the Mayam PACS server under sustained concurrent load.
///
/// `StressTester` creates realistic-looking DICOM study/series/instance
/// hierarchies with configurable parameters (number of patients, studies
/// per patient, series per study, instances per series, image dimensions)
/// and measures server throughput, latency, and error rates under load.
///
/// ## Test Scenarios
///
/// | Scenario | Description |
/// |---|---|
/// | **Sequential Ingest** | Single-threaded C-STORE of N instances. |
/// | **Concurrent Ingest** | M concurrent associations each storing N instances. |
/// | **Query Under Load** | C-FIND queries while concurrent C-STORE is active. |
/// | **Retrieve Burst** | Burst C-MOVE/C-GET of entire studies. |
/// | **Mixed Workload** | Simultaneous ingest, query, and retrieve operations. |
///
/// ## Usage
///
/// ```swift
/// let config = StressTestConfiguration(
///     patientCount: 100,
///     studiesPerPatient: 3,
///     seriesPerStudy: 5,
///     instancesPerSeries: 50,
///     concurrentAssociations: 8,
///     imageSize: .ct512
/// )
/// let tester = StressTester(configuration: config)
/// let result = await tester.runIngestBenchmark()
/// print(result.formattedSummary)
/// ```
///
/// Reference: Milestone 14 — Performance Optimisation & Benchmarking
public struct StressTester: Sendable {

    // MARK: - Stored Properties

    /// The stress test configuration.
    public let configuration: StressTestConfiguration

    // MARK: - Initialiser

    /// Creates a new stress tester.
    ///
    /// - Parameter configuration: The test configuration.
    public init(configuration: StressTestConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Synthetic Data Generation

    /// Generates a batch of synthetic DICOM instance metadata for stress testing.
    ///
    /// Each instance includes realistic DICOM UIDs, patient demographics, and
    /// study/series metadata suitable for exercising C-STORE, C-FIND, and
    /// C-MOVE code paths.
    ///
    /// - Returns: An array of ``SyntheticInstance`` descriptors.
    public func generateSyntheticDataset() -> [SyntheticInstance] {
        var instances: [SyntheticInstance] = []
        let baseUID = "1.2.826.0.1.3680043.9.7433"
        var instanceCounter = 0

        for patientIndex in 0..<configuration.patientCount {
            let patientID = String(format: "STRESS-PAT-%06d", patientIndex)
            let patientName = "StressTest^Patient\(patientIndex)"

            for studyIndex in 0..<configuration.studiesPerPatient {
                let studyUID = "\(baseUID).1.\(patientIndex).\(studyIndex)"
                let accessionNumber = String(format: "ACC%08d", patientIndex * 1000 + studyIndex)
                let studyDate = generateStudyDate(offsetDays: patientIndex * 30 + studyIndex)

                for seriesIndex in 0..<configuration.seriesPerStudy {
                    let seriesUID = "\(studyUID).\(seriesIndex)"
                    let modality = configuration.modalities[seriesIndex % configuration.modalities.count]

                    for instanceIndex in 0..<configuration.instancesPerSeries {
                        let sopInstanceUID = "\(seriesUID).\(instanceIndex)"
                        instanceCounter += 1

                        instances.append(SyntheticInstance(
                            sopInstanceUID: sopInstanceUID,
                            sopClassUID: sopClassUIDForModality(modality),
                            studyInstanceUID: studyUID,
                            seriesInstanceUID: seriesUID,
                            patientID: patientID,
                            patientName: patientName,
                            accessionNumber: accessionNumber,
                            modality: modality,
                            studyDate: studyDate,
                            instanceNumber: instanceIndex + 1,
                            seriesNumber: seriesIndex + 1
                        ))
                    }
                }
            }
        }

        return instances
    }

    /// Generates synthetic pixel data for a single instance.
    ///
    /// - Returns: Raw pixel data bytes.
    public func generateInstanceData() -> Data {
        let benchmark = CodecBenchmark()
        return benchmark.generateSyntheticPixelData(imageSize: configuration.imageSize)
    }

    /// Returns a summary of the dataset that will be generated.
    ///
    /// - Returns: A ``DatasetSummary`` describing the synthetic dataset.
    public func datasetSummary() -> DatasetSummary {
        let totalInstances = configuration.patientCount
            * configuration.studiesPerPatient
            * configuration.seriesPerStudy
            * configuration.instancesPerSeries
        let bytesPerInstance = configuration.imageSize.width
            * configuration.imageSize.height
            * (configuration.imageSize.bitsAllocated / 8)
        let totalBytes = Int64(totalInstances) * Int64(bytesPerInstance)

        return DatasetSummary(
            patientCount: configuration.patientCount,
            totalStudies: configuration.patientCount * configuration.studiesPerPatient,
            totalSeries: configuration.patientCount * configuration.studiesPerPatient * configuration.seriesPerStudy,
            totalInstances: totalInstances,
            bytesPerInstance: bytesPerInstance,
            totalBytes: totalBytes,
            concurrentAssociations: configuration.concurrentAssociations
        )
    }

    // MARK: - Private Helpers

    /// Generates a study date offset from a base date.
    private func generateStudyDate(offsetDays: Int) -> String {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let date = calendar.date(byAdding: .day, value: offsetDays, to: baseDate)!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    /// Returns the SOP Class UID for a given modality.
    private func sopClassUIDForModality(_ modality: String) -> String {
        switch modality {
        case "CT": return "1.2.840.10008.5.1.4.1.1.2"       // CT Image Storage
        case "MR": return "1.2.840.10008.5.1.4.1.1.4"       // MR Image Storage
        case "CR": return "1.2.840.10008.5.1.4.1.1.1"       // CR Image Storage
        case "DX": return "1.2.840.10008.5.1.4.1.1.1.1"     // DX Image Storage
        case "US": return "1.2.840.10008.5.1.4.1.1.6.1"     // US Image Storage
        case "XA": return "1.2.840.10008.5.1.4.1.1.12.1"    // XA Image Storage
        case "MG": return "1.2.840.10008.5.1.4.1.1.1.2"     // MG Image Storage
        default:   return "1.2.840.10008.5.1.4.1.1.7"       // Secondary Capture
        }
    }
}

// MARK: - StressTestConfiguration

/// Configuration for a stress test run.
public struct StressTestConfiguration: Sendable {

    /// Number of synthetic patients.
    public let patientCount: Int

    /// Studies per patient.
    public let studiesPerPatient: Int

    /// Series per study.
    public let seriesPerStudy: Int

    /// Instances per series.
    public let instancesPerSeries: Int

    /// Number of concurrent DICOM associations.
    public let concurrentAssociations: Int

    /// Image dimensions for synthetic pixel data.
    public let imageSize: BenchmarkImageSize

    /// Modalities to cycle through.
    public let modalities: [String]

    /// Creates a stress test configuration.
    ///
    /// - Parameters:
    ///   - patientCount: Number of patients (default: 100).
    ///   - studiesPerPatient: Studies per patient (default: 2).
    ///   - seriesPerStudy: Series per study (default: 3).
    ///   - instancesPerSeries: Instances per series (default: 50).
    ///   - concurrentAssociations: Concurrent associations (default: 8).
    ///   - imageSize: Image dimensions (default: CT 512×512).
    ///   - modalities: Modality cycle (default: CT, MR, CR, DX).
    public init(
        patientCount: Int = 100,
        studiesPerPatient: Int = 2,
        seriesPerStudy: Int = 3,
        instancesPerSeries: Int = 50,
        concurrentAssociations: Int = 8,
        imageSize: BenchmarkImageSize = .ct512,
        modalities: [String] = ["CT", "MR", "CR", "DX"]
    ) {
        self.patientCount = patientCount
        self.studiesPerPatient = studiesPerPatient
        self.seriesPerStudy = seriesPerStudy
        self.instancesPerSeries = instancesPerSeries
        self.concurrentAssociations = concurrentAssociations
        self.imageSize = imageSize
        self.modalities = modalities
    }
}

// MARK: - SyntheticInstance

/// Describes a single synthetic DICOM instance for stress testing.
public struct SyntheticInstance: Sendable {

    /// SOP Instance UID.
    public let sopInstanceUID: String

    /// SOP Class UID.
    public let sopClassUID: String

    /// Study Instance UID.
    public let studyInstanceUID: String

    /// Series Instance UID.
    public let seriesInstanceUID: String

    /// Patient ID.
    public let patientID: String

    /// Patient Name.
    public let patientName: String

    /// Accession Number.
    public let accessionNumber: String

    /// Modality (CT, MR, CR, etc.).
    public let modality: String

    /// Study Date (YYYYMMDD format).
    public let studyDate: String

    /// Instance Number within the series.
    public let instanceNumber: Int

    /// Series Number within the study.
    public let seriesNumber: Int

    /// Creates a synthetic instance.
    public init(
        sopInstanceUID: String,
        sopClassUID: String,
        studyInstanceUID: String,
        seriesInstanceUID: String,
        patientID: String,
        patientName: String,
        accessionNumber: String,
        modality: String,
        studyDate: String,
        instanceNumber: Int,
        seriesNumber: Int
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.sopClassUID = sopClassUID
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
        self.patientID = patientID
        self.patientName = patientName
        self.accessionNumber = accessionNumber
        self.modality = modality
        self.studyDate = studyDate
        self.instanceNumber = instanceNumber
        self.seriesNumber = seriesNumber
    }
}

// MARK: - DatasetSummary

/// Summary of a synthetic dataset to be generated.
public struct DatasetSummary: Sendable, Equatable {

    /// Number of patients.
    public let patientCount: Int

    /// Total number of studies.
    public let totalStudies: Int

    /// Total number of series.
    public let totalSeries: Int

    /// Total number of instances.
    public let totalInstances: Int

    /// Bytes per instance (uncompressed pixel data).
    public let bytesPerInstance: Int

    /// Total bytes across all instances.
    public let totalBytes: Int64

    /// Concurrent association count.
    public let concurrentAssociations: Int

    /// Formatted summary string.
    public var formattedSummary: String {
        let totalGB = Double(totalBytes) / 1_073_741_824
        return """
        Synthetic Dataset Summary:
          Patients:     \(patientCount)
          Studies:      \(totalStudies)
          Series:       \(totalSeries)
          Instances:    \(totalInstances)
          Per Instance: \(bytesPerInstance) bytes
          Total Data:   \(String(format: "%.2f", totalGB)) GB
          Associations: \(concurrentAssociations) concurrent
        """
    }

    /// Creates a dataset summary.
    public init(
        patientCount: Int,
        totalStudies: Int,
        totalSeries: Int,
        totalInstances: Int,
        bytesPerInstance: Int,
        totalBytes: Int64,
        concurrentAssociations: Int
    ) {
        self.patientCount = patientCount
        self.totalStudies = totalStudies
        self.totalSeries = totalSeries
        self.totalInstances = totalInstances
        self.bytesPerInstance = bytesPerInstance
        self.totalBytes = totalBytes
        self.concurrentAssociations = concurrentAssociations
    }
}
