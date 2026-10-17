-- Read-only post-import verification for the official funding candidates.
-- Run from the repository root after the import. This script never changes data.
BEGIN TRANSACTION READ ONLY;

WITH expected(slug, expected_name) AS (
  VALUES
    ('rise-palestine-startup-grant-review-2026', 'RISE Palestine Startup Grant'),
    ('scale-market-access-matching-grants-review-2026', 'Scale (Market-Access Matching Grants)'),
    ('start-now-interest-free-financing-review-2026', 'Start Now – Interest-Free Project Financing'),
    ('rise-team-company-stipend-review-2026', 'RISE Palestine TEAM Grant — Company Stipend'),
    ('rise-team-freelancer-stipend-review-2026', 'RISE Palestine TEAM Grant — Freelancer Stipend'),
    ('safe-palestine-bridge-financing-review-2026', 'SAFE Palestine — Startup Bridge Financing')
)
SELECT
  e.slug AS expected_slug,
  o.id AS matched_opportunity_id,
  o.slug AS matched_slug,
  o.name AS matched_name,
  o.status,
  (o.status = 'review') AS held_for_review,
  COUNT(DISTINCT s.id) AS source_count,
  COUNT(DISTINCT s.id) FILTER (WHERE s.is_official) AS official_source_count,
  COUNT(DISTINCT c.id) AS eligibility_criterion_count,
  CASE
    WHEN o.id IS NULL THEN 'MISSING — investigate before publication'
    WHEN o.status <> 'review' THEN 'CHECK STATUS — candidate should remain in review'
    WHEN COUNT(DISTINCT s.id) = 0 THEN 'CHECK SOURCES — no linked source records'
    WHEN COUNT(DISTINCT c.id) = 0 THEN 'CHECK CRITERIA — no linked eligibility criteria'
    ELSE 'PRESENT — manually review source freshness and eligibility'
  END AS verification_result
FROM expected e
LEFT JOIN opportunities o
  ON lower(btrim(o.slug)) = e.slug
  OR lower(btrim(o.name)) = lower(btrim(e.expected_name))
LEFT JOIN opportunity_sources s ON s.opportunity_id = o.id
LEFT JOIN eligibility_criteria c ON c.opportunity_id = o.id
GROUP BY e.slug, o.id, o.slug, o.name, o.status
ORDER BY e.slug, o.slug;

-- Check for any of the candidate slugs that became published unexpectedly.
SELECT slug, name, status, approved_at, last_verified_at
FROM opportunities
WHERE slug IN (
  'rise-palestine-startup-grant-review-2026',
  'scale-market-access-matching-grants-review-2026',
  'start-now-interest-free-financing-review-2026',
  'rise-team-company-stipend-review-2026',
  'rise-team-freelancer-stipend-review-2026',
  'safe-palestine-bridge-financing-review-2026'
)
ORDER BY slug;

-- Keep the most recent discovery records visible; a rerun may correctly report 0 new inserts.
SELECT source_name, started_at, completed_at, status, items_discovered, items_changed, metadata
FROM source_discovery_runs
WHERE source_name = 'official-funding-candidates-2026-10-17'
ORDER BY started_at DESC
LIMIT 10;

COMMIT;
