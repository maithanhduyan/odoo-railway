FROM nginx:alpine

# Remove default server block permanently
RUN rm -f /etc/nginx/conf.d/default.conf \
 && rm -rf /etc/nginx/templates \
 && rm -f /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh \
 && rm -f /docker-entrypoint.d/20-envsubst-on-templates.sh

# Copy config as template
COPY ./nginx/nginx.conf /etc/nginx/odoo.conf.template

# Copy entrypoint script into docker-entrypoint.d so it runs before nginx starts
COPY --chmod=755 ./nginx/entrypoint.sh /docker-entrypoint.d/05-odoo-envsubst.sh
