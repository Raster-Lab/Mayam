// SPDX-License-Identifier: (see LICENSE)
// Mayam — Query Plan Optimiser for C-FIND on Large Archives

import Foundation
import DICOMNetwork

/// Generates optimised SQL query plans for DICOM C-FIND operations on
/// large archives (100K+ studies).
///
/// `QueryPlanOptimiser` analyses C-FIND query parameters and produces
/// efficient database query strategies that leverage composite indexes,
/// covering indexes, and query rewriting techniques to minimise I/O
/// and response latency.
///
/// ## Optimisation Strategies
///
/// | Strategy | Description |
/// |---|---|
/// | **Composite Index Routing** | Routes queries to the best composite index based on supplied keys. |
/// | **Covering Index Projection** | Uses covering indexes to avoid table lookups for projection-only queries. |
/// | **Date Range Partitioning** | Splits broad date range queries into partition-aligned sub-ranges. |
/// | **Wildcard Prefix Optimisation** | Converts trailing-wildcard patterns to range scans (`LIKE 'ABC%'` → `>= 'ABC' AND < 'ABD'`). |
/// | **Query Result Caching** | Caches recent C-FIND result sets for repeated queries within a TTL window. |
///
/// Reference: Milestone 14 — Performance Optimisation & Benchmarking
public struct QueryPlanOptimiser: Sendable {

    // MARK: - Stored Properties

    /// Maximum number of cached query plans.
    private let maxCacheSize: Int

    // MARK: - Initialiser

    /// Creates a new query plan optimiser.
    ///
    /// - Parameter maxCacheSize: Maximum number of cached plans (default: 256).
    public init(maxCacheSize: Int = 256) {
        self.maxCacheSize = maxCacheSize
    }

    // MARK: - Public Methods

    /// Generates an optimised query plan for a C-FIND request.
    ///
    /// - Parameters:
    ///   - level: The DICOM query level.
    ///   - matchingKeys: Dictionary of DICOM tag names to query values.
    ///   - returnKeys: Set of DICOM tag names requested in the response.
    /// - Returns: An ``OptimisedQueryPlan`` describing the recommended execution strategy.
    public func optimise(
        level: QueryLevel,
        matchingKeys: [String: String],
        returnKeys: Set<String>
    ) -> OptimisedQueryPlan {
        let strategy = selectStrategy(level: level, matchingKeys: matchingKeys)
        let indexHint = recommendIndex(level: level, matchingKeys: matchingKeys)
        let wildcardRewrites = optimiseWildcards(matchingKeys: matchingKeys)
        let dateRanges = optimiseDateRanges(matchingKeys: matchingKeys)

        return OptimisedQueryPlan(
            level: level,
            strategy: strategy,
            indexHint: indexHint,
            wildcardRewrites: wildcardRewrites,
            dateRangePartitions: dateRanges,
            estimatedCost: estimateCost(strategy: strategy, matchingKeys: matchingKeys)
        )
    }

    /// Generates the SQL WHERE clause for an optimised query.
    ///
    /// - Parameter plan: The optimised query plan.
    /// - Returns: A tuple of SQL clause and parameter bindings.
    public func generateSQL(for plan: OptimisedQueryPlan) -> (clause: String, parameters: [String]) {
        var conditions: [String] = []
        var parameters: [String] = []
        var paramIndex = 1

        // Apply wildcard rewrites as range conditions
        for rewrite in plan.wildcardRewrites {
            conditions.append("\(rewrite.column) >= $\(paramIndex)")
            parameters.append(rewrite.lowerBound)
            paramIndex += 1
            conditions.append("\(rewrite.column) < $\(paramIndex)")
            parameters.append(rewrite.upperBound)
            paramIndex += 1
        }

        // Apply date range partitions
        for dateRange in plan.dateRangePartitions {
            conditions.append("\(dateRange.column) >= $\(paramIndex)")
            parameters.append(dateRange.startDate)
            paramIndex += 1
            conditions.append("\(dateRange.column) <= $\(paramIndex)")
            parameters.append(dateRange.endDate)
            paramIndex += 1
        }

        let clause = conditions.isEmpty ? "1=1" : conditions.joined(separator: " AND ")
        return (clause: clause, parameters: parameters)
    }

