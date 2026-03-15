#!/bin/sh
# Remove any default config that may have been recreated at runtime
rm -f /etc/nginx/conf.d/default.conf

# Extract DNS resolver from system for runtime domain resolution
DNS_RESOLVER=$(grep -m1 '^nameserver' /etc/resolv.conf | awk '{print $2}')
: "${DNS_RESOLVER:=8.8.8.8}"
# Wrap IPv6 addresses in brackets for nginx resolver directive
case "$DNS_RESOLVER" in
  *:*) DNS_RESOLVER="[${DNS_RESOLVER}]" ;;
esac
export DNS_RESOLVER

# Build backup server lines if ODOO_BACKUP_HOST is set
if [ -n "$ODOO_BACKUP_HOST" ]; then
    ODOO_BACKUP_LINE_HTTP="server ${ODOO_BACKUP_HOST}:${ODOO_PORT} backup;"
    ODOO_BACKUP_LINE_WS="server ${ODOO_BACKUP_HOST}:${ODOO_WS_PORT} backup;"
else
    ODOO_BACKUP_LINE_HTTP="# no backup configured"
    ODOO_BACKUP_LINE_WS="# no backup configured"
fi
export ODOO_BACKUP_LINE_HTTP ODOO_BACKUP_LINE_WS

envsubst '$PORT $ODOO_HOST $ODOO_PORT $ODOO_WS_PORT $DNS_RESOLVER $ODOO_BACKUP_LINE_HTTP $ODOO_BACKUP_LINE_WS' \
  < /etc/nginx/odoo.conf.template \
  > /etc/nginx/conf.d/odoo.conf

echo "Generated odoo.conf with PORT=${PORT}"
[ -n "$ODOO_BACKUP_HOST" ] && echo "Failover enabled: ${ODOO_BACKUP_HOST}"
cat /etc/nginx/conf.d/odoo.conf
