FROM nginx:alpine

# Remove default server block
RUN rm /etc/nginx/conf.d/default.conf

# Copy config as template
COPY ./nginx/nginx.conf /etc/nginx/templates/odoo.conf.template

# Only substitute Railway env vars; leave nginx variables ($http_host, etc.) intact
CMD sh -c "envsubst '\$PORT \$ODOO_HOST \$ODOO_PORT \$ODOO_WS_PORT' < /etc/nginx/templates/odoo.conf.template > /etc/nginx/conf.d/odoo.conf && nginx -g 'daemon off;'"
