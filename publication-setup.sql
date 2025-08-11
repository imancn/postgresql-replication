-- publication-setup.sql
-- Run this on the PRIMARY server connected to DB: "iman-db"
-- Make sure to restart PostgreSQL after ALTER SYSTEM changes for them to take effect.

-- Optional: switch DB in psql/DataGrip if needed
-- \c "iman-dd"

-- 1) Ensure logical replication prerequisites (requires server RESTART to apply)
ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM SET max_wal_senders = '10';
ALTER SYSTEM SET max_replication_slots = '10';

-- Optional: useful toggle (no restart required)
ALTER SYSTEM SET track_commit_timestamp = 'off';

-- Apply non-restart settings now (for completeness)
SELECT pg_reload_conf();

-- Inspect which settings still need a restart
SELECT name, setting, pending_restart
FROM pg_settings
WHERE name IN ('wal_level','max_wal_senders','max_replication_slots');

-- 2) Create a dedicated replication user (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replicator') THEN
    CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD 'CHANGE_ME';
  END IF;
END$$;

-- 3) Ensure the schema to be published exists (adjust if your schema name is different)
CREATE SCHEMA IF NOT EXISTS "iman-db";

-- 4) Create a clean publication: prefer a consistent name `pub_iman`
DO $$
BEGIN
  -- If an older/different publication name exists, you may drop it (optional)
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'pub_iman') THEN
    EXECUTE 'DROP PUBLICATION pub_iman';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'pub_iman') THEN
    EXECUTE 'CREATE PUBLICATION pub_iman FOR SCHEMA "iman-db"';
  END IF;
END$$;

-- 5) Inspect publication and its tables
\dRp+
SELECT * FROM pg_publication_tables WHERE pubname = 'pub_iman';

-- NOTE:
-- * Restart the PRIMARY after ALTER SYSTEM so wal_level=logical is active.
-- * Ensure pg_hba.conf on PRIMARY allows connections from 172.31.40.133 for user `replicator`.
