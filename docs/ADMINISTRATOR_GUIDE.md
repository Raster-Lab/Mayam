<!-- SPDX-License-Identifier: (see LICENSE) -->

# Mayam PACS — Administrator Guide

| | |
|---|---|
| **Product** | Mayam PACS |
| **Version** | 1.0.0 |
| **Document Version** | 1.0.0 |
| **Date** | 2025-07 |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Requirements](#2-system-requirements)
3. [Installation](#3-installation)
4. [Configuration](#4-configuration)
5. [Database Setup](#5-database-setup)
6. [LDAP / Active Directory Integration](#6-ldap--active-directory-integration)
7. [User Management](#7-user-management)
8. [Storage Management](#8-storage-management)
9. [Backup & Recovery](#9-backup--recovery)
10. [Security](#10-security)
11. [Monitoring & Operations](#11-monitoring--operations)
12. [Modality Worklist & Workflow](#12-modality-worklist--workflow)
13. [DICOMweb Configuration](#13-dicomweb-configuration)
14. [FHIR R4 Integration](#14-fhir-r4-integration)
15. [CLI Tools](#15-cli-tools)
16. [Upgrading](#16-upgrading)
17. [Troubleshooting](#17-troubleshooting)

---

## 1. Introduction

### 1.1 Overview

Mayam is a modern, departmental-level **Picture Archiving and Communication System (PACS)** built entirely in Swift 6.2 with strict concurrency. It is designed for radiology clinics, medium-sized hospitals, and veterinary practices. Mayam follows the **DICOM Standard 2026a** (XML edition) and provides a comprehensive set of DICOM services, DICOMweb APIs, and a web-based administration console.

Key capabilities include:

- **Core DICOM services** — C-STORE, C-FIND, C-MOVE, C-GET, C-ECHO, Storage Commitment, MWL, MPPS, IAN, and Print Management.
- **DICOMweb** — WADO-RS, QIDO-RS, STOW-RS, UPS-RS, and WADO-URI.
- **Intelligent storage** — Store-as-received, serve-as-stored, hierarchical storage management (HSM), and compressed copy management.
- **Healthcare interoperability** — HL7 v2.x messaging (MLLP) and FHIR R4 resources.
- **Security and compliance** — TLS 1.3, LDAP/Active Directory authentication, RBAC, IHE ATNA audit trail, delete protection, and privacy flags.
- **Single-binary deployment** — No JVM, no heavy runtime dependencies.

### 1.2 Intended Audience

This guide is intended for **system administrators**, **IT engineers**, and **PACS administrators** responsible for installing, configuring, and maintaining a Mayam deployment. Familiarity with DICOM networking concepts, command-line administration, and basic database management is assumed.

### 1.3 Document Conventions

| Convention | Meaning |
|---|---|
| `monospace` | Commands, file paths, configuration keys, and code snippets. |
| **Bold** | Important terms, UI element names, and warnings. |
| `<placeholder>` | A value you must replace with your own. |
| `#` prefix in YAML | Comment; the line is ignored by the configuration parser. |
| `$` prefix | Shell prompt; do not type the `$` character. |

> **Note:** This guide uses British English throughout, consistent with the Mayam project conventions.

---

## 2. System Requirements

### 2.1 Supported Platforms

| Platform | Architecture | Minimum OS Version |
|---|---|---|
| macOS | Apple Silicon (arm64) | macOS 14 Sonoma |
| Linux | x86_64, aarch64 | Ubuntu 22.04 LTS / Fedora 40+ |

### 2.2 Hardware Requirements

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 4 cores | 8+ cores |
| RAM | 8 GB | 16+ GB |
| Storage (OS + application) | 20 GB SSD | 50 GB SSD |
| Storage (DICOM archive) | Depends on volume | SSD for online tier; NAS/object storage for near-line |
| Network | 1 Gbps | 10 Gbps for high-volume sites |

> **Recommendation:** Use SSD or NVMe storage for the primary online archive. Mechanical discs are suitable only for near-line and offline tiers.

### 2.3 Software Dependencies

| Component | Version | Notes |
|---|---|---|
| Swift runtime | 6.2 | Bundled in release binaries; required only when building from source. |
| PostgreSQL | 18.3 | Primary metadata database for production deployments. |
| SQLite | 3.x | Lightweight fallback for single-user or embedded deployments. |
| OpenSSL / LibreSSL | 3.x | Required on Linux for TLS support. |

### 2.4 Network Ports

| Service | Default Port | Protocol | Description |
|---|---|---|---|
| DICOM SCP | 11112 | TCP | DICOM association listener |
| DICOMweb | 8080 | HTTP/HTTPS | WADO-RS, QIDO-RS, STOW-RS, UPS-RS |
| Admin Console | 8081 | HTTP/HTTPS | Web-based administration UI and REST API |
| HL7 MLLP | 2575 | TCP | HL7 v2.x messaging (optional) |
| PostgreSQL | 5432 | TCP | Database (when using Docker Compose) |

---

## 3. Installation

### 3.1 macOS

#### 3.1.1 DMG / PKG Installer

Download the latest `.dmg` disk image from the [Releases](https://github.com/Raster-Lab/Mayam/releases) page. Open the disk image and run the `.pkg` installer. All dependencies, including LDAP libraries, are bundled within the package.

```bash
$ open Mayam-1.0.0.dmg
# Follow the on-screen instructions in the installer.
```

The installer places the `mayam` binary in `/usr/local/bin/` and the default configuration in `/etc/mayam/mayam.yaml`.

#### 3.1.2 Homebrew

```bash
$ brew install raster-lab/tap/mayam
```

After installation, start the service:

```bash
$ brew services start mayam
```

#### 3.1.3 Building from Source

Ensure Xcode 16.3+ (or the Swift 6.2 toolchain) is installed, then:

```bash
$ git clone https://github.com/Raster-Lab/Mayam.git
$ cd Mayam
$ swift build -c release
```

The release binary is located at `.build/release/mayam`. Copy it to a location on your `$PATH`:

```bash
$ sudo cp .build/release/mayam /usr/local/bin/
$ sudo cp .build/release/mayam-cli /usr/local/bin/
$ sudo mkdir -p /etc/mayam
$ sudo cp Config/mayam.yaml /etc/mayam/mayam.yaml
```

### 3.2 Linux

#### 3.2.1 APT (Debian / Ubuntu)

```bash
$ sudo apt update
$ sudo apt install mayam
```

#### 3.2.2 RPM (RHEL / Fedora)

```bash
$ sudo dnf install mayam
```

#### 3.2.3 Building from Source

Install the Swift 6.2 toolchain for Linux from [swift.org](https://www.swift.org/install/), then:

```bash
$ git clone https://github.com/Raster-Lab/Mayam.git
$ cd Mayam
$ swift build -c release --static-swift-stdlib
```

Install the binary and create the service user:

```bash
$ sudo cp .build/release/mayam /usr/local/bin/
$ sudo cp .build/release/mayam-cli /usr/local/bin/
$ sudo groupadd -r mayam
$ sudo useradd -r -g mayam -d /var/lib/mayam -s /bin/false mayam
$ sudo mkdir -p /etc/mayam /var/lib/mayam/archive /var/log/mayam
$ sudo cp Config/mayam.yaml /etc/mayam/mayam.yaml
$ sudo chown -R mayam:mayam /var/lib/mayam /var/log/mayam
```

Install the systemd service unit:

```bash
$ sudo cp Config/mayam.service /etc/systemd/system/
$ sudo systemctl daemon-reload
$ sudo systemctl enable mayam
$ sudo systemctl start mayam
```

### 3.3 Docker

#### 3.3.1 Container Image

Pull the official multi-architecture image:

```bash
$ docker pull ghcr.io/raster-lab/mayam:1.0.0
```

Run the container:

```bash
$ docker run -d \
    --name mayam \
    -p 11112:11112 \
    -p 8080:8080 \
    -p 8081:8081 \
    -v mayam_archive:/var/lib/mayam/archive \
    -e MAYAM_LOG_LEVEL=info \
    -e MAYAM_ADMIN_JWT_SECRET="<your-secret>" \
    ghcr.io/raster-lab/mayam:1.0.0
```

#### 3.3.2 Docker Compose

The repository includes a `docker-compose.yml` for a full-stack deployment with PostgreSQL and optional monitoring:

```bash
# Start Mayam + PostgreSQL
$ docker compose up -d

# Start with Prometheus + Grafana monitoring
$ docker compose --profile monitoring up -d

# View logs
$ docker compose logs -f mayam
```

Build multi-architecture images locally:

```bash
$ docker buildx build --platform linux/amd64,linux/arm64 -t mayam:latest .
```

The Docker Compose stack provisions the following services:

| Service | Image | Purpose |
|---|---|---|
| `postgres` | `postgres:18` | Metadata database with health checks |
| `mayam` | Built from `Dockerfile` | PACS server (depends on healthy `postgres`) |
| `prometheus` | `prom/prometheus:latest` | Metrics collection (monitoring profile) |
| `grafana` | `grafana/grafana:latest` | Dashboard visualisation (monitoring profile) |

Persistent volumes:

| Volume | Mount Point | Purpose |
|---|---|---|
| `postgres_data` | `/var/lib/postgresql/data` | Database files |
| `archive_data` | `/var/lib/mayam/archive` | DICOM archive |
| `prometheus_data` | `/prometheus` | Metrics history |
| `grafana_data` | `/var/lib/grafana` | Dashboard state |

---

## 4. Configuration

### 4.1 Configuration Hierarchy

Mayam uses a layered configuration system. Each layer overrides the previous:

1. **Built-in defaults** — Sensible defaults compiled into the binary.
2. **YAML configuration file** — Located at the path specified by the `MAYAM_CONFIG` environment variable, or `Config/mayam.yaml` relative to the working directory.
3. **Environment variable overrides** — Individual settings overridden via environment variables prefixed with `MAYAM_`.

### 4.2 Configuration File Location

The default configuration file path is `Config/mayam.yaml`. Override it with:

```bash
$ export MAYAM_CONFIG=/etc/mayam/mayam.yaml
```

In Docker and systemd deployments, this variable is set automatically (see [§3](#3-installation)).

### 4.3 Full Configuration Reference

Below is the complete reference for all configuration sections. Values shown are the built-in defaults unless otherwise noted.

#### 4.3.1 DICOM

```yaml
dicom:
  aeTitle: "MAYAM"                                  # Application Entity Title (max 16 characters)
  port: 11112                                       # TCP port for DICOM associations
  maxAssociations: 64                               # Maximum concurrent DICOM associations
  tlsEnabled: false                                 # Enable TLS 1.3 for DICOM associations
  tlsCertificatePath: "/etc/mayam/certs/server.pem" # Path to TLS certificate (PEM)
  tlsKeyPath: "/etc/mayam/certs/server-key.pem"     # Path to TLS private key (PEM)
```

#### 4.3.2 Storage

```yaml
storage:
  archivePath: "/var/lib/mayam/archive"  # Root directory for the DICOM archive
  checksumEnabled: true                  # Compute SHA-256 checksums on ingest
```

#### 4.3.3 Log

```yaml
log:
  level: "info"   # Minimum log severity: trace, debug, info, notice, warning, error, critical
```

#### 4.3.4 Web (DICOMweb)

```yaml
web:
  port: 8080                                        # TCP port for DICOMweb HTTP(S)
  tlsEnabled: false                                 # Enable TLS for DICOMweb
  tlsCertificatePath: "/etc/mayam/certs/server.pem"
  tlsKeyPath: "/etc/mayam/certs/server-key.pem"
  basePath: "/dicomweb"                             # URL base path for DICOMweb services
```

#### 4.3.5 Admin Console

```yaml
admin:
  port: 8081                          # TCP port for the Admin Console
  jwtSecret: "change-me-in-prod"      # Secret for signing JWT tokens — MUST be changed in production
  sessionExpirySeconds: 3600          # JWT session lifetime (seconds)
  setupCompleted: false               # Set to true after the Setup Wizard is completed
  tlsEnabled: false                   # Enable TLS for the Admin Console
  tlsCertificatePath: ""              # Path to TLS certificate (PEM)
  tlsKeyPath: ""                      # Path to TLS private key (PEM)
```

> **⚠ Warning:** The default `jwtSecret` value **must** be replaced with a strong, random secret before exposing the Admin Console to any network.

#### 4.3.6 LDAP

```yaml
ldap:
  enabled: false                                            # Enable LDAP authentication
  host: "ldap.example.com"                                  # LDAP server hostname or IP
  port: 636                                                 # LDAP server port (636 for LDAPS)
  useTLS: true                                              # Use TLS (LDAPS)
  baseDN: "dc=example,dc=com"                               # Base Distinguished Name for searches
  bindDN: "cn=readonly,dc=example,dc=com"                   # Bind DN for service account
  bindPassword: ""                                          # Bind password (use env var in production)
  userSearchFilter: "(uid={username})"                      # Search filter; {username} is replaced at runtime
  groupSearchFilter: "(member={userDN})"                    # Group membership filter
  schema:
    adminGroupDN: "cn=pacs-admins,ou=groups,dc=example,dc=com"
    operatorGroupDN: "cn=pacs-operators,ou=groups,dc=example,dc=com"
    viewerGroupDN: "cn=pacs-viewers,ou=groups,dc=example,dc=com"
```

#### 4.3.7 HSM (Hierarchical Storage Management)

```yaml
hsm:
  enabled: false
  tiers:
    - name: "online"
      path: "/var/lib/mayam/archive"
      type: "ssd"
    - name: "nearline"
      path: "/mnt/nas/mayam"
      type: "nas"
    - name: "archive"
      path: "s3://mayam-archive"
      type: "s3"
  migrationRules:
    - from: "online"
      to: "nearline"
      afterDays: 90               # Migrate studies older than 90 days
      triggerOnLastAccess: true    # Use last-access date rather than study date
    - from: "nearline"
      to: "archive"
      afterDays: 365
```

#### 4.3.8 Backup

```yaml
backup:
  enabled: false
  targets:
    - type: local                           # Local file system
      path: "/backup/mayam"
    - type: smb                             # Network share (SMB/CIFS)
      path: "//nas.example.com/backup"
      username: "backup-user"
      password: ""                          # Use env var MAYAM_BACKUP_SMB_PASSWORD
    - type: nfs                             # Network share (NFS)
      path: "nas.example.com:/export/backup"
    - type: s3                              # S3-compatible object storage
      endpoint: "https://s3.amazonaws.com"
      bucket: "mayam-backup"
      region: "eu-west-1"
      accessKeyId: ""                       # Use env var MAYAM_BACKUP_S3_ACCESS_KEY
      secretAccessKey: ""                   # Use env var MAYAM_BACKUP_S3_SECRET_KEY
  schedule:
    frequency: daily                        # daily, weekly, monthly
    time: "02:00"                           # 24-hour format, server local time
    retainCount: 30                         # Number of backups to retain
```

#### 4.3.9 HL7

```yaml
hl7:
  mllpEnabled: false          # Enable HL7 v2.x MLLP listener
  mllpPort: 2575              # MLLP TCP port
  mllpTLSEnabled: false       # Enable TLS for MLLP connections
  fhirEnabled: false          # Enable FHIR R4 resource endpoints
```

#### 4.3.10 Security

```yaml
security:
  # IHE ATNA audit trail
  atnaEnabled: false                          # Enable ATNA audit logging
  atnaHMACSecret: "change-me-in-production"   # HMAC-SHA256 secret for tamper detection

  # Syslog export
  syslog:
    enabled: false
    host: "localhost"
    port: 6514
    transport: tls        # udp | tcp | tls
    facility: 10          # security/authorisation
    appName: "mayam"

  # Access control
  aclEnabled: false                       # Enable per-entity access control lists
  deleteProtectionEnabled: true           # Prevent deletion of protected entities
  privacyFlagEnabled: true                # Restrict access to flagged entities

  # Anonymisation
  anonymisationEnabled: false             # Enable DICOM PS3.15 Annex E anonymisation
```

#### 4.3.11 Codec (Transcoding)

```yaml
codec:
  onDemandTranscoding: true               # Transcode on the fly when a client lacks support
  backgroundTranscodingConcurrency: 4     # Number of concurrent background transcoding workers
```

### 4.4 Environment Variable Overrides

Any configuration value may be overridden with an environment variable. The naming convention is:

```
MAYAM_<SECTION>_<KEY>
```

All letters are upper-case and periods or camelCase boundaries are replaced with underscores.

| Environment Variable | Configuration Key | Default |
|---|---|---|
| `MAYAM_CONFIG` | *(config file path)* | `Config/mayam.yaml` |
| `MAYAM_DICOM_AE_TITLE` | `dicom.aeTitle` | `MAYAM` |
| `MAYAM_DICOM_PORT` | `dicom.port` | `11112` |
| `MAYAM_DICOM_MAX_ASSOCIATIONS` | `dicom.maxAssociations` | `64` |
| `MAYAM_DICOM_TLS_ENABLED` | `dicom.tlsEnabled` | `false` |
| `MAYAM_DICOM_TLS_CERTIFICATE_PATH` | `dicom.tlsCertificatePath` | — |
| `MAYAM_DICOM_TLS_KEY_PATH` | `dicom.tlsKeyPath` | — |
| `MAYAM_STORAGE_ARCHIVE_PATH` | `storage.archivePath` | `/var/lib/mayam/archive` |
| `MAYAM_STORAGE_CHECKSUM_ENABLED` | `storage.checksumEnabled` | `true` |
| `MAYAM_LOG_LEVEL` | `log.level` | `info` |
| `MAYAM_WEB_PORT` | `web.port` | `8080` |
| `MAYAM_WEB_TLS_ENABLED` | `web.tlsEnabled` | `false` |
| `MAYAM_WEB_BASE_PATH` | `web.basePath` | `/dicomweb` |
| `MAYAM_ADMIN_PORT` | `admin.port` | `8081` |
| `MAYAM_ADMIN_JWT_SECRET` | `admin.jwtSecret` | `change-me-in-prod` |
| `MAYAM_ADMIN_SESSION_EXPIRY_SECONDS` | `admin.sessionExpirySeconds` | `3600` |
| `MAYAM_ADMIN_TLS_ENABLED` | `admin.tlsEnabled` | `false` |
| `MAYAM_HL7_MLLP_ENABLED` | `hl7.mllpEnabled` | `false` |
| `MAYAM_HL7_MLLP_PORT` | `hl7.mllpPort` | `2575` |
| `MAYAM_HL7_FHIR_ENABLED` | `hl7.fhirEnabled` | `false` |

---

## 5. Database Setup

### 5.1 PostgreSQL 18.3 (Production)

PostgreSQL 18.3 is the recommended database for all production deployments.

#### 5.1.1 Creating the Database

```bash
$ sudo -u postgres createuser --createdb mayam
$ sudo -u postgres createdb -O mayam mayam
```

Set a secure password:

```sql
ALTER USER mayam WITH ENCRYPTED PASSWORD '<strong-password>';
```

Configure the connection in `mayam.yaml` or via environment variables:

```yaml
database:
  driver: postgresql
  host: "localhost"
  port: 5432
  name: "mayam"
  user: "mayam"
  password: ""           # Use MAYAM_DATABASE_PASSWORD env var in production
  sslMode: "require"     # disable | require | verify-ca | verify-full
```

#### 5.1.2 Automatic Migrations

Mayam runs database migrations automatically on startup. Migration files are stored in `Sources/MayamCore/Database/Migrations/` as sequentially numbered SQL files (e.g., `001_initial_schema.sql`, `002_add_series_table.sql`). Each migration runs inside a transaction (`BEGIN` / `COMMIT`).

No manual intervention is required for schema upgrades — simply deploy the new binary and restart the service.

### 5.2 SQLite (Lightweight Deployments)

For single-user or embedded deployments where PostgreSQL is not available:

```yaml
database:
  driver: sqlite
  path: "/var/lib/mayam/mayam.db"
```

> **Note:** SQLite does not support concurrent write access. It is not recommended for multi-user or high-volume environments.

### 5.3 Backup Recommendations

- Schedule daily PostgreSQL backups using `pg_dump`:

  ```bash
  $ pg_dump -U mayam -h localhost -F custom -f /backup/mayam_$(date +%Y%m%d).dump mayam
  ```

- Enable WAL archiving for point-in-time recovery in critical deployments.
- Store backups on a separate volume or off-site location.
- Test restore procedures regularly.

---

## 6. LDAP / Active Directory Integration

### 6.1 Enabling LDAP Authentication

Set `ldap.enabled: true` in `mayam.yaml` and configure the connection parameters. When LDAP is enabled, local password authentication is bypassed for all non-admin accounts; the built-in `admin` account always retains local authentication as a recovery mechanism.

### 6.2 OpenLDAP Configuration Example

```yaml
ldap:
  enabled: true
  host: "ldap.hospital.nhs.uk"
  port: 636
  useTLS: true
  baseDN: "dc=hospital,dc=nhs,dc=uk"
  bindDN: "cn=mayam-svc,ou=service-accounts,dc=hospital,dc=nhs,dc=uk"
  bindPassword: ""    # Set MAYAM_LDAP_BIND_PASSWORD env var
  userSearchFilter: "(uid={username})"
  groupSearchFilter: "(member={userDN})"
  schema:
    adminGroupDN: "cn=pacs-admins,ou=groups,dc=hospital,dc=nhs,dc=uk"
    operatorGroupDN: "cn=pacs-operators,ou=groups,dc=hospital,dc=nhs,dc=uk"
    viewerGroupDN: "cn=pacs-viewers,ou=groups,dc=hospital,dc=nhs,dc=uk"
```

### 6.3 Active Directory Configuration Example

```yaml
ldap:
  enabled: true
  host: "ad.hospital.example.com"
  port: 636
  useTLS: true
  baseDN: "dc=hospital,dc=example,dc=com"
  bindDN: "cn=mayam-svc,ou=Service Accounts,dc=hospital,dc=example,dc=com"
  bindPassword: ""    # Set MAYAM_LDAP_BIND_PASSWORD env var
  userSearchFilter: "(sAMAccountName={username})"
  groupSearchFilter: "(member={userDN})"
  schema:
    adminGroupDN: "cn=PACS Admins,ou=Groups,dc=hospital,dc=example,dc=com"
    operatorGroupDN: "cn=PACS Operators,ou=Groups,dc=hospital,dc=example,dc=com"
    viewerGroupDN: "cn=PACS Viewers,ou=Groups,dc=hospital,dc=example,dc=com"
```

### 6.4 Group-to-Role Mapping

| LDAP Group DN | Mayam Role | Description |
|---|---|---|
| `adminGroupDN` | Administrator | Full system access |
| `operatorGroupDN` | Operator | Node management, study routing, storage operations |
| `viewerGroupDN` | Viewer | Read-only access to studies and worklists |

Users who do not match any configured group are denied access.

### 6.5 Testing LDAP Connectivity

Use the Admin API to test LDAP connectivity without restarting the server:

```bash
$ curl -X POST http://localhost:8081/admin/api/ldap/test \
    -H "Authorization: Bearer <jwt-token>" \
    -H "Content-Type: application/json" \
    -d '{
      "host": "ldap.hospital.nhs.uk",
      "port": 636,
      "useTLS": true,
      "bindDN": "cn=mayam-svc,ou=service-accounts,dc=hospital,dc=nhs,dc=uk",
      "bindPassword": "<password>",
      "baseDN": "dc=hospital,dc=nhs,dc=uk",
      "testUsername": "jdoe"
    }'
```

A successful response returns `200 OK` with the resolved user attributes and group memberships.

---

## 7. User Management

### 7.1 Default Admin Account

On first startup, Mayam creates a built-in administrator account:

| Field | Value |
|---|---|
| Username | `admin` |
| Password | `admin` |

> **⚠ Warning:** Change the default admin password **immediately** after first login. Navigate to the Admin Console at `http://localhost:8081/admin/` and use the Settings page, or update the credentials via the Admin API.

### 7.2 Creating Users via the Admin API

```bash
$ curl -X POST http://localhost:8081/admin/api/users \
    -H "Authorization: Bearer <jwt-token>" \
    -H "Content-Type: application/json" \
    -d '{
      "username": "jsmith",
      "password": "<secure-password>",
      "role": "operator",
      "fullName": "Jane Smith",
      "email": "jsmith@hospital.example.com"
    }'
```

### 7.3 Role-Based Access Control (RBAC)

Mayam defines the following roles:

| Role | Description |
|---|---|
| Administrator | Full system access; can manage users, settings, and all resources. |
| Operator | Manages DICOM nodes, storage pools, study routing; limited settings access. |
| Viewer | Read-only access to studies, worklists, and MPPS; can use DICOMweb. |
| Auditor | Access to audit logs and compliance reports; no clinical data modification. |

### 7.4 Permissions

Each role is composed of granular permissions:

| Permission | admin | operator | viewer | auditor |
|---|---|---|---|---|
| `manageUsers` | ✓ | | | |
| `manageLDAP` | ✓ | | | |
| `manageNodes` | ✓ | ✓ | | |
| `manageStorage` | ✓ | ✓ | | |
| `viewLogs` | ✓ | ✓ | | ✓ |
| `manageSettings` | ✓ | | | |
| `viewStudies` | ✓ | ✓ | ✓ | |
| `manageWorklist` | ✓ | ✓ | | |
| `exportData` | ✓ | ✓ | | |
| `viewAuditTrail` | ✓ | | | ✓ |

---

## 8. Storage Management

### 8.1 Archive Directory Structure

Mayam organises DICOM objects on disc in a hierarchical structure:

```
/var/lib/mayam/archive/
└── <PatientID>/
    └── <StudyInstanceUID>/
        └── <SeriesInstanceUID>/
            ├── <SOPInstanceUID>.dcm          # Original representation
            └── <SOPInstanceUID>.j2k.dcm      # Compressed copy (if configured)
```

### 8.2 Storage Policies and the Representation Model

Mayam manages multiple derivative representations of each study, presented to end users as a single logical item. Configurable rules govern data handling at each lifecycle stage:

| Stage | Applicable Policies |
|---|---|
| **Ingest** | Store-as-received; optional compressed-copy creation; duplicate detection; SHA-256 checksums; study-level ZIP/TAR+Zstd packaging; per-modality codec selection. |
| **Online** | Serve-as-stored; on-demand transcoding for unsupported clients; QoS priority for STAT studies. |
| **Near-Line** | Policy-driven migration triggers (age, last-access, modality, study status); archive packaging format (ZIP / TAR+Zstd); retention rules. |
| **Offline** | Tape / cold object-storage tier; minimum retention periods; delete protection enforcement for legal-hold studies. |
| **Rehydrate** | On-demand recall to the online tier; prefetch hints from query patterns; automatic cache eviction after a configurable TTL. |

The representation model supports per-modality, per-site, and per-tele-radiology-destination configurations:

| Dimension | Description |
|---|---|
| **Per Modality** | Default archive codec per modality type (e.g., JPEG-LS for CR/DX, JPEG 2000 for CT/MR). |
| **Per Site** | Site-level storage profiles defining which representations to create and retain. |
| **Per Destination** | Destination-specific compressed copies for tele-radiology; bandwidth-aware codec selection. |
| **Derivative Limit** | Maximum number of representations per study (e.g., original + 2 compressed copies). |

### 8.3 Compressed Copy Management

Mayam leverages native Swift codecs for high-performance image compression:

| Codec | Transfer Syntax | Typical Use |
|---|---|---|
| JPEG 2000 | Lossless & lossy; HTJ2K mode | CT, MR, general purpose |
| JPEG-LS | Lossless / near-lossless | CR, DX, fast lossless archival |
| JPEG XL | Progressive decode; HDR | Next-generation archival |
| JP3D | 3D volumetric compression | CT/MR volume stacks |

Configure compressed copy creation in the storage policy section of your configuration, or manage it via the Admin Console under **Compression Policies**.

### 8.4 Hierarchical Storage Management (HSM)

HSM automates the movement of studies between storage tiers based on configurable rules (see [§4.3.7](#437-hsm-hierarchical-storage-management)). Typical tier configurations:

| Tier | Storage Type | Access Time | Cost |
|---|---|---|---|
| Online | Local SSD / NVMe | Milliseconds | Highest |
| Near-Line | NAS / external drives | Seconds | Medium |
| Archive | S3-compatible / tape | Minutes | Lowest |

Studies are recalled to the online tier on demand when a retrieve request is received for data residing on a lower tier.

### 8.5 Integrity Scanning

When `storage.checksumEnabled` is set to `true`, Mayam computes a SHA-256 checksum for every stored DICOM object. Periodic integrity scans verify that stored data matches the recorded checksums. Configure scan frequency and alerting via the Admin Console or the Admin API.

---

## 9. Backup & Recovery

### 9.1 Backup Targets

Mayam supports the following backup destinations:

| Target Type | Description |
|---|---|
| `local` | Local file system path. |
| `smb` | Network share via SMB/CIFS. |
| `nfs` | Network share via NFS. |
| `s3` | S3-compatible object storage (AWS S3, MinIO, etc.). |

See [§4.3.8](#438-backup) for the full configuration reference.

### 9.2 Scheduling Backups

Configure automated backups in `mayam.yaml`:

```yaml
backup:
  enabled: true
  targets:
    - type: local
      path: "/backup/mayam"
  schedule:
    frequency: daily
    time: "02:00"
    retainCount: 30
```

Supported frequencies: `daily`, `weekly`, `monthly`.

### 9.3 Point-in-Time Recovery

For PostgreSQL deployments, combine Mayam's application-level backups with PostgreSQL WAL archiving for point-in-time recovery:

1. Enable WAL archiving in `postgresql.conf`:

   ```ini
   archive_mode = on
   archive_command = 'cp %p /backup/wal/%f'
   ```

2. Use `pg_basebackup` for the initial base backup.
3. Restore to any point in time using `pg_restore` with the WAL archives.

### 9.4 Storage Commitment (DICOM)

Mayam supports the DICOM Storage Commitment SOP Class (N-ACTION / N-EVENT-REPORT). When a modality requests storage commitment, Mayam verifies the integrity of each stored instance before issuing a positive commitment response. This provides end-to-end confirmation that studies have been reliably archived.

---

## 10. Security

### 10.1 TLS 1.3 Configuration

All Mayam network interfaces support TLS 1.3. Enable TLS independently for each interface:

```yaml
dicom:
  tlsEnabled: true
  tlsCertificatePath: "/etc/mayam/certs/server.pem"
  tlsKeyPath: "/etc/mayam/certs/server-key.pem"

web:
  tlsEnabled: true
  tlsCertificatePath: "/etc/mayam/certs/server.pem"
  tlsKeyPath: "/etc/mayam/certs/server-key.pem"

admin:
  tlsEnabled: true
  tlsCertificatePath: "/etc/mayam/certs/server.pem"
  tlsKeyPath: "/etc/mayam/certs/server-key.pem"

hl7:
  mllpTLSEnabled: true
```

### 10.2 Certificate and Key File Setup

Certificate requirements:

- PEM-encoded X.509 certificate and private key.
- Minimum key length: RSA 2048-bit or ECDSA P-256.
- The certificate should include the server hostname in the Subject Alternative Name (SAN).
- Rotate certificates before expiry.

Generate a self-signed certificate for testing:

```bash
$ openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -keyout /etc/mayam/certs/server-key.pem \
    -out /etc/mayam/certs/server.pem \
    -days 365 -nodes \
    -subj "/CN=mayam.hospital.example.com"
```

> **Production:** Use certificates issued by a trusted Certificate Authority (CA). Self-signed certificates are suitable only for testing.

### 10.3 ATNA Audit Trail Logging

Mayam implements the IHE Audit Trail and Node Authentication (ATNA) profile with structured audit messages conforming to RFC 3881 / DICOM Audit Message XML.

Enable ATNA and syslog export:

```yaml
security:
  atnaEnabled: true
  atnaHMACSecret: "<strong-random-secret>"
  syslog:
    enabled: true
    host: "syslog.hospital.example.com"
    port: 6514
    transport: tls
```

Audited events:

| Event | Code | Description |
|---|---|---|
| Application Activity | 110100 | Server start/stop |
| Audit Log Used | 110101 | Audit log accessed |
| DICOM Instances Accessed | 110103 | Study/series/instance viewed |
| DICOM Instances Transferred | 110104 | C-STORE, C-MOVE, C-GET |
| DICOM Study Deleted | 110105 | Study permanently removed |
| Export | 110106 | Data exported |
| Import | 110107 | Data imported |
| Order Record | 110109 | Order/accession modified |
| Patient Record | 110110 | Patient demographics changed |
| Query | 110112 | C-FIND, QIDO-RS query executed |
| Security Alert | 110113 | Unauthorised access attempt |
| User Authentication | 110114 | Login/logout event |

HMAC-SHA256 integrity hashing ensures audit records cannot be tampered with without detection.

### 10.4 Delete Protection and Privacy Flags

**Delete Protection:** When the `deleteProtect` flag is set on a Patient, Accession, or Study, all deletion requests are rejected. The flag must be explicitly removed by an authorised administrator. All flag changes are recorded in the `protection_flag_audit` table.

**Privacy Flag:** When the `privacyFlag` is set on a Patient or Study:

- **C-FIND / QIDO-RS:** Flagged entities are suppressed from query results.
- **C-MOVE / C-GET / WADO-RS:** Retrieve requests are rejected.
- **Routing rules:** Flagged entities are excluded from automatic routing.
- **Override:** Administrators and explicitly authorised users may access flagged entities.

### 10.5 DICOM Anonymisation

Mayam supports DICOM PS3.15 Annex E anonymisation profiles for research data export:

| Profile | Description |
|---|---|
| Basic Profile | Removes or replaces all identifying attributes |
| Retain Safe Private | Keeps reviewed-safe private attributes |
| Retain UIDs | Preserves original UIDs for referential integrity |
| Retain Device Identity | Keeps station names and serial numbers |
| Retain Patient Characteristics | Keeps age, sex, size, weight |
| Retain Long Full Dates | Preserves all date/time attributes |
| Clean Descriptors | Removes free-text descriptions |

Enable anonymisation:

```yaml
security:
  anonymisationEnabled: true
```

### 10.6 IHE ATNA Profile Compliance

Mayam publishes IHE Integration Statements for the following profiles:

- Scheduled Workflow (SWF)
- Patient Information Reconciliation (PIR)
- Consistent Presentation of Images (CPI)
- Key Image Note (KIN)
- Import Reconciliation Workflow (IRWF)
- Cross-Enterprise Document Sharing for Imaging (XDS-I.b)
- Audit Trail and Node Authentication (ATNA)

For the full DICOM Conformance Statement, see [`docs/CONFORMANCE_STATEMENT.md`](CONFORMANCE_STATEMENT.md). For GDPR and HIPAA compliance guidance, see [`COMPLIANCE.md`](../COMPLIANCE.md).

---

## 11. Monitoring & Operations

### 11.1 Prometheus Metrics Endpoint

Mayam exposes a Prometheus-compatible metrics endpoint on the DICOMweb port:

```bash
$ curl http://localhost:8080/metrics
```

Exported metrics include:

| Metric | Description |
|---|---|
| `mayam_associations_active` | Currently active DICOM associations |
| `mayam_requests_per_second` | Request throughput |
| `mayam_latency_percentiles` | Response latency percentiles |
| `mayam_storage_utilization_bytes` | Archive storage usage in bytes |
| `mayam_compression_ratio` | Average compression ratio across stored objects |
| `mayam_backup_status` | Last backup status and timestamp |
| `mayam_error_rate` | Error rate across all services |

### 11.2 Health Check Endpoint

```bash
$ curl http://localhost:8080/health
```

Returns `200 OK` with a JSON body indicating server status. Use this endpoint with load balancers, container orchestrators, and uptime monitors.

### 11.3 Grafana Dashboard Setup

1. Start Grafana as part of the Docker Compose monitoring profile:

   ```bash
   $ docker compose --profile monitoring up -d
   ```

2. Open Grafana at `http://localhost:3000` (default credentials: `admin` / `admin`).
3. Add Prometheus as a data source (`http://prometheus:9090`).
4. Import the bundled dashboard from `Config/grafana-dashboard.json`.

The dashboard visualises storage utilisation, association metrics, throughput, latency percentiles, and error rates.

### 11.4 systemd Service Management (Linux)

The included systemd unit file (`Config/mayam.service`) provides:

- Automatic restart on failure (up to 3 attempts per 60 seconds).
- Graceful shutdown with `SIGTERM`, followed by `SIGKILL` after 30 seconds.
- Security hardening: `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp=true`.
- Resource limits: `LimitNOFILE=65535`, `LimitNPROC=4096`.

Common commands:

```bash
# Start the service
$ sudo systemctl start mayam

# Stop the service (graceful shutdown)
$ sudo systemctl stop mayam

# Restart the service
$ sudo systemctl restart mayam

# Check service status
$ sudo systemctl status mayam

# View logs
$ sudo journalctl -u mayam -f
```

### 11.5 launchd Management (macOS)

The included launchd plist (`Config/com.raster-lab.mayam.plist`) provides:

- Automatic start at boot (`RunAtLoad`).
- Automatic restart on non-zero exit (`KeepAlive.SuccessfulExit = false`).
- Resource limits: `NumberOfFiles=65535`, `NumberOfProcesses=4096`.

Install and manage the service:

```bash
# Install the plist
$ sudo cp Config/com.raster-lab.mayam.plist /Library/LaunchDaemons/

# Load (start) the service
$ sudo launchctl load /Library/LaunchDaemons/com.raster-lab.mayam.plist

# Unload (stop) the service
$ sudo launchctl unload /Library/LaunchDaemons/com.raster-lab.mayam.plist

# View logs
$ tail -f /var/log/mayam/mayam.log
$ tail -f /var/log/mayam/mayam-error.log
```

### 11.6 Log Levels and Filtering

Mayam supports the following log levels, in order of increasing severity:

| Level | Description |
|---|---|
| `trace` | Extremely detailed diagnostic output (e.g., PDU byte dumps). |
| `debug` | Detailed diagnostic information for developers. |
| `info` | Routine operational messages (association events, storage operations). |
| `notice` | Normal but noteworthy conditions. |
| `warning` | Conditions that may indicate a problem (e.g., nearing storage capacity). |
| `error` | Errors that prevent an individual operation from completing. |
| `critical` | Severe errors that may cause the server to stop. |

Set the log level in configuration or via the `MAYAM_LOG_LEVEL` environment variable:

```bash
$ export MAYAM_LOG_LEVEL=debug
```

### 11.7 Graceful Shutdown Behaviour

When Mayam receives `SIGTERM`:

1. **New associations are refused** — the DICOM listener stops accepting new connections.
2. **In-progress associations complete** — active C-STORE, C-MOVE, and other operations are allowed to finish.
3. **Pending writes are flushed** — all queued storage operations are completed.
4. **Database connections close cleanly** — active transactions are committed or rolled back.
5. **The process exits** — once all operations have completed or the timeout (30 seconds by default) is reached.

---

## 12. Modality Worklist & Workflow

### 12.1 MWL SCP Configuration

Mayam provides a Modality Worklist (MWL) SCP that modalities query to receive scheduled procedure step information. MWL entries are managed via the Admin Console or the Admin API:

```bash
# Create a scheduled procedure step
$ curl -X POST http://localhost:8081/admin/api/worklist \
    -H "Authorization: Bearer <jwt-token>" \
    -H "Content-Type: application/json" \
    -d '{
      "patientID": "PAT001",
      "patientName": "DOE^JOHN",
      "accessionNumber": "ACC20250701",
      "scheduledAETitle": "CT_SCANNER_1",
      "modality": "CT",
      "scheduledDateTime": "2025-07-15T09:00:00Z",
      "procedureDescription": "CT Abdomen with Contrast"
    }'
```

Modalities query the MWL SCP using standard DICOM C-FIND at the MAYAM AE Title.

### 12.2 MPPS Handling

Mayam acts as an MPPS SCP, accepting N-CREATE and N-SET messages from modalities to track procedure progress. MPPS instances are read-only in the Admin Console and accessible via:

```bash
$ curl http://localhost:8081/admin/api/mpps \
    -H "Authorization: Bearer <jwt-token>"
```

### 12.3 Instance Availability Notification

Mayam publishes study lifecycle events via both DICOM Instance Availability Notification (IAN) and equivalent RESTful webhooks. The following events are available:

| Event | Trigger |
|---|---|
| `study.received` | First instance of a new study stored |
| `study.updated` | Additional instances arrive for an existing study |
| `study.complete` | Study completeness criteria met |
| `study.available` | Study available for retrieval |
| `study.routed` | Study forwarded to a destination node |
| `study.archived` | Study migrated to near-line/offline tier |
| `study.rehydrated` | Study recalled to online tier |
| `study.deleted` | Study permanently removed |
| `study.error` | Error during processing |

### 12.4 RIS Event Webhooks

Register webhook subscriptions via the Admin API:

```bash
$ curl -X POST http://localhost:8081/admin/api/webhooks \
    -H "Authorization: Bearer <jwt-token>" \
    -H "Content-Type: application/json" \
    -d '{
      "url": "https://ris.hospital.example.com/pacs-events",
      "events": ["study.available", "study.complete"],
      "secret": "<hmac-shared-secret>"
    }'
```

Webhook payloads are delivered as JSON over HTTPS POST with HMAC-SHA256 signature verification. Delivery retries use exponential back-off.

### 12.5 HL7 v2.x Integration

Enable the MLLP listener to receive and send HL7 v2.x messages:

```yaml
hl7:
  mllpEnabled: true
  mllpPort: 2575
```

Supported message types:

| Message Type | Direction | Description |
|---|---|---|
| ORM (Order) | Inbound | Receive orders from RIS for worklist population |
| ORU (Observation Result) | Outbound | Send study results to downstream systems |
| ADT (Admit/Discharge/Transfer) | Inbound | Receive patient demographic updates |
| ACK (Acknowledgement) | Both | Message acknowledgement |

HL7 v2.x messaging is powered by [HL7kit](https://github.com/Raster-Lab/HL7kit).

---

## 13. DICOMweb Configuration

### 13.1 Service Overview

Mayam provides the following DICOMweb services:

| Service | Description |
|---|---|
| **WADO-RS** | RESTful retrieval of DICOM objects, metadata, and rendered frames. |
| **QIDO-RS** | RESTful query across patients, studies, series, and instances. |
| **STOW-RS** | RESTful storage of DICOM objects via HTTP multipart. |
| **UPS-RS** | Unified Procedure Step management over REST. |
| **WADO-URI** | Legacy single-frame retrieval (backwards compatibility). |

### 13.2 Port and TLS Configuration

```yaml
web:
  port: 8080
  tlsEnabled: true
  tlsCertificatePath: "/etc/mayam/certs/server.pem"
  tlsKeyPath: "/etc/mayam/certs/server-key.pem"
```

### 13.3 Base Path Configuration

The `basePath` setting controls the URL prefix for all DICOMweb endpoints:

```yaml
web:
  basePath: "/dicomweb"
```

With this setting, the QIDO-RS studies endpoint is available at:

```
https://mayam.hospital.example.com:8080/dicomweb/studies
```

---

## 14. FHIR R4 Integration

### 14.1 Supported Resources

When FHIR is enabled, Mayam exposes the following FHIR R4 resources:

| Resource | Description |
|---|---|
| `Patient` | Patient demographics synchronised with the DICOM patient model. |
| `ImagingStudy` | FHIR representation of DICOM studies with series and instance references. |
| `DiagnosticReport` | Reporting resource linked to imaging studies. |
| `Endpoint` | FHIR endpoint discovery for DICOMweb service URLs. |

### 14.2 REST API Endpoints

FHIR resources are served under the `/fhir` base path on the DICOMweb port:

```
GET  https://mayam.hospital.example.com:8080/fhir/Patient/<id>
GET  https://mayam.hospital.example.com:8080/fhir/ImagingStudy?patient=<id>
GET  https://mayam.hospital.example.com:8080/fhir/DiagnosticReport?study=<uid>
GET  https://mayam.hospital.example.com:8080/fhir/Endpoint
```

### 14.3 Enabling / Disabling FHIR

```yaml
hl7:
  fhirEnabled: true
```

Or via environment variable:

```bash
$ export MAYAM_HL7_FHIR_ENABLED=true
```

FHIR R4 functionality is powered by [HL7kit](https://github.com/Raster-Lab/HL7kit).

---

## 15. CLI Tools

Mayam includes a command-line interface (`mayam-cli`) for administrative tasks.

### 15.1 Configuration Validation

Validate a configuration file without starting the server:

```bash
$ mayam-cli config validate /etc/mayam/mayam.yaml
```

If the configuration is valid, the command exits with status `0` and prints a confirmation message. If there are errors, they are printed to standard error with details of the invalid key or value.

Example:

```bash
$ mayam-cli config validate Config/mayam.yaml
✓ Configuration is valid.
  AE Title:     MAYAM
  DICOM Port:   11112
  Archive Path: /var/lib/mayam/archive
  Log Level:    info
```

### 15.2 Additional Commands

The following commands are planned for future releases:

| Command | Description |
|---|---|
| `mayam-cli status` | Display the running server status, uptime, and association statistics. |
| `mayam-cli echo --host <host> --port <port> --ae <ae-title>` | Send a DICOM C-ECHO to verify connectivity with a remote node. |

---

## 16. Upgrading

### 16.1 Before You Upgrade

1. **Back up the database:**

   ```bash
   $ pg_dump -U mayam -h localhost -F custom -f /backup/mayam_pre_upgrade.dump mayam
   ```

2. **Back up the configuration file:**

   ```bash
   $ cp /etc/mayam/mayam.yaml /etc/mayam/mayam.yaml.bak
   ```

3. **Back up the archive** (or ensure recent backups are available).

4. **Review the release notes** for any breaking changes or new required configuration keys.

### 16.2 Database Migration Compatibility

Mayam applies database migrations automatically on startup. Migrations are forward-only — they cannot be rolled back automatically. Always take a database backup before upgrading.

If a migration fails, the server will not start and will log the error. Restore the database backup, resolve the issue, and retry.

### 16.3 Configuration File Compatibility

New configuration keys are introduced with sensible defaults. Existing configuration files will continue to work without modification unless a release explicitly deprecates a key. Deprecated keys trigger a warning in the server log.

Use `mayam-cli config validate` to check your configuration against a new version before starting the server.

### 16.4 Rolling Upgrade Considerations

Mayam is designed as a single-instance server for departmental deployments. If you run multiple instances behind a load balancer:

1. Stop one instance at a time.
2. Upgrade the binary.
3. Start the upgraded instance and verify it is healthy.
4. Proceed with the next instance.

Ensure all instances are upgraded before any new database migration is applied (the first instance to start will run migrations).

---

## 17. Troubleshooting

### 17.1 Common Issues

| Symptom | Likely Cause | Resolution |
|---|---|---|
| Server fails to start | Invalid configuration | Run `mayam-cli config validate /etc/mayam/mayam.yaml` and fix reported errors. |
| `Address already in use` | Port conflict | Check for other processes using ports 11112, 8080, or 8081 with `ss -tlnp` (Linux) or `lsof -i :<port>` (macOS). |
| Modality cannot connect | Firewall or AE Title mismatch | Ensure the firewall allows TCP traffic on port 11112. Verify the AE Title matches on both sides. |
| Admin Console inaccessible | Wrong port or TLS misconfiguration | Check `admin.port` and `admin.tlsEnabled` settings. If TLS is enabled, use `https://`. |
| Studies not appearing in queries | Privacy flag or ACL restriction | Check whether the study has the privacy flag set. Verify the querying user has appropriate permissions. |
| High memory usage | Too many concurrent associations | Reduce `dicom.maxAssociations` or increase available memory. |
| Database connection refused | PostgreSQL not running or misconfigured | Verify PostgreSQL is running: `pg_isready -U mayam`. Check connection parameters in the config. |

### 17.2 Log Analysis

Check the server logs for diagnostic information:

```bash
# systemd (Linux)
$ sudo journalctl -u mayam -f --no-pager

# launchd (macOS)
$ tail -f /var/log/mayam/mayam.log

# Docker
$ docker compose logs -f mayam
```

Increase the log level temporarily for detailed diagnostics:

```bash
$ export MAYAM_LOG_LEVEL=debug
$ sudo systemctl restart mayam
```

> **Remember** to revert the log level to `info` after diagnosing the issue to avoid excessive log volume.

### 17.3 Network Connectivity Testing (C-ECHO)

Use a DICOM verification (C-ECHO) to test connectivity between Mayam and a remote node:

```bash
# From the CLI (planned)
$ mayam-cli echo --host 192.168.1.100 --port 11112 --ae REMOTE_AE

# From the Admin Console
# Navigate to DICOM Nodes → select the node → click "Verify (C-ECHO)"
```

A successful C-ECHO confirms:

- TCP connectivity between the two hosts.
- The remote AE Title is correct.
- The remote node is accepting DICOM associations.

### 17.4 Database Connection Issues

**PostgreSQL not reachable:**

```bash
$ pg_isready -h localhost -U mayam
# Expected: localhost:5432 - accepting connections
```

**Authentication failure:**

```bash
$ psql -h localhost -U mayam -d mayam -c "SELECT 1;"
# If this fails, check pg_hba.conf and the user's password.
```

**Migration failure on startup:**

Check the server log for the specific migration file and SQL error. Common causes include:

- Schema conflicts from manual database modifications.
- Insufficient database user privileges (ensure the `mayam` user owns the database).

---

*For the DICOM Conformance Statement, see [`docs/CONFORMANCE_STATEMENT.md`](CONFORMANCE_STATEMENT.md).*
*For GDPR and HIPAA compliance guidance, see [`COMPLIANCE.md`](../COMPLIANCE.md).*
*For the project README and development instructions, see [`README.md`](../README.md).*

---

*Mayam is a [Raster-Lab](https://github.com/Raster-Lab) project.*
