-- Mayam — Migration 004: HSM, Backup, and Integrity Tracking Tables
--
-- Adds tables for:
--   1. study_tier_records — tracks the current storage tier of each study.
--   2. migration_history  — audit log of tier-to-tier migrations.
--   3. backup_targets     — configured backup destinations.
--   4. backup_history     — records of completed backup operations.
--   5. integrity_scans    — results of periodic checksum verification scans.

BEGIN;

-- 1. Study Tier Records
CREATE TABLE IF NOT EXISTS study_tier_records (
    study_instance_uid  TEXT        PRIMARY KEY,
    current_tier        TEXT        NOT NULL DEFAULT 'online',
    current_path        TEXT        NOT NULL,
    last_accessed_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    migrated_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    study_date          TIMESTAMP,
    modality            TEXT
);

CREATE INDEX IF NOT EXISTS idx_study_tier_records_tier
    ON study_tier_records (current_tier);

CREATE INDEX IF NOT EXISTS idx_study_tier_records_last_accessed
    ON study_tier_records (last_accessed_at);

-- 2. Migration History
CREATE TABLE IF NOT EXISTS migration_history (
    id                  SERIAL      PRIMARY KEY,
    study_instance_uid  TEXT        NOT NULL,
    source_tier         TEXT        NOT NULL,
    target_tier         TEXT        NOT NULL,
    migrated_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_migration_history_study
    ON migration_history (study_instance_uid);

-- 3. Backup Targets
CREATE TABLE IF NOT EXISTS backup_targets (
    id                  UUID        PRIMARY KEY,
    name                TEXT        NOT NULL,
    target_type         TEXT        NOT NULL,
    destination_path    TEXT        NOT NULL,
    enabled             BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Backup History
CREATE TABLE IF NOT EXISTS backup_history (
    id                  UUID        PRIMARY KEY,
    target_id           UUID        NOT NULL REFERENCES backup_targets(id),
    started_at          TIMESTAMP   NOT NULL,
    completed_at        TIMESTAMP,
    object_count        INTEGER     NOT NULL DEFAULT 0,
    size_bytes          BIGINT      NOT NULL DEFAULT 0,
    status              TEXT        NOT NULL DEFAULT 'running',
    error_message       TEXT
);

CREATE INDEX IF NOT EXISTS idx_backup_history_target
    ON backup_history (target_id);

CREATE INDEX IF NOT EXISTS idx_backup_history_status
    ON backup_history (status);

-- 5. Integrity Scans
CREATE TABLE IF NOT EXISTS integrity_scans (
    id                  UUID        PRIMARY KEY,
    started_at          TIMESTAMP   NOT NULL,
    completed_at        TIMESTAMP,
    scanned_count       INTEGER     NOT NULL DEFAULT 0,
    valid_count         INTEGER     NOT NULL DEFAULT 0,
    mismatch_count      INTEGER     NOT NULL DEFAULT 0,
    error_count         INTEGER     NOT NULL DEFAULT 0,
    status              TEXT        NOT NULL DEFAULT 'running'
);

COMMIT;
