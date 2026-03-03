-- Mayam — Migration 006: Security Hardening & IHE Compliance Tables
--
-- Adds tables for Milestone 12 — Security Hardening & IHE Compliance:
--   1. atna_audit_events        — IHE ATNA structured audit event log.
--   2. access_control_entries    — Per-entity ACLs for privacy-flagged data.
--   3. anonymisation_jobs        — Tracks anonymisation/pseudonymisation export jobs.
--   4. ihe_integration_statements — IHE profile conformance declarations.

BEGIN;

-- 1. ATNA Audit Events
--
-- Each row represents a structured audit event conforming to the IHE ATNA
-- profile (RFC 3881 / DICOM Audit Message XML).  Events include an
-- HMAC-SHA256 integrity hash for tamper detection.
CREATE TABLE IF NOT EXISTS atna_audit_events (
    id                          UUID        PRIMARY KEY,
    event_id                    TEXT        NOT NULL,
    event_outcome               INTEGER     NOT NULL DEFAULT 0,
    event_date_time             TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_action_description    TEXT,
    active_participants         TEXT        NOT NULL DEFAULT '[]',   -- JSON array
    participant_objects          TEXT        NOT NULL DEFAULT '[]',   -- JSON array
    audit_source_id             TEXT        NOT NULL DEFAULT 'MAYAM',
    integrity_hash              TEXT,
    created_at                  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_atna_event_id
    ON atna_audit_events (event_id);

CREATE INDEX IF NOT EXISTS idx_atna_event_date_time
    ON atna_audit_events (event_date_time);

CREATE INDEX IF NOT EXISTS idx_atna_audit_source_id
    ON atna_audit_events (audit_source_id);

CREATE INDEX IF NOT EXISTS idx_atna_event_outcome
    ON atna_audit_events (event_outcome);

-- 2. Access Control Entries
--
-- Per-entity ACLs evaluated when the Privacy Flag is set on a patient or
-- study.  Each entry grants or denies a specific user or role access to the
-- protected entity.
CREATE TABLE IF NOT EXISTS access_control_entries (
    id                  BIGSERIAL   PRIMARY KEY,
    entity_type         TEXT        NOT NULL,
    entity_id           BIGINT      NOT NULL,
    principal_type      TEXT        NOT NULL,
    principal_id        TEXT        NOT NULL,
    permission          TEXT        NOT NULL DEFAULT 'allow',
    created_by          TEXT,
    created_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ace_entity
    ON access_control_entries (entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_ace_principal
    ON access_control_entries (principal_type, principal_id);

CREATE INDEX IF NOT EXISTS idx_ace_permission
    ON access_control_entries (permission);

-- 3. Anonymisation Jobs
--
-- Tracks anonymisation/pseudonymisation export jobs for research data export
-- per DICOM PS3.15 Annex E.
CREATE TABLE IF NOT EXISTS anonymisation_jobs (
    id                  UUID        PRIMARY KEY,
    profile             TEXT        NOT NULL DEFAULT 'basic',
    status              TEXT        NOT NULL DEFAULT 'pending',
    study_instance_uid  TEXT        NOT NULL,
    patient_id          TEXT        NOT NULL,
    requested_by        TEXT,
    attributes_processed INTEGER    NOT NULL DEFAULT 0,
    attributes_modified  INTEGER    NOT NULL DEFAULT 0,
    started_at          TIMESTAMP,
    completed_at        TIMESTAMP,
    created_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_anon_jobs_status
    ON anonymisation_jobs (status);

CREATE INDEX IF NOT EXISTS idx_anon_jobs_study
    ON anonymisation_jobs (study_instance_uid);

CREATE INDEX IF NOT EXISTS idx_anon_jobs_patient
    ON anonymisation_jobs (patient_id);

-- 4. IHE Integration Statements
--
-- Records the IHE profiles, actors, and options that Mayam declares
-- conformance to.
CREATE TABLE IF NOT EXISTS ihe_integration_statements (
    id                  UUID        PRIMARY KEY,
    profile             TEXT        NOT NULL,
    actors              TEXT        NOT NULL DEFAULT '[]',   -- JSON array
    options             TEXT        NOT NULL DEFAULT '[]',   -- JSON array
    framework_version   TEXT        NOT NULL,
    statement_date      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes               TEXT,
    created_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ihe_profile
    ON ihe_integration_statements (profile);

COMMIT;
