#!/bin/sh
envsubst '$PORT $ODOO_HOST $ODOO_PORT $ODOO_WS_PORT' \
  < /etc/nginx/templates/odoo.conf.template \
  > /etc/nginx/conf.d/odoo.conf

exec nginx -g 'daemon off;' 2>&1
