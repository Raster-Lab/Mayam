-- Mayam — PostgreSQL 18.3 Schema Migration
-- Migration: 007_add_metrics_tables
-- Description: Creates tables for operational metrics and migration tracking.

BEGIN;

-- ============================================================
-- Schema Migrations Tracking
-- ============================================================
CREATE TABLE IF NOT EXISTS schema_migrations (
    version     INTEGER     PRIMARY KEY,
    filename    TEXT        NOT NULL,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE schema_migrations IS 'Tracks which database migrations have been applied.';

-- ============================================================
-- Operational Metrics Snapshots
-- ============================================================
CREATE TABLE IF NOT EXISTS metrics_snapshots (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    snapshot_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    active_associations INTEGER     NOT NULL DEFAULT 0,
    total_requests      BIGINT      NOT NULL DEFAULT 0,
    latency_p50         DOUBLE PRECISION NOT NULL DEFAULT 0,
    latency_p90         DOUBLE PRECISION NOT NULL DEFAULT 0,
    latency_p99         DOUBLE PRECISION NOT NULL DEFAULT 0,
    storage_bytes       BIGINT      NOT NULL DEFAULT 0,
    compression_ratio   DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    error_count         BIGINT      NOT NULL DEFAULT 0,
    queue_depth         INTEGER     NOT NULL DEFAULT 0
);

CREATE INDEX idx_metrics_snapshots_at ON metrics_snapshots (snapshot_at);

COMMENT ON TABLE metrics_snapshots IS 'Periodic snapshots of operational metrics for historical trending.';

COMMIT;
