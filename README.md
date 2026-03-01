# Mayam Server

**A modern, clean-sheet PACS server built from the ground up in Swift.**

Mayam Server is a departmental-level Picture Archiving and Communication System (PACS) designed for clinics, medium-sized hospitals, and veterinary practices. It is built entirely in Swift 6.2 with strict concurrency, optimised for Apple Silicon (M-series) processors, and fully cross-platform with first-class Linux support.

Mayam Server follows the **DICOM Standard 2026a** (XML edition) and leverages the [Raster-Lab](https://github.com/Raster-Lab) family of frameworks—making it both a production-grade PACS and a showcase for these libraries.

---

## Design Principles

| Principle | Description |
|---|---|
| **Clean-Sheet** | No legacy code, no C/C++ bridges for core logic—pure Swift from networking to storage. |
| **Easy to Deploy** | Single-binary server; minimal external dependencies; guided setup wizard. |
| **Easy to Administer** | Responsive web-based administration console usable by clinicians and lay staff. |
| **Stable & Performant** | Designed around Swift structured concurrency, zero-copy I/O, and Apple Silicon SIMD. |
| **Standards-First** | DICOM 2026a compliance throughout; HL7 v2/FHIR interoperability out of the box. |
| **Open & Extensible** | Clear API separation between server core and administration UI; plugin architecture. |

---

## Feature List

### Core DICOM Services

- **C-STORE SCP/SCU** — Receive and send DICOM objects from/to any modality or workstation.
- **C-FIND SCP/SCU** — Patient, Study, Series, and Image-level query support.
- **C-MOVE SCP/SCU** — Retrieve and route studies between DICOM nodes.
- **C-GET SCP/SCU** — Pull-based retrieval for firewall-friendly environments.
- **C-ECHO SCP/SCU** — DICOM verification (ping) for connectivity testing.
- **Storage Commitment (N-ACTION/N-EVENT-REPORT)** — Confirm reliable archival of studies.
- **Modality Worklist (MWL) SCP** — Provide scheduled procedure information to modalities.
- **Modality Performed Procedure Step (MPPS) SCP** — Track procedure progress in real time.
- **DICOM Print Management SCP** — Film-based and virtual print support.
- **Instance Availability Notification (IAN)** — Notify downstream systems (including RIS) when studies are available; exposed as both a DICOM service and a RESTful API for easy integration.
- **Multiple Transfer Syntax Support** — Including Implicit/Explicit VR Little/Big Endian, JPEG, JPEG 2000, JPEG-LS, JPEG XL, RLE, and Deflated Explicit VR.

### DICOMweb Services

- **WADO-RS** — RESTful retrieval of DICOM objects and rendered frames.
- **QIDO-RS** — RESTful query across patients, studies, series, and instances.
- **STOW-RS** — RESTful store of DICOM objects via HTTP.
- **UPS-RS** — Unified Procedure Step over REST for worklist management.
- **WADO-URI** — Legacy web-access retrieval compatibility.

### Storage & Archive

- **Online Storage** — High-performance primary storage on local SSDs/NVMe with configurable file system layouts.
- **Near-Line Storage** — Tiered storage with policy-driven migration to slower/cheaper media (NAS, external drives, object storage).
- **Hierarchical Storage Management (HSM)** — Automatic data lifecycle policies (hot → warm → cold).
- **Backup & Disaster Recovery** — Scheduled and on-demand backups; support for local, network, and cloud backup targets; point-in-time recovery.
- **Storage Commitment Verification** — End-to-end integrity checks on archived data.
- **Study-Level Archive Packaging** — ZIP (and optionally TAR+Zstd) packaging of studies for efficient bulk transfer, backup, and near-line storage.
- **Store-As-Received** — Studies received in a compressed transfer syntax are stored in their original compressed form; no unnecessary decompression on ingest.
- **Serve-As-Stored** — When a client supports the stored transfer syntax, serve the original compressed data directly without transcoding; decompress or transcode only when the requesting client does not support the stored format.
- **Compressed Copy on Receipt** — Optional server-side policy to create an additional compressed copy (e.g., JPEG 2000, JPEG-LS) of each study at ingest time, supporting tele-radiology and bandwidth-constrained retrieval scenarios.
- **Unified Object Presentation** — Original and compressed copies of the same study are presented as a single logical item to end users; the PACS automatically serves whichever representation is most appropriate for the requesting client.
- **Lossless & Lossy Transcoding** — On-the-fly or background transcoding between transfer syntaxes, triggered only when needed.
- **De-Duplication** — Content-addressable detection of duplicate SOP instances.

#### Storage Policy Matrix

Configurable rules govern data handling at each lifecycle stage:

| Stage | Applicable Policies |
|---|---|
| **Ingest** | Store-as-received; optional compressed-copy creation; duplicate detection; integrity checksum; study-level ZIP/TAR+Zstd packaging; per-modality codec selection |
| **Online** | Serve-as-stored; on-demand transcoding for unsupported clients; QoS priority for STAT studies |
| **Near-Line** | Policy-driven migration triggers (age, last-access, modality, study status); archive packaging format (ZIP / TAR+Zstd); retention rules |
| **Offline** | Tape / cold object-storage tier; minimum retention periods; deletion protection for legal-hold studies |
| **Rehydrate** | On-demand recall to online tier; prefetch hints from query patterns; automatic cache eviction after configurable TTL |

#### Representation Model

The server manages multiple derivative representations of each study, presented to end users as a single logical item:

| Dimension | Representation Rules |
|---|---|
| **Per Modality** | Default archive codec per modality type (e.g., JPEG-LS lossless for CR/DX, JPEG 2000 for CT/MR, uncompressed for US). Configurable per-modality ingest and compressed-copy policies. |
| **Per Site** | Site-level storage profiles defining which representations to create and retain (e.g., a main site keeps originals + lossless, a satellite site keeps lossy only). |
| **Per Tele-Radiology Destination** | Destination-specific compressed copies pre-built at ingest or on first request; codec, quality, and resolution rules per remote reading site. Bandwidth-aware selection. |
| **Derivative Limit** | Configurable maximum number of representations per study (e.g., original + 2 compressed copies). Oldest/least-used derivatives can be pruned by policy. |

#### RIS Event Catalog (IAN + Webhooks)

Mayam Server publishes lifecycle events via DICOM Instance Availability Notification and equivalent RESTful webhooks. The following event catalog defines each event type and its payload:

| Event | Trigger | Key Payload Fields |
|---|---|---|
| `study.received` | First instance of a new study is stored | `studyInstanceUID`, `accessionNumber`, `patientID`, `patientName`, `modality`, `studyDate`, `studyDescription`?, `receivingAE`, `sourceAE`, `timestamp` |
| `study.updated` | Additional instances arrive for an existing study | `studyInstanceUID`, `accessionNumber`, `seriesCount`, `instanceCount`, `latestSeriesUID`, `sourceAE`, `timestamp` |
| `study.complete` | Study completeness criteria met (configurable timer / instance count / MPPS completed) | `studyInstanceUID`, `accessionNumber`, `patientID`, `modality`, `seriesCount`, `instanceCount`, `studyStatus`, `timestamp` |
| `study.available` | Study is available for retrieval (IAN equivalent) | `studyInstanceUID`, `accessionNumber`, `patientID`, `retrieveAE`, `retrieveURL` (DICOMweb), `availableTransferSyntaxes[]`, `timestamp` |
| `study.routed` | Study has been forwarded to a destination node | `studyInstanceUID`, `accessionNumber`, `destinationAE`, `destinationURL`, `transferSyntaxUsed`, `routeRuleID`, `timestamp` |
| `study.archived` | Study migrated to near-line / offline tier | `studyInstanceUID`, `accessionNumber`, `storageTier`, `archiveFormat`, `archivePath`, `timestamp` |
| `study.rehydrated` | Study recalled from near-line / offline to online | `studyInstanceUID`, `accessionNumber`, `previousTier`, `currentTier`, `recallDuration`, `timestamp` |
| `study.deleted` | Study permanently removed from all tiers | `studyInstanceUID`, `accessionNumber`, `patientID`, `deletionReason`, `deletedBy`, `timestamp` |
| `study.error` | An error occurred during processing | `studyInstanceUID`, `accessionNumber`, `errorCode`, `errorMessage`, `stage` (ingest/route/archive/rehydrate), `timestamp` |

**Webhook delivery:** JSON payloads over HTTPS POST with HMAC-SHA256 signature verification (per-subscription shared secret with key rotation support); configurable retry with exponential back-off; subscription management via the Admin API. Fields marked with `?` are nullable and may be absent when the triggering event occurs before the attribute is available (e.g., `studyDescription` may not be present until subsequent instances arrive).

### Image Compression

Leveraging Raster-Lab's native Swift codecs for best-in-class performance on Apple Silicon:

| Codec | Framework | Key Benefit |
|---|---|---|
| JPEG 2000 (ISO 15444) | [J2KSwift](https://github.com/Raster-Lab/J2KSwift) | Lossless & lossy; HTJ2K high-throughput mode; JPIP streaming |
| JPEG-LS (ISO 14495) | [JLSwift](https://github.com/Raster-Lab/JLSwift) | Fast lossless/near-lossless; ARM NEON acceleration |
| JPEG XL (ISO 18181) | [JXLSwift](https://github.com/Raster-Lab/JXLSwift) | Next-gen codec; progressive decode; HDR support |
| JP3D Volumetric (ISO 15444-10) | [OpenJP3D](https://github.com/Raster-Lab/OpenJP3D) | Native 3D volume compression for CT/MR stacks |

### Healthcare Interoperability

- **HL7 v2.x Messaging** — ADT, ORM, ORU message processing via [HL7kit](https://github.com/Raster-Lab/HL7kit).
- **HL7 FHIR R4** — ImagingStudy, Patient, DiagnosticReport resource support.
- **MLLP Transport** — Standard Minimal Lower Layer Protocol with TLS.
- **IAN-Style REST APIs for RIS Integration** — RESTful endpoints mirroring Instance Availability Notification semantics, enabling RIS and other non-DICOM systems to subscribe to study-available, study-updated, and study-archived events via webhooks or polling.
- **IHE Profile Support** — Targets key IHE Radiology profiles:
  - Scheduled Workflow (SWF)
  - Patient Information Reconciliation (PIR)
  - Consistent Presentation of Images (CPI)
  - Key Image Note (KIN)
  - Import Reconciliation Workflow (IRWF)
  - Cross-Enterprise Document Sharing for Imaging (XDS-I.b)

### Administration & Configuration

- **Responsive Web Console** — Modern HTML5/CSS/JS administration interface; mobile-friendly.
- **RESTful Admin API** — Complete separation of UI and server; every admin function available via documented REST endpoints to enable future native GUI/App tools.
- **Setup Wizard** — Guided first-run configuration for AE Title, ports, storage paths, and network settings.
- **LDAP Integration** — User authentication and authorisation via LDAP/Active Directory, following DICOM configuration standards (LDAP DICOM schema).
- **Role-Based Access Control (RBAC)** — Predefined roles (Administrator, Technologist, Physician, Auditor) with customisable permissions.
- **Audit Logging** — DICOM/IHE ATNA-compliant audit trail; syslog export.
- **Dashboard & Monitoring** — Real-time server health, storage utilisation, association statistics, and error rate metrics.
- **DICOM Node Management** — Add, edit, verify (C-ECHO) remote AE Titles from the web console.
- **Transfer Syntax & Compression Policies** — Per-node and per-modality rules for inbound/outbound transcoding.

### Networking & Performance

- **Swift Structured Concurrency** — Actor-based isolation; no data races under strict concurrency.
- **Asynchronous I/O** — Built on Swift NIO for high-throughput, non-blocking network operations.
- **Apple Silicon Optimisation** — NEON SIMD, Accelerate framework, Metal compute shaders (macOS).
- **Linux Optimisation** — io_uring, epoll, and portable SIMD paths for Swift on Linux.
- **TLS 1.3 Support** — Secure DICOM (DICOM TLS) and HTTPS for DICOMweb / Admin API.
- **Connection Pooling** — Efficient association management for high-volume modality traffic.
- **Quality of Service (QoS)** — Configurable priority queues for STAT vs. routine studies.
- **Bandwidth Throttling** — Per-node and global rate limits to protect network resources.

### Security & Compliance

- **DICOM TLS** — Encrypted DICOM associations per DICOM PS3.15.
- **HTTPS Everywhere** — All web services served over TLS.
- **LDAP/AD Authentication** — Centralised identity management.
- **IHE ATNA Audit Trail** — Tamper-evident logging of all access and modifications.
- **Data Integrity** — SHA-256 checksums on archived objects; periodic integrity scans.
- **Access Control Lists (ACLs)** — Fine-grained per-study, per-patient access where required.
- **Anonymisation / Pseudonymisation** — Built-in DICOM tag stripping profiles for research export.
- **GDPR / HIPAA Awareness** — Configuration guides and tooling to support regulatory compliance workflows.

### Deployment & Operations

- **Single-Binary Distribution** — One executable; no JVM, no container runtime required.
- **Docker & OCI Images** — Official container images for orchestrated deployments.
- **macOS Native** — Runs as a launchd service; optional menu-bar status app.
- **Linux Systemd** — Service unit file included for production Linux deployments.
- **Configuration Profiles** — YAML-based configuration with environment variable overrides.
- **Prometheus Metrics Endpoint** — `/metrics` for integration with Grafana and alerting stacks.
- **Health Check Endpoint** — `/health` for load balancers and orchestrators.
- **Automated Database Migrations** — Schema upgrades handled transparently on server start.

---

## Technology Stack

| Layer | Technology |
|---|---|
| Language | Swift 6.2 (strict concurrency) |
| DICOM Engine | [DICOMKit](https://github.com/Raster-Lab/DICOMKit) |
| Networking | Swift NIO, Async/Await, Actors |
| Image Codecs | J2KSwift, JLSwift, JXLSwift, OpenJP3D |
| HL7 / FHIR | [HL7kit](https://github.com/Raster-Lab/HL7kit) |
| Web Framework | Hummingbird (Swift) |
| Database | SQLite (embedded) / PostgreSQL (scaled) |
| Admin UI | HTML5, CSS3, Vanilla JS (no heavy frameworks) |
| Authentication | LDAP (DICOM Configuration schema) |
| Build System | Swift Package Manager |
| Platforms | macOS (Apple Silicon primary), Linux (x86_64, aarch64) |

---

## Target Audience

- **Radiology Clinics** — Single-site or small multi-site imaging centres.
- **Medium-Sized Hospitals** — Departmental PACS for radiology, cardiology, orthopaedics.
- **Veterinary Practices** — Imaging for companion and large animal medicine.
- **Research & Teaching** — Academic institutions needing a flexible, standards-compliant archive.
- **Teleradiology** — DICOMweb-enabled remote reading workflows.

---

## Getting Started

> **Note:** Mayam Server is currently in the planning and early development phase. Build and installation instructions will be provided as the project progresses through its [milestones](milestones.md).

### Requirements

- **macOS 15+** (Sequoia) with Xcode 16.3+ / Swift 6.2, or
- **Linux** (Ubuntu 24.04 LTS / Fedora 40+) with the Swift 6.2 toolchain.
- 4 GB RAM minimum; 8 GB+ recommended.
- SSD storage recommended for the primary archive.

### Quick Start (Future)

```bash
# Clone and build
git clone https://github.com/Raster-Lab/Mayam-Server.git
cd Mayam-Server
swift build -c release

# Run with guided setup
.build/release/mayam-server --setup
```

---

## Project Structure (Planned)

```
Mayam-Server/
├── Sources/
│   ├── MayamServer/          # Main server entry point
│   ├── MayamCore/            # Core PACS engine, storage, DICOM services
│   ├── MayamWeb/             # DICOMweb & Admin REST API
│   ├── MayamAdmin/           # Web console static assets
│   └── MayamCLI/             # Command-line administration tools
├── Tests/
│   ├── MayamCoreTests/
│   ├── MayamWebTests/
│   └── IntegrationTests/
├── Config/
│   └── mayam.yaml            # Default configuration
├── Docker/
│   └── Dockerfile
├── Package.swift
├── README.md
└── milestones.md
```

---

## Related Projects

| Project | Description |
|---|---|
| [DICOMKit](https://github.com/Raster-Lab/DICOMKit) | Pure Swift DICOM library — parsing, networking, DICOMweb |
| [J2KSwift](https://github.com/Raster-Lab/J2KSwift) | JPEG 2000 codec with HTJ2K and JPIP support |
| [JLSwift](https://github.com/Raster-Lab/JLSwift) | JPEG-LS lossless/near-lossless codec |
| [JXLSwift](https://github.com/Raster-Lab/JXLSwift) | JPEG XL next-generation image codec |
| [OpenJP3D](https://github.com/Raster-Lab/OpenJP3D) | JP3D volumetric image compression |
| [HL7kit](https://github.com/Raster-Lab/HL7kit) | HL7 v2.x, v3, and FHIR R4 framework |

---

## Contributing

Contributions are welcome! Please see the [milestones](milestones.md) for the current development roadmap. Contribution guidelines will be published as the project matures.

---

## Licence

This project is licensed under the terms specified in the repository. See `LICENSE` for details.

---

*Mayam Server is a [Raster-Lab](https://github.com/Raster-Lab) project.*