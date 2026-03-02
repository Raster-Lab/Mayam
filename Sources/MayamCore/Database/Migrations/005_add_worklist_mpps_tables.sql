-- Mayam — Migration 005: Worklist, MPPS & Webhook Tables
--
-- Adds tables for Milestone 10 — Worklist, MPPS & Workflow:
--   1. scheduled_procedure_steps — Modality Worklist (MWL) entries served to modalities.
--   2. performed_procedure_steps — MPPS instances received from modalities via N-CREATE/N-SET.
--   3. webhook_subscriptions     — RESTful webhook endpoint registrations.
--   4. webhook_delivery_records  — Audit log of webhook delivery attempts.

BEGIN;

-- 1. Scheduled Procedure Steps (Modality Worklist)
--
-- Each row represents a scheduled imaging procedure available to modalities
-- via the MWL SCP C-FIND service (DICOM PS3.4 Annex K).
CREATE TABLE IF NOT EXISTS scheduled_procedure_steps (
    scheduled_procedure_step_id     TEXT        PRIMARY KEY,
    study_instance_uid              TEXT        NOT NULL,
    accession_number                TEXT        NOT NULL,
    patient_id                      TEXT        NOT NULL,
    patient_name                    TEXT        NOT NULL,
    patient_birth_date              TEXT,
    patient_sex                     TEXT,
    referring_physician_name        TEXT,
    requested_procedure_id          TEXT,
    requested_procedure_description TEXT,
    scheduled_start_date            TEXT        NOT NULL,
    scheduled_start_time            TEXT,
    modality                        TEXT        NOT NULL,
    scheduled_performing_physician  TEXT,
    scheduled_procedure_step_description TEXT,
    scheduled_station_ae_title      TEXT,
    scheduled_station_name          TEXT,
    scheduled_procedure_step_location TEXT,
    status                          TEXT        NOT NULL DEFAULT 'SCHEDULED',
    created_at                      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sps_patient_id
    ON scheduled_procedure_steps (patient_id);

CREATE INDEX IF NOT EXISTS idx_sps_accession_number
    ON scheduled_procedure_steps (accession_number);

CREATE INDEX IF NOT EXISTS idx_sps_scheduled_start_date
    ON scheduled_procedure_steps (scheduled_start_date);

CREATE INDEX IF NOT EXISTS idx_sps_modality
    ON scheduled_procedure_steps (modality);

CREATE INDEX IF NOT EXISTS idx_sps_status
    ON scheduled_procedure_steps (status);

CREATE INDEX IF NOT EXISTS idx_sps_station_ae_title
    ON scheduled_procedure_steps (scheduled_station_ae_title);

-- 2. Performed Procedure Steps (MPPS)
--
-- Each row represents a MPPS instance created by a modality via N-CREATE and
-- updated via N-SET (DICOM PS3.4 Annex F).
CREATE TABLE IF NOT EXISTS performed_procedure_steps (
    sop_instance_uid                        TEXT        PRIMARY KEY,
    status                                  TEXT        NOT NULL DEFAULT 'IN PROGRESS',
    study_instance_uid                      TEXT,
    accession_number                        TEXT,
    patient_id                              TEXT,
    patient_name                            TEXT,
    modality                                TEXT,
    performed_station_ae_title              TEXT,
    performed_station_name                  TEXT,
    performed_start_date                    TEXT,
    performed_start_time                    TEXT,
    performed_end_date                      TEXT,
    performed_end_time                      TEXT,
    performed_procedure_step_description    TEXT,
    performed_procedure_step_id             TEXT,
    scheduled_procedure_step_id             TEXT,
    performed_series_instance_uids          TEXT,   -- JSON array of UIDs
    number_of_instances                     INTEGER     NOT NULL DEFAULT 0,
    created_at                              TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                              TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pps_patient_id
    ON performed_procedure_steps (patient_id);

CREATE INDEX IF NOT EXISTS idx_pps_study_instance_uid
    ON performed_procedure_steps (study_instance_uid);

CREATE INDEX IF NOT EXISTS idx_pps_accession_number
    ON performed_procedure_steps (accession_number);

CREATE INDEX IF NOT EXISTS idx_pps_status
    ON performed_procedure_steps (status);

CREATE INDEX IF NOT EXISTS idx_pps_scheduled_procedure_step_id
    ON performed_procedure_steps (scheduled_procedure_step_id);

-- 3. Webhook Subscriptions
--
-- Each row defines an endpoint that receives RIS lifecycle event notifications
-- (study.received, study.available, etc.) via JSON/HTTPS POST with HMAC-SHA256
-- signatures.
CREATE TABLE IF NOT EXISTS webhook_subscriptions (
    id                  UUID        PRIMARY KEY,
    name                TEXT        NOT NULL,
    url                 TEXT        NOT NULL,
    secret              TEXT        NOT NULL,
    event_types         TEXT        NOT NULL DEFAULT '[]',  -- JSON array of EventType raw values
    enabled             BOOLEAN     NOT NULL DEFAULT TRUE,
    max_retries         INTEGER     NOT NULL DEFAULT 5,
    retry_delay_seconds INTEGER     NOT NULL DEFAULT 10,
    created_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_webhook_subscriptions_enabled
    ON webhook_subscriptions (enabled);

-- 4. Webhook Delivery Records
--
-- Audit log for every webhook delivery attempt. Enables retry tracking and
-- delivery diagnostics in the Admin Console.
CREATE TABLE IF NOT EXISTS webhook_delivery_records (
    id                  UUID        PRIMARY KEY,
    subscription_id     UUID        NOT NULL REFERENCES webhook_subscriptions(id) ON DELETE CASCADE,
    event_id            UUID        NOT NULL,
    http_status_code    INTEGER,
    status              TEXT        NOT NULL DEFAULT 'pending',
    attempt_count       INTEGER     NOT NULL DEFAULT 0,
    next_retry_at       TIMESTAMP,
    last_error          TEXT,
    attempted_at        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_webhook_delivery_subscription
    ON webhook_delivery_records (subscription_id);

CREATE INDEX IF NOT EXISTS idx_webhook_delivery_status
    ON webhook_delivery_records (status);

CREATE INDEX IF NOT EXISTS idx_webhook_delivery_attempted_at
    ON webhook_delivery_records (attempted_at);

COMMIT;
