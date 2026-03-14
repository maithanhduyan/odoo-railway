#!/bin/sh
set -e

# Build Odoo command with required args
CMD="odoo"
CMD="$CMD --http-port=${ODOO_PORT:-8069}"
CMD="$CMD --gevent-port=${ODOO_GEVENT_PORT:-8072}"
CMD="$CMD --proxy-mode"
CMD="$CMD --without-demo=True"

# Database (required)
CMD="$CMD --db_host=${ODOO_DATABASE_HOST}"
CMD="$CMD --db_port=${ODOO_DATABASE_PORT:-5432}"
CMD="$CMD --db_user=${ODOO_DATABASE_USER}"
CMD="$CMD --db_password=${ODOO_DATABASE_PASSWORD}"
CMD="$CMD --database=${ODOO_DATABASE_NAME}"

# SMTP (optional — only add if ODOO_SMTP_HOST is set)
if [ -n "$ODOO_SMTP_HOST" ]; then
  CMD="$CMD --smtp=${ODOO_SMTP_HOST}"
  CMD="$CMD --smtp-port=${ODOO_SMTP_PORT_NUMBER:-587}"
  [ -n "$ODOO_SMTP_USER" ]     && CMD="$CMD --smtp-user=${ODOO_SMTP_USER}"
  [ -n "$ODOO_SMTP_PASSWORD" ] && CMD="$CMD --smtp-password=${ODOO_SMTP_PASSWORD}"
  [ -n "$ODOO_EMAIL_FROM" ]    && CMD="$CMD --email-from=${ODOO_EMAIL_FROM}"
fi

# Init modules on first deploy only (set ODOO_INIT=base or ODOO_INIT=all)
if [ -n "$ODOO_INIT" ]; then
  CMD="$CMD --init=${ODOO_INIT}"
fi

exec $CMD 2>&1