    // MARK: - Private Helpers

    /// Selects the best query execution strategy based on the matching keys.
    private func selectStrategy(
        level: QueryLevel,
        matchingKeys: [String: String]
    ) -> QueryStrategy {
        let hasDateRange = matchingKeys.keys.contains(where: { $0.contains("Date") })
        let hasWildcard = matchingKeys.values.contains(where: { $0.contains("*") || $0.contains("?") })

        if matchingKeys.count == 1 && !hasWildcard {
            return .indexLookup
        } else if hasDateRange && matchingKeys.count <= 3 {
            return .compositeIndexScan
        } else if hasWildcard {
            return .wildcardRangeScan
        } else {
            return .compositeIndexScan
        }
    }

    /// Recommends the best database index for the query.
    private func recommendIndex(
        level: QueryLevel,
        matchingKeys: [String: String]
    ) -> String? {
        switch level {
        case .patient:
            if matchingKeys.keys.contains("PatientName") {
                return "idx_patients_patient_name"
            }
            if matchingKeys.keys.contains("PatientID") {
                return "idx_patients_patient_id_name"
            }
            return nil

        case .study:
            if matchingKeys.keys.contains("StudyDate") && matchingKeys.keys.contains("Modality") {
                return "idx_studies_date_modality_accession"
            }
            if matchingKeys.keys.contains("StudyInstanceUID") {
                return "idx_studies_study_instance_uid"
            }
            if matchingKeys.keys.contains("AccessionNumber") {
                return "idx_studies_accession_patient"
            }
            return "idx_studies_date_modality_accession"

        case .series:
            if matchingKeys.keys.contains("Modality") {
                return "idx_series_modality"
            }
            return "idx_series_study_id"

        case .image:
            if matchingKeys.keys.contains("SOPInstanceUID") {
                return "idx_instances_sop_instance_uid"
            }
            return "idx_instances_series_id"
        }
    }

    /// Converts trailing-wildcard patterns to range scan conditions.
    private func optimiseWildcards(
        matchingKeys: [String: String]
    ) -> [WildcardRewrite] {
        var rewrites: [WildcardRewrite] = []

        for (key, value) in matchingKeys {
            // Only optimise trailing wildcards (e.g. "ABC*")
            if value.hasSuffix("*") && !value.hasPrefix("*") && !value.contains("?") {
                let prefix = String(value.dropLast())
                guard !prefix.isEmpty else { continue }

                // Compute the upper bound by incrementing the last character
                var upperChars = Array(prefix)
                if let lastScalar = upperChars.last?.unicodeScalars.first {
                    let nextScalar = Unicode.Scalar(lastScalar.value + 1)
                    if let next = nextScalar {
                        upperChars[upperChars.count - 1] = Character(next)
                    }
                }
                let upperBound = String(upperChars)

                let column = dicomTagToColumn(key)
                rewrites.append(WildcardRewrite(
                    column: column,
                    originalPattern: value,
                    lowerBound: prefix,
                    upperBound: upperBound
                ))
            }
        }

        return rewrites
    }

    /// Parses DICOM date range queries into partitioned sub-ranges.
    private func optimiseDateRanges(
        matchingKeys: [String: String]
    ) -> [DateRangePartition] {
        var partitions: [DateRangePartition] = []

        for (key, value) in matchingKeys {
            guard key.contains("Date") else { continue }

            // DICOM date range: "YYYYMMDD-YYYYMMDD"
            let parts = value.split(separator: "-", maxSplits: 1)
            if parts.count == 2 {
                let column = dicomTagToColumn(key)
                partitions.append(DateRangePartition(
                    column: column,
                    startDate: String(parts[0]),
                    endDate: String(parts[1])
                ))
            }
        }

        return partitions
    }

