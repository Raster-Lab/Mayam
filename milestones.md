# Mayam Server — Development Milestones

This document defines the phased roadmap for Mayam Server. Each milestone is a self-contained deliverable that can be tested and validated independently before moving to the next phase.

> **Standard:** DICOM 2026a (XML edition)
> **Language:** Swift 6.2 with strict concurrency
> **Platforms:** macOS (Apple Silicon primary) · Linux (x86_64, aarch64)

---

## Milestone 1 — Project Bootstrap & Core Infrastructure

**Goal:** Establish the Swift Package Manager project skeleton, CI pipeline, and foundational abstractions.

- Set up the Swift Package Manager workspace with module targets (`MayamServer`, `MayamCore`, `MayamWeb`, `MayamAdmin`, `MayamCLI`).
- Integrate [DICOMKit](https://github.com/Raster-Lab/DICOMKit) as a package dependency.
- Define the actor-based concurrency architecture (server actor, association actors, storage actors).
- Implement a YAML-based configuration loader with environment variable overrides.
- Create the logging subsystem (Apple `os_log` on macOS, `swift-log` on Linux).
- Set up GitHub Actions CI for macOS and Linux (build, test, lint).
- Add unit test targets and establish code-coverage baseline.
- Write developer documentation: build instructions, architecture overview.

---

## Milestone 2 — DICOM Association & Verification Service

**Goal:** Accept inbound DICOM TCP connections and support the C-ECHO service.

- Implement the DICOM Upper Layer Protocol (association negotiation, A-ASSOCIATE, A-RELEASE, A-ABORT) using Swift NIO.
- Build the Service Class Provider (SCP) dispatcher that routes incoming DIMSE commands to service handlers.
- Implement **C-ECHO SCP** — the simplest verification service, to prove end-to-end association handling.
- Implement **C-ECHO SCU** — outbound verification for testing connectivity to remote nodes.
- Support configurable AE Title, port, and accepted presentation contexts.
- Add TLS 1.3 support for secure DICOM associations (DICOM PS3.15).
- Write integration tests using DICOMKit's SCU tools.

---

## Milestone 3 — Storage Service (C-STORE SCP/SCU)

**Goal:** Receive, validate, and persistently archive DICOM objects with intelligent compression handling.

- Implement **C-STORE SCP** — receive DICOM objects from modalities and workstations.
- Design the on-disk storage layout (configurable directory hierarchy by Patient/Study/Series).
- Implement the metadata index database (SQLite for single-node; abstraction layer for future PostgreSQL).
- Store received objects with SHA-256 integrity checksums.
- **Store-As-Received** — preserve the original transfer syntax of incoming objects; do not decompress compressed data on ingest.
- Support core Transfer Syntaxes: Implicit VR Little Endian, Explicit VR Little/Big Endian, Deflated Explicit VR, RLE.
- Implement **C-STORE SCU** — send/forward DICOM objects to remote DICOM nodes.
- **Serve-As-Stored** — when a requesting client accepts the stored transfer syntax, serve the original compressed data directly without transcoding; decompress or transcode only when the client does not support the stored format.
- Implement **Study-Level Archive Packaging** — ZIP (and optionally TAR+Zstd) packaging of complete studies for efficient backup, near-line storage, and bulk transfer.
- Define and implement the **Storage Policy Matrix** — configurable rules governing data handling at each lifecycle stage:
  - **Ingest** — store-as-received; optional compressed-copy creation; duplicate detection; integrity checksum; per-modality codec selection.
  - **Online** — serve-as-stored; on-demand transcoding for unsupported clients; QoS priority for STAT studies.
  - **Near-Line** — policy-driven migration triggers (age, last-access, modality, study status); archive packaging format (ZIP / TAR+Zstd); retention rules.
  - **Offline** — cold object-storage / tape tier; minimum retention periods; deletion protection for legal-hold studies.
  - **Rehydrate** — on-demand recall to online tier; prefetch hints from query patterns; automatic cache eviction after configurable TTL.
- Add duplicate SOP Instance detection and configurable duplicate policies (reject, overwrite, keep both).
- Write storage performance benchmarks targeting Apple Silicon (M-series).

---

## Milestone 4 — Image Codec Integration

**Goal:** Integrate Raster-Lab compression frameworks for full transfer syntax support with smart storage management.

- Integrate [J2KSwift](https://github.com/Raster-Lab/J2KSwift) — JPEG 2000 lossless/lossy encoding and decoding.
- Integrate [JLSwift](https://github.com/Raster-Lab/JLSwift) — JPEG-LS lossless/near-lossless encoding and decoding.
- Integrate [JXLSwift](https://github.com/Raster-Lab/JXLSwift) — JPEG XL encoding and decoding.
- Integrate [OpenJP3D](https://github.com/Raster-Lab/OpenJP3D) — JP3D volumetric compression for 3D datasets.
- Implement **Compressed Copy on Receipt** — optional server-side policy to create an additional compressed copy (e.g., JPEG 2000, JPEG-LS) of each study at ingest time; supports tele-radiology and bandwidth-constrained retrieval scenarios.
- Implement **Unified Object Presentation** — original and compressed copies of the same study are presented as a single logical item to end users; the PACS automatically selects whichever representation is most appropriate for the requesting client. This should be seamless and transparent.
- Define and implement the **Representation Model** — manage multiple derivative representations per study:
  - **Per Modality** — default archive codec per modality type (e.g., JPEG-LS lossless for CR/DX, JPEG 2000 for CT/MR, uncompressed for US); configurable per-modality ingest and compressed-copy policies.
  - **Per Site** — site-level storage profiles defining which representations to create and retain (e.g., main site keeps originals + lossless, satellite site keeps lossy only).
  - **Per Tele-Radiology Destination** — destination-specific compressed copies pre-built at ingest or on first request; codec, quality, and resolution rules per remote reading site; bandwidth-aware selection.
  - **Derivative Limit** — configurable maximum number of representations per study; oldest/least-used derivatives pruned by policy.
- Implement on-demand transcoding — transcode only when a client requests a transfer syntax that differs from the stored format.
- Implement background batch transcoding for existing archive data.
- Add transfer syntax negotiation in association handling for all supported codecs.
- Benchmark codec performance on Apple Silicon vs. Linux (NEON/SIMD paths).

---

## Milestone 5 — Query/Retrieve Services (C-FIND, C-MOVE, C-GET)

**Goal:** Enable querying the archive and retrieving studies.

- Implement **C-FIND SCP** at Patient, Study, Series, and Image (Instance) query levels.
- Support standard DICOM query attributes, wildcards, date ranges, and modality filtering.
- Implement **C-MOVE SCP** — retrieve studies and route them to a specified destination AE.
- Implement **C-GET SCP** — pull-based retrieval within the same association.
- Implement **C-FIND SCU**, **C-MOVE SCU**, **C-GET SCU** — for federated queries and upstream retrieval.
- Optimise query performance with database indexing strategies.
- Support query result pagination for large result sets.
- Write conformance tests against DICOM query/retrieve test suites.

---

## Milestone 6 — DICOMweb Services

**Goal:** Provide a complete RESTful DICOMweb interface.

- Implement **WADO-RS** — retrieve DICOM objects, metadata, rendered frames, and bulk data via REST.
- Implement **QIDO-RS** — RESTful query for studies, series, and instances.
- Implement **STOW-RS** — store DICOM objects via multipart HTTP POST.
- Implement **UPS-RS** — Unified Procedure Step management via REST.
- Implement **WADO-URI** — legacy single-frame retrieval for backward compatibility.
- Serve all DICOMweb endpoints over HTTPS with configurable TLS certificates.
- Add JSON and XML multipart DICOM response formats.
- Write DICOMweb conformance tests; validate with DICOMKit's DICOMweb client.

---

## Milestone 7 — Web Administration Console

**Goal:** Deliver a responsive web-based administration interface.

- Design and implement the **RESTful Admin API** as a separate, documented endpoint group.
- Implement authentication and session management for the admin API (JWT tokens backed by LDAP).
- Build the **Web Console** frontend:
  - Dashboard — server status, storage utilisation, association metrics, recent activity.
  - DICOM Node Manager — add, edit, delete, and verify (C-ECHO) remote AE Titles.
  - Storage Manager — view storage pools, utilisation, near-line status, and run integrity checks.
  - Log Viewer — filterable, searchable audit and application logs.
  - Transfer Syntax / Compression Policy editor.
  - System Settings — AE Title, ports, TLS certificates, LDAP connection, backup schedules.
- Ensure full mobile/tablet responsiveness.
- Ensure every admin action is available via the REST API (for future native App/GUI tools).
- Add first-run **Setup Wizard** for guided initial configuration.

---

## Milestone 8 — User Management & LDAP Integration

**Goal:** Implement user authentication, authorisation, and DICOM LDAP configuration.

- Implement LDAP client for user authentication (bind) and directory queries.
- Support Active Directory and standard OpenLDAP schemas.
- Implement the **DICOM LDAP Configuration** schema (DICOM PS3.15 Annex H) for AE Title and network configuration storage.
- Implement **Role-Based Access Control (RBAC)** with predefined roles:
  - Administrator — full system access.
  - Technologist — node management, study routing, limited settings.
  - Physician — query/retrieve, DICOMweb access, read-only admin.
  - Auditor — log access and compliance reporting.
- Support local fallback accounts when LDAP is unavailable.
- Add user and role management screens to the web console.
- Write integration tests against an embedded LDAP test server.

---

## Milestone 9 — Near-Line Storage & Backup

**Goal:** Implement tiered storage, lifecycle policies, and backup/recovery.

- Implement the **Hierarchical Storage Management (HSM)** engine:
  - Define storage tiers: Online (SSD/NVMe), Near-Line (NAS/external), Archive (object storage / tape).
  - Policy-driven automatic migration based on age, last-access, modality, or study status.
  - Transparent on-demand recall from near-line to online when queried.
- Implement **Storage Commitment SCP** (N-ACTION/N-EVENT-REPORT) — confirm to modalities that studies are safely archived.
- Implement scheduled and on-demand **Backup**:
  - Local backup targets (directory, external drive).
  - Network backup targets (SMB/NFS share).
  - Cloud-compatible object storage (S3-compatible API).
- Implement **Point-in-Time Recovery** for the metadata database.
- Implement periodic **Integrity Scan** — verify SHA-256 checksums across all archived objects.
- Add backup and storage tier management to the web console.

---

## Milestone 10 — Worklist, MPPS & Workflow

**Goal:** Support modality worklist, procedure tracking, and RIS-friendly notification APIs for clinical workflow.

- Implement **Modality Worklist (MWL) SCP** — serve scheduled procedure step information to modalities.
- Implement **Modality Performed Procedure Step (MPPS) SCP** — receive procedure status (in-progress, completed, discontinued).
- Implement **Instance Availability Notification (IAN)** — notify downstream systems (including RIS) when studies become available, both as a DICOM service and as a RESTful API.
- Implement **IAN-Style REST APIs for RIS Integration** — RESTful endpoints that mirror IAN semantics, enabling RIS and other non-DICOM systems to subscribe to study-available, study-updated, and study-archived events via webhooks or polling.
- Define and implement the **RIS Event Catalog** — the full set of lifecycle events published via DICOM IAN and RESTful webhooks:
  - `study.received` — first instance of a new study stored (payload: studyInstanceUID, accessionNumber, patientID, patientName, modality, studyDate, studyDescription?, receivingAE, sourceAE, timestamp).
  - `study.updated` — additional instances arrive for an existing study (payload: studyInstanceUID, accessionNumber, seriesCount, instanceCount, latestSeriesUID, sourceAE, timestamp).
  - `study.complete` — study completeness criteria met (payload: studyInstanceUID, accessionNumber, patientID, modality, seriesCount, instanceCount, studyStatus, timestamp).
  - `study.available` — study available for retrieval / IAN equivalent (payload: studyInstanceUID, accessionNumber, patientID, retrieveAE, retrieveURL, availableTransferSyntaxes[], timestamp).
  - `study.routed` — study forwarded to a destination (payload: studyInstanceUID, accessionNumber, destinationAE, destinationURL, transferSyntaxUsed, routeRuleID, timestamp).
  - `study.archived` — study migrated to near-line/offline tier (payload: studyInstanceUID, accessionNumber, storageTier, archiveFormat, archivePath, timestamp).
  - `study.rehydrated` — study recalled to online tier (payload: studyInstanceUID, accessionNumber, previousTier, currentTier, recallDuration, timestamp).
  - `study.deleted` — study permanently removed (payload: studyInstanceUID, accessionNumber, patientID, deletionReason, deletedBy, timestamp).
  - `study.error` — processing error (payload: studyInstanceUID, accessionNumber, errorCode, errorMessage, stage, timestamp).
  - Webhook delivery via JSON/HTTPS POST with HMAC-SHA256 signatures (per-subscription shared secret with key rotation support), configurable retry with exponential back-off, and subscription management via the Admin API. Fields marked with `?` are nullable and may be absent when the triggering event occurs before the attribute is available.
- Integrate with HL7 v2.x ORM/ORU messages via [HL7kit](https://github.com/Raster-Lab/HL7kit) for order-driven workflows.
- Add worklist management screens to the web console.

---

## Milestone 11 — HL7 & FHIR Interoperability

**Goal:** Full healthcare messaging integration.

- Implement an **HL7 v2.x MLLP listener** using HL7kit for ADT (patient demographics), ORM (orders), and ORU (results) messages.
- Implement **HL7 FHIR R4** resource endpoints:
  - `ImagingStudy` — expose studies as FHIR resources.
  - `Patient` — patient demographics synchronisation.
  - `DiagnosticReport` — radiology report references.
  - `Endpoint` — FHIR endpoint discovery for DICOMweb URLs.
- Implement configurable message routing and transformation rules.
- Support HL7 message acknowledgement (ACK/NACK) workflows.
- Write integration tests with sample HL7 and FHIR message flows.

---

## Milestone 12 — Security Hardening & IHE Compliance

**Goal:** Production-grade security and IHE profile conformance.

- Implement **IHE ATNA** (Audit Trail and Node Authentication):
  - Structured audit messages (RFC 3881 / DICOM Audit Message XML).
  - Syslog export (TLS-secured UDP/TCP).
  - Tamper-evident local audit log storage.
- Implement **Anonymisation / Pseudonymisation** profiles for research data export (DICOM PS3.15 Annex E).
- Implement per-study and per-patient **Access Control Lists (ACLs)** for sensitive data.
- Conduct security review: TLS configuration, input validation, DICOM fuzzing, API authentication.
- Publish **IHE Integration Statements** for targeted profiles (SWF, PIR, CPI, KIN, XDS-I.b).
- Provide GDPR and HIPAA compliance configuration guides.

---

## Milestone 13 — Monitoring, Metrics & Operations

**Goal:** Production observability and operational tooling.

- Implement a **Prometheus-compatible `/metrics` endpoint** exposing:
  - Active associations, requests/second, latency percentiles.
  - Storage utilisation per tier, compression ratios.
  - Backup status and last-run timestamps.
  - Error rates and queue depths.
- Implement a **`/health` endpoint** for load balancer and orchestrator probes.
- Publish a sample **Grafana dashboard** configuration.
- Implement graceful shutdown with in-flight association draining.
- Implement **automated database migrations** on server startup.
- Provide **Docker / OCI container images** with multi-architecture support (amd64, arm64).
- Provide **macOS launchd** plist and **Linux systemd** unit files.

---

## Milestone 14 — Performance Optimisation & Benchmarking

**Goal:** Tune for production workloads and publish performance baselines.

- Profile and optimise the DICOM association pipeline (zero-copy buffer handling, send file).
- Optimise database query plans for C-FIND on large archives (100K+ studies).
- Optimise concurrent C-STORE throughput (target: saturate 10 Gbps on Apple Silicon).
- Benchmark all codec paths (J2KSwift, JLSwift, JXLSwift) for encode/decode throughput.
- Optimise near-line recall latency for HSM-migrated studies.
- Publish reproducible benchmark scripts and baseline results.
- Conduct stress testing with synthetic DICOM datasets.

---

## Milestone 15 — Documentation, Packaging & Release

**Goal:** First public release with complete documentation.

- Write the **DICOM Conformance Statement** (DICOM PS3.2 style).
- Write the **Administrator Guide** — installation, configuration, LDAP setup, backup, upgrades.
- Write the **API Reference** — OpenAPI/Swagger specs for Admin API and DICOMweb endpoints.
- Write the **Deployment Guide** — bare-metal macOS, bare-metal Linux, Docker, Docker Compose.
- Publish **Homebrew formula** (macOS) and **APT/RPM packages** (Linux).
- Create the project website and release notes.
- Tag **v1.0.0** release.

---

## Milestone Summary

| # | Milestone | Key Deliverable |
|---|---|---|
| 1 | Project Bootstrap & Core Infrastructure | SPM workspace, CI, architecture foundations |
| 2 | DICOM Association & Verification | C-ECHO SCP/SCU, TCP association handling |
| 3 | Storage Service | C-STORE SCP/SCU, on-disk archive, metadata DB, store-as-received, serve-as-stored, ZIP/TAR+Zstd packaging, storage policy matrix |
| 4 | Image Codec Integration | J2KSwift, JLSwift, JXLSwift, OpenJP3D, compressed copy on receipt, unified object presentation, representation model |
| 5 | Query/Retrieve Services | C-FIND, C-MOVE, C-GET SCP/SCU |
| 6 | DICOMweb Services | WADO-RS, QIDO-RS, STOW-RS, UPS-RS |
| 7 | Web Administration Console | Admin REST API, responsive web UI, setup wizard |
| 8 | User Management & LDAP | LDAP auth, RBAC, DICOM LDAP configuration |
| 9 | Near-Line Storage & Backup | HSM, storage commitment, backup & recovery |
| 10 | Worklist, MPPS & Workflow | MWL SCP, MPPS, IAN (DICOM + REST), RIS event catalog, webhook delivery |
| 11 | HL7 & FHIR Interoperability | HL7 v2.x MLLP, FHIR R4 resources |
| 12 | Security Hardening & IHE Compliance | ATNA, anonymisation, ACLs, IHE profiles |
| 13 | Monitoring, Metrics & Operations | Prometheus, Docker, systemd, health checks |
| 14 | Performance Optimisation | Benchmarks, tuning, stress testing |
| 15 | Documentation, Packaging & Release | Conformance statement, guides, v1.0.0 |

---

*Milestones are sequential but may overlap where dependencies allow parallel work. Each milestone concludes with a tagged pre-release for testing and review.*
