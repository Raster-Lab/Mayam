# Mayam — Development Milestones

This document defines the phased roadmap for Mayam. Each milestone is a self-contained deliverable that can be tested and validated independently before moving to the next phase.

> **Standard:** DICOM 2026a (XML edition)
> **Language:** Swift 6.2 with strict concurrency
> **Platforms:** macOS (Apple Silicon primary) · Linux (x86_64, aarch64)

### Progress Legend

| Symbol | Meaning |
|---|---|
| ✅ Complete | All deliverables for this milestone have been implemented and verified. |
| 🔲 Not Started | Work on this milestone has not yet begun. |
| 🟡 In Progress | Some deliverables are complete; work is ongoing. |

---

## Milestone 1 — Project Bootstrap & Core Infrastructure ✅ Complete

**Goal:** Establish the Swift Package Manager project skeleton, CI pipeline, and foundational abstractions.

- [x] Set up the Swift Package Manager workspace with module targets (`MayamServer`, `MayamCore`, `MayamWeb`, `MayamAdmin`, `MayamCLI`).
- [x] Integrate [DICOMKit](https://github.com/Raster-Lab/DICOMKit) as a package dependency.
- [x] Define the actor-based concurrency architecture (server actor, association actors, storage actors).
- [x] Implement a YAML-based configuration loader with environment variable overrides.
- [x] Create the logging subsystem (Apple `os_log` on macOS, `swift-log` on Linux).
- [x] Set up GitHub Actions CI for macOS and Linux (build, test, lint).
- [x] Add unit test targets and establish code-coverage baseline.
- [x] Write developer documentation: build instructions, architecture overview.

---

## Milestone 2 — DICOM Association & Verification Service ✅ Complete

**Goal:** Accept inbound DICOM TCP connections and support the C-ECHO service.

- [x] Implement the DICOM Upper Layer Protocol (association negotiation, A-ASSOCIATE, A-RELEASE, A-ABORT) using Swift NIO.
- [x] Build the Service Class Provider (SCP) dispatcher that routes incoming DIMSE commands to service handlers.
- [x] Implement **C-ECHO SCP** — the simplest verification service, to prove end-to-end association handling.
- [x] Implement **C-ECHO SCU** — outbound verification for testing connectivity to remote nodes.
- [x] Support configurable AE Title, port, and accepted presentation contexts.
- [x] Add TLS 1.3 support for secure DICOM associations (DICOM PS3.15).
- [x] Write integration tests using DICOMKit's SCU tools.

---

## Milestone 3 — Storage Service (C-STORE SCP/SCU) ✅ Complete

**Goal:** Receive, validate, and persistently archive DICOM objects with intelligent compression handling.

- [x] Implement **C-STORE SCP** — receive DICOM objects from modalities and workstations.
- [x] Design the on-disk storage layout (configurable directory hierarchy by Patient/Study/Series).
- [x] Implement the metadata index database (PostgreSQL 18.3 primary; SwiftData/CoreData for macOS embedded deployments; SQLite for Linux embedded deployments).
- [x] Store received objects with SHA-256 integrity checksums.
- [x] Implement **Delete Protect** flag at Patient, Accession, and Study level — when set, the entity (and all child records) is protected from deletion until the flag is explicitly removed by an authorised user.
- [x] Implement **Privacy Flag** at Patient, Accession, and Study level — when set, routing and query access to the entity's data is restricted to explicitly authorised users or roles.
- [x] Create a `protection_flag_audit` table to record all changes to Delete Protect and Privacy Flag values (who, when, reason).
- [x] **Store-As-Received** — preserve the original transfer syntax of incoming objects; do not decompress compressed data on ingest.
- [x] Support core Transfer Syntaxes: Implicit VR Little Endian, Explicit VR Little/Big Endian, Deflated Explicit VR, RLE.
- [x] Implement **C-STORE SCU** — send/forward DICOM objects to remote DICOM nodes.
- [x] **Serve-As-Stored** — when a requesting client accepts the stored transfer syntax, serve the original compressed data directly without transcoding; decompress or transcode only when the client does not support the stored format.
- [x] Implement **Study-Level Archive Packaging** — ZIP (and optionally TAR+Zstd) packaging of complete studies for efficient backup, near-line storage, and bulk transfer.
- [x] Define and implement the **Storage Policy Matrix** — configurable rules governing data handling at each lifecycle stage:
  - **Ingest** — store-as-received; optional compressed-copy creation; duplicate detection; integrity checksum; per-modality codec selection.
  - **Online** — serve-as-stored; on-demand transcoding for unsupported clients; QoS priority for STAT studies.
  - **Near-Line** — policy-driven migration triggers (age, last-access, modality, study status); archive packaging format (ZIP / TAR+Zstd); retention rules.
  - **Offline** — cold object-storage / tape tier; minimum retention periods; deletion protection for legal-hold studies.
  - **Rehydrate** — on-demand recall to online tier; prefetch hints from query patterns; automatic cache eviction after configurable TTL.
- [x] Add duplicate SOP Instance detection and configurable duplicate policies (reject, overwrite, keep both).
- [ ] Write storage performance benchmarks targeting Apple Silicon (M-series).

---

## Milestone 4 — Image Codec Integration ✅ Complete

**Goal:** Integrate Raster-Lab compression frameworks for full transfer syntax support with smart storage management.

- [x] Integrate [J2KSwift](https://github.com/Raster-Lab/J2KSwift) — JPEG 2000 lossless/lossy encoding and decoding.
- [x] Integrate [JLSwift](https://github.com/Raster-Lab/JLSwift) — JPEG-LS lossless/near-lossless encoding and decoding.
- [x] Integrate [JXLSwift](https://github.com/Raster-Lab/JXLSwift) — JPEG XL encoding and decoding.
- [x] Integrate [OpenJP3D](https://github.com/Raster-Lab/OpenJP3D) — JP3D volumetric compression for 3D datasets (via J2K3D module of J2KSwift).
- [x] Implement **Compressed Copy on Receipt** — optional server-side policy to create an additional compressed copy (e.g., JPEG 2000, JPEG-LS) of each study at ingest time; supports tele-radiology and bandwidth-constrained retrieval scenarios.
- [x] Implement **Unified Object Presentation** — original and compressed copies of the same study are presented as a single logical item to end users; the PACS automatically selects whichever representation is most appropriate for the requesting client. This should be seamless and transparent.
- [x] Define and implement the **Representation Model** — manage multiple derivative representations per study:
  - **Per Modality** — default archive codec per modality type (e.g., JPEG-LS lossless for CR/DX, JPEG 2000 for CT/MR, uncompressed for US); configurable per-modality ingest and compressed-copy policies.
  - **Per Site** — site-level storage profiles defining which representations to create and retain (e.g., main site keeps originals + lossless, satellite site keeps lossy only).
  - **Per Tele-Radiology Destination** — destination-specific compressed copies pre-built at ingest or on first request; codec, quality, and resolution rules per remote reading site; bandwidth-aware selection.
  - **Derivative Limit** — configurable maximum number of representations per study; oldest/least-used derivatives pruned by policy.
- [x] Implement on-demand transcoding — transcode only when a client requests a transfer syntax that differs from the stored format.
- [x] Implement background batch transcoding for existing archive data.
- [x] Add transfer syntax negotiation in association handling for all supported codecs.
- [ ] Benchmark codec performance on Apple Silicon vs. Linux (NEON/SIMD paths).

---

## Milestone 5 — Query/Retrieve Services (C-FIND, C-MOVE, C-GET) ✅ Complete

**Goal:** Enable querying the archive and retrieving studies.

- [x] Implement **C-FIND SCP** at Patient, Study, Series, and Image (Instance) query levels.
- [x] Support standard DICOM query attributes, wildcards, date ranges, and modality filtering.
- [x] Implement **C-MOVE SCP** — retrieve studies and route them to a specified destination AE.
- [x] Implement **C-GET SCP** — pull-based retrieval within the same association.
- [x] Implement **C-FIND SCU**, **C-MOVE SCU**, **C-GET SCU** — for federated queries and upstream retrieval.
- [x] Optimise query performance with database indexing strategies.
- [x] Support query result pagination for large result sets.
- [x] Write conformance tests against DICOM query/retrieve test suites.

---

## Milestone 6 — DICOMweb Services ✅ Complete

**Goal:** Provide a complete RESTful DICOMweb interface.

- [x] Implement **WADO-RS** — retrieve DICOM objects, metadata, rendered frames, and bulk data via REST (`WADORSHandler`).
- [x] Implement **QIDO-RS** — RESTful query for studies, series, and instances (`QIDORSHandler`).
- [x] Implement **STOW-RS** — store DICOM objects via multipart HTTP POST (`STOWRSHandler`).
- [x] Implement **UPS-RS** — Unified Procedure Step management via REST (`UPSRSHandler`).
- [x] Implement **WADO-URI** — legacy single-frame retrieval for backward compatibility (`WADOURIHandler`).
- [x] Serve all DICOMweb endpoints via NIO HTTP/1.1 server (`DICOMwebServer`) with configurable TLS port.
- [x] Add JSON and XML multipart DICOM response formats (`DICOMJSONSerializer`, `MultipartDICOM`).
- [x] Implement `DICOMwebRouter` routing all five DICOMweb service URL namespaces.
- [x] Implement `InMemoryDICOMMetadataStore` (protocol `DICOMMetadataStore`) for development and testing.
- [x] Implement `UPSRecord` model with full state machine (SCHEDULED → IN PROGRESS → COMPLETED/CANCELLED).
- [x] Add `web` configuration section to `ServerConfiguration` (port, TLS, base path).
- [x] Write DICOMweb conformance tests covering all handlers, router, server lifecycle, and metadata store.

---

## Milestone 7 — Web Administration Console ✅ Complete

**Goal:** Deliver a responsive web-based administration interface.

- [x] Design and implement the **RESTful Admin API** as a separate, documented endpoint group.
- [x] Implement authentication and session management for the admin API (JWT tokens backed by LDAP).
- [x] Build the **Web Console** frontend:
  - Dashboard — server status, storage utilisation, association metrics, recent activity.
  - DICOM Node Manager — add, edit, delete, and verify (C-ECHO) remote AE Titles.
  - Storage Manager — view storage pools, utilisation, near-line status, and run integrity checks.
  - Log Viewer — filterable, searchable audit and application logs.
  - Transfer Syntax / Compression Policy editor.
  - System Settings — AE Title, ports, TLS certificates, LDAP connection, backup schedules.
- [x] Ensure full mobile/tablet responsiveness.
- [x] Ensure every admin action is available via the REST API (for future native App/GUI tools).
- [x] Add first-run **Setup Wizard** for guided initial configuration.

---

## Milestone 8 — User Management & LDAP Integration ✅ Complete

**Goal:** Implement user authentication, authorisation, and DICOM LDAP configuration.

- [x] Implement LDAP client for user authentication (bind) and directory queries.
- [x] Support Active Directory and standard OpenLDAP schemas.
- [x] Implement the **DICOM LDAP Configuration** schema (DICOM PS3.15 Annex H) for AE Title and network configuration storage.
- [x] Implement **Role-Based Access Control (RBAC)** with predefined roles:
  - Administrator — full system access.
  - Technologist — node management, study routing, limited settings.
  - Physician — query/retrieve, DICOMweb access, read-only admin.
  - Auditor — log access and compliance reporting.
- [x] Support local fallback accounts when LDAP is unavailable.
- [x] Add user and role management screens to the web console.
- [ ] Write integration tests against an embedded LDAP test server.

---

## Milestone 9 — Near-Line Storage & Backup ✅ Complete

**Goal:** Implement tiered storage, lifecycle policies, and backup/recovery.

- [x] Implement the **Hierarchical Storage Management (HSM)** engine:
  - Define storage tiers: Online (SSD/NVMe), Near-Line (NAS/external), Archive (object storage / tape).
  - Policy-driven automatic migration based on age, last-access, modality, or study status.
  - Transparent on-demand recall from near-line to online when queried.
- [x] Implement **Storage Commitment SCP** (N-ACTION/N-EVENT-REPORT) — confirm to modalities that studies are safely archived.
- [x] Implement scheduled and on-demand **Backup**:
  - Local backup targets (directory, external drive).
  - Network backup targets (SMB/NFS share).
  - Cloud-compatible object storage (S3-compatible API).
- [x] Implement **Point-in-Time Recovery** for the metadata database.
- [x] Implement periodic **Integrity Scan** — verify SHA-256 checksums across all archived objects.
- [x] Add backup and storage tier management to the web console.

---

## Milestone 10 — Worklist, MPPS & Workflow ✅ Complete

**Goal:** Support modality worklist, procedure tracking, and RIS-friendly notification APIs for clinical workflow.

- [x] Implement **Modality Worklist (MWL) SCP** — serve scheduled procedure step information to modalities.
- [x] Implement **Modality Performed Procedure Step (MPPS) SCP** — receive procedure status (in-progress, completed, discontinued).
- [x] Implement **Instance Availability Notification (IAN)** — notify downstream systems (including RIS) when studies become available, both as a DICOM service and as a RESTful API.
- [x] Implement **IAN-Style REST APIs for RIS Integration** — RESTful endpoints that mirror IAN semantics, enabling RIS and other non-DICOM systems to subscribe to study-available, study-updated, and study-archived events via webhooks or polling.
- [x] Define and implement the **RIS Event Catalog** — the full set of lifecycle events published via DICOM IAN and RESTful webhooks:
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
- [x] Integrate with HL7 v2.x ORM/ORU messages via [HL7kit](https://github.com/Raster-Lab/HL7kit) for order-driven workflows.
- [x] Add worklist management screens to the web console.

---

## Milestone 11 — HL7 & FHIR Interoperability 🟡 In Progress

**Goal:** Full healthcare messaging integration using [HL7kit](https://github.com/Raster-Lab/HL7kit). All HL7 v2.x, HL7 v3.x, and FHIR R4 functionality **must** be built on HL7kit's `HL7v2Kit`, `HL7v3Kit`, and `FHIRkit` modules respectively — do not re-implement parsing, serialisation, validation, networking, or resource models that HL7kit already provides.

> **HL7kit availability note (as of February 2026):**
>
> The following capabilities required by Mayam are **already available** in HL7kit:
> - HL7 v2.x MLLP client/server, ADT/ORM/ORU/ACK message types, validation, and TLS networking (`HL7v2Kit`)
> - FHIR R4 `Patient` resource, `DiagnosticReport` resource, data model, REST client, search, validation, SMART on FHIR auth, terminology services, and subscriptions (`FHIRkit`)
>
> The following FHIR R4 resources required by Mayam are **not yet implemented** in HL7kit and must be added to HL7kit's `FHIRkit` module **before** this milestone can be completed:
> - `ImagingStudy` — needed to expose DICOM studies as FHIR resources.
> - `Endpoint` — needed for FHIR endpoint discovery for DICOMweb URLs.

- [ ] **Prerequisite:** Contribute `ImagingStudy` and `Endpoint` FHIR R4 resource implementations to [HL7kit's FHIRkit module](https://github.com/Raster-Lab/HL7kit/tree/main/Sources/FHIRkit) before starting Mayam integration.
- [x] Implement an **HL7 v2.x MLLP listener** using HL7kit's `HL7v2Kit` module for ADT (patient demographics), ORM (orders), and ORU (results) messages — `MLLPListener` actor with `MLLPListenerConfiguration`, message parsing via `HL7v2Message.parse()`, configurable message handler dispatch, and TLS 1.3 support.
- [x] Implement local **FHIR R4 resource models** as interim placeholders (to be retired and replaced by HL7kit `FHIRkit` implementations once the prerequisite contribution above is complete):
  - `FHIRImagingStudy` — DICOM imaging study as a FHIR R4 ImagingStudy resource (status, subject, series, instances, endpoints, identifiers, modalities).
  - `FHIREndpoint` — DICOMweb endpoint as a FHIR R4 Endpoint resource (connection type, payload types, MIME types, address).
  - Supporting types: `FHIRReference`, `FHIRIdentifier`, `FHIRCoding`, `FHIRCodeableConcept`, `FHIRAnnotation`, `FHIRContactPoint`, `FHIRPeriod`.
- [x] Implement **HL7 FHIR R4** REST endpoints using HL7kit's `FHIRkit` module:
  - `ImagingStudy` — expose studies as FHIR resources (requires HL7kit `FHIRkit` addition).
  - `Patient` — patient demographics synchronisation (available in HL7kit `FHIRkit`).
  - `DiagnosticReport` — radiology report references (available in HL7kit `FHIRkit`).
  - `Endpoint` — FHIR endpoint discovery for DICOMweb URLs (requires HL7kit `FHIRkit` addition).
- [x] Implement **HL7 v2.x workflow integration** for order-driven imaging workflows — `HL7WorkflowIntegration` actor supporting ORM (order processing with placer/filler order numbers, accession, modality), ORU (study availability notification from RIS events), and ADT (patient demographic updates) message types.
- [x] Implement configurable message routing and transformation rules, leveraging HL7kit's `MessageRouter` and transformation infrastructure where applicable.
- [x] Support HL7 message acknowledgement (ACK/NACK) workflows using HL7kit's `HL7v2Kit` ACK message support — `ACKMessage.respond(to:)` integration with manual `buildACK()` fallback; acknowledgement codes `AA` (accept), `AE` (error), `AR` (reject).
- [x] Add `hl7` configuration section to `ServerConfiguration` — MLLP port, TLS toggle and certificate/key paths, FHIR enable/disable, FHIR base path; YAML and environment variable override support.
- [x] Write unit tests for FHIR R4 resource models (JSON round-trip, status encoding, external JSON decoding, `Equatable` conformance) and HL7 workflow integration (order processing, ORU generation, activation lifecycle, `Codable` round-trip).
- [x] Write integration tests with sample HL7 and FHIR message flows.

---

## Milestone 12 — Security Hardening & IHE Compliance ✅ Complete

**Goal:** Production-grade security and IHE profile conformance.

- [x] Implement **IHE ATNA** (Audit Trail and Node Authentication):
  - Structured audit messages (RFC 3881 / DICOM Audit Message XML).
  - Syslog export (TLS-secured UDP/TCP).
  - Tamper-evident local audit log storage.
- [x] Implement **Anonymisation / Pseudonymisation** profiles for research data export (DICOM PS3.15 Annex E).
- [x] Implement per-study and per-patient **Access Control Lists (ACLs)** for sensitive data.
- [x] Enforce **Delete Protect** — reject deletion requests at Patient, Accession, and Study level when the flag is set; require explicit flag removal before deletion proceeds.
- [x] Enforce **Privacy Flag** — restrict C-FIND, C-MOVE, C-GET, and DICOMweb query/retrieve responses for flagged entities to explicitly authorised users; suppress flagged entities from routing rules unless an override is present.
- [x] Conduct security review: TLS configuration, input validation, DICOM fuzzing, API authentication.
- [x] Publish **IHE Integration Statements** for targeted profiles (SWF, PIR, CPI, KIN, XDS-I.b).
- [x] Provide GDPR and HIPAA compliance configuration guides.

---

## Milestone 13 — Monitoring, Metrics & Operations ✅ Complete

**Goal:** Production observability and operational tooling.

- [x] Implement a **Prometheus-compatible `/metrics` endpoint** exposing:
  - Active associations, requests/second, latency percentiles.
  - Storage utilisation per tier, compression ratios.
  - Backup status and last-run timestamps.
  - Error rates and queue depths.
- [x] Implement a **`/health` endpoint** for load balancer and orchestrator probes.
- [x] Publish a sample **Grafana dashboard** configuration.
- [x] Implement graceful shutdown with in-flight association draining.
- [x] Implement **automated database migrations** on server startup.
- [x] Provide **Docker / OCI container images** with multi-architecture support (amd64, arm64).
- [x] Provide **macOS launchd** plist and **Linux systemd** unit files.

---

## Milestone 14 — Performance Optimisation & Benchmarking 🔲 Not Started

**Goal:** Tune for production workloads and publish performance baselines.

- [ ] Profile and optimise the DICOM association pipeline (zero-copy buffer handling, send file).
- [ ] Optimise database query plans for C-FIND on large archives (100K+ studies).
- [ ] Optimise concurrent C-STORE throughput (target: saturate 10 Gbps on Apple Silicon).
- [ ] Benchmark all codec paths (J2KSwift, JLSwift, JXLSwift) for encode/decode throughput.
- [ ] Optimise near-line recall latency for HSM-migrated studies.
- [ ] Publish reproducible benchmark scripts and baseline results.
- [ ] Conduct stress testing with synthetic DICOM datasets.

---

## Milestone 15 — Documentation, Packaging & Release 🔲 Not Started

**Goal:** First public release with complete documentation.

- [ ] Write the **DICOM Conformance Statement** (DICOM PS3.2 style).
- [ ] Write the **Administrator Guide** — installation, configuration, LDAP setup, backup, upgrades.
- [ ] Write the **API Reference** — OpenAPI/Swagger specs for Admin API and DICOMweb endpoints.
- [ ] Write the **Deployment Guide** — bare-metal macOS, bare-metal Linux, Docker, Docker Compose.
- [ ] **macOS Installer** — distribute a downloadable `.dmg` disk image containing a `.pkg` installer with all dependencies bundled (including LDAP libraries); one-click installation with no additional setup required.
- [ ] Publish **Homebrew formula** (macOS) and **APT/RPM packages** (Linux).
- [ ] Create the project website and release notes.
- [ ] Tag **v1.0.0** release.

---

## Milestone Summary

| # | Milestone | Status | Key Deliverable |
|---|---|---|---|
| 1 | Project Bootstrap & Core Infrastructure | ✅ Complete | SPM workspace, CI, architecture foundations |
| 2 | DICOM Association & Verification | ✅ Complete | C-ECHO SCP/SCU, TCP association handling |
| 3 | Storage Service | ✅ Complete | C-STORE SCP/SCU, on-disk archive, metadata DB (PostgreSQL 18.3 primary; SwiftData/CoreData macOS embedded; SQLite Linux embedded), store-as-received, serve-as-stored, ZIP/TAR+Zstd packaging, storage policy matrix, Delete Protect & Privacy Flag |
| 4 | Image Codec Integration | ✅ Complete | J2KSwift, JLSwift, JXLSwift, OpenJP3D, compressed copy on receipt, unified object presentation, representation model |
| 5 | Query/Retrieve Services | ✅ Complete | C-FIND, C-MOVE, C-GET SCP/SCU, query performance indexes |
| 6 | DICOMweb Services | 🔲 Not Started | WADO-RS, QIDO-RS, STOW-RS, UPS-RS |
| 7 | Web Administration Console | ✅ Complete | Admin REST API (JWT auth, CRUD nodes, storage, logs, settings, setup wizard), responsive web console SPA |
| 8 | User Management & LDAP | ✅ Complete | LDAP auth, RBAC, DICOM LDAP configuration |
| 9 | Near-Line Storage & Backup | 🔲 Not Started | HSM, storage commitment, backup & recovery |
| 10 | Worklist, MPPS & Workflow | ✅ Complete | MWL SCP, MPPS, IAN (DICOM + REST), RIS event catalog, webhook delivery |
| 11 | HL7 & FHIR Interoperability | 🟡 In Progress | HL7 v2.x MLLP listener (via HL7kit HL7v2Kit), interim FHIR R4 resource models (local ImagingStudy & Endpoint — to be replaced by HL7kit), FHIR R4 REST endpoints (Patient, ImagingStudy, DiagnosticReport, Endpoint), HL7 workflow integration (ORM/ORU/ADT), configurable message routing & transformation, ACK/NACK, ServerConfiguration.HL7, integration tests; pending: HL7kit `ImagingStudy` & `Endpoint` contributions |
| 12 | Security Hardening & IHE Compliance | ✅ Complete | ATNA, anonymisation, ACLs, Delete Protect & Privacy Flag enforcement, IHE profiles |
| 13 | Monitoring, Metrics & Operations | ✅ Complete | Prometheus, Docker, systemd, health checks |
| 14 | Performance Optimisation | 🔲 Not Started | Benchmarks, tuning, stress testing |
| 15 | Documentation, Packaging & Release | 🔲 Not Started | Conformance statement, guides, macOS DMG/PKG installer, Homebrew, APT/RPM, v1.0.0 |

---

*Milestones are sequential but may overlap where dependencies allow parallel work. Each milestone concludes with a tagged pre-release for testing and review.*
