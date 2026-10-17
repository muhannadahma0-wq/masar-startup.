import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const sql = readFileSync(new URL('../db/imports/official-opportunities-2026-10-17.sql', import.meta.url), 'utf8');
const verifySql = readFileSync(new URL('../db/imports/verify-official-opportunities-2026-10-17.sql', import.meta.url), 'utf8');
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
  assert.match(verifySql, /FROM opportunity_sources/i);
  assert.match(verifySql, /FROM eligibility_criteria/i);
  assert.match(verifySql, /FROM source_discovery_runs/i);
  assert.doesNotMatch(verifySql, /\b(?:INSERT\s+INTO|UPDATE\s+opportunities|DELETE\s+FROM|TRUNCATE|DROP\s+TABLE|ALTER\s+TABLE)\b/i);
  for (const slug of candidateSlugs) assert.ok(verifySql.includes(slug), 'verifier missing candidate ' + slug);
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
