-- Mayam — PostgreSQL Performance Index Migration
-- Migration: 008_add_performance_indexes
-- Description: Adds composite, covering, and partial indexes optimised for
--              C-FIND on large archives (100K+ studies) and concurrent
--              C-STORE throughput.
--
-- Reference: Milestone 14 — Performance Optimisation & Benchmarking

BEGIN;

-- ============================================================
-- Composite Indexes for C-FIND Query Patterns
-- ============================================================

-- Study-level: Date + Modality + Accession is the most common C-FIND
-- pattern in clinical workflows (worklist-driven retrieval).
CREATE INDEX IF NOT EXISTS idx_studies_date_modality_accession
    ON studies (study_date, modality, accession_number);

-- Study-level: Accession + Patient for RIS-driven lookups.
CREATE INDEX IF NOT EXISTS idx_studies_accession_patient
    ON studies (accession_number, patient_id);

-- Patient-level: Patient ID + Name composite for combined queries.
CREATE INDEX IF NOT EXISTS idx_patients_patient_id_name
    ON patients (patient_id, patient_name);

-- Study-level: Patient ID + Study Date for patient history queries.
CREATE INDEX IF NOT EXISTS idx_studies_patient_date
    ON studies (patient_id, study_date DESC);

-- Series-level: Study + Modality for series-level drill-down queries.
CREATE INDEX IF NOT EXISTS idx_series_study_modality
    ON series (study_id, modality);

-- Instance-level: Series + Instance Number for ordered retrieval.
CREATE INDEX IF NOT EXISTS idx_instances_series_number
    ON instances (series_id, instance_number);

-- ============================================================
-- Covering Indexes for Projection-Only Queries
-- ============================================================

-- Patient-level covering index: avoids table lookup for patient list queries.
CREATE INDEX IF NOT EXISTS idx_patients_covering_list
    ON patients (patient_id, patient_name, date_of_birth, sex);

-- Study-level covering index: avoids table lookup for study list queries.
CREATE INDEX IF NOT EXISTS idx_studies_covering_list
    ON studies (study_instance_uid, study_date, modality, study_description, accession_number);

-- ============================================================
-- Partial Indexes for Active/Recent Data
-- ============================================================

-- Studies from the last 90 days (covers majority of clinical queries).
-- Uses a fixed date for migration safety; a scheduled job should recreate
-- this index periodically with the current date.
CREATE INDEX IF NOT EXISTS idx_studies_recent
    ON studies (study_date DESC, modality)
    WHERE study_date >= '20250101';

-- ============================================================
-- Text Search Indexes for Wildcard Queries
-- ============================================================

-- Patient name trigram index for efficient wildcard searches.
-- Requires pg_trgm extension (installed by default on most PostgreSQL deployments).
-- Gracefully skipped if the extension is not available.
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE INDEX IF NOT EXISTS idx_patients_name_trgm
        ON patients USING gin (patient_name gin_trgm_ops);
    CREATE INDEX IF NOT EXISTS idx_studies_description_trgm
        ON studies USING gin (study_description gin_trgm_ops);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_trgm extension not available — skipping trigram indexes';
END
$$;

-- ============================================================
-- Comments
-- ============================================================

COMMENT ON INDEX idx_studies_date_modality_accession IS
    'Composite index for the most common C-FIND pattern: date + modality + accession.';
COMMENT ON INDEX idx_studies_accession_patient IS
    'Composite index for RIS-driven accession number lookups with patient context.';
COMMENT ON INDEX idx_patients_patient_id_name IS
    'Composite index for combined Patient ID + Name C-FIND queries.';
COMMENT ON INDEX idx_studies_patient_date IS
    'Composite index for patient history timeline queries (newest first).';
COMMENT ON INDEX idx_series_study_modality IS
    'Composite index for series-level drill-down by study and modality.';
COMMENT ON INDEX idx_instances_series_number IS
    'Composite index for ordered instance retrieval within a series.';
COMMENT ON INDEX idx_patients_covering_list IS
    'Covering index to avoid table lookups for patient list C-FIND results.';
COMMENT ON INDEX idx_studies_covering_list IS
    'Covering index to avoid table lookups for study list C-FIND results.';

COMMIT;
