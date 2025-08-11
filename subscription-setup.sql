-- subscription-setup.sql
-- Run this on the SUBSCRIBER server connected to DB: "central"

-- Optional: switch DB in psql/DataGrip if needed
-- \c "central"

-- 0) Ensure target schema (and **matching tables**) exist.
--    Logical replication does NOT create tables automatically.
--    Create the same tables here as on the PRIMARY (definitions must be compatible).
CREATE SCHEMA IF NOT EXISTS "iman-db";
-- TODO: CREATE TABLE statements for each table under "iman-db" to match the PRIMARY.

-- 1) Safe re-run: drop existing subscription if present
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_subscription WHERE subname = 'sub_iman') THEN
    EXECUTE 'DROP SUBSCRIPTION sub_iman';
  END IF;
END$$;

-- 2) Create the subscription pointing to the PRIMARY
CREATE SUBSCRIPTION sub_iman
CONNECTION 'host=172.31.40.112 port=5432 dbname=accounting-db-v1 user=replicator password=CHANGE_ME sslmode=prefer'
PUBLICATION pub_iman
WITH (
  copy_data = true,   -- initial table copy
  create_slot = true, -- auto-creates a replication slot on the PRIMARY
  enabled = true
);

-- 3) Observe status; `status` should become 'replicating' after initial copy
SELECT subname, status, received_lsn, last_msg_send_time, last_msg_receipt_time
FROM pg_stat_subscription;

-- NOTES:
-- * PRIMARY must have wal_level=logical **and must be restarted** after ALTER SYSTEM.
-- * PRIMARY's pg_hba.conf must allow host 172.31.40.133 for user `replicator`.
-- * If you add new tables later, run on PRIMARY:
--     ALTER PUBLICATION pub_iman ADD TABLE "iman-db".your_table;
--   and ensure the same table exists on SUBSCRIBER before data flows.
