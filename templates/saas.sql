-- ============================================================
-- Schema: Multi-Tenant SaaS
-- Domain: SaaS platform with tenant isolation
-- Source: database-architect SKILL.md §20.1
-- Usage: psql -U postgres -d yourdb -f saas.sql
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Enums
CREATE TYPE user_role AS ENUM ('admin', 'member', 'viewer');
CREATE TYPE tenant_plan AS ENUM ('free', 'pro', 'enterprise');

-- Tenants (top-level isolation boundary)
CREATE TABLE tenants (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug        TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    plan        tenant_plan NOT NULL DEFAULT 'free',
    settings    JSONB DEFAULT '{}' NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE tenants IS 'Organization-level isolation boundary';

-- Users (login across tenants or per-tenant)
CREATE TABLE users (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id    BIGINT NOT NULL REFERENCES tenants(id),
    email        TEXT NOT NULL,
    name         TEXT NOT NULL,
    avatar_url   TEXT,
    role         user_role NOT NULL DEFAULT 'member',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tenant_id, email)
);
COMMENT ON TABLE users IS 'Users scoped to a tenant';

-- Feature flags per tenant
CREATE TABLE tenant_features (
    tenant_id   BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    feature     TEXT NOT NULL,
    enabled     BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, feature)
);
COMMENT ON TABLE tenant_features IS 'Per-tenant feature toggles';

-- Audit log (all tenants)
CREATE TABLE audit_log (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id   BIGINT NOT NULL REFERENCES tenants(id),
    user_id     BIGINT REFERENCES users(id),
    action      TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id   BIGINT,
    details     JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE audit_log IS 'Immutable audit trail for all tenant changes';

-- Indexes
CREATE INDEX idx_users_tenant ON users (tenant_id);
CREATE INDEX idx_audit_log_tenant ON audit_log (tenant_id);
CREATE INDEX idx_audit_log_created ON audit_log (tenant_id, created_at DESC);
CREATE INDEX idx_tenants_slug ON tenants (slug);

-- Row-Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY users_tenant_isolation ON users
    USING (tenant_id = current_setting('app.tenant_id')::BIGINT);

CREATE POLICY features_tenant_isolation ON tenant_features
    USING (tenant_id = current_setting('app.tenant_id')::BIGINT);

CREATE POLICY audit_tenant_isolation ON audit_log
    USING (tenant_id = current_setting('app.tenant_id')::BIGINT);
