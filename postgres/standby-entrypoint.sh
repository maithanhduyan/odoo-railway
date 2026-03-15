#!/bin/bash
set -e

# Standby entrypoint: performs base backup from primary and starts as replica.
# This script replaces the normal entrypoint for standby nodes.

PGDATA="${PGDATA:-/var/lib/postgresql/data/pgdata}"
PRIMARY_HOST="${PRIMARY_HOST:-pg-primary}"
PRIMARY_PORT="${PRIMARY_PORT:-5432}"
REPLICATION_USER="${REPLICATION_USER:-replicator}"
REPLICATION_PASSWORD="${REPLICATION_PASSWORD:-repl_secret}"

export PGPASSWORD="$REPLICATION_PASSWORD"

# Wait for primary to be ready
echo "Waiting for primary at ${PRIMARY_HOST}:${PRIMARY_PORT}..."
until pg_isready -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$REPLICATION_USER" 2>/dev/null; do
  echo "Primary not ready, retrying in 2s..."
  sleep 2
done
echo "Primary is ready."

# If PGDATA is empty or missing, do a base backup from primary
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Performing base backup from primary..."
  rm -rf "$PGDATA"/*

  pg_basebackup \
    -h "$PRIMARY_HOST" \
    -p "$PRIMARY_PORT" \
    -U "$REPLICATION_USER" \
    -D "$PGDATA" \
    -Fp -Xs -P -R

  # -R flag creates standby.signal and sets primary_conninfo in postgresql.auto.conf
  echo "Base backup completed. Standby signal configured."
else
  echo "PGDATA already initialized, ensuring standby.signal exists..."
  touch "$PGDATA/standby.signal"

  # Ensure primary_conninfo is set
  if ! grep -q "primary_conninfo" "$PGDATA/postgresql.auto.conf" 2>/dev/null; then
    echo "primary_conninfo = 'host=${PRIMARY_HOST} port=${PRIMARY_PORT} user=${REPLICATION_USER} password=${REPLICATION_PASSWORD}'" >> "$PGDATA/postgresql.auto.conf"
  fi
fi

# Ensure correct permissions
chmod 0700 "$PGDATA"

unset PGPASSWORD

echo "Starting PostgreSQL standby..."
exec postgres -p "${POSTGRES_PORT:-5432}" -c "listen_addresses=*"
