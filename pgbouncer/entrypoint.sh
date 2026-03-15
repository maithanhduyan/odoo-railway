#!/bin/sh
set -e

# Generate userlist.txt from environment variables
USERLIST_FILE="/etc/pgbouncer/userlist.txt"
CONFIG_FILE="/etc/pgbouncer/pgbouncer.ini"

DB_USER="${DB_USER:-odoo}"
DB_PASSWORD="${DB_PASSWORD:-odoo}"
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"

# Generate userlist with plain-text passwords (PgBouncer handles SCRAM auth)
echo "\"${DB_USER}\" \"${DB_PASSWORD}\"" > "$USERLIST_FILE"

# Add replication user if defined
if [ -n "$REPLICATION_USER" ] && [ -n "$REPLICATION_PASSWORD" ]; then
  echo "\"${REPLICATION_USER}\" \"${REPLICATION_PASSWORD}\"" >> "$USERLIST_FILE"
fi

# Substitute environment variables in pgbouncer.ini
sed -i "s/\${DB_HOST:-postgres}/${DB_HOST}/g" "$CONFIG_FILE"
sed -i "s/\${DB_PORT:-5432}/${DB_PORT}/g" "$CONFIG_FILE"
sed -i "s/\${DB_USER:-odoo}/${DB_USER}/g" "$CONFIG_FILE"

echo "PgBouncer configured: host=${DB_HOST}, port=${DB_PORT}, user=${DB_USER}"

exec pgbouncer /etc/pgbouncer/pgbouncer.ini
