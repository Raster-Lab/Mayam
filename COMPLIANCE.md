# Mayam — GDPR & HIPAA Compliance Configuration Guide

This guide describes how to configure Mayam for compliance with the **General Data Protection Regulation (GDPR)** and the **Health Insurance Portability and Accountability Act (HIPAA)**.  It covers the security features, configuration options, and operational practices required for compliant deployment.

> **Disclaimer:** This guide provides technical configuration guidance.  It does not constitute legal advice.  Organisations must consult qualified legal and compliance professionals to ensure their specific deployment meets all applicable regulatory requirements.

---

## Table of Contents

1. [Overview](#overview)
2. [GDPR Compliance](#gdpr-compliance)
3. [HIPAA Compliance](#hipaa-compliance)
4. [IHE ATNA — Audit Trail and Node Authentication](#ihe-atna--audit-trail-and-node-authentication)
5. [Encryption and TLS Configuration](#encryption-and-tls-configuration)
6. [Access Control and Authentication](#access-control-and-authentication)
7. [Delete Protection and Privacy Flags](#delete-protection-and-privacy-flags)
8. [Anonymisation and Pseudonymisation](#anonymisation-and-pseudonymisation)
9. [Data Retention and Deletion](#data-retention-and-deletion)
10. [Backup and Recovery](#backup-and-recovery)
11. [Configuration Reference](#configuration-reference)

---

## Overview

Mayam provides the following security features to support GDPR and HIPAA compliance:

| Feature | GDPR Article | HIPAA Rule | Mayam Component |
|---|---|---|---|
| Audit logging | Art. 30 (Records of processing) | §164.312(b) (Audit controls) | IHE ATNA audit trail |
| Encryption in transit | Art. 32 (Security of processing) | §164.312(e)(1) (Transmission security) | TLS 1.3 for all protocols |
| Access control | Art. 25 (Data protection by design) | §164.312(a)(1) (Access control) | RBAC + per-entity ACLs |
| Data minimisation | Art. 5(1)(c) (Data minimisation) | §164.514 (De-identification) | Anonymisation profiles |
| Right to erasure | Art. 17 (Right to erasure) | N/A | Delete protection with audit |
| Data portability | Art. 20 (Right to data portability) | N/A | DICOM export, DICOMweb |
| Integrity | Art. 5(1)(f) (Integrity) | §164.312(c)(1) (Integrity) | SHA-256 checksums, HMAC audit |
| Breach notification | Art. 33–34 (Breach notification) | §164.408 (Notification) | Security alert audit events |

---

## GDPR Compliance

### Article 25 — Data Protection by Design and by Default

Enable privacy flag enforcement and access control to restrict access to sensitive patient data by default:

```yaml
security:
  privacyFlagEnabled: true
  aclEnabled: true
  deleteProtectionEnabled: true
```

### Article 17 — Right to Erasure

Mayam supports controlled deletion with full audit trails.  Delete protection flags prevent accidental or unauthorised deletion of patient data:

1. An authorised administrator removes the delete protection flag (audit-logged).
2. The deletion proceeds and is recorded as an ATNA audit event.
3. All audit records of the deletion are retained indefinitely.

### Article 30 — Records of Processing Activities

Enable ATNA audit trail to record all data processing activities:

```yaml
security:
  atnaEnabled: true
  atnaHMACSecret: "<strong-random-secret>"
  syslog:
    enabled: true
    host: "syslog.example.com"
    port: 6514
    transport: tls
```

### Article 32 — Security of Processing

Enable TLS 1.3 for all network communication:

```yaml
dicom:
  tlsEnabled: true
  tlsCertificatePath: "/etc/mayam/certs/server.pem"
  tlsKeyPath: "/etc/mayam/certs/server.key"

web:
  tlsEnabled: true
  tlsCertificatePath: "/etc/mayam/certs/server.pem"
  tlsKeyPath: "/etc/mayam/certs/server.key"

admin:
  tlsEnabled: true
  tlsCertificatePath: "/etc/mayam/certs/server.pem"
  tlsKeyPath: "/etc/mayam/certs/server.key"
```

---

## HIPAA Compliance

### §164.312(a)(1) — Access Control

Configure RBAC with LDAP integration and per-entity ACLs:

```yaml
ldap:
  enabled: true
  host: "ldap.example.com"
  port: 636
  useTLS: true
  baseDN: "dc=example,dc=com"
  schema:
    adminGroupDN: "cn=pacs-admins,ou=groups,dc=example,dc=com"
    techGroupDN: "cn=pacs-techs,ou=groups,dc=example,dc=com"
    physicianGroupDN: "cn=physicians,ou=groups,dc=example,dc=com"

security:
  aclEnabled: true
```

### §164.312(b) — Audit Controls

Enable comprehensive audit logging with tamper-evident storage:

```yaml
security:
  atnaEnabled: true
  atnaHMACSecret: "<strong-random-secret>"
```

### §164.312(c)(1) — Integrity

Enable SHA-256 checksums for all stored DICOM objects:

```yaml
storage:
  checksumEnabled: true
```

### §164.312(e)(1) — Transmission Security

Enable TLS 1.3 for all network protocols (DICOM, DICOMweb, Admin, MLLP):

```yaml
dicom:
  tlsEnabled: true

web:
  tlsEnabled: true

admin:
  tlsEnabled: true

hl7:
  mllpTLSEnabled: true
```

---

## IHE ATNA — Audit Trail and Node Authentication

Mayam implements the IHE ATNA profile with:

- **Structured audit messages** conforming to RFC 3881 / DICOM Audit Message XML.
- **Tamper-evident local storage** with HMAC-SHA256 integrity hashing.
- **Syslog export** via TLS-secured TCP (RFC 5425), plain TCP (RFC 6587), or UDP (RFC 5426).

### Audited Events

| Event | Code | Description |
|---|---|---|
| Application Activity | 110100 | Server start/stop |
| Audit Log Used | 110101 | Audit log accessed |
| DICOM Instances Accessed | 110103 | Study/series/instance viewed |
| DICOM Instances Transferred | 110104 | C-STORE, C-MOVE, C-GET |
| DICOM Study Deleted | 110105 | Study permanently removed |
| Export | 110106 | Data exported (anonymised or otherwise) |
| Import | 110107 | Data imported |
| Order Record | 110109 | Order/accession modified |
| Patient Record | 110110 | Patient demographics changed |
| Query | 110112 | C-FIND, QIDO-RS query executed |
| Security Alert | 110113 | Unauthorised access attempt |
| User Authentication | 110114 | Login/logout event |

### Configuration

```yaml
security:
  atnaEnabled: true
  atnaHMACSecret: "<change-this-in-production>"
  syslog:
    enabled: true
    host: "syslog.example.com"
    port: 6514
    transport: tls       # Options: udp, tcp, tls
    facility: 10         # security/authorization (default)
    appName: "mayam"
```

---

## Encryption and TLS Configuration

All Mayam network interfaces support TLS 1.3:

| Interface | Port (default) | TLS Config Key |
|---|---|---|
| DICOM SCP | 11112 | `dicom.tlsEnabled` |
| DICOMweb | 8080 | `web.tlsEnabled` |
| Admin Console | 8081 | `admin.tlsEnabled` |
| HL7 MLLP | 2575 | `hl7.mllpTLSEnabled` |
| Syslog Export | 6514 | `security.syslog.transport: tls` |

### Certificate Requirements

- Use certificates signed by a trusted Certificate Authority (CA).
- Minimum key length: RSA 2048-bit or ECDSA P-256.
- Certificate and key files must be in PEM format.
- Rotate certificates before expiry.

---

## Access Control and Authentication

### Role-Based Access Control (RBAC)

| Role | Permissions |
|---|---|
| Administrator | Full system access |
| Technologist | Node management, study routing, limited settings |
| Physician | Query/retrieve, DICOMweb access, read-only admin |
| Auditor | Log access and compliance reporting |

### Per-Entity ACLs

When the Privacy Flag is set on a patient or study, access is restricted to users and roles explicitly listed in the entity's access control list.  Evaluation rules:

1. **Deny** entries always take precedence.
2. **Allow** entries grant access for the specified user or role.
3. If no entry matches, access is **denied** (default-deny).
4. **Administrators** are always exempt.

---

## Delete Protection and Privacy Flags

### Delete Protection

When the `deleteProtect` flag is set on a Patient, Accession, or Study:

- All deletion requests are rejected with a descriptive error.
- The flag must be explicitly removed by an authorised administrator.
- All flag changes are recorded in the `protection_flag_audit` table.

### Privacy Flag

When the `privacyFlag` is set on a Patient or Study:

- **C-FIND / QIDO-RS**: Flagged entities are suppressed from query results.
- **C-MOVE / C-GET / WADO-RS**: Retrieve requests are rejected.
- **Routing rules**: Flagged entities are excluded from automatic routing.
- **Override**: Administrators and explicitly authorised users may access flagged entities.

---

## Anonymisation and Pseudonymisation

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

### Configuration

```yaml
security:
  anonymisationEnabled: true
```

---

## Data Retention and Deletion

- Configure retention policies via the storage policy matrix.
- Near-line and offline tiers support minimum retention periods.
- Legal-hold studies are protected from deletion via the delete protection flag.
- All deletions are audit-logged with operator identity and reason.

---

## Backup and Recovery

- Enable encrypted backups to secure locations.
- Support for local, network (SMB/NFS), and cloud (S3-compatible) targets.
- Point-in-time recovery for the metadata database.
- Periodic integrity scans verify SHA-256 checksums.

```yaml
backup:
  enabled: true
  targets:
    - type: local
      path: "/backup/mayam"
  schedule:
    frequency: daily
    time: "02:00"
```

---

## Configuration Reference

Complete `security` section of `mayam.yaml`:

```yaml
security:
  # IHE ATNA audit trail
  atnaEnabled: false                          # Enable ATNA audit logging
  atnaHMACSecret: "change-me-in-production"   # HMAC secret for tamper detection

  # Syslog export
  syslog:
    enabled: false
    host: "localhost"
    port: 6514
    transport: tls        # udp | tcp | tls
    facility: 10
    appName: "mayam"

  # Anonymisation
  anonymisationEnabled: false

  # Access control
  aclEnabled: false

  # Protection flags (enabled by default)
  deleteProtectionEnabled: true
  privacyFlagEnabled: true
```

---

*For additional guidance, consult the DICOM Conformance Statement and the IHE Integration Statements published with each Mayam release.*
