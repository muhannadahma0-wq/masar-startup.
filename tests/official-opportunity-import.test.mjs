import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const schemaSql = readFileSync(new URL('../db/schema.sql', import.meta.url), 'utf8');
const sql = readFileSync(new URL('../db/imports/official-opportunities-2026-10-17.sql', import.meta.url), 'utf8');
const verifySql = readFileSync(new URL('../db/imports/verify-official-opportunities-2026-10-17.sql', import.meta.url), 'utf8');
const preflightSql = readFileSync(new URL('../db/imports/preflight-official-opportunities-2026-10-17.sql', import.meta.url), 'utf8');
const runbook = readFileSync(new URL('../docs/research/production-db-setup-and-import-ar.md', import.meta.url), 'utf8');
const refs = JSON.parse(readFileSync(new URL('../data/research/open-source-project-references.json', import.meta.url), 'utf8'));
const review = readFileSync(new URL('../docs/research/official-opportunities-and-open-source-review-ar.md', import.meta.url), 'utf8');

const candidateSlugs = [
  'rise-palestine-startup-grant-review-2026',
  'scale-market-access-matching-grants-review-2026',
  'start-now-interest-free-financing-review-2026',
  'rise-team-company-stipend-review-2026',
  'rise-team-freelancer-stipend-review-2026',
  'safe-palestine-bridge-financing-review-2026'
];

test('all six official candidates stay in review; nothing is published automatically', () => {
  assert.match(sql, /c\.slug,c\.name,c\.organization,c\.description,c\.support_type,'review'/);
  assert.match(sql, /'published',false/);
  for (const slug of candidateSlugs) assert.ok(sql.includes(slug), 'missing candidate ' + slug);
});

