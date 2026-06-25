-- ============================================================
-- Schema: IoT / Time-Series
-- Domain: Device telemetry with partitioned readings
-- Source: database-architect SKILL.md §20.4
-- Usage: psql -U postgres -d yourdb -f iot.sql
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS timescaledb;  -- optional, for better TS performance

-- Device registry
CREATE TABLE devices (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL,
    device_type TEXT NOT NULL,
    firmware    TEXT,
    location    JSONB DEFAULT '{}',
    metadata    JSONB DEFAULT '{}',
    is_active   BOOLEAN NOT NULL DEFAULT true,
    last_seen   TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE devices IS 'Registered IoT devices';

-- Device configuration (current state per device)
CREATE TABLE device_state (
    device_id   BIGINT NOT NULL PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    config      JSONB DEFAULT '{}',
    status      TEXT DEFAULT 'online' CHECK (status IN ('online', 'offline', 'error')),
    last_reading_at TIMESTAMPTZ,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE device_state IS 'Current state of each device (1 row per device)';

-- Time-series readings (partitioned by month)
CREATE TABLE readings (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    device_id   BIGINT NOT NULL,
    ts          TIMESTAMPTZ NOT NULL,
    metric      TEXT NOT NULL,
    value       DOUBLE PRECISION NOT NULL,
    metadata    JSONB DEFAULT '{}',
    PRIMARY KEY (id, ts)
) PARTITION BY RANGE (ts);
COMMENT ON TABLE readings IS 'Time-series sensor readings (partitioned)';

-- Create monthly partitions (extend as needed)
CREATE TABLE readings_2026_06 PARTITION OF readings
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE readings_2026_07 PARTITION OF readings
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE readings_2026_08 PARTITION OF readings
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE readings_2026_09 PARTITION OF readings
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE readings_2026_10 PARTITION OF readings
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE readings_2026_11 PARTITION OF readings
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE readings_2026_12 PARTITION OF readings
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Events (discrete alerts, state changes)
CREATE TABLE events (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    device_id   BIGINT NOT NULL REFERENCES devices(id),
    event_type  TEXT NOT NULL,
    severity    TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    message     TEXT NOT NULL,
    details     JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE events IS 'Discrete device events and alerts';

-- Indexes
CREATE INDEX idx_devices_type ON devices (device_type);
CREATE INDEX idx_devices_active ON devices (is_active) WHERE is_active = true;
CREATE INDEX idx_readings_device_ts ON readings (device_id, ts DESC);
CREATE INDEX idx_readings_metric ON readings (device_id, metric, ts DESC);
CREATE INDEX idx_events_device ON events (device_id, created_at DESC);
CREATE INDEX idx_events_severity ON events (severity) WHERE severity IN ('error', 'critical');

-- Partition maintenance function
CREATE OR REPLACE FUNCTION create_readings_partition()
RETURNS void AS $$
DECLARE
    next_month TEXT;
    start_date TEXT;
    end_date TEXT;
BEGIN
    next_month := to_char(now() + INTERVAL '2 months', 'YYYY_MM');
    start_date := to_char(now() + INTERVAL '2 months', 'YYYY-MM-01');
    end_date := to_char(now() + INTERVAL '3 months', 'YYYY-MM-01');
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS readings_%s PARTITION OF readings
         FOR VALUES FROM (%L) TO (%L)',
        next_month, start_date, end_date
    );
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION create_readings_partition() IS 'Call monthly via pg_cron to auto-create partitions';
