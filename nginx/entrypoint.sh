#!/bin/sh
# Extract DNS resolver from system for runtime domain resolution
export DNS_RESOLVER=$(grep -m1 '^nameserver' /etc/resolv.conf | awk '{print $2}')
: "${DNS_RESOLVER:=8.8.8.8}"

envsubst '$PORT $ODOO_HOST $ODOO_PORT $ODOO_WS_PORT $DNS_RESOLVER' \
  < /etc/nginx/odoo.conf.template \
  > /etc/nginx/conf.d/odoo.conf

exec nginx -g 'daemon off;' 2>&1
