#!/bin/bash
set -e

# Generate userlist.txt from environment variables
USERLIST_FILE="/etc/pgbouncer/userlist.txt"
CONFIG_FILE="/etc/pgbouncer/pgbouncer.ini"

DB_USER="${DB_USER:-odoo}"
DB_PASSWORD="${DB_PASSWORD:-odoo}"
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"

# Generate MD5 password hash for pgbouncer auth
# Format: "username" "md5<md5hash of password+username>"
MD5_PASS=$(echo -n "${DB_PASSWORD}${DB_USER}" | md5sum | awk '{print $1}')
echo "\"${DB_USER}\" \"md5${MD5_PASS}\"" > "$USERLIST_FILE"

# Add replication user if defined
if [ -n "$REPLICATION_USER" ] && [ -n "$REPLICATION_PASSWORD" ]; then
  MD5_REPL=$(echo -n "${REPLICATION_PASSWORD}${REPLICATION_USER}" | md5sum | awk '{print $1}')
  echo "\"${REPLICATION_USER}\" \"md5${MD5_REPL}\"" >> "$USERLIST_FILE"
fi

# Substitute environment variables in pgbouncer.ini
sed -i "s/\${DB_HOST:-postgres}/${DB_HOST}/g" "$CONFIG_FILE"
sed -i "s/\${DB_PORT:-5432}/${DB_PORT}/g" "$CONFIG_FILE"
sed -i "s/\${DB_USER:-odoo}/${DB_USER}/g" "$CONFIG_FILE"

echo "PgBouncer configured: host=${DB_HOST}, port=${DB_PORT}, user=${DB_USER}"

exec pgbouncer /etc/pgbouncer/pgbouncer.ini
