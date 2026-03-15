#!/bin/bash
set -e

# This script configures the PRIMARY PostgreSQL server for streaming replication.
# It runs as part of docker-entrypoint-initdb.d on first initialization.

REPLICATION_USER="${REPLICATION_USER:-replicator}"
REPLICATION_PASSWORD="${REPLICATION_PASSWORD:-repl_secret}"

# Create replication user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${REPLICATION_USER}') THEN
        CREATE ROLE ${REPLICATION_USER} WITH REPLICATION LOGIN PASSWORD '${REPLICATION_PASSWORD}';
      END IF;
    END
    \$\$;
EOSQL

# Configure pg_hba.conf for replication connections
cat >> "$PGDATA/pg_hba.conf" <<EOF

# Replication connections
host    replication     ${REPLICATION_USER}     0.0.0.0/0       md5
EOF

# Configure postgresql.conf for replication
cat >> "$PGDATA/postgresql.conf" <<EOF

# ---- Streaming Replication (Primary) ----
wal_level = replica
max_wal_senders = 5
max_replication_slots = 5
wal_keep_size = 256MB
hot_standby = on
synchronous_commit = on
EOF

echo "Primary replication configuration completed."
