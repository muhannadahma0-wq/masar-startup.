-- Masar Startup initial relational schema (PostgreSQL + pgvector).
-- Do not seed this database with invented, published funding opportunities.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS users (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
 email TEXT NOT NULL UNIQUE, display_name TEXT NOT NULL,
 preferred_language TEXT NOT NULL DEFAULT 'ar' CHECK (preferred_language IN ('ar','en')),
 role TEXT NOT NULL DEFAULT 'founder' CHECK (role IN ('founder','reviewer','admin')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE UNIQUE INDEX IF NOT EXISTS users_auth_user_id_uidx ON public.users(auth_user_id);
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

-- Supabase Auth mapping and ownership-aware row-level security baseline.
-- The auth schema is provided by Supabase; local integration tests create a minimal test-only stub.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO anon, authenticated;

CREATE OR REPLACE FUNCTION private.current_masar_user_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT u.id FROM public.users AS u WHERE u.auth_user_id = auth.uid() LIMIT 1
$function$;

CREATE OR REPLACE FUNCTION private.current_masar_user_role()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT u.role FROM public.users AS u WHERE u.auth_user_id = auth.uid() LIMIT 1
$function$;

CREATE OR REPLACE FUNCTION private.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
  IF NEW.email IS NULL OR btrim(NEW.email) = '' THEN RETURN NEW; END IF;
  INSERT INTO public.users (auth_user_id, email, display_name, preferred_language, role)
  VALUES (
    NEW.id,
    lower(NEW.email),
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'display_name', ''),
             NULLIF(split_part(NEW.email, '@', 1), ''),
             'Founder'),
    CASE WHEN NEW.raw_user_meta_data ->> 'preferred_language' IN ('ar', 'en')
         THEN NEW.raw_user_meta_data ->> 'preferred_language' ELSE 'ar' END,
    'founder'
  )
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.current_masar_user_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.current_masar_user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.handle_new_auth_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.current_masar_user_id() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION private.current_masar_user_role() TO anon, authenticated;

DROP TRIGGER IF EXISTS masar_create_public_user_after_auth_signup ON auth.users;
CREATE TRIGGER masar_create_public_user_after_auth_signup
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION private.handle_new_auth_user();

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.startup_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pitch_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evidence_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opportunities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opportunity_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opportunity_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eligibility_criteria ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_discovery_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opportunity_source_chunks ENABLE ROW LEVEL SECURITY;

-- Revoke default broad table privileges; grant only the columns and actions needed.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
GRANT USAGE ON SCHEMA public TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;

GRANT SELECT ON public.opportunities, public.opportunity_sources, public.eligibility_criteria TO anon, authenticated;
GRANT SELECT ON public.opportunity_versions, public.source_discovery_runs, public.audit_log, public.opportunity_source_chunks TO authenticated;

GRANT SELECT ON public.users TO authenticated;
GRANT UPDATE (display_name, preferred_language) ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.startup_profiles TO authenticated;
GRANT SELECT ON public.pitch_analyses, public.evidence_claims, public.match_evaluations TO authenticated;

GRANT SELECT ON public.application_records TO authenticated;
GRANT INSERT (startup_id, opportunity_id, notes, draft_answers, required_documents)
  ON public.application_records TO authenticated;
GRANT UPDATE (status, notes, draft_answers, required_documents, updated_at)
  ON public.application_records TO authenticated;
GRANT DELETE ON public.application_records TO authenticated;

GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

-- Idempotent policy reset, including redundant policies from earlier iterations.
DROP POLICY IF EXISTS "Public reads approved published opportunities" ON public.opportunities;
DROP POLICY IF EXISTS "Public reads sources for approved published opportunities" ON public.opportunity_sources;
DROP POLICY IF EXISTS "Public reads criteria for approved published opportunities" ON public.eligibility_criteria;
DROP POLICY IF EXISTS "Owners read own Masar user row" ON public.users;
DROP POLICY IF EXISTS "Owners update safe Masar profile fields" ON public.users;
DROP POLICY IF EXISTS "Owners read own startup profiles" ON public.startup_profiles;
DROP POLICY IF EXISTS "Owners create own startup profiles" ON public.startup_profiles;
DROP POLICY IF EXISTS "Owners update own startup profiles" ON public.startup_profiles;
DROP POLICY IF EXISTS "Owners delete own startup profiles" ON public.startup_profiles;
DROP POLICY IF EXISTS "Owners read own pitch analyses" ON public.pitch_analyses;
DROP POLICY IF EXISTS "Owners read claims from own pitch analyses" ON public.evidence_claims;
DROP POLICY IF EXISTS "Owners read own match evaluations" ON public.match_evaluations;
DROP POLICY IF EXISTS "Owners read own applications" ON public.application_records;
DROP POLICY IF EXISTS "Owners create applications for own startups" ON public.application_records;
DROP POLICY IF EXISTS "Owners update own applications" ON public.application_records;
DROP POLICY IF EXISTS "Owners delete own applications" ON public.application_records;
DROP POLICY IF EXISTS "Owners read own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Owners mark own notifications read" ON public.notifications;
DROP POLICY IF EXISTS "Reviewers read opportunities for review" ON public.opportunities;
DROP POLICY IF EXISTS "Reviewers read opportunity sources" ON public.opportunity_sources;
DROP POLICY IF EXISTS "Reviewers read opportunity versions" ON public.opportunity_versions;
DROP POLICY IF EXISTS "Reviewers read eligibility criteria" ON public.eligibility_criteria;
DROP POLICY IF EXISTS "Administrators read audit log" ON public.audit_log;
DROP POLICY IF EXISTS "Reviewers read source discovery runs" ON public.source_discovery_runs;
DROP POLICY IF EXISTS "Reviewers read source chunks" ON public.opportunity_source_chunks;

