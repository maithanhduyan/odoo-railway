#!/bin/sh
set -e

# Build argument list using set -- to handle values with spaces safely
set -- odoo
set -- "$@" "--http-port=${ODOO_PORT:-8069}"
set -- "$@" "--gevent-port=${ODOO_GEVENT_PORT:-8072}"
set -- "$@" "--proxy-mode"
set -- "$@" "--without-demo=True"

# Database (required)
set -- "$@" "--db_host=${ODOO_DATABASE_HOST}"
set -- "$@" "--db_port=${ODOO_DATABASE_PORT:-5432}"
set -- "$@" "--db_user=${ODOO_DATABASE_USER}"
set -- "$@" "--db_password=${ODOO_DATABASE_PASSWORD}"
set -- "$@" "--database=${ODOO_DATABASE_NAME}"

# SMTP (optional — only add if ODOO_SMTP_HOST is set)
if [ -n "$ODOO_SMTP_HOST" ]; then
  set -- "$@" "--smtp=${ODOO_SMTP_HOST}"
  set -- "$@" "--smtp-port=${ODOO_SMTP_PORT_NUMBER:-587}"
  [ -n "$ODOO_SMTP_USER" ]     && set -- "$@" "--smtp-user=${ODOO_SMTP_USER}"
  [ -n "$ODOO_SMTP_PASSWORD" ] && set -- "$@" "--smtp-password=${ODOO_SMTP_PASSWORD}"
  [ -n "$ODOO_EMAIL_FROM" ]    && set -- "$@" "--email-from=${ODOO_EMAIL_FROM}"
fi

# Init modules on first deploy only (set ODOO_INIT=base or ODOO_INIT=all)
if [ -n "$ODOO_INIT" ]; then
  set -- "$@" "--init=${ODOO_INIT}"
fi

exec "$@" 2>&1

