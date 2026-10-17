-- Read-only preflight before importing reviewed funding candidates.
-- Confirms database identity and the minimum schema expected by the import.
-- Does not read credentials, insert/update/delete data, or change schema.

BEGIN TRANSACTION READ ONLY;

SELECT
  current_database() AS connected_database,
  current_user AS connected_role,
  current_setting('server_version') AS postgres_version,
  inet_server_addr() AS server_address,
  current_schema() AS current_schema;

WITH required_tables(table_name) AS (
  VALUES
    ('opportunities'),
    ('opportunity_sources'),
    ('eligibility_criteria'),
    ('audit_log'),
    ('source_discovery_runs')
)
SELECT
  r.table_name,
  EXISTS (
    SELECT 1
    FROM information_schema.tables t
    WHERE t.table_schema = current_schema()
      AND t.table_name = r.table_name
      AND t.table_type = 'BASE TABLE'
  ) AS present_in_current_schema
FROM required_tables r
ORDER BY r.table_name;

WITH required_extensions(extension_name) AS (
  VALUES ('pgcrypto'), ('vector')
)
SELECT
  r.extension_name,
  EXISTS (
    SELECT 1
    FROM pg_extension e
    WHERE e.extname = r.extension_name
  ) AS installed
FROM required_extensions r
ORDER BY r.extension_name;

SELECT
  (
    SELECT count(*)
    FROM information_schema.tables t
    WHERE t.table_schema = current_schema()
      AND t.table_type = 'BASE TABLE'
      AND t.table_name IN (
        'opportunities',
        'opportunity_sources',
        'eligibility_criteria',
        'audit_log',
        'source_discovery_runs'
      )
  ) = 5 AS all_required_tables_present,
  (
    SELECT count(*)
    FROM pg_extension e
    WHERE e.extname IN ('pgcrypto', 'vector')
  ) = 2 AS all_required_extensions_installed;

COMMIT;
