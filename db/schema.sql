-- Masar Startup initial relational schema (PostgreSQL + pgvector).
-- Do not seed this database with invented, published funding opportunities.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS users (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), email TEXT NOT NULL UNIQUE, display_name TEXT NOT NULL,
 preferred_language TEXT NOT NULL DEFAULT 'ar' CHECK (preferred_language IN ('ar','en')),
 role TEXT NOT NULL DEFAULT 'founder' CHECK (role IN ('founder','reviewer','admin')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS startup_profiles (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 name TEXT NOT NULL, description TEXT, sector TEXT, stage TEXT CHECK (stage IN ('idea','mvp','early_revenue','growth','unknown')),
 country_of_establishment TEXT, eligible_geographies TEXT[] NOT NULL DEFAULT '{}', target_markets TEXT[] NOT NULL DEFAULT '{}',
 support_needs TEXT[] NOT NULL DEFAULT '{}', funding_amount NUMERIC(16,2), funding_currency CHAR(3) NOT NULL DEFAULT 'USD',
 profile_json JSONB NOT NULL DEFAULT '{}', confirmed_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS startup_profiles_owner_idx ON startup_profiles(owner_user_id);
CREATE TABLE IF NOT EXISTS pitch_analyses (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), startup_id UUID REFERENCES startup_profiles(id) ON DELETE SET NULL,
 requested_by UUID REFERENCES users(id) ON DELETE SET NULL, original_filename TEXT NOT NULL, mime_type TEXT NOT NULL,
 file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes > 0), private_storage_key TEXT,
 status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','processing','completed','partial','failed')),
 extracted_content JSONB, agent_outputs JSONB, report JSONB, founder_reviewed_at TIMESTAMPTZ,
 approved_profile_patch JSONB, error_code TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS pitch_analyses_startup_created_idx ON pitch_analyses(startup_id, created_at DESC);
CREATE TABLE IF NOT EXISTS evidence_claims (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), pitch_analysis_id UUID NOT NULL REFERENCES pitch_analyses(id) ON DELETE CASCADE,
 claim_text TEXT NOT NULL, claim_type TEXT NOT NULL DEFAULT 'other',
 evidence_status TEXT NOT NULL CHECK (evidence_status IN ('supported','partial','missing','unverified','contradictory')),
 source_reference TEXT, source_excerpt TEXT, confidence NUMERIC(4,3) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
 reviewer_decision TEXT CHECK (reviewer_decision IN ('accepted','edited','rejected')), reviewer_note TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS opportunities (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), slug TEXT NOT NULL UNIQUE, name TEXT NOT NULL, organization TEXT NOT NULL, description TEXT NOT NULL,
 support_type TEXT NOT NULL CHECK (support_type IN ('grant','investment','incubator','accelerator','competition','other')),
 status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','review','published','paused','closed','archived')),
 eligible_geographies TEXT[] NOT NULL DEFAULT '{}', excluded_geographies TEXT[] NOT NULL DEFAULT '{}', sectors TEXT[] NOT NULL DEFAULT '{}',
 eligible_stages TEXT[] NOT NULL DEFAULT '{}', amount_min NUMERIC(16,2), amount_max NUMERIC(16,2), currency CHAR(3), deadline TIMESTAMPTZ,
 rolling_admissions BOOLEAN NOT NULL DEFAULT false, application_language TEXT[] NOT NULL DEFAULT '{}', official_url TEXT, submission_url TEXT,
 official_criteria TEXT, last_verified_at TIMESTAMPTZ, verified_by UUID REFERENCES users(id) ON DELETE SET NULL, approved_at TIMESTAMPTZ,
 created_by UUID REFERENCES users(id) ON DELETE SET NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK (amount_min IS NULL OR amount_max IS NULL OR amount_min <= amount_max),
 CHECK (status <> 'published' OR (official_url IS NOT NULL AND last_verified_at IS NOT NULL AND approved_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS opportunities_status_deadline_idx ON opportunities(status, deadline);
CREATE INDEX IF NOT EXISTS opportunities_geo_gin_idx ON opportunities USING GIN(eligible_geographies);
CREATE INDEX IF NOT EXISTS opportunities_sector_gin_idx ON opportunities USING GIN(sectors);
CREATE TABLE IF NOT EXISTS opportunity_sources (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), opportunity_id UUID NOT NULL REFERENCES opportunities(id) ON DELETE CASCADE,
 source_url TEXT NOT NULL, source_title TEXT, source_excerpt TEXT, source_hash TEXT, checked_at TIMESTAMPTZ, check_method TEXT,
 is_official BOOLEAN NOT NULL DEFAULT false, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(opportunity_id, source_url)
);
CREATE TABLE IF NOT EXISTS opportunity_versions (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), opportunity_id UUID NOT NULL REFERENCES opportunities(id) ON DELETE CASCADE,
 version_number INTEGER NOT NULL, snapshot JSONB NOT NULL, change_summary TEXT, changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(opportunity_id, version_number)
);
CREATE TABLE IF NOT EXISTS eligibility_criteria (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), opportunity_id UUID NOT NULL REFERENCES opportunities(id) ON DELETE CASCADE,
 criterion_key TEXT NOT NULL, label TEXT NOT NULL, description TEXT,
 rule_type TEXT NOT NULL CHECK (rule_type IN ('equals','includes','gte','lte','truthy','date_window','custom_review')),
 expected_value JSONB, mandatory BOOLEAN NOT NULL DEFAULT true, source_id UUID REFERENCES opportunity_sources(id) ON DELETE SET NULL,
 order_index INTEGER NOT NULL DEFAULT 0, is_active BOOLEAN NOT NULL DEFAULT true, UNIQUE(opportunity_id, criterion_key)
);
CREATE TABLE IF NOT EXISTS match_evaluations (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), startup_id UUID NOT NULL REFERENCES startup_profiles(id) ON DELETE CASCADE,
 opportunity_id UUID NOT NULL REFERENCES opportunities(id) ON DELETE CASCADE,
 eligibility_status TEXT NOT NULL CHECK (eligibility_status IN ('ELIGIBLE','NOT_ELIGIBLE','UNCERTAIN')),
 fit_score NUMERIC(5,2) CHECK (fit_score IS NULL OR fit_score BETWEEN 0 AND 100), criterion_results JSONB NOT NULL DEFAULT '[]',
 explanation JSONB NOT NULL DEFAULT '{}', ruleset_version TEXT NOT NULL DEFAULT '1.0.0', evaluated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(startup_id, opportunity_id, ruleset_version, evaluated_at)
);
CREATE INDEX IF NOT EXISTS match_evaluations_startup_idx ON match_evaluations(startup_id, evaluated_at DESC);
CREATE TABLE IF NOT EXISTS application_records (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), startup_id UUID NOT NULL REFERENCES startup_profiles(id) ON DELETE CASCADE,
 opportunity_id UUID NOT NULL REFERENCES opportunities(id) ON DELETE RESTRICT,
 status TEXT NOT NULL DEFAULT 'saved' CHECK (status IN ('saved','preparing','submitted','under_review','accepted','rejected','withdrawn')),
 deadline_snapshot TIMESTAMPTZ, notes TEXT, draft_answers JSONB NOT NULL DEFAULT '{}', required_documents JSONB NOT NULL DEFAULT '[]',
 submitted_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(startup_id, opportunity_id)
);
CREATE TABLE IF NOT EXISTS notifications (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 application_id UUID REFERENCES application_records(id) ON DELETE CASCADE, opportunity_id UUID REFERENCES opportunities(id) ON DELETE CASCADE,
 type TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, scheduled_for TIMESTAMPTZ, sent_at TIMESTAMPTZ, read_at TIMESTAMPTZ,
 dedupe_key TEXT UNIQUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_user_unread_idx ON notifications(user_id, created_at DESC) WHERE read_at IS NULL;
CREATE TABLE IF NOT EXISTS source_discovery_runs (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), source_name TEXT NOT NULL, started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 completed_at TIMESTAMPTZ, status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running','completed','partial','failed')),
 items_discovered INTEGER NOT NULL DEFAULT 0, items_changed INTEGER NOT NULL DEFAULT 0, error_summary TEXT, metadata JSONB NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS audit_log (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL, action TEXT NOT NULL,
 entity_type TEXT NOT NULL, entity_id UUID, changes JSONB NOT NULL DEFAULT '{}', request_id TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS audit_log_entity_idx ON audit_log(entity_type, entity_id, created_at DESC);
CREATE TABLE IF NOT EXISTS opportunity_source_chunks (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), source_id UUID NOT NULL REFERENCES opportunity_sources(id) ON DELETE CASCADE,
 chunk_index INTEGER NOT NULL, content TEXT NOT NULL, embedding vector(3072), metadata JSONB NOT NULL DEFAULT '{}',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(source_id, chunk_index)
);
CREATE INDEX IF NOT EXISTS opportunity_chunk_source_idx ON opportunity_source_chunks(source_id, chunk_index);
-- Add vector indexes only after embeddings exist and operator support is confirmed.
