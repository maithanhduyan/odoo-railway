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
chown -R postgres:postgres "$PGDATA"
chmod 0700 "$PGDATA"

# Generate SSL certs if primary had SSL enabled but certs weren't copied
SSL_DIR="/var/lib/postgresql/data/certs"
if grep -q "ssl_cert_file" "$PGDATA/postgresql.conf" 2>/dev/null && [ ! -f "$SSL_DIR/server.crt" ]; then
  echo "Generating SSL certificates for standby..."
  mkdir -p "$SSL_DIR"
  openssl req -new -x509 -days 820 -nodes -text -out "$SSL_DIR/root.crt" -keyout "$SSL_DIR/root.key" -subj "/CN=root-ca"
  chmod og-rwx "$SSL_DIR/root.key"
  openssl req -new -nodes -text -out "$SSL_DIR/server.csr" -keyout "$SSL_DIR/server.key" -subj "/CN=localhost"
  chown postgres:postgres "$SSL_DIR/server.key"
  chmod og-rwx "$SSL_DIR/server.key"
  openssl x509 -req -in "$SSL_DIR/server.csr" -text -days 820 -CA "$SSL_DIR/root.crt" -CAkey "$SSL_DIR/root.key" -CAcreateserial -out "$SSL_DIR/server.crt"
  chown postgres:postgres "$SSL_DIR/server.crt"
  chown -R postgres:postgres "$SSL_DIR"
fi

unset PGPASSWORD

echo "Starting PostgreSQL standby..."
exec gosu postgres postgres -p "${POSTGRES_PORT:-5432}" -c "listen_addresses=*"
