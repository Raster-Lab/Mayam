-- Mayam — PostgreSQL 18.3 Base Schema Migration
-- Migration: 001_create_base_tables
-- Description: Creates the core Patient, Accession, and Study tables
--              with Delete Protect and Privacy Flag support.

BEGIN;

-- ============================================================
-- Patients
-- ============================================================
CREATE TABLE IF NOT EXISTS patients (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id      TEXT        NOT NULL UNIQUE,
    patient_name    TEXT,
    delete_protect  BOOLEAN     NOT NULL DEFAULT FALSE,
    privacy_flag    BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON COLUMN patients.delete_protect IS 'When TRUE the patient and all child records are protected from deletion until the flag is removed.';
COMMENT ON COLUMN patients.privacy_flag   IS 'When TRUE routing and access to this patient's data is restricted to explicitly authorised users.';

CREATE INDEX idx_patients_delete_protect ON patients (delete_protect) WHERE delete_protect = TRUE;
CREATE INDEX idx_patients_privacy_flag   ON patients (privacy_flag)   WHERE privacy_flag   = TRUE;

-- ============================================================
-- Accessions
-- ============================================================
CREATE TABLE IF NOT EXISTS accessions (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    accession_number  TEXT        NOT NULL UNIQUE,
    patient_id        BIGINT      NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
    delete_protect    BOOLEAN     NOT NULL DEFAULT FALSE,
    privacy_flag      BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON COLUMN accessions.delete_protect IS 'When TRUE the accession and all child studies are protected from deletion until the flag is removed.';
COMMENT ON COLUMN accessions.privacy_flag   IS 'When TRUE routing and access to this accession's data is restricted to explicitly authorised users.';

CREATE INDEX idx_accessions_patient_id      ON accessions (patient_id);
CREATE INDEX idx_accessions_delete_protect  ON accessions (delete_protect) WHERE delete_protect = TRUE;
CREATE INDEX idx_accessions_privacy_flag    ON accessions (privacy_flag)   WHERE privacy_flag   = TRUE;

-- ============================================================
-- Studies
-- ============================================================
CREATE TABLE IF NOT EXISTS studies (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_instance_uid    TEXT        NOT NULL UNIQUE,
    accession_id          BIGINT      REFERENCES accessions(id) ON DELETE RESTRICT,
    patient_id            BIGINT      NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
    study_date            DATE,
    study_description     TEXT,
    modality              TEXT,
    delete_protect        BOOLEAN     NOT NULL DEFAULT FALSE,
    privacy_flag          BOOLEAN     NOT NULL DEFAULT FALSE,
    checksum_sha256       TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON COLUMN studies.delete_protect IS 'When TRUE the study is protected from deletion until the flag is removed.';
COMMENT ON COLUMN studies.privacy_flag   IS 'When TRUE routing and access to this study is restricted to explicitly authorised users.';

CREATE INDEX idx_studies_patient_id      ON studies (patient_id);
CREATE INDEX idx_studies_accession_id    ON studies (accession_id);
CREATE INDEX idx_studies_study_date      ON studies (study_date);
CREATE INDEX idx_studies_delete_protect  ON studies (delete_protect) WHERE delete_protect = TRUE;
CREATE INDEX idx_studies_privacy_flag    ON studies (privacy_flag)   WHERE privacy_flag   = TRUE;

-- ============================================================
-- Audit log for flag changes
-- ============================================================
CREATE TABLE IF NOT EXISTS protection_flag_audit (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_type     TEXT        NOT NULL CHECK (entity_type IN ('patient', 'accession', 'study')),
    entity_id       BIGINT      NOT NULL,
    flag_name       TEXT        NOT NULL CHECK (flag_name IN ('delete_protect', 'privacy_flag')),
    old_value       BOOLEAN     NOT NULL,
    new_value       BOOLEAN     NOT NULL,
    changed_by      TEXT,
    reason          TEXT,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_protection_flag_audit_entity ON protection_flag_audit (entity_type, entity_id);

COMMIT;
