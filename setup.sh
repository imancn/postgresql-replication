#!/bin/bash
set -euo pipefail

PRIMARY_HOST=postgres-primary
PRIMARY_PORT=5432
SUBSCRIBER_HOST=postgres-subscriber
SUBSCRIBER_PORT=5432
REPL_USER=postgres
REPL_PASS=mysecret
PRIMARY_DB=postgres-db
SUBSCRIBER_DB=replication-db
SCHEMA=public
TABLE=replication_test
BULK_TABLE=replication_bulk
TEST_ROW_DATA="test_replication_$(date +%s)"

echo "🧹 Cleaning up previous setup..."
docker compose down -v || true

echo -e "\n🚀 Starting Postgres containers..."
docker compose up -d

echo -e "\n⏳ Waiting for databases to become ready..."
for c in postgres-primary postgres-subscriber; do
  until docker exec $c pg_isready -U postgres; do sleep 2; done
done

# --- Create ALL test tables up-front in the primary ---
echo -e "\n📦 Creating test tables in primary if missing..."
docker exec postgres-primary psql -U postgres -d $PRIMARY_DB -c "CREATE TABLE IF NOT EXISTS $SCHEMA.$TABLE (id serial PRIMARY KEY, data text);"
docker exec postgres-primary psql -U postgres -d $PRIMARY_DB -c "DROP TABLE IF EXISTS $SCHEMA.$BULK_TABLE CASCADE;"
docker exec postgres-primary psql -U postgres -d $PRIMARY_DB -c "CREATE TABLE $SCHEMA.$BULK_TABLE (id serial PRIMARY KEY, value integer);"

# --- Export schema and import into subscriber ---
echo -e "\n📦 Exporting schema from primary..."
docker exec postgres-primary pg_dump -U postgres -d $PRIMARY_DB -n $SCHEMA --schema-only --no-owner --no-privileges > schema.sql

echo -e "\n📤 Importing schema to subscriber..."
cat schema.sql | docker exec -i postgres-subscriber psql -U postgres -d $SUBSCRIBER_DB || true

# --- Setup logical replication ---
echo -e "\n🔗 Creating publication on primary..."
docker exec postgres-primary psql -U postgres -d $PRIMARY_DB -c "DROP PUBLICATION IF EXISTS tests_publication;"
docker exec postgres-primary psql -U postgres -d $PRIMARY_DB -c "CREATE PUBLICATION tests_publication FOR ALL TABLES;"

echo -e "\n🔗 Creating subscription on subscriber..."
docker exec postgres-subscriber psql -U postgres -d $SUBSCRIBER_DB -c "DROP SUBSCRIPTION IF EXISTS tests_subscription;"
docker exec postgres-subscriber psql -U postgres -d $SUBSCRIBER_DB -c \
"CREATE SUBSCRIPTION tests_subscription CONNECTION 'host=$PRIMARY_HOST port=$PRIMARY_PORT user=$REPL_USER password=$REPL_PASS dbname=$PRIMARY_DB' PUBLICATION tests_publication WITH (copy_data = true, create_slot = true);"

# --- Single-row test (basic) ---
echo -e "\n📝 Inserting test row into primary..."
docker exec postgres-primary psql -U postgres -d $PRIMARY_DB -c "INSERT INTO $SCHEMA.$TABLE (data) VALUES ('$TEST_ROW_DATA');"

echo -e "\n⏳ Waiting for replication to catch up..."
sleep 5

echo -e "\n🔎 Checking replicated data in subscriber..."
RESULT=$(docker exec postgres-subscriber psql -U postgres -d $SUBSCRIBER_DB -tAc "SELECT data FROM $SCHEMA.$TABLE WHERE data = '$TEST_ROW_DATA';")

if [[ "$RESULT" == "$TEST_ROW_DATA" ]]; then
  echo -e "\n✅ SUCCESS: Data replicated! '$TEST_ROW_DATA' found in subscriber."
else
  echo -e "\n❌ ERROR: Data NOT replicated. Subscriber returned: '$RESULT'"
  exit 1
fi

echo -e "\n🟢 Logical replication setup and basic test complete!"

#########################################
# Massive Integration Test: Bulk Insert/Update/Delete
#########################################

echo -e "\n➕ Inserting 100 rows into '$BULK_TABLE' on primary..."
docker exec postgres-primary psql -U postgres -d $PRIMARY_DB -c "INSERT INTO $SCHEMA.$BULK_TABLE (value) SELECT generate_series(1,100);"

echo -e "\n⏳ Waiting for replication..."
sleep 5

COUNT=$(docker exec postgres-subscriber psql -U postgres -d $SUBSCRIBER_DB -tAc "SELECT COUNT(*) FROM $SCHEMA.$BULK_TABLE;")
if [[ "$COUNT" -eq 100 ]]; then
  echo -e "\n✅ Insert test: 100 rows successfully replicated to subscriber."
else
  echo -e "\n❌ Insert test failed: Only $COUNT rows found in subscriber!"
  exit 2
fi

echo -e "\n✏️ Updating rows (value = value*10) in primary..."
docker exec postgres-primary psql -U postgres -d $PRIMARY_DB -c "UPDATE $SCHEMA.$BULK_TABLE SET value = value*10;"

echo -e "\n⏳ Waiting for replication..."
sleep 5

UPDATED=$(docker exec postgres-subscriber psql -U postgres -d $SUBSCRIBER_DB -tAc "SELECT COUNT(*) FROM $SCHEMA.$BULK_TABLE WHERE value % 10 = 0;")
if [[ "$UPDATED" -eq 100 ]]; then
  echo -e "\n✅ Update test: All 100 rows were updated and replicated."
else
  echo -e "\n❌ Update test failed: Only $UPDATED rows updated in subscriber!"
  exit 3
fi

echo -e "\n🗑️ Deleting all rows in primary..."
docker exec postgres-primary psql -U postgres -d $PRIMARY_DB -c "DELETE FROM $SCHEMA.$BULK_TABLE;"

echo -e "\n⏳ Waiting for replication..."
sleep 5

DELETED=$(docker exec postgres-subscriber psql -U postgres -d $SUBSCRIBER_DB -tAc "SELECT COUNT(*) FROM $SCHEMA.$BULK_TABLE;")
if [[ "$DELETED" -eq 0 ]]; then
  echo -e "\n✅ Delete test: All rows deleted in subscriber."
else
  echo -e "\n❌ Delete test failed: $DELETED rows remain in subscriber!"
  exit 4
fi

echo -e "\n🎉 All massive replication tests passed!"
