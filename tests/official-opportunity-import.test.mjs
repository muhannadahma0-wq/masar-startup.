import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const sql = readFileSync(new URL('../db/imports/official-opportunities-2026-10-17.sql', import.meta.url), 'utf8');
const refs = JSON.parse(readFileSync(new URL('../data/research/open-source-project-references.json', import.meta.url), 'utf8'));
const review = readFileSync(new URL('../docs/research/official-opportunities-and-open-source-review-ar.md', import.meta.url), 'utf8');

test('new official candidates are held in review; none is published automatically', () => {
  assert.match(sql, /c\.slug,c\.name,c\.organization,c\.description,c\.support_type,'review'/);
  assert.match(sql, /'published',false/);
});

test('import is additive and never updates or deletes existing opportunities', () => {
  assert.match(sql, /BEGIN;/);
  assert.match(sql, /COMMIT;/);
  assert.match(sql, /ON CONFLICT \(slug\) DO NOTHING/);
  assert.match(sql, /WHERE NOT EXISTS\s*\(/);
  assert.doesNotMatch(sql, /\bUPDATE\s+opportunities\b/i);
  assert.doesNotMatch(sql, /\bDELETE\s+FROM\s+opportunities\b/i);
});

test('sources and structured criteria are linked to official evidence', () => {
  assert.match(sql, /INSERT INTO opportunity_sources/);
  assert.match(sql, /INSERT INTO eligibility_criteria/);
  for (const url of [
    'https://risepalestine.intersecthub.org/apply-for-support/',
    'https://ipsd.ps/content/programs/scale-market-access-matching-grants.html',
    'https://www.pma.ps/start-now-program'
  ]) assert.ok(sql.includes(url), 'missing official source ' + url);
});

test('expired PEF announcement is excluded from candidate SQL', () => {
  assert.doesNotMatch(sql, /e\.pef\.ps\/files\/Home\/Project\/2138/);
  assert.match(review, /30 سبتمبر 2026/);
});

test('repository references are separate from funding opportunities', () => {
  assert.equal(refs.projects.length, 6);
  assert.ok(refs.projects.every(p => p.repositoryUrl.startsWith('https://github.com/')));
  assert.match(refs.purpose, /must never be inserted into the opportunities table/);
});
