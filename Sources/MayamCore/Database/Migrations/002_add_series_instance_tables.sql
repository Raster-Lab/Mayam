-- Mayam — PostgreSQL 18.3 Schema Migration
-- Migration: 002_add_series_instance_tables
-- Description: Adds Series and Instance tables to support the C-STORE
--              storage service (Milestone 3).  Each Instance records the
--              stored transfer syntax and SHA-256 checksum to enable
--              serve-as-stored semantics and integrity verification.

BEGIN;

-- ============================================================
-- Series
-- ============================================================
CREATE TABLE IF NOT EXISTS series (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    series_instance_uid   TEXT        NOT NULL UNIQUE,
    study_id              BIGINT      NOT NULL REFERENCES studies(id) ON DELETE RESTRICT,
    series_number         INT,
    modality              TEXT,
    series_description    TEXT,
    instance_count        INT         NOT NULL DEFAULT 0,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  series                    IS 'DICOM series within a study.';
COMMENT ON COLUMN series.series_instance_uid IS 'DICOM Series Instance UID (0020,000E).';
COMMENT ON COLUMN series.instance_count      IS 'Cached count of SOP instances in this series; updated on each C-STORE.';

CREATE INDEX idx_series_study_id          ON series (study_id);
CREATE INDEX idx_series_modality          ON series (modality);

-- ============================================================
-- Instances
-- ============================================================
CREATE TABLE IF NOT EXISTS instances (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sop_instance_uid      TEXT        NOT NULL UNIQUE,
    sop_class_uid         TEXT        NOT NULL,
    series_id             BIGINT      NOT NULL REFERENCES series(id) ON DELETE RESTRICT,
    instance_number       INT,
    -- Transfer syntax UID as stored; enables serve-as-stored semantics.
    transfer_syntax_uid   TEXT        NOT NULL,
    checksum_sha256       TEXT,
    file_size_bytes       BIGINT      NOT NULL DEFAULT 0,
    -- Path relative to the archive root (e.g. PATIENT/STUDY/SERIES/SOP.dcm)
    file_path             TEXT        NOT NULL,
    calling_ae_title      TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  instances                   IS 'Individual DICOM SOP instances (files) within a series.';
COMMENT ON COLUMN instances.transfer_syntax_uid IS 'Transfer syntax in which the object is stored (store-as-received).';
COMMENT ON COLUMN instances.checksum_sha256     IS 'Hex-encoded SHA-256 integrity checksum of the stored file.';
COMMENT ON COLUMN instances.file_path           IS 'Relative path within the archive root directory.';

CREATE INDEX idx_instances_series_id      ON instances (series_id);
CREATE INDEX idx_instances_sop_class_uid  ON instances (sop_class_uid);

COMMIT;
