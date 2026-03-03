# Mayam — Performance Benchmarks

This directory contains reproducible benchmark scripts and baseline results for Mayam's performance optimisation suite.

## Overview

Mayam targets the following performance goals (Milestone 14):

| Metric | Target | Measurement |
|---|---|---|
| **C-STORE Throughput** | Saturate 10 Gbps on Apple Silicon | Concurrent C-STORE with synthetic datasets |
| **C-FIND Latency** | < 100 ms for 100K+ study archives | Query plan optimisation with composite indexes |
| **Codec Throughput** | Maximum encode/decode throughput | Per-codec benchmarking (J2KSwift, JLSwift, JXLSwift) |
| **HSM Recall Latency** | < 50 ms for cached recalls | Prefetch cache with LRU eviction |

## Running Benchmarks

### Full Benchmark Suite

```bash
# Run all benchmarks with full iteration counts
./Benchmarks/run_benchmarks.sh

# Run in quick mode for CI validation
./Benchmarks/run_benchmarks.sh --quick
```

### Individual Benchmark Components

```bash
# Run only performance tests
swift test --filter "PerformanceTests"

# Run codec benchmarks specifically
swift test --filter "test_codecBenchmark"

# Run stress test benchmarks
swift test --filter "test_stressTester"
```

### Release Mode Benchmarks

For accurate throughput measurements, always build and test in release mode:

```bash
swift build -c release
swift test -c release --filter "PerformanceTests"
```

## Benchmark Components

### 1. Buffer Pool (`BufferPool`)

Measures the overhead of byte buffer allocation vs. pooled reuse in the DICOM association pipeline.

- **Metric:** Pool hit rate, allocation count, acquire/release throughput.
- **Goal:** > 90% hit rate under sustained C-STORE traffic.

### 2. Concurrent Store Optimiser (`ConcurrentStoreOptimiser`)

Measures file write throughput with coalesced writes and backpressure management.

- **Metric:** Bytes/second, write operations/second, in-flight byte tracking.
- **Goal:** Saturate NVMe bandwidth with concurrent associations.

### 3. Query Plan Optimiser (`QueryPlanOptimiser`)

Validates query plan generation for common C-FIND patterns on large archives.

- **Metric:** Query execution strategy selection, index utilisation.
- **Goal:** Composite index routing for all common query patterns.

### 4. Codec Benchmarks (`CodecBenchmark`)

Measures encode/decode throughput for all supported DICOM image codecs.

- **Metric:** Megapixels/second, bytes/second, compression ratio.
- **Codecs:** JPEG 2000, HTJ2K, JPEG-LS, JPEG XL, RLE.
- **Image Sizes:** 256×256 (MR), 512×512 (CT/CR), 2048×2048 (DX), 4096×4096 (MG).

### 5. Recall Prefetch Cache (`RecallPrefetchCache`)

Measures cache performance for HSM near-line study recalls.

- **Metric:** Hit rate, eviction count, prefetch effectiveness.
- **Goal:** > 80% hit rate for sequential patient access patterns.

### 6. Stress Tester (`StressTester`)

Generates synthetic DICOM datasets and measures end-to-end performance.

- **Configuration:** Patient count, studies/patient, series/study, instances/series.
- **Scenarios:** Sequential ingest, concurrent ingest, query under load, mixed workload.

## Results

Benchmark results are saved to `Benchmarks/results/` with timestamped filenames.

### Baseline Results

Baseline measurements are taken on the following reference hardware:

- **macOS:** Apple M2 Pro, 16 GB RAM, 1 TB NVMe SSD
- **Linux:** AWS c7g.xlarge (Graviton3), 8 GB RAM, gp3 EBS

Results should be compared against these baselines when evaluating performance regressions.

## Database Performance Indexes

Migration `008_add_performance_indexes.sql` adds the following indexes optimised for C-FIND on large archives:

| Index | Purpose |
|---|---|
| `idx_studies_date_modality_accession` | Most common C-FIND pattern (date + modality + accession) |
| `idx_studies_accession_patient` | RIS-driven accession lookups |
| `idx_patients_patient_id_name` | Combined Patient ID + Name queries |
| `idx_studies_patient_date` | Patient history timeline queries |
| `idx_series_study_modality` | Series-level drill-down |
| `idx_instances_series_number` | Ordered instance retrieval |
| `idx_patients_covering_list` | Covering index for patient list (avoids table lookup) |
| `idx_studies_covering_list` | Covering index for study list (avoids table lookup) |
| `idx_studies_recent` | Partial index for recent studies (last 90 days) |
| `idx_patients_name_trgm` | Trigram index for wildcard patient name search |
| `idx_studies_description_trgm` | Trigram index for wildcard study description search |