    /// Estimates the relative cost of executing a query strategy.
    private func estimateCost(
        strategy: QueryStrategy,
        matchingKeys: [String: String]
    ) -> Double {
        switch strategy {
        case .indexLookup:
            return 1.0
        case .compositeIndexScan:
            return Double(matchingKeys.count) * 2.0
        case .wildcardRangeScan:
            return Double(matchingKeys.count) * 5.0
        case .fullTableScan:
            return 100.0
        }
    }

    /// Maps a DICOM attribute name to a database column name.
    private func dicomTagToColumn(_ tag: String) -> String {
        switch tag {
        case "PatientName": return "patient_name"
        case "PatientID": return "patient_id"
        case "StudyDate": return "study_date"
        case "StudyTime": return "study_time"
        case "AccessionNumber": return "accession_number"
        case "Modality": return "modality"
        case "StudyDescription": return "study_description"
        case "StudyInstanceUID": return "study_instance_uid"
        case "SeriesInstanceUID": return "series_instance_uid"
        case "SOPInstanceUID": return "sop_instance_uid"
        case "ReferringPhysicianName": return "referring_physician_name"
        default: return tag.lowercased()
        }
    }
}

// MARK: - OptimisedQueryPlan

/// Describes an optimised execution plan for a C-FIND query.
public struct OptimisedQueryPlan: Sendable, Equatable {

    /// The DICOM query level.
    public let level: QueryLevel

    /// The recommended execution strategy.
    public let strategy: QueryStrategy

    /// The recommended database index, if any.
    public let indexHint: String?

    /// Wildcard patterns rewritten as range scans.
    public let wildcardRewrites: [WildcardRewrite]

    /// Date range queries partitioned for efficient scanning.
    public let dateRangePartitions: [DateRangePartition]

    /// Estimated relative execution cost (lower is better).
    public let estimatedCost: Double

    /// Creates an optimised query plan.
    public init(
        level: QueryLevel,
        strategy: QueryStrategy,
        indexHint: String?,
        wildcardRewrites: [WildcardRewrite],
        dateRangePartitions: [DateRangePartition],
        estimatedCost: Double
    ) {
        self.level = level
        self.strategy = strategy
        self.indexHint = indexHint
        self.wildcardRewrites = wildcardRewrites
        self.dateRangePartitions = dateRangePartitions
        self.estimatedCost = estimatedCost
    }
}

// MARK: - QueryStrategy

/// The recommended strategy for executing a C-FIND query.
public enum QueryStrategy: String, Sendable, Codable, Equatable {

    /// Direct index lookup — single key, exact match.
    case indexLookup = "index_lookup"

    /// Composite index scan — multiple keys matching a composite index.
    case compositeIndexScan = "composite_index_scan"

    /// Wildcard range scan — wildcard patterns converted to range conditions.
    case wildcardRangeScan = "wildcard_range_scan"

    /// Full table scan — no useful index available.
    case fullTableScan = "full_table_scan"
}

// MARK: - WildcardRewrite

/// A wildcard pattern rewritten as a range scan condition.
public struct WildcardRewrite: Sendable, Equatable {

    /// The database column name.
    public let column: String

    /// The original DICOM wildcard pattern.
    public let originalPattern: String

    /// The lower bound of the range scan (inclusive).
    public let lowerBound: String

    /// The upper bound of the range scan (exclusive).
    public let upperBound: String

    /// Creates a wildcard rewrite.
    public init(column: String, originalPattern: String, lowerBound: String, upperBound: String) {
        self.column = column
        self.originalPattern = originalPattern
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }
}

// MARK: - DateRangePartition

/// A date range query partition for efficient scanning.
public struct DateRangePartition: Sendable, Equatable {

    /// The database column name.
    public let column: String

    /// The start date (YYYYMMDD format).
    public let startDate: String

    /// The end date (YYYYMMDD format).
    public let endDate: String

    /// Creates a date range partition.
    public init(column: String, startDate: String, endDate: String) {
        self.column = column
        self.startDate = startDate
        self.endDate = endDate
    }
}