CREATE POLICY "Public reads approved published opportunities"
ON public.opportunities FOR SELECT TO anon, authenticated
USING (
  (status = 'published' AND approved_at IS NOT NULL)
  OR (SELECT private.current_masar_user_role()) IN ('reviewer', 'admin')
);

CREATE POLICY "Public reads sources for approved published opportunities"
ON public.opportunity_sources FOR SELECT TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.opportunities AS o
    WHERE o.id = opportunity_sources.opportunity_id
      AND o.status = 'published' AND o.approved_at IS NOT NULL
  )
  OR (SELECT private.current_masar_user_role()) IN ('reviewer', 'admin')
);

CREATE POLICY "Public reads criteria for approved published opportunities"
ON public.eligibility_criteria FOR SELECT TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.opportunities AS o
    WHERE o.id = eligibility_criteria.opportunity_id
      AND o.status = 'published' AND o.approved_at IS NOT NULL
  )
  OR (SELECT private.current_masar_user_role()) IN ('reviewer', 'admin')
);

CREATE POLICY "Owners read own Masar user row"
ON public.users FOR SELECT TO authenticated
USING (auth_user_id = (SELECT auth.uid()));

CREATE POLICY "Owners update safe Masar profile fields"
ON public.users FOR UPDATE TO authenticated
USING (auth_user_id = (SELECT auth.uid()))
WITH CHECK (
  auth_user_id = (SELECT auth.uid())
  AND role = (SELECT private.current_masar_user_role())
);

CREATE POLICY "Owners read own startup profiles"
ON public.startup_profiles FOR SELECT TO authenticated
USING (owner_user_id = (SELECT private.current_masar_user_id()));

CREATE POLICY "Owners create own startup profiles"
ON public.startup_profiles FOR INSERT TO authenticated
WITH CHECK (owner_user_id = (SELECT private.current_masar_user_id()));

CREATE POLICY "Owners update own startup profiles"
ON public.startup_profiles FOR UPDATE TO authenticated
USING (owner_user_id = (SELECT private.current_masar_user_id()))
WITH CHECK (owner_user_id = (SELECT private.current_masar_user_id()));

CREATE POLICY "Owners delete own startup profiles"
ON public.startup_profiles FOR DELETE TO authenticated
USING (owner_user_id = (SELECT private.current_masar_user_id()));

CREATE POLICY "Owners read own pitch analyses"
ON public.pitch_analyses FOR SELECT TO authenticated
USING (requested_by = (SELECT private.current_masar_user_id()));

CREATE POLICY "Owners read claims from own pitch analyses"
ON public.evidence_claims FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.pitch_analyses AS p
    WHERE p.id = evidence_claims.pitch_analysis_id
      AND p.requested_by = (SELECT private.current_masar_user_id())
  )
);

CREATE POLICY "Owners read own match evaluations"
ON public.match_evaluations FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.startup_profiles AS sp
    WHERE sp.id = match_evaluations.startup_id
      AND sp.owner_user_id = (SELECT private.current_masar_user_id())
  )
);

CREATE POLICY "Owners read own applications"
ON public.application_records FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.startup_profiles AS sp
    WHERE sp.id = application_records.startup_id
      AND sp.owner_user_id = (SELECT private.current_masar_user_id())
  )
);

CREATE POLICY "Owners create applications for own startups"
ON public.application_records FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.startup_profiles AS sp
    WHERE sp.id = application_records.startup_id
      AND sp.owner_user_id = (SELECT private.current_masar_user_id())
  )
  AND EXISTS (
    SELECT 1 FROM public.opportunities AS o
    WHERE o.id = application_records.opportunity_id
      AND o.status = 'published' AND o.approved_at IS NOT NULL
  )
);

CREATE POLICY "Owners update own applications"
ON public.application_records FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.startup_profiles AS sp
    WHERE sp.id = application_records.startup_id
      AND sp.owner_user_id = (SELECT private.current_masar_user_id())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.startup_profiles AS sp
    WHERE sp.id = application_records.startup_id
      AND sp.owner_user_id = (SELECT private.current_masar_user_id())
  )
);

CREATE POLICY "Owners delete own applications"
ON public.application_records FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.startup_profiles AS sp
    WHERE sp.id = application_records.startup_id
      AND sp.owner_user_id = (SELECT private.current_masar_user_id())
  )
);

CREATE POLICY "Owners read own notifications"
ON public.notifications FOR SELECT TO authenticated
USING (user_id = (SELECT private.current_masar_user_id()));

CREATE POLICY "Owners mark own notifications read"
ON public.notifications FOR UPDATE TO authenticated
USING (user_id = (SELECT private.current_masar_user_id()))
WITH CHECK (user_id = (SELECT private.current_masar_user_id()));

CREATE POLICY "Reviewers read opportunity versions"
ON public.opportunity_versions FOR SELECT TO authenticated
USING ((SELECT private.current_masar_user_role()) IN ('reviewer', 'admin'));

CREATE POLICY "Administrators read audit log"
ON public.audit_log FOR SELECT TO authenticated
USING ((SELECT private.current_masar_user_role()) = 'admin');

CREATE POLICY "Reviewers read source discovery runs"
ON public.source_discovery_runs FOR SELECT TO authenticated
USING ((SELECT private.current_masar_user_role()) IN ('reviewer', 'admin'));

CREATE POLICY "Reviewers read source chunks"
ON public.opportunity_source_chunks FOR SELECT TO authenticated
USING ((SELECT private.current_masar_user_role()) IN ('reviewer', 'admin'));