test('import is transactional and does not update/delete existing opportunity records', () => {
  assert.match(sql, /BEGIN;/);
  assert.match(sql, /COMMIT;/);
  assert.match(sql, /ON CONFLICT \(slug\) DO NOTHING/);
  assert.match(sql, /WHERE NOT EXISTS\s*\(/);
  assert.match(sql, /SELECT 1 FROM _masar_candidates sibling/);
  assert.doesNotMatch(sql, /\bUPDATE\s+opportunities\b/i);
  assert.doesNotMatch(sql, /\bDELETE\s+FROM\s+opportunities\b/i);
});

test('official evidence and rule records are included', () => {
  assert.match(sql, /INSERT INTO opportunity_sources/);
  assert.match(sql, /c\.official_url,c\.submission_url,c\.official_criteria/);
  assert.match(sql, /sibling\.submission_url/);
  assert.match(sql, /INSERT INTO eligibility_criteria/);
  for (const url of [
    'https://risepalestine.intersecthub.org/apply-for-support/',
    'https://risepalestine.intersecthub.org/grants/startup-grant/',
    'https://risepalestine.intersecthub.org/grants/team-grant/',
    'https://ipsd.ps/content/programs/scale-market-access-matching-grants.html',
    'https://www.pma.ps/start-now-program',
    'https://risepalestinesubmit.intersecthub.org/grant/startup%20Grant',
    'https://risepalestinesubmit.intersecthub.org/grant/team%20Grant',
    'https://risepalestinesubmit.intersecthub.org/grant/freelancer%20Grant',
    'https://fs20.formsite.com/DAIForms/NEXUS-Scale/login',
    'https://airtable.com/appQmP5eXgHfbG51m/shrMZRS8rhyjfyWvZ'
  ]) assert.ok(sql.includes(url), 'missing official source ' + url);
});

test('post-import verifier is read-only and checks each candidate plus linked evidence', () => {
  assert.match(verifySql, /BEGIN TRANSACTION READ ONLY;/i);
  assert.match(verifySql, /COMMIT;/i);
  assert.match(verifySql, /FROM opportunities/i);
  assert.match(verifySql, /JOIN opportunity_sources/i);
  assert.match(verifySql, /JOIN eligibility_criteria/i);
  assert.match(verifySql, /FROM source_discovery_runs/i);
  assert.doesNotMatch(verifySql, /\b(?:INSERT\s+INTO|UPDATE\s+opportunities|DELETE\s+FROM|TRUNCATE|DROP\s+TABLE|ALTER\s+TABLE)\b/i);
  for (const slug of candidateSlugs) assert.ok(verifySql.includes(slug), 'verifier missing candidate ' + slug);
});

test('production preflight only reads database identity, schema tables, and extensions', () => {
  assert.match(preflightSql, /BEGIN TRANSACTION READ ONLY;/i);
  assert.match(preflightSql, /current_database\(\)/i);
  assert.match(preflightSql, /opportunities/);
  assert.match(preflightSql, /opportunity_sources/);
  assert.match(preflightSql, /eligibility_criteria/);
  assert.match(preflightSql, /source_discovery_runs/);
  assert.match(preflightSql, /pgcrypto/);
  assert.match(preflightSql, /vector/);
  assert.doesNotMatch(preflightSql, /\b(?:INSERT\s+INTO|UPDATE\s+|DELETE\s+FROM|TRUNCATE|DROP\s+TABLE|ALTER\s+TABLE|CREATE\s+)\b/i);
  assert.match(runbook, /لا ترسل كلمة مرور قاعدة البيانات/);
  assert.match(runbook, /backup|نسخة احتياطية/i);
  assert.match(runbook, /database: connected/);
});

test('expired PEF announcement is excluded from candidate SQL', () => {
  assert.doesNotMatch(sql, /e\.pef\.ps\/files\/Home\/Project\/2138/);
  assert.match(review, /30 سبتمبر 2026/);
});

test('open-source references remain separate from funding opportunities', () => {
  assert.equal(refs.projects.length, 6);
  assert.equal(refs.fundingResearchUpdate.length, 2);
  assert.ok(refs.projects.every(p => p.repositoryUrl.startsWith('https://github.com/')));
  assert.match(refs.purpose, /must never be inserted into the opportunities table/);
});

const apiServer = readFileSync(new URL('../apps/api/src/server.ts', import.meta.url), 'utf8');
const apiEnvExample = readFileSync(new URL('../apps/api/.env.example', import.meta.url), 'utf8');

test('Supabase REST fallback reads only published, approved opportunities with a publishable key', () => {
  assert.match(apiServer, /SUPABASE_URL/);
  assert.match(apiServer, /SUPABASE_PUBLISHABLE_KEY/);
  assert.match(apiServer, /apikey:\s*supabasePublishableKey/);
  assert.match(apiServer, /status',\s*'eq\.published'/);
  assert.match(apiServer, /approved_at',\s*'not\.is\.null'/);
  assert.match(apiServer, /mode:\s*'database'/);
  assert.match(apiEnvExample, /SUPABASE_URL=/);
  assert.match(apiEnvExample, /SUPABASE_PUBLISHABLE_KEY=/);
  assert.doesNotMatch(apiServer, /service_role/i);
  assert.ok(!apiServer.includes('authorization: `Bearer ${supabasePublishableKey}`'), 'publishable keys must only be sent through the apikey header');
});


test('database schema enables RLS on all public tables and only publishes approved opportunities for clients', () => {
  const publicTables = [
    'users', 'startup_profiles', 'pitch_analyses', 'evidence_claims', 'opportunities',
    'opportunity_sources', 'opportunity_versions', 'eligibility_criteria', 'match_evaluations',
    'application_records', 'notifications', 'source_discovery_runs', 'audit_log', 'opportunity_source_chunks'
  ];
  for (const table of publicTables) {
    assert.ok(schemaSql.includes(`ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY;`), 'RLS missing on ' + table);
  }
  assert.match(schemaSql, /CREATE POLICY "Public reads approved published opportunities"/);
  assert.match(schemaSql, /TO anon, authenticated/);
  assert.match(schemaSql, /status = 'published' AND approved_at IS NOT NULL/);
  assert.match(schemaSql, /DROP POLICY IF EXISTS "Public reads approved published opportunities"/);
});

const webApp = readFileSync(new URL('../apps/web/src/App.tsx', import.meta.url), 'utf8');
const webEnvExample = readFileSync(new URL('../apps/web/.env.example', import.meta.url), 'utf8');

test('funding opportunities come from the API and do not use hard-coded opportunity demos', () => {
  assert.match(webApp, /VITE_API_BASE_URL/);
  assert.match(webApp, /fetch\(\`\$\{apiBase\}\/api\/opportunities\`/);
  assert.match(webApp, /setOpportunities\(items\.map/);
  assert.match(webApp, /formatOpportunityAmount/);
  assert.match(webApp, /o\.sourceUrl/);
  assert.doesNotMatch(webApp, /const demoOpportunities: Opportunity\[\]/);
  assert.match(webEnvExample, /VITE_API_BASE_URL=/);
});


const rlsIntegrationSql = readFileSync(new URL('./rls-ownership.integration.sql', import.meta.url), 'utf8');

test('schema maps Supabase Auth identities and grants only ownership-scoped client access', () => {
  assert.ok(schemaSql.includes('auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE'));
  assert.ok(schemaSql.includes('CREATE SCHEMA IF NOT EXISTS private'));
  assert.ok(schemaSql.includes('CREATE OR REPLACE FUNCTION private.current_masar_user_id()'));
  assert.ok(schemaSql.includes('CREATE OR REPLACE FUNCTION private.current_masar_user_role()'));
  assert.ok(schemaSql.includes('CREATE TRIGGER masar_create_public_user_after_auth_signup'));
  assert.ok(schemaSql.includes('REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon, authenticated'));
  for (const policy of [
    'Owners read own startup profiles',
    'Owners create applications for own startups',
    'Owners read own notifications',
    'Administrators read audit log',
    'Reviewers read source chunks'
  ]) assert.ok(schemaSql.includes('CREATE POLICY "' + policy + '"'), 'missing policy ' + policy);
  assert.ok(!schemaSql.includes('CREATE OR REPLACE FUNCTION public.current_masar_user_id()'));
  assert.ok(!schemaSql.includes('CREATE OR REPLACE FUNCTION public.current_masar_user_role()'));
});

test('RLS integration fixture verifies two-user isolation and rolls back every fixture row', () => {
  assert.ok(rlsIntegrationSql.includes('founder-a@example.test'));
  assert.ok(rlsIntegrationSql.includes('founder-b@example.test'));
  assert.match(rlsIntegrationSql, /Founder can see another startup profile/);
  assert.match(rlsIntegrationSql, /Founder inserted an application for another founder/);
  assert.match(rlsIntegrationSql, /Founder was able to update their own role/);
  assert.match(rlsIntegrationSql, /ROLLBACK;/);
});


const apiSource = readFileSync(new URL('../apps/api/src/server.ts', import.meta.url), 'utf8');
const webClientSource = readFileSync(new URL('../apps/web/src/lib/supabase.ts', import.meta.url), 'utf8');

test('Supabase Auth is configured with a publishable key and pitch analysis rejects anonymous callers', () => {
  assert.match(webClientSource, /VITE_SUPABASE_URL/);
  assert.match(webClientSource, /VITE_SUPABASE_PUBLISHABLE_KEY/);
  assert.match(webClientSource, /createClient\(url, publishableKey/);
  assert.match(webApp, /supabase\.auth\.signUp/);
  assert.match(webApp, /supabase\.auth\.signInWithPassword/);
  assert.match(webApp, /supabase\.auth\.onAuthStateChange/);
  assert.match(webApp, /if\(nextSession\)\{\s*setAuthOpen\(false\)/);
  assert.match(webApp, /protectedPages/);
  assert.match(webApp, /auth_user_id/);
  assert.match(webApp, /emailRedirectTo:\s*window\.location\.origin/);
  assert.doesNotMatch(webClientSource, /sb_secret_/i);
  assert.doesNotMatch(webClientSource, /service_role\\s*:/i);
  assert.match(apiSource, /async function validateSupabaseAccessToken/);
  assert.match(apiSource, /new URL\('\/auth\/v1\/user', supabaseUrl\)/);
  assert.match(apiSource, /app\.post\('\/api\/pitch-analyses',requireSupabaseAuth,upload\.single\('file'\)/);
  assert.match(apiSource, /AUTHENTICATION_REQUIRED/);
  assert.match(apiSource, /AUTH_SERVICE_UNAVAILABLE/);
});
